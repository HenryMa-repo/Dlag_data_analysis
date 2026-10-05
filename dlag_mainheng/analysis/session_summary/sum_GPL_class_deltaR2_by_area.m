%% sum_GPL_class_deltaR2_by_area.m
% Summarize neuron-wise reconstruction delta R2 across sessions after
% grouping neurons by spontaneous-subtracted GPL classification.
%
% R2 grouping modes:
%   by_stimtype       : grating and plaid (original behavior)
%   by_three_features : G-S-L through P-L-H (eight groups)
%
% For every neuron and requested R2 group, this script computes:
%   acr_vs_wit = R2(use_across)      - R2(use_within)
%   ff_vs_fb   = R2(use_feedforward) - R2(use_feedback)
%
% Optional stimulus-feature delta figures are available only for
% r2_split_mode = 'by_three_features'. For every reconstruction source
% (Across, Within, Feedforward, and Feedback), they compute matched:
%   GP = Grating - Plaid
%   SL = Small   - Large
%   LH = Low     - High
% while holding the other two stimulus dimensions fixed.
%
% Z-scoring is performed before subtraction, separately for every session
% and model group/area. Within one session-area, one common mean and one
% common sample SD are calculated after pooling all finite raw R2 values
% from all plotted GPL classes, all selected stimulus groups, and all five
% reconstruction fields: all, across, within, feedforward, and feedback.
% That same mean and SD are applied to every R2 value before any difference
% is calculated. Consequently, a zero delta of z-scored R2 means that the
% two original R2 values are equal. In an undifferenced z-scored R2 figure,
% zero instead marks that session-area's pooled raw-R2 mean. Areas are never
% mixed.
%
% Invalid GPL neurons remain in all population/unit-ID alignment checks and
% in session_data, but they are excluded from the z-score pool and figures.
%
% Conditions are displayed in one of two ways:
%   separate : condition-specific distributions remain separate inside
%              every GPL-class x delta-type block. Condition identity is
%              encoded by color and a legend, not by x-axis text.
%   pooled   : all condition values are concatenated within every
%              GPL-class x delta-type block. No averaging across conditions
%              is performed before concatenation.
%
% Raw delta R2 and delta of z-scored R2 are plotted in separate figures.
% The original analysis therefore produces two figures per model group/area.
% When stimulus-feature deltas are enabled, each model group/area receives
% six additional figures: raw GP/SL/LH and GP/SL/LH differences of
% z-scored R2.
% In by_three_features mode, optional cross-session undifferenced R2 figures
% compare the eight conditions within all/across/within/FF/FB separately for
% every model group/area x GPL class, for both raw and z-scored R2.
%
% In every figure, pooling concatenates observations without first averaging
% within neuron. Sessions are pooled without session-specific color, legend,
% or connecting line. The saved MAT retains the original session identity,
% raw deltas, deltas of z-scored R2, and the exact R2 z-score mean/SD used
% for every session-area.
%
% All z-scored outputs share the same session-area R2 normalization. Raw
% deltas remain direct differences of the original, unstandardized R2.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';

% -------------------------------------------------------------------------
% Reconstruction R2 settings
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

% Must match calculate_reconstruction_R2_dfferent_ways.m.
r2_split_mode = 'by_three_features';
% Options:
%   'by_stimtype'       - original grating/plaid grouping
%   'by_three_features' - G-S-L, G-S-H, G-L-L, G-L-H,
%                         P-S-L, P-S-H, P-L-L, P-L-H

condition_display_mode = 'separate';
% Options:
%   'separate' - keep conditions separate within every class x delta block;
%                condition colors and a legend identify the conditions
%   'pooled'   - concatenate all condition values within every class x
%                delta block; one neuron can contribute one value per
%                condition, and conditions are not averaged first

feature_delta_plot_mode = 'separate';
% Options:
%   'off'      - do not calculate or plot stimulus-feature delta R2
%   'separate' - keep the four matched fixed-dimension combinations
%                separate inside every GPL-class x reconstruction block
%   'pooled'   - concatenate the four matched combinations inside every
%                GPL-class x reconstruction block without averaging first
% This option is independent of condition_display_mode above.
% Any value other than 'off' requires r2_split_mode = 'by_three_features'.

plot_cross_session_condition_r2 = false;
% true  : in by_three_features mode, additionally plot the pooled-across-
%         session raw and z-scored R2 comparison for every area x GPL class
% false : skip those additional undifferenced R2 figures

model_mode = 'all_condition_model';
% Options:
%   'all_condition_model'
%   'condition_specific_models'

% Must match the source file produced by
% calculate_reconstruction_R2_dfferent_ways.m.
reconstruction_suffix = 'all_across_within_ff_fb';

% -------------------------------------------------------------------------
% GPL settings
% -------------------------------------------------------------------------

% Display/file labels only. Their order must follow the DLAG model-group
% order represented by yDims and unit_ids_by_group.
group_names = {'V1', 'MT'};

% Spontaneous-subtracted GPL classification file.
gpl_mat_name = 'unit_gpl_results_sponsub.mat';

% -------------------------------------------------------------------------
% Save settings
% -------------------------------------------------------------------------

save_mat = true;
save_fig = false;
save_svg = false;
save_png = true;
close_after_save = true;

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
% Cross-session condition-comparison R2 style (by_three_features only)
% -------------------------------------------------------------------------

% These settings match plot_GPL_class_reconstruction_R2_by_area.m.
r2_condition_plot_style = 'bar_points';
% Options:
%   'bar_points'    : optional mean bar + points + optional median square
%   'violin'        : violin + points + optional mean diamond/median line
%   'points_median' : points + optional mean diamond/median line; no outline

r2_condition_show_mean = struct( ...
    'bar_points', true, ...
    'violin', false, ...
    'points_median', false);

r2_condition_show_median = struct( ...
    'bar_points', true, ...
    'violin', true, ...
    'points_median', true);

r2_condition_point_size = 5;
r2_condition_point_alpha = 0.70;
r2_condition_point_jitter_width = 0.020;

r2_condition_violin_alpha = 0.28;
r2_condition_violin_width = 0.085;

r2_condition_bar_alpha = 0.90;
r2_condition_bar_width = 0.075;

r2_condition_mean_marker_size = 5;
r2_condition_median_marker_size = 5;
r2_condition_median_line_width = 2.0;

r2_condition_figure_width = 1600;
r2_condition_figure_height = 760;

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

% All five reconstruction R2 fields share one normalization pool within
% every session x model group/area. The same mean and sample SD are applied
% before any delta is calculated.
r2_field_names = { ...
    'use_all', ...
    'use_across', ...
    'use_within', ...
    'use_feedforward', ...
    'use_feedback'};

r2_field_labels = {'all', 'across', 'within', 'FF', 'FB'};

% These four fields enter the existing latent-source and stimulus-feature
% differences. use_all enters normalization and the undifferenced R2 plots,
% but is intentionally not added as a feature-delta reconstruction source.
source_r2_field_names = { ...
    'use_across', ...
    'use_within', ...
    'use_feedforward', ...
    'use_feedback'};

source_r2_field_labels = {'across', 'within', 'FF', 'FB'};

% Full display labels used as the middle x-axis hierarchy in the optional
% stimulus-feature delta figures. Their order follows source_r2_field_names.
feature_source_labels = { ...
    'Across', 'Within', 'Feedforward', 'Feedback'};

delta_names = {'acr_vs_wit', 'ff_vs_fb'};
delta_labels = {'acr vs. wit', 'ff vs. fb'};

delta_positive_fields = {'use_across', 'use_feedforward'};
delta_negative_fields = {'use_within', 'use_feedback'};

%% ======================= VALIDATE SETTINGS =============================

group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);
mapping_file_tag = strjoin(group_file_tags, '_');

[r2_split_mode, split_file_tag, stim_types, category_labels] = ...
    getR2SplitConfigLocal(r2_split_mode);

condition_display_mode = lower(strtrim(char(condition_display_mode)));
feature_delta_plot_mode = lower(strtrim(char(feature_delta_plot_mode)));
feature_delta_definitions = buildFeatureDeltaDefinitionsLocal();
feature_delta_enabled = ~strcmp(feature_delta_plot_mode, 'off');
plot_value_modes = {'raw', 'zscore'};

r2_condition_plot_style = ...
    normalizeConditionComparisonStyleLocal(r2_condition_plot_style);
validatePlotStatisticOptionsLocal( ...
    r2_condition_show_mean, 'r2_condition_show_mean');
validatePlotStatisticOptionsLocal( ...
    r2_condition_show_median, 'r2_condition_show_median');

r2_condition_compare_config = struct();
r2_condition_compare_config.plot_style = r2_condition_plot_style;
r2_condition_compare_config.show_mean = logical( ...
    r2_condition_show_mean.(r2_condition_plot_style));
r2_condition_compare_config.show_median = logical( ...
    r2_condition_show_median.(r2_condition_plot_style));
r2_condition_compare_config.point_size = r2_condition_point_size;
r2_condition_compare_config.point_alpha = r2_condition_point_alpha;
r2_condition_compare_config.point_jitter_width = ...
    r2_condition_point_jitter_width;
r2_condition_compare_config.violin_alpha = ...
    r2_condition_violin_alpha;
r2_condition_compare_config.violin_width = ...
    r2_condition_violin_width;
r2_condition_compare_config.bar_alpha = r2_condition_bar_alpha;
r2_condition_compare_config.bar_width = r2_condition_bar_width;
r2_condition_compare_config.mean_marker_size = ...
    r2_condition_mean_marker_size;
r2_condition_compare_config.median_marker_size = ...
    r2_condition_median_marker_size;
r2_condition_compare_config.median_line_width = ...
    r2_condition_median_line_width;
r2_condition_compare_config.figure_width = ...
    r2_condition_figure_width;
r2_condition_compare_config.figure_height = ...
    r2_condition_figure_height;
validateConditionComparisonConfigLocal(r2_condition_compare_config);

validateUserSettingsLocal( ...
    root_dir, data_content, model_mode, r2_split_mode, ...
    condition_display_mode, feature_delta_plot_mode, ...
    plot_cross_session_condition_r2, runIdx, ...
    reconstruction_suffix, group_names, gpl_mat_name, ...
    condition_colors_base, pooled_condition_color, ...
    feature_delta_color, figure_visible, ...
    class_names, class_labels, class_markers, class_short_names, ...
    r2_field_names, r2_field_labels, ...
    source_r2_field_names, source_r2_field_labels, ...
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

r2_condition_comparison_enabled = ...
    logical(plot_cross_session_condition_r2) && ...
    strcmp(r2_split_mode, 'by_three_features');

condition_colors = condition_colors_base(1:numel(stim_types), :);

model_tag = makeModelTagLocal(model_mode);

if strcmp(r2_split_mode, 'by_stimtype')
    output_prefix = sprintf( ...
        '%s_%s_GPLclass_deltaR2_acr_vs_wit_ff_vs_fb', ...
        data_content, model_tag);
else
    output_prefix = sprintf( ...
        '%s_%s_stszct_GPLclass_deltaR2_acr_vs_wit_ff_vs_fb', ...
        data_content, model_tag);
end

output_base = sprintf('%s_%s_%s', ...
    output_prefix, mapping_file_tag, condition_display_mode);

if feature_delta_enabled
    output_base = sprintf('%s_featuredelta_%s', ...
        output_base, feature_delta_plot_mode);
end

fprintf('\n============================================================\n');
fprintf('Across-session GPL-class delta R2 summary by area\n');
fprintf('Root dir              : %s\n', root_dir);
fprintf('Data content          : %s\n', data_content);
fprintf('Model mode            : %s\n', model_mode);
fprintf('R2 split mode         : %s\n', r2_split_mode);
fprintf('Condition display     : %s\n', condition_display_mode);
fprintf('Feature-delta plots   : %s\n', feature_delta_plot_mode);
if r2_condition_comparison_enabled
    fprintf('R2 condition compare  : on (%s)\n', ...
        r2_condition_plot_style);
elseif plot_cross_session_condition_r2
    fprintf(['R2 condition compare  : skipped ', ...
        '(requires by_three_features)\n']);
else
    fprintf('R2 condition compare  : off\n');
end
fprintf('Run index             : %d\n', runIdx);
fprintf('GPL MAT               : %s\n', gpl_mat_name);
fprintf('Delta 1               : across - within\n');
fprintf('Delta 2               : feedforward - feedback\n');
fprintf(['Z-score pool          : within each session x area, ', ...
    'all P/C/U neurons x %d R2 sources x %d R2 groups\n'], ...
    numel(r2_field_names), numel(stim_types));
fprintf('Z-score order         : R2 first, differences second\n');
fprintf('Z-score SD            : sample SD (N-1 normalization)\n');
fprintf('Violin summary bar    : %s\n', violin_summary_type);
fprintf('Value figures         : raw delta and delta of z-scored R2\n');
if feature_delta_enabled
    fprintf(['Feature-delta Z       : uses the same session x area ', ...
        'R2 mean and SD before subtraction\n']);
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
            session_dir, data_content, model_mode, r2_split_mode, ...
            split_file_tag, runIdx, ...
            reconstruction_suffix, group_names, group_display_names, ...
            group_file_tags, gpl_mat_name, ...
            r2_field_names, source_r2_field_names, delta_names, ...
            delta_positive_fields, delta_negative_fields, ...
            stim_types, category_labels, feature_delta_plot_mode, ...
            feature_delta_definitions, reference);

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

MultiSessionGPLClassDeltaR2 = buildMultiSessionDeltaSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, ...
    r2_split_mode, split_file_tag, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, class_short_names, ...
    r2_field_names, r2_field_labels, ...
    source_r2_field_names, source_r2_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, category_labels, ...
    output_prefix, output_base, condition_display_mode, ...
    condition_colors, pooled_condition_color, plot_value_modes, ...
    violin_summary_type, condition_step, between_delta_gap, ...
    between_class_gap, feature_delta_plot_mode, ...
    feature_delta_color, feature_delta_definitions, ...
    plot_cross_session_condition_r2, ...
    r2_condition_comparison_enabled, ...
    r2_condition_compare_config);

if save_mat
    mat_file = fullfile(root_dir, [output_base, '.mat']);
    save(mat_file, 'MultiSessionGPLClassDeltaR2', '-v7.3');
    fprintf('\nSaved MAT:\n  %s\n', mat_file);
end

%% ======================= PLOT GROUP FIGURES ============================

fig_handles = gobjects(numel(group_names), numel(plot_value_modes));

for g = 1:numel(group_names)
    for vm = 1:numel(plot_value_modes)
        value_mode = plot_value_modes{vm};

        fig = plotCombinedDeltaSummaryLocal( ...
            MultiSessionGPLClassDeltaR2.pooled(g), ...
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
            fig_file = fullfile(root_dir, [figure_base, '.fig']);
            saveFigLocal(fig, fig_file);
            fprintf('Saved FIG:\n  %s\n', fig_file);
        end

        if save_svg
            svg_file = fullfile(root_dir, [figure_base, '.svg']);
            saveSvgLocal(fig, svg_file);
            fprintf('Saved SVG:\n  %s\n', svg_file);
        end

        if save_png
            png_file = fullfile(root_dir, [figure_base, '.png']);
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
            pooled_effect = MultiSessionGPLClassDeltaR2.feature_delta_pooled(g).effect.(D.name);

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
                    fig_file = fullfile( ...
                        root_dir, [figure_base, '.fig']);
                    saveFigLocal(fig, fig_file);
                    fprintf('Saved FIG:\n  %s\n', fig_file);
                end

                if save_svg
                    svg_file = fullfile( ...
                        root_dir, [figure_base, '.svg']);
                    saveSvgLocal(fig, svg_file);
                    fprintf('Saved SVG:\n  %s\n', svg_file);
                end

                if save_png
                    png_file = fullfile( ...
                        root_dir, [figure_base, '.png']);
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

%% ============== PLOT CROSS-SESSION UNDIFFERENCED R2 ==================

if r2_condition_comparison_enabled
    r2_condition_fig_handles = gobjects( ...
        numel(group_names), numel(class_names), ...
        numel(plot_value_modes));

    for g = 1:numel(group_names)
        for c = 1:numel(class_names)
            for vm = 1:numel(plot_value_modes)
                value_mode = plot_value_modes{vm};

                fig = plotCrossSessionConditionR2Local( ...
                    MultiSessionGPLClassDeltaR2.pooled(g), ...
                    stim_types, category_labels, ...
                    r2_field_names, r2_field_labels, ...
                    class_names{c}, class_labels{c}, c, ...
                    value_mode, group_display_names{g}, ...
                    data_content, model_mode, condition_colors, ...
                    figure_visible, r2_condition_compare_config);

                r2_condition_fig_handles(g, c, vm) = fig;

                figure_base = sprintf( ...
                    '%s_%s_%s_%s_condcmp_%s_GPLclass_R2_%s_%s_%s', ...
                    data_content, model_mode, group_file_tags{g}, ...
                    split_file_tag, class_short_names{c}, ...
                    reconstruction_suffix, ...
                    r2_condition_plot_style, value_mode);

                if save_fig
                    fig_file = fullfile( ...
                        root_dir, [figure_base, '.fig']);
                    saveFigLocal(fig, fig_file);
                    fprintf('Saved FIG:\n  %s\n', fig_file);
                end

                if save_svg
                    svg_file = fullfile( ...
                        root_dir, [figure_base, '.svg']);
                    saveSvgLocal(fig, svg_file);
                    fprintf('Saved SVG:\n  %s\n', svg_file);
                end

                if save_png
                    png_file = fullfile( ...
                        root_dir, [figure_base, '.png']);
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
        getR2SplitConfigLocal(mode)

    if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
        error('r2_split_mode must be a character vector or string scalar.');
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
            error(['Unknown r2_split_mode: %s. Valid options are ', ...
                '''by_stimtype'' and ''by_three_features''.'], mode);
    end
end

function style = normalizeConditionComparisonStyleLocal(style)

    if ~(ischar(style) || (isstring(style) && isscalar(style)))
        error(['r2_condition_plot_style must be a character vector ', ...
            'or string scalar.']);
    end

    style = lower(strtrim(char(style)));
    valid_styles = {'bar_points', 'violin', 'points_median'};

    if ~any(strcmp(style, valid_styles))
        error(['r2_condition_plot_style = ''%s'' is invalid. Valid ', ...
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
            error(['R2 condition-comparison config is missing ', ...
                'field %s.'], required_fields{i});
        end
    end

    normalizeConditionComparisonStyleLocal(config.plot_style);
    validateLogicalScalarLocal(config.show_mean, ...
        'r2 condition-comparison show_mean');
    validateLogicalScalarLocal(config.show_median, ...
        'r2 condition-comparison show_median');

    validateattributes(config.point_size, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_point_size');
    validateattributes(config.point_alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'r2_condition_point_alpha');
    validateattributes(config.point_jitter_width, {'numeric'}, ...
        {'scalar', 'real', 'nonnegative', 'finite'}, ...
        mfilename, 'r2_condition_point_jitter_width');
    validateattributes(config.violin_alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'r2_condition_violin_alpha');
    validateattributes(config.violin_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_violin_width');
    validateattributes(config.bar_alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'r2_condition_bar_alpha');
    validateattributes(config.bar_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_bar_width');
    validateattributes(config.mean_marker_size, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_mean_marker_size');
    validateattributes(config.median_marker_size, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_median_marker_size');
    validateattributes(config.median_line_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_median_line_width');
    validateattributes(config.figure_width, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_figure_width');
    validateattributes(config.figure_height, {'numeric'}, ...
        {'scalar', 'real', 'positive', 'finite'}, ...
        mfilename, 'r2_condition_figure_height');
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
    root_dir, data_content, model_mode, r2_split_mode, ...
    condition_display_mode, feature_delta_plot_mode, ...
    plot_cross_session_condition_r2, runIdx, ...
    reconstruction_suffix, group_names, gpl_mat_name, ...
    condition_colors_base, pooled_condition_color, ...
    feature_delta_color, figure_visible, ...
    class_names, class_labels, class_markers, class_short_names, ...
    r2_field_names, r2_field_labels, ...
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
    requireNonemptyTextLocal(reconstruction_suffix, ...
        'reconstruction_suffix');
    requireNonemptyTextLocal(gpl_mat_name, 'gpl_mat_name');

    valid_model_modes = { ...
        'all_condition_model', ...
        'condition_specific_models'};

    assertStringOptionLocal(model_mode, valid_model_modes, 'model_mode');
    assertStringOptionLocal(r2_split_mode, ...
        {'by_stimtype', 'by_three_features'}, 'r2_split_mode');
    assertStringOptionLocal(condition_display_mode, ...
        {'separate', 'pooled'}, 'condition_display_mode');
    assertStringOptionLocal(feature_delta_plot_mode, ...
        {'off', 'separate', 'pooled'}, 'feature_delta_plot_mode');
    assertStringOptionLocal(figure_visible, {'on', 'off'}, ...
        'figure_visible');
    validateLogicalScalarLocal(plot_cross_session_condition_r2, ...
        'plot_cross_session_condition_r2');

    if ~strcmp(feature_delta_plot_mode, 'off') && ...
            ~strcmp(r2_split_mode, 'by_three_features')
        error(['feature_delta_plot_mode = ''%s'' requires ', ...
            'r2_split_mode = ''by_three_features''.'], ...
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
            'RGB row in [0,1] per R2 condition.']);
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
        r2_field_names, r2_field_labels, ...
        'r2_field_names', 'r2_field_labels');

    required_r2_fields = { ...
        'use_all', 'use_across', 'use_within', ...
        'use_feedforward', 'use_feedback'};

    if ~isequal(reshape(r2_field_names, 1, []), required_r2_fields)
        error(['r2_field_names must retain this order: ', ...
            'use_all, use_across, use_within, ', ...
            'use_feedforward, use_feedback.']);
    end

    validateParallelLabelListsLocal( ...
        source_field_names, source_field_labels, ...
        'source_r2_field_names', 'source_r2_field_labels');
    validateParallelLabelListsLocal( ...
        source_field_names, feature_source_labels, ...
        'source_r2_field_names', 'feature_source_labels');
    validateParallelLabelListsLocal( ...
        delta_names, delta_labels, 'delta_names', 'delta_labels');

    if ~any(strcmp('use_all', r2_field_names))
        error('r2_field_names must include use_all.');
    end

    for f = 1:numel(source_field_names)
        if ~any(strcmp(source_field_names{f}, r2_field_names))
            error(['source_r2_field_names{%d} is unavailable in ', ...
                'r2_field_names.'], f);
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
                'source_r2_field_names.'], delta_names{d});
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
                    'a stimulus field unavailable in r2_split_mode.'], ...
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
        case 'all_condition_model'
            tag = 'all_condition_M';

        case 'condition_specific_models'
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
    session_dir, data_content, model_mode, r2_split_mode, ...
    split_file_tag, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, gpl_mat_name, r2_field_names, ...
    source_field_names, delta_names, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, feature_delta_plot_mode, ...
    feature_delta_definitions, reference)

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

    r2_file = resolveR2FileLocal( ...
        session_dir, data_content, model_mode, runIdx, ...
        reconstruction_suffix, split_file_tag);

    if ~isfile(r2_file)
        error('Required reconstruction R2 file not found: %s', r2_file);
    end

    S = load(r2_file, 'stimtype_recon_R2');

    if ~isfield(S, 'stimtype_recon_R2')
        error('%s does not contain stimtype_recon_R2.', r2_file);
    end

    R = S.stimtype_recon_R2;
    num_groups = numel(group_names);

    validateStimtypeR2Local( ...
        R, data_content, model_mode, num_groups, r2_field_names, ...
        r2_split_mode, split_file_tag, stim_types, ...
        category_labels, r2_file);

    reference = validateOrInitializeReferenceLocal( ...
        reference, R, group_names, group_display_names, ...
        group_file_tags, r2_field_names, source_field_names, delta_names, ...
        r2_split_mode, stim_types, category_labels, session_dir);

    empty_group = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'unit_ids', [], ...
        'gpl_file', '', ...
        'class_info', struct(), ...
        'zscore', struct(), ...
        'r2_zscore', struct(), ...
        'feature_delta', struct(), ...
        'feature_delta_zscore', struct(), ...
        'stim', struct());

    groups = repmat(empty_group, 1, num_groups);

    fprintf('  R2 file: %s\n', r2_file);

    [gpl_group_by_index, gpl_file_by_index] = ...
        loadGplGroupsByModelIndexLocal( ...
        session_dir, gpl_mat_name, num_groups);

    source_r2_indices = nan(1, numel(source_field_names));

    for f = 1:numel(source_field_names)
        source_r2_indices(f) = find(strcmp( ...
            r2_field_names, source_field_names{f}), 1, 'first');
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
            raw_r2_matrix = nan( ...
                numel(model_ids), numel(r2_field_names));

            for f = 1:numel(r2_field_names)
                raw_r2_matrix(:, f) = getGroupR2VectorLocal( ...
                    R.(stim_name), r2_field_names{f}, g);
            end

            source_r2_matrix = raw_r2_matrix(:, source_r2_indices);

            raw_delta_matrix = nan( ...
                numel(model_ids), numel(delta_names));

            for d = 1:numel(delta_names)
                raw_delta_matrix(:, d) = ...
                    source_r2_matrix(:, delta_positive_indices(d)) - ...
                    source_r2_matrix(:, delta_negative_indices(d));
            end

            groups(g).stim.(stim_name).raw_r2_matrix = ...
                raw_r2_matrix;
            groups(g).stim.(stim_name).z_r2_matrix = ...
                nan(size(raw_r2_matrix));
            groups(g).stim.(stim_name).source_r2_matrix = ...
                source_r2_matrix;
            groups(g).stim.(stim_name).z_source_r2_matrix = ...
                nan(size(source_r2_matrix));
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

        plotted_mask = ...
            class_info.pattern | ...
            class_info.component | ...
            class_info.unclassified;

        if ~any(plotted_mask)
            error('%s contains no pattern/component/unclassified neurons.', ...
                group_display_names{g});
        end

        r2_zscore_pool = [];

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            this_r2 = groups(g).stim.(stim_name).raw_r2_matrix;
            this_r2 = this_r2(plotted_mask, :);
            r2_zscore_pool = [ ...
                r2_zscore_pool; this_r2(:)]; %#ok<AGROW>
        end

        num_possible = numel(r2_zscore_pool);
        r2_zscore_pool = r2_zscore_pool(isfinite(r2_zscore_pool));

        if numel(r2_zscore_pool) < 2
            error(['%s has fewer than two finite R2 values in the ', ...
                'session-area R2 z-score pool.'], ...
                group_display_names{g});
        end

        pool_mean = mean(r2_zscore_pool);
        pool_sd = std(r2_zscore_pool, 0);

        if ~isfinite(pool_mean) || ~isfinite(pool_sd) || pool_sd <= 0
            error(['%s has an invalid or zero sample SD in the ', ...
                'session-area R2 z-score pool.'], ...
                group_display_names{g});
        end

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            raw_r2_matrix = ...
                groups(g).stim.(stim_name).raw_r2_matrix;
            z_r2_matrix = (raw_r2_matrix - pool_mean) ./ pool_sd;
            z_source_r2_matrix = ...
                z_r2_matrix(:, source_r2_indices);
            z_delta_matrix = nan( ...
                numel(model_ids), numel(delta_names));

            for d = 1:numel(delta_names)
                z_delta_matrix(:, d) = ...
                    z_source_r2_matrix(:, delta_positive_indices(d)) - ...
                    z_source_r2_matrix(:, delta_negative_indices(d));
            end

            groups(g).stim.(stim_name).z_r2_matrix = z_r2_matrix;
            groups(g).stim.(stim_name).z_source_r2_matrix = ...
                z_source_r2_matrix;
            groups(g).stim.(stim_name).z_delta_matrix = z_delta_matrix;

            for d = 1:numel(delta_names)
                groups(g).stim.(stim_name).z_delta.( ...
                    delta_names{d}) = ...
                    z_delta_matrix(:, d);
            end
        end

        normalization = struct();
        normalization.pool_mean = pool_mean;
        normalization.pool_sd = pool_sd;
        normalization.std_normalization = 0;
        normalization.n_finite = numel(r2_zscore_pool);
        normalization.n_possible = num_possible;
        normalization.n_nonfinite = ...
            num_possible - numel(r2_zscore_pool);
        normalization.pooling_scope = [ ...
            'all finite P/C/U neuron raw R2 values pooled across ', ...
            num2str(numel(r2_field_names)), ...
            ' reconstruction fields (all, across, within, FF, FB) ', ...
            'and all ', num2str(numel(stim_types)), ...
            ' stimulus groups within this session and model group/area'];
        normalization.operation_order = [ ...
            'Apply the common R2 mean and sample SD first; then ', ...
            'calculate every latent-source or stimulus-feature difference'];

        groups(g).zscore = normalization;
        groups(g).r2_zscore = normalization;

        if ~strcmp(feature_delta_plot_mode, 'off')
            groups(g).feature_delta = ...
                computeFeatureDeltasForGroupLocal( ...
                groups(g).stim, ...
                numel(source_field_names), ...
                feature_delta_definitions, ...
                group_display_names{g});
            groups(g).feature_delta_zscore = normalization;
        end

        fprintf(['  %s: pattern=%d, component=%d, ', ...
            'unclassified=%d, invalid=%d, ', ...
            'R2 z-mean=%.6g, R2 z-SD=%.6g, z-N=%d/%d\n'], ...
            group_display_names{g}, ...
            sum(class_info.pattern), ...
            sum(class_info.component), ...
            sum(class_info.unclassified), ...
            sum(class_info.invalid), ...
            pool_mean, pool_sd, ...
            numel(r2_zscore_pool), num_possible);
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
    rec.r2_file = r2_file;
    rec.group = groups;
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
                stim_data.(D.positive_stim{k}).source_r2_matrix;
            negative_raw = ...
                stim_data.(D.negative_stim{k}).source_r2_matrix;
            positive_z = ...
                stim_data.(D.positive_stim{k}).z_source_r2_matrix;
            negative_z = ...
                stim_data.(D.negative_stim{k}).z_source_r2_matrix;

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
                error(['%s has incompatible source R2 matrices for ', ...
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
        E.zscore_order = 'R2 first, matched stimulus subtraction second';

        feature_delta.(D.name) = E;
    end
end

function r2_file = resolveR2FileLocal( ...
    session_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, split_file_tag)

    file_name = sprintf('%s_%s_%s_R2_%s.mat', ...
        data_content, model_mode, split_file_tag, ...
        reconstruction_suffix);

    switch char(model_mode)
        case 'all_condition_model'
            r2_file = fullfile( ...
                session_dir, ...
                sprintf('FA_Dlag_%s', data_content), ...
                'mat_results', ...
                sprintf('run%03d', runIdx), ...
                file_name);

        case 'condition_specific_models'
            r2_file = fullfile(session_dir, file_name);

        otherwise
            error('Unknown model_mode: %s', model_mode);
    end
end

function validateStimtypeR2Local( ...
    R, expected_content, expected_mode, expected_num_groups, field_names, ...
    expected_split_mode, expected_split_file_tag, ...
    stim_types, category_labels, source_file)

    required_top = { ...
        'data_content', ...
        'model_mode', ...
        'yDims', ...
        'unit_ids_by_group'};

    for i = 1:numel(required_top)
        if ~isfield(R, required_top{i})
            error('%s: stimtype_recon_R2 is missing %s.', ...
                source_file, required_top{i});
        end
    end

    if ~strcmp(char(R.data_content), char(expected_content))
        error('%s: data_content is %s; expected %s.', ...
            source_file, char(R.data_content), char(expected_content));
    end

    if ~strcmp(char(R.model_mode), char(expected_mode))
        error('%s: model_mode is %s; expected %s.', ...
            source_file, char(R.model_mode), char(expected_mode));
    end

    if isfield(R, 'r2_split_mode')
        stored_split_mode = lower(strtrim(char(R.r2_split_mode)));

        if ~strcmp(stored_split_mode, expected_split_mode)
            error('%s: r2_split_mode is %s; expected %s.', ...
                source_file, stored_split_mode, expected_split_mode);
        end
    elseif ~strcmp(expected_split_mode, 'by_stimtype')
        error(['%s: by_three_features requires an R2 MAT produced by ', ...
            'calculate_reconstruction_R2_dfferent_ways.m.'], source_file);
    end

    if isfield(R, 'split_file_tag') && ...
            ~strcmp(char(R.split_file_tag), expected_split_file_tag)
        error('%s: split_file_tag is %s; expected %s.', ...
            source_file, char(R.split_file_tag), ...
            expected_split_file_tag);
    end

    if isfield(R, 'category_fields')
        stored_category_fields = normalizeTextCellLocal( ...
            R.category_fields, 'R.category_fields');

        if ~isequal(reshape(stored_category_fields, 1, []), ...
                reshape(stim_types, 1, []))
            error(['%s: category_fields do not match ', ...
                'r2_split_mode = %s.'], ...
                source_file, expected_split_mode);
        end
    end

    if isfield(R, 'category_labels')
        stored_category_labels = normalizeTextCellLocal( ...
            R.category_labels, 'R.category_labels');

        if ~isequal(reshape(stored_category_labels, 1, []), ...
                reshape(category_labels, 1, []))
            error(['%s: category_labels do not match ', ...
                'r2_split_mode = %s.'], ...
                source_file, expected_split_mode);
        end
    end

    y_dims = double(R.yDims(:)');
    num_groups = expected_num_groups;

    if numel(y_dims) ~= num_groups || ...
            any(~isfinite(y_dims)) || ...
            any(y_dims ~= round(y_dims)) || ...
            any(y_dims < 1)
        error(['%s: yDims is invalid or contains %d groups instead ', ...
            'of the %d entries supplied in group_names.'], ...
            source_file, numel(y_dims), num_groups);
    end

    if ~iscell(R.unit_ids_by_group) || ...
            numel(R.unit_ids_by_group) ~= num_groups
        error('%s: unit_ids_by_group has the wrong group count.', ...
            source_file);
    end

    for g = 1:num_groups
        ids = R.unit_ids_by_group{g};

        if ~isnumeric(ids) || numel(ids) ~= y_dims(g)
            error(['%s: unit_ids_by_group{%d} length does not ', ...
                'match yDims(%d).'], source_file, g, g);
        end
    end

    for st = 1:numel(stim_types)
        stim_name = stim_types{st};

        if ~isfield(R, stim_name) || ~isstruct(R.(stim_name))
            error('%s: missing stimulus field %s.', ...
                source_file, stim_name);
        end

        for f = 1:numel(field_names)
            field_name = field_names{f};

            if ~isfield(R.(stim_name), field_name) || ...
                    ~isstruct(R.(stim_name).(field_name)) || ...
                    ~isfield(R.(stim_name).(field_name), ...
                    'neuron_by_group')
                error('%s: %s.%s is missing neuron_by_group.', ...
                    source_file, stim_name, field_name);
            end

            by_group = ...
                R.(stim_name).(field_name).neuron_by_group;

            if ~iscell(by_group) || numel(by_group) ~= num_groups
                error('%s: %s.%s.neuron_by_group has wrong group count.', ...
                    source_file, stim_name, field_name);
            end

            for g = 1:num_groups
                if ~isnumeric(by_group{g}) || ...
                        numel(by_group{g}) ~= y_dims(g)
                    error(['%s: %s.%s group %d has the wrong ', ...
                        'neuron count.'], ...
                        source_file, stim_name, field_name, g);
                end
            end
        end
    end
end

function reference = validateOrInitializeReferenceLocal( ...
    reference, R, group_names, group_display_names, group_file_tags, ...
    r2_field_names, source_field_names, delta_names, r2_split_mode, ...
    stim_types, category_labels, session_dir)

    if isempty(fieldnames(reference))
        reference.num_groups = numel(R.yDims);
        reference.group_names = reshape(group_names, 1, []);
        reference.group_display_names = ...
            reshape(group_display_names, 1, []);
        reference.group_file_tags = reshape(group_file_tags, 1, []);
        reference.r2_field_names = ...
            reshape(r2_field_names, 1, []);
        reference.source_field_names = ...
            reshape(source_field_names, 1, []);
        reference.delta_names = reshape(delta_names, 1, []);
        reference.r2_split_mode = r2_split_mode;
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
            ~isequal(reshape(r2_field_names, 1, []), ...
            reference.r2_field_names) || ...
            ~isequal(reshape(source_field_names, 1, []), ...
            reference.source_field_names) || ...
            ~isequal(reshape(delta_names, 1, []), ...
            reference.delta_names) || ...
            ~strcmp(r2_split_mode, reference.r2_split_mode) || ...
            ~isequal(reshape(stim_types, 1, []), ...
            reference.stim_types) || ...
            ~isequal(reshape(category_labels, 1, []), ...
            reference.category_labels)
        error('%s: plotting labels or field order differ across sessions.', ...
            session_dir);
    end
end

function vec = getGroupR2VectorLocal(stim_result, field_name, group_idx)
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
    r2_split_mode, split_file_tag, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, class_short_names, ...
    r2_field_names, r2_field_labels, ...
    source_field_names, source_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, category_labels, ...
    output_prefix, output_base, condition_display_mode, ...
    condition_colors, pooled_condition_color, plot_value_modes, ...
    violin_summary_type, condition_step, between_delta_gap, ...
    between_class_gap, feature_delta_plot_mode, ...
    feature_delta_color, feature_delta_definitions, ...
    plot_cross_session_condition_r2, ...
    r2_condition_comparison_enabled, r2_condition_compare_config)

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
        'r2_file', {}, ...
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
        session_info(s).r2_file = records{s}.r2_file;
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
                raw_r2_matrix = zeros(0, numel(r2_field_names));
                z_r2_matrix = zeros(0, numel(r2_field_names));
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

                    raw_r2_matrix = [ ...
                        raw_r2_matrix; ...
                        G.stim.(stim_name).raw_r2_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    z_r2_matrix = [ ...
                        z_r2_matrix; ...
                        G.stim.(stim_name).z_r2_matrix( ...
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
                C.raw_r2_matrix = raw_r2_matrix;
                C.z_r2_matrix = z_r2_matrix;
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
                C.finite_count_raw_by_r2_field = ...
                    sum(isfinite(raw_r2_matrix), 1);
                C.finite_count_z_by_r2_field = ...
                    sum(isfinite(z_r2_matrix), 1);
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

    M.meta.format_version = 'GPL_class_deltaR2_by_area_v5';
    M.meta.root_dir = root_dir;
    M.meta.data_content = data_content;
    M.meta.model_mode = model_mode;
    M.meta.r2_split_mode = r2_split_mode;
    M.meta.split_file_tag = split_file_tag;
    M.meta.condition_display_mode = condition_display_mode;
    M.meta.feature_delta_plot_mode = feature_delta_plot_mode;
    M.meta.feature_delta_enabled = ...
        ~strcmp(feature_delta_plot_mode, 'off');
    M.meta.plot_cross_session_condition_r2 = ...
        logical(plot_cross_session_condition_r2);
    M.meta.r2_condition_comparison_enabled = ...
        logical(r2_condition_comparison_enabled);
    M.meta.r2_condition_plot_style = ...
        r2_condition_compare_config.plot_style;
    M.meta.zscore_operation_order = 'R2 first, differences second';
    M.meta.runIdx = runIdx;
    M.meta.reconstruction_suffix = reconstruction_suffix;
    M.meta.gpl_mat_name = gpl_mat_name;
    M.meta.output_prefix = output_prefix;
    M.meta.output_base = output_base;
    M.meta.mapping_file_tag = mapping_file_tag;
    M.meta.num_sessions = num_sessions;
    M.meta.num_groups = num_groups;
    M.meta.num_stim_types = numel(stim_types);
    M.meta.num_categories = numel(stim_types);
    M.meta.num_delta_types = numel(delta_names);
    M.meta.num_r2_fields = numel(r2_field_names);
    M.meta.num_feature_delta_types = ...
        numel(feature_delta_definitions);

    M.settings.condition_colors = condition_colors;
    M.settings.pooled_condition_color = pooled_condition_color;
    M.settings.feature_delta_color = feature_delta_color;
    M.settings.plot_value_modes = reshape(plot_value_modes, 1, []);
    M.settings.violin_summary_type = violin_summary_type;
    M.settings.zscore_std_normalization = 0;
    M.settings.r2_condition_compare_config = ...
        r2_condition_compare_config;
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
    M.labels.r2_field_name = reshape(r2_field_names, 1, []);
    M.labels.r2_field = reshape(r2_field_labels, 1, []);
    M.labels.source_r2_field_name = ...
        reshape(source_field_names, 1, []);
    M.labels.source_r2_field = ...
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
    M.r2_zscore_by_session_area = zscore_by_session_area;
    M.pooled = pooled;
    M.feature_delta_definitions = feature_delta_definitions;
    M.feature_delta_zscore_by_session_area = ...
        feature_zscore_by_session_area;
    M.feature_delta_pooled = feature_delta_pooled;

    M.dimension_names.source_r2_matrix = { ...
        'neuron', 'source_r2_field'};
    M.dimension_names.raw_r2_matrix = {'neuron', 'r2_field'};
    M.dimension_names.z_r2_matrix = {'neuron', 'r2_field'};
    M.dimension_names.raw_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.z_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.feature_raw_delta_array = { ...
        'neuron', 'source_r2_field', 'fixed_dimension_match'};
    M.dimension_names.feature_z_delta_array = { ...
        'neuron', 'source_r2_field', 'fixed_dimension_match'};

    M.notes.delta_definition = [ ...
        'acr_vs_wit = use_across R2 - use_within R2; ', ...
        'ff_vs_fb = use_feedforward R2 - use_feedback R2'];
    M.notes.zscore_definition = [ ...
        'For every session and area/model group separately, one mean and ', ...
        'one sample SD are calculated from all finite raw R2 values after ', ...
        'pooling pattern/component/unclassified neurons, all five ', ...
        'reconstruction fields (all, across, within, FF, FB), and all ', ...
        num2str(numel(stim_types)), ...
        ' stimulus groups selected by r2_split_mode. The same mean and ', ...
        'SD are applied to every R2 value in that session-area before ', ...
        'any latent-source or stimulus-feature difference is calculated.'];
    M.notes.zscore_zero_interpretation = [ ...
        'Because both terms in every difference use the same session-area ', ...
        'R2 mean and SD, their shared mean cancels. A zero difference of ', ...
        'z-scored R2 therefore means the two original R2 values are equal. ', ...
        'For an undifferenced z-scored R2 value, zero instead denotes the ', ...
        'pooled raw-R2 mean of that session-area.'];
    M.notes.invalid_neurons = [ ...
        'Invalid neurons remain in alignment checks and session_data, ', ...
        'but are excluded from the z-score pool and summary figures.'];
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
    M.notes.value_figures = [ ...
        'Raw delta R2 and delta of z-scored R2 are always plotted as ', ...
        'separate figures for every model group/area.'];
    M.notes.feature_delta_definition = [ ...
        'For each reconstruction source separately: GP = Grating minus ', ...
        'Plaid, SL = Small minus Large, and LH = Low minus High, while ', ...
        'holding the other two stimulus dimensions fixed.'];
    M.notes.feature_delta_zscore_definition = [ ...
        'The optional stimulus-feature delta figures use the same common ', ...
        'R2 mean and sample SD as every other z-scored result in that ', ...
        'session-area. R2 is standardized first and the matched GP, SL, ', ...
        'or LH subtraction is performed second.'];
    M.notes.feature_delta_plotting = [ ...
        'In separate mode, the four matched fixed-dimension combinations ', ...
        'remain separate. In pooled mode they are concatenated without ', ...
        'first averaging within neuron. All feature-delta distributions ', ...
        'use one neutral color.'];
    M.notes.r2_condition_comparison = [ ...
        'When enabled in by_three_features mode, undifferenced R2 figures ', ...
        'pool neurons across sessions within each area and GPL class. ', ...
        'Raw and z-scored R2 are plotted separately for all, across, ', ...
        'within, FF, and FB; the eight conditions remain separate and ', ...
        'retain their standard colors.'];
end

function fig = plotCrossSessionConditionR2Local( ...
    pooled_group, stim_types, condition_labels, ...
    r2_field_names, r2_field_labels, ...
    class_name, class_label, class_idx, value_mode, ...
    group_display_name, data_content, model_mode, ...
    condition_colors, figure_visible, config)

    num_conditions = numel(stim_types);
    num_reconstructions = numel(r2_field_names);

    [matrix_field, y_label, value_title, default_y_limits] = ...
        getUndifferencedR2ValueModeConfigLocal(value_mode);

    values = cell(num_reconstructions, num_conditions);
    all_values = [];

    for p = 1:num_conditions
        stim_name = stim_types{p};

        if ~isfield(pooled_group.stim, stim_name) || ...
                ~isfield(pooled_group.stim.(stim_name), 'class') || ...
                ~isfield(pooled_group.stim.(stim_name).class, class_name)
            error('Missing pooled R2 data for %s / %s.', ...
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
        '%s | GPL class: %s | %s condition-comparison R2', ...
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
        'XTickLabel', r2_field_labels, ...
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
        '%s | GPL class: %s | %d-condition reconstruction R^2 comparison | %s', ...
        group_display_name, class_label, num_conditions, value_title), ...
        'Interpreter', 'none', ...
        'FontWeight', 'bold');

    if strcmp(value_mode, 'zscore')
        subtitle_text = sprintf([ ...
            '%s | %s | Z=0: session-area pooled R2 mean | ', ...
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
        getUndifferencedR2ValueModeConfigLocal(value_mode)

    value_mode = lower(strtrim(char(value_mode)));

    switch value_mode
        case 'raw'
            matrix_field = 'raw_r2_matrix';
            y_label = 'Neuron R^2';
            value_title = 'Raw R2';
            default_y_limits = [-1, 1];

        case 'zscore'
            matrix_field = 'z_r2_matrix';
            y_label = 'Z(R^2)';
            value_title = 'Z-scored R2';
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

    figure_name = sprintf('%s GPL-class delta R2 | %s | %s', ...
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
            y_label = ['\Delta_{', subscript, '}R^2'];
            value_title = 'Raw feature delta R2';
            default_y_limits = [-0.1, 0.1];

        case 'zscore'
            matrix_field = 'z_delta_array';
            y_label = ['\Delta_{', subscript, '}Z(R^2)'];
            value_title = 'Feature delta of Z-scored R2';
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
            y_label = '\DeltaR^2';
            value_title = 'Raw delta R2';
            default_y_limits = [-0.1, 0.1];

        case 'zscore'
            matrix_field = 'z_delta_matrix';
            y_label = '\Delta Z(R^2)';
            value_title = 'Delta of Z-scored R2';
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
