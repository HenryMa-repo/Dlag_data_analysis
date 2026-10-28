%% latent_compare_figure_plot.m
% Poster figure for latent-category summaries across sessions and areas.
% All axes, category/condition labels and legends use Arial 30 pt. The
% larger canvas reserves space for labels outside the plotted data.
% Neutral colors use the same shared_gray/axis_gray/guide_gray/division_gray
% controls as timescale_compare_figure; area-specific data retain area colors.
%
% Place this standalone script alongside sum_sessions_latent_compare.m. It
% reads the SAME Latents_compare.m results, uses the SAME per-session values,
% filters, and NaN handling, and leaves existing outputs untouched.
%
% X-axis order: Within [V1 MT], Across [V1 MT],
% Feedforward [V1 MT], Feedback [V1 MT], Ambiguous [V1 MT].
% Identical latent categories stay together; areas are adjacent within each
% category. Only the latent category is labeled below each pair; a single
% colored legend identifies the V1 and MT areas.
% Model group 1 is labeled V1 and group 2 MT by default. group_names are
% display/file labels only and MUST follow the model's saved group order;
% they never select or validate the group from stored area/probe metadata.
%
% Area alone determines color. By-condition plots use one gray-labeled panel
% per condition, with area colors reused in every panel. A pooled summary
% produces a single plot containing all areas. No figure title is added.
%
% Each point is one session for pooled_category; for by_condition, each
% session contributes one point per stim_dir, as in the source program.
% Output includes the original MultiSessionSummary (MAT), editable FIG/SVG,
% and optional high-resolution PNG. File names are distinct from the source.
%
% Folder rule:
%   root_dir/*/catgt_*
% Each catgt_* folder is treated as one session.
%
% Supported analyses:
%   1) condition_specific_models + by_condition
%      Reads: catgt_dir/<data_content>_sum_all_conditions_DSL_and_latent_category_stats.mat
%      Uses : SummaryCategory
%      Metrics: percentLatents, percentSharedVariance
%
%   2) all_condition_model + by_condition
%      Reads: catgt_dir/FA_Dlag_<data_content>/mat_results/runXXX/DSL_and_latent_category_stats.mat
%      Uses : CondPosteriorVarExp
%      Metric: percentSharedVariance only
%
%      Important:
%      For by_condition plots, stim-dir panels are NOT compared across sessions.
%      All stim-dir entries from each session are pooled into the same
%      condition/category distribution. Therefore, if each session has two
%      stim dirs, each session contributes two points to each condition/category.
%
%   3) all_condition_model + pooled_category
%      Reads: catgt_dir/FA_Dlag_<data_content>/mat_results/runXXX/DSL_and_latent_category_stats.mat
%      Uses : Stats / Stats_bystimdir / Stats_bystimnamedir / Stats_bycondition
%      Metrics: percentLatents, percentSharedVariance
%
% Output: ONE figure containing both areas for each selected analysis.
% by_condition: ONE figure with labeled condition panels, each with both areas.
% Optional .mat, .fig, .svg and .png saved into root_dir.
%
% Plot styles:
%   bar_points    = optional mean bar + individual points + optional median
%   violin        = violin + individual points + optional mean/median
%   points_median = individual points + optional mean/median, no outline
%
% Color codes area ONLY. Latent categories, conditions, and sessions do not
% get additional colors or shades. The legend identifies the area colors.

clc; clear;

%% ========================== USER SETTINGS ==============================
root_dir = 'I:\np_data';

% -------------------------------------------------------------------------
% Data content
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

% -------------------------------------------------------------------------
% Model mode
% -------------------------------------------------------------------------
model_mode = 'all_condition_model';
% Options:
%   'all_condition_model'
%   'condition_specific_models'

% -------------------------------------------------------------------------
% Summary type
% -------------------------------------------------------------------------
summary_type = 'pooled_category';
% Options:
%   'by_condition'
%   'pooled_category'
%
% Notes:
%   condition_specific_models supports only 'by_condition'.
%   all_condition_model supports both 'by_condition' and 'pooled_category'.
%   all_condition_model + by_condition uses posterior condition-specific
%   shared variance and supports only metric_name = 'percentSharedVariance'.

% -------------------------------------------------------------------------
% DSL filter
% -------------------------------------------------------------------------
DSL_filter = 'all_latents';
% Options for condition_specific_models:
%   'all_latents'
%   'DSL_filtered'
%
% Options for all_condition_model:
%   'all_latents'
%   'DSL_filtered'
%   'stim_dir_DSL_filtered'
%   'stim_name_stim_dir_DSL_filtered'
%   'condition_DSL_filtered'

% -------------------------------------------------------------------------
% Metric
% -------------------------------------------------------------------------
metric_name = 'percentLatents';
% Options:
%   'percentLatents'
%   'percentSharedVariance'
%
% Notes:
%   all_condition_model + by_condition supports only 'percentSharedVariance'.

% Display/file labels only. Their order must follow the group order already
% present in the saved Latents_compare results. These names do not select
% data and are not compared with any stored group or area name.
% Repeated area names are allowed, for example: {'V1', 'V2', 'V1'}.
group_names = {'V1', 'MT'};

% -------------------------------------------------------------------------
% Save options
% -------------------------------------------------------------------------
save_mat = false;
save_fig = true;
save_svg = true;
save_png = false;
png_dpi = 300;
close_after_save = false;

% Print full MATLAB error report for skipped sessions.
print_full_error_report = false;

% -------------------------------------------------------------------------
% Plot options
% -------------------------------------------------------------------------
make_plots = true;
fig_visible = 'on';   % 'on' or 'off'

% Color rows correspond to UNIQUE area names in their first-occurrence order.
% Repeating one name in group_names reuses its assigned color.
area_colors = [0.0000, 0.4470, 0.7410; ...  % V1: blue
               0.8500, 0.3250, 0.0980];    % MT: orange

% Same neutral-color controls as timescale_compare_figure.
% All area-specific bars, violins and dots continue to use area_colors.
shared_gray = [0 0 0];       % mean/median marks and neutral point outlines
axis_gray = [0 0 0];         % axes, labels, panel labels and legend text
guide_gray = [0.3 0.3 0.3];  % vertical category separators
division_gray = [0.3 0.3 0.3]; % optional horizontal reference lines
latent_division_lines = []; % metric units (%); [] keeps reference lines off

% Distances are in x-axis data units. Areas within one latent category are
% adjacent; there is a wider gap between different latent categories.
within_category_area_spacing = 1.0;
between_category_spacing = 1.9;

% FIG/SVG sizes in inches; vector export is suited to poster composition.
pooled_figure_size_inches = [18.0, 9.0];
condition_panel_size_inches = [16.0, 9.0]; % 2 columns, one row per 2 conditions
axis_font_size = 30; % points; axes, labels, condition labels and legend
category_font_size = 30; % points; category tick labels

plot_style = 'points_median';
% Options:
%   'bar_points'    : optional mean bar + points + optional median square
%   'violin'        : violin + points + optional mean diamond/median line
%   'points_median' : points + optional mean diamond/median line; no outline

% Mean and median visibility can be set independently for each plot style.
% The defaults give the intended three displays:
%   bar_points    -> mean bar + points
%   violin        -> violin + points + median
%   points_median -> points + median
plot_show_mean = struct( ...
    'bar_points', true, ...
    'violin', false, ...
    'points_median', false);

plot_show_median = struct( ...
    'bar_points', false, ...
    'violin', true, ...
    'points_median', true);

point_size =70;
point_alpha = 1;

% Maximum absolute horizontal displacement of points from their category
% center. Jitter is deterministic, so rerunning gives the same positions.
point_jitter_width = 0.140;         % each condition occupies its own panel
pooled_point_jitter_width = 0.140;  % pooled-category plot

% Violin mode options
violin_alpha = 0.28;
violin_width = 0.28;         % by-condition plot (one value set per category)
pooled_violin_width = 0.28;  % pooled-category plot

% Bar + points mode options
bar_alpha = 0.9;
bar_width = 0.45;            % by-condition plot (one bar per category)
pooled_bar_width = 0.45;     % pooled-category plot

% Summary marker options
mean_marker_size = 5;
median_marker_size = 6;
median_line_width = 2.0;

%% ======================= VALIDATE SETTINGS =============================
plot_style = lower(strtrim(char(plot_style)));
validateUserSettings(model_mode, summary_type, DSL_filter, metric_name, plot_style);
validatePlotStatisticOptionsLocal(plot_show_mean, 'plot_show_mean');
validatePlotStatisticOptionsLocal(plot_show_median, 'plot_show_median');

plot_show_mean_current = logical(plot_show_mean.(plot_style));
plot_show_median_current = logical(plot_show_median.(plot_style));

validateattributes(png_dpi, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'png_dpi');
validateattributes(point_jitter_width, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'}, ...
    mfilename, 'point_jitter_width');
validateattributes(pooled_point_jitter_width, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'}, ...
    mfilename, 'pooled_point_jitter_width');
validateattributes(within_category_area_spacing, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'}, ...
    mfilename, 'within_category_area_spacing');
validateattributes(between_category_spacing, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'}, ...
    mfilename, 'between_category_spacing');
validateattributes(area_colors, {'numeric'}, ...
    {'2d', 'ncols', 3, 'real', 'finite', '>=', 0, '<=', 1}, mfilename, 'area_colors');
gray_colors = {shared_gray, axis_gray, guide_gray, division_gray};
gray_color_names = {'shared_gray', 'axis_gray', 'guide_gray', 'division_gray'};
for k = 1:numel(gray_colors)
    validateattributes(gray_colors{k}, {'numeric'}, ...
        {'size', [1 3], 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, gray_color_names{k});
end
validateattributes(latent_division_lines, {'numeric'}, ...
    {'real', 'finite'}, mfilename, 'latent_division_lines');
if ~isempty(latent_division_lines) && ~isvector(latent_division_lines)
    error('latent_division_lines must be a vector or [].');
end
validateattributes(axis_font_size, {'numeric'}, ...
    {'scalar', 'positive', 'finite'}, mfilename, 'axis_font_size');
validateattributes(category_font_size, {'numeric'}, ...
    {'scalar', 'positive', 'finite'}, mfilename, 'category_font_size');
validateattributes(pooled_figure_size_inches, {'numeric'}, ...
    {'vector', 'numel', 2, 'positive', 'finite'}, ...
    mfilename, 'pooled_figure_size_inches');
validateattributes(condition_panel_size_inches, {'numeric'}, ...
    {'vector', 'numel', 2, 'positive', 'finite'}, ...
    mfilename, 'condition_panel_size_inches');

group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags, group_mapping_tag] = ...
    buildGroupLabelsLocal(group_names);
group_colors = resolveAreaColorsLocal(group_names, area_colors);

model_tag = makeModelTag(model_mode);
type_tag = makeSummaryTypeTag(summary_type);
filter_tag = makeFilterTag(DSL_filter);
metric_tag = makeMetricTag(metric_name);
stat_tag = sprintf('m%d_md%d', plot_show_mean_current, plot_show_median_current);
out_base = sprintf('latent_compare_figure_plot_%s_%s_run%03d_%s_%s_%s_%s_%s_%s_catArea_withinFirst', ...
    data_content, model_tag, runIdx, type_tag, filter_tag, ...
    metric_tag, plot_style, stat_tag, group_mapping_tag);

fprintf('Root dir          : %s\n', root_dir);
fprintf('Model mode        : %s\n', model_mode);
fprintf('Summary type      : %s\n', summary_type);
fprintf('DSL filter        : %s\n', DSL_filter);
fprintf('Metric            : %s\n', metric_name);
fprintf('Plot style        : %s\n', plot_style);
fprintf('Show mean         : %d\n', plot_show_mean_current);
fprintf('Show median       : %d\n', plot_show_median_current);
fprintf('Group labels      : %s\n', strjoin(group_display_names, ' | '));
fprintf('Output base tag   : %s\n', out_base);

%% ======================= FIND SESSION FOLDERS ==========================
session_dirs = findCatgtSessionDirs(root_dir);
if isempty(session_dirs)
    error('No catgt_* folders found under one level below root_dir: %s', root_dir);
end
fprintf('Found %d candidate catgt_* session folders.\n', numel(session_dirs));

%% ======================= READ ALL SESSIONS =============================
records = {};
skipped = struct('session_dir', {}, 'reason', {});
ref = struct();

for si = 1:numel(session_dirs)
    session_dir = session_dirs{si};
    fprintf('[%d/%d] Reading %s\n', si, numel(session_dirs), session_dir);

    try
        [rec, ref] = readOneSession(session_dir, data_content, model_mode, summary_type, ...
            DSL_filter, metric_name, runIdx, ref);

        records{end+1} = rec; %#ok<SAGROW>

    catch ME
        skipped(end+1).session_dir = session_dir; %#ok<SAGROW>
        skipped(end).reason = ME.message;

        warning('Skipping session: %s\nReason: %s', session_dir, ME.message);

        if print_full_error_report
            fprintf('\nFull error report for skipped session:\n');
            fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        end
    end
end

if isempty(records)
    fprintf('\nSkipped sessions:\n');
    for k = 1:numel(skipped)
        fprintf('  %s\n    %s\n', skipped(k).session_dir, skipped(k).reason);
    end
    error('No valid sessions were loaded.');
end

fprintf('Loaded %d valid sessions. Skipped %d sessions.\n', numel(records), numel(skipped));

numGroups = ref.value_size(1);
validateGroupNameCountLocal(group_names, numGroups, ...
    'the loaded latent-category results');

%% ======================= STACK VALUES ==================================
MultiSessionSummary = buildMultiSessionSummary(records, skipped, ref, root_dir, ...
    data_content, model_mode, summary_type, DSL_filter, metric_name, runIdx, ...
    out_base, group_names, group_display_names, group_file_tags, ...
    group_mapping_tag);

% Reorder display only. MultiSessionSummary.values and labels.categories
% retain the upstream order so saved numerical results remain compatible.
plot_category_indices = withinFirstCategoryOrderLocal( ...
    MultiSessionSummary.labels.categories);
plot_category_labels = MultiSessionSummary.labels.categories(plot_category_indices);
fprintf('Plot latent order : %s\n', strjoin(plot_category_labels, ' | '));

plot_config = struct();
plot_config.plot_style = plot_style;
plot_config.show_mean_by_style = plot_show_mean;
plot_config.show_median_by_style = plot_show_median;
plot_config.show_mean = plot_show_mean_current;
plot_config.show_median = plot_show_median_current;
plot_config.point_size = point_size;
plot_config.point_alpha = point_alpha;
plot_config.point_jitter_width = point_jitter_width;
plot_config.pooled_point_jitter_width = pooled_point_jitter_width;
plot_config.violin_alpha = violin_alpha;
plot_config.violin_width = violin_width;
plot_config.pooled_violin_width = pooled_violin_width;
plot_config.bar_alpha = bar_alpha;
plot_config.bar_width = bar_width;
plot_config.pooled_bar_width = pooled_bar_width;
plot_config.mean_marker_size = mean_marker_size;
plot_config.median_marker_size = median_marker_size;
plot_config.median_line_width = median_line_width;
plot_config.session_color_encoding = false;
plot_config.png_dpi = png_dpi;
plot_config.category_order_indices = plot_category_indices;
plot_config.category_order_labels = plot_category_labels;
plot_config.area_colors = group_colors;
plot_config.shared_gray = shared_gray;
plot_config.axis_gray = axis_gray;
plot_config.guide_gray = guide_gray;
plot_config.division_gray = division_gray;
plot_config.division_lines = latent_division_lines;
plot_config.within_category_area_spacing = within_category_area_spacing;
plot_config.between_category_spacing = between_category_spacing;
plot_config.pooled_figure_size_inches = pooled_figure_size_inches;
plot_config.condition_panel_size_inches = condition_panel_size_inches;
plot_config.axis_font_size = axis_font_size;
plot_config.category_font_size = category_font_size;

MultiSessionSummary.meta.plot_options = plot_config;
MultiSessionSummary.meta.plot_category_order_indices = plot_category_indices;
MultiSessionSummary.meta.plot_category_order_labels = plot_category_labels;
MultiSessionSummary.meta.created_by = 'latent_compare_figure_plot.m';

if save_mat
    mat_file = fullfile(root_dir, [out_base '.mat']);
    save(mat_file, 'MultiSessionSummary', '-v7.3');
    fprintf('Saved mat: %s\n', mat_file);
end

%% ======================= PLOT ==========================================
if make_plots
    if strcmp(summary_type, 'by_condition')
        fig_handle = plotByConditionSummary( ...
            MultiSessionSummary, fig_visible, plot_config);
    else
        fig_handle = plotPooledCategorySummary( ...
            MultiSessionSummary, fig_visible, plot_config);
    end

    if save_fig || save_svg || save_png
        if save_fig
            savefig(fig_handle, fullfile(root_dir, [out_base '.fig']));
        end
        if save_svg
            svg_file = fullfile(root_dir, [out_base '.svg']);
            try
                exportgraphics(fig_handle, svg_file, ...
                    'ContentType', 'vector', 'BackgroundColor', 'white');
            catch ME
                warning('latent_compare_figure_plot:SVGExportFallback', ...
                    'SVG exportgraphics failed (%s); trying painters SVG.', ...
                    ME.message);
                print(fig_handle, svg_file, '-dsvg', '-painters');
            end
        end
        if save_png
            exportgraphics(fig_handle, fullfile(root_dir, [out_base '.png']), ...
                'Resolution', png_dpi, 'BackgroundColor', 'white');
        end
        fprintf('Saved figures to: %s\n', root_dir);
    end

    if close_after_save
        close(fig_handle);
    end
end

fprintf('Done.\n');

%% =======================================================================
% Local functions
% ========================================================================

function validateUserSettings(model_mode, summary_type, DSL_filter, metric_name, plot_style)
    valid_model = {'all_condition_model', 'condition_specific_models'};
    valid_summary = {'by_condition', 'pooled_category'};
    valid_metric = {'percentLatents', 'percentSharedVariance'};
    valid_plot_style = {'bar_points', 'violin', 'points_median'};

    valid_csm_filter = {'all_latents', 'DSL_filtered'};
    valid_acm_filter = {'all_latents', 'DSL_filtered', 'stim_dir_DSL_filtered', ...
        'stim_name_stim_dir_DSL_filtered', 'condition_DSL_filtered'};

    assertStringOption(model_mode, valid_model, 'model_mode');
    assertStringOption(summary_type, valid_summary, 'summary_type');
    assertStringOption(metric_name, valid_metric, 'metric_name');
    assertStringOption(plot_style, valid_plot_style, 'plot_style');

    if strcmp(model_mode, 'condition_specific_models')
        assertStringOption(DSL_filter, valid_csm_filter, 'DSL_filter');

        if ~strcmp(summary_type, 'by_condition')
            error('condition_specific_models supports only summary_type = ''by_condition''.');
        end

    else
        assertStringOption(DSL_filter, valid_acm_filter, 'DSL_filter');
    end

    if strcmp(model_mode, 'all_condition_model') && strcmp(summary_type, 'by_condition') && ...
            ~strcmp(metric_name, 'percentSharedVariance')
        error('all_condition_model + by_condition supports only metric_name = ''percentSharedVariance''.');
    end
end

function assertStringOption(value, validOptions, varName)
    if ~ischar(value) && ~isstring(value)
        error('%s must be a char or string.', varName);
    end

    value = char(value);

    if ~any(strcmp(value, validOptions))
        error('%s = ''%s'' is invalid. Valid options are: %s', ...
            varName, value, strjoin(validOptions, ', '));
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
        valid = (islogical(value) || isnumeric(value)) && ...
            isscalar(value) && isfinite(double(value)) && ...
            ismember(double(value), [0, 1]);

        if ~valid
            error('%s.%s must be a logical scalar.', ...
                variable_name, field_name);
        end
    end
end

function tag = makeModelTag(model_mode)
    switch char(model_mode)
        case 'condition_specific_models'
            tag = 'condition_specific_M';
        case 'all_condition_model'
            tag = 'all_condition_M';
        otherwise
            error('Unknown model_mode: %s', model_mode);
    end
end

function tag = makeSummaryTypeTag(summary_type)
    switch char(summary_type)
        case 'by_condition'
            tag = 'byCond';
        case 'pooled_category'
            tag = 'pooled';
        otherwise
            error('Unknown summary_type: %s', summary_type);
    end
end

function tag = makeFilterTag(DSL_filter)
    switch char(DSL_filter)
        case 'all_latents'
            tag = 'all';
        case 'DSL_filtered'
            tag = 'dsl';
        case 'stim_dir_DSL_filtered'
            tag = 'dslStimDir';
        case 'stim_name_stim_dir_DSL_filtered'
            tag = 'dslStimNameDir';
        case 'condition_DSL_filtered'
            tag = 'dslCond';
        otherwise
            error('Unknown DSL_filter: %s', DSL_filter);
    end
end

function tag = makeMetricTag(metric_name)
    switch char(metric_name)
        case 'percentLatents'
            tag = 'pctLat';
        case 'percentSharedVariance'
            tag = 'pctSV';
        otherwise
            error('Unknown metric_name: %s', metric_name);
    end
end

function session_dirs = findCatgtSessionDirs(root_dir)
    listing = dir(fullfile(root_dir, '*', 'catgt_*'));
    is_folder = [listing.isdir];
    listing = listing(is_folder);

    session_dirs = cell(1, numel(listing));
    for k = 1:numel(listing)
        session_dirs{k} = fullfile(listing(k).folder, listing(k).name);
    end

    session_dirs = sort(session_dirs);
end

function [rec, ref] = readOneSession(session_dir, data_content, model_mode, summary_type, ...
        DSL_filter, metric_name, runIdx, ref)

    mat_file = getMatFileForSession(session_dir, data_content, model_mode, runIdx);

    if ~exist(mat_file, 'file')
        error('Required mat file not found: %s', mat_file);
    end

    switch model_mode
        case 'condition_specific_models'
            S = load(mat_file, 'SummaryCategory');

            if ~isfield(S, 'SummaryCategory') || isempty(S.SummaryCategory)
                error('SummaryCategory not found or empty in %s.', mat_file);
            end

            [values, labels, condition_labels, stim_dir_titles] = extractConditionSpecificByCondition( ...
                S.SummaryCategory, DSL_filter, metric_name);

            source_name = 'SummaryCategory';

        case 'all_condition_model'
            if strcmp(summary_type, 'by_condition')
                S = load(mat_file, 'CondPosteriorVarExp');

                if ~isfield(S, 'CondPosteriorVarExp') || isempty(S.CondPosteriorVarExp)
                    error('CondPosteriorVarExp not found or empty in %s.', mat_file);
                end

                [values, labels, condition_labels, stim_dir_titles] = extractAllConditionByCondition( ...
                    S.CondPosteriorVarExp, DSL_filter, metric_name);

                source_name = 'CondPosteriorVarExp';

            else
                S = load(mat_file, 'Stats', 'Stats_bystimdir', 'Stats_bystimnamedir', 'Stats_bycondition');

                [values, labels] = extractAllConditionPooledCategory(S, DSL_filter, metric_name);

                condition_labels = {};
                stim_dir_titles = {};
                source_name = getPooledSourceName(DSL_filter);
            end

        otherwise
            error('Unknown model_mode: %s', model_mode);
    end

    ref = updateAndCheckReference(ref, values, labels, condition_labels, stim_dir_titles, session_dir);

    rec = struct();
    rec.session_dir = session_dir;
    rec.session_name = getSessionName(session_dir);
    rec.mat_file = mat_file;
    rec.source_name = source_name;
    rec.stim_dir_titles = stim_dir_titles;
    rec.values = values;
end

function mat_file = getMatFileForSession(session_dir, data_content, model_mode, runIdx)
    switch char(model_mode)
        case 'condition_specific_models'
            mat_file = fullfile(session_dir, ...
                sprintf('%s_sum_all_conditions_DSL_and_latent_category_stats.mat', data_content));

        case 'all_condition_model'
            mat_file = fullfile(session_dir, sprintf('FA_Dlag_%s', data_content), ...
                'mat_results', sprintf('run%03d', runIdx), 'DSL_and_latent_category_stats.mat');

        otherwise
            error('Unknown model_mode: %s', model_mode);
    end
end

function [values, labels, condition_labels, stim_dir_titles] = extractConditionSpecificByCondition( ...
        SummaryCategory, DSL_filter, metric_name)

    data_field = mapConditionSpecificFilterField(DSL_filter);

    labels = getLabelsFromSummaryCategory(SummaryCategory);
    condition_labels = getConditionLabelsFromSummaryCategory(SummaryCategory);
    stim_dir_titles = getStimDirTitlesFromSummaryCategory(SummaryCategory);

    if ~isfield(SummaryCategory, 'group') || isempty(SummaryCategory.group)
        error('SummaryCategory.group is missing or empty.');
    end

    if ~isfield(SummaryCategory.group(1), data_field)
        error('SummaryCategory.group(1).%s is missing.', data_field);
    end

    if ~isfield(SummaryCategory.group(1).(data_field), 'stim_dir')
        error('SummaryCategory.group(1).%s.stim_dir is missing.', data_field);
    end

    numGroups = numel(SummaryCategory.group);
    numStimDir = numel(SummaryCategory.group(1).(data_field).stim_dir);
    numCond = numel(condition_labels);
    numCat = numel(labels);

    values = nan(numGroups, numStimDir, numCond, numCat);

    for g = 1:numGroups
        if ~isfield(SummaryCategory.group(g), data_field)
            error('SummaryCategory.group(%d).%s is missing.', g, data_field);
        end

        if ~isfield(SummaryCategory.group(g).(data_field), 'stim_dir')
            error('SummaryCategory.group(%d).%s.stim_dir is missing.', g, data_field);
        end

        if numel(SummaryCategory.group(g).(data_field).stim_dir) ~= numStimDir
            error('Number of stim_dir entries differs across groups in SummaryCategory.');
        end

        for d = 1:numStimDir
            Sd = SummaryCategory.group(g).(data_field).stim_dir(d);

            if ~isfield(Sd, metric_name)
                error('Field %s missing in SummaryCategory.group(%d).%s.stim_dir(%d).', ...
                    metric_name, g, data_field, d);
            end

            V = Sd.(metric_name);
            assertMatrixSize(V, [numCond, numCat], ...
                sprintf('SummaryCategory group %d stim_dir %d', g, d));

            values(g, d, :, :) = V;
        end
    end
end

function field_name = mapConditionSpecificFilterField(DSL_filter)
    switch char(DSL_filter)
        case 'all_latents'
            field_name = 'all';
        case 'DSL_filtered'
            field_name = 'filtered';
        otherwise
            error('Invalid DSL_filter for condition_specific_models: %s', DSL_filter);
    end
end

function [values, labels, condition_labels, stim_dir_titles] = extractAllConditionByCondition( ...
        CondPosteriorVarExp, DSL_filter, metric_name)

    if ~strcmp(metric_name, 'percentSharedVariance')
        error('CondPosteriorVarExp by-condition summary supports only percentSharedVariance.');
    end

    mode_name = mapAllConditionPosteriorModeName(DSL_filter);

    labels = getLabelsFromCondPosteriorVarExp(CondPosteriorVarExp);
    condition_labels = getConditionLabelsFromCondPosteriorVarExp(CondPosteriorVarExp);
    stim_dir_titles = getStimDirTitlesFromCondPosteriorVarExp(CondPosteriorVarExp);

    if ~isfield(CondPosteriorVarExp, 'group') || isempty(CondPosteriorVarExp.group)
        error('CondPosteriorVarExp.group is missing or empty.');
    end

    if ~isfield(CondPosteriorVarExp.group(1), 'category') || ...
            ~isfield(CondPosteriorVarExp.group(1).category, mode_name) || ...
            ~isfield(CondPosteriorVarExp.group(1).category.(mode_name), 'stim_dir')
        error('CondPosteriorVarExp.group(1).category.%s.stim_dir is missing.', mode_name);
    end

    numGroups = numel(CondPosteriorVarExp.group);
    numStimDir = numel(CondPosteriorVarExp.group(1).category.(mode_name).stim_dir);
    numCond = numel(condition_labels);
    numCat = numel(labels);

    values = nan(numGroups, numStimDir, numCond, numCat);

    for g = 1:numGroups
        if ~isfield(CondPosteriorVarExp.group(g), 'category') || ...
                ~isfield(CondPosteriorVarExp.group(g).category, mode_name)
            error('CondPosteriorVarExp.group(%d).category.%s is missing.', g, mode_name);
        end

        if ~isfield(CondPosteriorVarExp.group(g).category.(mode_name), 'stim_dir')
            error('CondPosteriorVarExp.group(%d).category.%s.stim_dir is missing.', g, mode_name);
        end

        if numel(CondPosteriorVarExp.group(g).category.(mode_name).stim_dir) ~= numStimDir
            error('Number of stim_dir entries differs across groups in CondPosteriorVarExp.');
        end

        for d = 1:numStimDir
            Sd = CondPosteriorVarExp.group(g).category.(mode_name).stim_dir(d);

            if ~isfield(Sd, metric_name)
                error('Field %s missing in CondPosteriorVarExp.group(%d).category.%s.stim_dir(%d).', ...
                    metric_name, g, mode_name, d);
            end

            V = Sd.(metric_name);
            assertMatrixSize(V, [numCond, numCat], ...
                sprintf('CondPosteriorVarExp group %d stim_dir %d', g, d));

            values(g, d, :, :) = V;
        end
    end
end

function mode_name = mapAllConditionPosteriorModeName(DSL_filter)
    switch char(DSL_filter)
        case 'all_latents'
            mode_name = 'all';
        case 'DSL_filtered'
            mode_name = 'filtered_DSL_alltrials';
        case 'stim_dir_DSL_filtered'
            mode_name = 'filtered_DSL_bystimdir';
        case 'stim_name_stim_dir_DSL_filtered'
            mode_name = 'filtered_DSL_bystimnamedir';
        case 'condition_DSL_filtered'
            mode_name = 'filtered_DSL_bycondition';
        otherwise
            error('Invalid DSL_filter for all_condition_model: %s', DSL_filter);
    end
end

function [values, labels] = extractAllConditionPooledCategory(S, DSL_filter, metric_name)
    [stats_var_name, data_field] = mapAllConditionPooledStatsField(DSL_filter);

    if ~isfield(S, stats_var_name) || isempty(S.(stats_var_name))
        error('%s not found or empty.', stats_var_name);
    end

    StatsUse = S.(stats_var_name);

    if ~isfield(StatsUse, 'labels') || isempty(StatsUse.labels)
        error('%s.labels is missing or empty.', stats_var_name);
    end

    labels = cellstr(StatsUse.labels);

    if ~isfield(StatsUse, 'group') || isempty(StatsUse.group)
        error('%s.group is missing or empty.', stats_var_name);
    end

    numGroups = numel(StatsUse.group);
    numCat = numel(labels);

    values = nan(numGroups, numCat);

    for g = 1:numGroups
        if ~isfield(StatsUse.group(g), data_field)
            error('%s.group(%d).%s is missing.', stats_var_name, g, data_field);
        end

        Sd = StatsUse.group(g).(data_field);

        if ~isfield(Sd, metric_name)
            error('Field %s missing in %s.group(%d).%s.', ...
                metric_name, stats_var_name, g, data_field);
        end

        V = reshape(Sd.(metric_name), 1, []);

        if numel(V) ~= numCat
            error('%s.group(%d).%s.%s has %d categories; expected %d.', ...
                stats_var_name, g, data_field, metric_name, numel(V), numCat);
        end

        values(g, :) = V;
    end
end

function [stats_var_name, data_field] = mapAllConditionPooledStatsField(DSL_filter)
    switch char(DSL_filter)
        case 'all_latents'
            stats_var_name = 'Stats';
            data_field = 'all';
        case 'DSL_filtered'
            stats_var_name = 'Stats';
            data_field = 'filtered';
        case 'stim_dir_DSL_filtered'
            stats_var_name = 'Stats_bystimdir';
            data_field = 'filtered';
        case 'stim_name_stim_dir_DSL_filtered'
            stats_var_name = 'Stats_bystimnamedir';
            data_field = 'filtered';
        case 'condition_DSL_filtered'
            stats_var_name = 'Stats_bycondition';
            data_field = 'filtered';
        otherwise
            error('Invalid DSL_filter for all_condition_model pooled_category: %s', DSL_filter);
    end
end

function source_name = getPooledSourceName(DSL_filter)
    switch char(DSL_filter)
        case {'all_latents', 'DSL_filtered'}
            source_name = 'Stats';
        case 'stim_dir_DSL_filtered'
            source_name = 'Stats_bystimdir';
        case 'stim_name_stim_dir_DSL_filtered'
            source_name = 'Stats_bystimnamedir';
        case 'condition_DSL_filtered'
            source_name = 'Stats_bycondition';
        otherwise
            source_name = '';
    end
end

function ref = updateAndCheckReference(ref, values, labels, condition_labels, stim_dir_titles, session_dir)
    if isempty(fieldnames(ref))
        ref.value_size = size(values);
        ref.labels = labels;
        ref.condition_labels = condition_labels;
        ref.num_stim_dir = getNumStimDirFromValues(values);
        ref.stim_dir_titles_first_session = stim_dir_titles;
        return;
    end

    if ~isequal(size(values), ref.value_size)
        error('Value size mismatch in %s. Got [%s], expected [%s].', ...
            session_dir, num2str(size(values)), num2str(ref.value_size));
    end

    if ~isequal(cellstr(labels), cellstr(ref.labels))
        error('Category labels mismatch in %s.', session_dir);
    end

    if ~isempty(ref.condition_labels) || ~isempty(condition_labels)
        if ~isequal(cellstr(condition_labels), cellstr(ref.condition_labels))
            error('Condition labels mismatch in %s.', session_dir);
        end
    end

    % Do NOT compare stim-dir titles or actual direction values across sessions.
    % Different sessions can use different physical directions, so by-condition
    % plotting pools stim-dir entries within each condition/category.
end

function n = getNumStimDirFromValues(values)
    sz = size(values);
    if numel(sz) >= 4
        n = sz(2);
    else
        n = 0;
    end
end

function labels = getLabelsFromSummaryCategory(SummaryCategory)
    if isfield(SummaryCategory, 'labels') && ~isempty(SummaryCategory.labels)
        labels = cellstr(SummaryCategory.labels);
    else
        error('SummaryCategory.labels is missing or empty.');
    end
end

function condition_labels = getConditionLabelsFromSummaryCategory(SummaryCategory)
    if isfield(SummaryCategory, 'meta') && isfield(SummaryCategory.meta, 'panelConditionShortLabels')
        condition_labels = cellstr(SummaryCategory.meta.panelConditionShortLabels);
    else
        condition_labels = defaultConditionShortLabels();
    end
end

function stim_dir_titles = getStimDirTitlesFromSummaryCategory(SummaryCategory)
    if isfield(SummaryCategory, 'meta') && isfield(SummaryCategory.meta, 'stimDirPanelTitles')
        stim_dir_titles = cellstr(SummaryCategory.meta.stimDirPanelTitles);
    elseif isfield(SummaryCategory, 'meta') && isfield(SummaryCategory.meta, 'stimDirLabels')
        stim_dir_titles = cellstr(SummaryCategory.meta.stimDirLabels);
    else
        stim_dir_titles = {};
    end
end

function labels = getLabelsFromCondPosteriorVarExp(CondSV)
    if isfield(CondSV, 'meta') && isfield(CondSV.meta, 'categoryLabels')
        labels = cellstr(CondSV.meta.categoryLabels);
    else
        error('CondPosteriorVarExp.meta.categoryLabels is missing.');
    end
end

function condition_labels = getConditionLabelsFromCondPosteriorVarExp(CondSV)
    if isfield(CondSV, 'meta') && isfield(CondSV.meta, 'conditionShortLabels')
        condition_labels = cellstr(CondSV.meta.conditionShortLabels);
    else
        condition_labels = defaultConditionShortLabels();
    end
end

function stim_dir_titles = getStimDirTitlesFromCondPosteriorVarExp(CondSV)
    if isfield(CondSV, 'meta') && isfield(CondSV.meta, 'stimDirLabels') && ...
            isfield(CondSV.meta, 'stimDirValues')

        labs = cellstr(CondSV.meta.stimDirLabels);
        vals = CondSV.meta.stimDirValues;

        stim_dir_titles = cell(1, numel(labs));
        for k = 1:numel(labs)
            stim_dir_titles{k} = sprintf('%s = %s', labs{k}, formatNumberForLabel(vals(k)));
        end

    else
        stim_dir_titles = {};
    end
end

function labels = defaultConditionShortLabels()
    labels = {'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
              'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};
end

function assertMatrixSize(V, expectedSize, contextStr)
    if ~isequal(size(V), expectedSize)
        error('%s value matrix has size [%s], expected [%s].', ...
            contextStr, num2str(size(V)), num2str(expectedSize));
    end
end

function name = getSessionName(session_dir)
    [parent_dir, catgt_name] = fileparts(session_dir);
    [~, parent_name] = fileparts(parent_dir);
    name = sprintf('%s/%s', parent_name, catgt_name);
end

function MultiSessionSummary = buildMultiSessionSummary(records, skipped, ref, root_dir, ...
        data_content, model_mode, summary_type, DSL_filter, metric_name, runIdx, ...
        out_base, group_names, group_display_names, group_file_tags, ...
        group_mapping_tag)

    numSessions = numel(records);
    firstValues = records{1}.values;
    valueSize = size(firstValues);

    MultiSessionSummary = struct();

    MultiSessionSummary.meta.root_dir = root_dir;
    MultiSessionSummary.meta.data_content = data_content;
    MultiSessionSummary.meta.model_mode = model_mode;
    MultiSessionSummary.meta.summary_type = summary_type;
    MultiSessionSummary.meta.DSL_filter = DSL_filter;
    MultiSessionSummary.meta.metric_name = metric_name;
    MultiSessionSummary.meta.runIdx = runIdx;
    MultiSessionSummary.meta.output_base = out_base;
    MultiSessionSummary.meta.group_names = group_names;
    MultiSessionSummary.meta.group_display_names = group_display_names;
    MultiSessionSummary.meta.group_file_tags = group_file_tags;
    MultiSessionSummary.meta.group_mapping_tag = group_mapping_tag;
    MultiSessionSummary.meta.group_label_source = ...
        'manual group_names parameter; display/file labels only';
    MultiSessionSummary.meta.created_by = 'sum_sessions_latent_compare.m';
    MultiSessionSummary.meta.created_on = datestr(now);

    MultiSessionSummary.labels.categories = ref.labels;
    MultiSessionSummary.labels.conditions = ref.condition_labels;
    MultiSessionSummary.labels.groups = group_display_names;

    included = records;
    for s = 1:numel(included)
        if isfield(included{s}, 'values')
            included{s} = rmfield(included{s}, 'values');
        end
    end

    MultiSessionSummary.sessions.included = included;
    MultiSessionSummary.sessions.skipped = skipped;

    if strcmp(summary_type, 'by_condition')
        if numel(valueSize) ~= 4
            error('For by_condition, expected value size [group, stim_dir, condition, category], got [%s].', ...
                num2str(valueSize));
        end

        numGroups = valueSize(1);
        numStimDir = valueSize(2);
        numCond = valueSize(3);
        numCat = valueSize(4);

        originalValues = nan([numSessions, valueSize]);
        pooledValues = nan(numSessions * numStimDir, numGroups, numCond, numCat);

        observation_info = struct('observation_index', {}, 'session_index', {}, ...
            'stim_dir_index', {}, 'session_name', {}, 'session_dir', {}, 'mat_file', {});

        obs = 0;
        for s = 1:numSessions
            originalValues(s, :, :, :, :) = records{s}.values;

            for d = 1:numStimDir
                obs = obs + 1;

                tmp = records{s}.values(:, d, :, :);
                tmp = reshape(tmp, [numGroups, numCond, numCat]);

                pooledValues(obs, :, :, :) = tmp;

                observation_info(obs).observation_index = obs;
                observation_info(obs).session_index = s;
                observation_info(obs).stim_dir_index = d;
                observation_info(obs).session_name = records{s}.session_name;
                observation_info(obs).session_dir = records{s}.session_dir;
                observation_info(obs).mat_file = records{s}.mat_file;
            end
        end

        MultiSessionSummary.values = pooledValues;
        MultiSessionSummary.values_by_session_stimdir = originalValues;
        MultiSessionSummary.observation_info = observation_info;

        MultiSessionSummary.meta.num_sessions = numSessions;
        MultiSessionSummary.meta.num_stim_dir_per_session = numStimDir;
        MultiSessionSummary.meta.num_observations = size(pooledValues, 1);
        MultiSessionSummary.meta.by_condition_stim_dir_handling = ...
            'stim_dir entries pooled within condition/category; each session contributes one point per stim_dir';

        MultiSessionSummary.dimension_names = {'session_stim_dir_observation', 'group', 'condition', 'category'};
        MultiSessionSummary.dimension_names_values_by_session_stimdir = ...
            {'session', 'group', 'stim_dir', 'condition', 'category'};

    else
        if numel(valueSize) ~= 2
            error('For pooled_category, expected value size [group, category], got [%s].', ...
                num2str(valueSize));
        end

        allValues = nan([numSessions, valueSize]);
        for s = 1:numSessions
            allValues(s, :, :) = records{s}.values;
        end

        MultiSessionSummary.values = allValues;
        MultiSessionSummary.meta.num_sessions = numSessions;
        MultiSessionSummary.dimension_names = {'session', 'group', 'category'};
    end
end

function fig = plotByConditionSummary(M, fig_visible, config)
    % One labeled panel per condition. All panels use the same y scale.
    % Values are observation (session x stim_dir) x group x condition x class.
    values = M.values(:,:,:,config.category_order_indices);
    numGroups = size(values, 2);
    numCond = size(values, 3);
    numCat = size(values, 4);
    condition_labels = M.labels.conditions;
    if isempty(condition_labels)
        condition_labels = defaultConditionShortLabels();
    end

    nCols = min(2, numCond);
    nRows = ceil(numCond / nCols);
    panelSize = config.condition_panel_size_inches;
    fig = createPosterFigureLocal(fig_visible, ...
        [nCols * panelSize(1), nRows * panelSize(2)]);
    [x, separators] = buildCategoryPositionsLocal( ...
        numGroups, numCat, config.within_category_area_spacing, ...
        config.between_category_spacing);

    yMax = computeFlexibleYMax(values(:));
    for p = 1:numCond
        row = ceil(p / nCols);
        col = mod(p - 1, nCols) + 1;

        % Explicit axes positions leave room for category tick labels.
        panel_band = 0.88 / nRows;
        left = (col - 1) / nCols + 0.15 / nCols;
        width = 0.78 / nCols;
        bottom = 0.075 + (nRows - row) * panel_band + 0.20 * panel_band;
        height = 0.63 * panel_band;
        ax = axes('Parent', fig, 'Position', [left, bottom, width, height]);
        hold(ax, 'on');

        for g = 1:numGroups
            for c = 1:numCat
                y = reshape(values(:, g, p, c), [], 1);
                jitter_seed = 100000 * g + 1000 * c + p;
                drawSummaryWithPoints(ax, x(g,c), y, ...
                    config.plot_style, config.violin_width, ...
                    config.bar_width, config.area_colors(g,:), ...
                    config.point_size, config.point_alpha, ...
                    config.violin_alpha, config.bar_alpha, ...
                    config.point_jitter_width, config.show_mean, ...
                    config.show_median, config.mean_marker_size, ...
                    config.median_marker_size, config.median_line_width, ...
                    jitter_seed, config.shared_gray);
            end
        end

        formatPosterAxesLocal(ax, x, separators, yMax, ...
            config.category_order_labels, config);
        if p == 1
            first_ax = ax;
        end
        if col == 1
            ylabel(ax, metricLabel(M.meta.metric_name), ...
                'FontName', 'Arial', 'FontSize', config.axis_font_size, ...
                'Color', config.axis_gray);
        end
        text(ax, 0.025, 1.035, condition_labels{p}, ...
            'Units', 'normalized', 'FontName', 'Arial', ...
            'FontSize', config.axis_font_size, 'FontWeight', 'bold', ...
            'Color', config.axis_gray, 'VerticalAlignment', 'bottom', ...
            'Interpreter', 'none', 'Clipping', 'off');
    end
    addAreaLegendLocal(first_ax, M.meta.group_names, ...
        config.area_colors, config.axis_font_size, true, config.axis_gray);
end

function fig = plotPooledCategorySummary(M, fig_visible, config)
    % Values are session x group x class. No session-level averaging.
    values = M.values(:,:,config.category_order_indices);
    numGroups = size(values, 2);
    numCat = size(values, 3);
    fig = createPosterFigureLocal( ...
        fig_visible, config.pooled_figure_size_inches);
    ax = axes('Parent', fig, 'Position', [0.12, 0.20, 0.84, 0.69]);
    hold(ax, 'on');

    [x, separators] = buildCategoryPositionsLocal( ...
        numGroups, numCat, config.within_category_area_spacing, ...
        config.between_category_spacing);
    yMax = computeFlexibleYMax(values(:));

    for g = 1:numGroups
        for c = 1:numCat
            y = reshape(values(:, g, c), [], 1);
            jitter_seed = 100000 * g + 100 * c;
            drawSummaryWithPoints(ax, x(g,c), y, ...
                config.plot_style, config.pooled_violin_width, ...
                config.pooled_bar_width, config.area_colors(g,:), ...
                config.point_size, config.point_alpha, ...
                config.violin_alpha, config.bar_alpha, ...
                config.pooled_point_jitter_width, config.show_mean, ...
                config.show_median, config.mean_marker_size, ...
                config.median_marker_size, config.median_line_width, ...
                jitter_seed, config.shared_gray);
        end
    end

    formatPosterAxesLocal(ax, x, separators, yMax, ...
        config.category_order_labels, config);
    ylabel(ax, metricLabel(M.meta.metric_name), ...
        'FontName', 'Arial', 'FontSize', config.axis_font_size, ...
        'Color', config.axis_gray);
    addAreaLegendLocal(ax, M.meta.group_names, ...
        config.area_colors, config.axis_font_size, false, config.axis_gray);
end

function fig = createPosterFigureLocal(visibility, sizeInches)
    fig = figure('Visible', visibility, 'Color', 'w', ...
        'Units', 'inches', 'Position', [0.7 0.7 sizeInches], ...
        'PaperPositionMode', 'auto', 'InvertHardcopy', 'off');
end

function [positions, separators] = buildCategoryPositionsLocal( ...
        numGroups, numCat, withinSpacing, betweenSpacing)
    positions = zeros(numGroups, numCat);
    for c = 1:numCat
        positions(:,c) = 1 + (c - 1) * ...
            ((numGroups - 1) * withinSpacing + betweenSpacing) + ...
            (0:numGroups-1)' * withinSpacing;
    end
    separators = (positions(end,1:end-1) + positions(1,2:end)) / 2;
end

function formatPosterAxesLocal(ax, positions, separators, yMax, ...
        category_labels, config)
    margin = max(0.55, config.within_category_area_spacing * 0.57);
    allX = reshape(positions, 1, []);
    categoryCenters = mean(positions, 1);
    set(ax, 'FontName', 'Arial', 'FontUnits', 'points', ...
        'FontSize', config.category_font_size, ...
        'TickDir', 'out', 'TickLength', [0.008, 0.008], ...
        'LineWidth', 0.9, 'Box', 'off', 'XGrid', 'off', 'YGrid', 'off', ...
        'XColor', config.axis_gray, 'YColor', config.axis_gray, ...
        'XTick', categoryCenters, 'XTickLabel', category_labels, ...
        'TickLabelInterpreter', 'none');
    xlim(ax, [min(allX) - margin, max(allX) + margin]);
    ylim(ax, [0 yMax]);

    % Category boundaries and optional reference lines stay neutral.
    for k = 1:numel(separators)
        line(ax, [separators(k) separators(k)], [0 yMax], ...
            'Color', config.guide_gray, 'LineWidth', 0.7, ...
            'HandleVisibility', 'off');
    end
    for reference_y = config.division_lines(:)'
        if reference_y >= 0 && reference_y <= yMax
            line(ax, xlim(ax), [reference_y reference_y], ...
                'Color', config.division_gray, 'LineStyle', '--', ...
                'LineWidth', 1, 'HandleVisibility', 'off');
        end
    end

end

function addAreaLegendLocal(ax, group_names, colors, fontSize, manyPanels, axisGray)
    % A single legend belongs to the whole figure, even in by_condition mode.
    % Repeat area names share one legend entry and the same plotted color.
    uniqueNames = {};
    firstIndices = [];
    for g = 1:numel(group_names)
        if ~any(strcmp(uniqueNames, group_names{g}))
            uniqueNames{end+1} = group_names{g}; %#ok<AGROW>
            firstIndices(end+1) = g; %#ok<AGROW>
        end
    end
    handles = gobjects(1, numel(firstIndices));
    for k = 1:numel(firstIndices)
        g = firstIndices(k);
        handles(k) = plot(ax, nan, nan, 'o', ...
            'MarkerSize', 7, 'MarkerFaceColor', colors(g,:), ...
            'MarkerEdgeColor', 'none', 'LineStyle', 'none');
    end

    oldPosition = ax.Position;
    lgd = legend(ax, handles, uniqueNames, ...
        'Box', 'off', 'Orientation', 'horizontal', ...
        'FontName', 'Arial', 'FontSize', fontSize, 'TextColor', axisGray, ...
        'Interpreter', 'none', 'AutoUpdate', 'off');
    lgd.NumColumns = numel(uniqueNames);
    lgd.Units = 'normalized';
    figure_position = get(ancestor(ax, 'figure'), 'Position'); % inches
    text_height = 1.5 * fontSize / (72 * figure_position(4));
    if manyPanels
        legend_height = max(0.022, text_height);
        lgd.Position = [0.73, 0.99 - legend_height, 0.24, legend_height];
    else
        legend_height = max(0.048, text_height);
        lgd.Position = [0.73, 0.98 - legend_height, 0.24, legend_height];
    end
    ax.Position = oldPosition;
end

function colors = resolveAreaColorsLocal(group_names, palette)
    % Compare names explicitly so a repeated area has exactly the same color.
    uniqueNames = {};
    colors = zeros(numel(group_names), 3);
    for g = 1:numel(group_names)
        u = find(strcmp(uniqueNames, group_names{g}), 1);
        if isempty(u)
            uniqueNames{end+1} = group_names{g}; %#ok<AGROW>
            u = numel(uniqueNames);
        end
        if u > size(palette, 1)
            error(['area_colors has %d rows, but group_names has %d ' ...
                   'unique area names. Add one color per area.'], ...
                size(palette, 1), u);
        end
        colors(g,:) = palette(u,:);
    end
end

function indices = withinFirstCategoryOrderLocal(labels)
    % Resolve each of the five DLAG latent categories exactly once.
    % Accept both full names and the common FF / FB abbreviations.
    names = cellstr(labels);
    if numel(names) ~= 5
        error('Expected five latent categories; found %d.', numel(names));
    end
    names = cellfun(@(s) regexprep(lower(strtrim(s)), '[^a-z]', ''), ...
        names, 'UniformOutput', false);
    aliases = {{'within'}, {'across'}, {'feedforward', 'ff'}, ...
               {'feedback', 'fb'}, {'ambiguous'}};
    indices = zeros(1, numel(aliases));
    for k = 1:numel(aliases)
        matches = find(ismember(names, aliases{k}));
        if numel(matches) ~= 1
            error('Could not uniquely identify latent category %d among: %s', ...
                k, strjoin(cellstr(labels), ', '));
        end
        indices(k) = matches;
    end
end

function drawSummaryWithPoints(ax, x0, y, plot_style, violin_width, ...
        bar_width, color, point_size, point_alpha, violin_alpha, ...
        bar_alpha, point_jitter_width, show_mean, show_median, ...
        mean_marker_size, median_marker_size, median_line_width, jitter_seed, sharedGray)

    y = double(y(:));
    y = y(isfinite(y));

    if isempty(y)
        return;
    end

    meanVal = mean(y);
    medianVal = median(y);

    switch plot_style
        case 'bar_points'
            if show_mean
                hb = bar(ax, x0, meanVal, bar_width, ...
                    'FaceColor', color, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');

                try
                    hb.FaceAlpha = bar_alpha;
                catch
                    % FaceAlpha is unavailable for bars in older releases.
                end
            end

            point_edge_color = sharedGray;

        case 'violin'
            if numel(y) >= 2 && range(y) > eps
                [dens, yi] = estimateDensity(y);

                if ~isempty(dens) && max(dens) > 0
                    dens = dens ./ max(dens) .* violin_width;

                    patch(ax, ...
                        [x0 - dens, fliplr(x0 + dens)], ...
                        [yi, fliplr(yi)], color, ...
                        'FaceAlpha', violin_alpha, ...
                        'EdgeColor', color, ...
                        'LineWidth', 0.9, ...
                        'HandleVisibility', 'off');
                end
            end

            point_edge_color = 'none';

        case 'points_median'
            % No bar or density object.
            point_edge_color = 'none';

        otherwise
            error('Unknown plot_style: %s', plot_style);
    end

    jitter = deterministicJitterLocal( ...
        numel(y), point_jitter_width, jitter_seed);

    scatter(ax, x0 + jitter, y, point_size, ...
        'MarkerFaceColor', color, ...
        'MarkerEdgeColor', [0.6 0.6 0.6], ...
        'MarkerFaceAlpha', point_alpha, ...
        'MarkerEdgeAlpha', point_alpha, ...
        'HandleVisibility', 'off');

    if show_mean && ~strcmp(plot_style, 'bar_points')
        plot(ax, x0, meanVal, 'd', ...
            'MarkerSize', mean_marker_size, ...
            'Color', sharedGray, ...
            'MarkerFaceColor', sharedGray, ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    if show_median
        if strcmp(plot_style, 'bar_points')
            plot(ax, x0, medianVal, 's', ...
                'MarkerSize', median_marker_size, ...
                'Color', color, ...
                'MarkerFaceColor', sharedGray, ...
                'LineWidth', 0.8, ...
                'HandleVisibility', 'off');
        else
            median_half_width = violin_width .* 0.72;
            plot(ax, ...
                [x0 - median_half_width, x0 + median_half_width], ...
                [medianVal, medianVal], '-', ...
                'Color', color, ...
                'LineWidth', median_line_width, ...
                'HandleVisibility', 'off');
        end
    end
end

function jitter = deterministicJitterLocal(n, half_width, seed)

    if n <= 1 || half_width <= 0
        jitter = zeros(n, 1);
        return;
    end

    stream = RandStream('mt19937ar', 'Seed', seed);
    jitter = (2 .* rand(stream, n, 1) - 1) .* half_width;
end

function [dens, yi] = estimateDensity(y)
    y = y(:)';

    if numel(y) < 2 || range(y) <= eps
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

    % Fallback without Statistics Toolbox.
    nBins = min(20, max(6, round(sqrt(numel(y)) * 2)));
    edges = linspace(min(y), max(y), nBins + 1);
    counts = histcounts(y, edges);
    centers = (edges(1:end-1) + edges(2:end)) / 2;

    if numel(counts) >= 3
        kernel = [1 2 3 2 1];
        kernel = kernel / sum(kernel);
        counts = conv(counts, kernel, 'same');
    end

    yi = linspace(min(y), max(y), 80);
    dens = interp1(centers, counts, yi, 'linear', 0);
end

function yMax = computeFlexibleYMax(values)
    values = values(isfinite(values));

    if isempty(values)
        yMax = 1;
        return;
    end

    maxVal = max(values);

    if maxVal <= 0
        yMax = 1;
    elseif maxVal <= 0.5
        yMax = 0.6;
    elseif maxVal <= 1
        yMax = 1.2;
    elseif maxVal <= 2
        yMax = 2.4;
    elseif maxVal <= 5
        yMax = 6;
    elseif maxVal <= 10
        yMax = 12;
    elseif maxVal <= 20
        yMax = 24;
    elseif maxVal <= 40
        yMax = 45;
    elseif maxVal <= 60
        yMax = 66;
    elseif maxVal <= 80
        yMax = 88;
    elseif maxVal <= 100
        yMax = 105;
    else
        yMax = maxVal * 1.08;
    end
end

function s = metricLabel(metric_name)
    % Preserve the wording while keeping 30 pt y labels within each panel.
    switch char(metric_name)
        case 'percentLatents'
            s = {'Percentage of', 'latents (%)'};
        case 'percentSharedVariance'
            s = {'Percentage of shared', 'variance explained (%)'};
        otherwise
            s = metric_name;
    end
end

function s = formatNumberForLabel(v)
    if ~isfinite(v)
        s = 'NaN';
    elseif abs(v - round(v)) < 1e-10
        s = sprintf('%d', round(v));
    else
        s = sprintf('%.4g', v);
    end
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

function [group_display_names, group_file_tags, group_mapping_tag] = ...
        buildGroupLabelsLocal(group_names)

    nGroups = numel(group_names);
    group_display_names = cell(1, nGroups);
    group_file_tags = cell(1, nGroups);

    for g = 1:nGroups
        group_display_names{g} = sprintf( ...
            'Group %d: %s', g, group_names{g});
        group_file_tags{g} = sprintf( ...
            'G%02d_%s', g, makeSafeGroupNameTagLocal(group_names{g}));
    end

    group_mapping_tag = strjoin(group_file_tags, '_');
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

function validateGroupNameCountLocal(group_names, numGroups, context_text)

    if numel(group_names) ~= numGroups
        error(['group_names has %d entries, but %s contains %d groups. ' ...
               'The order of group_names must follow the saved group order.'], ...
              numel(group_names), context_text, numGroups);
    end
end
