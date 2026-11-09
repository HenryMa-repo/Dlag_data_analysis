%% var_stimuli_depended_balance_change.m
% Stimulus dependence of component percentages: observed TOTAL or SHARED.
% All-condition POSTERIOR only; unnormalized COUNT variance, no Z score.
% Input: all_condition_mode/posterior_rawvar/postVar_*_allcond_u0/u1.mat.
% No input MAT is modified and no model is refitted/reconstructed here.
%
% variance_denominator='total': original observed-Total analysis.
%   Requires PosteriorRawVarExtra, PosteriorRawVarNoise, PosteriorRawVarTotal.
%   Total = mean_t var_trial(seqEst.y,0), M-1; no uncertainty added to Total.
%   Latent and residual-Noise numerators use the selected u0/u1 result.
%   Noise = y - All reconstruction (with its saved u1 correction if selected).
% variance_denominator='shared': percentage of All-latent shared variance.
%   Requires ONLY PosteriorRawVarExtra. Noise/Total are not read or analyzed.
%   Denominator = raw_var in the label-matched All column: joint All-latent
%   reconstruction variance, including cross-latent covariance. NEVER replace
%   it with Across + Within or a sum of individual latent variances.
%   u0: posterior-mean variance in BOTH numerator and denominator.
%   u1: saved posterior-uncertainty correction in BOTH, including full All
%       posterior covariance for the denominator. All includes Ambiguous.
%
% RATIOS FIRST, ENDPOINT MEANS SECOND, SUBTRACTION LAST:
%   D = observed Total ('total') or joint All-latent variance ('shared').
%   neuron : P(n,c,d,k) = 100 * V(n,c,d,k) / D(n,c,d).
%   session: P(s,c,d,k) = 100 * sum_n V(n,c,d,k) / sum_n D(n,c,d),
%            with the SAME selected neurons in both sums (ratio of means,
%            NOT a mean of neuron percentages).
% Compute all 16 condition x direction ratios BEFORE any condition averaging.
% Neuron: one observation/neuron; average both directions and other features.
% Session: one observation/session x direction; directions remain separate.
% Endpoints always use arithmetic MEAN. summary_center controls only the
% displayed center across observations. Delta is FIRST minus SECOND:
%   Grating - Plaid; Small - Large; Low - High, in PERCENTAGE POINTS.
% This is not own-baseline percentage change.
%
% Zero denominator -> undefined neuron ratio (NaN), never epsilon/clipping.
% Population ratios require a positive denominator SUM; zero-denominator
% neurons still enter both sums. Matched endpoint means retain the SAME
% finite condition pairs; neuron matches must have BOTH directions.
% No valid match -> NaN. Component percentages can exceed 100 and need not
% sum to 100 because reconstructed components can covary; FF/FB overlap Across.
%
% FIGURES: 3 feature rows; separate area/component axes, area1 before area2.
% component_pair='within_across': Within then Across in each area.
% component_pair='ff_fb': FF then FB in each area.
%   total : 3 x 6; append Noise after each area's two selected components.
%   shared: 3 x 4; NO Noise column or Noise statistics.
% comparison_plot_mode='paired': display the two averaged percentage endpoints.
%   total : original lines; independent neuron/session individual-line toggles.
%   shared: two BARS + optional errors; NO individual or summary connecting
%           lines. Both individual-line toggles are ignored in shared mode.
%   summary_center='mean'/'median'; error_type='sem'/'std'/'none'. SEM remains
%   sample SD/sqrt(N), not a median confidence interval. Both bars/summaries
%   use exactly the same complete observation pairs as the statistical test.
% comparison_plot_mode='delta': original violin/dot/IQR/whisker style,
%   FIRST minus SECOND, with optional full-range outlier inset.
% Both modes test the SAME per-observation deltas, two-sided against zero.
% Difference of displayed medians need not equal median of paired deltas.
% Legend n counts contributing NEURONS, once per session/unit. Test n counts
% observations (neurons or session-directions). Nominal P; no cluster or
% multiple-comparison adjustment. ALL finite deltas enter the test, including
% points hidden by plot zoom. signrank/ttest require Statistics Toolbox.
%
% Saved summary: VarStimuliBalanceChange, in a separate MAT file.
% total mode retains its original five data columns/field names (v2).
% shared mode stores four columns Across/Within/FF/FB, shared_variance,
% neuron_percent_shared / population_percent_shared and shared sums (v3).
% Output names include total/shared, layout, family and paired/delta.

% FIGURE OUTPUT:
% figure_layout='combined': the original complete grid, using figure_width/height.
% figure_layout='separate': one figure per MAIN panel, using single_figure_width/
% single_figure_height (pixels). Any violin inset stays with its parent panel.
% The same save_png/save_fig/save_svg and close_after_save settings apply to
% every figure. Saving disabled still allows drawing, as in the original.
% Separate filenames add feature/area/component IDs; histograms, when present,
% keep both areas in ONE figure. The summary MAT still contains ALL panels.
% paired_ylim_mode='tight' fits ONLY displayed LINE endpoints and error bars;
% displayed individual lines also contribute their full ranges. Zero is NOT
% forced into the axis. 'zero_based' includes zero as in the original.
% paired_ylim_padding=[lower upper] gives margins as fractions of that span.
% These limits apply to paired LINES in BOTH layouts. Shared bars keep their
% zero baseline; histograms and delta violins retain their original scale rules.
%

clc; clear;

%% -------------------------- USER SETTINGS -----------------------------
root_dir = 'I:\np_data';
session_dirs = {}; % {} discovers catgt_* at root or one level below root.
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;
uncertainty_included = 0; % shared: same u0/u1 for numerator AND All denominator
variance_denominator = 'shared'; % 'total' (original) or 'shared' (All latent; no Noise)
summary_unit = 'neuron'; % 'neuron' or 'session' (= session x direction)
comparison_plot_mode = 'delta'; % 'paired': shared BARS / total LINES; 'delta': violin
component_pair = 'within_across'; % 'within_across' or 'ff_fb'; Noise only in total mode
neuron_population = 'all_neurons'; % 'all_neurons' includes invalid; or 'pcu_neurons'
group_names = {'V1','MT'}; % Two areas, in MODEL GROUP order
gpl_mat_name = 'unit_gpl_results_sponsub.mat'; % Only read for pcu_neurons
skip_missing_sessions = true; % Missing required input reported; malformed input errors

summary_center = 'median'; % 'mean' or 'median'; display center across observations
error_type = 'sem'; % 'sem', 'std', or 'none'; PAIRED endpoint errors only
show_session_individual_lines = true; % TOTAL + PAIRED session mode only
show_neuron_individual_lines = false; % TOTAL + PAIRED neuron mode only
test_method = 'signrank'; % 'signrank' or 'ttest'; always TWO-SIDED against zero
significance_alpha = 0.05;
show_p_values = true;
area_colors = [0.0000 0.4470 0.7410; 0.8500 0.3250 0.0980];
% Total-mode paired LINE style, in display order; shared paired uses bars.
component_line_styles = {'-','--',':'};
component_markers = {'o','s','^'};
individual_gray = 0.86; individual_line_width = 0.6;
summary_gray = 0.20; summary_line_width = 3.0;
summary_marker_size = 10;
% The following outlier/violin options apply only to comparison_plot_mode='delta'.
poster_outlier_mode = 'zoom_inset'; % 'zoom_inset' or 'full_range'
poster_show_inset = false;
poster_central_percentile = 70;
poster_point_size = 9; poster_point_alpha = 0.45;
poster_point_jitter_width = 0.12;
poster_violin_width = 0.25; poster_violin_alpha = 0.18;
poster_violin_point_spread_gain = 1.3;
poster_violin_point_edge_fraction = 0.90;
font_name = 'Arial'; font_size = 10;
figure_width = 3600; figure_height = 900; % total: six / shared: four panels per row
figure_layout = 'separate'; % 'combined' (original grid) or 'separate' (one panel/figure)
single_figure_width = 640;  % pixels; only figure_layout='separate'
single_figure_height = 520; % pixels; original figure_width/height are for 'combined'
paired_ylim_mode = 'tight'; % paired LINES only: 'tight' or 'zero_based'
paired_ylim_padding = [0.04 0.30]; % [lower upper] margins x displayed data span
figure_visible = 'on';
make_plots = true;
save_mat = false;
save_png = false; save_fig = true; save_svg = false;
png_dpi = 300;
close_after_save = false;
output_dir = ''; % '' -> root_dir/all_condition_mode/var_stimuli_depended_balance_change

%% ---------------------------- LOAD INPUTS -----------------------------
cfg=struct();
settingNames={'root_dir','session_dirs','data_content','runIdx','uncertainty_included', ...
    'variance_denominator','summary_unit','comparison_plot_mode','component_pair','neuron_population', ...
    'figure_layout','single_figure_width','single_figure_height', ...
    'paired_ylim_mode','paired_ylim_padding', ...
    'group_names','gpl_mat_name','skip_missing_sessions', ...
    'summary_center','error_type','show_session_individual_lines','show_neuron_individual_lines','test_method', ...
    'significance_alpha','show_p_values','area_colors','component_line_styles','component_markers', ...
    'individual_gray','individual_line_width','summary_gray','summary_line_width','summary_marker_size', ...
    'poster_outlier_mode','poster_show_inset','poster_central_percentile', ...
    'poster_point_size','poster_point_alpha','poster_point_jitter_width','poster_violin_width', ...
    'poster_violin_alpha','poster_violin_point_spread_gain','poster_violin_point_edge_fraction', ...
    'font_name','font_size','figure_width','figure_height','figure_visible','make_plots', ...
    'save_mat','save_png','save_fig','save_svg','png_dpi','close_after_save','output_dir'};
for k=1:numel(settingNames), cfg.(settingNames{k})=eval(settingNames{k}); end
cfg=vbValidateConfigLocal(cfg);
cfg.component_labels={'Across','Within','FF','FB'};
cfg.input_component_labels={'Across','Within','Feedforward','Feedback'};
if strcmp(cfg.variance_denominator,'shared')
    cfg.required_input_variables={'PosteriorRawVarExtra'};
    cfg.denominator_label='Shared';
    cfg.neuron_percentage_field='neuron_percent_shared';
    cfg.population_percentage_field='population_percent_shared';
else
    cfg.component_labels{end+1}='Noise';
    cfg.required_input_variables={'PosteriorRawVarExtra','PosteriorRawVarNoise','PosteriorRawVarTotal'};
    cfg.denominator_label='Total';
    cfg.neuron_percentage_field='neuron_percent_total';
    cfg.population_percentage_field='population_percent_total';
end
% Data columns stay canonical; display indices implement the selected family.
if strcmp(cfg.component_pair,'within_across')
    cfg.plot_component_indices=[2 1];
else
    cfg.plot_component_indices=[3 4];
end
if strcmp(cfg.variance_denominator,'total'), cfg.plot_component_indices(end+1)=5; end
cfg.plot_component_labels=cfg.component_labels(cfg.plot_component_indices);
sessions=vbSessionDirsLocal(cfg);
records={}; skipped=struct('session_dir',{},'reason',{});
for s=1:numel(sessions)
    file=fullfile(sessions{s},'all_condition_mode','posterior_rawvar', ...
        sprintf('postVar_%s_r%03d_allcond_u%d.mat',cfg.data_content,cfg.runIdx,cfg.uncertainty_included));
    reason='';
    if ~isfile(file)
        reason=['Missing posterior MAT: ' file];
    else
        available=who('-file',file);
        missing=cfg.required_input_variables(~ismember(cfg.required_input_variables,available));
        if ~isempty(missing)
            reason=sprintf('Missing %s for %s mode; rerun posterior_rawvar with data_condition=[]: %s', ...
                strjoin(missing,', '),cfg.variance_denominator,file);
        end
    end
    if ~isempty(reason)
        if ~cfg.skip_missing_sessions, error('%s',reason); end
        warning('VarBalance:MissingSession','%s',reason);
        skipped(end+1)=struct('session_dir',sessions{s},'reason',reason); %#ok<SAGROW>
        continue;
    end
    fprintf('[%d/%d] %s\n',s,numel(sessions),sessions{s});
    try
        if strcmp(cfg.variance_denominator,'shared')
            R=vbReadSharedSessionLocal(sessions{s},file,cfg);
        else
            R=vbReadSessionLocal(sessions{s},file,cfg);
        end
    catch ME
        context=MException('VarBalance:InvalidInput','Invalid input in %s:\n%s',sessions{s},ME.message);
        context=addCause(context,ME); throw(context);
    end
    records{end+1}=R; %#ok<SAGROW>
end
if isempty(records)
    error(['No usable sessions. Run updated posterior_rawvar with data_condition=[] ', ...
        'and matching data_content/runIdx/uncertainty_included; check root_dir.']);
end
records=[records{:}];

%% ------------------------- AVERAGE, THEN DELTA -------------------------
VarStimuliBalanceChange=struct();
VarStimuliBalanceChange.format_version='var_stimuli_balance_change_v2';
VarStimuliBalanceChange.meta=struct('created_on',datestr(now,30), ...
    'created_by','var_stimuli_depended_balance_change.m','model_mode','all_condition', ...
    'variance_source','posterior','variance_unit','count','response_normalization','none', ...
    'observation_unit',cfg.summary_unit,'uncertainty_included',cfg.uncertainty_included, ...
    'denominator','observed_y_trial_variance_without_posterior_uncertainty', ...
    'neuron_percentage','100 * component_variance / observed_total_variance, per condition and direction', ...
    'session_percentage','100 * sum_neuron(component_variance) / sum_neuron(observed_total_variance)', ...
    'operation_order','16 condition-direction percentages, then endpoint means, then FIRST minus SECOND', ...
    'delta_definition','Grating-Plaid; Small-Large; Low-High','delta_unit','percentage_points', ...
    'missing_policy','same finite matched pairs on both endpoints; both directions required in neuron mode', ...
    'layout','3 feature rows x 6 columns; area1 selected triplet, then area2 selected triplet; independent axes', ...
    'test_tail','both','p_adjustment','none (nominal)','cluster_adjustment','none');
if strcmp(cfg.variance_denominator,'shared')
    VarStimuliBalanceChange.format_version='var_stimuli_balance_change_v3';
    VarStimuliBalanceChange.meta.denominator='joint_all_latent_variance_with_matching_posterior_uncertainty';
    VarStimuliBalanceChange.meta.neuron_percentage= ...
        '100 * component_variance / all_latent_variance, per condition and direction';
    VarStimuliBalanceChange.meta.session_percentage= ...
        '100 * sum_neuron(component_variance) / sum_neuron(all_latent_variance)';
    VarStimuliBalanceChange.meta.layout= ...
        '3 feature rows x 4 columns; area1 selected pair, then area2 selected pair; independent axes';
    VarStimuliBalanceChange.meta.paired_display_style='bars';
else
    VarStimuliBalanceChange.meta.paired_display_style='lines';
end
VarStimuliBalanceChange.meta.variance_denominator=cfg.variance_denominator;
VarStimuliBalanceChange.meta.denominator_uncertainty_included= ...
    strcmp(cfg.variance_denominator,'shared') && cfg.uncertainty_included;
VarStimuliBalanceChange.meta.comparison_plot_mode=cfg.comparison_plot_mode;
VarStimuliBalanceChange.meta.component_pair=cfg.component_pair;
VarStimuliBalanceChange.meta.paired_error_definition='sample SD, SEM=sample SD/sqrt(n_pairs), or none';
VarStimuliBalanceChange.meta.figure_layout=cfg.figure_layout;
if strcmp(cfg.figure_layout,'separate')
    VarStimuliBalanceChange.meta.layout='one figure per main panel; violin inset kept with its parent';
end
VarStimuliBalanceChange.component_labels=cfg.component_labels;
VarStimuliBalanceChange.plot_component_indices=cfg.plot_component_indices;
VarStimuliBalanceChange.plot_component_labels=cfg.plot_component_labels;
VarStimuliBalanceChange.sessions=records;
VarStimuliBalanceChange.skipped_sessions=skipped;
features=vbFeatureDefinitionsLocal(); featureRecords=cell(1,numel(features));
for f=1:numel(features)
    F=features(f); areaRecords=cell(1,2);
    for g=1:2
        A=vbCollectDeltaLocal(records,g,F,cfg);
        A=vbAddPairSummaryLocal(A,cfg);
        areaRecords{g}=A;
        shownStats=A.stats(cfg.plot_component_indices);
        fprintf('%s | %s | %s: finite pairs/deltas %s; two-sided P %s\n', ...
            F.name,cfg.group_names{g},strjoin(cfg.plot_component_labels,'/'), ...
            mat2str([shownStats.n]),mat2str([shownStats.p],4));
    end
    F.area=[areaRecords{:}]; featureRecords{f}=F;
end
VarStimuliBalanceChange.feature=[featureRecords{:}];

%% ------------------------------- SAVE ---------------------------------
if isempty(cfg.output_dir)
    cfg.output_dir=fullfile(cfg.root_dir,'all_condition_mode','var_stimuli_depended_balance_change');
end
base=vbOutputNameLocal(cfg);
VarStimuliBalanceChange.settings=cfg;
if cfg.save_mat || (cfg.make_plots && (cfg.save_png || cfg.save_fig || cfg.save_svg))
    if ~isfolder(cfg.output_dir)
        [ok,msg]=mkdir(cfg.output_dir); if ~ok, error('Cannot create output folder: %s',msg); end
    end
end
if cfg.save_mat
    save(fullfile(cfg.output_dir,[base '.mat']),'VarStimuliBalanceChange','-v7.3');
    fprintf('Saved percentages, endpoint means, deltas, identities and tests: %s.mat\n',base);
end
if cfg.make_plots
    if strcmp(cfg.figure_layout,'separate')
        vbPlotSeparateLocal(VarStimuliBalanceChange,cfg,base);
    else
        fig=vbPlotLocal(VarStimuliBalanceChange,cfg);
        vbSaveFigureLocal(fig,cfg.output_dir,base,cfg);
    end
end
fprintf('Done: %d sessions used; %d missing sessions reported.\n',numel(records),numel(skipped));

%% --------------------------- LOCAL FUNCTIONS --------------------------

function cfg=vbValidateConfigLocal(cfg)
    options={'figure_layout',{'combined','separate'}; 'paired_ylim_mode',{'tight','zero_based'}; ...
        'summary_unit',{'neuron','session'}; 'neuron_population',{'all_neurons','pcu_neurons'}; ...
        'comparison_plot_mode',{'paired','delta'}; 'component_pair',{'within_across','ff_fb'}; ...
        'variance_denominator',{'total','shared'}; 'error_type',{'sem','std','none'}; ...
        'summary_center',{'mean','median'}; 'test_method',{'signrank','ttest'}; ...
        'poster_outlier_mode',{'zoom_inset','full_range'}; 'figure_visible',{'on','off'}};
    for k=1:size(options,1)
        key=options{k,1}; value=lower(strtrim(char(cfg.(key))));
        if ~ismember(value,options{k,2}), error('Invalid %s: %s',key,value); end
        cfg.(key)=value;
    end
    cfg.root_dir=char(cfg.root_dir); cfg.data_content=char(cfg.data_content);
    cfg.output_dir=char(cfg.output_dir); cfg.font_name=char(cfg.font_name);
    cfg.group_names=cellstr(string(cfg.group_names(:)'));
    if ~isfolder(cfg.root_dir), error('root_dir does not exist: %s',cfg.root_dir); end
    if isempty(cfg.data_content) || any(ismember(cfg.data_content,['/' '\'])) || ...
            ~contains(lower(cfg.data_content),'count')
        error('data_content must name count-based observations, e.g. demean_count_within_t_and_condition.');
    end
    if numel(cfg.group_names)~=2 || any(cellfun(@isempty,cfg.group_names))
        error('This layout requires exactly two group_names in model order.');
    end
    validateattributes(cfg.runIdx,{'numeric'},{'scalar','positive','integer','finite'});
    validateattributes(cfg.single_figure_width,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(cfg.single_figure_height,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(cfg.paired_ylim_padding,{'numeric'}, ...
        {'vector','numel',2,'real','finite','nonnegative'});
    cfg.paired_ylim_padding=double(cfg.paired_ylim_padding(:)');
    flags={'uncertainty_included','skip_missing_sessions','show_p_values','poster_show_inset', ...
        'show_session_individual_lines','show_neuron_individual_lines', ...
        'make_plots','save_mat','save_png','save_fig','save_svg','close_after_save'};
    for k=1:numel(flags)
        v=cfg.(flags{k});
        if ~(isnumeric(v)||islogical(v)) || ~isscalar(v) || ~ismember(double(v),[0 1])
            error('%s must be true/false or 0/1.',flags{k});
        end
        cfg.(flags{k})=logical(v);
    end
    validateattributes(cfg.area_colors,{'numeric'},{'size',[2 3],'real','finite','>=',0,'<=',1});
    for key={'poster_point_alpha','poster_violin_alpha','individual_gray','summary_gray'}
        validateattributes(cfg.(key{1}),{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
    end
    for key={'font_size','figure_width','figure_height','png_dpi','poster_point_size', ...
            'poster_violin_width','poster_violin_point_spread_gain', ...
            'individual_line_width','summary_line_width','summary_marker_size'}
        validateattributes(cfg.(key{1}),{'numeric'},{'scalar','real','finite','positive'});
    end
    validateattributes(cfg.significance_alpha,{'numeric'},{'scalar','real','finite','>',0,'<',1});
    validateattributes(cfg.poster_central_percentile,{'numeric'},{'scalar','real','finite','>',0,'<=',100});
    validateattributes(cfg.poster_point_jitter_width,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(cfg.poster_violin_point_edge_fraction,{'numeric'},{'scalar','real','finite','>',0,'<=',1});
    cfg.component_line_styles=cellstr(string(cfg.component_line_styles(:)'));
    cfg.component_markers=cellstr(string(cfg.component_markers(:)'));
    if numel(cfg.component_line_styles)~=3 || ...
            ~all(ismember(cfg.component_line_styles,{'-','--',':','-.'}))
        error('Provide three valid component_line_styles, in display order.');
    end
    if numel(cfg.component_markers)~=3 || ...
            ~all(ismember(cfg.component_markers,{'o','s','^','v','d','p','h','+','x','*','.'}))
        error('Provide three valid component_markers, in display order.');
    end
    if exist(cfg.test_method,'file')~=2
        error('%s requires Statistics and Machine Learning Toolbox.',cfg.test_method);
    end
end

function R=vbReadSessionLocal(sessionDir,file,cfg)
    S=load(file,'PosteriorRawVarExtra','PosteriorRawVarNoise','PosteriorRawVarTotal');
    X=S.PosteriorRawVarExtra; Q=S.PosteriorRawVarNoise; O=S.PosteriorRawVarTotal;
    for block={X,Q,O}
        vbRequireLocal(block{1},{'format_version','meta','labels','condition_ids','condition'},'variance input');
    end
    if ~strcmp(X.format_version,'posterior_rawvar_extra_v1') || ...
            ~strcmp(Q.format_version,'posterior_rawvar_noise_v1') || ...
            ~strcmp(O.format_version,'posterior_rawvar_total_v1')
        error('Unsupported Extra/Noise/Total version. Use the supplied posterior_rawvar.m.');
    end
    for block={X.meta,Q.meta,O.meta}
        m=block{1};
        vbRequireLocal(m,{'model_mode','data_condition','variance_source','data_content','runIdx', ...
            'uncertainty_included','conditionShortLabels','dirValues','variance_method','variance_normalization'},'metadata');
        if ~strcmp(m.model_mode,'all_condition') || ~isempty(m.data_condition) || ...
                ~strcmp(m.data_content,cfg.data_content) || m.runIdx~=cfg.runIdx
            error('Only matching all-condition posterior content/run files are supported.');
        end
        if ~strcmp(m.variance_method,'across_trials_per_bin_mean_over_bins') || ...
                ~strcmp(m.variance_normalization,'M-1')
            error('Require per-bin trial sample variance (M-1), averaged over bins.');
        end
    end
    for block={X.meta,Q.meta}
        m=block{1};
        if ~strcmp(m.variance_source,'posterior') || ...
                double(m.uncertainty_included)~=double(cfg.uncertainty_included)
            error('Latent/Noise source or u setting does not match the selected posterior file.');
        end
    end
    if ~strcmp(Q.meta.noise_definition,'posterior_residual_y_minus_all') || ...
            ~strcmp(Q.meta.uncertainty_method,'mean_trial_bin_diag_full_C_Vsm_C_transpose') || ...
            ~isequal(cellstr(string(Q.labels(:)')),{'Noise'})
        error('Noise must use the posterior residual definition with full All uncertainty.');
    end
    vbRequireLocal(O.meta,{'total_definition','source_uncertainty_included','extra_created_on'},'Total.meta');
    if ~strcmp(O.meta.variance_source,'observed') || ...
            ~strcmp(O.meta.total_definition,'observed_y_trial_variance') || O.meta.uncertainty_included~=0 || ...
            double(O.meta.source_uncertainty_included)~=double(cfg.uncertainty_included) || ...
            ~isequal(cellstr(string(O.labels(:)')),{'Total'})
        error('Total must be observed variance, without a posterior uncertainty correction.');
    end
    if ~strcmp(Q.meta.extra_created_on,X.meta.created_on) || ~strcmp(O.meta.extra_created_on,X.meta.created_on)
        error('Noise/Total belongs to a different Extra result. Rerun updated posterior_rawvar.');
    end
    expected={'G-S-L','G-S-H','G-L-L','G-L-H','P-S-L','P-S-H','P-L-L','P-L-H'};
    labels=cellstr(string(X.meta.conditionShortLabels(:)'));
    rowOrder=vbLabelOrderLocal(expected,labels);
    columns=vbLabelOrderLocal(cfg.input_component_labels,X.labels); % label-based, not field-order-based
    vbLabelOrderLocal({'Across','Within','Feedforward','Feedback','Ambiguous','All'},X.labels);
    allColumn=vbLabelOrderLocal({'All'},X.labels);
    vbSizeLocal(X.condition_ids,[8 2],'Extra condition_ids');
    xIds=[X.condition.condition_id]; qIds=[Q.condition.condition_id]; oIds=[O.condition.condition_id];
    if numel(X.condition)~=16 || numel(unique(X.condition_ids(:)))~=16 || ...
            any(~isfinite(X.condition_ids(:))) || ~isequal(sort(xIds(:)),sort(X.condition_ids(:)))
        error('Require all 16 unique original condition-direction entries.');
    end
    for block={Q,O}
        B=block{1};
        if ~isequal(B.condition_ids,X.condition_ids) || ...
                ~isequal(sort([B.condition.condition_id]),sort(xIds)) || ...
                ~isequal(cellstr(string(B.meta.conditionShortLabels(:)')),labels)
            error('Extra/Noise/Total condition records or label mappings disagree.');
        end
    end
    dt=vbBinSecondsLocal(X.meta);
    if abs(dt-vbBinSecondsLocal(Q.meta))>1e-9*dt || abs(dt-vbBinSecondsLocal(O.meta))>1e-9*dt
        error('Extra, Noise and Total use different bin widths.');
    end
    dirs=double(X.meta.dirValues(:)');
    if numel(dirs)~=2 || numel(unique(dirs))~=2 || any(~isfinite(dirs)) || ...
            ~isequal(dirs,double(Q.meta.dirValues(:)')) || ~isequal(dirs,double(O.meta.dirValues(:)'))
        error('Require the same two directions in Extra, Noise and Total.');
    end
    R=struct('session_dir',sessionDir,'source_file',file,'bin_size_seconds',dt, ...
        'direction_values',dirs,'condition_ids',X.condition_ids(rowOrder,:), ...
        'condition_labels',{expected},'input_component_columns',columns);
    groups=cell(1,2); gplGroups={}; gplFiles={};
    if strcmp(cfg.neuron_population,'pcu_neurons')
        [gplGroups,gplFiles]=loadGplGroupsByModelIndexLocal(sessionDir,cfg.gpl_mat_name,2);
    end
    if numel(X.condition(1).group)~=2, error('Require exactly two model groups.'); end
    for g=1:2
        ids=vbIdsLocal(X.condition(1).group(g).unit_ids); n=numel(ids);
        values=nan(n,8,2,5); totals=nan(n,8,2);
        for d=1:2
            for c=1:8
                id=X.condition_ids(rowOrder(c),d);
                E=X.condition(xIds==id); N=Q.condition(qIds==id); T=O.condition(oIds==id);
                if E.feature_index~=rowOrder(c) || E.direction_index~=d || E.direction_value~=dirs(d) || ...
                        E.n_trials<2 || E.n_bins<1 || numel(E.group)~=2 || ...
                        ~strcmp(E.bestmodel_file,X.condition(1).bestmodel_file) || ~strcmp(E.model_mode,'all_condition')
                    error('Invalid condition/direction/model/trial identity in Extra.');
                end
                for block={N,T}
                    C=block{1};
                    if C.feature_index~=E.feature_index || C.direction_index~=d || C.direction_value~=dirs(d) || ...
                            C.n_trials~=E.n_trials || C.n_bins~=E.n_bins || ...
                            ~isequal(C.trial_ids,E.trial_ids) || numel(C.group)~=2 || ...
                            ~strcmp(C.model_mode,'all_condition')
                        error('Extra/Noise/Total condition and trial identities disagree.');
                    end
                end
                A=E.group(g); B=N.group(g); C=T.group(g);
                if ~isequal(vbIdsLocal(A.unit_ids),ids) || ~isequal(vbIdsLocal(B.unit_ids),ids) || ...
                        ~isequal(vbIdsLocal(C.unit_ids),ids) || ...
                        A.n_neurons~=n || B.n_neurons~=n || C.n_neurons~=n
                    error('Neuron IDs/order/count differ across conditions or input variables.');
                end
                for key={'raw_var','reconstruction_var','uncertainty_var'}
                    vbSizeLocal(A.(key{1}),[n numel(X.labels)],['latent ' key{1}]);
                end
                for key={'raw_var','residual_var','uncertainty_var'}
                    vbSizeLocal(B.(key{1}),[n 1],['Noise ' key{1}]);
                end
                vbSizeLocal(C.raw_var,[n 1],'Total raw_var');
                vbSizeLocal(C.raw_var_by_bin,[n E.n_bins],'Total raw_var_by_bin');
                vbNonnegativeLocal(A.raw_var,'latent variance');
                vbNonnegativeLocal(A.reconstruction_var,'latent reconstruction variance');
                vbNonnegativeLocal(B.raw_var,'Noise variance'); vbNonnegativeLocal(B.residual_var,'Noise residual');
                vbNonnegativeLocal(C.raw_var,'observed Total variance');
                vbNonnegativeLocal(C.raw_var_by_bin,'observed Total by bin');
                vbNearLocal(C.raw_var,mean(C.raw_var_by_bin,2),'Total time-bin average',false);
                latentExpected=double(A.reconstruction_var); noiseExpected=double(B.residual_var);
                if cfg.uncertainty_included
                    vbNonnegativeLocal(A.uncertainty_var,'latent uncertainty');
                    vbNonnegativeLocal(B.uncertainty_var,'Noise uncertainty');
                    vbNearLocal(B.uncertainty_var,A.uncertainty_var(:,allColumn),'Noise versus All uncertainty',false);
                    latentExpected=latentExpected+double(A.uncertainty_var);
                    noiseExpected=noiseExpected+double(B.uncertainty_var);
                end
                vbNearLocal(A.raw_var,latentExpected,'selected latent variance',false);
                vbNearLocal(B.raw_var,noiseExpected,'selected Noise variance',false);
                values(:,c,d,:)=reshape([double(A.raw_var(:,columns)) double(B.raw_var)],n,1,1,5);
                totals(:,c,d)=double(C.raw_var);
            end
        end
        selected=true(n,1); classCode=zeros(n,1);
        if strcmp(cfg.neuron_population,'pcu_neurons')
            I=validateAndExtractClassesLocal(gplGroups{g},ids,cfg.group_names{g},gplFiles{g});
            selected=I.pattern|I.component|I.unclassified;
            classCode(I.pattern)=1; classCode(I.component)=2; classCode(I.unclassified)=3; classCode(I.invalid)=4;
        end
        denominator=totals; denominator(denominator<=0)=NaN;
        neuronPct=100.*bsxfun(@rdivide,values,denominator);
        neuronPct(~isfinite(neuronPct))=NaN;
        % No per-neuron Total>0 filter here: the population denominator is a
        % SUM, so even zero-Total neurons must enter numerator and denominator.
        numeratorSum=reshape(sum(values(selected,:,:,:),1),8,2,5);
        denominatorSum=reshape(sum(totals(selected,:,:),1),8,2);
        populationPct=nan(8,2,5);
        if any(selected)
            den=denominatorSum; den(den<=0)=NaN;
            populationPct=100.*bsxfun(@rdivide,numeratorSum,den);
            populationPct(~isfinite(populationPct))=NaN;
        end
        G=struct('name',cfg.group_names{g},'unit_ids',ids, ...
            'component_variance',values,'total_variance',totals, ...
            'neuron_percent_total',neuronPct,'population_percent_total',populationPct, ...
            'population_component_sum',numeratorSum,'population_total_sum',denominatorSum, ...
            'population_selected_mask',selected,'class_code',classCode,'n_selected_neurons',nnz(selected), ...
            'n_zero_total_by_condition',reshape(sum(totals(selected,:,:)==0,1),8,2));
        groups{g}=G;
        fprintf('  %s: %d selected neurons; %d zero-Total neuron/condition/direction entries.\n', ...
            G.name,G.n_selected_neurons,sum(G.n_zero_total_by_condition(:)));
    end
    R.group=[groups{:}]; % No assignment between partially built/dissimilar structs.
end

function R=vbReadSharedSessionLocal(sessionDir,file,cfg)
% Read ONLY latent results. All is a JOINT reconstructed-activity variance,
% with the SAME u0/u1 convention as each numerator. No observed Total/Noise.
    S=load(file,'PosteriorRawVarExtra'); X=S.PosteriorRawVarExtra;
    vbRequireLocal(X,{'format_version','meta','labels','condition_ids','condition'},'Extra');
    if ~strcmp(X.format_version,'posterior_rawvar_extra_v1')
        error('Unsupported Extra version. Use the supplied posterior_rawvar.m.');
    end
    m=X.meta;
    vbRequireLocal(m,{'model_mode','data_condition','variance_source','data_content','runIdx', ...
        'uncertainty_included','conditionShortLabels','dirValues','variance_method','variance_normalization'},'Extra.meta');
    if ~strcmp(m.model_mode,'all_condition') || ~isempty(m.data_condition) || ...
            ~strcmp(m.data_content,cfg.data_content) || m.runIdx~=cfg.runIdx || ...
            ~strcmp(m.variance_source,'posterior') || ...
            double(m.uncertainty_included)~=double(cfg.uncertainty_included)
        error('Require matching all-condition posterior data_content/runIdx/u0/u1 in Extra.');
    end
    if ~strcmp(m.variance_method,'across_trials_per_bin_mean_over_bins') || ...
            ~strcmp(m.variance_normalization,'M-1')
        error('Require per-bin trial sample variance (M-1), averaged over bins.');
    end
    expected={'G-S-L','G-S-H','G-L-L','G-L-H','P-S-L','P-S-H','P-L-L','P-L-H'};
    labels=cellstr(string(m.conditionShortLabels(:)'));
    rowOrder=vbLabelOrderLocal(expected,labels);
    columns=vbLabelOrderLocal(cfg.input_component_labels,X.labels);
    vbLabelOrderLocal({'Across','Within','Feedforward','Feedback','Ambiguous','All'},X.labels);
    allColumn=vbLabelOrderLocal({'All'},X.labels);
    vbSizeLocal(X.condition_ids,[8 2],'Extra condition_ids');
    idsByCondition=[X.condition.condition_id];
    if numel(X.condition)~=16 || numel(unique(X.condition_ids(:)))~=16 || ...
            any(~isfinite(X.condition_ids(:))) || ...
            ~isequal(sort(idsByCondition(:)),sort(X.condition_ids(:)))
        error('Require all 16 unique original condition-direction entries.');
    end
    dt=vbBinSecondsLocal(m); dirs=double(m.dirValues(:)');
    if numel(dirs)~=2 || numel(unique(dirs))~=2 || any(~isfinite(dirs))
        error('Require exactly two distinct finite directions in Extra.');
    end
    R=struct('session_dir',sessionDir,'source_file',file,'bin_size_seconds',dt, ...
        'direction_values',dirs,'condition_ids',X.condition_ids(rowOrder,:), ...
        'condition_labels',{expected},'input_component_columns',columns, ...
        'input_all_column',allColumn);
    groups=cell(1,2); gplGroups={}; gplFiles={};
    if strcmp(cfg.neuron_population,'pcu_neurons')
        [gplGroups,gplFiles]=loadGplGroupsByModelIndexLocal(sessionDir,cfg.gpl_mat_name,2);
    end
    if numel(X.condition(1).group)~=2, error('Require exactly two model groups.'); end
    K=numel(cfg.component_labels);
    for g=1:2
        ids=vbIdsLocal(X.condition(1).group(g).unit_ids); n=numel(ids);
        values=nan(n,8,2,K); shared=nan(n,8,2);
        for d=1:2
            for c=1:8
                id=X.condition_ids(rowOrder(c),d); E=X.condition(idsByCondition==id);
                if E.feature_index~=rowOrder(c) || E.direction_index~=d || E.direction_value~=dirs(d) || ...
                        E.n_trials<2 || E.n_bins<1 || numel(E.group)~=2 || ...
                        ~strcmp(E.bestmodel_file,X.condition(1).bestmodel_file) || ...
                        ~strcmp(E.model_mode,'all_condition')
                    error('Invalid condition/direction/model/trial identity in Extra.');
                end
                A=E.group(g);
                if ~isequal(vbIdsLocal(A.unit_ids),ids) || A.n_neurons~=n
                    error('Neuron IDs/order/count differ across Extra conditions.');
                end
                for key={'raw_var','reconstruction_var','uncertainty_var'}
                    vbSizeLocal(A.(key{1}),[n numel(X.labels)],['latent ' key{1}]);
                end
                vbNonnegativeLocal(A.raw_var,'latent variance including All');
                vbNonnegativeLocal(A.reconstruction_var,'latent reconstruction variance including All');
                latentExpected=double(A.reconstruction_var);
                if cfg.uncertainty_included
                    vbNonnegativeLocal(A.uncertainty_var,'latent uncertainty including full All');
                    latentExpected=latentExpected+double(A.uncertainty_var);
                end
                vbNearLocal(A.raw_var,latentExpected,'selected latent and All variances',false);
                values(:,c,d,:)=reshape(double(A.raw_var(:,columns)),n,1,1,K);
                shared(:,c,d)=double(A.raw_var(:,allColumn));
            end
        end
        selected=true(n,1); classCode=zeros(n,1);
        if strcmp(cfg.neuron_population,'pcu_neurons')
            I=validateAndExtractClassesLocal(gplGroups{g},ids,cfg.group_names{g},gplFiles{g});
            selected=I.pattern|I.component|I.unclassified;
            classCode(I.pattern)=1; classCode(I.component)=2; classCode(I.unclassified)=3; classCode(I.invalid)=4;
        end
        denominator=shared; denominator(denominator<=0)=NaN;
        neuronPct=100.*bsxfun(@rdivide,values,denominator);
        neuronPct(~isfinite(neuronPct))=NaN;
        % Population: sum over the SAME selected cells in numerator and
        % denominator, including cells whose individual All variance is zero.
        numeratorSum=reshape(sum(values(selected,:,:,:),1),8,2,K);
        denominatorSum=reshape(sum(shared(selected,:,:),1),8,2);
        populationPct=nan(8,2,K);
        if any(selected)
            den=denominatorSum; den(den<=0)=NaN;
            populationPct=100.*bsxfun(@rdivide,numeratorSum,den);
            populationPct(~isfinite(populationPct))=NaN;
        end
        G=struct('name',cfg.group_names{g},'unit_ids',ids, ...
            'component_variance',values,'shared_variance',shared, ...
            'neuron_percent_shared',neuronPct,'population_percent_shared',populationPct, ...
            'population_component_sum',numeratorSum,'population_shared_sum',denominatorSum, ...
            'population_selected_mask',selected,'class_code',classCode,'n_selected_neurons',nnz(selected), ...
            'n_zero_shared_by_condition',reshape(sum(shared(selected,:,:)==0,1),8,2));
        groups{g}=G;
        fprintf('  %s: %d selected neurons; %d zero-Shared neuron/condition/direction entries.\n', ...
            G.name,G.n_selected_neurons,sum(G.n_zero_shared_by_condition(:)));
    end
    R.group=[groups{:}];
end

function vbSharedBarPanelLocal(ax,A,F,cfg,g,k)
% Two endpoint BARS, never connecting lines. Same complete observation pairs
% and same two-sided delta test as the violin. No 100-percent clipping.
    hold(ax,'on'); color=cfg.area_colors(g,:); gray=cfg.summary_gray*[1 1 1];
    y=A.center(:,k)'; err=A.error(:,k)';
    h=bar(ax,[1 2],y,0.65,'FaceColor',color,'EdgeColor','none');
    if ~strcmp(cfg.error_type,'none')
        errorbar(ax,[1 2],y,err,'LineStyle','none','Color',gray,'LineWidth',1.4, ...
            'CapSize',9,'HandleVisibility','off');
    end
    legend(ax,h,sprintf('%s: n=%d',cfg.group_names{g},A.legend_neuron_count_by_component(k)), ...
        'Location','northwest','Box','off','Interpreter','none','FontSize',cfg.font_size);
    set(ax,'XLim',[0.5 2.5],'XTick',[1 2],'XTickLabel',F.endpoint_labels);
    finiteErr=err; finiteErr(~isfinite(finiteErr))=0;
    extrema=[0;y(:);y(:)-finiteErr(:);y(:)+finiteErr(:)];
    extrema=extrema(isfinite(extrema));
    if isempty(extrema) || max(extrema)==min(extrema)
        ylim(ax,[0 1]);
    else
        lo=min(0,min(extrema)); hi=max(extrema); span=hi-lo;
        ylim(ax,[lo-0.04*span hi+0.30*span]);
    end
    vbPanelTitleLocal(ax,A,F,cfg,g,k);
    ylabel(ax,'% of Shared','Interpreter','none');
    vbAxesStyleLocal(ax,cfg);
    ax.UserData=struct('component',cfg.component_labels{k},'area',cfg.group_names{g}, ...
        'observation_unit',cfg.summary_unit,'n_pairs',A.n_pairs(k),'mode','paired', ...
        'paired_display_style','bars','variance_denominator','shared', ...
        'value_unit','percent_of_all_latent_shared_variance','statistics',A.stats(k));
end

function A=vbCollectDeltaLocal(records,g,F,cfg)
% Form endpoint MEANS from condition-level percentages, then subtract them.
% A display median never changes the averaging that defines an observation.
    K=numel(cfg.component_labels);
    if strcmp(cfg.summary_unit,'neuron'), nMatches=8; else, nMatches=4; end
    A=struct('name',cfg.group_names{g},'endpoints',zeros(0,2,K), ...
        'delta_percent_points',zeros(0,K),'matched_first',zeros(0,nMatches,K), ...
        'matched_second',zeros(0,nMatches,K),'matched_valid',false(0,nMatches,K), ...
        'n_matched_condition_directions',zeros(0,K),'session_index',zeros(0,1), ...
        'direction_index',zeros(0,1),'direction_value',zeros(0,1), ...
        'unit_id',zeros(0,1),'unit_row_index',zeros(0,1),'class_code',zeros(0,1), ...
        'n_neurons_per_observation',zeros(0,1),'legend_neuron_count_by_component',zeros(1,K));
    endpoints={}; firstParts={}; secondParts={}; validity={};
    for s=1:numel(records)
        G=records(s).group(g); selected=G.population_selected_mask;
        if strcmp(cfg.summary_unit,'neuron')
            n=nnz(selected); if n==0, continue; end
            V=G.(cfg.neuron_percentage_field); V=V(selected,:,:,:);
            left=V(:,F.first_conditions,:,:); right=V(:,F.second_conditions,:,:);
            good=isfinite(left)&isfinite(right);
            % Each retained match contributes both directions equally.
            bothDirs=all(good,3); good=repmat(bothDirs,1,1,2,1);
            left=reshape(left,n,8,K); right=reshape(right,n,8,K); good=reshape(good,n,8,K);
            Y=vbEndpointMeansLocal(left,right,good);
            endpoints{end+1}=Y; firstParts{end+1}=left; secondParts{end+1}=right; validity{end+1}=good; %#ok<AGROW>
            A.session_index=[A.session_index;repmat(s,n,1)]; %#ok<AGROW>
            A.direction_index=[A.direction_index;nan(n,1)]; A.direction_value=[A.direction_value;nan(n,1)]; %#ok<AGROW>
            A.unit_id=[A.unit_id;G.unit_ids(selected)]; A.unit_row_index=[A.unit_row_index;find(selected)]; %#ok<AGROW>
            A.class_code=[A.class_code;G.class_code(selected)]; %#ok<AGROW>
            A.n_neurons_per_observation=[A.n_neurons_per_observation;ones(n,1)]; %#ok<AGROW>
        else
            for d=1:2
                V=G.(cfg.population_percentage_field); V=reshape(V(:,d,:),8,K);
                left=reshape(V(F.first_conditions,:),1,4,K);
                right=reshape(V(F.second_conditions,:),1,4,K);
                good=isfinite(left)&isfinite(right);
                Y=vbEndpointMeansLocal(left,right,good);
                endpoints{end+1}=Y; firstParts{end+1}=left; secondParts{end+1}=right; validity{end+1}=good; %#ok<AGROW>
                A.session_index=[A.session_index;s]; A.direction_index=[A.direction_index;d]; %#ok<AGROW>
                A.direction_value=[A.direction_value;records(s).direction_values(d)]; %#ok<AGROW>
                A.unit_id=[A.unit_id;NaN]; A.unit_row_index=[A.unit_row_index;NaN]; A.class_code=[A.class_code;NaN]; %#ok<AGROW>
                A.n_neurons_per_observation=[A.n_neurons_per_observation;nnz(selected)]; %#ok<AGROW>
            end
        end
    end
    if ~isempty(endpoints)
        A.endpoints=cat(1,endpoints{:}); A.matched_first=cat(1,firstParts{:});
        A.matched_second=cat(1,secondParts{:}); A.matched_valid=cat(1,validity{:});
    end
    n=size(A.endpoints,1);
    A.n_matched_condition_directions=reshape(sum(A.matched_valid,2),n,K);
    % No differences are averaged: subtraction happens ONCE, after the means.
    A.delta_percent_points=reshape(A.endpoints(:,1,:)-A.endpoints(:,2,:),n,K);
    A.delta_center=nan(1,K); tests=cell(1,K);
    for k=1:K
        valid=isfinite(A.delta_percent_points(:,k)); vals=A.delta_percent_points(valid,k);
        if ~isempty(vals)
            if strcmp(cfg.summary_center,'mean'), A.delta_center(k)=mean(vals);
            else, A.delta_center(k)=median(vals); end
        end
        tests{k}=vbTestLocal(vals,cfg);
        if strcmp(cfg.summary_unit,'neuron')
            A.legend_neuron_count_by_component(k)=nnz(valid);
        else
            usedSessions=unique(A.session_index(valid));
            for s=usedSessions(:)'
                % All selected neurons enter each valid session ratio, even
                % zero-denominator neurons. Count each unit once across directions.
                A.legend_neuron_count_by_component(k)=A.legend_neuron_count_by_component(k)+ ...
                    records(s).group(g).n_selected_neurons;
            end
        end
    end
    A.stats=[tests{:}];
end

function Y=vbEndpointMeansLocal(left,right,good)
    left(~good)=NaN; right(~good)=NaN;
    n=size(left,1); Y=nan(n,2,size(left,3));
    Y(:,1,:)=vbFiniteMeanLocal(left,2);
    Y(:,2,:)=vbFiniteMeanLocal(right,2);
end

function T=vbTestLocal(x,cfg)
    x=x(isfinite(x)); x=x(:);
    T=struct('method',cfg.test_method,'tail','both','n',numel(x),'n_nonzero',nnz(x), ...
        'mean',NaN,'median',NaN,'p',NaN,'significant',false,'alpha',cfg.significance_alpha, ...
        'null_value',0,'unit','percentage_points');
    if isempty(x), return; end
    T.mean=mean(x); T.median=median(x);
    if strcmp(cfg.test_method,'ttest') && numel(x)<2, return; end
    if all(x==0)
        T.p=1;
    elseif strcmp(cfg.test_method,'signrank')
        T.p=signrank(x,0,'tail','both');
    elseif std(x,0)==0
        T.p=0;
    else
        [~,T.p]=ttest(x,0,'Tail','both','Alpha',cfg.significance_alpha);
    end
    T.significant=isfinite(T.p)&&T.p<cfg.significance_alpha;
end

function A=vbAddPairSummaryLocal(A,cfg)
% Use the SAME complete observation pairs as the saved delta and its test.
% Endpoint centers/errors describe percentages. They never define the delta:
% the median of paired differences need not equal the difference of medians.
    n=size(A.endpoints,1); K=numel(cfg.component_labels);
    A.center=nan(2,K); A.error=nan(2,K); A.n_pairs=zeros(1,K);
    for k=1:K
        Y=reshape(A.endpoints(:,:,k),n,2);
        good=all(isfinite(Y),2)&isfinite(A.delta_percent_points(:,k));
        A.n_pairs(k)=nnz(good);
        if A.n_pairs(k)~=A.stats(k).n
            error('Paired endpoints and delta statistics have different observation counts.');
        end
        for e=1:2
            [A.center(e,k),A.error(e,k)]=vbCenterErrorLocal(Y(good,e),cfg);
        end
    end
end

function [center,err]=vbCenterErrorLocal(x,cfg)
    x=double(x(:)); x=x(isfinite(x)); center=NaN; err=NaN;
    if isempty(x), return; end
    if strcmp(cfg.summary_center,'mean'), center=mean(x); else, center=median(x); end
    if strcmp(cfg.error_type,'none'), err=0;
    elseif numel(x)>1
        err=std(x,0);
        if strcmp(cfg.error_type,'sem'), err=err/sqrt(numel(x)); end
    end
end

function vbPanelTitleLocal(ax,A,F,cfg,g,k)
% The same paired-difference P value is shown in paired and delta modes.
    caption=[F.name ' | ' cfg.group_names{g} ' | ' cfg.component_labels{k}];
    if cfg.show_p_values
        p=A.stats(k).p;
        if isfinite(p)
            pText=[posterPValueTextLocal(p) '  ' posterStarsLocal(p,cfg.significance_alpha)];
        else
            pText='\bfP\rm = NA';
        end
        title(ax,{caption,pText},'Interpreter','tex','FontWeight','normal');
    else
        title(ax,caption,'Interpreter','none','FontWeight','normal');
    end
end

function vbPairedPanelLocal(ax,A,F,cfg,g,k,j)
% ONE area/component per axis. No source shares this y range.
    hold(ax,'on'); color=cfg.area_colors(g,:);
    gray=cfg.summary_gray*[1 1 1]; light=cfg.individual_gray*[1 1 1];
    n=size(A.endpoints,1); Y=reshape(A.endpoints(:,:,k),n,2);
    good=all(isfinite(Y),2)&isfinite(A.delta_percent_points(:,k));
    Y=Y(good,:); extrema=[];
    showIndividuals=(strcmp(cfg.summary_unit,'session') && cfg.show_session_individual_lines) || ...
        (strcmp(cfg.summary_unit,'neuron') && cfg.show_neuron_individual_lines);
    if showIndividuals && ~isempty(Y)
        plot(ax,[1 2],Y','Color',light,'LineStyle',cfg.component_line_styles{j}, ...
            'LineWidth',cfg.individual_line_width,'HandleVisibility','off');
        extrema=[extrema;Y(:)];
    end
    y=A.center(:,k)'; err=A.error(:,k)';
    if ~strcmp(cfg.error_type,'none')
        errorbar(ax,[1 2],y,err,'LineStyle','none','Color',gray,'LineWidth',1.4, ...
            'CapSize',9,'HandleVisibility','off');
    end
    h=plot(ax,[1 2],y,'Color',gray,'LineStyle',cfg.component_line_styles{j}, ...
        'LineWidth',cfg.summary_line_width,'Marker',cfg.component_markers{j}, ...
        'MarkerSize',cfg.summary_marker_size,'MarkerFaceColor',color,'MarkerEdgeColor',color);
    finiteErr=err; finiteErr(~isfinite(finiteErr))=0;
    extrema=[extrema;y(:);y(:)-finiteErr(:);y(:)+finiteErr(:)];
    legend(ax,h,sprintf('%s: n=%d',cfg.group_names{g},A.legend_neuron_count_by_component(k)), ...
        'Location','northwest','Box','off','Interpreter','none','FontSize',cfg.font_size);
    set(ax,'XLim',[0.65 2.35],'XTick',[1 2],'XTickLabel',F.endpoint_labels);
    ylim(ax,vbPairedYLimitsLocal(extrema,cfg));
    vbPanelTitleLocal(ax,A,F,cfg,g,k);
    ylabel(ax,'% of Total','Interpreter','none');
    vbAxesStyleLocal(ax,cfg);
    ax.UserData=struct('component',cfg.component_labels{k},'area',cfg.group_names{g}, ...
        'observation_unit',cfg.summary_unit,'n_pairs',nnz(good),'mode','paired', ...
        'value_unit','percent_of_observed_total','statistics',A.stats(k));
end

function vbPlotSeparateLocal(R,cfg,base)
% Preserve feature/area/display-component order in independent figures.
    for f=1:numel(R.feature)
        F=R.feature(f);
        for g=1:2
            for j=1:numel(cfg.plot_component_indices)
                k=cfg.plot_component_indices(j);
                [fig,ax]=vbSinglePanelFigureLocal(cfg); job=[];
                if strcmp(cfg.comparison_plot_mode,'paired')
                    if strcmp(cfg.variance_denominator,'shared')
                        vbSharedBarPanelLocal(ax,F.area(g),F,cfg,g,k);
                    else
                        vbPairedPanelLocal(ax,F.area(g),F,cfg,g,k,j);
                    end
                else
                    job=vbDeltaPanelLocal(ax,F.area(g),F,cfg,g,k,f);
                end
                panelBase=vbPanelBaseLocal(base,F,cfg,g,k);
                vbFinishSinglePanelLocal(fig,job,cfg,panelBase);
            end
        end
    end
end

function [fig,ax]=vbSinglePanelFigureLocal(cfg)
% A real single-panel figure, not an image/crop of the combined figure.
    fig=figure('Color','w','Visible',cfg.figure_visible,'Units','pixels', ...
        'Position',[40 40 cfg.single_figure_width cfg.single_figure_height]);
    layout=tiledlayout(fig,1,1,'TileSpacing','loose','Padding','loose');
    ax=nexttile(layout,1);
end

function vbFinishSinglePanelLocal(fig,job,cfg,base)
    set(findall(fig,'-property','FontName'),'FontName',cfg.font_name);
    set(findall(fig,'-property','FontSize'),'FontSize',cfg.font_size);
    drawnow; % Resolve this figure's geometry before positioning its inset.
    if ~isempty(job), vbDrawDeltaInsetLocal(fig,job,cfg); end
    drawnow;
    vbSaveFigureLocal(fig,cfg.output_dir,base,cfg);
end

function panelBase=vbPanelBaseLocal(base,F,cfg,g,k)
% Group index plus feature/component prevents duplicate panel filenames.
    areaTag=regexprep(cfg.group_names{g},'[^A-Za-z0-9_-]','_');
    areaTag=areaTag(1:min(16,numel(areaTag)));
    tag=sprintf('%s_g%02d_%s_%s',F.tag,g,areaTag,cfg.component_labels{k});
    panelBase=[base '_' tag];
    if numel(fullfile(cfg.output_dir,[panelBase '.png']))>=240
        % Keep the readable panel identity even when the analysis base is long.
        panelBase=['VarBal_' vbHashLocal(base) '_' tag];
    end
end

function limits=vbPairedYLimitsLocal(extrema,cfg)
% Only values actually displayed enter this LINE-plot scale. No clipping.
    v=double(extrema(:)); v=v(isfinite(v));
    if isempty(v), limits=[0 1]; return; end
    if strcmp(cfg.paired_ylim_mode,'zero_based')
        v=[0;v];
    end
    lo=min(v); hi=max(v);
    if lo==hi
        if strcmp(cfg.paired_ylim_mode,'zero_based')
            limits=[0 1]; return;
        end
        % Constant endpoints still need a nonzero range centered on their
        % actual value (e.g. both at 1), not the old [0 1] fallback.
        halfSpan=max(0.01*abs(lo),1e-6);
        lo=lo-halfSpan; hi=hi+halfSpan;
    end
    span=hi-lo;
    limits=[lo-cfg.paired_ylim_padding(1)*span, ...
            hi+cfg.paired_ylim_padding(2)*span];
end

function fig=vbPlotLocal(R,cfg)
    fig=figure('Color','w','Visible',cfg.figure_visible,'Units','pixels', ...
        'Position',[40 40 cfg.figure_width cfg.figure_height]);
    perArea=numel(cfg.plot_component_indices); nCols=2*perArea;
    layout=tiledlayout(fig,3,nCols,'TileSpacing','loose','Padding','loose');
    insetJobs={};
    for f=1:3
        F=R.feature(f);
        for g=1:2
            for j=1:perArea
                k=cfg.plot_component_indices(j);
                col=(g-1)*perArea+j;
                ax=nexttile(layout,(f-1)*nCols+col);
                if strcmp(cfg.comparison_plot_mode,'paired')
                    if strcmp(cfg.variance_denominator,'shared')
                        vbSharedBarPanelLocal(ax,F.area(g),F,cfg,g,k);
                    else
                        vbPairedPanelLocal(ax,F.area(g),F,cfg,g,k,j);
                    end
                else
                    job=vbDeltaPanelLocal(ax,F.area(g),F,cfg,g,k,f);
                    if ~isempty(job), insetJobs{end+1}=job; end %#ok<AGROW>
                end
            end
        end
    end
    set(findall(fig,'-property','FontName'),'FontName',cfg.font_name);
    set(findall(fig,'-property','FontSize'),'FontSize',cfg.font_size);
    drawnow;
    for j=1:numel(insetJobs), vbDrawDeltaInsetLocal(fig,insetJobs{j},cfg); end
    drawnow;
end

function job=vbDeltaPanelLocal(ax,A,F,cfg,g,k,f)
% One violin per area/component, using the reference density/point painters.
    job=[]; hold(ax,'on'); color=cfg.area_colors(g,:);
    vals=double(A.delta_percent_points(:,k)); vals=vals(isfinite(vals));
    [limit,fullLimit,isZoom]=vbDeltaLimitsLocal(vals,cfg);
    drawInset=isZoom && cfg.poster_show_inset;
    painter=struct('violin_width',cfg.poster_violin_width,'violin_alpha',cfg.poster_violin_alpha);
    halfSpan=max(0.65,1.4*cfg.poster_violin_width);
    xlimits=[1-halfSpan 1+halfSpan];
    if drawInset, xlimits(2)=1+1.9*halfSpan; end % reserve room at upper right
    plot(ax,xlimits,[0 0],'--','Color',[0.6 0.6 0.6], ...
        'LineWidth',0.8,'HandleVisibility','off');
    jitter=zeros(size(vals));
    if ~isempty(vals)
        profile=posterDrawSummaryLocal(ax,1,vals,painter,color,limit);
        jitter=posterViolinJitterLocal(vals,profile,cfg.poster_point_jitter_width, ...
            cfg.poster_violin_width,cfg.poster_violin_point_spread_gain, ...
            cfg.poster_violin_point_edge_fraction,10000*f+100*g+k);
        visible=abs(vals)<=limit;
        posterScatterLocal(ax,1+jitter(visible),vals(visible),color, ...
            cfg.poster_point_size,cfg.poster_point_alpha);
        posterDrawInnerMarksLocal(ax,1,vals,A.delta_center(k));
    end
    set(ax,'XLim',xlimits,'YLim',[-limit limit],'XTick',1, ...
        'XTickLabel',cfg.component_labels(k),'TickLabelInterpreter','none');
    ylabel(ax,['\Delta % of ' cfg.denominator_label ' (pp)'],'Interpreter','tex');
    xlabel(ax,[F.endpoint_labels{1} ' - ' F.endpoint_labels{2}],'Interpreter','none');
    vbPanelTitleLocal(ax,A,F,cfg,g,k);
    h=plot(ax,NaN,NaN,'o','LineStyle','none','MarkerSize',7, ...
        'MarkerFaceColor',color,'MarkerEdgeColor','none');
    legend(ax,h,sprintf('%s: n=%d',cfg.group_names{g},A.legend_neuron_count_by_component(k)), ...
        'Location','southoutside','Box','off','Interpreter','none','FontSize',cfg.font_size);
    vbAxesStyleLocal(ax,cfg);
    ax.UserData=struct('component',cfg.component_labels{k},'area',cfg.group_names{g}, ...
        'observation_unit',cfg.summary_unit,'n_deltas',numel(vals),'mode','delta', ...
        'delta_direction','first_minus_second','value_unit','percentage_points', ...
        'variance_denominator',cfg.variance_denominator, ...
        'main_abs_limit',limit,'full_abs_limit',fullLimit, ...
        'points_outside_main_axis',sum(abs(vals)>limit),'inset_drawn',drawInset, ...
        'statistics',A.stats(k));
    if drawInset
        job=struct('main_axes',ax,'values',vals,'jitter',jitter,'color',color, ...
            'full_limit',fullLimit,'xlimits',[1-halfSpan 1+halfSpan]);
    end
end

function vbDrawDeltaInsetLocal(fig,J,cfg)
% Full-range scatter inset follows the reference; no observations are removed
% from the stored deltas or tests when the main violin is zoomed.
    ax=J.main_axes; oldUnits=ax.Units; ax.Units='normalized'; pos=ax.Position; ax.Units=oldUnits;
    rect=[pos(1)+0.65*pos(3),pos(2)+0.66*pos(4),0.30*pos(3),0.29*pos(4)];
    inset=axes('Parent',fig,'Units','normalized','Position',rect,'Color',[0.98 0.98 0.98]);
    hold(inset,'on');
    plot(inset,J.xlimits,[0 0],'--','Color',[0.6 0.6 0.6], ...
        'LineWidth',0.6,'HandleVisibility','off');
    posterScatterLocal(inset,1+J.jitter,J.values,J.color,max(2,cfg.poster_point_size*0.65),0.35);
    set(inset,'XLim',J.xlimits,'YLim',[-J.full_limit J.full_limit], ...
        'XTick',[],'YTick',[-J.full_limit 0 J.full_limit], ...
        'YAxisLocation','right','FontName',cfg.font_name,'FontSize',cfg.font_size, ...
        'TickDir','out','Box','off','LineWidth',1,'YColor',[0.4 0.4 0.4]);
    inset.UserData=struct('mode','delta_full_range_inset','n_values',numel(J.values));
end

function base=vbOutputNameLocal(cfg)
    if strcmp(cfg.neuron_population,'all_neurons'), pop='allN'; else, pop='pcuN'; end
    content=cfg.data_content;
    if strcmp(content,'demean_count_within_t_and_condition'), content='dmTC';
    else
        safe=regexprep(content,'[^A-Za-z0-9_]','_');
        if numel(safe)>16 || ~strcmp(content,safe), safe=[safe(1:min(10,end)) '_' vbHashLocal(content)]; end
        content=safe;
    end
    nCols=2*numel(cfg.plot_component_indices);
    base=sprintf('VarBal_%s_r%03d_allcond_u%d_%s_%s_%s_%s_%s_ppt_3x%d_%s_%s', ...
        content,cfg.runIdx,cfg.uncertainty_included,cfg.summary_unit,pop,cfg.summary_center, ...
        cfg.test_method,cfg.variance_denominator,nCols,cfg.component_pair,cfg.comparison_plot_mode);
    if strcmp(cfg.comparison_plot_mode,'delta')
        if strcmp(cfg.poster_outlier_mode,'full_range'), base=[base '_full']; else, base=[base '_zoom']; end
        if ~cfg.poster_show_inset, base=[base '_noInset']; end
    else
        base=[base '_' cfg.error_type];
        if strcmp(cfg.variance_denominator,'shared')
            base=[base '_bars'];
        else
            if strcmp(cfg.summary_unit,'session') && ~cfg.show_session_individual_lines
                base=[base '_summaryOnly'];
            end
            if strcmp(cfg.summary_unit,'neuron') && cfg.show_neuron_individual_lines
                base=[base '_neuronLines'];
            end
        end
    end
    if ~cfg.show_p_values, base=[base '_noP']; end
    if strcmp(cfg.figure_layout,'separate'), base=[base '_panels']; end
    if strcmp(cfg.comparison_plot_mode,'paired') && strcmp(cfg.paired_ylim_mode,'tight') && strcmp(cfg.variance_denominator,'total')
        base=[base '_tight'];
    end
    if numel(fullfile(cfg.output_dir,[base '.png']))>=240
        base=['VarBal_' cfg.summary_unit '_' vbHashLocal(base)];
    end
end

function dirs=vbSessionDirsLocal(cfg)
    if ~isempty(cfg.session_dirs)
        dirs=cellstr(string(cfg.session_dirs(:)));
    else
        [~,name]=fileparts(cfg.root_dir);
        if startsWith(name,'catgt_')
            dirs={cfg.root_dir};
        else
            a=dir(fullfile(cfg.root_dir,'catgt_*'));
            b=dir(fullfile(cfg.root_dir,'*','catgt_*')); listing=[a(:);b(:)];
            listing=listing([listing.isdir]); dirs=cell(numel(listing),1);
            for k=1:numel(listing), dirs{k}=fullfile(listing(k).folder,listing(k).name); end
        end
    end
    dirs=unique(dirs,'stable');
    if isempty(dirs), error('No catgt_* sessions found under root_dir. Or set session_dirs explicitly.'); end
    numbers=nan(numel(dirs),1); labels=cell(size(dirs));
    for k=1:numel(dirs)
        if ~isfolder(dirs{k}), error('Session folder does not exist: %s',dirs{k}); end
        [parent,leaf]=fileparts(dirs{k}); [~,parent]=fileparts(parent);
        labels{k}=[parent '/' leaf]; token=regexp(parent,'p(\d+)','tokens','once');
        if isempty(token), numbers(k)=Inf; else, numbers(k)=str2double(token{1}); end
    end
    T=table(numbers(:),labels(:),dirs(:),'VariableNames',{'number','label','folder'});
    T=sortrows(T,{'number','label'}); dirs=T.folder;
end

function F=vbFeatureDefinitionsLocal()
    F=struct('name',{'Stimulus','Size','Contrast'},'tag',{'GP','SL','LH'}, ...
        'endpoint_labels',{{'Grating','Plaid'},{'Small','Large'},{'Low','High'}}, ...
        'first_conditions',{[1 2 3 4],[1 2 5 6],[1 3 5 7]}, ...
        'second_conditions',{[5 6 7 8],[3 4 7 8],[2 4 6 8]});
end

function y=vbFiniteMeanLocal(X,dim)
% Identical finite-value mean rule used by the two reference programs.
    keep=isfinite(X); count=sum(keep,dim); X(~keep)=0;
    y=sum(X,dim)./count; y(count==0)=NaN;
end

function [limit,fullLimit,isZoom]=vbDeltaLimitsLocal(vals,cfg)
% Reference robust symmetric scale, computed independently for EACH panel.
    isZoom=false;
    if isempty(vals), limit=0.1; fullLimit=0.1; return; end
    fullLimit=1.08*max(abs(vals));
    if strcmp(cfg.poster_outlier_mode,'zoom_inset')
        limit=1.12*posterEmpiricalPercentileLocal(abs(vals),cfg.poster_central_percentile);
        [q1,q3,lo,hi]=posterTukeySummaryLocal(vals);
        limit=max(limit,1.1*max(abs([median(vals) q1 q3])));
        limit=max(limit,1.08*max(abs([lo hi])));
        % If mean is chosen for the center mark, it must also remain visible.
        if strcmp(cfg.summary_center,'mean'), limit=max(limit,1.1*abs(mean(vals))); end
        limit=max(limit,min(fullLimit,0.002));
        isZoom=any(abs(vals)>limit);
    else
        limit=fullLimit;
    end
    if ~isfinite(limit) || limit<=0, limit=0.1; end
    if ~isfinite(fullLimit) || fullLimit<=0, fullLimit=limit; end
    if ~isZoom, limit=max(limit,fullLimit); end
end

function vbAxesStyleLocal(ax,cfg)
    set(ax,'FontName',cfg.font_name,'FontSize',cfg.font_size, ...
        'TickDir','out','Box','off','LineWidth',1.2,'Layer','top', ...
        'XColor',[0.2 0.2 0.2],'YColor',[0.2 0.2 0.2], ...
        'TitleFontSizeMultiplier',1,'LabelFontSizeMultiplier',1);
    grid(ax,'off');
end

function vbSaveFigureLocal(fig,folder,base,cfg)
% Short temporary paths avoid the PNG-library destination-path failure.
    if cfg.save_fig || cfg.save_png || cfg.save_svg
        if numel(fullfile(folder,[base '.png']))>=240
            base=['VarBal_' cfg.summary_unit '_' vbHashLocal(base)];
        end
        drawnow;
        if cfg.save_fig, savefig(fig,fullfile(folder,[base '.fig'])); end
        if cfg.save_png
            temporary=[tempname '.png']; cleaner=onCleanup(@()vbRemoveTempLocal(temporary)); %#ok<NASGU>
            try
                exportgraphics(fig,temporary,'Resolution',cfg.png_dpi);
                vbNonemptyFileLocal(temporary);
            catch exportError
                vbRemoveTempLocal(temporary);
                set(fig,'PaperPositionMode','auto');
                try
                    print(fig,temporary,'-dpng',sprintf('-r%g',cfg.png_dpi));
                    vbNonemptyFileLocal(temporary);
                catch printError
                    error('VarBalance:PngExport','PNG export failed. exportgraphics: %s\nprint: %s', ...
                        exportError.message,printError.message);
                end
            end
            [ok,msg]=movefile(temporary,fullfile(folder,[base '.png']),'f');
            if ~ok, error('PNG destination could not be written: %s',msg); end
            clear cleaner;
        end
        if cfg.save_svg
            temporary=[tempname '.svg']; cleaner=onCleanup(@()vbRemoveTempLocal(temporary)); %#ok<NASGU>
            set(fig,'Renderer','painters','PaperPositionMode','auto');
            print(fig,temporary,'-dsvg','-painters'); vbNonemptyFileLocal(temporary);
            [ok,msg]=movefile(temporary,fullfile(folder,[base '.svg']),'f');
            if ~ok, error('SVG destination could not be written: %s',msg); end
            clear cleaner;
        end
        fprintf('Saved figures: %s\n',fullfile(folder,base));
        if cfg.close_after_save, close(fig); end
    end
end

function vbNonemptyFileLocal(file)
    d=dir(file); if isempty(d) || d.bytes==0, error('Exporter did not create a nonempty file: %s',file); end
end

function vbRemoveTempLocal(file)
    if isfile(file), delete(file); end
end

function hash=vbHashLocal(text)
    v=0; text=double(char(text));
    for k=1:numel(text), v=mod(131*v+text(k),4294967296); end
    hash=lower(dec2hex(v,8));
end

function order=vbLabelOrderLocal(wanted,actual)
    actual=cellstr(string(actual(:)')); wanted=cellstr(string(wanted(:)'));
    if numel(unique(actual))~=numel(actual), error('Duplicate input labels.'); end
    [ok,order]=ismember(wanted,actual);
    if ~all(ok), error('Required input labels are missing: %s',strjoin(wanted(~ok),', ')); end
end

function ids=vbIdsLocal(ids)
    ids=double(ids(:));
    if any(~isfinite(ids) | ids~=round(ids)) || numel(unique(ids))~=numel(ids) || isempty(ids)
        error('Require nonempty unique finite integer neuron IDs.');
    end
end

function vbSizeLocal(A,shape,label)
    sz=size(A); sz(end+1:numel(shape))=1;
    if ~isequal(sz,shape), error('%s has unexpected dimensions.',label); end
end

function vbRequireLocal(S,fields,label)
    if ~isstruct(S), error('%s must be a struct.',label); end
    for k=1:numel(fields)
        if ~isfield(S,fields{k}), error('%s is missing %s.',label,fields{k}); end
    end
end

function vbNonnegativeLocal(A,label)
    if ~isnumeric(A) || ~isreal(A) || any(~isfinite(A(:))) || any(A(:)<0)
        error('%s must be finite nonnegative real variance.',label);
    end
end

function vbNearLocal(A,B,label,allowNaN)
    if ~isnumeric(A) || ~isnumeric(B) || ~isreal(A) || ~isreal(B) || ~isequal(size(A),size(B))
        error('Invalid shape/type in %s.',label);
    end
    A=double(A); B=double(B);
    if any(isinf(A(:))) || any(isinf(B(:))) || ~isequal(isnan(A),isnan(B)) || ...
            (~allowNaN && any(isnan(A(:))))
        error('Invalid/mismatched nonfinite values in %s.',label);
    end
    good=isfinite(A); a=A(good); b=B(good);
    if ~isempty(a) && max(abs(a-b))>1e-8*max(1,max(abs(b)))
        error('Inconsistent %s.',label);
    end
end

function dt=vbBinSecondsLocal(meta)
    if isfield(meta,'bin_size_seconds'), dt=double(meta.bin_size_seconds);
    elseif isfield(meta,'bin_size'), dt=double(meta.bin_size);
    else, error('Missing bin_size in seconds.'); end
    validateattributes(dt,{'numeric'},{'scalar','real','finite','positive'});
    if isfield(meta,'bin_size') && abs(double(meta.bin_size)-dt)>1e-9*dt
        error('bin_size and bin_size_seconds disagree.');
    end
    for f={'bin_edges','bin_centers'}
        if ~isfield(meta,f{1}) || isempty(meta.(f{1})), continue; end
        v=double(meta.(f{1}));
        if ~isvector(v) || any(~isfinite(v(:))) || any(abs(diff(v(:))-dt)>1e-7*dt)
            error('Invalid analysis-bin metadata in %s.',f{1});
        end
    end
end

function [gpl_group_by_index, gpl_file_by_index] = ...
    loadGplGroupsByModelIndexLocal( ...
    session_dir, gpl_mat_name, num_groups)
% Load every probe-level GPL MAT at most once and map its nested group
% entries to the reconstruction group order. Only model_group_index is used
% for mapping. Stored group/area names and user-supplied probe IDs are not
% read for data selection or consistency checks.

    d = dir(fullfile( ...
        session_dir, ...
        '*_imec*', ...
        'kilosort*', ...
        gpl_mat_name));

    d = d(~[d.isdir]);

    if isempty(d)
        error(['No %s was found under any *_imec*/kilosort* folder ', ...
            'in %s. Run GPL_analysis_by_area.m first.'], ...
            gpl_mat_name, session_dir);
    end

    paths = cell(1, numel(d));
    for i = 1:numel(d)
        paths{i} = fullfile(d(i).folder, d(i).name);
    end

    [paths, sort_order] = sort(paths);
    d = d(sort_order);

    gpl_group_by_index = cell(1, num_groups);
    gpl_file_by_index = cell(1, num_groups);

    for file_idx = 1:numel(d)
        gpl_file = paths{file_idx};
        S = load(gpl_file, 'gpl_results');

        if ~isfield(S, 'gpl_results') || ...
                ~isstruct(S.gpl_results) || ...
                ~isscalar(S.gpl_results)
            error('%s does not contain one valid gpl_results struct.', ...
                gpl_file);
        end

        P = S.gpl_results;

        if ~isfield(P, 'format_version') || ...
                ~(ischar(P.format_version) || ...
                (isstring(P.format_version) && isscalar(P.format_version))) || ...
                ~strcmp(char(P.format_version), 'grouped_by_probe_v1')
            error(['Unsupported GPL result format in %s. This program ', ...
                'requires the grouped probe-level output produced by ', ...
                'GPL_analysis_by_area.m.'], gpl_file);
        end

        if ~isfield(P, 'group') || ~isstruct(P.group) || isempty(P.group)
            error('%s is missing nonempty gpl_results.group.', gpl_file);
        end

        for local_group_idx = 1:numel(P.group)
            G = P.group(local_group_idx);

            if ~isfield(G, 'model_group_index') || ...
                    ~isnumeric(G.model_group_index) || ...
                    ~isscalar(G.model_group_index) || ...
                    ~isfinite(double(G.model_group_index)) || ...
                    double(G.model_group_index) ~= ...
                    round(double(G.model_group_index))
                error(['%s contains a nested GPL group with an invalid ', ...
                    'model_group_index.'], gpl_file);
            end

            group_idx = double(G.model_group_index);

            if group_idx < 1 || group_idx > num_groups
                error(['%s contains model_group_index %d, but the ', ...
                    'reconstruction contains groups 1:%d.'], ...
                    gpl_file, group_idx, num_groups);
            end

            if ~isempty(gpl_group_by_index{group_idx})
                error(['Model group %d was found in more than one GPL ', ...
                    'group entry. The classification source is ambiguous:\n', ...
                    '%s\n%s'], ...
                    group_idx, gpl_file_by_index{group_idx}, gpl_file);
            end

            gpl_group_by_index{group_idx} = G;
            gpl_file_by_index{group_idx} = gpl_file;
        end
    end

    missing_groups = find(cellfun(@isempty, gpl_group_by_index));

    if ~isempty(missing_groups)
        error(['No GPL group entry was found for model group(s) %s in ', ...
            '%s.'], mat2str(missing_groups), session_dir);
    end

    fprintf('  GPL source files found: %d\n', numel(d));
end

function info = validateAndExtractClassesLocal( ...
    G, model_ids, group_display_name, gpl_file)

    if ~isfield(G, 'used_unit_ids') || ~isfield(G, 'plaid')
        error('%s lacks used_unit_ids or plaid classification.', ...
            gpl_file);
    end

    if ~isfield(G, 'baseline_subtracted') || ...
            ~(islogical(G.baseline_subtracted) || ...
            isnumeric(G.baseline_subtracted)) || ...
            ~isscalar(G.baseline_subtracted) || ...
            ~isfinite(double(G.baseline_subtracted)) || ...
            ~ismember(double(G.baseline_subtracted), [0, 1]) || ...
            ~logical(G.baseline_subtracted)
        error('%s is not marked baseline_subtracted = true.', gpl_file);
    end

    gpl_ids = double(G.used_unit_ids(:));
    model_ids = double(model_ids(:));

    if numel(gpl_ids) ~= numel(model_ids)
        error(['Neuron-count mismatch for %s: ', ...
            'reconstruction=%d, GPL=%d.'], ...
            group_display_name, ...
            numel(model_ids), numel(gpl_ids));
    end

    if numel(unique(gpl_ids)) ~= numel(gpl_ids) || ...
            numel(unique(model_ids)) ~= numel(model_ids)
        error('Duplicate unit IDs found for %s.', group_display_name);
    end

    if ~isequal(sort(gpl_ids), sort(model_ids))
        error('GPL/reconstruction unit-ID sets differ for %s.', ...
            group_display_name);
    end

    if ~isequal(gpl_ids, model_ids)
        error('GPL/reconstruction unit-ID order differs for %s.', ...
            group_display_name);
    end

    required_masks = { ...
        'is_pattern', ...
        'is_component', ...
        'is_unclassified', ...
        'is_invalid'};

    masks = cell(size(required_masks));

    for i = 1:numel(required_masks)
        mask_name = required_masks{i};

        if ~isfield(G.plaid, mask_name)
            error('%s is missing gpl_results.plaid.%s.', ...
                gpl_file, mask_name);
        end

        this_mask = G.plaid.(mask_name);
        masks{i} = logical(this_mask(:));

        if numel(masks{i}) ~= numel(model_ids)
            error('GPL class mask %s has the wrong length.', ...
                mask_name);
        end
    end

    class_count = zeros(numel(model_ids), 1);

    for i = 1:numel(masks)
        class_count = class_count + double(masks{i});
    end

    if any(class_count ~= 1)
        bad_ids = model_ids(class_count ~= 1);

        error(['GPL classes are not mutually exclusive and exhaustive ', ...
            'for %s. Affected IDs: %s'], ...
            group_display_name, summarizeIdsLocal(bad_ids));
    end

    info = struct();
    info.unit_ids = model_ids;
    info.pattern = masks{1};
    info.component = masks{2};
    info.unclassified = masks{3};
    info.invalid = masks{4};
end

function s = summarizeIdsLocal(ids)
    ids = ids(:)';

    if isempty(ids)
        s = 'none';
    elseif numel(ids) <= 20
        s = mat2str(ids);
    else
        s = sprintf('%s ... (%d total)', ...
            mat2str(ids(1:20)), numel(ids));
    end
end

function label = posterPValueTextLocal(p)
    prefix = '\bfP\rm'; % Bold only the P, not the value or stars.
    if p < 0.001
        label = [prefix, '<0.001'];
    else
        label = sprintf('%s=%.3g', prefix, p);
    end
end

function stars = posterStarsLocal(p, alpha)
    if p >= alpha
        stars = 'ns';
    elseif p < 0.0001
        stars = '****';
    elseif p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    else
        stars = '*';
    end
end

function value = posterEmpiricalPercentileLocal(vals, percent)
% Empirical lower order statistic, so one extreme point cannot alone set
% the axis height in a small sample. No Statistics Toolbox is required.
    vals = sort(vals(isfinite(vals)));
    if isempty(vals)
        value = NaN;
        return;
    end
    rank = max(1, min(numel(vals), floor(numel(vals) * percent / 100)));
    value = vals(rank);
end

function value = posterInterpolatedPercentileLocal(vals, percent)
% Use interpolated quartiles for descriptive statistics. The more robust
% lower-order percentile above is reserved for the main-axis zoom limit.
    vals = sort(vals(isfinite(vals)));
    rank = 1 + (numel(vals) - 1) * percent / 100;
    lower_rank = floor(rank);
    upper_rank = ceil(rank);
    value = vals(lower_rank) + (rank - lower_rank) * ...
        (vals(upper_rank) - vals(lower_rank));
end

function profile = posterDrawSummaryLocal( ...
    ax, x0, vals, config, area_color, ylimit)
% Return exactly the violin contour used for centered point spreading.
    profile = struct('y', [], 'half_width', []);
    within_axis = vals(abs(vals) <= ylimit);
    if numel(within_axis) <= 1 || max(within_axis) <= min(within_axis)
        return;
    end
    [density, yy] = estimateDensityLocal(within_axis);
    valid = isfinite(density(:)) & isfinite(yy(:));
    density = double(density(valid));
    yy = double(yy(valid));
    if numel(yy) <= 1 || max(density) <= 0
        return;
    end
    [yy, idx] = sort(yy);
    density = max(density(idx), 0);
    [yy, idx] = unique(yy, 'stable');
    density = density(idx);
    if numel(yy) < 30
        kernel = [1, 4, 6, 4, 1] / 16;
        density = conv(density, kernel, 'same');
        grid_y = linspace(min(within_axis), ...
            max(within_axis), 100)';
        density = max(0, interp1(yy, density, grid_y, 'linear', 0));
        yy = grid_y;
    end
    if max(density) <= 0
        return;
    end
    half_width = density ./ max(density) .* config.violin_width;
    yy = yy(:);
    half_width = half_width(:);
    profile.y = yy;
    profile.half_width = half_width;
    % Explicit columns avoid accidental horizontal colored patch edges.
    patch(ax, [x0 - half_width; x0 + flipud(half_width)], ...
        [yy; flipud(yy)], area_color, ...
        'FaceAlpha', config.violin_alpha, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    plot(ax, x0 - half_width, yy, '-', 'Color', area_color, ...
        'LineWidth', 0.9, 'HandleVisibility', 'off');
    plot(ax, x0 + half_width, yy, '-', 'Color', area_color, ...
        'LineWidth', 0.9, 'HandleVisibility', 'off');
end

function jitter = posterViolinJitterLocal( ...
    vals, profile, base_width, violin_width, gain, edge_fraction, seed)
% Like densityAwareJitterLocal in the source: a CENTERED uniform random
% offset, narrower where the density is lower. Gain scales all spreads.
    jitter = zeros(numel(vals), 1);
    if numel(profile.y) < 2
        return;
    end
    contour_width = interp1(profile.y, profile.half_width, ...
        vals(:), 'linear', 0);
    contour_width(~isfinite(contour_width)) = 0;
    contour_width = max(0, contour_width);
    density_ratio = min(1, contour_width ./ violin_width);
    density_floor = 0.08; % matches densityAwareJitterLocal
    density_factor = density_floor + ...
        (1 - density_floor) .* density_ratio;
    local_spread = base_width .* gain .* density_factor;
    local_spread = min(local_spread, edge_fraction .* contour_width);
    stream = RandStream('mt19937ar', 'Seed', seed);
    jitter = (2 .* rand(stream, numel(vals), 1) - 1) .* ...
        local_spread;
end

function [q1, q3, whisker_low, whisker_high] = ...
        posterTukeySummaryLocal(vals)
% Whiskers end at the most extreme OBSERVED inliers, not at a theoretical
% Q1/Q3 +/- 1.5*IQR position that may contain no measured observation.
    q1 = posterInterpolatedPercentileLocal(vals, 25);
    q3 = posterInterpolatedPercentileLocal(vals, 75);
    iqr_value = q3 - q1;
    inliers = vals(vals >= q1 - 1.5 * iqr_value & ...
        vals <= q3 + 1.5 * iqr_value);
    whisker_low = min(inliers);
    whisker_high = max(inliers);
end

function posterDrawInnerMarksLocal(ax, x0, vals, center)
% Black Q1-Q3 bar, thin observed Tukey whiskers, horizontal selected mean/median mark.
    [q1, q3, whisker_low, whisker_high] = ...
        posterTukeySummaryLocal(vals);
    ink = [0, 0, 0];
    plot(ax, [x0, x0], [whisker_low, whisker_high], '-', ...
        'Color', ink, 'LineWidth', 1.1, 'HandleVisibility', 'off');
    for v = [whisker_low, whisker_high]
        plot(ax, [x0 - 0.06, x0 + 0.06], [v, v], '-', ...
            'Color', ink, 'LineWidth', 1.1, 'HandleVisibility', 'off');
    end
    plot(ax, [x0, x0], [q1, q3], '-', ...
        'Color', ink, 'LineWidth', 5, 'HandleVisibility', 'off');
    plot(ax, [x0 - 0.19, x0 + 0.19], ...
        [center, center], '-', ...
        'Color', [1, 1, 1], 'LineWidth', 4.5, ...
        'HandleVisibility', 'off');
    plot(ax, [x0 - 0.2, x0 + 0.2], ...
        [center, center], '-', ...
        'Color', ink, 'LineWidth', 2.3, ...
        'HandleVisibility', 'off');
end

function posterScatterLocal(ax, x, y, area_color, point_size, alpha)
    if isempty(y)
        return;
    end
    try
        scatter(ax, x, y, point_size, 'o', ...
            'MarkerFaceColor', area_color, ...
            'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', alpha, 'HandleVisibility', 'off');
    catch
        lighter = 1 - alpha * (1 - area_color);
        scatter(ax, x, y, point_size, 'o', ...
            'MarkerFaceColor', lighter, ...
            'MarkerEdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
end

function [f, xi] = estimateDensityLocal(vals)

    vals = vals(:);
    vals = vals(isfinite(vals));

    if isempty(vals) || numel(vals) < 2 || max(vals) == min(vals)
        f = [];
        xi = [];
        return;
    end

    if exist('ksdensity', 'file') == 2
        try
            [f, xi] = ksdensity(vals, 'NumPoints', 100);
            return;
        catch
            % Fall through to histogram fallback.
        end
    end

    num_bins = min(20, max(5, round(sqrt(numel(vals)))));

    try
        [counts, edges] = histcounts( ...
            vals, num_bins, 'Normalization', 'pdf');
    catch
        [counts, edges] = histcounts(vals, num_bins);
        bin_width = mean(diff(edges));

        if sum(counts) <= 0 || ~isfinite(bin_width) || bin_width <= 0
            f = [];
            xi = [];
            return;
        end

        counts = counts ./ (sum(counts) * bin_width);
    end

    xi = edges(1:end-1) + diff(edges) / 2;
    f = counts;

    valid = isfinite(f) & isfinite(xi);
    f = f(valid);
    xi = xi(valid);
end
