%% GPL_class_deltaVar_figure_plot.m
% Standalone plotting/statistics script; no workspace variables are needed.
%
% INPUTS: saved across-session summaries, NOT models or reconstructions.
%   1. sum_sessions_latent_compare_var.m -> MultiSessionSummary
%      Run with metric_name='rawvariance', condition_display_mode='pooled',
%      save_mat=true. Its pooled population includes ALL MODEL NEURONS,
%      including neurons with invalid/missing GPL labels.
%   2. GPL_class_rawvar.m -> MultiSessionRawVar, save_mat=true.
%      Either condition_display_mode works: both representations are saved.
%      This supplies P/C/U class balances and optional class-specific effects.
% Default input folder: root_dir/<model_mode>_mode.
%
% One dot and one statistical observation = ONE SESSION x ONE DIRECTION.
% Directions remain separate. Neurons and the four condition matches are
% averaged WITHIN an observation; neither is treated as a replicate here.
%
% FEATURE EFFECTS (raw variance per neuron):
%   G-P, Small-Large, Low-High. Hold the other two features fixed, subtract
%   the four corresponding condition pairs, then equally average the four
%   differences within each session-direction. All four must be finite.
%   pooled: use the saved all-neuron mean, sum(neuron variances)/N_model.
%           Do not equally average P/C/U class means; that would also omit
%           neurons without a valid GPL class.
%   separate: do the same calculation separately in P, C and U.
%   Each effect has a Within/Across figure and an FF/FB figure; areas are
%   adjacent and color-coded, as in GPL_class_deltaR2_figure_plot.m.
%
% BALANCES: use the saved mean over all EIGHT conditions within a direction:
%   Across-Within and Feedforward-Feedback, separately for each area/class.
%   There are two balance figures per area; x-axis categories are P/C/U.
%   Missing classes remain NaN; a present class with no latents has var=0.
%
% STATISTICS (MATLAB Statistics and Machine Learning Toolbox):
%   - Each distribution vs 0: TWO-SIDED Wilcoxon signed-rank (signrank).
%   - Three classes: Friedman, rows=session-direction, columns=P/C/U.
%     Use complete rows for this omnibus test; require at least two rows.
%   - Only if Friedman P<alpha: three TWO-SIDED paired signrank tests,
%     P-C, C-U, P-U, Holm-corrected within this area x balance.
%     Each pair uses its available matched rows; row IDs/N are saved.
%   - One-sample and omnibus P values are nominal (as in the reference).
%     Plot mean/median is a display choice, not a switch of statistical test.
%   - Full values, identities, paired differences and P values are saved.
%
% PLOTS: ordinary jittered points, no violin/density/outlier removal.
% show_bar=false -> horizontal center line; true -> column from zero.
% summary_stat chooses mean/median for that line or column, independently
% of the fixed averaging used to define each observation.
% No independent-noise category, variance percentages or z-scoring.
% Posterior uncertainty is selected from upstream u0/u1 summaries; this
% script does not recalculate/add uncertainty or perform reconstruction.
% all_condition + model and posterior + DSL_filtered are unsupported.
%
% Automatic selection checks saved settings, not just filenames. Among
% matching display variants (e.g. noise0/noise1, plot styles), use the most
% recently saved compatible file and print its full path. Set the explicit
% file options below to select a particular saved summary.
% Outputs go in <summary_dir>/deltaVar_figures with a new GPLdVar prefix.

clc; clear;

%% ============================ USER SETTINGS ===========================
root_dir = 'I:\np_data';
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;                           % 1=data; 2=independently shuffled units
group_names = {'V1','MT'};            % exact MODEL GROUP order in summaries
gpl_mat_name = 'unit_gpl_results_sponsub.mat'; % class-definition provenance
model_mode = 'each_condition';         % 'each_condition' or 'all_condition'
variance_source = 'model';        % 'model' or 'posterior'
uncertainty_included = 0;             % posterior only: select saved u0/u1
DSL_filter = 'all_latents';           % MODEL only: also 'DSL_filtered'
DSL_threshold = [];                  % []=use saved value; or select a value

feature_population_mode = 'pooled';   % 'pooled'=ALL model neurons; 'separate'=P/C/U
analyze_feature_effects = true;
analyze_balances = true;

summary_dir = '';                    % '' -> root_dir/<model_mode>_mode
pooled_summary_file = '';            % ''=auto; or full path to sumLV_*.mat
class_summary_file = '';             % ''=auto; or full path to GPLrawVar_*.mat
output_dir = '';                     % '' -> <summary_dir>/deltaVar_figures

show_bar = false;                    % false=horizontal line; true=column
summary_stat = 'median';             % 'mean' or 'median'
significance_alpha = 0.05;

save_mat = true;
save_stats_csv = false;               % numerical P values and sample sizes
save_fig = false;
save_png = true;
save_svg = false;                    % uses print -dsvg for older MATLAB
make_plots = true;                   % false still calculates/saves statistics
close_after_save = true;             % close only when a figure was saved
figure_visible = 'on';
png_dpi = 300;

area_colors = [0.0000 0.4470 0.7410; ... % V1
               0.8500 0.3250 0.0980];   % MT; rows follow group_names
point_size = 36;
point_alpha = 0.70;
point_jitter_width = 0.12;
jitter_seed = 1;
bar_width = 0.50;
bar_alpha = 0.30;
center_line_width = 2.2;
center_line_halfwidth = 0.22;
font_name = 'Arial';
axis_font_size = 12;
figure_width = 1100;
figure_height = 720;

%% =============================== CONFIG ===============================
cfg = struct('root_dir',root_dir,'data_content',data_content,'runIdx',runIdx, ...
    'group_names',{group_names},'gpl_mat_name',gpl_mat_name,'model_mode',model_mode, ...
    'variance_source',variance_source,'uncertainty_included',uncertainty_included, ...
    'DSL_filter',DSL_filter,'DSL_threshold',DSL_threshold, ...
    'feature_population_mode',feature_population_mode, ...
    'analyze_feature_effects',analyze_feature_effects,'analyze_balances',analyze_balances, ...
    'summary_dir',summary_dir,'pooled_summary_file',pooled_summary_file, ...
    'class_summary_file',class_summary_file,'output_dir',output_dir, ...
    'show_bar',show_bar,'summary_stat',summary_stat,'alpha',significance_alpha, ...
    'save_mat',save_mat,'save_stats_csv',save_stats_csv,'save_fig',save_fig, ...
    'save_png',save_png,'save_svg',save_svg,'make_plots',make_plots, ...
    'close_after_save',close_after_save,'figure_visible',figure_visible,'png_dpi',png_dpi, ...
    'area_colors',area_colors,'point_size',point_size,'point_alpha',point_alpha, ...
    'point_jitter_width',point_jitter_width,'jitter_seed',jitter_seed, ...
    'bar_width',bar_width,'bar_alpha',bar_alpha,'center_line_width',center_line_width, ...
    'center_line_halfwidth',center_line_halfwidth,'font_name',font_name, ...
    'axis_font_size',axis_font_size,'figure_width',figure_width,'figure_height',figure_height);
cfg = normalizeConfigLocal(cfg);

%% ============================ READ SUMMARIES ==========================
feature_input = []; class_input = [];
if cfg.analyze_balances || (cfg.analyze_feature_effects && ...
        strcmp(cfg.feature_population_mode,'separate'))
    [M,filename] = loadSummaryLocal(cfg,'classes');
    class_input = unpackClassesLocal(M,filename,cfg);
    clear M;
end
if cfg.analyze_feature_effects
    if strcmp(cfg.feature_population_mode,'pooled')
        [M,filename] = loadSummaryLocal(cfg,'pooled');
        feature_input = unpackPooledLocal(M,filename,cfg);
        clear M;
    else
        feature_input = class_input;
    end
end
cfg = resolveSavedFilterLocal(cfg,feature_input,class_input);
reportObservationsLocal(feature_input,class_input);

%% ======================= CALCULATE AND TEST ===========================
definitions = featureDefinitionsLocal();
MultiSessionGPLClassDeltaVar = struct();
MultiSessionGPLClassDeltaVar.settings = cfg;
MultiSessionGPLClassDeltaVar.meta = struct( ...
    'created_by','GPL_class_deltaVar_figure_plot.m','created_on',datestr(now,30), ...
    'model_mode',cfg.model_mode,'variance_source',cfg.variance_source, ...
    'uncertainty_included',cfg.uncertainty_included_effective, ...
    'test_unit','session_direction','value_mode','raw', ...
    'population_definition','Pooled features include all model neurons; balances use P/C/U', ...
    'averaging_rule','All four matched feature differences / all eight balance conditions required', ...
    'one_sample_test','two-sided signrank vs zero; nominal P', ...
    'class_tests','Friedman then paired two-sided signrank; Holm across three pairs', ...
    'directions','Two directions remain separate observations; no averaging over directions');
MultiSessionGPLClassDeltaVar.feature = [];
MultiSessionGPLClassDeltaVar.balance = [];
MultiSessionGPLClassDeltaVar.panels = {};
if cfg.analyze_feature_effects
    F = calculateFeaturesLocal(feature_input,definitions,cfg);
    MultiSessionGPLClassDeltaVar.feature = F;
    families = {[2 1],[3 4]};          % same source order as deltaR2 reference
    family_tags = {'witAcr','ffFb'};
    for c = 1:numel(F.population_labels)
        for e = 1:numel(definitions)
            for k = 1:numel(families)
                P = featurePanelLocal(F,c,e,families{k},cfg);
                P.figure_tag = sprintf('fd%s_%s_%s',definitions(e).tag, ...
                    family_tags{k},F.population_tags{c});
                P = computeTestsLocal(P,false,cfg);
                MultiSessionGPLClassDeltaVar.panels{end+1} = P;
            end
        end
    end
end
if cfg.analyze_balances
    B = calculateBalancesLocal(class_input,cfg);
    MultiSessionGPLClassDeltaVar.balance = B;
    for g = 1:numel(cfg.group_names)
        for k = 1:2
            P = balancePanelLocal(B,g,k,cfg);
            P.figure_tag = sprintf('bal%d_g%02d',k,g);
            P = computeTestsLocal(P,true,cfg);
            MultiSessionGPLClassDeltaVar.panels{end+1} = P;
        end
    end
end
cfg.output_base = sprintf('GPLdVar_%s_r%03d_%s_%s_%s_%s_%s_%s_b%d_f%dq%d', ...
    safeTagLocal(cfg.data_content),cfg.runIdx,cfg.mapping_tag,cfg.mode_tag, ...
    cfg.source_tag,cfg.filter_tag,cfg.feature_population_mode,cfg.summary_stat, ...
    cfg.show_bar,cfg.analyze_feature_effects,cfg.analyze_balances);
MultiSessionGPLClassDeltaVar.settings = cfg;
MultiSessionGPLClassDeltaVar.meta.output_base = cfg.output_base;
MultiSessionGPLClassDeltaVar.statistics_table = statisticsTableLocal( ...
    MultiSessionGPLClassDeltaVar.panels,cfg);
disp(MultiSessionGPLClassDeltaVar.statistics_table);

%% =============================== SAVE/PLOT ============================
if cfg.save_mat || cfg.save_stats_csv || ...
        (cfg.make_plots && (cfg.save_fig || cfg.save_png || cfg.save_svg))
    ensureDirLocal(cfg.output_dir);
end
% Save statistics before plotting, so an export error cannot lose tests.
if cfg.save_mat
    filename = fullfile(cfg.output_dir,[cfg.output_base '.mat']);
    save(filename,'MultiSessionGPLClassDeltaVar','-v7.3');
    fprintf('Saved MAT: %s\n',filename);
end
if cfg.save_stats_csv
    filename = fullfile(cfg.output_dir,[cfg.output_base '_stats.csv']);
    writetable(MultiSessionGPLClassDeltaVar.statistics_table,filename);
    fprintf('Saved statistics: %s\n',filename);
end
if cfg.make_plots
    for p = 1:numel(MultiSessionGPLClassDeltaVar.panels)
        P = MultiSessionGPLClassDeltaVar.panels{p};
        fig = plotPanelLocal(P,cfg);
        saveFigureLocal(fig,cfg,[cfg.output_base '_' P.figure_tag]);
    end
end
fprintf('Done: %d panels; each point is one session x direction.\n', ...
    numel(MultiSessionGPLClassDeltaVar.panels));

%% =========================== LOCAL FUNCTIONS ==========================
function cfg = normalizeConfigLocal(cfg)
    cfg.root_dir = char(cfg.root_dir);
    cfg.data_content = strtrim(char(cfg.data_content));
    for name = {'summary_dir','pooled_summary_file','class_summary_file','output_dir', ...
            'figure_visible','font_name','gpl_mat_name'}
        cfg.(name{1}) = strtrim(char(cfg.(name{1})));
    end
    cfg.group_names = textListLocal(cfg.group_names);
    if isempty(cfg.data_content) || isempty(cfg.group_names)
        error('data_content and group_names must not be empty.');
    end
    cfg.model_mode = canonicalModeLocal(cfg.model_mode);
    cfg.mode_tag = 'eachcond';
    if strcmp(cfg.model_mode,'all_condition'), cfg.mode_tag = 'allcond'; end
    cfg.variance_source = lower(strtrim(char(cfg.variance_source)));
    requireOptionLocal(cfg.variance_source,{'model','posterior'},'variance_source');
    if strcmp(cfg.model_mode,'all_condition') && strcmp(cfg.variance_source,'model')
        error('all_condition + model is unsupported. Choose posterior or each_condition.');
    end
    cfg.DSL_filter = lower(strtrim(char(cfg.DSL_filter)));
    requireOptionLocal(cfg.DSL_filter,{'all_latents','dsl_filtered'},'DSL_filter');
    if strcmp(cfg.DSL_filter,'dsl_filtered'), cfg.DSL_filter = 'DSL_filtered'; end
    if strcmp(cfg.variance_source,'posterior') && ~strcmp(cfg.DSL_filter,'all_latents')
        error('Posterior summaries require DSL_filter=''all_latents''.');
    end
    logicalFields = {'uncertainty_included','analyze_feature_effects','analyze_balances', ...
        'show_bar','save_mat','save_stats_csv','save_fig','save_png','save_svg', ...
        'make_plots','close_after_save'};
    for k = 1:numel(logicalFields)
        f = logicalFields{k}; v = cfg.(f);
        if ~(isnumeric(v) || islogical(v)) || ~isscalar(v) || ~ismember(double(v),[0 1])
            error('%s must be a scalar 0 or 1.',f);
        end
        cfg.(f) = logical(v);
    end
    if ~cfg.analyze_feature_effects && ~cfg.analyze_balances
        error('Enable analyze_feature_effects and/or analyze_balances.');
    end
    cfg.uncertainty_included_effective = false;
    cfg.source_tag = 'model';
    if strcmp(cfg.variance_source,'posterior')
        cfg.uncertainty_included_effective = cfg.uncertainty_included;
        cfg.source_tag = sprintf('post_u%d',cfg.uncertainty_included);
    end
    cfg.feature_population_mode = lower(strtrim(char(cfg.feature_population_mode)));
    if strcmp(cfg.feature_population_mode,'pool'), cfg.feature_population_mode = 'pooled'; end
    requireOptionLocal(cfg.feature_population_mode,{'pooled','separate'},'feature_population_mode');
    cfg.summary_stat = lower(strtrim(char(cfg.summary_stat)));
    requireOptionLocal(cfg.summary_stat,{'mean','median'},'summary_stat');
    requireOptionLocal(cfg.figure_visible,{'on','off'},'figure_visible');
    validateattributes(cfg.runIdx,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(cfg.alpha,{'numeric'},{'scalar','positive','<=',0.05,'finite'});
    validateattributes(cfg.jitter_seed,{'numeric'},{'scalar','integer','>=',0,'<=',2^32-1});
    if ~isempty(cfg.DSL_threshold)
        validateattributes(cfg.DSL_threshold,{'numeric'},{'scalar','finite'});
    end
    for name = {'point_alpha','bar_alpha'}
        validateattributes(cfg.(name{1}),{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
    end
    for name = {'point_size','bar_width','center_line_width','center_line_halfwidth', ...
            'axis_font_size','figure_width','figure_height','png_dpi'}
        validateattributes(cfg.(name{1}),{'numeric'},{'scalar','positive','finite'});
    end
    validateattributes(cfg.point_jitter_width,{'numeric'},{'scalar','nonnegative','finite'});
    validateattributes(cfg.area_colors,{'numeric'}, ...
        {'size',[numel(cfg.group_names) 3],'>=',0,'<=',1,'finite'});
    for name = {'signrank','friedman'}
        if strcmp(name{1},'friedman') && ~cfg.analyze_balances, continue; end
        if exist(name{1},'file') == 0
            error('Statistics and Machine Learning Toolbox is required (%s unavailable).',name{1});
        end
    end
    if isempty(cfg.summary_dir)
        cfg.summary_dir = fullfile(cfg.root_dir,[cfg.model_mode '_mode']);
    end
    if isempty(cfg.output_dir), cfg.output_dir = fullfile(cfg.summary_dir,'deltaVar_figures'); end
    cfg.summary_dir = absolutePathLocal(cfg.summary_dir);
    cfg.output_dir = absolutePathLocal(cfg.output_dir);
    cfg.condition_labels = {'G-S-L','G-S-H','G-L-L','G-L-H', ...
        'P-S-L','P-S-H','P-L-L','P-L-H'};
    cfg.latent_labels = {'Across','Within','Feedforward','Feedback'};
    cfg.class_labels = {'Pattern cell','Component cell','Unclassified cell'};
    cfg.class_tags = {'P','C','U'};
    cfg.area_labels = cfg.group_names;
    if numel(unique(lower(string(cfg.group_names)))) < numel(cfg.group_names)
        for g = 1:numel(cfg.group_names)
            cfg.area_labels{g} = sprintf('G%d: %s',g,cfg.group_names{g});
        end
    end
    cfg.mapping_tag = strjoin(cellfun(@safeTagLocal,cfg.group_names,'UniformOutput',false),'_');
end

function [M,filename] = loadSummaryLocal(cfg,kind)
    if strcmp(kind,'pooled')
        override = cfg.pooled_summary_file; variable = 'MultiSessionSummary';
        pattern = 'sumLV_*.mat';
        instruction = ['Run sum_sessions_latent_compare_var.m with matching settings, ', ...
            'metric_name=''rawvariance'', condition_display_mode=''pooled'', save_mat=true.'];
    else
        override = cfg.class_summary_file; variable = 'MultiSessionRawVar';
        pattern = 'GPLrawVar_*.mat';
        instruction = 'Run GPL_class_rawvar.m with matching settings and save_mat=true.';
    end
    if ~isempty(override)
        filename = absolutePathLocal(char(override));
        if ~isfile(filename), error('Summary does not exist: %s',filename); end
        S = load(filename,variable);
        if ~isfield(S,variable), error('%s lacks %s.',filename,variable); end
        M = S.(variable);
        validateSummaryLocal(M,cfg,kind);
    else
        files = dir(fullfile(cfg.summary_dir,pattern));
        files = files(~[files.isdir]);
        [~,order] = sort([files.datenum],'descend'); files = files(order);
        found = false; reasons = {};
        for k = 1:numel(files)
            candidate = fullfile(files(k).folder,files(k).name);
            try
                vars = who('-file',candidate);
                if ~ismember(variable,vars), error('Missing %s.',variable); end
                S = load(candidate,variable);
                validateSummaryLocal(S.(variable),cfg,kind);
                M = S.(variable); filename = candidate; found = true;
                break;
            catch ME
                reasons{end+1} = sprintf('%s: %s',files(k).name,ME.message); %#ok<AGROW>
            end
        end
        if ~found
            for k = 1:numel(reasons), fprintf('  Rejected: %s\n',reasons{k}); end
            error('No matching %s summary in %s.\n%s',kind,cfg.summary_dir,instruction);
        end
    end
    fprintf('Using %s summary:\n  %s\n',kind,filename);
end

function validateSummaryLocal(M,cfg,kind)
    requireFieldsLocal(M,{'settings','meta','labels','condition_ids','observation_info'},'Summary');
    C = M.settings;
    requireFieldsLocal(C,{'data_content','runIdx','group_names','DSL_filter'},'Summary.settings');
    if ~strcmp(char(C.data_content),cfg.data_content) || ~isequal(C.runIdx,cfg.runIdx)
        error('data_content or runIdx differs from the requested settings.');
    end
    if ~isequal(lower(string(textListLocal(C.group_names))),lower(string(cfg.group_names)))
        error('group_names/model group order differs from the requested settings.');
    end
    mode = metaSettingLocal(M,'model_mode','each_condition');
    source = metaSettingLocal(M,'variance_source','model');
    if ~strcmp(canonicalModeLocal(mode),cfg.model_mode) || ~strcmpi(char(source),cfg.variance_source)
        error('model_mode or variance_source differs from the requested settings.');
    end
    if ~strcmpi(char(C.DSL_filter),cfg.DSL_filter), error('DSL_filter differs.'); end
    if strcmp(cfg.variance_source,'posterior')
        u = metaSettingLocal(M,'uncertainty_included',NaN);
        if ~isscalar(u) || ~isfinite(double(u)) || double(u) ~= double(cfg.uncertainty_included)
            error('Posterior uncertainty_included differs or is missing.');
        end
    end
    if strcmp(kind,'pooled')
        requireFieldsLocal(M,{'values'},'MultiSessionSummary');
        metric = metaSettingLocal(M,'metric_name','');
        population = metaSettingLocal(M,'population_mode_effective','');
        if isempty(population) && isfield(C,'condition_display_mode'), population = C.condition_display_mode; end
        if ~strcmpi(char(metric),'rawvariance')
            error('Require metric_name=''rawvariance'' (not a percentage or latent count).');
        end
        if ~ismember(lower(char(population)),{'pooled','pool'}) || size(M.values,3) ~= 1
            error('Require a pooled ALL-MODEL-NEURON summary, not a mean of three classes.');
        end
    else
        requireFieldsLocal(M,{'raw_variance_mean','n_neurons','values_pooled'},'MultiSessionRawVar');
        requireFieldsLocal(C,{'gpl_mat_name'},'Class summary.settings');
        if ~strcmpi(char(C.gpl_mat_name),cfg.gpl_mat_name)
            error('The class summary uses a different gpl_mat_name.');
        end
    end
    if strcmp(cfg.DSL_filter,'DSL_filtered')
        threshold = savedThresholdLocal(M);
        if ~isempty(cfg.DSL_threshold) && abs(threshold-cfg.DSL_threshold) > 1e-10
            error('Saved DSL threshold differs from DSL_threshold.');
        end
    end
end

function D = unpackPooledLocal(M,filename,cfg)
    requireFieldsLocal(M.labels,{'conditions','categories'},'Summary.labels');
    co = labelOrderLocal(M.labels.conditions,cfg.condition_labels);
    la = labelOrderLocal(M.labels.categories,cfg.latent_labels);
    n = size(M.values,1); ng = numel(cfg.group_names);
    checkSizeLocal(M.values,[n ng 1 8 numel(M.labels.categories)],'pooled variance');
    D = inputBaseLocal(M,filename,n,co,cfg);
    D.raw_variance_mean = double(M.values(:,:,:,co,la));
    D.n_neurons = nan(n,ng,1,8);
    % Counts are for provenance only: the saved pooled mean already uses
    % ALL model neurons. It must never be rebuilt from just P/C/U means.
    if isfield(M,'session_data')
        for o = 1:n
            s = D.observation_info(o).session_index;
            d = D.observation_info(o).direction_index;
            R = recordAtLocal(M.session_data,s);
            for g = 1:ng
                N = R.group(g).population(1).n_neurons(co,d);
                D.n_neurons(o,g,1,:) = reshape(N,[1 1 1 8]);
            end
        end
    end
    D.population_labels = {'All model neurons'};
    D.population_tags = {'allN'};
    D.population_definition = 'sum of individual neuron variances / number of all model neurons';
    checkFiniteOrNaNLocal(D.raw_variance_mean,'pooled raw variance');
end

function D = unpackClassesLocal(M,filename,cfg)
    requireFieldsLocal(M.labels,{'conditions','variance','classes','delta_names'},'Summary.labels');
    co = labelOrderLocal(M.labels.conditions,cfg.condition_labels);
    la = labelOrderLocal(M.labels.variance,cfg.latent_labels);
    cl = labelOrderLocal(M.labels.classes,cfg.class_labels);
    de = labelOrderLocal(M.labels.delta_names,{'acr_vs_wit','ff_vs_fb'});
    n = size(M.raw_variance_mean,1); ng = numel(cfg.group_names);
    checkSizeLocal(M.raw_variance_mean,[n ng 3 8 numel(M.labels.variance)],'class variance');
    checkSizeLocal(M.n_neurons,[n ng 3 8],'class neuron counts');
    checkSizeLocal(M.values_pooled,[n ng 3 2],'class pooled balances');
    D = inputBaseLocal(M,filename,n,co,cfg);
    D.raw_variance_mean = double(M.raw_variance_mean(:,:,cl,co,la));
    D.n_neurons = double(M.n_neurons(:,:,cl,co));
    D.saved_balances = double(M.values_pooled(:,:,cl,de));
    D.population_labels = cfg.class_labels; D.population_tags = cfg.class_tags;
    D.population_definition = 'mean of individual neuron variances in each valid GPL class';
    checkFiniteOrNaNLocal(D.raw_variance_mean,'class raw variance');
    checkFiniteOrNaNLocal(D.n_neurons,'class neuron counts');
    if any(D.n_neurons(isfinite(D.n_neurons)) < 0) || ...
            any(mod(D.n_neurons(isfinite(D.n_neurons)),1) ~= 0)
        error('Class neuron counts must be nonnegative integers or NaN.');
    end
    absent = ~isfinite(D.n_neurons) | D.n_neurons == 0;
    if any(isfinite(D.raw_variance_mean(repmat(absent,[1 1 1 1 4]))))
        error('A missing/empty class has finite variance. Regenerate GPL_class_rawvar output.');
    end
end

function D = inputBaseLocal(M,filename,n,co,cfg)
    info = M.observation_info;
    if n < 1 || ~isstruct(info) || numel(info) ~= n
        error('observation_info does not match the number of variance rows.');
    end
    requireFieldsLocal(info,{'session_index','direction_index','direction_value','session_name'},'observation_info');
    keys = cell(n,1);
    for k = 1:n
        validateattributes(info(k).session_index,{'numeric'},{'scalar','integer','positive'});
        validateattributes(info(k).direction_index,{'numeric'},{'scalar','integer','>=',1,'<=',2});
        validateattributes(info(k).direction_value,{'numeric'},{'scalar','finite'});
        keys{k} = sprintf('%s|dir%d',char(info(k).session_name),info(k).direction_index);
    end
    if numel(unique(keys)) ~= n, error('Duplicate session-direction identities in summary.'); end
    checkSizeLocal(M.condition_ids,[n 8],'condition IDs');
    D = struct('source_file',filename,'source_meta',M.meta,'source_settings',M.settings, ...
        'observation_info',info(:),'observation_keys',{keys}, ...
        'condition_ids',M.condition_ids(:,co),'condition_labels',{cfg.condition_labels}, ...
        'latent_labels',{cfg.latent_labels},'group_names',{cfg.group_names}, ...
        'num_sessions',numel(unique({info.session_name})),'DSL_threshold',NaN);
    if strcmp(cfg.DSL_filter,'DSL_filtered'), D.DSL_threshold = savedThresholdLocal(M); end
end

function cfg = resolveSavedFilterLocal(cfg,F,B)
    cfg.filter_tag = 'all'; cfg.DSL_threshold_effective = NaN;
    if ~strcmp(cfg.DSL_filter,'DSL_filtered'), return; end
    v = [];
    if ~isempty(F), v(end+1) = F.DSL_threshold; end
    if ~isempty(B), v(end+1) = B.DSL_threshold; end
    if any(abs(v-v(1)) > 1e-10)
        error('Feature/balance inputs use different DSL thresholds. Select matching summary files.');
    end
    cfg.DSL_threshold_effective = v(1);
    cfg.filter_tag = ['dsl' safeTagLocal(sprintf('%.12g',v(1)))];
end

function reportObservationsLocal(F,B)
    if ~isempty(F)
        fprintf('Feature effects: %d sessions, %d session-direction rows.\n', ...
            F.num_sessions,numel(F.observation_info));
    end
    if ~isempty(B)
        fprintf('Class data: %d sessions, %d session-direction rows.\n', ...
            B.num_sessions,numel(B.observation_info));
    end
    if ~isempty(F) && ~isempty(B) && ...
            ~isequal(sort(F.observation_keys),sort(B.observation_keys))
        warning(['Feature and class summaries contain different session-direction sets. ', ...
            'Each analysis retains its own saved rows and identities; no rows are matched by position across files.']);
    end
end

function F = calculateFeaturesLocal(D,definitions,cfg)
    F = D; V = D.raw_variance_mean;
    n = size(V,1); ng = size(V,2); nc = size(V,3);
    F.values = nan(n,ng,nc,4,3);
    F.matched_differences = nan(n,ng,nc,4,4,3);
    F.definitions = definitions;
    for e = 1:3
        X = V(:,:,:,definitions(e).positive,:) - V(:,:,:,definitions(e).negative,:);
        F.matched_differences(:,:,:,:,:,e) = permute(X,[1 2 3 5 4]);
        F.values(:,:,:,:,e) = reshape(mean(X,4),[n ng nc 4]);
    end
    F.dimension_names = {'session_direction','model_group','neuron_population','latent_category','feature_effect'};
    F.matched_dimension_names = {'session_direction','model_group','neuron_population', ...
        'latent_category','condition_match','feature_effect'};
    F.n_points = reshape(sum(isfinite(F.values),1),[ng nc 4 3]);
    F.population_mode = cfg.feature_population_mode;
end

function B = calculateBalancesLocal(D,cfg)
    B = D; V = D.raw_variance_mean;
    n = size(V,1); ng = size(V,2);
    B.values_separate = V(:,:,:,:,[1 3])-V(:,:,:,:,[2 4]);
    expected = reshape(mean(B.values_separate,4),[n ng 3 2]);
    assertSameNumericLocal(expected,D.saved_balances,'saved class balances vs raw variances');
    B.values = D.saved_balances;
    B.balance_names = {'Across - Within','Feedforward - Feedback'};
    B.dimension_names = {'session_direction','model_group','cell_class','balance'};
    B.n_points = reshape(sum(isfinite(B.values),1),[ng 3 2]);
    B.class_labels = cfg.class_labels;
end

function defs = featureDefinitionsLocal()
    t = struct('name','','tag','','label','','positive',[],'negative',[]);
    defs = repmat(t,1,3);
    defs(1) = struct('name','stimtype_G_minus_P','tag','GP','label','Grating - Plaid', ...
        'positive',[1 2 3 4],'negative',[5 6 7 8]);
    defs(2) = struct('name','size_S_minus_L','tag','SL','label','Small - Large', ...
        'positive',[1 2 5 6],'negative',[3 4 7 8]);
    defs(3) = struct('name','contrast_Low_minus_High','tag','LH','label','Low - High', ...
        'positive',[1 3 5 7],'negative',[2 4 6 8]);
end

function P = emptyPanelLocal()
% A common template also avoids assignments between dissimilar structures.
    P = struct('family','','effect_label','','population','','outer_labels',{{}}, ...
        'area_names',{{}},'groups',{{}},'colors',[],'ylabel','','observation_info',[], ...
        'num_sessions',0,'figure_tag','','statistics',[]);
end

function P = featurePanelLocal(F,c,e,latents,cfg)
    P = emptyPanelLocal();
    P.family = 'stimulus_feature'; P.effect_label = F.definitions(e).label;
    P.population = F.population_labels{c};
    P.outer_labels = cfg.latent_labels(latents); P.area_names = cfg.area_labels;
    P.groups = cell(numel(latents),numel(cfg.group_names));
    for l = 1:numel(latents)
        for g = 1:numel(cfg.group_names)
            P.groups{l,g} = reshape(F.values(:,g,c,latents(l),e),[],1);
        end
    end
    P.colors = cfg.area_colors;
    P.ylabel = '\DeltaVar per neuron';
    P.observation_info = F.observation_info; P.num_sessions = F.num_sessions;
end

function P = balancePanelLocal(B,g,k,cfg)
    P = emptyPanelLocal();
    P.family = 'latent_balance'; P.effect_label = B.balance_names{k};
    P.population = 'P/C/U separately';
    P.outer_labels = cfg.class_labels; P.area_names = cfg.area_labels(g);
    P.groups = cell(3,1);
    for c = 1:3, P.groups{c,1} = reshape(B.values(:,g,c,k),[],1); end
    P.colors = cfg.area_colors(g,:);
    P.ylabel = ['\DeltaVar per neuron (' B.balance_names{k} ')'];
    P.observation_info = B.observation_info; P.num_sessions = B.num_sessions;
end

function P = computeTestsLocal(P,compareClasses,cfg)
    shape = size(P.groups);
    S = struct('unit','session_direction','alpha',cfg.alpha, ...
        'one_sample_method','Wilcoxon signed-rank vs zero','one_sample_tail','both', ...
        'one_sample_p_raw',nan(shape),'one_sample_n',zeros(shape), ...
        'one_sample_n_nonzero',zeros(shape),'one_sample_mean',nan(shape), ...
        'one_sample_median',nan(shape),'one_sample_observation_indices',{cell(shape)}, ...
        'one_sample_details',{cell(shape)}, ...
        'omnibus_method','Friedman','omnibus_p',NaN,'omnibus_n',0, ...
        'omnibus_observation_indices',[],'omnibus_table',{{}},'omnibus_details',[], ...
        'omnibus_status','not applicable','posthoc_performed',false, ...
        'pairwise_method','paired two-sided Wilcoxon signed-rank', ...
        'pairwise_groups',[1 2;2 3;1 3], ...
        'pairwise_p_raw',nan(3,1),'pairwise_p_holm',nan(3,1), ...
        'pairwise_n',zeros(3,1),'pairwise_n_nonzero',zeros(3,1), ...
        'pairwise_observation_indices',{cell(3,1)}, ...
        'pairwise_differences',{cell(3,1)},'pairwise_details',{cell(3,1)}, ...
        'adjustment','Nominal one-sample/omnibus P; Holm for three post hoc class pairs only');
    nRows = numel(P.observation_info);
    for k = 1:numel(P.groups)
        x = double(P.groups{k}(:));
        if numel(x) ~= nRows, error('Each group must retain all observation rows, including NaN.'); end
        keep = isfinite(x); v = x(keep);
        S.one_sample_observation_indices{k} = find(keep);
        S.one_sample_n(k) = numel(v); S.one_sample_n_nonzero(k) = nnz(v ~= 0);
        if isempty(v), continue; end
        S.one_sample_mean(k) = mean(v); S.one_sample_median(k) = median(v);
        [S.one_sample_p_raw(k),S.one_sample_details{k}] = signedRankLocal(v);
    end
    if compareClasses
        if ~isequal(shape,[3 1]), error('Balance comparisons require three aligned class columns.'); end
        Y = [P.groups{1}(:),P.groups{2}(:),P.groups{3}(:)];
        complete = all(isfinite(Y),2); Z = Y(complete,:);
        S.omnibus_n = size(Z,1); S.omnibus_observation_indices = find(complete);
        S.omnibus_status = 'fewer than two complete P/C/U observations';
        if S.omnibus_n >= 2
            if all(Z(:,1) == Z(:,2) & Z(:,1) == Z(:,3))
                S.omnibus_p = 1;
                S.omnibus_status = 'all three classes tied within every complete observation';
            else
                [S.omnibus_p,S.omnibus_table,S.omnibus_details] = friedman(Z,1,'off');
                S.omnibus_status = 'tested';
            end
        end
        S.posthoc_performed = isfinite(S.omnibus_p) && S.omnibus_p < cfg.alpha;
        for k = 1:3
            a = S.pairwise_groups(k,1); b = S.pairwise_groups(k,2);
            keep = isfinite(Y(:,a)) & isfinite(Y(:,b));
            v = Y(keep,a)-Y(keep,b);
            S.pairwise_n(k) = numel(v); S.pairwise_n_nonzero(k) = nnz(v ~= 0);
            S.pairwise_observation_indices{k} = find(keep);
            S.pairwise_differences{k} = v;
            if S.posthoc_performed
                [S.pairwise_p_raw(k),S.pairwise_details{k}] = signedRankLocal(v);
            end
        end
        if S.posthoc_performed, S.pairwise_p_holm = holmLocal(S.pairwise_p_raw); end
    end
    P.statistics = S;
end

function [p,details] = signedRankLocal(v)
    v = double(v(:)); v = v(isfinite(v));
    details = struct('method','signrank','tail','both','matlab_stats',[], ...
        'n_finite',numel(v),'n_exact_nonzero',nnz(v ~= 0),'note','');
    if isempty(v)
        p = NaN; details.note = 'no finite observations';
    elseif all(v == 0)
        p = 1; details.note = 'all differences are zero; no nonzero signed ranks';
    else
        [p,~,stats] = signrank(v,0,'tail','both');
        details.matlab_stats = stats;
        details.note = 'MATLAB default exact/approximate selection; zero differences ignored by signrank';
    end
end

function adjusted = holmLocal(p)
    adjusted = nan(size(p));
    ids = find(isfinite(p));
    [v,order] = sort(p(ids)); previous = 0;
    m = numel(p);                       % fixed family of three planned pairs
    for k = 1:numel(v)
        previous = max(previous,min(1,(m-k+1)*v(k)));
        adjusted(ids(order(k))) = previous;
    end
end

function T = statisticsTableLocal(panels,cfg)
    template = struct('figure_tag','','family','','effect','','population','', ...
        'area','','comparison','','test','','n',0,'n_nonzero',NaN, ...
        'mean_difference',NaN,'median_difference',NaN,'p_raw',NaN, ...
        'p_holm',NaN,'significant',false,'status','');
    rows = repmat(template,0,1);
    for p = 1:numel(panels)
        P = panels{p}; S = P.statistics;
        for a = 1:size(P.groups,1)
            for g = 1:size(P.groups,2)
                r = template; r.figure_tag = P.figure_tag; r.family = P.family;
                r.effect = P.effect_label; r.population = P.population;
                r.area = P.area_names{g}; r.comparison = [P.outer_labels{a} ' vs 0'];
                r.test = 'signrank_two_sided'; r.n = S.one_sample_n(a,g);
                r.n_nonzero = S.one_sample_n_nonzero(a,g);
                r.mean_difference = S.one_sample_mean(a,g);
                r.median_difference = S.one_sample_median(a,g);
                r.p_raw = S.one_sample_p_raw(a,g); r.significant = r.p_raw < cfg.alpha;
                r.status = 'tested';
                if r.n == 0, r.status = 'no finite observations'; end
                if r.n > 0 && r.n_nonzero == 0, r.status = 'all zero'; end
                rows(end+1,1) = r; %#ok<AGROW>
            end
        end
        if ~strcmp(P.family,'latent_balance'), continue; end
        r = template; r.figure_tag = P.figure_tag; r.family = P.family;
        r.effect = P.effect_label; r.population = P.population; r.area = P.area_names{1};
        r.comparison = 'P / C / U'; r.test = 'Friedman'; r.n = S.omnibus_n;
        r.p_raw = S.omnibus_p; r.significant = r.p_raw < cfg.alpha; r.status = S.omnibus_status;
        rows(end+1,1) = r; %#ok<AGROW>
        for k = 1:3
            r = template; r.figure_tag = P.figure_tag; r.family = P.family;
            r.effect = P.effect_label; r.population = P.population; r.area = P.area_names{1};
            a = S.pairwise_groups(k,1); b = S.pairwise_groups(k,2);
            r.comparison = [cfg.class_tags{a} ' - ' cfg.class_tags{b}];
            r.test = 'paired_signrank_two_sided_Holm';
            r.n = S.pairwise_n(k); r.n_nonzero = S.pairwise_n_nonzero(k);
            v = S.pairwise_differences{k};
            if ~isempty(v), r.mean_difference = mean(v); r.median_difference = median(v); end
            r.p_raw = S.pairwise_p_raw(k); r.p_holm = S.pairwise_p_holm(k);
            r.significant = r.p_holm < cfg.alpha;
            r.status = 'not tested: Friedman gate not passed';
            if S.posthoc_performed, r.status = 'tested'; end
            rows(end+1,1) = r; %#ok<AGROW>
        end
    end
    T = struct2table(rows);
end

function fig = plotPanelLocal(P,cfg)
    nOuter = size(P.groups,1); nInner = size(P.groups,2);
    isBalance = strcmp(P.family,'latent_balance');
    x = nan(nOuter,nInner); centers = nan(1,nOuter);
    for a = 1:nOuter
        x(a,:) = (a-1)*(nInner+1.3)+(1:nInner);
        centers(a) = mean(x(a,:));
    end
    xl = [x(1,1)-0.7 x(end,end)+0.7];
    allValues = vertcat(P.groups{:}); allValues = allValues(isfinite(allValues));
    limit = 1;
    if ~isempty(allValues) && any(allValues ~= 0), limit = 1.10*max(abs(allValues)); end
    fig = figure('Name',[P.effect_label ' | ' P.population], ...
        'NumberTitle','off','Color','w','Visible',cfg.figure_visible, ...
        'Position',[100 100 cfg.figure_width cfg.figure_height],'Renderer','painters');
    mainPos = [0.11 0.23 0.83 0.58];
    if isBalance, mainPos = [0.11 0.28 0.83 0.43]; end
    ax = axes('Parent',fig,'Position',mainPos); hold(ax,'on');
    plot(ax,xl,[0 0],'--','Color',[0.6 0.6 0.6],'LineWidth',0.8,'HandleVisibility','off');
    for a = 2:nOuter
        xSep = (x(a-1,end)+x(a,1))/2;
        plot(ax,[xSep xSep],[-limit limit],'-','Color',[0.88 0.88 0.88], ...
            'LineWidth',0.6,'HandleVisibility','off');
    end
    % Same row uses the same jitter within this figure, even if another
    % class is missing. This does not change the global MATLAB RNG state.
    stream = RandStream('mt19937ar','Seed',cfg.jitter_seed);
    offsets = (2*rand(stream,numel(P.observation_info),1)-1)*cfg.point_jitter_width;
    centerValues = nan(nOuter,nInner);
    for a = 1:nOuter
        for g = 1:nInner
            v = P.groups{a,g}(:); keep = isfinite(v); values = v(keep);
            if isempty(values), continue; end
            color = P.colors(g,:);
            if strcmp(cfg.summary_stat,'mean'), center = mean(values); else, center = median(values); end
            centerValues(a,g) = center;
            if cfg.show_bar
                w = cfg.bar_width/2;
                patch(ax,x(a,g)+[-w w w -w],[0 0 center center],color, ...
                    'FaceAlpha',cfg.bar_alpha,'EdgeColor','none','HandleVisibility','off');
            end
            h = scatter(ax,x(a,g)+offsets(keep),values,cfg.point_size,color,'filled', ...
                'MarkerEdgeColor','none','HandleVisibility','off');
            if isprop(h,'MarkerFaceAlpha'), h.MarkerFaceAlpha = cfg.point_alpha; end
            if ~cfg.show_bar
                plot(ax,x(a,g)+[-1 1]*cfg.center_line_halfwidth,[center center],'-', ...
                    'Color',[0.2 0.2 0.2],'LineWidth',cfg.center_line_width,'HandleVisibility','off');
            end
        end
    end
    xlim(ax,xl); ylim(ax,[-limit limit]);
    set(ax,'XTick',centers,'XTickLabel',P.outer_labels,'TickLabelInterpreter','none', ...
        'FontName',cfg.font_name,'FontSize',cfg.axis_font_size,'TickDir','out', ...
        'XColor',[0.3 0.3 0.3],'YColor',[0.25 0.25 0.25],'LineWidth',1);
    box(ax,'off');
    ylabel(ax,P.ylabel,'Interpreter','tex','FontName',cfg.font_name,'FontSize',cfg.axis_font_size+1);
    textBoxLocal(fig,[0.10 0.945 0.69 0.04],P.effect_label,cfg,cfg.axis_font_size+2,'left','none');
    if ~isBalance
        textBoxLocal(fig,[0.10 0.905 0.78 0.035],P.population,cfg,cfg.axis_font_size,'left','none');
    end
    handles = gobjects(1,nInner);
    for g = 1:nInner
        handles(g) = plot(ax,nan,nan,'o','MarkerSize',7,'LineStyle','none', ...
            'MarkerFaceColor',P.colors(g,:),'MarkerEdgeColor',P.colors(g,:));
    end
    lgd = legend(ax,handles,P.area_names,'Box','off','Interpreter','none', ...
        'Orientation','horizontal','FontName',cfg.font_name,'FontSize',cfg.axis_font_size);
    set(lgd,'Units','normalized','Position',[0.74 0.94 0.22 0.045]);
    set(ax,'Position',mainPos);
    annotateStatisticsLocal(fig,P,cfg,x,xl,mainPos,isBalance);
    centerText = ['Horizontal line: ' cfg.summary_stat];
    if cfg.show_bar, centerText = ['Bar: ' cfg.summary_stat]; end
    footer = sprintf('%s | dots: session x direction | %d sessions | %s, %s', ...
        centerText,P.num_sessions,cfg.model_mode,cfg.source_tag);
    textBoxLocal(fig,[0.10 0.075 0.86 0.035],footer,cfg,10,'left','none');
    textBoxLocal(fig,[0.10 0.035 0.86 0.035], ...
        [cfg.data_content ' | ' cfg.DSL_filter ' | two-sided tests'],cfg,9,'left','none');
    fig.UserData = struct('panel',P,'x_positions',x,'center_values',centerValues, ...
        'summary_stat',cfg.summary_stat,'show_bar',cfg.show_bar,'settings',cfg);
end

function annotateStatisticsLocal(fig,P,cfg,x,xl,pos,isBalance)
    S = P.statistics; xFig = pos(1)+(x-xl(1))/diff(xl)*pos(3); top = pos(2)+pos(4);
    sortedX = sort(xFig(:)); width = 0.18;
    if numel(sortedX)>1, width = min(width,0.95*min(diff(sortedX))); end
    for k = 1:numel(P.groups)
        p = S.one_sample_p_raw(k); n = S.one_sample_n(k);
        if isfinite(p)
            label = {sprintf('%s %s',pTextLocal(p),starsLocal(p,cfg.alpha)),sprintf('n=%d',n)};
        else
            label = {'No data','n=0'};
        end
        textBoxLocal(fig,[xFig(k)-width/2 top+0.008 width 0.062], ...
            label,cfg,10,'center','tex');
    end
    if ~isBalance, return; end
    if isfinite(S.omnibus_p)
        label = sprintf('Friedman: %s %s (n=%d complete session-direction rows)', ...
            pTextLocal(S.omnibus_p),starsLocal(S.omnibus_p,cfg.alpha),S.omnibus_n);
    else
        label = sprintf('Friedman: not tested (n=%d complete P/C/U rows)',S.omnibus_n);
    end
    textBoxLocal(fig,[0.10 0.17 0.86 0.04],label,cfg,10,'left','tex');
    if S.posthoc_performed
        note = 'Class brackets: paired signrank, Holm-adjusted P; one-sample P is nominal.';
    else
        note = 'Class post hoc tests require Friedman P < alpha; one-sample P is nominal.';
    end
    textBoxLocal(fig,[0.10 0.125 0.86 0.035],note,cfg,9,'left','none');
    pairs = find(isfinite(S.pairwise_p_holm) & S.pairwise_p_holm < cfg.alpha);
    for level = 1:numel(pairs)
        k = pairs(level); a = S.pairwise_groups(k,1); b = S.pairwise_groups(k,2);
        left = xFig(a,1); right = xFig(b,1); y = top+0.080+0.047*(level-1);
        annotation(fig,'line',[left right],[y y],'Color',[0.23 0.23 0.23],'LineWidth',1);
        annotation(fig,'line',[left left],[y-0.009 y],'Color',[0.23 0.23 0.23],'LineWidth',1);
        annotation(fig,'line',[right right],[y-0.009 y],'Color',[0.23 0.23 0.23],'LineWidth',1);
        p = S.pairwise_p_holm(k);
        textBoxLocal(fig,[(left+right)/2-0.11 y+0.002 0.22 0.032], ...
            sprintf('%s %s',pTextLocal(p),starsLocal(p,cfg.alpha)),cfg,10,'center','tex');
    end
end

function textBoxLocal(fig,pos,value,cfg,fontSize,align,interpreter)
    annotation(fig,'textbox',pos,'String',value,'Interpreter',interpreter, ...
        'EdgeColor','none','FontName',cfg.font_name,'FontSize',fontSize, ...
        'Color',[0.23 0.23 0.23],'HorizontalAlignment',align, ...
        'VerticalAlignment','middle','Margin',0);
end

function label = pTextLocal(p)
    if p < 0.001, label = '\bfP\rm<0.001';
    else, label = sprintf('\\bfP\\rm=%.3g',p); end
end

function stars = starsLocal(p,alpha)
    if p >= alpha, stars = 'ns';
    elseif p < 0.0001, stars = '****';
    elseif p < 0.001, stars = '***';
    elseif p < 0.01, stars = '**';
    else, stars = '*'; end
end

function saveFigureLocal(fig,cfg,base)
    if cfg.save_fig, savefig(fig,fullfile(cfg.output_dir,[base '.fig'])); end
    if cfg.save_png
        filename = fullfile(cfg.output_dir,[base '.png']);
        if exist('exportgraphics','file') == 2
            exportgraphics(fig,filename,'Resolution',cfg.png_dpi);
        else
            set(fig,'PaperPositionMode','auto');
            print(fig,filename,'-dpng',sprintf('-r%d',cfg.png_dpi));
        end
    end
    if cfg.save_svg
        set(fig,'PaperPositionMode','auto','Renderer','painters');
        print(fig,fullfile(cfg.output_dir,[base '.svg']),'-dsvg','-painters');
    end
    saved = cfg.save_fig || cfg.save_png || cfg.save_svg;
    if saved, fprintf('Saved figure: %s\n',base); end
    if saved && cfg.close_after_save, close(fig); end
end

function v = metaSettingLocal(M,name,fallback)
    if isfield(M.meta,name), v = M.meta.(name);
    elseif isfield(M.settings,name), v = M.settings.(name);
    else, v = fallback; end
end

function value = savedThresholdLocal(M)
    requireFieldsLocal(M,{'session_data'},'DSL-filtered summary');
    values = nan(1,numel(M.session_data));
    for k = 1:numel(values)
        R = recordAtLocal(M.session_data,k);
        requireFieldsLocal(R,{'DSL_threshold'},'saved session'); values(k) = R.DSL_threshold;
    end
    if isempty(values) || any(~isfinite(values)) || any(abs(values-values(1)) > 1e-10)
        error('Missing or inconsistent saved DSL thresholds.');
    end
    value = values(1);
end

function R = recordAtLocal(records,k)
    if iscell(records), R = records{k}; else, R = records(k); end
end

function mode = canonicalModeLocal(mode)
    switch lower(strtrim(char(mode)))
        case {'each_condition','condition_specific_models'}, mode = 'each_condition';
        case {'all_condition','all_condition_model'}, mode = 'all_condition';
        otherwise, error('model_mode must be each_condition or all_condition.');
    end
end

function indices = labelOrderLocal(actual,expected)
    actual = textListLocal(actual); expected = textListLocal(expected);
    actual = cellfun(@labelKeyLocal,actual,'UniformOutput',false);
    expected = cellfun(@labelKeyLocal,expected,'UniformOutput',false);
    if numel(unique(actual)) ~= numel(actual), error('Duplicate labels in input summary.'); end
    [ok,indices] = ismember(expected,actual);
    if ~all(ok), error('Required labels missing in summary: %s',strjoin(expected(~ok),', ')); end
end

function key = labelKeyLocal(value)
    key = lower(regexprep(char(value),'[^a-zA-Z0-9]',''));
    switch key
        case {'pattern','p'}, key = 'patterncell';
        case {'component','c'}, key = 'componentcell';
        case {'unclassified','u'}, key = 'unclassifiedcell';
        case 'ff', key = 'feedforward';
        case 'fb', key = 'feedback';
    end
end

function values = textListLocal(values)
    if ischar(values), values = cellstr(values);
    elseif isstring(values), values = cellstr(values); end
    if ~iscell(values), error('Expected a cell/string array of text labels.'); end
    values = reshape(values,1,[]);
    for k = 1:numel(values), values{k} = strtrim(char(values{k})); end
end

function requireFieldsLocal(S,names,context)
    if ~isstruct(S), error('%s must be a structure.',context); end
    for k = 1:numel(names)
        if ~isfield(S,names{k}), error('%s lacks %s.',context,names{k}); end
    end
end

function requireOptionLocal(value,options,name)
    if ~ismember(char(value),options), error('%s must be one of: %s.',name,strjoin(options,', ')); end
end

function checkSizeLocal(value,expected,name)
    actual = size(value); n = max(numel(actual),numel(expected));
    actual(end+1:n) = 1; expected(end+1:n) = 1;
    if ~isequal(actual,expected), error('%s has incompatible dimensions.',name); end
end

function checkFiniteOrNaNLocal(value,name)
    if ~isreal(value) || any(isinf(value(:))), error('%s must be real and finite or NaN.',name); end
end

function assertSameNumericLocal(a,b,name)
    checkSizeLocal(b,size(a),name);
    if ~isequal(isnan(a),isnan(b)), error('%s has inconsistent missing values.',name); end
    finite = isfinite(a) & isfinite(b);
    if any(isinf(a(:))) || any(isinf(b(:))) || ...
            any(abs(a(finite)-b(finite)) > 1e-10*max(1,max(abs(a(finite)),abs(b(finite)))))
        error('%s do not agree. Regenerate the matching upstream summary.',name);
    end
end

function path = absolutePathLocal(path)
    path = char(path);
    if isempty(path), path = pwd; return; end
    absolute = path(1) == '/' || strncmp(path,'\\',2) || ...
        ~isempty(regexp(path,'^[A-Za-z]:[\\/]','once'));
    if ~absolute, path = fullfile(pwd,path); end
end

function tag = safeTagLocal(value)
    tag = regexprep(char(value),'[^a-zA-Z0-9_-]','_');
end

function ensureDirLocal(folder)
    if ~isfolder(folder)
        [ok,msg] = mkdir(folder); if ~ok, error('Cannot create output folder: %s',msg); end
    end
end
