%% sum_GPL_class_deltavar_by_area_neuron.m
% Standalone script; all local functions are included in this file.
% INPUTS (read-only):
% model: each session's *_eachcond_variance_DSL_summary.mat plus bestmodel
%        varexp_raw.by_neuron. Run plot_dlag_results_for_each_condtion_mode_var
%        and latent_compare_for_each_condtion_mode first.
% posterior: each session's <model_mode>_mode/posterior_rawvar/postVar_*.mat.
%        Run posterior_rawvar.m with matching mode/source/u0 or u1 first.
% GPL labels: grouped unit_gpl_results_sponsub.mat files under Kilosort folders.
% Supported: each_condition + model; each_condition/all_condition + posterior.
% No independent noise or percentage variance. No reconstruction/refit here.
% A model neuron is identified by SESSION + MODEL GROUP + saved unit ID.
% All 16 conditions and the same ordered neuron IDs are required per session.
% The five variance categories are Across, Within, Feedforward, Feedback,
% Ambiguous. Empty latent categories have zero variance, not missing neurons.
% Z reference: selected neurons x 8 combinations x BOTH directions x all FIVE
% categories, separately within each session-area; sample SD (N-1).
% First standardize the original 16-condition variances, THEN equally average
% the two directions. Raw direction variances are also equally averaged.
% Stimulus matches: G-P, Small-Large, Low-High. Balances: Across-Within, FF-FB.
% NaN/Inf are excluded from the Z reference; an undefined Z baseline yields
% NaN Z values while preserving raw observations. Finite input var is required.
% The saved MAT retains direction arrays, neuron/session IDs, exact mean/SD,
% eight-condition values, matched differences and source provenance.
% File tags distinguish model mode, variance source, uncertainty, run, DSL and
% neuron population. Existing R2/session-direction outputs are not overwritten.
% EXPLORATORY FIGURES ONLY: no statistical tests. Directions are averaged;
% eight condition values and four matched feature differences remain separate.
% 'pooled' CONCATENATES them; it never averages these values within a neuron.
% All class plots show P/C/U separately. neuron_population selects the Z
% reference pool only; raw P/C/U class plots are unchanged by this option.
% plot_zscore controls Z figures only; both raw and Z arrays are retained.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';

% -------------------------------------------------------------------------
% Raw variance settings
% -------------------------------------------------------------------------

data_content = 'demean_count_within_t_and_condition';
% Options usually include:
%   raw_count
%   raw_fr
%   z_within_trial
%   z_within_condition
%   z_across_conditions
%   demean_count_within_trial
%   demean_fr_within_trial
%   demean_pooledsd_within_condition
%	demean_count_within_t_and_condition

% DLAG result-folder index, matching the original ANOVA program:
%   FA_Dlag_<data_content>/mat_results/run%03d
runIdx = 1; %1 means data, 2 means shuffle all units independently

var_split_mode = 'by_three_features'; % fixed; do not change

condition_display_mode = 'pooled';
% Options:
%   'separate' - keep conditions separate within every class x delta block;
%                condition colors and a legend identify the conditions
%   'pooled'   - concatenate all condition values within every class x
%                delta block; one neuron can contribute one value per
%                condition, and conditions are not averaged first

feature_delta_plot_mode = 'pooled';
% Options:
%   'off'      - do not calculate or plot stimulus-feature delta Var
%   'separate' - keep the four matched fixed-dimension combinations
%                separate inside every GPL-class x reconstruction block
%   'pooled'   - concatenate the four matched combinations inside every
%                GPL-class x reconstruction block without averaging first
% This option is independent of condition_display_mode above.
% Any value other than 'off' requires var_split_mode = 'by_three_features'.

plot_cross_session_condition_var = true;
% true  : in by_three_features mode, additionally plot the pooled-across-
%         session raw and z-scored Var comparison for every area x GPL class
% false : skip those additional undifferenced Var figures

% Source settings (must match the saved single-session results).
model_mode = 'all_condition';  % 'each_condition' or 'all_condition'
variance_source = 'posterior';      % 'model' or 'posterior'
uncertainty_included = 0;       % posterior only: selects saved u0/u1 file
DSL_filter = 'all_latents';     % model only: 'all_latents' / 'DSL_filtered'
DSL_threshold = 0.3;            % checked against saved value when filtered
variance_category_tag = 'across_within_ff_fb_amb'; % fixed saved categories

% -------------------------------------------------------------------------
% GPL settings
% -------------------------------------------------------------------------

% Display/file labels only. Their order must follow the DLAG model-group
% order represented by yDims and unit_ids_by_group.
group_names = {'V1', 'MT'};

% Spontaneous-subtracted GPL classification file.
gpl_mat_name = 'unit_gpl_results_sponsub.mat';
neuron_population = 'pcu_neurons'; % Z reference only: 'pcu_neurons' / 'all_neurons'
plot_zscore = false;              % raw figures are always drawn


% -------------------------------------------------------------------------
% Save settings
% -------------------------------------------------------------------------

save_mat = false;
save_fig = false;
save_svg = false;
save_png = false;
close_after_save = false;

figure_visible = 'on';
% 'on' or 'off'

png_dpi = 300;
print_full_error_report = false;

% -------------------------------------------------------------------------
% Violin settings
% -------------------------------------------------------------------------

violin_summary_type = 'mean';
% Options:
%   'mean'
%   'median'
% Controls the horizontal bar drawn inside every violin.

violin_width = 0.28;
violin_face_alpha = 0.20;

show_violin_points = true;
violin_point_size = 3;
violin_point_jitter_width = 0.08;
violin_point_alpha = 0.35;

% -------------------------------------------------------------------------
% Cross-session condition-comparison Var style (by_three_features only)
% -------------------------------------------------------------------------

% These settings match the reference condition-comparison plots.
var_condition_plot_style = 'bar_points';
% Options:
%   'bar_points'    : optional mean bar + points + optional median square
%   'violin'        : violin + points + optional mean diamond/median line
%   'points_median' : points + optional mean diamond/median line; no outline

var_condition_show_mean = struct( ...
    'bar_points', true, ...
    'violin', false, ...
    'points_median', false);

var_condition_show_median = struct( ...
    'bar_points', true, ...
    'violin', true, ...
    'points_median', true);

var_condition_point_size = 5;
var_condition_point_alpha = 0.70;
var_condition_point_jitter_width = 0.020;

var_condition_violin_alpha = 0.28;
var_condition_violin_width = 0.085;

var_condition_bar_alpha = 0.90;
var_condition_bar_width = 0.075;

var_condition_mean_marker_size = 5;
var_condition_median_marker_size = 5;
var_condition_median_line_width = 2.0;

var_condition_figure_width = 1600;
var_condition_figure_height = 760;

% -------------------------------------------------------------------------
% Condition colors and layout
% -------------------------------------------------------------------------

% Same eight-condition palette used by the other condition-wise programs.
% Rows follow this fixed order in by_three_features mode:
% G-S-L, G-S-H, G-L-L, G-L-H, P-S-L, P-S-H, P-L-L, P-L-H.
% by_stimtype uses the first two rows for grating and plaid.
condition_colors_base = lines(8);

% Used only when condition_display_mode = 'pooled'. Area identity is shown
% by the figure title/file name and is never encoded by color.
pooled_condition_color = [0.35, 0.35, 0.35];

% All stimulus-feature delta distributions use this neutral color.
feature_delta_color = [0.35, 0.35, 0.35];

% Distances are measured between violin centers. In separate mode,
% condition_step controls spacing inside one delta-type block.
condition_step = 0.70;
between_delta_gap = 1.35;
between_class_gap = 2.10;

% Article-figure typography and dimensions.
font_name = 'Arial';
axis_font_size = 11;
class_label_font_size = 10;
title_font_size = 12;
axis_line_width = 1;

figure_width = 1900;
figure_height = 780;

% -------------------------------------------------------------------------
% Fixed labels and source-field definitions
% -------------------------------------------------------------------------

class_names = {'pattern', 'component', 'unclassified'};
class_labels = {'Pattern cell', 'Component cell', 'Unclassified cell'};
class_markers = {'o', 's', '^'};
class_short_names = {'P', 'C', 'U'};

% All five raw variance fields share one normalization pool within
% every session x model group/area. The same mean and sample SD are applied
% before any delta is calculated.
var_field_names = {'use_across','use_within','use_feedforward', ...
    'use_feedback','use_ambiguous'};
var_field_labels = {'across','within','FF','FB','ambiguous'};
% All five categories enter normalization and undifferenced variance plots.
% The four source fields below enter feature/balance differences.
source_var_field_names = { ...
    'use_across', ...
    'use_within', ...
    'use_feedforward', ...
    'use_feedback'};

source_var_field_labels = {'across', 'within', 'FF', 'FB'};

% Full display labels used as the middle x-axis hierarchy in the optional
% stimulus-feature delta figures. Their order follows source_var_field_names.
feature_source_labels = { ...
    'Across', 'Within', 'Feedforward', 'Feedback'};

delta_names = {'acr_vs_wit', 'ff_vs_fb'};
delta_labels = {'acr vs. wit', 'ff vs. fb'};

delta_positive_fields = {'use_across', 'use_feedforward'};
delta_negative_fields = {'use_within', 'use_feedback'};

neuron_population = lower(strtrim(char(neuron_population)));
assertStringOptionLocal(var_split_mode,{'by_three_features'},'var_split_mode');
variance_config = neuronVarianceConfigLocal(data_content,runIdx,model_mode, ...
    variance_source,uncertainty_included,DSL_filter,DSL_threshold, ...
    group_names,neuron_population);
model_mode = variance_config.model_mode;
output_dir = fullfile(root_dir,variance_config.model_dir,'neuron_rawvar', 'condition_summary');
if (save_mat || save_fig || save_svg || save_png) && ~isfolder(output_dir)
    mkdir(output_dir);
end

%% ======================= VALIDATE SETTINGS =============================

group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);
mapping_file_tag = strjoin(group_file_tags, '_');

[var_split_mode, split_file_tag, stim_types, category_labels] = ...
    getVarSplitConfigLocal(var_split_mode);

condition_display_mode = lower(strtrim(char(condition_display_mode)));
feature_delta_plot_mode = lower(strtrim(char(feature_delta_plot_mode)));
feature_delta_definitions = buildFeatureDeltaDefinitionsLocal();
feature_delta_enabled = ~strcmp(feature_delta_plot_mode, 'off');
validateLogicalScalarLocal(plot_zscore,'plot_zscore');
plot_value_modes = {'raw'};
if plot_zscore, plot_value_modes{end+1}='zscore'; end

var_condition_plot_style = ...
    normalizeConditionComparisonStyleLocal(var_condition_plot_style);
validatePlotStatisticOptionsLocal( ...
    var_condition_show_mean, 'var_condition_show_mean');
validatePlotStatisticOptionsLocal( ...
    var_condition_show_median, 'var_condition_show_median');

var_condition_compare_config = struct();
var_condition_compare_config.plot_style = var_condition_plot_style;
var_condition_compare_config.show_mean = logical( ...
    var_condition_show_mean.(var_condition_plot_style));
var_condition_compare_config.show_median = logical( ...
    var_condition_show_median.(var_condition_plot_style));
var_condition_compare_config.point_size = var_condition_point_size;
var_condition_compare_config.point_alpha = var_condition_point_alpha;
var_condition_compare_config.point_jitter_width = ...
    var_condition_point_jitter_width;
var_condition_compare_config.violin_alpha = ...
    var_condition_violin_alpha;
var_condition_compare_config.violin_width = ...
    var_condition_violin_width;
var_condition_compare_config.bar_alpha = var_condition_bar_alpha;
var_condition_compare_config.bar_width = var_condition_bar_width;
var_condition_compare_config.mean_marker_size = ...
    var_condition_mean_marker_size;
var_condition_compare_config.median_marker_size = ...
    var_condition_median_marker_size;
var_condition_compare_config.median_line_width = ...
    var_condition_median_line_width;
var_condition_compare_config.figure_width = ...
    var_condition_figure_width;
var_condition_compare_config.figure_height = ...
    var_condition_figure_height;
validateConditionComparisonConfigLocal(var_condition_compare_config);

validateUserSettingsLocal( ...
    root_dir, data_content, model_mode, var_split_mode, ...
    condition_display_mode, feature_delta_plot_mode, ...
    plot_cross_session_condition_var, runIdx, ...
    variance_category_tag, group_names, gpl_mat_name, ...
    condition_colors_base, pooled_condition_color, ...
    feature_delta_color, figure_visible, ...
    class_names, class_labels, class_markers, class_short_names, ...
    var_field_names, var_field_labels, ...
    source_var_field_names, source_var_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, ...
    violin_summary_type, ...
    save_mat, save_fig, save_svg, save_png, close_after_save, ...
    png_dpi, violin_width, violin_face_alpha, ...
    show_violin_points, violin_point_size, ...
    violin_point_jitter_width, violin_point_alpha, ...
    condition_step, between_delta_gap, between_class_gap, ...
    figure_width, figure_height, feature_delta_definitions);

var_condition_comparison_enabled = ...
    logical(plot_cross_session_condition_var) && ...
    strcmp(var_split_mode, 'by_three_features');

condition_colors = condition_colors_base(1:numel(stim_types), :);

model_tag = makeModelTagLocal(model_mode);

output_prefix = ['sumNdV_' variance_config.file_tag];
output_base = sprintf('%s_%s_%s_feat%s_z%d_cond%d',output_prefix,mapping_file_tag, ...
    condition_display_mode,feature_delta_plot_mode,plot_zscore,plot_cross_session_condition_var);

fprintf('\n============================================================\n');
fprintf('Across-session GPL-class delta Var summary by area\n');
fprintf('Root dir              : %s\n', root_dir);
fprintf('Data content          : %s\n', data_content);
fprintf('Model mode            : %s\n', model_mode);
fprintf('Var split mode         : %s\n', var_split_mode);
fprintf('Condition display     : %s\n', condition_display_mode);
fprintf('Feature-delta plots   : %s\n', feature_delta_plot_mode);
if var_condition_comparison_enabled
    fprintf('Var condition compare  : on (%s)\n', ...
        var_condition_plot_style);
elseif plot_cross_session_condition_var
    fprintf(['Var condition compare  : skipped ', ...
        '(requires by_three_features)\n']);
else
    fprintf('Var condition compare  : off\n');
end
fprintf('Run index             : %d\n', runIdx);
fprintf('GPL MAT               : %s\n', gpl_mat_name);
fprintf('Delta 1               : across - within\n');
fprintf('Delta 2               : feedforward - feedback\n');
fprintf('Variance source       : %s (effective uncertainty=%d)\n', ...
    variance_config.variance_source,variance_config.uncertainty_included);
fprintf('Z-score pool          : %s x 16 conditions x %d categories, per session-area\n', ...
    neuron_population,numel(var_field_names));
fprintf('Z-score order         : standardize, mean two directions, then differences\n');
fprintf('Z-score SD            : sample SD (N-1 normalization)\n');
fprintf('Violin summary bar    : %s\n', violin_summary_type);
fprintf('Value figures         : raw; Z-score figures enabled=%d\n',plot_zscore);
if feature_delta_enabled
    fprintf(['Feature-delta Z       : uses the same session x area ', ...
        'Var mean and SD before subtraction\n']);
end
fprintf('Group labels          :\n');
for g = 1:numel(group_names)
    fprintf('  %s\n', group_display_names{g});
end
fprintf('Summary output base   : %s\n', output_base);
fprintf('============================================================\n');

%% ======================= FIND SESSION FOLDERS ==========================

session_dirs = findCatgtSessionDirsLocal(root_dir);

if isempty(session_dirs)
    error('No catgt_* folders found one level below root_dir: %s', root_dir);
end

fprintf('\nFound %d candidate catgt_* session folders.\n', ...
    numel(session_dirs));

%% ======================= READ ALL SESSIONS =============================

records = {};
skipped = struct('session_dir', {}, 'reason', {});
reference = struct();

for si = 1:numel(session_dirs)
    session_dir = session_dirs{si};

    fprintf('\n[%d/%d] Reading %s\n', ...
        si, numel(session_dirs), session_dir);

    try
        [rec, reference] = readOneSessionLocal( ...
            session_dir, data_content, model_mode, var_split_mode, ...
            split_file_tag, runIdx, ...
            variance_category_tag, group_names, group_display_names, ...
            group_file_tags, gpl_mat_name, ...
            var_field_names, source_var_field_names, delta_names, ...
            delta_positive_fields, delta_negative_fields, ...
            stim_types, category_labels, feature_delta_plot_mode, ...
            feature_delta_definitions, reference, neuron_population, variance_config);

        records{end + 1} = rec; %#ok<SAGROW>

    catch ME
        skipped(end + 1).session_dir = session_dir; %#ok<SAGROW>
        skipped(end).reason = ME.message;

        warning('Skipping session: %s\nReason: %s', ...
            session_dir, ME.message);

        if print_full_error_report
            fprintf('\nFull error report for skipped session:\n');
            fprintf('%s\n', getReport(ME, 'extended', ...
                'hyperlinks', 'off'));
        end
    end
end

if isempty(records)
    fprintf('\nSkipped sessions:\n');

    for k = 1:numel(skipped)
        fprintf('  %s\n    %s\n', ...
            skipped(k).session_dir, skipped(k).reason);
    end

    error('No valid sessions were loaded.');
end

num_sessions = numel(records);

for s = 1:num_sessions
    records{s}.session_index = s;
    records{s}.session_label = sprintf('S%d', s);
end

fprintf('\nLoaded %d valid sessions.\n', num_sessions);
fprintf('Skipped %d sessions.\n', numel(skipped));

fprintf('\nSession mapping retained in the MAT file:\n');

for s = 1:num_sessions
    fprintf('  %-4s -> %s/%s\n', ...
        records{s}.session_label, ...
        records{s}.session_parent_name, ...
        records{s}.catgt_name);
end

%% ======================= BUILD AND SAVE SUMMARY ========================

MultiSessionGPLClassDeltaVarNeuron = buildMultiSessionDeltaSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, ...
    var_split_mode, split_file_tag, runIdx, ...
    variance_category_tag, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, class_short_names, ...
    var_field_names, var_field_labels, ...
    source_var_field_names, source_var_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, category_labels, ...
    output_prefix, output_base, condition_display_mode, ...
    condition_colors, pooled_condition_color, plot_value_modes, ...
    violin_summary_type, condition_step, between_delta_gap, ...
    between_class_gap, feature_delta_plot_mode, ...
    feature_delta_color, feature_delta_definitions, ...
    plot_cross_session_condition_var, ...
    var_condition_comparison_enabled, ...
    var_condition_compare_config);


MultiSessionGPLClassDeltaVarNeuron.meta.created_by = 'sum_GPL_class_deltavar_by_area_neuron.m';
MultiSessionGPLClassDeltaVarNeuron.meta.variance_source = variance_config.variance_source;
MultiSessionGPLClassDeltaVarNeuron.meta.model_mode = variance_config.model_mode;
MultiSessionGPLClassDeltaVarNeuron.meta.uncertainty_included = variance_config.uncertainty_included;
MultiSessionGPLClassDeltaVarNeuron.meta.neuron_population = neuron_population;
MultiSessionGPLClassDeltaVarNeuron.meta.output_dir = output_dir;
MultiSessionGPLClassDeltaVarNeuron.settings.variance = variance_config;
MultiSessionGPLClassDeltaVarNeuron.notes.zscore_definition = [ ...
    'Selected neurons, all 16 direction/condition combinations and all five ', ...
    'variance categories within each session-area; common mean/sample SD ', ...
    'before equal direction averaging and before any subtraction.'];
MultiSessionGPLClassDeltaVarNeuron.notes.direction_averaging = ...
    'Equal mean of two already-computed direction variances; no trial pooling.';
MultiSessionGPLClassDeltaVarNeuron.notes.invalid_neurons = ...
    'Figures show P/C/U separately. neuron_population selects only the shared Z reference.';
MultiSessionGPLClassDeltaVarNeuron.dimension_names.direction_var = ...
    {'neuron','feature_combination','direction','latent_category'};
MultiSessionGPLClassDeltaVarNeuron.dimension_names.direction_zvar = ...
    MultiSessionGPLClassDeltaVarNeuron.dimension_names.direction_var;
MultiSessionGPLClassDeltaVarNeuron.settings.plot_zscore = logical(plot_zscore);
MultiSessionGPLClassDeltaVarNeuron.meta.test_unit = 'none_no_statistics';

if save_mat
    mat_file = fullfile(output_dir, [output_base, '.mat']);
    save(mat_file, 'MultiSessionGPLClassDeltaVarNeuron', '-v7.3');
    fprintf('\nSaved MAT:\n  %s\n', mat_file);
end

%% ======================= PLOT GROUP FIGURES ============================

fig_handles = gobjects(numel(group_names), numel(plot_value_modes));

for g = 1:numel(group_names)
    for vm = 1:numel(plot_value_modes)
        value_mode = plot_value_modes{vm};

        fig = plotCombinedDeltaSummaryLocal( ...
            MultiSessionGPLClassDeltaVarNeuron.pooled(g), ...
            stim_types, category_labels, condition_display_mode, ...
            value_mode, group_display_names{g}, ...
            class_names, class_labels, class_markers, ...
            delta_names, delta_labels, condition_colors, ...
            pooled_condition_color, ...
            violin_summary_type, violin_width, violin_face_alpha, ...
            show_violin_points, violin_point_size, ...
            violin_point_jitter_width, violin_point_alpha, ...
            condition_step, between_delta_gap, between_class_gap, ...
            font_name, axis_font_size, class_label_font_size, ...
            title_font_size, axis_line_width, ...
            figure_visible, figure_width, figure_height);

        fig_handles(g, vm) = fig;

        figure_base = sprintf('%s_%s_%s_%s', ...
            output_prefix, group_file_tags{g}, ...
            condition_display_mode, value_mode);

        if save_fig
            fig_file = fullfile(output_dir, [figure_base, '.fig']);
            saveFigLocal(fig, fig_file);
            fprintf('Saved FIG:\n  %s\n', fig_file);
        end

        if save_svg
            svg_file = fullfile(output_dir, [figure_base, '.svg']);
            saveSvgLocal(fig, svg_file);
            fprintf('Saved SVG:\n  %s\n', svg_file);
        end

        if save_png
            png_file = fullfile(output_dir, [figure_base, '.png']);
            savePngLocal(fig, png_file, png_dpi);
            fprintf('Saved PNG:\n  %s\n', png_file);
        end

        if close_after_save
            close(fig);
        end
    end
end

%% ================= PLOT STIMULUS-FEATURE DELTAS =======================

if feature_delta_enabled
    feature_fig_handles = gobjects( ...
        numel(group_names), numel(feature_delta_definitions), ...
        numel(plot_value_modes));

    for g = 1:numel(group_names)
        for e = 1:numel(feature_delta_definitions)
            D = feature_delta_definitions(e);
            pooled_effect = MultiSessionGPLClassDeltaVarNeuron.feature_delta_pooled(g).effect.(D.name);

            for vm = 1:numel(plot_value_modes)
                value_mode = plot_value_modes{vm};

                fig = plotFeatureDeltaSummaryLocal( ...
                    pooled_effect, D, feature_delta_plot_mode, ...
                    value_mode, group_display_names{g}, ...
                    class_names, class_labels, class_markers, ...
                    feature_source_labels, feature_delta_color, ...
                    violin_summary_type, violin_width, ...
                    violin_face_alpha, show_violin_points, ...
                    violin_point_size, violin_point_jitter_width, ...
                    violin_point_alpha, condition_step, ...
                    between_delta_gap, between_class_gap, ...
                    font_name, axis_font_size, ...
                    class_label_font_size, title_font_size, ...
                    axis_line_width, figure_visible, ...
                    figure_width, figure_height);

                feature_fig_handles(g, e, vm) = fig;

                figure_base = sprintf( ...
                    '%s_%s_featuredelta_%s_%s_%s', ...
                    output_prefix, group_file_tags{g}, ...
                    D.file_tag, feature_delta_plot_mode, value_mode);

                if save_fig
                    fig_file = fullfile(output_dir, [figure_base, '.fig']);
                    saveFigLocal(fig, fig_file);
                    fprintf('Saved FIG:\n  %s\n', fig_file);
                end

                if save_svg
                    svg_file = fullfile(output_dir, [figure_base, '.svg']);
                    saveSvgLocal(fig, svg_file);
                    fprintf('Saved SVG:\n  %s\n', svg_file);
                end

                if save_png
                    png_file = fullfile(output_dir, [figure_base, '.png']);
                    savePngLocal(fig, png_file, png_dpi);
                    fprintf('Saved PNG:\n  %s\n', png_file);
                end

                if close_after_save
                    close(fig);
                end
            end
        end
    end
end

%% ============== PLOT CROSS-SESSION UNDIFFERENCED Var ==================

if var_condition_comparison_enabled
    var_condition_fig_handles = gobjects( ...
        numel(group_names), numel(class_names), ...
        numel(plot_value_modes));

    for g = 1:numel(group_names)
        for c = 1:numel(class_names)
            for vm = 1:numel(plot_value_modes)
                value_mode = plot_value_modes{vm};

                fig = plotCrossSessionConditionVarLocal( ...
                    MultiSessionGPLClassDeltaVarNeuron.pooled(g), ...
                    stim_types, category_labels, ...
                    var_field_names, var_field_labels, ...
                    class_names{c}, class_labels{c}, c, ...
                    value_mode, group_display_names{g}, ...
                    data_content, model_mode, condition_colors, ...
                    figure_visible, var_condition_compare_config);

                var_condition_fig_handles(g, c, vm) = fig;

                figure_base = sprintf('%s_%s_%s_cond_%s_%s',output_prefix, ...
                    group_file_tags{g},class_short_names{c},var_condition_plot_style,value_mode);

                if save_fig
                    fig_file = fullfile(output_dir, [figure_base, '.fig']);
                    saveFigLocal(fig, fig_file);
                    fprintf('Saved FIG:\n  %s\n', fig_file);
                end

                if save_svg
                    svg_file = fullfile(output_dir, [figure_base, '.svg']);
                    saveSvgLocal(fig, svg_file);
                    fprintf('Saved SVG:\n  %s\n', svg_file);
                end

                if save_png
                    png_file = fullfile(output_dir, [figure_base, '.png']);
                    savePngLocal(fig, png_file, png_dpi);
                    fprintf('Saved PNG:\n  %s\n', png_file);
                end

                if close_after_save
                    close(fig);
                end
            end
        end
    end
end

fprintf('\nDone.\n');

%% =======================================================================
% Local functions
% ========================================================================

function [mode, file_tag, category_fields, category_labels] = ...
        getVarSplitConfigLocal(mode)

    if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
        error('var_split_mode must be a character vector or string scalar.');
    end

    mode = lower(strtrim(char(mode)));

    switch mode
        case 'by_stimtype'
            file_tag = 'stimtype';
            category_fields = {'grating', 'plaid'};
            category_labels = {'grating', 'plaid'};

        case 'by_three_features'
            file_tag = 'stszct';
            category_fields = { ...
                'G_S_L', 'G_S_H', 'G_L_L', 'G_L_H', ...
                'P_S_L', 'P_S_H', 'P_L_L', 'P_L_H'};
            category_labels = { ...
                'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
                'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};

        otherwise
            error(['Unknown var_split_mode: %s. Valid options are ', ...
                '''by_stimtype'' and ''by_three_features''.'], mode);
    end
end

function style = normalizeConditionComparisonStyleLocal(style)

    if ~(ischar(style) || (isstring(style) && isscalar(style)))
        error(['var_condition_plot_style must be a character vector ', ...
            'or string scalar.']);
    end

    style = lower(strtrim(char(style)));
    valid_styles = {'bar_points', 'violin', 'points_median'};

    if ~any(strcmp(style, valid_styles))
        error(['var_condition_plot_style = ''%s'' is invalid. Valid ', ...
            'options are: %s.'], style, strjoin(valid_styles, ', '));
    end
end

function validatePlotStatisticOptionsLocal(options, variable_name)

    required_fields = {'bar_points', 'violin', 'points_median'};

    if ~(isstruct(options) && isscalar(options))
        error('%s must be a scalar struct.', variable_name);
    end

    for k = 1:numel(required_fields)
        field_name = required_fields{k};

        if ~isfield(options, field_name)
            error('%s is missing field %s.', variable_name, field_name);
        end

        value = options.(field_name);
        valid = ...
            (islogical(value) || isnumeric(value)) && ...
            isscalar(value) && ...
            isfinite(double(value)) && ...
            ismember(double(value), [0, 1]);

        if ~valid
            error('%s.%s must be a logical scalar.', ...
                variable_name, field_name);
        end
    end
end

function validateConditionComparisonConfigLocal(config)

    required_fields = { ...
        'plot_style', ...
        'show_mean', ...
        'show_median', ...
        'point_size', ...
        'point_alpha', ...
        'point_jitter_width', ...
        'violin_alpha', ...
        'violin_width', ...
        'bar_alpha', ...
        'bar_width', ...
        'mean_marker_size', ...
        'median_marker_size', ...
        'median_line_width', ...
        'figure_width', ...
        'figure_height'};

    for i = 1:numel(required_fields)
        if ~isfield(config, required_fields{i})
            error(['Var condition-comparison config is missing ', ...
                'field %s.'], required_fields{i});
        end
    end

    normalizeConditionComparisonStyleLocal(config.plot_style);
    validateLogicalScalarLocal(config.show_mean, ...
        'var condition-comparison show_mean');
    validateLogicalScalarLocal(config.show_median, ...
        'var condition-comparison show_median');

    validateattributes(config.point_size, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_point_size');
    validateattributes(config.point_alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'var_condition_point_alpha');
    validateattributes(config.point_jitter_width, {'numeric'}, ...
        {'scalar', 'real', 'nonnegative', 'finite'}, ...
        mfilename, 'var_condition_point_jitter_width');
    validateattributes(config.violin_alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'var_condition_violin_alpha');
    validateattributes(config.violin_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_violin_width');
    validateattributes(config.bar_alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'var_condition_bar_alpha');
    validateattributes(config.bar_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_bar_width');
    validateattributes(config.mean_marker_size, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_mean_marker_size');
    validateattributes(config.median_marker_size, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_median_marker_size');
    validateattributes(config.median_line_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_median_line_width');
    validateattributes(config.figure_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_figure_width');
    validateattributes(config.figure_height, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'var_condition_figure_height');
end

function definitions = buildFeatureDeltaDefinitionsLocal()
% Each row replaces exactly one position in the canonical
% stimulus-type / size / contrast label with a matched subtraction.

    template = struct( ...
        'name', '', ...
        'file_tag', '', ...
        'title', '', ...
        'subscript', '', ...
        'fixed_labels', {{}}, ...
        'positive_stim', {{}}, ...
        'negative_stim', {{}});

    definitions = repmat(template, 1, 3);

    definitions(1).name = 'stimtype_G_minus_P';
    definitions(1).file_tag = 'GP';
    definitions(1).title = 'Stimulus type effect: Grating - Plaid';
    definitions(1).subscript = 'GP';
    definitions(1).fixed_labels = { ...
        '\Delta-S-L', '\Delta-S-H', ...
        '\Delta-L-L', '\Delta-L-H'};
    definitions(1).positive_stim = { ...
        'G_S_L', 'G_S_H', 'G_L_L', 'G_L_H'};
    definitions(1).negative_stim = { ...
        'P_S_L', 'P_S_H', 'P_L_L', 'P_L_H'};

    definitions(2).name = 'size_S_minus_L';
    definitions(2).file_tag = 'SL';
    definitions(2).title = 'Size effect: Small - Large';
    definitions(2).subscript = 'SL';
    definitions(2).fixed_labels = { ...
        'G-\Delta-L', 'G-\Delta-H', ...
        'P-\Delta-L', 'P-\Delta-H'};
    definitions(2).positive_stim = { ...
        'G_S_L', 'G_S_H', 'P_S_L', 'P_S_H'};
    definitions(2).negative_stim = { ...
        'G_L_L', 'G_L_H', 'P_L_L', 'P_L_H'};

    definitions(3).name = 'contrast_Low_minus_High';
    definitions(3).file_tag = 'LH';
    definitions(3).title = 'Contrast effect: Low - High';
    definitions(3).subscript = 'LH';
    definitions(3).fixed_labels = { ...
        'G-S-\Delta', 'G-L-\Delta', ...
        'P-S-\Delta', 'P-L-\Delta'};
    definitions(3).positive_stim = { ...
        'G_S_L', 'G_L_L', 'P_S_L', 'P_L_L'};
    definitions(3).negative_stim = { ...
        'G_S_H', 'G_L_H', 'P_S_H', 'P_L_H'};
end

function validateUserSettingsLocal( ...
    root_dir, data_content, model_mode, var_split_mode, ...
    condition_display_mode, feature_delta_plot_mode, ...
    plot_cross_session_condition_var, runIdx, ...
    variance_category_tag, group_names, gpl_mat_name, ...
    condition_colors_base, pooled_condition_color, ...
    feature_delta_color, figure_visible, ...
    class_names, class_labels, class_markers, class_short_names, ...
    var_field_names, var_field_labels, ...
    source_field_names, source_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, ...
    violin_summary_type, ...
    save_mat, save_fig, save_svg, save_png, close_after_save, ...
    png_dpi, violin_width, violin_face_alpha, ...
    show_violin_points, violin_point_size, ...
    violin_point_jitter_width, violin_point_alpha, ...
    condition_step, between_delta_gap, between_class_gap, ...
    figure_width, figure_height, feature_delta_definitions)

    if ~ischar(root_dir) && ~isstring(root_dir)
        error('root_dir must be a char or string.');
    end

    root_dir = char(root_dir);

    if ~isfolder(root_dir)
        error('root_dir does not exist: %s', root_dir);
    end

    requireNonemptyTextLocal(data_content, 'data_content');
    requireNonemptyTextLocal(variance_category_tag, ...
        'variance_category_tag');
    requireNonemptyTextLocal(gpl_mat_name, 'gpl_mat_name');

    valid_model_modes = { ...
        'all_condition', ...
        'each_condition'};

    assertStringOptionLocal(model_mode, valid_model_modes, 'model_mode');
    assertStringOptionLocal(var_split_mode, ...
        {'by_stimtype', 'by_three_features'}, 'var_split_mode');
    assertStringOptionLocal(condition_display_mode, ...
        {'separate', 'pooled'}, 'condition_display_mode');
    assertStringOptionLocal(feature_delta_plot_mode, ...
        {'off', 'separate', 'pooled'}, 'feature_delta_plot_mode');
    assertStringOptionLocal(figure_visible, {'on', 'off'}, ...
        'figure_visible');
    validateLogicalScalarLocal(plot_cross_session_condition_var, ...
        'plot_cross_session_condition_var');

    if ~strcmp(feature_delta_plot_mode, 'off') && ...
            ~strcmp(var_split_mode, 'by_three_features')
        error(['feature_delta_plot_mode = ''%s'' requires ', ...
            'var_split_mode = ''by_three_features''.'], ...
            feature_delta_plot_mode);
    end

    validateattributes(runIdx, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, ...
        mfilename, 'runIdx');

    if ~iscell(group_names) || isempty(group_names)
        error('group_names must be a nonempty cell array of text.');
    end

    for g = 1:numel(group_names)
        requireNonemptyTextLocal(group_names{g}, ...
            sprintf('group_names{%d}', g));
    end

    if ~isnumeric(condition_colors_base) || ...
            size(condition_colors_base, 1) < numel(stim_types) || ...
            size(condition_colors_base, 2) ~= 3 || ...
            any(~isfinite(condition_colors_base(:))) || ...
            any(condition_colors_base(:) < 0) || ...
            any(condition_colors_base(:) > 1)
        error(['condition_colors_base must contain at least one finite ', ...
            'RGB row in [0,1] per Var condition.']);
    end

    if ~isnumeric(pooled_condition_color) || ...
            ~isequal(size(pooled_condition_color), [1, 3]) || ...
            any(~isfinite(pooled_condition_color)) || ...
            any(pooled_condition_color < 0) || ...
            any(pooled_condition_color > 1)
        error(['pooled_condition_color must be one finite 1-by-3 RGB ', ...
            'row in [0,1].']);
    end

    if ~isnumeric(feature_delta_color) || ...
            ~isequal(size(feature_delta_color), [1, 3]) || ...
            any(~isfinite(feature_delta_color)) || ...
            any(feature_delta_color < 0) || ...
            any(feature_delta_color > 1)
        error(['feature_delta_color must be one finite 1-by-3 RGB ', ...
            'row in [0,1].']);
    end

    validateParallelLabelListsLocal( ...
        class_names, class_labels, 'class_names', 'class_labels');
    validateParallelLabelListsLocal( ...
        class_names, class_short_names, ...
        'class_names', 'class_short_names');

    for c = 1:numel(class_names)
        if ~isvarname(char(class_names{c}))
            error('class_names{%d} must be a valid MATLAB field name.', c);
        end
    end
    validateParallelLabelListsLocal( ...
        var_field_names, var_field_labels, ...
        'var_field_names', 'var_field_labels');

    required_var_fields = {'use_across','use_within','use_feedforward', ...
        'use_feedback','use_ambiguous'};

    if ~isequal(reshape(var_field_names, 1, []), required_var_fields)
        error(['var_field_names must retain this order: ', ...
            'use_across, use_within, use_feedforward, ', ...
            'use_feedback, use_ambiguous.']);
    end

    validateParallelLabelListsLocal( ...
        source_field_names, source_field_labels, ...
        'source_var_field_names', 'source_var_field_labels');
    validateParallelLabelListsLocal( ...
        source_field_names, feature_source_labels, ...
        'source_var_field_names', 'feature_source_labels');
    validateParallelLabelListsLocal( ...
        delta_names, delta_labels, 'delta_names', 'delta_labels');

    if ~any(strcmp('use_ambiguous', var_field_names))
        error('var_field_names must include use_ambiguous.');
    end

    for f = 1:numel(source_field_names)
        if ~any(strcmp(source_field_names{f}, var_field_names))
            error(['source_var_field_names{%d} is unavailable in ', ...
                'var_field_names.'], f);
        end
    end

    for d = 1:numel(delta_names)
        if ~isvarname(char(delta_names{d}))
            error('delta_names{%d} must be a valid MATLAB field name.', d);
        end
    end

    if ~iscell(class_markers) || ...
            numel(class_markers) ~= numel(class_names)
        error('class_markers must contain one marker per GPL class.');
    end

    for c = 1:numel(class_markers)
        requireNonemptyTextLocal(class_markers{c}, ...
            sprintf('class_markers{%d}', c));
    end

    if ~iscell(delta_positive_fields) || ...
            ~iscell(delta_negative_fields) || ...
            numel(delta_positive_fields) ~= numel(delta_names) || ...
            numel(delta_negative_fields) ~= numel(delta_names)
        error(['delta_positive_fields and delta_negative_fields must ', ...
            'contain one source-field name per delta.']);
    end

    for d = 1:numel(delta_names)
        requireNonemptyTextLocal(delta_positive_fields{d}, ...
            sprintf('delta_positive_fields{%d}', d));
        requireNonemptyTextLocal(delta_negative_fields{d}, ...
            sprintf('delta_negative_fields{%d}', d));

        if ~any(strcmp(delta_positive_fields{d}, source_field_names)) || ...
                ~any(strcmp(delta_negative_fields{d}, source_field_names))
            error(['Delta %s refers to a field not present in ', ...
                'source_var_field_names.'], delta_names{d});
        end
    end

    if ~iscell(stim_types) || isempty(stim_types)
        error('stim_types must be a nonempty cell array.');
    end

    validateParallelLabelListsLocal( ...
        stim_types, category_labels, 'stim_types', 'category_labels');

    for st = 1:numel(stim_types)
        requireNonemptyTextLocal(stim_types{st}, ...
            sprintf('stim_types{%d}', st));

        if ~isvarname(char(stim_types{st}))
            error('stim_types{%d} must be a valid MATLAB field name.', st);
        end
    end

    if ~strcmp(feature_delta_plot_mode, 'off')
        validateFeatureDeltaDefinitionsLocal( ...
            feature_delta_definitions, stim_types);
    end

    assertStringOptionLocal(violin_summary_type, ...
        {'mean', 'median'}, 'violin_summary_type');

    validateLogicalScalarLocal(save_mat, 'save_mat');
    validateLogicalScalarLocal(save_fig, 'save_fig');
    validateLogicalScalarLocal(save_svg, 'save_svg');
    validateLogicalScalarLocal(save_png, 'save_png');
    validateLogicalScalarLocal(close_after_save, 'close_after_save');
    validateLogicalScalarLocal(show_violin_points, ...
        'show_violin_points');

    validateattributes(png_dpi, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'png_dpi');
    validateattributes(violin_width, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'violin_width');
    validateattributes(violin_face_alpha, {'numeric'}, ...
        {'scalar', '>=', 0, '<=', 1, 'finite'}, ...
        mfilename, 'violin_face_alpha');
    validateattributes(violin_point_size, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, ...
        mfilename, 'violin_point_size');
    validateattributes(violin_point_jitter_width, {'numeric'}, ...
        {'scalar', 'nonnegative', 'finite'}, ...
        mfilename, 'violin_point_jitter_width');
    validateattributes(violin_point_alpha, {'numeric'}, ...
        {'scalar', '>=', 0, '<=', 1, 'finite'}, ...
        mfilename, 'violin_point_alpha');
    validateattributes(condition_step, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, ...
        mfilename, 'condition_step');
    validateattributes(between_delta_gap, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, ...
        mfilename, 'between_delta_gap');
    validateattributes(between_class_gap, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, ...
        mfilename, 'between_class_gap');
    validateattributes(figure_width, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'figure_width');
    validateattributes(figure_height, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'figure_height');
end

function validateFeatureDeltaDefinitionsLocal(definitions, stim_types)

    required_fields = { ...
        'name', 'file_tag', 'title', 'subscript', ...
        'fixed_labels', 'positive_stim', 'negative_stim'};

    if ~isstruct(definitions) || numel(definitions) ~= 3
        error('feature_delta_definitions must contain exactly 3 entries.');
    end

    definition_names = cell(1, numel(definitions));
    file_tags = cell(1, numel(definitions));

    for e = 1:numel(definitions)
        D = definitions(e);

        for f = 1:numel(required_fields)
            if ~isfield(D, required_fields{f})
                error(['Feature-delta definition %d is missing ', ...
                    'field %s.'], e, required_fields{f});
            end
        end

        requireNonemptyTextLocal(D.name, ...
            sprintf('feature_delta_definitions(%d).name', e));
        requireNonemptyTextLocal(D.file_tag, ...
            sprintf('feature_delta_definitions(%d).file_tag', e));
        requireNonemptyTextLocal(D.title, ...
            sprintf('feature_delta_definitions(%d).title', e));
        requireNonemptyTextLocal(D.subscript, ...
            sprintf('feature_delta_definitions(%d).subscript', e));

        if ~isvarname(char(D.name))
            error('Feature-delta name %s is not a valid field name.', ...
                char(D.name));
        end

        if ~iscell(D.fixed_labels) || ...
                ~iscell(D.positive_stim) || ...
                ~iscell(D.negative_stim) || ...
                numel(D.fixed_labels) ~= 4 || ...
                numel(D.positive_stim) ~= 4 || ...
                numel(D.negative_stim) ~= 4
            error(['Feature-delta definition %s must contain exactly ', ...
                'four labels and four matched stimulus pairs.'], D.name);
        end

        for k = 1:4
            requireNonemptyTextLocal(D.fixed_labels{k}, ...
                sprintf('%s.fixed_labels{%d}', D.name, k));
            requireNonemptyTextLocal(D.positive_stim{k}, ...
                sprintf('%s.positive_stim{%d}', D.name, k));
            requireNonemptyTextLocal(D.negative_stim{k}, ...
                sprintf('%s.negative_stim{%d}', D.name, k));

            if ~any(strcmp(D.positive_stim{k}, stim_types)) || ...
                    ~any(strcmp(D.negative_stim{k}, stim_types))
                error(['Feature-delta definition %s pair %d refers to ', ...
                    'a stimulus field unavailable in var_split_mode.'], ...
                    D.name, k);
            end

            if strcmp(D.positive_stim{k}, D.negative_stim{k})
                error(['Feature-delta definition %s pair %d subtracts ', ...
                    'a stimulus field from itself.'], D.name, k);
            end
        end

        definition_names{e} = char(D.name);
        file_tags{e} = char(D.file_tag);
    end

    if numel(unique(definition_names)) ~= numel(definition_names) || ...
            numel(unique(file_tags)) ~= numel(file_tags)
        error('Feature-delta names and file tags must be unique.');
    end
end

function validateLogicalScalarLocal(value, var_name)
    if ~(islogical(value) || isnumeric(value)) || ...
            ~isscalar(value) || ~isfinite(double(value)) || ...
            ~ismember(double(value), [0, 1])
        error('%s must be one logical scalar.', var_name);
    end
end

function validateParallelLabelListsLocal( ...
    names, labels, names_var, labels_var)

    if ~iscell(names) || ~iscell(labels) || isempty(names) || ...
            numel(names) ~= numel(labels)
        error('%s and %s must be nonempty equal-length cell arrays.', ...
            names_var, labels_var);
    end

    for i = 1:numel(names)
        requireNonemptyTextLocal(names{i}, ...
            sprintf('%s{%d}', names_var, i));
        requireNonemptyTextLocal(labels{i}, ...
            sprintf('%s{%d}', labels_var, i));
    end

    names_char = cellfun(@char, names, 'UniformOutput', false);

    if numel(unique(names_char, 'stable')) ~= numel(names_char)
        error('%s contains duplicate entries.', names_var);
    end
end

function requireNonemptyTextLocal(value, var_name)
    if ~(ischar(value) || (isstring(value) && isscalar(value))) || ...
            isempty(char(value))
        error('%s must be nonempty text.', var_name);
    end
end

function values = normalizeTextCellLocal(values, var_name)
    if isstring(values)
        values = cellstr(values);
    elseif ischar(values)
        values = {values};
    elseif iscell(values)
        for i = 1:numel(values)
            requireNonemptyTextLocal(values{i}, ...
                sprintf('%s{%d}', var_name, i));
            values{i} = char(values{i});
        end
    else
        error('%s must be text or a cell array of text.', var_name);
    end

    values = reshape(values, 1, []);
end

function group_names = normalizeGroupNamesLocal(group_names)
    if isstring(group_names)
        group_names = cellstr(group_names(:)');
    elseif ischar(group_names)
        if size(group_names, 1) == 1
            group_names = {group_names};
        else
            group_names = reshape(cellstr(group_names), 1, []);
        end
    elseif iscell(group_names)
        group_names = reshape(group_names, 1, []);
    else
        error('group_names must be text or a cell array of text.');
    end

    if isempty(group_names)
        error('group_names cannot be empty.');
    end

    for g = 1:numel(group_names)
        value = group_names{g};

        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            error('group_names{%d} must contain text.', g);
        end

        value = strtrim(char(string(value)));

        if isempty(value)
            error('group_names{%d} cannot be empty.', g);
        end

        group_names{g} = value;
    end
end

function [group_display_names, group_file_tags] = ...
        buildGroupLabelsLocal(group_names)
    num_groups = numel(group_names);
    group_display_names = cell(1, num_groups);
    group_file_tags = cell(1, num_groups);

    for g = 1:num_groups
        group_display_names{g} = sprintf( ...
            'Group %d: %s', g, group_names{g});
        group_file_tags{g} = sprintf( ...
            'G%02d_%s', g, makeSafeGroupNameTagLocal(group_names{g}));
    end
end

function tag = makeSafeGroupNameTagLocal(group_name)
    tag = strtrim(char(string(group_name)));
    tag = regexprep(tag, '[^A-Za-z0-9_-]+', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');

    if isempty(tag)
        tag = 'area';
    end
end

function assertStringOptionLocal(value, valid_options, var_name)
    if ~ischar(value) && ~(isstring(value) && isscalar(value))
        error('%s must be a char or scalar string.', var_name);
    end

    value = char(value);

    if ~any(strcmp(value, valid_options))
        error('%s = ''%s'' is invalid. Valid options are: %s', ...
            var_name, value, strjoin(valid_options, ', '));
    end
end

function tag = makeModelTagLocal(model_mode)
    switch char(model_mode)
        case 'all_condition'
            tag = 'all_condition_M';

        case 'each_condition'
            tag = 'condition_specific_M';

        otherwise
            error('Unknown model_mode: %s', model_mode);
    end
end

function session_dirs = findCatgtSessionDirsLocal(root_dir)
    listing = dir(fullfile(root_dir, '*', 'catgt_*'));
    listing = listing([listing.isdir]);

    if isempty(listing)
        session_dirs = {};
        return;
    end

    n = numel(listing);
    session_dirs = cell(n, 1);
    session_numbers = nan(n, 1);
    parent_names = cell(n, 1);
    catgt_names = cell(n, 1);

    for k = 1:n
        session_dirs{k} = fullfile(listing(k).folder, listing(k).name);
        catgt_names{k} = listing(k).name;

        [parent_dir, ~] = fileparts(session_dirs{k});
        [~, parent_names{k}] = fileparts(parent_dir);
        session_numbers(k) = ...
            extractSessionNumberFromNameLocal(parent_names{k});
    end

    T = table(session_numbers, parent_names, catgt_names, session_dirs, ...
        'VariableNames', { ...
        'session_number', 'session_name', 'catgt_name', 'session_dir'});

    T = sortrows(T, { ...
        'session_number', 'session_name', 'catgt_name'});

    session_dirs = T.session_dir(:)';
end

function session_number = extractSessionNumberFromNameLocal(session_name)
    tokens = regexp(session_name, 'p(\d+)', 'tokens', 'once');

    if isempty(tokens)
        session_number = inf;
        return;
    end

    session_number = str2double(tokens{1});

    if ~isfinite(session_number)
        session_number = inf;
    end
end

function [rec, reference] = readOneSessionLocal( ...
    session_dir, data_content, model_mode, var_split_mode, ...
    split_file_tag, runIdx, ...
    variance_category_tag, group_names, group_display_names, ...
    group_file_tags, gpl_mat_name, var_field_names, ...
    source_field_names, delta_names, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, feature_delta_plot_mode, feature_delta_definitions, reference, neuron_population, variance_config)

    [parent_dir, catgt_name] = fileparts(session_dir);
    [~, session_parent_name] = fileparts(parent_dir);

    prefix = 'catgt_';

    if ~startsWith(catgt_name, prefix) || ...
            numel(catgt_name) <= numel(prefix)
        error('Unrecognized CatGT folder name: %s', catgt_name);
    end

    run_g = catgt_name(numel(prefix) + 1:end);
    run_tokens = regexp(run_g, '^(.+)_g(\d+)$', 'tokens', 'once');

    if isempty(run_tokens)
        error(['CatGT folder name must end in _g<number>: %s'], ...
            catgt_name);
    end

    run_name = run_tokens{1};
    run_ind = str2double(run_tokens{2});

    R = loadNeuronVarianceLocal(session_dir,variance_config);
    var_file = R.source_file;
    num_groups = numel(group_names);

    reference = validateOrInitializeReferenceLocal( ...
        reference, R, group_names, group_display_names, ...
        group_file_tags, var_field_names, source_field_names, delta_names, ...
        var_split_mode, stim_types, category_labels, session_dir);

    empty_group = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'unit_ids', [], ...
        'gpl_file', '', ...
        'class_info', struct(), ...
        'zscore', struct(), ...
        'var_zscore', struct(), ...
        'feature_delta', struct(), ...
        'feature_delta_zscore', struct(), ...
        'stim', struct());

    groups = repmat(empty_group, 1, num_groups);

    fprintf('  Var file: %s\n', var_file);

    [gpl_group_by_index, gpl_file_by_index] = ...
        loadGplGroupsByModelIndexLocal( ...
        session_dir, gpl_mat_name, num_groups);

    source_var_indices = nan(1, numel(source_field_names));

    for f = 1:numel(source_field_names)
        source_var_indices(f) = find(strcmp( ...
            var_field_names, source_field_names{f}), 1, 'first');
    end

    delta_positive_indices = nan(1, numel(delta_names));
    delta_negative_indices = nan(1, numel(delta_names));

    for d = 1:numel(delta_names)
        delta_positive_indices(d) = find(strcmp( ...
            source_field_names, delta_positive_fields{d}), ...
            1, 'first');
        delta_negative_indices(d) = find(strcmp( ...
            source_field_names, delta_negative_fields{d}), ...
            1, 'first');
    end

    for g = 1:num_groups
        model_ids = double(R.unit_ids_by_group{g}(:));
        gpl_results = gpl_group_by_index{g};
        gpl_file = gpl_file_by_index{g};

        class_info = validateAndExtractClassesLocal( ...
            gpl_results, model_ids, ...
            group_display_names{g}, gpl_file);

        groups(g).group_index = g;
        groups(g).group_name = group_names{g};
        groups(g).group_display_name = group_display_names{g};
        groups(g).group_file_tag = group_file_tags{g};
        groups(g).unit_ids = model_ids;
        groups(g).gpl_file = gpl_file;
        groups(g).class_info = class_info;

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            raw_var_matrix = nan( ...
                numel(model_ids), numel(var_field_names));

            for f = 1:numel(var_field_names)
                raw_var_matrix(:, f) = getGroupVarVectorLocal( ...
                    R.(stim_name), var_field_names{f}, g);
            end

            source_var_matrix = raw_var_matrix(:, source_var_indices);

            raw_delta_matrix = nan( ...
                numel(model_ids), numel(delta_names));

            for d = 1:numel(delta_names)
                raw_delta_matrix(:, d) = ...
                    source_var_matrix(:, delta_positive_indices(d)) - ...
                    source_var_matrix(:, delta_negative_indices(d));
            end

            groups(g).stim.(stim_name).raw_var_matrix = ...
                raw_var_matrix;
            groups(g).stim.(stim_name).z_var_matrix = ...
                nan(size(raw_var_matrix));
            groups(g).stim.(stim_name).source_var_matrix = ...
                source_var_matrix;
            groups(g).stim.(stim_name).z_source_var_matrix = ...
                nan(size(source_var_matrix));
            groups(g).stim.(stim_name).raw_delta_matrix = ...
                raw_delta_matrix;
            groups(g).stim.(stim_name).z_delta_matrix = ...
                nan(size(raw_delta_matrix));
            groups(g).stim.(stim_name).raw_delta = struct();
            groups(g).stim.(stim_name).z_delta = struct();

            for d = 1:numel(delta_names)
                groups(g).stim.(stim_name).raw_delta.( ...
                    delta_names{d}) = raw_delta_matrix(:, d);
                groups(g).stim.(stim_name).z_delta.( ...
                    delta_names{d}) = nan(numel(model_ids), 1);
            end
        end

        % One session-area baseline, computed BEFORE averaging directions.
        normalization_mask = true(numel(model_ids),1);
        if strcmp(neuron_population,'pcu_neurons')
            normalization_mask = class_info.pattern | ...
                class_info.component | class_info.unclassified;
        end
        X = R.direction_variance{g};
        selected = X(normalization_mask,:,:,:);
        num_possible = numel(selected);
        var_zscore_pool = selected(isfinite(selected));
        pool_mean = NaN; pool_sd = NaN;
        if ~isempty(var_zscore_pool), pool_mean=mean(var_zscore_pool); end
        if numel(var_zscore_pool)>=2, pool_sd=std(var_zscore_pool,0); end
        valid_z = isfinite(pool_mean) && isfinite(pool_sd) && pool_sd>0;
        Z = nan(size(X));
        if valid_z
            Z = (X-pool_mean)./pool_sd;
        else
            warning('%s: undefined variance Z baseline; raw values retained, Z values are NaN.', ...
                group_display_names{g});
        end
        % Preserve full direction data, then average directions equally.
        groups(g).direction_var = X;
        groups(g).direction_zvar = Z;
        groups(g).direction_reconstruction_var = [];
        groups(g).direction_uncertainty_var = [];
        if isfield(R,'reconstruction_by_direction')
            groups(g).direction_reconstruction_var = R.reconstruction_by_direction{g};
            groups(g).direction_uncertainty_var = R.uncertainty_by_direction{g};
        end
        Zmean = reshape(mean(Z,3),numel(model_ids),8,numel(var_field_names));
        for st=1:numel(stim_types)
            stim_name=stim_types{st};
            z_var_matrix=reshape(Zmean(:,st,:),numel(model_ids),numel(var_field_names));
            z_source_var_matrix=z_var_matrix(:,source_var_indices);
            z_delta_matrix=nan(numel(model_ids),numel(delta_names));
            for d=1:numel(delta_names)
                z_delta_matrix(:,d)=z_source_var_matrix(:,delta_positive_indices(d))- ...
                    z_source_var_matrix(:,delta_negative_indices(d));
                groups(g).stim.(stim_name).z_delta.(delta_names{d})=z_delta_matrix(:,d);
            end
            groups(g).stim.(stim_name).z_var_matrix=z_var_matrix;
            groups(g).stim.(stim_name).z_source_var_matrix=z_source_var_matrix;
            groups(g).stim.(stim_name).z_delta_matrix=z_delta_matrix;
        end
        normalization=struct();
        normalization.neuron_population=neuron_population;
        normalization.pool_mean=pool_mean; normalization.pool_sd=pool_sd;
        normalization.std_normalization=0;
        normalization.n_finite=numel(var_zscore_pool);
        normalization.n_possible=num_possible;
        normalization.n_nonfinite=num_possible-numel(var_zscore_pool);
        normalization.n_reference_neurons=nnz(normalization_mask);
        normalization.reference_unit_ids=model_ids(normalization_mask);
        normalization.valid=valid_z;
        normalization.pooling_scope=['Selected neurons, all 16 direction/condition ', ...
            'combinations and Across/Within/FF/FB/Ambiguous within one session-area'];
        normalization.operation_order=['Z-score before equal direction mean, ', ...
            'then matched differences, then any within-neuron condition mean'];

        groups(g).zscore = normalization;
        groups(g).var_zscore = normalization;

        if ~strcmp(feature_delta_plot_mode,'off')
            groups(g).feature_delta = computeFeatureDeltasForGroupLocal( ...
                groups(g).stim,numel(source_field_names),feature_delta_definitions, ...
                group_display_names{g});
            groups(g).feature_delta_zscore = normalization;
        end

        fprintf(['  %s: pattern=%d, component=%d, ', ...
            'unclassified=%d, invalid=%d, ', ...
            'Var z-mean=%.6g, Var z-SD=%.6g, z-N=%d/%d\n'], ...
            group_display_names{g}, ...
            sum(class_info.pattern), ...
            sum(class_info.component), ...
            sum(class_info.unclassified), ...
            sum(class_info.invalid), ...
            pool_mean, pool_sd, ...
            numel(var_zscore_pool), num_possible);
    end

    rec = struct();
    rec.session_index = [];
    rec.session_label = '';
    rec.session_name = sprintf('%s/%s', ...
        session_parent_name, catgt_name);
    rec.session_parent_name = session_parent_name;
    rec.session_number = ...
        extractSessionNumberFromNameLocal(session_parent_name);
    rec.session_dir = session_dir;
    rec.catgt_name = catgt_name;
    rec.run_name = run_name;
    rec.run_ind = run_ind;
    rec.run_g = run_g;
    rec.var_file = var_file;
    rec.group = groups;
    rec.variance_settings = variance_config;
    rec.variance_source = R.variance_source;
    rec.model_mode = R.model_mode;
    rec.uncertainty_included = R.uncertainty_included;
    rec.condition_ids = R.condition_ids;
    rec.direction_values = R.direction_values;
    rec.bestmodel_files = R.bestmodel_files;
    rec.DSL_threshold = R.DSL_threshold;
    rec.direction_dimension_names = {'neuron','feature_combination','direction','latent_category'};
end

function feature_delta = computeFeatureDeltasForGroupLocal( ...
        stim_data, num_source_fields, definitions, group_display_name)

    feature_delta = struct();

    for e = 1:numel(definitions)
        D = definitions(e);
        num_matches = numel(D.fixed_labels);
        raw_delta_array = [];
        z_delta_array = [];

        for k = 1:num_matches
            positive_raw = ...
                stim_data.(D.positive_stim{k}).source_var_matrix;
            negative_raw = ...
                stim_data.(D.negative_stim{k}).source_var_matrix;
            positive_z = ...
                stim_data.(D.positive_stim{k}).z_source_var_matrix;
            negative_z = ...
                stim_data.(D.negative_stim{k}).z_source_var_matrix;

            if k == 1
                num_neurons = size(positive_raw, 1);
                raw_delta_array = nan( ...
                    num_neurons, num_source_fields, num_matches);
                z_delta_array = nan( ...
                    num_neurons, num_source_fields, num_matches);
            end

            if ~isnumeric(positive_raw) || ...
                    ~isnumeric(negative_raw) || ...
                    ~isnumeric(positive_z) || ...
                    ~isnumeric(negative_z) || ...
                    ~isequal(size(positive_raw), ...
                    [num_neurons, num_source_fields]) || ...
                    ~isequal(size(negative_raw), ...
                    [num_neurons, num_source_fields]) || ...
                    ~isequal(size(positive_z), ...
                    [num_neurons, num_source_fields]) || ...
                    ~isequal(size(negative_z), ...
                    [num_neurons, num_source_fields])
                error(['%s has incompatible source Var matrices for ', ...
                    'feature delta %s, match %d.'], ...
                    group_display_name, D.name, k);
            end

            raw_delta_array(:, :, k) = ...
                positive_raw - negative_raw;
            z_delta_array(:, :, k) = positive_z - negative_z;
        end

        E = struct();
        E.name = D.name;
        E.file_tag = D.file_tag;
        E.title = D.title;
        E.subscript = D.subscript;
        E.fixed_labels = reshape(D.fixed_labels, 1, []);
        E.positive_stim = reshape(D.positive_stim, 1, []);
        E.negative_stim = reshape(D.negative_stim, 1, []);
        E.raw_delta_array = raw_delta_array;
        E.z_delta_array = z_delta_array;
        E.zscore_order = 'Var first, matched stimulus subtraction second';

        feature_delta.(D.name) = E;
    end
end





function reference = validateOrInitializeReferenceLocal( ...
    reference, R, group_names, group_display_names, group_file_tags, ...
    var_field_names, source_field_names, delta_names, var_split_mode, ...
    stim_types, category_labels, session_dir)

    if isempty(fieldnames(reference))
        reference.num_groups = numel(R.yDims);
        reference.group_names = reshape(group_names, 1, []);
        reference.group_display_names = ...
            reshape(group_display_names, 1, []);
        reference.group_file_tags = reshape(group_file_tags, 1, []);
        reference.var_field_names = ...
            reshape(var_field_names, 1, []);
        reference.source_field_names = ...
            reshape(source_field_names, 1, []);
        reference.delta_names = reshape(delta_names, 1, []);
        reference.var_split_mode = var_split_mode;
        reference.stim_types = reshape(stim_types, 1, []);
        reference.category_labels = reshape(category_labels, 1, []);
        return;
    end

    if numel(R.yDims) ~= reference.num_groups
        error('%s: number of groups differs across sessions.', ...
            session_dir);
    end

    if ~isequal(reshape(group_names, 1, []), ...
            reference.group_names) || ...
            ~isequal(reshape(group_display_names, 1, []), ...
            reference.group_display_names) || ...
            ~isequal(reshape(group_file_tags, 1, []), ...
            reference.group_file_tags) || ...
            ~isequal(reshape(var_field_names, 1, []), ...
            reference.var_field_names) || ...
            ~isequal(reshape(source_field_names, 1, []), ...
            reference.source_field_names) || ...
            ~isequal(reshape(delta_names, 1, []), ...
            reference.delta_names) || ...
            ~strcmp(var_split_mode, reference.var_split_mode) || ...
            ~isequal(reshape(stim_types, 1, []), ...
            reference.stim_types) || ...
            ~isequal(reshape(category_labels, 1, []), ...
            reference.category_labels)
        error('%s: plotting labels or field order differ across sessions.', ...
            session_dir);
    end
end

function vec = getGroupVarVectorLocal(stim_result, field_name, group_idx)
    by_group = stim_result.(field_name).neuron_by_group;
    vec = double(by_group{group_idx}(:));
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

function M = buildMultiSessionDeltaSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, ...
    var_split_mode, split_file_tag, runIdx, ...
    variance_category_tag, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, class_short_names, ...
    var_field_names, var_field_labels, ...
    source_field_names, source_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, category_labels, ...
    output_prefix, output_base, condition_display_mode, ...
    condition_colors, pooled_condition_color, plot_value_modes, ...
    violin_summary_type, condition_step, between_delta_gap, ...
    between_class_gap, feature_delta_plot_mode, ...
    feature_delta_color, feature_delta_definitions, ...
    plot_cross_session_condition_var, ...
    var_condition_comparison_enabled, var_condition_compare_config)

    num_sessions = numel(records);
    num_groups = numel(group_names);

    session_info = struct( ...
        'session_index', {}, ...
        'session_label', {}, ...
        'session_name', {}, ...
        'session_parent_name', {}, ...
        'session_number', {}, ...
        'session_dir', {}, ...
        'catgt_name', {}, ...
        'run_name', {}, ...
        'run_ind', {}, ...
        'run_g', {}, ...
        'var_file', {}, ...
        'gpl_file_by_group', {});

    for s = 1:num_sessions
        session_info(s).session_index = s;
        session_info(s).session_label = records{s}.session_label;
        session_info(s).session_name = records{s}.session_name;
        session_info(s).session_parent_name = ...
            records{s}.session_parent_name;
        session_info(s).session_number = records{s}.session_number;
        session_info(s).session_dir = records{s}.session_dir;
        session_info(s).catgt_name = records{s}.catgt_name;
        session_info(s).run_name = records{s}.run_name;
        session_info(s).run_ind = records{s}.run_ind;
        session_info(s).run_g = records{s}.run_g;
        session_info(s).var_file = records{s}.var_file;
        session_info(s).gpl_file_by_group = ...
            {records{s}.group.gpl_file};
    end

    zscore_template = struct( ...
        'session_index', [], ...
        'session_label', '', ...
        'session_name', '', ...
        'group_index', [], ...
        'group_name', '', ...
        'group_file_tag', '', ...
        'pool_mean', NaN, ...
        'pool_sd', NaN, ...
        'std_normalization', 0, ...
        'n_finite', 0, ...
        'n_possible', 0, ...
        'n_nonfinite', 0, ...
        'pooling_scope', '', ...
        'operation_order', '');

    zscore_by_session_area = repmat( ...
        zscore_template, num_sessions, num_groups);

    for s = 1:num_sessions
        for g = 1:num_groups
            Z = records{s}.group(g).zscore;
            zscore_by_session_area(s, g).session_index = s;
            zscore_by_session_area(s, g).session_label = ...
                records{s}.session_label;
            zscore_by_session_area(s, g).session_name = ...
                records{s}.session_name;
            zscore_by_session_area(s, g).group_index = g;
            zscore_by_session_area(s, g).group_name = group_names{g};
            zscore_by_session_area(s, g).group_file_tag = ...
                group_file_tags{g};
            zscore_by_session_area(s, g).pool_mean = Z.pool_mean;
            zscore_by_session_area(s, g).pool_sd = Z.pool_sd;
            zscore_by_session_area(s, g).std_normalization = ...
                Z.std_normalization;
            zscore_by_session_area(s, g).n_finite = Z.n_finite;
            zscore_by_session_area(s, g).n_possible = Z.n_possible;
            zscore_by_session_area(s, g).n_nonfinite = Z.n_nonfinite;
            zscore_by_session_area(s, g).pooling_scope = ...
                Z.pooling_scope;
            zscore_by_session_area(s, g).operation_order = ...
                Z.operation_order;
        end
    end

    feature_zscore_by_session_area = struct([]);

    if ~strcmp(feature_delta_plot_mode, 'off')
        feature_zscore_by_session_area = repmat( ...
            zscore_template, num_sessions, num_groups);

        for s = 1:num_sessions
            for g = 1:num_groups
                Z = records{s}.group(g).feature_delta_zscore;
                feature_zscore_by_session_area(s, g).session_index = s;
                feature_zscore_by_session_area(s, g).session_label = ...
                    records{s}.session_label;
                feature_zscore_by_session_area(s, g).session_name = ...
                    records{s}.session_name;
                feature_zscore_by_session_area(s, g).group_index = g;
                feature_zscore_by_session_area(s, g).group_name = ...
                    group_names{g};
                feature_zscore_by_session_area(s, g).group_file_tag = ...
                    group_file_tags{g};
                feature_zscore_by_session_area(s, g).pool_mean = ...
                    Z.pool_mean;
                feature_zscore_by_session_area(s, g).pool_sd = ...
                    Z.pool_sd;
                feature_zscore_by_session_area(s, g).std_normalization = ...
                    Z.std_normalization;
                feature_zscore_by_session_area(s, g).n_finite = ...
                    Z.n_finite;
                feature_zscore_by_session_area(s, g).n_possible = ...
                    Z.n_possible;
                feature_zscore_by_session_area(s, g).n_nonfinite = ...
                    Z.n_nonfinite;
                feature_zscore_by_session_area(s, g).pooling_scope = ...
                    Z.pooling_scope;
                feature_zscore_by_session_area(s, g).operation_order = ...
                    Z.operation_order;
            end
        end
    end

    pooled_template = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'stim', struct());

    pooled = repmat(pooled_template, 1, num_groups);

    for g = 1:num_groups
        pooled(g).group_index = g;
        pooled(g).group_name = group_names{g};
        pooled(g).group_display_name = group_display_names{g};
        pooled(g).group_file_tag = group_file_tags{g};

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            pooled(g).stim.(stim_name) = struct();
            pooled(g).stim.(stim_name).class = struct();

            for c = 1:numel(class_names)
                class_name = class_names{c};
                raw_var_matrix = zeros(0, numel(var_field_names));
                z_var_matrix = zeros(0, numel(var_field_names));
                raw_delta_matrix = zeros(0, numel(delta_names));
                z_delta_matrix = zeros(0, numel(delta_names));
                unit_ids = [];
                session_index = [];
                session_label = {};
                session_name = {};

                for s = 1:num_sessions
                    G = records{s}.group(g);
                    class_mask = G.class_info.(class_name);
                    n_this = sum(class_mask);

                    if n_this == 0
                        continue;
                    end

                    raw_var_matrix = [ ...
                        raw_var_matrix; ...
                        G.stim.(stim_name).raw_var_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    z_var_matrix = [ ...
                        z_var_matrix; ...
                        G.stim.(stim_name).z_var_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    raw_delta_matrix = [ ...
                        raw_delta_matrix; ...
                        G.stim.(stim_name).raw_delta_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    z_delta_matrix = [ ...
                        z_delta_matrix; ...
                        G.stim.(stim_name).z_delta_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    unit_ids = [unit_ids; G.unit_ids(class_mask)]; %#ok<AGROW>
                    session_index = [ ...
                        session_index; repmat(s, n_this, 1)]; %#ok<AGROW>
                    session_label = [ ...
                        session_label; ...
                        repmat({records{s}.session_label}, n_this, 1)]; %#ok<AGROW>
                    session_name = [ ...
                        session_name; ...
                        repmat({records{s}.session_name}, n_this, 1)]; %#ok<AGROW>
                end

                C = struct();
                C.class_name = class_name;
                C.class_label = class_labels{c};
                C.class_marker = class_markers{c};
                C.class_short_name = class_short_names{c};
                C.raw_var_matrix = raw_var_matrix;
                C.z_var_matrix = z_var_matrix;
                C.raw_delta_matrix = raw_delta_matrix;
                C.z_delta_matrix = z_delta_matrix;
                C.raw_delta = struct();
                C.z_delta = struct();

                for d = 1:numel(delta_names)
                    C.raw_delta.(delta_names{d}) = ...
                        raw_delta_matrix(:, d);
                    C.z_delta.(delta_names{d}) = ...
                        z_delta_matrix(:, d);
                end

                C.unit_ids = unit_ids;
                C.session_index = session_index;
                C.session_label = session_label;
                C.session_name = session_name;
                C.n_neurons = size(raw_delta_matrix, 1);
                C.finite_count_raw_by_var_field = ...
                    sum(isfinite(raw_var_matrix), 1);
                C.finite_count_z_by_var_field = ...
                    sum(isfinite(z_var_matrix), 1);
                C.finite_count_raw_by_delta = ...
                    sum(isfinite(raw_delta_matrix), 1);
                C.finite_count_z_by_delta = ...
                    sum(isfinite(z_delta_matrix), 1);

                pooled(g).stim.(stim_name).class.(class_name) = C;
            end
        end
    end

    feature_delta_pooled = struct([]);

    if ~strcmp(feature_delta_plot_mode, 'off')
        feature_pooled_template = struct( ...
            'group_index', [], ...
            'group_name', '', ...
            'group_display_name', '', ...
            'group_file_tag', '', ...
            'effect', struct());

        feature_delta_pooled = repmat( ...
            feature_pooled_template, 1, num_groups);

        for g = 1:num_groups
            feature_delta_pooled(g).group_index = g;
            feature_delta_pooled(g).group_name = group_names{g};
            feature_delta_pooled(g).group_display_name = ...
                group_display_names{g};
            feature_delta_pooled(g).group_file_tag = ...
                group_file_tags{g};

            for e = 1:numel(feature_delta_definitions)
                D = feature_delta_definitions(e);
                num_matches = numel(D.fixed_labels);
                E = struct();
                E.name = D.name;
                E.file_tag = D.file_tag;
                E.title = D.title;
                E.subscript = D.subscript;
                E.fixed_labels = reshape(D.fixed_labels, 1, []);
                E.positive_stim = reshape(D.positive_stim, 1, []);
                E.negative_stim = reshape(D.negative_stim, 1, []);
                E.class = struct();

                for c = 1:numel(class_names)
                    class_name = class_names{c};
                    raw_delta_array = zeros( ...
                        0, numel(source_field_names), num_matches);
                    z_delta_array = zeros( ...
                        0, numel(source_field_names), num_matches);
                    unit_ids = [];
                    session_index = [];
                    session_label = {};
                    session_name = {};

                    for s = 1:num_sessions
                        G = records{s}.group(g);
                        class_mask = G.class_info.(class_name);
                        n_this = sum(class_mask);

                        if n_this == 0
                            continue;
                        end

                        session_effect = G.feature_delta.(D.name);
                        raw_delta_array = cat(1, raw_delta_array, ...
                            session_effect.raw_delta_array( ...
                            class_mask, :, :));
                        z_delta_array = cat(1, z_delta_array, ...
                            session_effect.z_delta_array( ...
                            class_mask, :, :));

                        unit_ids = [ ...
                            unit_ids; G.unit_ids(class_mask)]; %#ok<AGROW>
                        session_index = [ ...
                            session_index; repmat(s, n_this, 1)]; %#ok<AGROW>
                        session_label = [ ...
                            session_label; ...
                            repmat({records{s}.session_label}, ...
                            n_this, 1)]; %#ok<AGROW>
                        session_name = [ ...
                            session_name; ...
                            repmat({records{s}.session_name}, ...
                            n_this, 1)]; %#ok<AGROW>
                    end

                    C = struct();
                    C.class_name = class_name;
                    C.class_label = class_labels{c};
                    C.class_marker = class_markers{c};
                    C.raw_delta_array = raw_delta_array;
                    C.z_delta_array = z_delta_array;
                    C.unit_ids = unit_ids;
                    C.session_index = session_index;
                    C.session_label = session_label;
                    C.session_name = session_name;
                    C.n_neurons = size(raw_delta_array, 1);
                    C.finite_count_raw_by_source_match = reshape( ...
                        sum(isfinite(raw_delta_array), 1), ...
                        numel(source_field_names), num_matches);
                    C.finite_count_z_by_source_match = reshape( ...
                        sum(isfinite(z_delta_array), 1), ...
                        numel(source_field_names), num_matches);

                    E.class.(class_name) = C;
                end

                feature_delta_pooled(g).effect.(D.name) = E;
            end
        end
    end

    M = struct();

    M.meta.format_version = 'GPL_class_deltaVar_by_area_v5';
    M.meta.root_dir = root_dir;
    M.meta.data_content = data_content;
    M.meta.model_mode = model_mode;
    M.meta.var_split_mode = var_split_mode;
    M.meta.split_file_tag = split_file_tag;
    M.meta.condition_display_mode = condition_display_mode;
    M.meta.feature_delta_plot_mode = feature_delta_plot_mode;
    M.meta.feature_delta_enabled = ...
        ~strcmp(feature_delta_plot_mode, 'off');
    M.meta.plot_cross_session_condition_var = ...
        logical(plot_cross_session_condition_var);
    M.meta.var_condition_comparison_enabled = ...
        logical(var_condition_comparison_enabled);
    M.meta.var_condition_plot_style = ...
        var_condition_compare_config.plot_style;
    M.meta.zscore_operation_order = 'Var first, differences second';
    M.meta.runIdx = runIdx;
    M.meta.variance_category_tag = variance_category_tag;
    M.meta.gpl_mat_name = gpl_mat_name;
    M.meta.output_prefix = output_prefix;
    M.meta.output_base = output_base;
    M.meta.mapping_file_tag = mapping_file_tag;
    M.meta.num_sessions = num_sessions;
    M.meta.num_groups = num_groups;
    M.meta.num_stim_types = numel(stim_types);
    M.meta.num_categories = numel(stim_types);
    M.meta.num_delta_types = numel(delta_names);
    M.meta.num_var_fields = numel(var_field_names);
    M.meta.num_feature_delta_types = ...
        numel(feature_delta_definitions);

    M.settings.condition_colors = condition_colors;
    M.settings.pooled_condition_color = pooled_condition_color;
    M.settings.feature_delta_color = feature_delta_color;
    M.settings.plot_value_modes = reshape(plot_value_modes, 1, []);
    M.settings.violin_summary_type = violin_summary_type;
    M.settings.zscore_std_normalization = 0;
    M.settings.var_condition_compare_config = ...
        var_condition_compare_config;
    M.settings.condition_step = condition_step;
    M.settings.between_delta_gap = between_delta_gap;
    M.settings.between_class_gap = between_class_gap;

    M.labels.group = reshape(group_display_names, 1, []);
    M.labels.group_name = reshape(group_names, 1, []);
    M.labels.group_display_name = reshape(group_display_names, 1, []);
    M.labels.group_file_tag = reshape(group_file_tags, 1, []);
    M.labels.session = {session_info.session_label};
    M.labels.class_name = reshape(class_names, 1, []);
    M.labels.class = reshape(class_labels, 1, []);
    M.labels.class_marker = reshape(class_markers, 1, []);
    M.labels.class_short_name = reshape(class_short_names, 1, []);
    M.labels.var_field_name = reshape(var_field_names, 1, []);
    M.labels.var_field = reshape(var_field_labels, 1, []);
    M.labels.source_var_field_name = ...
        reshape(source_field_names, 1, []);
    M.labels.source_var_field = ...
        reshape(source_field_labels, 1, []);
    M.labels.feature_source = ...
        reshape(feature_source_labels, 1, []);
    M.labels.delta_name = reshape(delta_names, 1, []);
    M.labels.delta = reshape(delta_labels, 1, []);
    M.labels.delta_positive_field = ...
        reshape(delta_positive_fields, 1, []);
    M.labels.delta_negative_field = ...
        reshape(delta_negative_fields, 1, []);
    M.labels.stimulus = reshape(stim_types, 1, []);
    M.labels.category_field = reshape(stim_types, 1, []);
    M.labels.category = reshape(category_labels, 1, []);
    M.labels.feature_delta_name = ...
        reshape({feature_delta_definitions.name}, 1, []);
    M.labels.feature_delta_file_tag = ...
        reshape({feature_delta_definitions.file_tag}, 1, []);
    M.labels.feature_delta_title = ...
        reshape({feature_delta_definitions.title}, 1, []);
    M.labels.feature_delta_subscript = ...
        reshape({feature_delta_definitions.subscript}, 1, []);

    M.sessions.included = session_info;
    M.sessions.skipped = skipped;

    M.session_data = [records{:}];
    M.zscore_by_session_area = zscore_by_session_area;
    M.var_zscore_by_session_area = zscore_by_session_area;
    M.pooled = pooled;
    M.feature_delta_definitions = feature_delta_definitions;
    M.feature_delta_zscore_by_session_area = ...
        feature_zscore_by_session_area;
    M.feature_delta_pooled = feature_delta_pooled;

    M.dimension_names.source_var_matrix = { ...
        'neuron', 'source_var_field'};
    M.dimension_names.raw_var_matrix = {'neuron', 'var_field'};
    M.dimension_names.z_var_matrix = {'neuron', 'var_field'};
    M.dimension_names.raw_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.z_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.feature_raw_delta_array = { ...
        'neuron', 'source_var_field', 'fixed_dimension_match'};
    M.dimension_names.feature_z_delta_array = { ...
        'neuron', 'source_var_field', 'fixed_dimension_match'};

    M.notes.delta_definition = [ ...
        'acr_vs_wit = use_across Var - use_within Var; ', ...
        'ff_vs_fb = use_feedforward Var - use_feedback Var'];
    M.notes.zscore_definition = ['Selected neuron population x all 16 direction/condition ', ...
        'combinations x five variance categories within each session-area. ', ...
        'Compute the common mean/sample SD before equal direction averaging ', ...
        'and before all matched differences. See settings and session_data.'];
    M.notes.zscore_zero_interpretation = [ ...
        'Because both terms in every difference use the same session-area ', ...
        'Var mean and SD, their shared mean cancels. A zero difference of ', ...
        'z-scored Var therefore means the two original Var values are equal. ', ...
        'For an undifferenced z-scored Var value, zero instead denotes the ', ...
        'pooled raw-Var mean of that session-area.'];
    M.notes.invalid_neurons = ['Invalid neurons remain in alignment and session_data. ', ...
        'Class plots use P/C/U; Z reference selection is stored in settings.'];
    M.notes.classification_source = [ ...
        'Spontaneous-subtracted GPL plaid classification selected from ', ...
        'nested GPL group entries by model_group_index.'];
    M.notes.session_plot_encoding = [ ...
        'Session identity is retained in the MAT but is not encoded by ', ...
        'color, shade, legend, or connecting lines in the figures.'];
    M.notes.condition_plotting = [ ...
        'In separate mode, conditions are separate distributions and ', ...
        'color encodes condition in the stored category order. In pooled ', ...
        'mode, condition vectors are concatenated without first averaging ', ...
        'within neuron, and no condition identity is encoded in the plot.'];
    M.notes.value_figures = 'Raw figures are always drawn; plot_zscore controls additional Z figures.';
    M.notes.feature_delta_definition = [ ...
        'For each reconstruction source separately: GP = Grating minus ', ...
        'Plaid, SL = Small minus Large, and LH = Low minus High, while ', ...
        'holding the other two stimulus dimensions fixed.'];
    M.notes.feature_delta_zscore_definition = [ ...
        'The optional stimulus-feature delta figures use the same common ', ...
        'Var mean and sample SD as every other z-scored result in that ', ...
        'session-area. Var is standardized first and the matched GP, SL, ', ...
        'or LH subtraction is performed second.'];
    M.notes.feature_delta_plotting = [ ...
        'In separate mode, the four matched fixed-dimension combinations ', ...
        'remain separate. In pooled mode they are concatenated without ', ...
        'first averaging within neuron. All feature-delta distributions ', ...
        'use one neutral color.'];
    M.notes.var_condition_comparison = ['When enabled, undifferenced neuron variance ', ...
        'compares eight direction-averaged conditions for Across/Within/FF/FB/Ambiguous, ', ...
        'separately by area and GPL class, with optional Z figures.'];
end

function fig = plotCrossSessionConditionVarLocal( ...
    pooled_group, stim_types, condition_labels, ...
    var_field_names, var_field_labels, ...
    class_name, class_label, class_idx, value_mode, ...
    group_display_name, data_content, model_mode, ...
    condition_colors, figure_visible, config)

    num_conditions = numel(stim_types);
    num_reconstructions = numel(var_field_names);

    [matrix_field, y_label, value_title, default_y_limits] = ...
        getUndifferencedVarValueModeConfigLocal(value_mode);

    values = cell(num_reconstructions, num_conditions);
    all_values = [];

    for p = 1:num_conditions
        stim_name = stim_types{p};

        if ~isfield(pooled_group.stim, stim_name) || ...
                ~isfield(pooled_group.stim.(stim_name), 'class') || ...
                ~isfield(pooled_group.stim.(stim_name).class, class_name)
            error('Missing pooled Var data for %s / %s.', ...
                stim_name, class_name);
        end

        C = pooled_group.stim.(stim_name).class.(class_name);

        if ~isfield(C, matrix_field) || ...
                ~isnumeric(C.(matrix_field)) || ...
                size(C.(matrix_field), 2) ~= num_reconstructions
            error('%s / %s has an invalid %s field.', ...
                stim_name, class_name, matrix_field);
        end

        matrix_values = C.(matrix_field);

        for r = 1:num_reconstructions
            y = double(matrix_values(:, r));
            y = y(isfinite(y));
            values{r, p} = y;
            all_values = [all_values; y(:)]; %#ok<AGROW>
        end
    end

    y_limits = paddedLimitsLocal( ...
        [all_values; 0], default_y_limits);
    offsets = computeConditionOffsetsLocal(num_conditions);

    figure_name = sprintf( ...
        '%s | GPL class: %s | %s condition-comparison Var', ...
        group_display_name, class_label, value_title);

    fig = figure( ...
        'Name', figure_name, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', figure_visible, ...
        'Position', [100, 100, ...
        config.figure_width, config.figure_height], ...
        'Renderer', 'painters');

    ax = axes(fig);
    hold(ax, 'on');

    plot(ax, ...
        [0.45, num_reconstructions + 0.55], ...
        [0, 0], ...
        'k--', ...
        'LineWidth', 1, ...
        'HandleVisibility', 'off');

    for r = 1:num_reconstructions
        for p = 1:num_conditions
            x0 = r + offsets(p);
            jitter_seed = ...
                100000 * pooled_group.group_index + ...
                10000 * class_idx + ...
                100 * r + p;

            drawConditionComparisonSummaryLocal( ...
                ax, x0, values{r, p}, condition_colors(p, :), ...
                config, jitter_seed);
        end
    end

    set(ax, ...
        'XTick', 1:num_reconstructions, ...
        'XTickLabel', var_field_labels, ...
        'TickLabelInterpreter', 'none', ...
        'TickDir', 'out', ...
        'LineWidth', 1, ...
        'FontSize', 11);

    xlim(ax, [0.45, num_reconstructions + 0.55]);
    ylim(ax, y_limits);

    grid(ax, 'on');
    box(ax, 'off');

    xlabel(ax, 'Reconstruction category', 'Interpreter', 'none');
    ylabel(ax, y_label, 'Interpreter', 'tex');

    title(ax, sprintf( ...
        '%s | GPL class: %s | %d-condition raw variance comparison | %s', ...
        group_display_name, class_label, num_conditions, value_title), ...
        'Interpreter', 'none', ...
        'FontWeight', 'bold');

    if strcmp(value_mode, 'zscore')
        subtitle_text = sprintf([ ...
            '%s | %s | Z=0: session-area pooled Var mean | ', ...
            'plot style: %s'], ...
            data_content, model_mode, config.plot_style);
    else
        subtitle_text = sprintf('%s | %s | plot style: %s', ...
            data_content, model_mode, config.plot_style);
    end

    if exist('subtitle', 'file') == 2
        subtitle(ax, subtitle_text, 'Interpreter', 'none');
    end

    dummy = gobjects(1, num_conditions);

    for p = 1:num_conditions
        dummy(p) = plot(ax, nan, nan, 'o', ...
            'MarkerFaceColor', condition_colors(p, :), ...
            'MarkerEdgeColor', condition_colors(p, :), ...
            'LineStyle', 'none', ...
            'MarkerSize', 7);
    end

    lgd = legend(ax, dummy, condition_labels, ...
        'Location', 'southoutside', ...
        'Orientation', 'horizontal', ...
        'Interpreter', 'none');
    lgd.NumColumns = min(4, num_conditions);

    hold(ax, 'off');
end

function [matrix_field, y_label, value_title, default_y_limits] = ...
        getUndifferencedVarValueModeConfigLocal(value_mode)

    value_mode = lower(strtrim(char(value_mode)));

    switch value_mode
        case 'raw'
            matrix_field = 'raw_var_matrix';
            y_label = 'Neuron Var';
            value_title = 'Raw Var';
            default_y_limits = [-1, 1];

        case 'zscore'
            matrix_field = 'z_var_matrix';
            y_label = 'Z(Var)';
            value_title = 'Z-scored Var';
            default_y_limits = [-3, 3];

        otherwise
            error('Unknown value_mode: %s', value_mode);
    end
end

function offsets = computeConditionOffsetsLocal(num_conditions)

    if num_conditions == 1
        offsets = 0;
    else
        total_width = 0.72;
        offsets = linspace( ...
            -total_width / 2, total_width / 2, num_conditions);
    end
end

function drawConditionComparisonSummaryLocal( ...
    ax, x0, y, this_color, config, jitter_seed)

    y = double(y(:));
    y = y(isfinite(y));

    if isempty(y)
        return;
    end

    mean_value = mean(y);
    median_value = median(y);

    switch config.plot_style
        case 'bar_points'
            if config.show_mean
                hb = bar(ax, x0, mean_value, config.bar_width, ...
                    'FaceColor', this_color, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');

                try
                    hb.FaceAlpha = config.bar_alpha;
                catch
                end
            end

            point_edge_color = 'k';

        case 'violin'
            if numel(y) >= 2 && max(y) > min(y)
                [dens, yi] = ...
                    estimateConditionComparisonDensityLocal(y);

                if ~isempty(dens) && max(dens) > 0
                    dens = dens(:)';
                    yi = yi(:)';
                    dens = dens ./ max(dens) .* config.violin_width;

                    patch(ax, ...
                        [x0 - dens, fliplr(x0 + dens)], ...
                        [yi, fliplr(yi)], ...
                        this_color, ...
                        'FaceAlpha', config.violin_alpha, ...
                        'EdgeColor', this_color, ...
                        'LineWidth', 0.9, ...
                        'HandleVisibility', 'off');
                end
            end

            point_edge_color = 'none';

        case 'points_median'
            point_edge_color = 'none';

        otherwise
            error('Unknown plot_style: %s', config.plot_style);
    end

    jitter = deterministicJitterLocal( ...
        numel(y), config.point_jitter_width, jitter_seed);

    try
        scatter(ax, x0 + jitter, y, config.point_size, ...
            'MarkerFaceColor', this_color, ...
            'MarkerEdgeColor', point_edge_color, ...
            'MarkerFaceAlpha', config.point_alpha, ...
            'MarkerEdgeAlpha', config.point_alpha, ...
            'HandleVisibility', 'off');
    catch
        scatter(ax, x0 + jitter, y, config.point_size, ...
            'MarkerFaceColor', this_color, ...
            'MarkerEdgeColor', point_edge_color, ...
            'HandleVisibility', 'off');
    end

    if config.show_mean && ~strcmp(config.plot_style, 'bar_points')
        plot(ax, x0, mean_value, 'kd', ...
            'MarkerSize', config.mean_marker_size, ...
            'MarkerFaceColor', 'k', ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    if config.show_median
        if strcmp(config.plot_style, 'bar_points')
            plot(ax, x0, median_value, 'ks', ...
                'MarkerSize', config.median_marker_size, ...
                'MarkerFaceColor', 'k', ...
                'LineWidth', 0.8, ...
                'HandleVisibility', 'off');
        else
            median_half_width = config.violin_width * 0.72;

            plot(ax, ...
                [x0 - median_half_width, x0 + median_half_width], ...
                [median_value, median_value], ...
                '-', ...
                'Color', this_color, ...
                'LineWidth', config.median_line_width, ...
                'HandleVisibility', 'off');
        end
    end
end

function [dens, yi] = estimateConditionComparisonDensityLocal(y)

    y = y(:)';

    if numel(y) < 2 || max(y) <= min(y)
        dens = [];
        yi = [];
        return;
    end

    if exist('ksdensity', 'file') == 2
        try
            [dens, yi] = ksdensity(y, 'NumPoints', 80);
            dens = dens(:)';
            yi = yi(:)';
            return;
        catch
        end
    end

    num_bins = min(20, max(6, round(sqrt(numel(y)) * 2)));
    edges = linspace(min(y), max(y), num_bins + 1);
    counts = histcounts(y, edges);
    centers = (edges(1:end-1) + edges(2:end)) / 2;

    if numel(counts) >= 3
        kernel = [1, 2, 3, 2, 1];
        kernel = kernel / sum(kernel);
        counts = conv(counts, kernel, 'same');
    end

    yi = linspace(min(y), max(y), 80);
    dens = interp1(centers, counts, yi, 'linear', 0);
end

function jitter = deterministicJitterLocal(n, half_width, seed)

    if n <= 1 || half_width <= 0
        jitter = zeros(n, 1);
        return;
    end

    stream = RandStream('mt19937ar', 'Seed', seed);
    jitter = (2 .* rand(stream, n, 1) - 1) .* half_width;
end

function fig = plotCombinedDeltaSummaryLocal( ...
    pooled_group, stim_types, category_labels, ...
    condition_display_mode, value_mode, group_display_name, ...
    class_names, class_labels, class_markers, ...
    delta_names, delta_labels, condition_colors, pooled_color, ...
    summary_type, violin_width, violin_face_alpha, ...
    show_points, point_size, point_jitter_width, point_alpha, ...
    condition_step, delta_gap, class_gap, ...
    font_name, axis_font_size, class_font_size, ...
    title_font_size, axis_line_width, ...
    figure_visible, figure_width, figure_height)

    num_classes = numel(class_names);
    num_deltas = numel(delta_names);
    num_conditions = numel(stim_types);

    [matrix_field, y_label, value_title, default_y_limits] = ...
        getValueModeConfigLocal(value_mode);

    [x_by_class_delta, delta_centers, class_centers, ...
        class_separators] = buildNestedXPositionsLocal( ...
        num_classes, num_deltas, num_conditions, ...
        condition_display_mode, condition_step, delta_gap, class_gap);

    all_values = [];

    for c = 1:num_classes
        for d = 1:num_deltas
            value_cells = collectConditionValuesLocal( ...
                pooled_group, stim_types, class_names{c}, d, ...
                matrix_field);

            for st = 1:num_conditions
                vals = value_cells{st};
                all_values = [ ...
                    all_values; vals(isfinite(vals))]; %#ok<AGROW>
            end
        end
    end

    y_limits = paddedLimitsLocal(all_values, default_y_limits);
    display_title = conditionDisplayModeTitleLocal( ...
        condition_display_mode);

    figure_name = sprintf('%s GPL-class delta Var | %s | %s', ...
        group_display_name, display_title, value_title);

    fig = figure( ...
        'Name', figure_name, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', figure_visible, ...
        'Position', [100, 100, figure_width, figure_height], ...
        'Renderer', 'painters');

    set(fig, ...
        'DefaultAxesFontName', font_name, ...
        'DefaultTextFontName', font_name);

    ax = axes(fig);
    hold(ax, 'on');

    set(ax, 'Units', 'normalized');

    if strcmp(condition_display_mode, 'separate')
        set(ax, 'Position', [0.055, 0.285, 0.925, 0.625]);
    else
        set(ax, 'Position', [0.075, 0.235, 0.90, 0.69]);
    end

    first_x = x_by_class_delta{1, 1}(1);
    last_x = x_by_class_delta{end, end}(end);
    edge_margin = max(0.60 * condition_step, 1.40 * violin_width);
    x_left = first_x - edge_margin;
    x_right = last_x + edge_margin;

    if y_limits(1) < 0 && y_limits(2) > 0
        plot(ax, [x_left, x_right], [0, 0], 'k--', ...
            'LineWidth', 1, 'HandleVisibility', 'off');
    end

    for c = 1:numel(class_separators)
        plot(ax, [class_separators(c), class_separators(c)], ...
            y_limits, '-', ...
            'Color', [0.75, 0.75, 0.75], ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    for c = 1:num_classes
        for d = 1:num_deltas
            value_cells = collectConditionValuesLocal( ...
                pooled_group, stim_types, class_names{c}, d, ...
                matrix_field);

            switch condition_display_mode
                case 'separate'
                    x_positions = x_by_class_delta{c, d};

                    for st = 1:num_conditions
                        drawOneViolinLocal( ...
                            ax, value_cells{st}, x_positions(st), ...
                            violin_width, condition_colors(st, :), ...
                            violin_face_alpha, summary_type, ...
                            show_points, point_size, ...
                            point_jitter_width, point_alpha, ...
                            class_markers{c});
                    end

                case 'pooled'
                    pooled_values = vertcat(value_cells{:});

                    drawOneViolinLocal( ...
                        ax, pooled_values, x_by_class_delta{c, d}(1), ...
                        violin_width, pooled_color, violin_face_alpha, ...
                        summary_type, show_points, point_size, ...
                        point_jitter_width, point_alpha, ...
                        class_markers{c});

                otherwise
                    error('Unknown condition_display_mode: %s', ...
                        condition_display_mode);
            end
        end
    end

    all_delta_centers = reshape(delta_centers.', 1, []);
    tick_labels = repmat(delta_labels, 1, num_classes);

    set(ax, ...
        'XLim', [x_left, x_right], ...
        'YLim', y_limits, ...
        'XTick', all_delta_centers, ...
        'XTickLabel', tick_labels, ...
        'TickLabelInterpreter', 'none');

    ylabel(ax, y_label, ...
        'Interpreter', 'tex', ...
        'FontName', font_name, ...
        'FontSize', axis_font_size, ...
        'FontWeight', 'normal');

    title(ax, sprintf('%s | %s | %s', ...
        group_display_name, display_title, value_title), ...
        'Interpreter', 'none', ...
        'FontName', font_name, ...
        'FontSize', title_font_size, ...
        'FontWeight', 'bold');

    cleanAxisLocal(ax, font_name, axis_font_size, axis_line_width);

    y_text = y_limits(1) - 0.135 * diff(y_limits);

    for c = 1:num_classes
        text(ax, class_centers(c), y_text, class_labels{c}, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', ...
            'Interpreter', 'none', ...
            'Clipping', 'off', ...
            'FontName', font_name, ...
            'FontSize', class_font_size, ...
            'FontWeight', 'normal');
    end

    if strcmp(condition_display_mode, 'separate')
        legend_labels = cell(size(category_labels));

        for st = 1:num_conditions
            legend_labels{st} = ...
                categoryDisplayNameLocal(category_labels{st});
        end

        addConditionLegendLocal(ax, legend_labels, condition_colors);
    end

    hold(ax, 'off');
end

function fig = plotFeatureDeltaSummaryLocal( ...
    pooled_effect, effect_definition, feature_display_mode, ...
    value_mode, group_display_name, ...
    class_names, class_labels, class_markers, source_labels, ...
    neutral_color, summary_type, violin_width, violin_face_alpha, ...
    show_points, point_size, point_jitter_width, point_alpha, ...
    inner_step, source_gap, class_gap, ...
    font_name, axis_font_size, class_font_size, ...
    title_font_size, axis_line_width, ...
    figure_visible, figure_width, figure_height)

    num_classes = numel(class_names);
    num_sources = numel(source_labels);
    num_matches = numel(effect_definition.fixed_labels);

    [matrix_field, y_label, value_title, default_y_limits] = ...
        getFeatureDeltaValueModeConfigLocal( ...
        value_mode, effect_definition.subscript);

    [x_by_class_source, source_centers, class_centers, ...
        class_separators] = buildNestedXPositionsLocal( ...
        num_classes, num_sources, num_matches, ...
        feature_display_mode, inner_step, source_gap, class_gap);

    all_values = [];

    for c = 1:num_classes
        for src = 1:num_sources
            value_cells = collectFeatureDeltaValuesLocal( ...
                pooled_effect, class_names{c}, src, matrix_field, ...
                num_sources, num_matches);

            for k = 1:num_matches
                vals = value_cells{k};
                all_values = [ ...
                    all_values; vals(isfinite(vals))]; %#ok<AGROW>
            end
        end
    end

    y_limits = paddedLimitsLocal(all_values, default_y_limits);
    display_title = featureDeltaDisplayModeTitleLocal( ...
        feature_display_mode);

    figure_name = sprintf('%s | %s | %s | %s', ...
        group_display_name, effect_definition.title, ...
        display_title, value_title);

    fig = figure( ...
        'Name', figure_name, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', figure_visible, ...
        'Position', [100, 100, figure_width, figure_height], ...
        'Renderer', 'painters');

    set(fig, ...
        'DefaultAxesFontName', font_name, ...
        'DefaultTextFontName', font_name);

    ax = axes(fig);
    hold(ax, 'on');
    set(ax, 'Units', 'normalized');

    if strcmp(feature_display_mode, 'separate')
        set(ax, 'Position', [0.055, 0.385, 0.925, 0.525]);
    else
        set(ax, 'Position', [0.075, 0.235, 0.90, 0.69]);
    end

    first_x = x_by_class_source{1, 1}(1);
    last_x = x_by_class_source{end, end}(end);
    edge_margin = max(0.60 * inner_step, 1.40 * violin_width);
    x_left = first_x - edge_margin;
    x_right = last_x + edge_margin;

    if y_limits(1) < 0 && y_limits(2) > 0
        plot(ax, [x_left, x_right], [0, 0], 'k--', ...
            'LineWidth', 1, 'HandleVisibility', 'off');
    end

    for c = 1:numel(class_separators)
        plot(ax, [class_separators(c), class_separators(c)], ...
            y_limits, '-', ...
            'Color', [0.75, 0.75, 0.75], ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    for c = 1:num_classes
        for src = 1:num_sources
            value_cells = collectFeatureDeltaValuesLocal( ...
                pooled_effect, class_names{c}, src, matrix_field, ...
                num_sources, num_matches);

            switch feature_display_mode
                case 'separate'
                    x_positions = x_by_class_source{c, src};

                    for k = 1:num_matches
                        drawOneViolinLocal( ...
                            ax, value_cells{k}, x_positions(k), ...
                            violin_width, neutral_color, ...
                            violin_face_alpha, summary_type, ...
                            show_points, point_size, ...
                            point_jitter_width, point_alpha, ...
                            class_markers{c});
                    end

                case 'pooled'
                    pooled_values = vertcat(value_cells{:});

                    drawOneViolinLocal( ...
                        ax, pooled_values, ...
                        x_by_class_source{c, src}(1), ...
                        violin_width, neutral_color, ...
                        violin_face_alpha, summary_type, ...
                        show_points, point_size, ...
                        point_jitter_width, point_alpha, ...
                        class_markers{c});

                otherwise
                    error('Unknown feature_delta_plot_mode: %s', ...
                        feature_display_mode);
            end
        end
    end

    set(ax, ...
        'XLim', [x_left, x_right], ...
        'YLim', y_limits);

    if strcmp(feature_display_mode, 'separate')
        all_inner_x = [];
        all_inner_labels = {};

        for c = 1:num_classes
            for src = 1:num_sources
                all_inner_x = [ ...
                    all_inner_x, x_by_class_source{c, src}]; %#ok<AGROW>
                all_inner_labels = [ ...
                    all_inner_labels, ...
                    effect_definition.fixed_labels]; %#ok<AGROW>
            end
        end

        set(ax, ...
            'XTick', all_inner_x, ...
            'XTickLabel', all_inner_labels, ...
            'TickLabelInterpreter', 'tex');

        try
            set(ax, 'XTickLabelRotation', 45);
        catch
        end
    else
        all_source_centers = reshape(source_centers.', 1, []);
        tick_labels = repmat(source_labels, 1, num_classes);

        set(ax, ...
            'XTick', all_source_centers, ...
            'XTickLabel', tick_labels, ...
            'TickLabelInterpreter', 'none');
    end

    ylabel(ax, y_label, ...
        'Interpreter', 'tex', ...
        'FontName', font_name, ...
        'FontSize', axis_font_size, ...
        'FontWeight', 'normal');

    title(ax, figure_name, ...
        'Interpreter', 'none', ...
        'FontName', font_name, ...
        'FontSize', title_font_size, ...
        'FontWeight', 'bold');

    cleanAxisLocal(ax, font_name, axis_font_size, axis_line_width);

    if strcmp(feature_display_mode, 'separate')
        source_y = y_limits(1) - 0.235 * diff(y_limits);
        class_y = y_limits(1) - 0.430 * diff(y_limits);

        for c = 1:num_classes
            for src = 1:num_sources
                text(ax, source_centers(c, src), source_y, ...
                    source_labels{src}, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'top', ...
                    'Interpreter', 'none', ...
                    'Clipping', 'off', ...
                    'FontName', font_name, ...
                    'FontSize', axis_font_size, ...
                    'FontWeight', 'normal');
            end

            text(ax, class_centers(c), class_y, class_labels{c}, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', ...
                'Interpreter', 'none', ...
                'Clipping', 'off', ...
                'FontName', font_name, ...
                'FontSize', class_font_size, ...
                'FontWeight', 'normal');
        end
    else
        class_y = y_limits(1) - 0.135 * diff(y_limits);

        for c = 1:num_classes
            text(ax, class_centers(c), class_y, class_labels{c}, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', ...
                'Interpreter', 'none', ...
                'Clipping', 'off', ...
                'FontName', font_name, ...
                'FontSize', class_font_size, ...
                'FontWeight', 'normal');
        end
    end

    hold(ax, 'off');
end

function [matrix_field, y_label, value_title, default_y_limits] = ...
        getFeatureDeltaValueModeConfigLocal(value_mode, subscript)

    value_mode = lower(strtrim(char(value_mode)));
    subscript = char(subscript);

    switch value_mode
        case 'raw'
            matrix_field = 'raw_delta_array';
            y_label = ['\Delta_{', subscript, '}Var'];
            value_title = 'Raw feature delta Var';
            default_y_limits = [-0.1, 0.1];

        case 'zscore'
            matrix_field = 'z_delta_array';
            y_label = ['\Delta_{', subscript, '}Z(Var)'];
            value_title = 'Feature delta of Z-scored Var';
            default_y_limits = [-3, 3];

        otherwise
            error('Unknown value_mode: %s', value_mode);
    end
end

function value_cells = collectFeatureDeltaValuesLocal( ...
    pooled_effect, class_name, source_idx, matrix_field, ...
    num_sources, num_matches)

    if ~isfield(pooled_effect, 'class') || ...
            ~isfield(pooled_effect.class, class_name)
        error('Missing pooled feature-delta data for class %s.', ...
            class_name);
    end

    C = pooled_effect.class.(class_name);

    if ~isfield(C, matrix_field) || ...
            ~isnumeric(C.(matrix_field))
        error('Class %s has an invalid %s field.', ...
            class_name, matrix_field);
    end

    matrix_values = C.(matrix_field);

    if size(matrix_values, 2) ~= num_sources || ...
            size(matrix_values, 3) ~= num_matches || ...
            source_idx < 1 || source_idx > num_sources
        error(['Class %s has incompatible dimensions in its ', ...
            '%s field.'], class_name, matrix_field);
    end

    value_cells = cell(1, num_matches);

    for k = 1:num_matches
        value_cells{k} = double(reshape( ...
            matrix_values(:, source_idx, k), [], 1));
    end
end

function title_text = featureDeltaDisplayModeTitleLocal( ...
        feature_display_mode)

    switch feature_display_mode
        case 'separate'
            title_text = 'Fixed combinations separate';
        case 'pooled'
            title_text = 'Fixed combinations pooled';
        otherwise
            error('Unknown feature_delta_plot_mode: %s', ...
                feature_display_mode);
    end
end

function [matrix_field, y_label, value_title, default_y_limits] = ...
        getValueModeConfigLocal(value_mode)

    value_mode = lower(strtrim(char(value_mode)));

    switch value_mode
        case 'raw'
            matrix_field = 'raw_delta_matrix';
            y_label = '\DeltaVar';
            value_title = 'Raw delta Var';
            default_y_limits = [-0.1, 0.1];

        case 'zscore'
            matrix_field = 'z_delta_matrix';
            y_label = '\Delta Z(Var)';
            value_title = 'Delta of Z-scored Var';
            default_y_limits = [-3, 3];

        otherwise
            error('Unknown value_mode: %s', value_mode);
    end
end

function [x_by_class_delta, delta_centers, class_centers, ...
        class_separators] = buildNestedXPositionsLocal( ...
        num_classes, num_deltas, num_conditions, ...
        condition_display_mode, condition_step, delta_gap, class_gap)

    switch condition_display_mode
        case 'separate'
            num_display_conditions = num_conditions;
        case 'pooled'
            num_display_conditions = 1;
        otherwise
            error('Unknown condition_display_mode: %s', ...
                condition_display_mode);
    end

    x_by_class_delta = cell(num_classes, num_deltas);
    delta_centers = nan(num_classes, num_deltas);
    class_centers = nan(1, num_classes);
    class_bounds = nan(num_classes, 2);
    x_cursor = 1;

    for c = 1:num_classes
        for d = 1:num_deltas
            x_positions = x_cursor + ...
                (0:num_display_conditions - 1) * condition_step;
            x_by_class_delta{c, d} = x_positions;
            delta_centers(c, d) = mean(x_positions);

            if d == 1
                class_bounds(c, 1) = x_positions(1);
            end

            if d < num_deltas
                x_cursor = x_positions(end) + delta_gap;
            else
                class_bounds(c, 2) = x_positions(end);
            end
        end

        class_centers(c) = mean(class_bounds(c, :));

        if c < num_classes
            x_cursor = class_bounds(c, 2) + class_gap;
        end
    end

    if num_classes > 1
        class_separators = 0.5 .* ( ...
            class_bounds(1:end - 1, 2) + ...
            class_bounds(2:end, 1));
    else
        class_separators = [];
    end
end

function value_cells = collectConditionValuesLocal( ...
    pooled_group, stim_types, class_name, delta_idx, matrix_field)

    value_cells = cell(1, numel(stim_types));

    for st = 1:numel(stim_types)
        stim_name = stim_types{st};

        if ~isfield(pooled_group.stim, stim_name) || ...
                ~isfield(pooled_group.stim.(stim_name), 'class') || ...
                ~isfield(pooled_group.stim.(stim_name).class, class_name)
            error('Missing pooled data for %s / %s.', ...
                stim_name, class_name);
        end

        C = pooled_group.stim.(stim_name).class.(class_name);

        if ~isfield(C, matrix_field) || ...
                ~isnumeric(C.(matrix_field)) || ...
                size(C.(matrix_field), 2) < delta_idx
            error('%s / %s has an invalid %s field.', ...
                stim_name, class_name, matrix_field);
        end

        matrix_values = C.(matrix_field);
        value_cells{st} = double(matrix_values(:, delta_idx));
    end
end

function title_text = conditionDisplayModeTitleLocal( ...
        condition_display_mode)

    switch condition_display_mode
        case 'separate'
            title_text = 'Conditions separate';
        case 'pooled'
            title_text = 'Conditions pooled';
        otherwise
            error('Unknown condition_display_mode: %s', ...
                condition_display_mode);
    end
end

function addConditionLegendLocal(ax, condition_labels, condition_colors)

    num_conditions = numel(condition_labels);
    legend_handles = gobjects(1, num_conditions);

    for st = 1:num_conditions
        legend_handles(st) = scatter( ...
            ax, nan, nan, 36, condition_colors(st, :), ...
            'o', 'filled', ...
            'MarkerEdgeColor', 'none');
    end

    lgd = legend(ax, legend_handles, condition_labels, ...
        'Location', 'southoutside', ...
        'Orientation', 'horizontal', ...
        'Interpreter', 'none');
    lgd.Box = 'off';

    try
        lgd.NumColumns = min(8, num_conditions);
    catch
    end
end

function drawOneViolinLocal( ...
    ax, vals, x_pos, violin_width, this_color, face_alpha, ...
    summary_type, show_points, point_size, max_jitter_width, ...
    point_alpha, marker_shape)

    vals = double(vals(:));
    vals = vals(isfinite(vals));

    if isempty(vals)
        return;
    end

    if show_points
        x_jitter = densityAwareJitterLocal( ...
            vals, x_pos, max_jitter_width);

        try
            scatter(ax, x_jitter, vals, point_size, marker_shape, ...
                'MarkerFaceColor', this_color, ...
                'MarkerEdgeColor', this_color, ...
                'MarkerFaceAlpha', point_alpha, ...
                'MarkerEdgeAlpha', point_alpha, ...
                'HandleVisibility', 'off');
        catch
            mixed_color = 1 - point_alpha .* (1 - this_color);

            scatter(ax, x_jitter, vals, point_size, marker_shape, ...
                'MarkerFaceColor', mixed_color, ...
                'MarkerEdgeColor', mixed_color, ...
                'HandleVisibility', 'off');
        end
    end

    can_draw_density = numel(vals) >= 2 && max(vals) ~= min(vals);

    if can_draw_density
        [f, xi] = estimateDensityLocal(vals);

        if ~isempty(f) && ~isempty(xi) && max(f) > 0
            f = f(:)';
            xi = xi(:)';
            f = f ./ max(f) .* violin_width;

            x_patch = [x_pos - f, fliplr(x_pos + f)];
            y_patch = [xi, fliplr(xi)];

            patch(ax, x_patch, y_patch, this_color, ...
                'FaceAlpha', face_alpha, ...
                'EdgeColor', this_color, ...
                'LineWidth', 1, ...
                'HandleVisibility', 'off');
        end
    end

    switch char(summary_type)
        case 'mean'
            summary_value = mean(vals);
        case 'median'
            summary_value = median(vals);
        otherwise
            error('Unknown violin_summary_type: %s', summary_type);
    end

    plot(ax, ...
        [x_pos - violin_width * 0.55, ...
         x_pos + violin_width * 0.55], ...
        [summary_value, summary_value], ...
        '-', ...
        'Color', this_color, ...
        'LineWidth', 2, ...
        'HandleVisibility', 'off');
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

function x_jitter = densityAwareJitterLocal( ...
    vals, x_pos, max_jitter_width)

    vals = vals(:);

    if isempty(vals)
        x_jitter = [];
        return;
    end

    if numel(vals) < 2 || max(vals) == min(vals)
        x_jitter = x_pos + zeros(size(vals));
        return;
    end

    [f, xi] = estimateDensityLocal(vals);

    if isempty(f) || isempty(xi) || max(f) <= 0
        x_jitter = x_pos + ...
            (rand(size(vals)) - 0.5) * 2 * max_jitter_width;
        return;
    end

    f = f(:);
    xi = xi(:);

    density_at_values = interp1( ...
        xi, f, vals, 'linear', 'extrap');
    density_at_values(~isfinite(density_at_values)) = 0;
    density_at_values(density_at_values < 0) = 0;

    if max(density_at_values) > 0
        density_at_values = ...
            density_at_values ./ max(density_at_values);
    else
        density_at_values = ones(size(vals));
    end

    density_floor = 0.08;
    density_at_values = density_floor + ...
        (1 - density_floor) .* density_at_values;
    local_width = max_jitter_width .* density_at_values;

    x_jitter = x_pos + ...
        (rand(size(vals)) - 0.5) .* 2 .* local_width;
end

function cleanAxisLocal(ax, font_name, font_size, line_width)
    grid(ax, 'on');
    box(ax, 'off');

    set(ax, ...
        'TickDir', 'out', ...
        'LineWidth', line_width, ...
        'FontName', font_name, ...
        'FontSize', font_size, ...
        'Layer', 'top');

    try
        set(ax, ...
            'GridColor', [0.82, 0.82, 0.82], ...
            'GridAlpha', 0.28);
    catch
    end
end

function lim_values = paddedLimitsLocal(values, default_limits)
    values = values(:);
    values = values(isfinite(values));

    if isempty(values)
        lim_values = default_limits;
        return;
    end

    min_value = min(values);
    max_value = max(values);

    if min_value == max_value
        padding = max(0.1, abs(min_value) * 0.1);
    else
        padding = 0.08 * (max_value - min_value);
    end

    lim_values = [min_value - padding, max_value + padding];
end

function label = categoryDisplayNameLocal(category_label)
    category_label = char(category_label);

    if isempty(category_label)
        label = '';
        return;
    end

    if contains(category_label, '-')
        label = category_label;
    else
        label = lower(category_label);
        label(1) = upper(label(1));
    end
end

function saveFigLocal(fig, fig_file)
    if exist('savefig', 'file') == 2
        savefig(fig, fig_file);
    else
        saveas(fig, fig_file);
    end
end

function saveSvgLocal(fig, svg_file)
    drawnow;

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, svg_file, ...
                'ContentType', 'vector', ...
                'BackgroundColor', 'white');
        else
            print(fig, svg_file, '-dsvg');
        end
    catch
        warning('SVG export failed. Falling back to saveas.');
        saveas(fig, svg_file);
    end
end

function savePngLocal(fig, png_file, dpi)
    drawnow;

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, png_file, ...
                'Resolution', dpi, ...
                'BackgroundColor', 'white');
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, png_file, '-dpng', sprintf('-r%d', dpi));
        end
    catch
        warning('PNG export failed. Falling back to saveas.');
        saveas(fig, png_file);
    end
end

function cfg = neuronVarianceConfigLocal(data_content,runIdx,model_mode, ...
        variance_source,uncertainty_included,DSL_filter,DSL_threshold, ...
        group_names,neuron_population)
% One configuration is used by both independently runnable scripts.
    cfg = struct('data_content',char(data_content),'runIdx',runIdx, ...
        'model_mode',lower(strtrim(char(model_mode))), ...
        'variance_source',lower(strtrim(char(variance_source))), ...
        'uncertainty_included',uncertainty_included, ...
        'DSL_filter',char(DSL_filter),'DSL_threshold',DSL_threshold, ...
        'group_names',{group_names},'neuron_population',char(neuron_population));
    assertStringOptionLocal(cfg.model_mode,{'each_condition','all_condition'},'model_mode');
    assertStringOptionLocal(cfg.variance_source,{'model','posterior'},'variance_source');
    assertStringOptionLocal(cfg.DSL_filter,{'all_latents','DSL_filtered'},'DSL_filter');
    assertStringOptionLocal(cfg.neuron_population,{'all_neurons','pcu_neurons'},'neuron_population');
    validateattributes(runIdx,{'numeric'},{'scalar','integer','positive','finite'});
    if ~isscalar(uncertainty_included) || ...
            ~ismember(double(uncertainty_included),[0 1])
        error('uncertainty_included must be 0 or 1.');
    end
    cfg.uncertainty_included = logical(uncertainty_included);
    cfg.model_dir = [cfg.model_mode '_mode'];
    if strcmp(cfg.model_mode,'each_condition'), cfg.mode_tag = 'eachcond';
    else, cfg.mode_tag = 'allcond'; end
    cfg.condition_labels = {'G-S-L','G-S-H','G-L-L','G-L-H', ...
        'P-S-L','P-S-H','P-L-L','P-L-H'};
    cfg.category_fields = {'G_S_L','G_S_H','G_L_L','G_L_H', ...
        'P_S_L','P_S_H','P_L_L','P_L_H'};
    cfg.latent_labels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
    cfg.variance_fields = {'use_across','use_within','use_feedforward', ...
        'use_feedback','use_ambiguous'};
    cfg.filter_tag = 'allL';
    if strcmp(cfg.variance_source,'model')
        if strcmp(cfg.model_mode,'all_condition')
            error('all_condition + model is unsupported. Use each_condition or posterior.');
        end
        cfg.uncertainty_included = false;
        cfg.source_tag = 'model';
        if strcmp(cfg.DSL_filter,'DSL_filtered')
            validateattributes(DSL_threshold,{'numeric'},{'scalar','real','finite'});
            cfg.filter_tag = sprintf('dsl%g',DSL_threshold);
        end
    else
        if ~strcmp(cfg.DSL_filter,'all_latents')
            error('Posterior raw variance does not support DSL filtering.');
        end
        cfg.source_tag = sprintf('postU%d',cfg.uncertainty_included);
    end
    if strcmp(cfg.neuron_population,'all_neurons'), cfg.population_tag = 'allN';
    else, cfg.population_tag = 'pcuN'; end
    % Compact names keep all selection keys while reducing Windows path length.
    content_tag = regexprep(cfg.data_content,'[^A-Za-z0-9_]','_');
    if strcmp(cfg.data_content,'demean_count_within_t_and_condition')
        content_tag = 'dmTC';
    end
    cfg.file_tag = sprintf('%s_r%03d_%s_%s_%s_%s',content_tag,runIdx, ...
        cfg.mode_tag,cfg.source_tag,cfg.filter_tag,cfg.population_tag);
end

function R = loadNeuronVarianceLocal(sessionDir,cfg)
% The retained arrays are N_neuron x 8 feature combinations x 2 dirs x 5 categories.
% No population-mean variance is used as an individual neuron observation.
    if strcmp(cfg.variance_source,'model')
        R = loadModelNeuronVarianceLocal(sessionDir,cfg);
    else
        R = loadPosteriorNeuronVarianceLocal(sessionDir,cfg);
    end
    nvRequireLocal(R,{'condition_ids','direction_values','direction_variance', ...
        'unit_ids_by_group','source_file'},'neuron variance input');
    nvSizeLocal(R.condition_ids,[8 2],'condition_ids');
    ids = double(R.condition_ids(:));
    if any(~isfinite(ids) | ids<1 | ids~=round(ids)) || numel(unique(ids))~=16
        error('Require all eight stimulus combinations in both directions.');
    end
    dirs = double(R.direction_values(:));
    if numel(dirs)~=2 || any(~isfinite(dirs)) || numel(unique(dirs))~=2
        error('Require two distinct stimulus directions.');
    end
    ng = numel(cfg.group_names);
    if numel(R.direction_variance)~=ng || numel(R.unit_ids_by_group)~=ng
        error('Input model-group count differs from group_names.');
    end
    R.yDims = zeros(1,ng);
    for g=1:ng
        ids = nvIdsLocal(R.unit_ids_by_group{g});
        R.unit_ids_by_group{g} = ids;
        R.yDims(g) = numel(ids);
        X = R.direction_variance{g};
        nvSizeLocal(X,[numel(ids) 8 2 5],'per-neuron direction variance');
        nvVarianceLocal(X,'per-neuron direction variance');
        % Equal-weight direction mean, not variance after concatenating trials.
        A = reshape(mean(X,3),numel(ids),8,5);
        for st=1:8
            for k=1:5
                R.(cfg.category_fields{st}).(cfg.variance_fields{k}).neuron_by_group{g} = ...
                    A(:,st,k);
            end
        end
    end
    R.data_content = cfg.data_content; R.runIdx = cfg.runIdx;
    R.model_mode = cfg.model_mode; R.variance_source = cfg.variance_source;
    R.uncertainty_included = cfg.uncertainty_included;
    R.category_fields = cfg.category_fields; R.category_labels = cfg.condition_labels;
    R.var_split_mode = 'by_three_features'; R.split_file_tag = 'stszct';
end

function R = loadModelNeuronVarianceLocal(sessionDir,cfg)
    filename = fullfile(sessionDir,sprintf('%s_run%03d_eachcond_variance_DSL_summary.mat', ...
        cfg.data_content,cfg.runIdx));
    if ~isfile(filename)
        error('Missing %s. Run latent_compare_for_each_condtion_mode.m first.',filename);
    end
    S = load(filename,'SummaryVariance','AllConditionResults');
    nvRequireLocal(S,{'SummaryVariance','AllConditionResults'},filename);
    V = S.SummaryVariance;
    nvRequireLocal(V,{'meta','labels','group'},'SummaryVariance');
    nvRequireLocal(V.meta,{'data_content','runIdx','conditionShortLabels','dirValues', ...
        'DSL_threshold'},'SummaryVariance.meta');
    if ~strcmp(char(V.meta.data_content),cfg.data_content) || V.meta.runIdx~=cfg.runIdx
        error('Model summary data_content/runIdx mismatch.');
    end
    rowOrder = nvLabelOrderLocal(cfg.condition_labels,V.meta.conditionShortLabels);
    colOrder = nvLabelOrderLocal(cfg.latent_labels,V.labels);
    if strcmp(cfg.DSL_filter,'DSL_filtered') && ...
            abs(double(V.meta.DSL_threshold)-cfg.DSL_threshold)>1e-12
        error('Saved DSL threshold differs from DSL_threshold; rerun the session summary.');
    end
    ng = numel(cfg.group_names);
    if numel(V.group)~=ng, error('Model summary group count mismatch.'); end
    original = S.AllConditionResults;
    nvRequireLocal(original,{'condition','Stats'},'AllConditionResults');
    originalIds = double([original.condition]);
    if numel(unique(originalIds))~=numel(originalIds)
        error('Duplicate conditions in AllConditionResults.');
    end
    selected = 'all';
    if strcmp(cfg.DSL_filter,'DSL_filtered'), selected = 'filtered'; end
    R = struct('source_file',filename,'direction_values',double(V.meta.dirValues(:)'), ...
        'condition_ids',nan(8,2),'unit_ids_by_group',{cell(1,ng)}, ...
        'direction_variance',{cell(1,ng)},'bestmodel_files',{cell(8,2)}, ...
        'DSL_threshold',double(V.meta.DSL_threshold));
    for d=1:2
        for g=1:ng
            nvRequireLocal(V.group(g),{selected},'SummaryVariance.group');
            B = V.group(g).(selected);
            nvRequireLocal(B,{'stim_dir'},'SummaryVariance selected filter');
            if numel(B.stim_dir)~=2, error('Expected two model direction blocks.'); end
            A = B.stim_dir(d);
            nvRequireLocal(A,{'conditionIds','raw_mean','n_neurons'},'model stim_dir');
            cond = double(A.conditionIds(:));
            if numel(cond)~=8, error('Expected eight conditions in each direction.'); end
            if g==1, R.condition_ids(:,d)=cond(rowOrder);
            elseif ~isequal(R.condition_ids(:,d),cond(rowOrder))
                error('Model groups disagree about condition IDs.');
            end
        end
        for st=1:8
            id = R.condition_ids(st,d);
            ci = find(originalIds==id);
            if numel(ci)~=1, error('Missing model metadata for condition %g.',id); end
            E = original(ci); T = E.Stats;
            nvRequireLocal(T,{'meta','classification','group'},'Stats');
            nvRequireLocal(T.meta,{'condition_id','xDim_across','xDim_within'},'Stats.meta');
            if T.meta.condition_id~=id || numel(T.group)~=ng
                error('Model category metadata does not match this condition/group count.');
            end
            file = nvBestmodelLocal(sessionDir,cfg,id,E);
            R.bestmodel_files{st,d}=file;
            D = load(file,'varexp_raw');
            nvRequireLocal(D,{'varexp_raw'},file); raw = D.varexp_raw;
            nvRequireLocal(raw,{'meta','by_neuron','unit_ids_by_group'},'varexp_raw');
            nvRequireLocal(raw.meta,{'condition_id','runIdx','data_content', ...
                'xDim_across','xDim_within'},'varexp_raw.meta');
            if raw.meta.condition_id~=id || raw.meta.runIdx~=cfg.runIdx || ...
                    ~strcmp(char(raw.meta.data_content),cfg.data_content) || ...
                    ~isequal(raw.meta.xDim_across,T.meta.xDim_across) || ...
                    ~isequal(raw.meta.xDim_within(:),T.meta.xDim_within(:))
                error('Model variance/category provenance mismatch in %s.',file);
            end
            if numel(raw.by_neuron)~=ng || numel(raw.unit_ids_by_group)~=ng
                error('Model variance has the wrong group count.');
            end
            for g=1:ng
                ids = nvIdsLocal(raw.unit_ids_by_group{g});
                nvRequireLocal(T.group(g),{'unit_ids','DSL_keep_mask'},'Stats.group');
                if ~isequal(ids,double(T.group(g).unit_ids(:)))
                    error('Model variance and classification neuron IDs/order differ.');
                end
                L = T.meta.xDim_across+T.meta.xDim_within(g);
                X = double(raw.by_neuron{g});
                nvSizeLocal(X,[numel(ids) L],'varexp_raw.by_neuron');
                nvVarianceLocal(X,'varexp_raw.by_neuron');
                masks = nvCategoryMasksLocal(L,T.meta.xDim_across,T.classification);
                keep = true(1,L);
                if strcmp(cfg.DSL_filter,'DSL_filtered')
                    keep = reshape(T.group(g).DSL_keep_mask,1,[]);
                    if numel(keep)~=L || any(~ismember(double(keep),[0 1]))
                        error('Invalid saved DSL mask.');
                    end
                    keep = logical(keep);
                end
                if isempty(R.unit_ids_by_group{g})
                    R.unit_ids_by_group{g}=ids;
                    R.direction_variance{g}=nan(numel(ids),8,2,5);
                elseif ~isequal(ids,R.unit_ids_by_group{g})
                    error('Model neuron IDs/order change across conditions in group %d.',g);
                end
                Y=zeros(numel(ids),5);
                for k=1:5, Y(:,k)=sum(X(:,keep & masks{k}),2); end
                B = V.group(g).(selected).stim_dir(d);
                expected = double(B.raw_mean(rowOrder(st),colOrder));
                nvNearLocal(mean(Y,1),expected,'model per-neuron versus saved mean');
                if double(B.n_neurons(rowOrder(st)))~=numel(ids)
                    error('Saved model neuron count mismatch.');
                end
                R.direction_variance{g}(:,st,d,:)=reshape(Y,numel(ids),1,1,5);
            end
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
                R.direction_variance{g}(:,st,d,:)=reshape(Y,N,1,1,5);
                R.reconstruction_by_direction{g}(:,st,d,:)=reshape(M,N,1,1,5);
                R.uncertainty_by_direction{g}(:,st,d,:)=reshape(U,N,1,1,5);
            end
        end
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

function filename = nvBestmodelLocal(sessionDir,cfg,id,entry)
    folder = fullfile(sessionDir,sprintf('FA_Dlag_%s_condition%d',cfg.data_content,id), ...
        'mat_results',sprintf('run%03d',cfg.runIdx));
    % Relocate the saved basename to this session, so moved sessions remain usable.
    if isfield(entry,'bestmodel_file') && ~isempty(entry.bestmodel_file)
        oldPath = strrep(char(entry.bestmodel_file),'\',filesep);
        [~,base,ext] = fileparts(oldPath);
        candidate = fullfile(folder,[base ext]);
        if isfile(candidate)
            filename = candidate;
            return;
        end
    end
    listing = dir(folder);
    listing = listing(~[listing.isdir]);
    keep = false(size(listing));
    for k = 1:numel(listing)
        [~,base,ext] = fileparts(listing(k).name);
        keep(k) = contains(lower(base),'bestmodel') && ...
            (strcmpi(ext,'.mat') || isempty(ext));
    end
    listing = listing(keep);
    if numel(listing) ~= 1
        error('Expected one bestmodel MAT in %s; found %d.',folder,numel(listing));
    end
    filename = fullfile(folder,listing(1).name);
end


function masks = nvCategoryMasksLocal(L,a,C)
    nvRequireLocal(C,{'acrossIdx','feedforwardIdx','feedbackIdx','ambiguousIdx'}, ...
        'Stats.classification');
    if ~isscalar(a) || a<0 || a~=round(a) || L<a
        error('Invalid across/within latent dimensions.');
    end
    masks = repmat({false(1,L)},1,5);
    masks{1}(1:a) = true;
    masks{2}(a+1:L) = true;
    fields = {'feedforwardIdx','feedbackIdx','ambiguousIdx'};
    for k = 1:3
        idx = double(C.(fields{k})(:));
        if any(~isfinite(idx) | idx<1 | idx>a | idx~=round(idx)) || ...
                numel(unique(idx)) ~= numel(idx)
            error('Invalid %s in Stats.classification.',fields{k});
        end
        masks{k+2}(idx) = true;
    end
    if ~isequal(sort(double(C.acrossIdx(:))),reshape(1:a,[],1)) || ...
            any(double(masks{3})+double(masks{4})+double(masks{5}) ~= double(masks{1}))
        error('FF/FB/Ambiguous must partition the across latents exactly.');
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

