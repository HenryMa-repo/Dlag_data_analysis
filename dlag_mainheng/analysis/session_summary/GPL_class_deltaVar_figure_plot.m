%% GPL_class_deltaVar_figure_plot.m
% Standalone plotting/statistics script; no workspace variables are needed.
%
% INPUTS: saved across-session summaries establish the original session roster.
% NEW 2026-10-23: All/mean_count posterior analyses also read each session's
% PosteriorRawVarExtra, appended by the updated posterior_rawvar.m. No
% reconstruction is performed here. Normalize EACH neuron/condition before
% averaging neurons; zero/invalid mean count stays NaN and is excluded from
% that condition's neuron mean. Require all feature matches as before.
% All gets one separate three-row figure; no Z is computed in this script.
% Existing summary programs do not need to be rerun to include these extras.
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
variance_unit = 'count'; % 'count' or 'rate'; metadata bin_size is in SECONDS
% The existing normalization selector 'mean_count' means mean RESPONSE:
% count -> Var(count)/mean(count); rate -> Var(rate)/mean(rate).
% The rate scales are 1/dt^2 (unnormalized) and 1/dt (normalized).
variance_normalization = 'none'; % 'none' or 'mean_count' (variance / mean spikes per bin)
% 'mean_count' is POSTERIOR ONLY. For model variance keep 'none'; model
% normalization is not implemented yet. Select saved u0/u1 as above.
analyze_all_latent_feature_effects = true; % separate 3-row All figure; no All Z
% All/mean_count posterior inputs require the updated posterior_rawvar.m.
% Set this false and normalization='none' to use legacy session MAT files.
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
cfg = dvExtraConfigLocal(cfg,variance_normalization,analyze_all_latent_feature_effects);
cfg = dvUnitConfigLocal(cfg,variance_unit);
cfg = normalizeConfigLocal(cfg);

%% ============================ READ SUMMARIES ==========================
feature_input = []; class_input = [];
if cfg.analyze_balances || ((cfg.analyze_feature_effects || cfg.analyze_all_latent_feature_effects) && ...
        strcmp(cfg.feature_population_mode,'separate'))
    [M,filename] = loadSummaryLocal(cfg,'classes');
    class_input = unpackClassesLocal(M,filename,cfg);
    clear M;
end
if cfg.analyze_feature_effects || cfg.analyze_all_latent_feature_effects
    if strcmp(cfg.feature_population_mode,'pooled')
        [M,filename] = loadSummaryLocal(cfg,'pooled');
        feature_input = unpackPooledLocal(M,filename,cfg);
        clear M;
    else
        feature_input = class_input;
    end
end
cfg = resolveSavedFilterLocal(cfg,feature_input,class_input);
class_input = dvUpgradeSessionInputLocal(class_input,cfg);
if strcmp(cfg.feature_population_mode,'separate')
    feature_input=class_input;
else
    feature_input = dvUpgradeSessionInputLocal(feature_input,cfg);
end
reportObservationsLocal(feature_input,class_input);

%% ======================= CALCULATE AND TEST ===========================
definitions = featureDefinitionsLocal();
MultiSessionGPLClassDeltaVar = struct();
MultiSessionGPLClassDeltaVar.settings = cfg;
MultiSessionGPLClassDeltaVar.meta = struct( ...
    'created_by','GPL_class_deltaVar_figure_plot.m','created_on',datestr(now,30), ...
    'model_mode',cfg.model_mode,'variance_source',cfg.variance_source, ...
    'uncertainty_included',cfg.uncertainty_included_effective, ...
    'variance_normalization',cfg.variance_normalization, ...
    'variance_unit',cfg.variance_unit,'normalization_denominator',cfg.normalization_denominator, ...
    'analyze_all_latent_feature_effects',cfg.analyze_all_latent_feature_effects, ...
    'test_unit','session_direction','value_mode','raw', ...
    'population_definition','Pooled features include all model neurons; balances use P/C/U', ...
    'averaging_rule','All four matched feature differences / all eight balance conditions required', ...
    'one_sample_test','two-sided signrank vs zero; nominal P', ...
    'class_tests','Friedman then paired two-sided signrank; Holm across three pairs', ...
    'directions','Two directions remain separate observations; no averaging over directions');
MultiSessionGPLClassDeltaVar.feature = [];
MultiSessionGPLClassDeltaVar.balance = [];
MultiSessionGPLClassDeltaVar.panels = {};
MultiSessionGPLClassDeltaVar.all_latent_feature = [];
MultiSessionGPLClassDeltaVar.all_latent_panels = {};
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
if cfg.analyze_all_latent_feature_effects
    FAll=dvAllSessionFeaturesLocal(feature_input,definitions,cfg);
    MultiSessionGPLClassDeltaVar.all_latent_feature=FAll;
    acfg=cfg; acfg.latent_labels={'All'};
    for c=1:numel(FAll.population_labels)
        rowPanels=cell(1,3);
        for e=1:3
            P=featurePanelLocal(FAll,c,e,1,acfg);
            P.family='stimulus_feature_all_latent';
            P.figure_tag=sprintf('fdAll_3features_%s',FAll.population_tags{c});
            rowPanels{e}=computeTestsLocal(P,false,cfg);
        end
        MultiSessionGPLClassDeltaVar.all_latent_panels{c}=rowPanels;
    end
end
cfg.output_base = sprintf('GPLdVar_%s_r%03d_%s_%s_%s_%s_%s_%s_b%d_f%dq%d', ...
    safeTagLocal(cfg.data_content),cfg.runIdx,cfg.mapping_tag,cfg.mode_tag, ...
    cfg.source_tag,cfg.filter_tag,cfg.feature_population_mode,cfg.summary_stat, ...
    cfg.show_bar,cfg.analyze_feature_effects,cfg.analyze_balances);
cfg.output_base=sprintf('%s_%s_%s_a%d',cfg.output_base,cfg.normalization_tag,cfg.unit_tag, ...
    cfg.analyze_all_latent_feature_effects);
MultiSessionGPLClassDeltaVar.settings = cfg;
MultiSessionGPLClassDeltaVar.meta.output_base = cfg.output_base;
statPanels=MultiSessionGPLClassDeltaVar.panels;
for c=1:numel(MultiSessionGPLClassDeltaVar.all_latent_panels)
    statPanels=[statPanels MultiSessionGPLClassDeltaVar.all_latent_panels{c}]; %#ok<AGROW>
end
MultiSessionGPLClassDeltaVar.statistics_table = statisticsTableLocal(statPanels,cfg);
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
    for c=1:numel(MultiSessionGPLClassDeltaVar.all_latent_panels)
        rowPanels=MultiSessionGPLClassDeltaVar.all_latent_panels{c};
        fig=dvPlotAllSessionLocal(rowPanels,cfg);
        saveFigureLocal(fig,cfg,[cfg.output_base '_' rowPanels{1}.figure_tag]);
    end
end
fprintf('Done: %d panels; each point is one session x direction.\n', ...
    numel(statPanels));

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
    if ~cfg.analyze_feature_effects && ~cfg.analyze_balances && ~cfg.analyze_all_latent_feature_effects
        error('Enable feature effects, All latent feature effects and/or balances.');
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
    if strcmp(cfg.variance_unit,'rate') || (strcmp(cfg.variance_source,'posterior') && ...
            (strcmp(cfg.variance_normalization,'mean_count') || cfg.analyze_all_latent_feature_effects))
        requireFieldsLocal(M,{'session_data'},'summary for posterior Extra');
        D.session_records=M.session_data;
    end
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
    panelMode=isfield(cfg,'panel_figure');
    if panelMode
        fig=cfg.panel_figure; before=findall(fig);
    else
    fig = figure('Name',[P.effect_label ' | ' P.population], ...
        'NumberTitle','off','Color','w','Visible',cfg.figure_visible, ...
        'Position',[100 100 cfg.figure_width cfg.figure_height],'Renderer','painters');
    end
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
    yLabel=dvUnitAxisLabelLocal(P.ylabel,cfg);
    ylabel(ax,yLabel,'Interpreter','tex','FontName',cfg.font_name,'FontSize',cfg.axis_font_size+1);
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
    if panelMode, dvFitPanelLocal(fig,before,cfg.panel_rect); end
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

function D = dvUpgradeSessionInputLocal(D,cfg)
% The saved summary fixes the session roster/class membership. New values
% come from each neuron's saved Extra, before the population mean is taken.
    if isempty(D), return; end
    D.variance_normalization=cfg.variance_normalization;
    D.variance_unit=cfg.variance_unit;
    D.normalization_denominator=cfg.normalization_denominator;
    D.all_variance_mean=[];
    if strcmp(cfg.variance_source,'model')
        if cfg.analyze_all_latent_feature_effects
            % Model prior latent dimensions are independent; apply the same DSL selection.
            D.all_variance_mean=D.raw_variance_mean(:,:,:,:,1)+D.raw_variance_mean(:,:,:,:,2);
        end
        if strcmp(cfg.variance_unit,'rate'), D=dvScaleModelSessionUnitsLocal(D,cfg); end
        return;
    end
    if strcmp(cfg.variance_normalization,'none') && ~cfg.analyze_all_latent_feature_effects && ...
            strcmp(cfg.variance_unit,'count')
        return;
    end
    n=numel(D.observation_info); ng=numel(cfg.group_names); nc=numel(D.population_labels);
    D.original_n_neurons=D.n_neurons;
    D.bin_size_seconds=nan(n,1); D.unit_scale=ones(n,1);
    D.all_variance_mean=nan(n,ng,nc,8);
    D.all_n_neurons=nan(n,ng,nc,8);
    D.posterior_source_files=cell(n,1);
    D.normalization_excluded=cell(n,ng);
    pcfg=cfg; pcfg.model_dir=[cfg.model_mode '_mode'];
    pcfg.latent_labels={'Across','Within','Feedforward','Feedback','Ambiguous'};
    classNames={'pattern','component','unclassified'};
    sessions=unique([D.observation_info.session_index],'stable');
    for s=sessions(:)'
        obs=find([D.observation_info.session_index]==s);
        rec=recordAtLocal(D.session_records,s);
        sessionDir=char(rec.session_dir);
        if ~isfolder(sessionDir)
            parts=regexp(char(rec.session_name),'[\\/]','split');
            sessionDir=fullfile(cfg.root_dir,parts{:});
        end
        R=loadPosteriorNeuronVarianceLocal(sessionDir,pcfg);
        for o=obs(:)'
            d=D.observation_info(o).direction_index;
            if ~isequal(double(D.condition_ids(o,:)),double(R.condition_ids(:,d)')) || ...
                    D.observation_info(o).direction_value~=R.direction_values(d)
                error('Saved summary and per-session posterior condition/direction mapping disagree.');
            end
            D.posterior_source_files{o}=R.source_file;
            if strcmp(cfg.variance_unit,'rate')
                D.bin_size_seconds(o)=R.bin_size_seconds; D.unit_scale(o)=R.unit_scale;
            end
            for g=1:ng
                ids=R.unit_ids_by_group{g}; N=numel(ids);
                old=reshape(R.original_direction_variance{g}(:,:,d,1:4),N,8,4);
                chosen=reshape(R.direction_variance{g}(:,:,d,1:4),N,8,4);
                if cfg.analyze_all_latent_feature_effects
                    allV=reshape(R.direction_all_variance{g}(:,:,d),N,8);
                end
                if strcmp(cfg.variance_normalization,'mean_count')
                    counts=reshape(R.mean_count_by_direction{g}(:,:,d),N,8);
                    D.normalization_excluded{o,g}=struct('unit_ids',ids, ...
                        'mean_count',counts,'invalid',~isfinite(counts)|counts<=0);
                end
                for c=1:nc
                    rows=true(N,1);
                    if nc==3
                        info=rec.group(g).class_info;
                        if ~isequal(double(info.unit_ids(:)),ids)
                            error('Saved class membership and posterior neuron IDs/order differ.');
                        end
                        rows=logical(info.(classNames{c})(:));
                        if numel(rows)~=N, error('Invalid saved class membership length.'); end
                    elseif isfield(rec.group(g),'unit_ids') && ...
                            ~isequal(double(rec.group(g).unit_ids(:)),ids)
                        error('Saved pooled population and posterior neuron IDs/order differ.');
                    end
                    legacyMean=reshape(dvFiniteMeanLocal(old(rows,:,:),1),8,4);
                    saved=reshape(D.raw_variance_mean(o,g,c,:,:),8,4);
                    nvNearWithNaNLocal(saved,legacyMean,'saved summary versus original posterior means');
                    if strcmp(cfg.variance_normalization,'mean_count') || strcmp(cfg.variance_unit,'rate')
                        v=reshape(dvFiniteMeanLocal(chosen(rows,:,:),1),8,4);
                        D.raw_variance_mean(o,g,c,:,:)=reshape(v,1,1,1,8,4);
                        nn=sum(isfinite(chosen(rows,:,1)),1);
                        D.n_neurons(o,g,c,:)=reshape(nn,1,1,1,8);
                    end
                    if cfg.analyze_all_latent_feature_effects
                        D.all_variance_mean(o,g,c,:)=reshape(dvFiniteMeanLocal(allV(rows,:),1),1,1,1,8);
                        D.all_n_neurons(o,g,c,:)=reshape(sum(isfinite(allV(rows,:)),1),1,1,1,8);
                    end
                end
            end
        end
    end
    if isfield(D,'saved_balances') && ...
            (strcmp(cfg.variance_normalization,'mean_count') || strcmp(cfg.variance_unit,'rate'))
        V=D.raw_variance_mean;
        D.saved_balances=reshape(mean(V(:,:,:,:,[1 3])-V(:,:,:,:,[2 4]),4),n,ng,3,2);
    end
    D=rmfield(D,'session_records');
end

function y = dvFiniteMeanLocal(X,dim)
    keep=isfinite(X); count=sum(keep,dim); X(~keep)=0;
    y=sum(X,dim)./count; y(count==0)=NaN;
end

function F = dvAllSessionFeaturesLocal(D,definitions,cfg)
    F=D; V=D.all_variance_mean;
    n=size(V,1); ng=size(V,2); nc=size(V,3);
    F.latent_labels={'All'};
    F.values=nan(n,ng,nc,1,3);
    F.matched_differences=nan(n,ng,nc,1,4,3);
    F.definitions=definitions;
    for e=1:3
        X=V(:,:,:,definitions(e).positive)-V(:,:,:,definitions(e).negative);
        F.values(:,:,:,:,e)=reshape(mean(X,4),n,ng,nc,1);
        F.matched_differences(:,:,:,:,:,e)=reshape(X,n,ng,nc,1,4);
    end
    F.dimension_names={'session_direction','model_group','neuron_population','All','feature_effect'};
    F.n_points=reshape(sum(isfinite(F.values),1),ng,nc,1,3);
    F.population_mode=cfg.feature_population_mode;
    F.zscore_computed=false;
end

function fig = dvPlotAllSessionLocal(panels,cfg)
    fig=figure('Name','All latent | three stimulus features','NumberTitle','off', ...
        'Color','w','Visible',cfg.figure_visible,'Renderer','painters', ...
        'Position',[80 40 cfg.figure_width max(1100,round(1.8*cfg.figure_height))]);
    pcfg=cfg; pcfg.panel_figure=fig;
    for e=1:3
        pcfg.panel_rect=[0 (3-e)/3 1 1/3];
        plotPanelLocal(panels{e},pcfg);
    end
    fig.UserData=struct('panels',{panels},'settings',cfg,'zscore_computed',false);
end

function cfg = dvExtraConfigLocal(cfg,normalization,allEnabled)
    cfg.variance_source = lower(strtrim(char(cfg.variance_source)));
    cfg.variance_normalization = lower(strtrim(char(normalization)));
    if ~ismember(cfg.variance_normalization,{'none','mean_count'})
        error('variance_normalization must be ''none'' or ''mean_count''.');
    end
    if ~(isnumeric(allEnabled) || islogical(allEnabled)) || ...
            ~isscalar(allEnabled) || ~ismember(double(allEnabled),[0 1])
        error('analyze_all_latent_feature_effects must be a scalar 0 or 1.');
    end
    cfg.analyze_all_latent_feature_effects = logical(allEnabled);
    if strcmp(cfg.variance_normalization,'mean_count') && ...
            ~strcmp(cfg.variance_source,'posterior')
        error(['variance_normalization=''mean_count'' currently supports posterior only. ', ...
            'For model variance select ''none''; model normalization is not implemented.']);
    end
    cfg.normalization_tag = 'raw';
    if strcmp(cfg.variance_normalization,'mean_count'), cfg.normalization_tag='mc'; end
end

function E = nvReadExtraLocal(filename,P,cfg)
% Keep the legacy five-column variable authoritative. Only new options need Extra.
    E = [];
    if strcmp(cfg.variance_normalization,'none') && ~cfg.analyze_all_latent_feature_effects && ...
            strcmp(cfg.variance_unit,'count')
        return;
    end
    names = who('-file',filename);
    if ~ismember('PosteriorRawVarExtra',names)
        error(['Missing PosteriorRawVarExtra in %s. Run the updated posterior_rawvar.m ', ...
            'for this session/mode/u%d to append All and mean-count normalized results. ', ...
            'Alternatively use variance_normalization=''none'' and ', ...
            'analyze_all_latent_feature_effects=false for legacy inputs.'], ...
            filename,cfg.uncertainty_included);
    end
    S = load(filename,'PosteriorRawVarExtra'); E = S.PosteriorRawVarExtra;
    nvRequireLocal(E,{'format_version','meta','labels','condition_ids','condition'},'PosteriorRawVarExtra');
    if ~strcmp(char(E.format_version),'posterior_rawvar_extra_v1')
        error('Unsupported PosteriorRawVarExtra format in %s.',filename);
    end
    nvRequireLocal(E.meta,{'data_content','runIdx','model_mode','uncertainty_included', ...
        'variance_source','DSL_filter','variance_method','variance_normalization', ...
        'conditionShortLabels','dirValues'},'PosteriorRawVarExtra.meta');
    if ~strcmp(char(E.meta.data_content),cfg.data_content) || E.meta.runIdx~=cfg.runIdx || ...
            ~strcmp(char(E.meta.model_mode),cfg.model_mode) || ...
            ~isequal(double(E.meta.uncertainty_included),double(cfg.uncertainty_included)) || ...
            ~strcmp(char(E.meta.variance_source),'posterior') || ...
            ~strcmp(char(E.meta.DSL_filter),'all_latents') || ...
            ~strcmp(char(E.meta.variance_method),'across_trials_per_bin_mean_over_bins') || ...
            ~strcmp(char(E.meta.variance_normalization),'M-1')
        error('PosteriorRawVarExtra provenance disagrees with requested inputs: %s.',filename);
    end
    nvLabelOrderLocal([cfg.latent_labels {'All'}],E.labels);
    row = nvLabelOrderLocal(P.meta.conditionShortLabels,E.meta.conditionShortLabels);
    nvSizeLocal(E.condition_ids,[8 2],'Extra.condition_ids');
    if ~isequal(double(E.condition_ids(row,:)),double(P.condition_ids)) || ...
            ~isequal(double(E.meta.dirValues(:)),double(P.meta.dirValues(:))) || ...
            numel(E.condition)~=numel(P.condition) || ...
            ~isequal(sort(double([E.condition.condition_id])),sort(double([P.condition.condition_id])))
        error('Legacy and Extra condition/direction identities disagree in %s.',filename);
    end
    if isfield(E.meta,'original_created_on') && isfield(P.meta,'created_on') && ...
            ~strcmp(char(E.meta.original_created_on),char(P.meta.created_on))
        error('Extra belongs to a different legacy result; rerun posterior_rawvar.m: %s.',filename);
    end
end

function [Y,M,U,count] = nvSelectExtraLocal(Extra,E,A,g,cfg)
% Returns five original categories plus All, ordered by LABEL, never by position.
    Q = Extra.condition([Extra.condition.condition_id]==E.condition_id);
    if numel(Q)~=1 || numel(Q.group)~=numel(E.group) || ...
            Q.direction_index~=E.direction_index || Q.direction_value~=E.direction_value || ...
            Q.n_trials~=E.n_trials || Q.n_bins~=E.n_bins
        error('Extra condition metadata does not match the original posterior result.');
    end
    if isfield(Q,'trial_ids') && isfield(E,'trial_ids') && ~isequal(Q.trial_ids,E.trial_ids)
        error('Extra and original trial IDs/order differ.');
    end
    B=Q.group(g); N=numel(A.unit_ids);
    nvRequireLocal(B,{'unit_ids','n_neurons','raw_var','reconstruction_var', ...
        'uncertainty_var'},'Extra group');
    if ~isequal(double(B.unit_ids(:)),double(A.unit_ids(:))) || B.n_neurons~=N
        error('Extra and legacy neuron IDs/order differ in group %d.',g);
    end
    cols=nvLabelOrderLocal([cfg.latent_labels {'All'}],Extra.labels);
    for f={'raw_var','reconstruction_var','uncertainty_var'}
        nvSizeLocal(B.(f{1}),[N 6],['Extra.' f{1}]);
    end
    Y=double(B.raw_var(:,cols)); M=double(B.reconstruction_var(:,cols));
    U=double(B.uncertainty_var(:,cols)); count=nan(N,1);
    nvVarianceLocal(Y,'Extra raw variance'); nvVarianceLocal(M,'Extra reconstruction');
    % A has already been reordered to the required five labels by the caller.
    nvNearLocal(Y(:,1:5),A.raw_var,'Extra versus legacy raw variance');
    nvNearLocal(M(:,1:5),A.reconstruction_var,'Extra versus legacy reconstruction');
    if cfg.uncertainty_included
        nvVarianceLocal(U,'Extra uncertainty');
        nvNearLocal(U(:,1:5),A.uncertainty_var,'Extra versus legacy uncertainty');
        nvNearLocal(Y,M+U,'Extra raw = reconstruction + uncertainty');
    else
        nvNearLocal(Y,M,'Extra raw = reconstruction');
    end
    if ~strcmp(cfg.variance_normalization,'mean_count'), return; end
    nvRequireLocal(B,{'mean_count','normalization_valid','normalized_var', ...
        'normalized_reconstruction_var','normalized_uncertainty_var'},'Extra normalized group');
    count=double(B.mean_count(:)); nvSizeLocal(count,[N 1],'mean_count');
    valid=isfinite(count) & count>0;
    flag=double(B.normalization_valid(:));
    if numel(flag)~=N || any(~ismember(flag,[0 1])) || ~isequal(logical(flag),valid)
        error('Extra normalization_valid disagrees with mean_count.');
    end
    den=count; den(~valid)=NaN;
    for f={'normalized_var','normalized_reconstruction_var','normalized_uncertainty_var'}
        nvSizeLocal(B.(f{1}),[N 6],['Extra.' f{1}]);
    end
    NY=double(B.normalized_var(:,cols)); NM=double(B.normalized_reconstruction_var(:,cols));
    NU=double(B.normalized_uncertainty_var(:,cols));
    nvSelectedVarianceLocal(NY,'normalized variance',true);
    nvSelectedVarianceLocal(NM,'normalized reconstruction',true);
    nvNearWithNaNLocal(NY,bsxfun(@rdivide,Y,den),'normalized variance / mean_count');
    nvNearWithNaNLocal(NM,bsxfun(@rdivide,M,den),'normalized reconstruction / mean_count');
    if cfg.uncertainty_included
        nvSelectedVarianceLocal(NU,'normalized uncertainty',true);
        nvNearWithNaNLocal(NU,bsxfun(@rdivide,U,den),'normalized uncertainty / mean_count');
        nvNearWithNaNLocal(NY,NM+NU,'normalized variance decomposition');
    end
    Y=NY; M=NM; U=NU;
end

function nvSelectedVarianceLocal(X,label,allowNaN)
    if ~allowNaN, nvVarianceLocal(X,label); return; end
    if ~isnumeric(X) || ~isreal(X) || any(isinf(X(:))) || any(X(:)<0)
        error('%s must contain nonnegative finite values or NaN for invalid mean count.',label);
    end
end

function nvNearWithNaNLocal(A,B,label)
    if ~isequal(size(A),size(B)) || ~isequal(isnan(A),isnan(B)) || ...
            any(isinf(A(:))) || any(isinf(B(:)))
        error('%s: sizes or missing-value masks disagree.',label);
    end
    good=isfinite(A) & isfinite(B);
    nvNearLocal(A(good),B(good),label);
end

function dvFitPanelLocal(fig,before,rect)
% Reuse the unchanged renderer, then place its new axes/legend/text in one row.
% No figure/axes are copied, so legends keep their original data handles.
    current=findall(fig);
    added=current(~ismember(current,before));
    for pass=1:2
        for k=1:numel(added)
            h=added(k); kind=get(h,'Type');
            isAxis=strcmp(kind,'axes');
            if (pass==1 && isAxis) || (pass==2 && ~isAxis), continue; end
            if ~ismember(kind,{'axes','legend','textboxshape'}), continue; end
            set(h,'Units','normalized'); p=get(h,'Position');
            set(h,'Position',[rect(1)+p(1)*rect(3),rect(2)+p(2)*rect(4), ...
                p(3)*rect(3),p(4)*rect(4)]);
        end
    end
end

function R = loadPosteriorNeuronVarianceLocal(sessionDir,cfg)
    [filename,usedLegacy]=nvPosteriorFileLocal(sessionDir,cfg);
    S=load(filename,'PosteriorRawVar'); nvRequireLocal(S,{'PosteriorRawVar'},filename);
    P=S.PosteriorRawVar;
    nvRequireLocal(P,{'format_version','meta','labels','condition_ids','condition'},filename);
    nvValidatePosteriorModeLocal(P,cfg,usedLegacy);
    nvRequireLocal(P.meta,{'data_content','runIdx','uncertainty_included', ...
        'variance_source','DSL_filter','variance_method','variance_normalization', ...
        'conditionShortLabels','dirValues'},'PosteriorRawVar.meta');
    if ~strcmp(char(P.meta.data_content),cfg.data_content) || P.meta.runIdx~=cfg.runIdx || ...
            ~isequal(double(P.meta.uncertainty_included),double(cfg.uncertainty_included)) || ...
            ~strcmp(char(P.meta.variance_source),'posterior') || ...
            ~strcmp(char(P.meta.DSL_filter),'all_latents')
        error('Posterior content/run/mode/uncertainty/filter provenance mismatch.');
    end
    if ~strcmp(P.meta.variance_method,'across_trials_per_bin_mean_over_bins') || ...
            ~strcmp(P.meta.variance_normalization,'M-1')
        error('Require posterior per-bin M-1 trial variance averaged over bins.');
    end
    rowOrder=nvLabelOrderLocal(cfg.condition_labels,P.meta.conditionShortLabels);
    colOrder=nvLabelOrderLocal(cfg.latent_labels,P.labels);
    nvSizeLocal(P.condition_ids,[8 2],'posterior condition_ids');
    ng=numel(cfg.group_names);
    R=struct('source_file',filename,'direction_values',double(P.meta.dirValues(:)'), ...
        'condition_ids',double(P.condition_ids(rowOrder,:)), ...
        'unit_ids_by_group',{cell(1,ng)},'direction_variance',{cell(1,ng)}, ...
        'reconstruction_by_direction',{cell(1,ng)}, ...
        'uncertainty_by_direction',{cell(1,ng)}, ...
        'bestmodel_files',{cell(8,2)},'DSL_threshold',NaN, ...
        'input_format_version',char(P.format_version));
    Extra=nvReadExtraLocal(filename,P,cfg);
    R.original_direction_variance=cell(1,ng);
    R.direction_all_variance=cell(1,ng);
    R.mean_count_by_direction=cell(1,ng);
    R.variance_normalization=cfg.variance_normalization;
    conditionIds=double([P.condition.condition_id]);
    if numel(conditionIds)~=16 || numel(unique(conditionIds))~=16 || ...
            ~isequal(sort(conditionIds(:)),sort(R.condition_ids(:)))
        error('Posterior output must contain exactly all 16 direction/condition entries.');
    end
    for d=1:2
        for st=1:8
            E=P.condition(conditionIds==R.condition_ids(st,d));
            nvRequireLocal(E,{'feature_index','direction_index','direction_value','group', ...
                'n_trials','n_bins','bestmodel_file'},'posterior condition');
            if E.feature_index~=rowOrder(st) || E.direction_index~=d || ...
                    E.direction_value~=R.direction_values(d) || numel(E.group)~=ng || ...
                    E.n_trials<2 || E.n_bins<1
                error('Posterior condition positions/counts/groups disagree with metadata.');
            end
            R.bestmodel_files{st,d}=E.bestmodel_file;
            for g=1:ng
                A=E.group(g);
                nvRequireLocal(A,{'unit_ids','n_neurons','raw_var','reconstruction_var', ...
                    'uncertainty_var'},'posterior group');
                ids=nvIdsLocal(A.unit_ids); N=numel(ids);
                if A.n_neurons~=N, error('Posterior neuron count mismatch.'); end
                if isempty(R.unit_ids_by_group{g})
                    R.unit_ids_by_group{g}=ids;
                    R.direction_variance{g}=nan(N,8,2,5);
                    R.original_direction_variance{g}=nan(N,8,2,5);
                    R.direction_all_variance{g}=nan(N,8,2);
                    R.mean_count_by_direction{g}=nan(N,8,2);
                    R.reconstruction_by_direction{g}=nan(N,8,2,5);
                    R.uncertainty_by_direction{g}=nan(N,8,2,5);
                elseif ~isequal(ids,R.unit_ids_by_group{g})
                    error('Posterior neuron IDs/order change across conditions in group %d.',g);
                end
                for f={'raw_var','reconstruction_var','uncertainty_var'}
                    nvSizeLocal(A.(f{1}),[N 5],['posterior ' f{1}]);
                end
                Y=double(A.raw_var(:,colOrder));
                M=double(A.reconstruction_var(:,colOrder));
                U=double(A.uncertainty_var(:,colOrder));
                nvVarianceLocal(Y,'posterior raw variance');
                nvVarianceLocal(M,'posterior reconstruction variance');
                if cfg.uncertainty_included
                    nvVarianceLocal(U,'posterior uncertainty');
                    nvNearLocal(Y,M+U,'posterior raw = reconstruction + uncertainty');
                else
                    nvNearLocal(Y,M,'posterior raw = reconstruction');
                end
                R.original_direction_variance{g}(:,st,d,:)=reshape(Y,N,1,1,5);
                if ~isempty(Extra)
                    ordered=A; ordered.raw_var=Y; ordered.reconstruction_var=M; ordered.uncertainty_var=U;
                    [EY,EM,EU,count]=nvSelectExtraLocal(Extra,E,ordered,g,cfg);
                    Y=EY(:,1:5); M=EM(:,1:5); U=EU(:,1:5);
                    if cfg.analyze_all_latent_feature_effects
                        R.direction_all_variance{g}(:,st,d)=EY(:,6);
                    end
                    R.mean_count_by_direction{g}(:,st,d)=count;
                end
                R.direction_variance{g}(:,st,d,:)=reshape(Y,N,1,1,5);
                R.reconstruction_by_direction{g}(:,st,d,:)=reshape(M,N,1,1,5);
                R.uncertainty_by_direction{g}(:,st,d,:)=reshape(U,N,1,1,5);
            end
        end
    end
    if strcmp(cfg.variance_unit,'rate')
        dt=dvBinSecondsLocal(Extra.meta,'PosteriorRawVarExtra.meta');
        R=dvScaleDirectionUnitsLocal(R,cfg,dt);
    end

end


function order=nvLabelOrderLocal(expected,actual)
    actual=cellstr(string(actual(:)'));
    [ok,order]=ismember(expected,actual);
    if numel(actual)~=numel(expected) || ~all(ok) || numel(unique(order))~=numel(expected)
        error('Saved labels do not match the required condition/category labels.');
    end
end


function ids=nvIdsLocal(ids)
    ids=double(ids(:));
    if isempty(ids) || any(~isfinite(ids)) || numel(unique(ids))~=numel(ids)
        error('Model-used neuron IDs must be finite, nonempty, and unique within area.');
    end
end


function nvSizeLocal(X,expected,label)
    actual=size(X); n=max(numel(actual),numel(expected));
    actual(end+1:n)=1; expected(end+1:n)=1;
    if ~isnumeric(X) || ~isreal(X) || ~isequal(actual,expected)
        error('%s has size %s; expected %s.',label,mat2str(size(X)),mat2str(expected));
    end
end


function nvVarianceLocal(X,label)
    if ~isreal(X) || any(~isfinite(X(:))) || any(X(:)<0)
        error('%s must contain finite nonnegative variances.',label);
    end
end


function nvNearLocal(A,B,label)
    if ~isequal(size(A),size(B)) || any(~isfinite(A(:))) || any(~isfinite(B(:)))
        error('%s: invalid values or incompatible sizes.',label);
    end
    if ~isempty(A) && max(abs(A(:)-B(:)))>1e-8*max(1,max(abs(B(:))))
        error('%s: values disagree.',label);
    end
end


function nvRequireLocal(S,fields,label)
    if ~isstruct(S) || isempty(S), error('%s must be a nonempty struct.',label); end
    for k=1:numel(fields)
        if ~isfield(S,fields{k}), error('%s is missing %s.',label,fields{k}); end
    end
end


function [filename,usedLegacy] = nvPosteriorFileLocal(sessionDir,cfg)
    filename = fullfile(sessionDir,cfg.model_dir,'posterior_rawvar', ...
        sprintf('postVar_%s_r%03d_%s_u%d.mat',cfg.data_content,cfg.runIdx, ...
        cfg.mode_tag,cfg.uncertainty_included));
    usedLegacy = false;
    if isfile(filename), return; end
    % Only each-condition mode may use an old, untagged v1 file. A present
    % new file is authoritative; validation errors never trigger fallback.
    if strcmp(cfg.model_mode,'each_condition')
        legacy = fullfile(sessionDir,'each_condition_mode','posterior_rawvar', ...
            sprintf('postVar_%s_r%03d_u%d.mat',cfg.data_content,cfg.runIdx,cfg.uncertainty_included));
        if isfile(legacy)
            filename = legacy;
            usedLegacy = true;
            fprintf('Using legacy each-condition posterior file: %s\n',filename);
            return;
        end
    end
    error(['Missing %s. Run posterior_rawvar.m in this session with matching ', ...
        'data_condition (1:16 for each_condition; [] for all_condition), ', ...
        'data_content, runIdx and uncertainty_included.'],filename);
end



function nvValidatePosteriorModeLocal(P,cfg,usedLegacy)
    version = char(P.format_version);
    if strcmp(version,'posterior_rawvar_eachcond_v1')
        if ~usedLegacy || ~strcmp(cfg.model_mode,'each_condition')
            error('Legacy posterior data are valid only at the old each-condition path.');
        end
        if isfield(P.meta,'model_mode') && ~strcmp(char(P.meta.model_mode),'each_condition')
            error('Legacy posterior model mode is inconsistent.');
        end
        return;
    end
    if ~strcmp(version,'posterior_rawvar_v2')
        error('Unsupported PosteriorRawVar format: %s.',version);
    end
    nvRequireLocal(P.meta,{'model_mode','mode_tag','data_condition'},'PosteriorRawVar.meta');
    if ~strcmp(char(P.meta.model_mode),cfg.model_mode) || ~strcmp(char(P.meta.mode_tag),cfg.mode_tag)
        error('Posterior model mode disagrees with model_mode; results are not mixed.');
    end
    if strcmp(cfg.model_mode,'all_condition')
        if ~isempty(P.meta.data_condition)
            error('All-condition posterior metadata must record data_condition = [].');
        end
    elseif ~isequal(sort(double(P.meta.data_condition(:))),sort(double([P.condition.condition_id]')))
        error('Each-condition posterior selection disagrees with its condition entries.');
    end
    trialIds = [];
    for ci = 1:numel(P.condition)
        E = P.condition(ci);
        nvRequireLocal(E,{'model_mode','model_condition_id','bestmodel_file', ...
            'condition_id','n_trials','trial_ids','group'},'PosteriorRawVar.condition');
        if ~strcmp(char(E.model_mode),cfg.model_mode)
            error('A posterior condition has a different model mode.');
        end
        if strcmp(cfg.model_mode,'each_condition')
            if ~isequal(double(E.model_condition_id),double(E.condition_id))
                error('Condition-specific model ID disagrees with its output condition.');
            end
        else
            if ~isempty(E.model_condition_id) || ...
                    ~strcmp(char(E.bestmodel_file),char(P.condition(1).bestmodel_file))
                error('All-condition posterior entries must come from one shared model.');
            end
            ids = double(E.trial_ids(:)');
            if numel(ids) ~= E.n_trials || any(~isfinite(ids) | ids<1 | ids~=round(ids))
                error('Invalid trial IDs in all-condition posterior output.');
            end
            trialIds = [trialIds ids]; %#ok<AGROW>
            if numel(E.group) ~= numel(P.condition(1).group)
                error('All-condition model group count changes across conditions.');
            end
            for g = 1:numel(E.group)
                G = E.group(g); reference = P.condition(1).group(g);
                if ~isequal(G.counts,reference.counts) || G.nLatents ~= reference.nLatents || ...
                        ~isequal(G.category_indices,reference.category_indices)
                    error('All-condition latent classification changes across conditions.');
                end
            end
        end
    end
    if numel(unique(trialIds)) ~= numel(trialIds)
        error('An all-condition posterior trial appears in more than one condition.');
    end
end



function cfg = dvUnitConfigLocal(cfg,unit)
    cfg.variance_unit=lower(strtrim(char(unit)));
    if ~ismember(cfg.variance_unit,{'count','rate'})
        error('variance_unit must be ''count'' or ''rate''.');
    end
    if strcmp(cfg.variance_unit,'rate') && ~contains(lower(cfg.data_content),'count')
        error('variance_unit=''rate'' converts count-based data_content; do not convert already-rate or z-scored inputs.');
    end
    cfg.unit_tag='ct'; cfg.normalization_denominator='none';
    if strcmp(cfg.variance_unit,'rate'), cfg.unit_tag='hz'; end
    if strcmp(cfg.variance_normalization,'mean_count')
        if strcmp(cfg.variance_unit,'rate'), cfg.normalization_denominator='mean_rate';
        else, cfg.normalization_denominator='mean_count'; end
    end
end

function R = dvScaleDirectionUnitsLocal(R,cfg,dt)
% Apply the selected unit BEFORE directions, contrasts and Z baselines.
% original_direction_variance remains in count units for legacy validation.
    R.bin_size_seconds=dt; R.variance_unit=cfg.variance_unit;
    R.normalization_denominator=cfg.normalization_denominator;
    R.unit_scale=1;
    if ~strcmp(cfg.variance_unit,'rate'), return; end
    power=2;
    if strcmp(cfg.variance_normalization,'mean_count'), power=1; end
    R.unit_scale=1/dt^power;
    for f={'direction_variance','direction_all_variance', ...
            'reconstruction_by_direction','uncertainty_by_direction'}
        if ~isfield(R,f{1}), continue; end
        for g=1:numel(R.(f{1}))
            R.(f{1}){g}=R.(f{1}){g}./(dt^power);
        end
    end
    if isfield(R,'mean_count_by_direction')
        R.mean_rate_by_direction=cell(size(R.mean_count_by_direction));
        for g=1:numel(R.mean_count_by_direction)
            R.mean_rate_by_direction{g}=R.mean_count_by_direction{g}./dt;
        end
    end
end

function dt = dvModelBinSecondsLocal(sessionDir,meta)
% Match the model's saved stimulus tag, rather than assuming a run index.
    if isfield(meta,'bin_size') || isfield(meta,'bin_size_seconds')
        dt=dvBinSecondsLocal(meta,'model variance metadata'); return;
    end
    if ~isfield(meta,'stim_tag') || isempty(meta.stim_tag)
        error('Model variance metadata lacks stim_tag needed to select the bin width.');
    end
    filename=fullfile(sessionDir,'model_data_allruns.mat');
    if ~isfile(filename), error('Missing bin-width metadata: %s',filename); end
    S=load(filename,'model_data_allruns');
    if ~isfield(S,'model_data_allruns') || ~iscell(S.model_data_allruns)
        error('model_data_allruns must be a cell array in %s.',filename);
    end
    tags=cellfun(@(x)char(x.stim_tag),S.model_data_allruns,'UniformOutput',false);
    index=find(strcmp(tags,char(meta.stim_tag)));
    if numel(index)~=1, error('The model stim_tag does not select exactly one bin-width metadata entry.'); end
    dt=dvBinSecondsLocal(S.model_data_allruns{index},filename);
end

function label = dvUnitAxisLabelLocal(label,cfg)
    normalized=strcmp(cfg.variance_normalization,'mean_count');
    if strcmp(cfg.variance_unit,'count')
        if normalized && isempty(strfind(label,'mean count')) %#ok<STREMP>
            label=strrep(label,'Z(Var)','Z(Var / mean count)');
            if isempty(strfind(label,'mean count')) %#ok<STREMP>
                label=strrep(label,'Var','(Var / mean count)');
            end
        end
        return;
    end
    % A pre-built All ylabel may already mention its count normalization.
    if ~isempty(strfind(label,'mean count')) %#ok<STREMP>
        label=strrep(label,'Var','Var(rate)');
        label=strrep(label,'mean count','mean rate');
    elseif normalized
        label=strrep(label,'Z(Var)','Z(Var(rate) / mean rate)');
        if isempty(strfind(label,'mean rate')) %#ok<STREMP>
            label=strrep(label,'Var','(Var(rate) / mean rate)');
        end
    else
        label=strrep(label,'Var','Var(rate)');
    end
end

function dt = dvBinSecondsLocal(meta,context)
% processing_to_count_and_fr stores bin_size/bin_edges/bin_centers in SECONDS.
    dt=NaN;
    if isfield(meta,'bin_size_seconds') && ~isempty(meta.bin_size_seconds)
        dt=double(meta.bin_size_seconds);
    elseif isfield(meta,'bin_size') && ~isempty(meta.bin_size)
        dt=double(meta.bin_size);
    end
    if ~isnumeric(dt) || ~isreal(dt) || ~isscalar(dt) || ~isfinite(dt) || dt<=0
        error('variance_units:BinWidth', ...
            '%s must provide a finite positive bin_size in seconds; no bin width is guessed.',context);
    end
    if isfield(meta,'bin_size') && isnumeric(meta.bin_size) && ...
            isscalar(meta.bin_size) && isfinite(meta.bin_size) && ...
            abs(double(meta.bin_size)-dt)>1e-9*max(dt,eps)
        error('variance_units:BinWidth','bin_size and bin_size_seconds disagree in %s.',context);
    end
    for f={'bin_edges','bin_centers'}
        if ~isfield(meta,f{1}) || isempty(meta.(f{1})), continue; end
        v=double(meta.(f{1}));
        if ~isreal(v) || ~isvector(v) || any(~isfinite(v(:)))
            error('variance_units:BinWidth','Invalid %s in %s.',f{1},context);
        end
        if numel(v)>1 && any(abs(diff(v(:))-dt)>1e-7*max(dt,eps))
            error('variance_units:BinWidth','%s does not match bin_size in seconds in %s.',f{1},context);
        end
    end
end

function D = dvScaleModelSessionUnitsLocal(D,cfg)
    D.variance_unit=cfg.variance_unit;
    if ~strcmp(cfg.variance_unit,'rate'), return; end
    n=numel(D.observation_info);
    D.bin_size_seconds=nan(n,1); D.unit_scale=nan(n,1);
    sessions=unique([D.observation_info.session_index],'stable');
    for s=sessions(:)'
        rec=recordAtLocal(D.session_records,s);
        sessionDir=char(rec.session_dir);
        if ~isfolder(sessionDir)
            parts=regexp(char(rec.session_name),'[\\/]','split');
            sessionDir=fullfile(cfg.root_dir,parts{:});
        end
        if ~isfield(rec,'bestmodel_files') || isempty(rec.bestmodel_files)
            error('Saved model summary lacks bestmodel_files needed for the rate conversion.');
        end
        candidates=rec.bestmodel_files;
        index=find(~cellfun(@isempty,candidates),1);
        if isempty(index), error('Saved model summary has no source bestmodel path.'); end
        file=char(candidates{index});
        if ~isfile(file)
            old=strrep(file,'\',filesep); [~,name,ext]=fileparts(old);
            cond=rec.condition_ids(index);
            file=fullfile(sessionDir,sprintf('FA_Dlag_%s_condition%d',cfg.data_content,cond), ...
                'mat_results',sprintf('run%03d',cfg.runIdx),[name ext]);
        end
        if ~isfile(file), error('Missing model source for bin-width selection: %s',file); end
        S=load(file,'varexp_raw');
        if ~isfield(S,'varexp_raw') || ~isfield(S.varexp_raw,'meta')
            error('Missing varexp_raw.meta in %s.',file);
        end
        dt=dvModelBinSecondsLocal(sessionDir,S.varexp_raw.meta);
        obs=find([D.observation_info.session_index]==s);
        D.raw_variance_mean(obs,:,:,:,:)=D.raw_variance_mean(obs,:,:,:,:)./(dt^2);
        if ~isempty(D.all_variance_mean)
            D.all_variance_mean(obs,:,:,:)=D.all_variance_mean(obs,:,:,:)./(dt^2);
        end
        if isfield(D,'saved_balances'), D.saved_balances(obs,:,:,:)=D.saved_balances(obs,:,:,:)./(dt^2); end
        D.bin_size_seconds(obs)=dt; D.unit_scale(obs)=1/dt^2;
    end
    D=rmfield(D,'session_records');
end
