%% compare_deltaR2_with_deltaVar.m
% Compare stimulus-dependent delta R2 with three SAVED Varline metrics.
% Standalone SCRIPT: edit USER SETTINGS, then Run from an empty workspace.
% Revision 2026-11-10b: accept duplicate display variants after exact checks.
%
% INPUTS (read only):
%   1. GPL_class_deltaR2_figure_plot.m summary MAT containing
%      MultiSessionGPLClassDeltaR2 (the supplied poster_v6 format).
%   2. Varline_figure_plot.m summary MAT: count + mean_count + neuron.
%   3. Varline_figure_plot.m summary MAT: count + none + neuron.
%      Both Varline files contain VarlineResults (varline_posterior_v2).
%      Choose matching component_pair, data_content, runIdx and uncertainty.
% No GPL_class_deltaVar results, posterior MAT, model files or GPL files are
% loaded. No model fitting, reconstruction, variance or percentage calculation.
% Saved R2's four matched differences are finite-averaged exactly as in its
% original figure, then multiplied by -1. Saved Varline percentages/pp are
% read verbatim. The ONLY new statistical calculation is correlation.
%
% THREE FIGURES, EACH 3 x 4:
%   Rows: High - Low; Large - Small; Plaid - Grating.
%   Columns, within_across: V1 Within | V1 Across | MT Within | MT Across.
%   Columns, ff_fb:         V1 FF     | V1 FB     | MT FF     | MT FB.
%   Figure 1: normalized variance percentage change (count / mean_count).
%   Figure 2: figure 1 percentage - normalized Noise percentage (pp).
%   Figure 3: unnormalized variance percentage change (count / none).
% X and Y both use SECOND MINUS FIRST. Negative means a decrease, except
% that the pp difference in figure 2 measures change RELATIVE TO Noise.
% All finite data are displayed and tested: NO +/-100 limit, clipping,
% winsorization, jitter, central-percentile selection or outlier removal.
%
% MATCHING / POPULATION:
% A neuron is matched by actual session name + model group + saved unit ID.
% Session indices and neuron row numbers need NOT agree between input MATs.
% unit_id is the original saved ID; model_local_id is its 1-based row in the
% R2 model group. Do not assume these two IDs have the same numeric value.
% Use the intersection of session/neuron identities in all THREE MATs.
% Each panel then keeps its own finite X/Y pairs (so N can differ by metric).
% all_neurons includes GPL-invalid neurons. pcu_neurons keeps P/C/U using
% classifications already saved in the R2 MAT. A saved all-neuron Varline
% result can be subset to PCU. A PCU Varline result cannot supply all-neuron
% percentages without recalculation, which this program does not do.
% Raw R2 can use either saved population: its session_data retains all units.
% Z-scored R2 REQUIRES the requested saved population because its session-area
% standardization pool depends on neuron_population; Z is never recalculated.
%
% FILE SELECTION:
% Blank explicit paths enable metadata-based search in the directories below.
% Prefer an exact saved population over a supported population subset.
% Multiple equally matching files: compare the saved analysis values after
% aligning actual session names and unit IDs. If exactly equal (NaN=NaN),
% use the newest file and retain all equivalent filenames in input provenance.
% Display settings, old tests, timestamps and original folder paths are ignored.
% If analysis values/identities differ, report the first difference and stop;
% an explicit MAT path can resolve that ambiguity. No input files are changed.
% One R2 MAT contains all four sources. Each Varline MAT stores only its
% selected pair/normalization; ff_fb therefore needs its own two Varline MATs.
% Only all-condition POSTERIOR and summary_unit='neuron' are supported here.
%
% STATISTICS / OUTPUT:
% Pearson, Spearman or both; two-sided nominal P per panel, neurons pooled
% across sessions. No session-cluster or multiple-comparison adjustment.
% Fewer than 3 finite pairs or a constant axis -> coefficient/P = NaN.
% MATLAB Statistics and Machine Learning Toolbox is required for corr.
% Output MAT: DeltaR2VarComparison, containing settings, input provenance,
% session/neuron matching, all X/Y values, finite masks, IDs and correlations.
% All save flags may be false: figures still appear when make_plots=true.

clc;
clear;

%% =========================== USER SETTINGS ============================

root_dir = 'I:\np_data';

% Shared ANALYSIS settings: choose/validate the already saved result sets.
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;                         % 1 original; 2 independently shuffled units
group_names = {'V1','MT'};          % exactly two areas, in MODEL GROUP order
component_pair = 'within_across';  % 'within_across' or 'ff_fb'
neuron_population = 'all_neurons'; % 'all_neurons' or 'pcu_neurons'
included_sessions = {};           % {}: common sessions in all three MATs
% Or e.g. {'RafiL001p0122_g1','RafiL001p0125_g1'}; CatGT names/full paths
% are also accepted. Explicitly requested sessions must exist in all inputs.

% X-axis analysis settings.
r2_value_mode = 'raw';             % 'raw' or 'zscore'
reconstruction_suffix = 'all_across_within_ff_fb';
gpl_mat_name = 'unit_gpl_results_sponsub.mat'; % validates saved classification

% Y-axis analysis settings. Both normalizations are read for the three plots.
uncertainty_included = 0;          % 0 or 1; selects saved Varline u0/u1
variance_unit = 'count';           % fixed count, as requested
% model_mode='all_condition'; variance_source='posterior';
% summary_unit='neuron'; all are fixed and checked against input metadata.

correlation_method = 'Spearman';   % 'Pearson', 'Spearman' or 'both'
significance_alpha = 0.05;         % saved significance flag; P is uncorrected

% Optional exact MAT paths. Empty string -> automatic metadata-based search.
r2_mat_file = '';
varline_mean_count_mat_file = '';
varline_none_mat_file = '';
r2_search_dir = '';               % '' -> root_dir
varline_search_dir = '';          % '' -> root_dir/all_condition_mode/Varline_figure_plot

% Drawing parameters (do not affect the analysis).
make_plots = true;
font_name = 'Arial';
font_size = 10;
figure_width = 1200;
figure_height = 900;
figure_visible = 'on';
area_colors = [0.0000 0.4470 0.7410; 0.8500 0.3250 0.0980];
point_size = 10;                   % scatter marker area, points^2
point_alpha = 0.50;
point_edge_color = 'none';         % 'none' or [r g b], e.g. [0 0 0]
point_edge_alpha = 0.50;
axis_color = [0 0 0];
axis_line_width = 1.0;
zero_line_color = [0.3 0.3 0.3];
zero_line_width = 1.0;
axis_padding = 0.06;               % full-data range padding; NEVER a cutoff
show_statistics = true;

% Saving: empty output_dir uses root_dir/all_condition_mode/program name.
output_dir = '';
save_mat = true;
save_png = true;
save_fig = false;
save_svg = false;
png_dpi = 300;
close_after_save = true;

%% ========================== CONFIGURATION =============================

setting_names = {'root_dir','data_content','runIdx','group_names', ...
    'component_pair','neuron_population','included_sessions','r2_value_mode', ...
    'reconstruction_suffix','gpl_mat_name','uncertainty_included','variance_unit', ...
    'correlation_method','significance_alpha','r2_mat_file', ...
    'varline_mean_count_mat_file','varline_none_mat_file','r2_search_dir', ...
    'varline_search_dir','make_plots','font_name','font_size','figure_width', ...
    'figure_height','figure_visible','area_colors','point_size','point_alpha', ...
    'point_edge_color','point_edge_alpha','axis_color','axis_line_width', ...
    'zero_line_color','zero_line_width','axis_padding','show_statistics', ...
    'output_dir','save_mat','save_png','save_fig','save_svg','png_dpi','close_after_save'};
cfg = struct();
for k = 1:numel(setting_names)
    cfg.(setting_names{k}) = eval(setting_names{k});
end
cfg = cdvValidateConfigLocal(cfg);
features = cdvFeaturesLocal();
metrics = cdvMetricsLocal();

fprintf('\nCompare saved delta R2 with saved Varline percentages\n');
fprintf('Data: %s | run: %d | %s | %s | R2: %s | u%d\n', ...
    cfg.data_content,cfg.runIdx,cfg.component_pair,cfg.neuron_population, ...
    cfg.r2_value_mode,cfg.uncertainty_included);
fprintf('Correlation: %s, two-sided nominal P; all finite pairs, no range cutoff.\n', ...
    cfg.correlation_method);

%% ========================= LOAD SAVED SUMMARIES ========================

[R,r2_input] = cdvLoadSummaryLocal('r2','',cfg);
[VN,normalized_input] = cdvLoadSummaryLocal('varline','mean_count',cfg);
[VU,unnormalized_input] = cdvLoadSummaryLocal('varline','none',cfg);
cdvRequireFieldsLocal(R,{'session_data','labels'},'R2 summary');
cdvRequireFieldsLocal(R.labels,{'source_r2_field_name'},'R2 source labels');
cdvRequireFieldsLocal(VN,{'sessions','feature'},'normalized Varline summary');
cdvRequireFieldsLocal(VU,{'sessions','feature'},'unnormalized Varline summary');

source_indices = cdvLabelIndicesLocal(cfg.source_fields, ...
    R.labels.source_r2_field_name,'R2 source fields');
n_source_fields = numel(R.labels.source_r2_field_name);
[session_map,session_report] = cdvMatchSessionsLocal(R,VN,VU,cfg);

DeltaR2VarComparison = struct();
DeltaR2VarComparison.format_version = 'compare_deltaR2_with_deltaVar_v1_1';
DeltaR2VarComparison.meta = struct( ...
    'created_by','compare_deltaR2_with_deltaVar.m', ...
    'created_on',datestr(now,30), ...
    'model_mode','all_condition','variance_source','posterior', ...
    'observation_unit','neuron', ...
    'x_definition','negative finite mean of four SAVED first-minus-second R2 differences', ...
    'y_definition','SAVED Varline percent_change or percent_difference_from_noise, unchanged', ...
    'matching_key','actual session name + model group + saved unit ID', ...
    'identity_pool','intersection of identities in all three inputs, then requested population', ...
    'finite_policy','independently per panel: finite X and finite Y', ...
    'p_adjustment','none (nominal, two-sided)', ...
    'session_cluster_adjustment','none', ...
    'range_filter','none; all finite points displayed and tested', ...
    'variance_unit','count');
DeltaR2VarComparison.settings = cfg;
DeltaR2VarComparison.inputs = struct('r2',r2_input, ...
    'mean_count',normalized_input,'none',unnormalized_input);
DeltaR2VarComparison.sessions = session_report;
DeltaR2VarComparison.features = features;
DeltaR2VarComparison.column_labels = { ...
    [cfg.group_names{1} ' ' cfg.component_labels{1}], ...
    [cfg.group_names{1} ' ' cfg.component_labels{2}], ...
    [cfg.group_names{2} ' ' cfg.component_labels{1}], ...
    [cfg.group_names{2} ' ' cfg.component_labels{2}]};

%% =========================== MATCH NEURONS ============================

base_panels = repmat(cdvEmptyBaseLocal(),3,4);
for f = 1:3
    NF = cdvGetFeatureLocal(VN,features(f),'normalized Varline');
    UF = cdvGetFeatureLocal(VU,features(f),'unnormalized Varline');
    for g = 1:2
        for c = 1:2
            col = (g-1)*2+c;
            base_panels(f,col) = cdvCollectLocal(R,VN,VU,NF,UF,session_map, ...
                features(f),g,c,source_indices(c),n_source_fields,cfg);
        end
    end
end

%% ======================= CORRELATION AND FIGURES ======================

DeltaR2VarComparison.metric = repmat(struct('name','','label','', ...
    'unit','','variance_normalization','','panels',[]),1,3);
for m = 1:3
    panel_cells = cell(3,4);
    for f = 1:3
        for col = 1:4
            B = base_panels(f,col);
            P = B;
            P.y = B.y_all(:,m);
            P = rmfield(P,'y_all');
            P.metric = metrics(m).name;
            P.valid_mask = isfinite(P.x) & isfinite(P.y);
            P.n_matched = numel(P.x);
            P.n_used = nnz(P.valid_mask);
            P.n_nonfinite = P.n_matched-P.n_used;
            P.statistics = cdvCorrelationsLocal( ...
                P.x(P.valid_mask),P.y(P.valid_mask),cfg);
            panel_cells{f,col} = P;
            cdvPrintPanelLocal(P,metrics(m).label);
        end
    end
    DeltaR2VarComparison.metric(m).name = metrics(m).name;
    DeltaR2VarComparison.metric(m).label = metrics(m).label;
    DeltaR2VarComparison.metric(m).unit = metrics(m).unit;
    DeltaR2VarComparison.metric(m).variance_normalization = metrics(m).normalization;
    DeltaR2VarComparison.metric(m).panels = reshape([panel_cells{:}],3,4);
end

base = cdvOutputBaseLocal(cfg,session_report.included);
DeltaR2VarComparison.output_base = base;
if cfg.save_mat || (cfg.make_plots && (cfg.save_png || cfg.save_fig || cfg.save_svg))
    if ~isfolder(cfg.output_dir)
        [ok,msg] = mkdir(cfg.output_dir);
        if ~ok, error('Cannot create output directory: %s',msg); end
    end
end
if cfg.save_mat
    mat_file = fullfile(cfg.output_dir,[base '.mat']);
    save(mat_file,'DeltaR2VarComparison','-v7.3');
    fprintf('\nSaved analysis MAT: %s\n',mat_file);
end
if cfg.make_plots
    for m = 1:3
        fig = cdvPlotLocal(DeltaR2VarComparison.metric(m),features,cfg);
        cdvSaveFigureLocal(fig,[base '_' metrics(m).file_tag],cfg);
    end
end
fprintf('\nDone: %d common sessions, 3 metrics x 12 panels.\n',numel(session_map));

%% =========================== LOCAL FUNCTIONS ==========================

function cfg = cdvValidateConfigLocal(cfg)
    text_fields = {'root_dir','data_content','reconstruction_suffix','gpl_mat_name', ...
        'r2_mat_file','varline_mean_count_mat_file','varline_none_mat_file', ...
        'r2_search_dir','varline_search_dir','output_dir','font_name'};
    for k = 1:numel(text_fields)
        cfg.(text_fields{k}) = char(cfg.(text_fields{k}));
    end
    options = {'component_pair',{'within_across','ff_fb'}; ...
        'neuron_population',{'all_neurons','pcu_neurons'}; ...
        'r2_value_mode',{'raw','zscore'}; 'variance_unit',{'count'}; ...
        'correlation_method',{'pearson','spearman','both'}; ...
        'figure_visible',{'on','off'}};
    for k = 1:size(options,1)
        field = options{k,1}; value = lower(strtrim(char(cfg.(field))));
        if ~ismember(value,options{k,2}), error('Invalid %s: %s',field,value); end
        cfg.(field) = value;
    end
    if strcmp(cfg.correlation_method,'both')
        cfg.correlation_methods = {'Pearson','Spearman'};
    else
        method = cfg.correlation_method; method(1) = upper(method(1));
        cfg.correlation_methods = {method};
    end
    cfg.group_names = cdvCellstrLocal(cfg.group_names);
    if numel(cfg.group_names)~=2 || numel(unique(cfg.group_names))~=2
        error('group_names must contain exactly two distinct model groups.');
    end
    cfg.included_sessions = cdvCellstrLocal(cfg.included_sessions);
    validateattributes(cfg.runIdx,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(cfg.uncertainty_included,{'numeric','logical'}, ...
        {'scalar','finite','>=',0,'<=',1});
    if ~ismember(cfg.uncertainty_included,[0 1]), error('uncertainty_included must be 0 or 1.'); end
    validateattributes(cfg.significance_alpha,{'numeric'},{'scalar','>',0,'<',1});
    for key = {'font_size','figure_width','figure_height','point_size', ...
            'axis_line_width','zero_line_width','png_dpi'}
        validateattributes(cfg.(key{1}),{'numeric'},{'scalar','positive','finite'});
    end
    for key = {'point_alpha','point_edge_alpha'}
        validateattributes(cfg.(key{1}),{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
    end
    validateattributes(cfg.axis_padding,{'numeric'},{'scalar','nonnegative','finite'});
    validateattributes(cfg.area_colors,{'numeric'},{'size',[2 3],'>=',0,'<=',1,'finite'});
    for key = {'axis_color','zero_line_color'}
        validateattributes(cfg.(key{1}),{'numeric'},{'size',[1 3],'>=',0,'<=',1,'finite'});
    end
    if isnumeric(cfg.point_edge_color)
        validateattributes(cfg.point_edge_color,{'numeric'},{'size',[1 3],'>=',0,'<=',1,'finite'});
    elseif ~strcmpi(char(cfg.point_edge_color),'none')
        error('point_edge_color must be ''none'' or an RGB triplet.');
    else
        cfg.point_edge_color = 'none';
    end
    for key = {'make_plots','show_statistics','save_mat','save_png','save_fig', ...
            'save_svg','close_after_save'}
        value = cfg.(key{1});
        if ~isscalar(value) || ~(islogical(value)||isnumeric(value)) || ~ismember(value,[0 1])
            error('%s must be true or false.',key{1});
        end
        cfg.(key{1}) = logical(value);
    end
    if isempty(cfg.r2_search_dir), cfg.r2_search_dir = cfg.root_dir; end
    if isempty(cfg.varline_search_dir)
        cfg.varline_search_dir = fullfile(cfg.root_dir,'all_condition_mode','Varline_figure_plot');
    end
    if isempty(cfg.output_dir)
        cfg.output_dir = fullfile(cfg.root_dir,'all_condition_mode','compare_deltaR2_with_deltaVar');
    end
    if strcmp(cfg.component_pair,'within_across')
        cfg.component_labels = {'Within','Across'};
        cfg.source_fields = {'use_within','use_across'};
    else
        cfg.component_labels = {'FF','FB'};
        cfg.source_fields = {'use_feedforward','use_feedback'};
    end
    cfg.model_mode = 'all_condition'; cfg.variance_source = 'posterior';
    cfg.summary_unit = 'neuron';
    if exist('corr','file')==0
        error('Correlation requires MATLAB Statistics and Machine Learning Toolbox (corr).');
    end
end

function F = cdvFeaturesLocal()
    F = struct('tag',{'LH','SL','GP'}, ...
        'r2_name',{'contrast_Low_minus_High','size_S_minus_L','stimtype_G_minus_P'}, ...
        'label',{'High - Low','Large - Small','Plaid - Grating'}, ...
        'first',{'Low','Small','Grating'},'second',{'High','Large','Plaid'}, ...
        'first_conditions',{[1 3 5 7],[1 2 5 6],[1 2 3 4]}, ...
        'second_conditions',{[2 4 6 8],[3 4 7 8],[5 6 7 8]});
end

function M = cdvMetricsLocal()
    M = struct('name',{'normalized_percent_change','normalized_percent_minus_noise', ...
        'unnormalized_percent_change'}, ...
        'label',{'Normalized variance change','Normalized change - Noise change', ...
        'Unnormalized variance change'}, ...
        'unit',{'%','pp','%'},'normalization',{'mean_count','mean_count','none'}, ...
        'file_tag',{'mc_pct','mc_ppNoise','raw_pct'});
end

function [value,info] = cdvLoadSummaryLocal(kind,normalization,cfg)
    if strcmp(kind,'r2')
        variable = 'MultiSessionGPLClassDeltaR2'; folder = cfg.r2_search_dir;
        explicit_file = cfg.r2_mat_file; setting = 'r2_mat_file'; label = 'R2';
    else
        variable = 'VarlineResults'; folder = cfg.varline_search_dir;
        if strcmp(normalization,'mean_count')
            explicit_file = cfg.varline_mean_count_mat_file;
            setting = 'varline_mean_count_mat_file';
        else
            explicit_file = cfg.varline_none_mat_file; setting = 'varline_none_mat_file';
        end
        label = ['Varline ' normalization];
    end
    explicit = ~isempty(explicit_file);
    if explicit
        if ~isfile(explicit_file), error('%s does not exist: %s',setting,explicit_file); end
        candidates = {explicit_file};
    else
        if ~isfolder(folder), error('%s search directory does not exist: %s',label,folder); end
        listing = dir(fullfile(folder,'*.mat'));
        candidates = arrayfun(@(d)fullfile(d.folder,d.name),listing,'UniformOutput',false);
    end
    best = Inf; matches = {}; reasons = {}; value = []; saved_population = '';
    for k = 1:numel(candidates)
        file = candidates{k};
        try
            contents = whos('-file',file);
            if ~any(strcmp({contents.name},variable))
                if explicit, error('MAT does not contain %s.',variable); end
                continue;
            end
            S = load(file,variable); V = S.(variable);
            [priority,population] = cdvCheckInputSettingsLocal(V,kind,normalization,cfg);
            if priority<best
                best = priority; matches = {file}; value = V;
                saved_population = population;
            elseif priority==best
                matches{end+1} = file; %#ok<AGROW>
            end
        catch ME
            reasons{end+1} = sprintf('%s\n    %s',file,ME.message); %#ok<AGROW>
            if explicit
                error('Invalid %s MAT:\n%s\n%s',label,file,ME.message);
            end
        end
    end
    if isempty(matches)
        if isempty(reasons), detail = ['No MAT containing ' variable ' was found.'];
        else, detail = strjoin(reasons,sprintf('\n')); end
        error('No matching %s result in %s.\n%s\nSet %s to a matching saved MAT.', ...
            label,folder,detail,setting);
    elseif numel(matches)>1
        [value,chosen] = cdvResolveEquivalentLocal( ...
            value,matches,variable,kind,cfg,label,setting);
    else
        chosen = 1;
    end
    info = struct('file',matches{chosen},'variable',variable, ...
        'saved_neuron_population',saved_population, ...
        'requested_neuron_population',cfg.neuron_population);
    info.equivalent_files = matches;
    info.selection_rule = 'Exact analysis-value equivalence after session/unit alignment; newest equivalent file';
    info.duplicate_check_performed = numel(matches)>1;
    info.saved_settings = value.settings;
    info.saved_meta = value.meta;
    fprintf('Loaded %s: %s\n',label,matches{chosen});
    if ~strcmp(saved_population,cfg.neuron_population)
        fprintf('  Saved population %s; using saved per-neuron values for %s.\n', ...
            saved_population,cfg.neuron_population);
    end
end

function [value,chosen] = cdvResolveEquivalentLocal(value,files,variable,kind,cfg,label,setting)
% Compare only inputs actually consumed by this analysis. Full-struct equality
% would incorrectly reject pct100, histMedian, layout, save-time and path edits.
% Exact numeric comparison is intentional: no tolerance hides data changes.
    fprintf('\nFound %d matching %s MATs; checking saved analysis data...\n',numel(files),label);
    reference = cdvAnalysisValuesLocal(value,kind,cfg);
    modified = zeros(1,numel(files));
    for k = 1:numel(files)
        listing = dir(files{k}); modified(k) = listing(1).datenum;
    end
    [~,chosen] = max(modified); % deterministic first candidate if times tie
    for k = 2:numel(files)
        S = load(files{k},variable); candidate = S.(variable);
        try
            compared = cdvAnalysisValuesLocal(candidate,kind,cfg);
        catch ME
            error(['Cannot verify duplicate %s MAT:\n%s\n%s\n', ...
                'Set %s to the intended valid result.'],label,files{k},ME.message,setting);
        end
        difference = cdvFirstDifferenceLocal(reference,compared,'analysis');
        if ~isempty(difference)
            error(['Matching %s MATs contain different analysis data.\n', ...
                'Reference: %s\nCompared:  %s\nFirst difference: %s\n', ...
                'Candidates:\n%s\nSet %s to one exact path. No data were combined.'], ...
                label,files{1},files{k},difference,strjoin(files,sprintf('\n')),setting);
        end
        if k==chosen, value = candidate; end
    end
    fprintf('  All %d MATs have identical analysis values and neuron identities.\n',numel(files));
    fprintf('  Using newest equivalent file: %s\n',files{chosen});
    fprintf('  Display differences are ignored; all equivalent paths are saved in output inputs.\n');
end

function C = cdvAnalysisValuesLocal(V,kind,cfg)
% Canonical representation: feature order fixed, sessions sorted by actual
% name, neurons sorted by saved ID. Saved array/session order is not identity.
% This performs comparisons only; no R2, variance or percentage is recomputed.
    F = cdvFeaturesLocal();
    C = struct(); C.kind = kind;
    if strcmp(kind,'r2')
        records = V.session_data;
    else
        records = V.sessions;
    end
    original_keys = cdvSessionKeysLocal(records);
    [keys,order] = sort(original_keys);
    C.session_names = keys;
    sessions = cell(1,numel(keys));
    if strcmp(kind,'r2')
        source_indices = cdvLabelIndicesLocal(cfg.source_fields, ...
            V.labels.source_r2_field_name,'R2 source fields');
        n_sources = numel(V.labels.source_r2_field_name);
        if strcmp(cfg.r2_value_mode,'raw'), delta_field = 'raw_delta_array';
        else, delta_field = 'z_delta_array'; end
    end
    for s = 1:numel(keys)
        R = records(order(s));
        cdvRequireFieldsLocal(R,{'group'},'duplicate session');
        if numel(R.group)~=2, error('%s: unexpected group count.',keys{s}); end
        E = struct('name',keys{s});
        if strcmp(kind,'varline')
            cdvRequireFieldsLocal(R,{'condition_ids','direction_values','bin_size_seconds'},'Varline session');
            E.condition_ids = double(R.condition_ids);
            E.direction_values = double(R.direction_values(:)');
            E.bin_size_seconds = double(R.bin_size_seconds);
        end
        groups = cell(1,2);
        for g = 1:2
            G = R.group(g); ids = cdvIdsLocal(G.unit_ids,'duplicate neuron IDs');
            [ids,unit_order] = sort(ids);
            Q = struct('area',cfg.group_names{g},'unit_id',ids);
            if strcmp(kind,'r2')
                cdvExpectTextLocal(G.group_name,cfg.group_names{g},'R2 group name');
                if G.group_index~=g, error('R2 group index mismatch.'); end
                codes = cdvClassCodesLocal(G.class_info,numel(ids));
                Q.class_code = codes(unit_order);
                effects = cell(1,numel(F));
                for f = 1:numel(F)
                    cdvRequireFieldsLocal(G.feature_delta,{F(f).r2_name},'R2 feature deltas');
                    D = G.feature_delta.(F(f).r2_name);
                    cdvRequireFieldsLocal(D,{delta_field,'positive_stim','negative_stim'},'R2 difference');
                    X = double(D.(delta_field));
                    cdvSizeLocal(X,[numel(ids) n_sources 4],'R2 duplicate differences');
                    effects{f} = struct('tag',F(f).tag, ...
                        'positive_stim',{cdvCellstrLocal(D.positive_stim)}, ...
                        'negative_stim',{cdvCellstrLocal(D.negative_stim)}, ...
                        'matched_delta',X(unit_order,source_indices,:));
                end
                Q.effect = [effects{:}];
            else
                cdvExpectTextLocal(G.name,cfg.group_names{g},'Varline group name');
            end
            groups{g} = Q;
        end
        E.group = [groups{:}]; sessions{s} = E;
    end
    C.sessions = [sessions{:}];
    if strcmp(kind,'varline')
        feature_values = cell(1,numel(F));
        % original session index -> canonical (name-sorted) session index
        canonical_session = zeros(numel(keys),1);
        canonical_session(order) = (1:numel(keys))';
        for f = 1:numel(F)
            source = cdvGetFeatureLocal(V,F(f),'Varline duplicate');
            areas = cell(1,2);
            for g = 1:2
                A = source.area(g);
                cdvValidateVarlineAreaLocal(A,V,g,cfg);
                si = canonical_session(double(A.session_index(:)));
                ids = double(A.unit_id(:));
                [~,row_order] = sortrows([si ids],[1 2]);
                Q = struct('area',cfg.group_names{g}, ...
                    'session_index',si(row_order),'unit_id',ids(row_order), ...
                    'percent_change',double(A.percent_change(row_order,:)), ...
                    'percent_difference_from_noise',double(A.percent_difference_from_noise(row_order,:)));
                if strcmp(V.settings.neuron_population,'pcu_neurons')
                    codes = double(A.class_code(:)); Q.class_code = codes(row_order);
                end
                areas{g} = Q;
            end
            feature_values{f} = struct('tag',F(f).tag,'area',[areas{:}]);
        end
        C.feature = [feature_values{:}];
    end
end

function detail = cdvFirstDifferenceLocal(A,B,path)
% Find a useful difference to report instead of only listing ambiguous paths.
    detail = '';
    if isequaln(A,B), return; end
    if ~isequal(size(A),size(B))
        detail = sprintf('%s: size %s versus %s',path,mat2str(size(A)),mat2str(size(B)));
    elseif isstruct(A) && isstruct(B)
        fields = fieldnames(A);
        if ~isequal(fields,fieldnames(B))
            detail = sprintf('%s: saved field sets differ',path); return;
        end
        for k = 1:numel(A)
            for f = 1:numel(fields)
                name = fields{f};
                detail = cdvFirstDifferenceLocal(A(k).(name),B(k).(name), ...
                    sprintf('%s(%d).%s',path,k,name));
                if ~isempty(detail), return; end
            end
        end
    elseif iscell(A) && iscell(B)
        for k = 1:numel(A)
            detail = cdvFirstDifferenceLocal(A{k},B{k},sprintf('%s{%d}',path,k));
            if ~isempty(detail), return; end
        end
    elseif isnumeric(A) && isnumeric(B)
        equal = (A==B) | (isnan(A)&isnan(B));
        index = find(~equal,1);
        if isempty(index)
            detail = sprintf('%s: numeric representation differs',path);
        else
            detail = sprintf('%s: element %d, %.17g versus %.17g',path,index,A(index),B(index));
        end
    elseif ischar(A) && ischar(B)
        detail = sprintf('%s: ''%s'' versus ''%s''',path,A,B);
    else
        detail = sprintf('%s: values differ',path);
    end
end

function [priority,population] = cdvCheckInputSettingsLocal(V,kind,normalization,cfg)
    cdvRequireFieldsLocal(V,{'meta','settings'},'summary MAT');
    if strcmp(kind,'r2')
        S = V.meta;
        cdvRequireFieldsLocal(S,{'format_version','data_content','runIdx','model_mode', ...
            'neuron_population','r2_split_mode','reconstruction_suffix','gpl_mat_name'},'R2 metadata');
        if ~strcmp(S.format_version,'GPL_class_deltaR2_poster_v6')
            error('Require the supplied GPL_class_deltaR2 poster_v6 summary.');
        end
        cdvExpectTextLocal(S.model_mode,'all_condition_model','R2 model_mode');
        cdvExpectTextLocal(S.r2_split_mode,'by_three_features','R2 split mode');
        cdvExpectTextLocal(S.reconstruction_suffix,cfg.reconstruction_suffix,'R2 reconstruction_suffix');
        cdvExpectTextLocal(S.gpl_mat_name,cfg.gpl_mat_name,'R2 gpl_mat_name');
        cdvRequireFieldsLocal(V,{'labels','session_data'},'R2 summary');
        cdvRequireFieldsLocal(V.labels,{'group_name'},'R2 labels');
        names = cdvCellstrLocal(V.labels.group_name);
    else
        cdvRequireFieldsLocal(V,{'format_version'},'Varline summary');
        cdvExpectTextLocal(V.format_version,'varline_posterior_v2','Varline format');
        S = V.settings;
        cdvRequireFieldsLocal(S,{'data_content','runIdx','neuron_population','group_names', ...
            'summary_unit','component_pair','component_labels','variance_normalization', ...
            'variance_unit','uncertainty_included','gpl_mat_name'},'Varline settings');
        cdvRequireFieldsLocal(V.meta,{'model_mode','variance_source','observation_unit', ...
            'uncertainty_included','noise_definition'},'Varline metadata');
        cdvExpectTextLocal(V.meta.model_mode,'all_condition','Varline model_mode');
        cdvExpectTextLocal(V.meta.variance_source,'posterior','Varline variance_source');
        cdvExpectTextLocal(S.summary_unit,'neuron','Varline summary_unit');
        cdvExpectTextLocal(V.meta.observation_unit,'neuron','Varline observation_unit');
        cdvExpectTextLocal(V.meta.noise_definition,'posterior_residual_y_minus_all','Noise definition');
        cdvExpectTextLocal(S.component_pair,cfg.component_pair,'Varline component_pair');
        cdvExpectTextLocal(S.variance_normalization,normalization,'Varline normalization');
        cdvExpectTextLocal(S.variance_unit,cfg.variance_unit,'Varline unit');
        if ~isequal(double(S.uncertainty_included),double(cfg.uncertainty_included)) || ...
                ~isequal(double(V.meta.uncertainty_included),double(cfg.uncertainty_included))
            error('Varline uncertainty_included does not match requested u%d.',cfg.uncertainty_included);
        end
        if ~isequal(cdvCellstrLocal(S.component_labels),[cfg.component_labels {'Noise'}])
            error('Varline saved component labels/order disagree with component_pair.');
        end
        if strcmp(S.neuron_population,'pcu_neurons')
            cdvExpectTextLocal(S.gpl_mat_name,cfg.gpl_mat_name,'Varline gpl_mat_name');
        end
        names = cdvCellstrLocal(S.group_names);
    end
    cdvExpectTextLocal(S.data_content,cfg.data_content,'data_content');
    if ~isequal(double(S.runIdx),double(cfg.runIdx)), error('runIdx does not match.'); end
    if ~isequal(names,cfg.group_names), error('Group names/order do not match requested model groups.'); end
    population = char(S.neuron_population);
    if ~ismember(population,{'all_neurons','pcu_neurons'}), error('Unknown saved neuron_population.'); end
    priority = double(~strcmp(population,cfg.neuron_population));
    if strcmp(kind,'varline') && strcmp(cfg.neuron_population,'all_neurons') && priority
        error('PCU Varline summaries do not contain saved percentages for all neurons.');
    end
    if strcmp(kind,'r2') && strcmp(cfg.r2_value_mode,'zscore') && priority
        error('Z-scored R2 requires a MAT saved with neuron_population=''%s''.',cfg.neuron_population);
    end
end

function [map,report] = cdvMatchSessionsLocal(R,VN,VU,cfg)
    rk = cdvSessionKeysLocal(R.session_data);
    nk = cdvSessionKeysLocal(VN.sessions); uk = cdvSessionKeysLocal(VU.sessions);
    common = rk(ismember(rk,nk) & ismember(rk,uk));
    requested = cellfun(@cdvSessionKeyLocal,cfg.included_sessions,'UniformOutput',false);
    if numel(unique(requested))~=numel(requested), error('Duplicate included_sessions entries.'); end
    if ~isempty(requested)
        missing = requested(~ismember(requested,common));
        if ~isempty(missing)
            error('Requested sessions missing from one or more summaries: %s',strjoin(missing,', '));
        end
        common = common(ismember(common,requested));
    end
    if isempty(common), error('No common selected sessions in the three input MATs.'); end
    map = repmat(struct('name','','r2_index',0,'normalized_index',0,'raw_index',0),numel(common),1);
    for s = 1:numel(common)
        map(s).name = common{s};
        map(s).r2_index = find(strcmp(rk,common{s}));
        map(s).normalized_index = find(strcmp(nk,common{s}));
        map(s).raw_index = find(strcmp(uk,common{s}));
        n = VN.sessions(map(s).normalized_index); u = VU.sessions(map(s).raw_index);
        cdvRequireFieldsLocal(n,{'direction_values','condition_ids','bin_size_seconds'},'Varline session');
        cdvRequireFieldsLocal(u,{'direction_values','condition_ids','bin_size_seconds'},'Varline session');
        if ~isequaln(n.direction_values,u.direction_values) || ~isequaln(n.condition_ids,u.condition_ids) || ...
                ~isequaln(n.bin_size_seconds,u.bin_size_seconds)
            error('%s: normalized/raw Varline condition mapping, directions or bin width differ.',common{s});
        end
    end
    report = struct('included',{common},'mapping',map, ...
        'r2_not_used',{rk(~ismember(rk,common))}, ...
        'normalized_not_used',{nk(~ismember(nk,common))}, ...
        'unnormalized_not_used',{uk(~ismember(uk,common))});
    fprintf('\nCommon selected sessions (%d): %s\n',numel(common),strjoin(common,', '));
    for pair = {'r2_not_used','normalized_not_used','unnormalized_not_used'}
        unused = report.(pair{1});
        if ~isempty(unused), fprintf('  %s: %s\n',pair{1},strjoin(unused,', ')); end
    end
end

function keys = cdvSessionKeysLocal(records)
    if ~isstruct(records) || isempty(records), error('No saved session records.'); end
    keys = cell(1,numel(records));
    for s = 1:numel(records)
        if isfield(records,'run_g') && ~isempty(records(s).run_g)
            keys{s} = cdvSessionKeyLocal(records(s).run_g);
            if isfield(records,'session_dir') && ...
                    ~strcmp(keys{s},cdvSessionKeyLocal(records(s).session_dir))
                error('Saved run_g and session_dir identify different sessions.');
            end
        else
            cdvRequireFieldsLocal(records(s),{'session_dir'},'session record');
            keys{s} = cdvSessionKeyLocal(records(s).session_dir);
        end
    end
    if numel(unique(keys))~=numel(keys), error('Duplicate actual session names in a saved summary.'); end
end

function key = cdvSessionKeyLocal(value)
    value = strrep(strtrim(char(value)),char(92),'/');
    value = regexprep(value,'/+$','');
    parts = strsplit(value,'/'); key = parts{end};
    if strncmp(key,'catgt_',6), key = key(7:end); end
    if isempty(key), error('Empty session identity.'); end
end

function A = cdvGetFeatureLocal(V,F,label)
    cdvRequireFieldsLocal(V.feature,{'tag','endpoint_labels','first_conditions', ...
        'second_conditions','area'},[label ' feature']);
    index = find(strcmp({V.feature.tag},F.tag));
    if numel(index)~=1, error('%s needs exactly one %s feature.',label,F.tag); end
    A = V.feature(index);
    if ~isequal(cdvCellstrLocal(A.endpoint_labels),{F.first,F.second}) || ...
            ~isequal(double(A.first_conditions(:)'),F.first_conditions) || ...
            ~isequal(double(A.second_conditions(:)'),F.second_conditions) || numel(A.area)~=2
        error('%s: feature %s endpoints/condition mapping are incompatible.',label,F.tag);
    end
end

function B = cdvEmptyBaseLocal()
    B = struct('feature_tag','','feature_label','','area','','group_index',[], ...
        'component','','source_field','','session_name',{{}},'unit_id',zeros(0,1), ...
        'model_local_id',zeros(0,1),'class_code',zeros(0,1), ...
        'x',zeros(0,1),'y_all',zeros(0,3),'r2_first_minus_second',zeros(0,1), ...
        'r2_n_finite_matches',zeros(0,1),'alignment',struct([]));
end

function B = cdvCollectLocal(R,VN,VU,NF,UF,map,F,g,c,source_index,n_sources,cfg)
    B = cdvEmptyBaseLocal();
    B.feature_tag = F.tag; B.feature_label = F.label;
    B.area = cfg.group_names{g}; B.group_index = g;
    B.component = cfg.component_labels{c}; B.source_field = cfg.source_fields{c};
    N = NF.area(g); U = UF.area(g);
    cdvValidateVarlineAreaLocal(N,VN,g,cfg);
    cdvValidateVarlineAreaLocal(U,VU,g,cfg);
    if strcmp(cfg.r2_value_mode,'raw'), delta_field = 'raw_delta_array';
    else, delta_field = 'z_delta_array'; end
    for s = 1:numel(map)
        sm = map(s); rec = R.session_data(sm.r2_index);
        cdvRequireFieldsLocal(rec,{'group'},'R2 session');
        if numel(rec.group)~=2, error('%s: unexpected R2 group count.',sm.name); end
        G = rec.group(g);
        cdvRequireFieldsLocal(G,{'group_index','group_name','unit_ids','class_info','feature_delta'},'R2 group');
        if G.group_index~=g || ~strcmp(G.group_name,cfg.group_names{g})
            error('%s: R2 group mapping disagrees with requested area.',sm.name);
        end
        ids = cdvIdsLocal(G.unit_ids,'R2 neuron IDs'); n = numel(ids);
        class_code = cdvClassCodesLocal(G.class_info,n);
        cdvRequireFieldsLocal(G.feature_delta,{F.r2_name},'R2 feature deltas');
        D = G.feature_delta.(F.r2_name);
        cdvRequireFieldsLocal(D,{delta_field,'positive_stim','negative_stim'},'saved R2 difference');
        labels = {'G_S_L','G_S_H','G_L_L','G_L_H','P_S_L','P_S_H','P_L_L','P_L_H'};
        if ~isequal(cdvCellstrLocal(D.positive_stim),labels(F.first_conditions)) || ...
                ~isequal(cdvCellstrLocal(D.negative_stim),labels(F.second_conditions))
            error('%s: saved R2 %s subtraction direction/matches differ.',sm.name,F.tag);
        end
        deltas = double(D.(delta_field));
        cdvSizeLocal(deltas,[n n_sources 4],'saved R2 matched differences');
        d = reshape(deltas(:,source_index,:),n,4);
        [r2mean,nfinite] = cdvFiniteMeanLocal(d);

        nr = find(N.session_index(:)==sm.normalized_index);
        ur = find(U.session_index(:)==sm.raw_index);
        nid = double(N.unit_id(nr)); nid = nid(:);
        uid = double(U.unit_id(ur)); uid = uid(:);
        [has_n,ni] = ismember(ids,nid); [has_u,ui] = ismember(ids,uid);
        selected = true(n,1);
        if strcmp(cfg.neuron_population,'pcu_neurons'), selected = class_code<=3; end
        keep = selected & has_n & has_u;
        ii = find(keep); nn = nr(ni(keep)); uu = ur(ui(keep));
        cdvCheckSavedClassesLocal(N,nn,class_code(keep),VN.settings.neuron_population,sm.name);
        cdvCheckSavedClassesLocal(U,uu,class_code(keep),VU.settings.neuron_population,sm.name);
        report = struct('session',sm.name,'r2_total',n,'r2_selected',nnz(selected), ...
            'normalized_observations',numel(nr),'raw_observations',numel(ur), ...
            'matched_selected',nnz(keep), ...
            'selected_ids_missing_normalized',ids(selected & ~has_n), ...
            'selected_ids_missing_raw',ids(selected & ~has_u), ...
            'normalized_ids_without_r2',nid(~ismember(nid,ids)), ...
            'raw_ids_without_r2',uid(~ismember(uid,ids)));
        if isempty(B.alignment), B.alignment = report;
        else, B.alignment(end+1) = report; end %#ok<AGROW>
        if nnz(keep)~=nnz(selected) || ~isempty(report.normalized_ids_without_r2) || ...
                ~isempty(report.raw_ids_without_r2)
            fprintf('  Match %s %s %s %s: %d/%d selected R2 neurons; unmatched IDs saved.\n', ...
                sm.name,B.area,F.tag,B.component,nnz(keep),nnz(selected));
        end
        B.session_name = [B.session_name;repmat({sm.name},numel(ii),1)]; %#ok<AGROW>
        B.unit_id = [B.unit_id;ids(keep)]; %#ok<AGROW>
        B.model_local_id = [B.model_local_id;ii]; %#ok<AGROW>
        B.class_code = [B.class_code;class_code(keep)]; %#ok<AGROW>
        B.r2_first_minus_second = [B.r2_first_minus_second;r2mean(keep)]; %#ok<AGROW>
        B.r2_n_finite_matches = [B.r2_n_finite_matches;nfinite(keep)]; %#ok<AGROW>
        B.x = [B.x;-r2mean(keep)]; %#ok<AGROW>
        % Read precomputed percentages verbatim. In particular, do NOT compute
        % percentages of averages here or average percentage changes again.
        B.y_all = [B.y_all;double(N.percent_change(nn,c)), ...
            double(N.percent_difference_from_noise(nn,c)), ...
            double(U.percent_change(uu,c))]; %#ok<AGROW>
    end
    B.session_name = B.session_name(:);
end

function cdvValidateVarlineAreaLocal(A,V,g,cfg)
    cdvRequireFieldsLocal(A,{'name','session_index','unit_id','unit_row_index', ...
        'percent_change','percent_difference_from_noise','class_code'},'Varline area');
    cdvExpectTextLocal(A.name,cfg.group_names{g},'Varline area name');
    n = numel(A.unit_id);
    cdvSizeLocal(A.percent_change,[n 3],'saved percent_change');
    cdvSizeLocal(A.percent_difference_from_noise,[n 2],'saved percent_difference_from_noise');
    for key = {'session_index','unit_row_index','class_code'}
        v = A.(key{1});
        if ~isnumeric(v) || numel(v)~=n || any(~isfinite(v(:)))
            error('Invalid Varline %s.',key{1});
        end
    end
    si = double(A.session_index(:));
    if any(si<1 | si>numel(V.sessions) | si~=fix(si)), error('Invalid saved Varline session indices.'); end
    for s = unique(si)'
        rows = find(si==s); ids = cdvIdsLocal(A.unit_id(rows),'Varline neuron IDs');
        G = V.sessions(s).group(g);
        cdvRequireFieldsLocal(G,{'name','unit_ids'},'Varline session group');
        cdvExpectTextLocal(G.name,cfg.group_names{g},'Varline session group name');
        all_ids = cdvIdsLocal(G.unit_ids,'Varline model IDs');
        order = double(A.unit_row_index(rows)); order = order(:);
        if any(order<1 | order>numel(all_ids) | order~=fix(order)) || ...
                ~isequal(all_ids(order),ids)
            error('Saved Varline row indices do not identify the corresponding unit IDs.');
        end
    end
end

function codes = cdvClassCodesLocal(C,n)
    names = {'pattern','component','unclassified','invalid'};
    cdvRequireFieldsLocal(C,names,'saved R2 classifications');
    masks = false(n,4);
    for k = 1:4
        m = C.(names{k});
        if numel(m)~=n || any(~ismember(m(:),[0 1])), error('Invalid saved GPL class mask.'); end
        masks(:,k) = logical(m(:));
    end
    if any(sum(masks,2)~=1), error('Saved GPL classes must be exclusive and exhaustive.'); end
    codes = double(masks)*(1:4)';
end

function cdvCheckSavedClassesLocal(A,rows,codes,population,session)
    if strcmp(population,'pcu_neurons')
        saved = double(A.class_code(rows)); saved = saved(:);
        if any(saved~=codes) || any(saved<1 | saved>3)
            error('%s: saved PCU classifications differ between R2 and Varline.',session);
        end
    end
end

function [y,n] = cdvFiniteMeanLocal(X)
    good = isfinite(X); n = sum(good,2); X(~good) = 0;
    y = sum(X,2)./n; y(n==0) = NaN;
end

function S = cdvCorrelationsLocal(x,y,cfg)
    template = struct('method','','coefficient',NaN,'p_value',NaN, ...
        'n',numel(x),'significant',false,'status','');
    S = repmat(template,1,numel(cfg.correlation_methods));
    for k = 1:numel(S)
        S(k).method = cfg.correlation_methods{k};
        if numel(x)<3
            S(k).status = 'fewer_than_3_finite_pairs';
        elseif all(x==x(1)) || all(y==y(1))
            S(k).status = 'constant_axis';
        else
            [r,p] = corr(x,y,'Type',S(k).method,'Rows','complete','Tail','both');
            S(k).coefficient = r; S(k).p_value = p;
            S(k).significant = isfinite(p) && p<cfg.significance_alpha;
            S(k).status = 'ok';
        end
    end
end

function cdvPrintPanelLocal(P,metric)
    fprintf('%s | %s | %s %s | n=%d/%d',metric,P.feature_label,P.area,P.component,P.n_used,P.n_matched);
    for k = 1:numel(P.statistics)
        S = P.statistics(k);
        fprintf(' | %s: r=%.4g, P=%.4g',S.method,S.coefficient,S.p_value);
        if ~strcmp(S.status,'ok'), fprintf(' (%s)',S.status); end
    end
    fprintf('\n');
end

function fig = cdvPlotLocal(M,features,cfg)
    fig = figure('Color','w','Name',M.label,'NumberTitle','off', ...
        'Visible',cfg.figure_visible,'Units','pixels', ...
        'Position',[40 40 cfg.figure_width cfg.figure_height]);
    tiledlayout(fig,3,4,'TileSpacing','loose','Padding','loose');
    for f = 1:3
        for col = 1:4
            P = M.panels(f,col); ax = nexttile((f-1)*4+col);
            hold(ax,'on'); color = cfg.area_colors(P.group_index,:);
            x = P.x(P.valid_mask); y = P.y(P.valid_mask);
            xl = cdvLimitsLocal(x,cfg.axis_padding); yl = cdvLimitsLocal(y,cfg.axis_padding);
            plot(ax,xl,[0 0],'--','Color',cfg.zero_line_color, ...
                'LineWidth',cfg.zero_line_width,'HandleVisibility','off');
            plot(ax,[0 0],yl,'--','Color',cfg.zero_line_color, ...
                'LineWidth',cfg.zero_line_width,'HandleVisibility','off');
            if ~isempty(x)
                scatter(ax,x,y,cfg.point_size,'filled','MarkerFaceColor',color, ...
                    'MarkerFaceAlpha',cfg.point_alpha,'MarkerEdgeColor',cfg.point_edge_color, ...
                    'MarkerEdgeAlpha',cfg.point_edge_alpha);
            end
            set(ax,'XLim',xl,'YLim',yl,'FontName',cfg.font_name,'FontSize',cfg.font_size, ...
                'TickDir','out','Box','off','XColor',cfg.axis_color,'YColor',cfg.axis_color, ...
                'LineWidth',cfg.axis_line_width,'TickLabelInterpreter','tex', ...
                'TitleFontSizeMultiplier',1,'LabelFontSizeMultiplier',1);
            grid(ax,'off');
            title_lines = {[P.area ' ' P.component]};
            if cfg.show_statistics
                for k = 1:numel(P.statistics)
                    S = P.statistics(k);
                    if strcmp(S.method,'Spearman'), coefficient_label = '\rho';
                    else, coefficient_label = 'r'; end
                    title_lines{end+1} = sprintf('%s = %.3g, {\\bf P} = %s', ...
                        coefficient_label,S.coefficient,cdvPTextLocal(S.p_value)); %#ok<AGROW>
                end
                title_lines{end+1} = sprintf('n = %d',P.n_used); %#ok<AGROW>
            end
            title(ax,title_lines,'Interpreter','tex','FontWeight','normal');
            if strcmp(cfg.r2_value_mode,'raw'), x_label = '\Delta R^2';
            else, x_label = '\Delta Z(R^2)'; end
            xlabel(ax,{x_label,features(f).label},'Interpreter','tex');
            if strcmp(M.name,'normalized_percent_minus_noise')
                y_label = {'Normalized change','- Noise change (pp)'};
            elseif strcmp(M.name,'normalized_percent_change')
                y_label = {'Normalized variance','change (%)'};
            else
                y_label = {'Unnormalized variance','change (%)'};
            end
            if col==1, ylabel(ax,y_label,'Interpreter','none'); end
            ax.UserData = struct('metric',M.name,'feature',P.feature_tag, ...
                'area',P.area,'component',P.component,'n',P.n_used,'statistics',P.statistics);
        end
    end
    drawnow;
end

function lim = cdvLimitsLocal(x,padding)
    if isempty(x), lim = [-1 1]; return; end
    lo = min([0;x(:)]); hi = max([0;x(:)]);
    span = hi-lo;
    if span==0, lim = [-1 1]; return; end
    % Pad the complete data range, including zero; do not trim either tail.
    margin = max(padding,0.01)*span;
    lim = [lo-margin hi+margin];
    if any(~isfinite(lim))
        error('Finite data exceed representable axis padding; inspect saved values.');
    end
end

function text_value = cdvPTextLocal(p)
    if ~isfinite(p), text_value = 'NaN';
    elseif p==0, text_value = '0';
    elseif p<0.001, text_value = sprintf('%.2e',p);
    else, text_value = sprintf('%.3f',p); end
end

function base = cdvOutputBaseLocal(cfg,sessions)
    if strcmp(cfg.data_content,'demean_count_within_t_and_condition'), content = 'dmTC';
    else
        content = regexprep(cfg.data_content,'[^A-Za-z0-9_]','_');
        if numel(content)>12, content = [content(1:8) '_' cdvHashLocal(cfg.data_content)]; end
    end
    if strcmp(cfg.component_pair,'within_across'), pair = 'WA'; else, pair = 'FFFB'; end
    if strcmp(cfg.neuron_population,'all_neurons'), pop = 'allN'; else, pop = 'pcuN'; end
    if strcmp(cfg.correlation_method,'pearson'), method = 'Pear';
    elseif strcmp(cfg.correlation_method,'spearman'), method = 'Spear'; else, method = 'Both'; end
    identity = strjoin([sessions {cfg.reconstruction_suffix,cfg.gpl_mat_name}],';');
    base = sprintf('cmpR2Var_%s_r%03d_%s_%s_%s_u%d_%s_%s',content,cfg.runIdx, ...
        pair,pop,cfg.r2_value_mode,cfg.uncertainty_included,method,cdvHashLocal(identity));
end

function value = cdvHashLocal(text_value)
    bytes = double(unicode2native(char(text_value),'UTF-8'));
    h = 0;
    for k = 1:numel(bytes), h = mod(h*131+bytes(k),4294967291); end
    value = lower(dec2hex(h,8));
end

function cdvSaveFigureLocal(fig,base,cfg)
    flags = [cfg.save_png cfg.save_fig cfg.save_svg];
    extensions = {'.png','.fig','.svg'};
    for k = find(flags)
        target = fullfile(cfg.output_dir,[base extensions{k}]);
        % Short temp paths avoid MATLAB renderer problems with long Windows paths.
        temporary = [tempname extensions{k}];
        cleanup = onCleanup(@()cdvRemoveLocal(temporary));
        switch extensions{k}
            case '.png'
                exportgraphics(fig,temporary,'Resolution',cfg.png_dpi,'BackgroundColor','white');
            case '.fig'
                savefig(fig,temporary);
            case '.svg'
                print(fig,temporary,'-dsvg','-painters');
        end
        listing = dir(temporary);
        if isempty(listing) || listing.bytes==0, error('Figure export produced no data: %s',target); end
        [ok,msg] = copyfile(temporary,target,'f');
        if ~ok, error('Could not save figure %s: %s',target,msg); end
        clear cleanup;
        fprintf('Saved figure: %s\n',target);
    end
    if cfg.close_after_save, close(fig); end
end

function cdvRemoveLocal(file)
    if isfile(file), delete(file); end
end

function cdvRequireFieldsLocal(S,fields,label)
    if ~isstruct(S) || isempty(S), error('%s must be a nonempty struct.',label); end
    for k = 1:numel(fields)
        if ~isfield(S,fields{k}), error('%s lacks %s.',label,fields{k}); end
    end
end

function cdvExpectTextLocal(actual,expected,label)
    if ~strcmp(char(actual),char(expected))
        error('%s is ''%s''; requested ''%s''.',label,char(actual),char(expected));
    end
end

function values = cdvCellstrLocal(value)
    if isempty(value), values = {};
    elseif ischar(value), values = {value};
    elseif isstring(value), values = cellstr(value(:)');
    elseif iscell(value), values = cellfun(@char,value(:)','UniformOutput',false);
    else, error('Expected text or a cell array of text.'); end
    values = reshape(values,1,[]);
end

function index = cdvLabelIndicesLocal(expected,actual,label)
    actual = cdvCellstrLocal(actual);
    if numel(unique(actual))~=numel(actual), error('Duplicate %s.',label); end
    [ok,index] = ismember(expected,actual);
    if ~all(ok), error('Required labels missing from %s.',label); end
end

function ids = cdvIdsLocal(value,label)
    if ~isnumeric(value) || ~isreal(value), error('%s must be real numeric IDs.',label); end
    ids = double(value(:));
    if any(~isfinite(ids)) || numel(unique(ids))~=numel(ids)
        error('%s contain nonfinite or duplicate identities.',label);
    end
end

function cdvSizeLocal(value,expected,label)
    actual = size(value); n = max(numel(actual),numel(expected));
    actual(end+1:n) = 1; expected(end+1:n) = 1;
    if ~isnumeric(value) || ~isreal(value) || ~isequal(actual,expected)
        error('%s has size %s; expected %s.',label,mat2str(size(value)),mat2str(expected));
    end
end
