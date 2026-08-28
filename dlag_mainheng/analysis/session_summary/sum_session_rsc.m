%% =========================================================================
% sum_session_rsc.m
%
% Summarize condition-wise spike-count noise correlations across sessions.
%
% Required per-session input
% --------------------------
% Run calculate_rsc_by_condition.m inside every catgt_* folder first. This
% program scans:
%
%     root_dir/*/catgt_*
%
% In each catgt_* folder, the program searches for files named like:
%
%     raw_count_rsc_by_condition_*_G01_V1_G02_MT.mat
%
% The wildcard replaces the session-specific stim tag. Candidate files are
% loaded and admitted only when they contain exactly two directions and,
% within each direction, exactly one copy of each of the 8 required
% condition labels. The source condition order may be arbitrary; accepted
% conditions are reordered internally into the canonical 8-condition order.
% Stim tags and physical direction values are not compared across sessions.
% If several files in one catgt_* folder pass, their names are printed and
% the user selects one by number in the Command Window.
%
% Within-session transformation
% -----------------------------
% For each real session, stimulus direction, and neuron-pair type:
%
%   1) Fisher-transform every raw r_sc value with atanh(r_sc).
%   2) Pool the Fisher values from the 8 base conditions.
%   3) Calculate one pooled mean and one pooled sample SD.
%   4) Use those same pooled parameters to z-score all 8 conditions.
%
% The two directions are standardized independently. Thus a V1/MT session
% has 2 directions x 3 pair types = 6 independent normalization groups.
%
% Across-session plot
% -------------------
% Every real session contributes two plotted observations per condition:
% one per direction. For N sessions, each condition normally has 2N points.
% Direction values are not compared across sessions and are not encoded by
% marker style. All points are filled circles.
%
% The figure contains two panels:
%   left  : mean of each condition's z-scored Fisher-r_sc distribution;
%   right : sample SD of that same distribution.
%
% Eight condition bars are shown inside every pair-type block, with all
% session-direction points overlaid. Bar height is selectable as mean or
% median. Error bars are SEM calculated directly from all finite plotted
% session-direction observations:
%
%     SEM = sample SD(points) / sqrt(number of finite points)
%
% Fisher boundary rule
% --------------------
% Exact r_sc = +/-1 has an infinite Fisher transform. The raw value is
% preserved, while its Fisher and z-scored values are stored as NaN and
% excluded from normalization/plot summaries. A detailed warning is issued.
% Values are never artificially clipped to a finite Fisher value.
%
% Saved MAT contents
% ------------------
% MultiSessionRSC contains, for every included session:
%   - raw r_sc distributions;
%   - Fisher-transformed distributions;
%   - z-scored Fisher distributions;
%   - neuron-pair definitions/identities from the source file;
%   - condition and direction metadata;
%   - pooled normalization mean, SD, and valid-value counts;
%   - condition-level mean, sample SD, and valid-pair counts;
%   - the flattened 2N-observation arrays used for plotting;
%   - bar centers, SEM values, and observation counts.
% =========================================================================

clc;
clear;
close all;

%% =============================== Parameters ===============================

% Parent folder containing session_folder/catgt_*.
root_dir = 'I:\np_data';

% Area names in model-group order. Pair-type order is generated as:
% all within-area types first, then all unique across-area combinations.
area_names = {'V1', 'MT'};

% Candidate filename pattern inside every catgt_* folder.
% Leave empty to construct:
%   raw_count_rsc_by_condition_*_<group-area mapping>.mat
% For the default areas this is:
%   raw_count_rsc_by_condition_*_G01_V1_G02_MT.mat
% The '*' matches the possibly different stim tag in each session.
% Alternatively, enter another filename pattern containing zero or more '*'
% wildcards. Enter a filename/pattern only, without a folder.
input_mat_pattern = '';

% If true, folders with a missing/incompatible input are warned and skipped.
% If false, the first such problem stops the program.
skip_incomplete_sessions = true;
print_full_error_report = false;

% Output switches. Summary outputs are saved directly in root_dir. With the
% default areas and bar_summary_stat = 'mean', all enabled outputs use:
%   sum_session_rsc_16conditions_G01_V1_G02_MT_barmean
% and differ only by the .mat, .png, or .fig extension.
save_fig = false;
save_png = true;
save_mat = true;
png_resolution = 300;

% Figure lifecycle.
make_plot = true;
figure_visible = 'on';       % 'on' or 'off'
close_after_save = true;

% Bar height across the 2N session-direction points.
bar_summary_stat = 'mean';
% Options:
%   'mean'
%   'median'
% In both modes, the error length remains sample SD of the finite 2N points
% divided by sqrt(their count), centered on the selected bar height.

% Figure appearance.
condition_group_width = 0.90;
bar_width_fraction = 0.72;
point_jitter_fraction = 0.45;
bar_alpha = 0.38;
point_alpha = 0.88;
point_size = 30;
error_line_width = 1.25;
error_cap_size = 8;
font_name = 'Arial';
font_size = 12;

% Numerical tolerance used only to detect invalid source r_sc outside the
% mathematically allowed interval. Exact +/-1 values remain excluded from
% Fisher transformation as described above.
r_range_tolerance = 1e-10;

%% ============================= Validate setup =============================

area_names = normalizeAreaNamesLocal(area_names);

root_dir = char(string(root_dir));
if exist(root_dir, 'dir') ~= 7
    error('root_dir does not exist: %s', root_dir);
end

skip_incomplete_sessions = validateLogicalScalarLocal( ...
    skip_incomplete_sessions, 'skip_incomplete_sessions');
print_full_error_report = validateLogicalScalarLocal( ...
    print_full_error_report, 'print_full_error_report');
save_fig = validateLogicalScalarLocal(save_fig, 'save_fig');
save_png = validateLogicalScalarLocal(save_png, 'save_png');
save_mat = validateLogicalScalarLocal(save_mat, 'save_mat');
make_plot = validateLogicalScalarLocal(make_plot, 'make_plot');
close_after_save = validateLogicalScalarLocal( ...
    close_after_save, 'close_after_save');

if (save_fig || save_png) && ~make_plot
    error('make_plot must be true when save_fig or save_png is true.');
end

if ~(isscalar(png_resolution) && isnumeric(png_resolution) && ...
        isfinite(png_resolution) && png_resolution > 0)
    error('png_resolution must be one positive finite numeric scalar.');
end

figure_visible = lower(strtrim(char(string(figure_visible))));
if ~ismember(figure_visible, {'on', 'off'})
    error('figure_visible must be ''on'' or ''off''.');
end

bar_summary_stat = lower(strtrim(char(string(bar_summary_stat))));
if ~ismember(bar_summary_stat, {'mean', 'median'})
    error('bar_summary_stat must be ''mean'' or ''median''.');
end

validateOpenUnitIntervalLocal(condition_group_width, ...
    'condition_group_width');
validateOpenUnitIntervalLocal(bar_width_fraction, ...
    'bar_width_fraction');
validateClosedUnitIntervalLocal(point_jitter_fraction, ...
    'point_jitter_fraction');
validateClosedUnitIntervalLocal(bar_alpha, 'bar_alpha');
validateClosedUnitIntervalLocal(point_alpha, 'point_alpha');

if ~(isscalar(point_size) && isnumeric(point_size) && ...
        isfinite(point_size) && point_size > 0)
    error('point_size must be one positive finite numeric scalar.');
end
if ~(isscalar(error_line_width) && isnumeric(error_line_width) && ...
        isfinite(error_line_width) && error_line_width > 0)
    error('error_line_width must be one positive finite numeric scalar.');
end
if ~(isscalar(error_cap_size) && isnumeric(error_cap_size) && ...
        isfinite(error_cap_size) && error_cap_size >= 0)
    error('error_cap_size must be one nonnegative finite numeric scalar.');
end
if ~(isscalar(r_range_tolerance) && isnumeric(r_range_tolerance) && ...
        isfinite(r_range_tolerance) && r_range_tolerance >= 0)
    error('r_range_tolerance must be one nonnegative finite scalar.');
end

font_name = strtrim(char(string(font_name)));
if isempty(font_name)
    error('font_name must be nonempty.');
end
if ~(isscalar(font_size) && isnumeric(font_size) && ...
        isfinite(font_size) && font_size > 0)
    error('font_size must be one positive finite numeric scalar.');
end

area_mapping_tag = makeAreaMappingTagLocal(area_names);
if isempty(input_mat_pattern)
    input_mat_pattern = sprintf( ...
        'raw_count_rsc_by_condition_*_%s.mat', area_mapping_tag);
else
    input_mat_pattern = validateInputMatPatternLocal(input_mat_pattern);
end

expected_pair_type_names = buildExpectedPairTypeNamesLocal(area_names);
canonical_condition_labels = { ...
    'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
    'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};

output_base_name = sprintf('sum_session_rsc_16conditions_%s_bar%s', ...
    area_mapping_tag, ...
    makeSafeFileTagLocal(bar_summary_stat));

fprintf('\n============================================================\n');
fprintf('Across-session r_sc summary\n');
fprintf('Root directory       : %s\n', root_dir);
fprintf('Input MAT pattern    : %s\n', input_mat_pattern);
fprintf('Areas                : %s\n', strjoin(area_names, ', '));
fprintf('Pair types           : %s\n', ...
    strjoin(expected_pair_type_names, ' | '));
fprintf('Required conditions  : %s\n', ...
    strjoin(canonical_condition_labels, ' | '));
fprintf('Stim-tag equality    : not checked\n');
fprintf('Direction values     : not compared across sessions\n');
fprintf('Bar summary          : %s\n', bar_summary_stat);
fprintf('Error bars           : SEM across all finite 2N direction points\n');
fprintf('Output base          : %s\n', output_base_name);
fprintf('============================================================\n');

%% ========================= Find session folders ===========================

session_dirs = findCatgtSessionDirsLocal(root_dir);
if isempty(session_dirs)
    error('No catgt_* folders found one level below root_dir: %s', root_dir);
end

fprintf('\nFound %d candidate catgt_* session folder(s).\n', ...
    numel(session_dirs));

%% ============================ Read sessions ================================

records = {};
skipped = struct( ...
    'session_dir', {}, ...
    'input_pattern', {}, ...
    'candidate_files', {}, ...
    'reason', {});
reference = struct();
reference.area_names = area_names;
reference.pair_type_names = expected_pair_type_names;
reference.condition_short_labels = canonical_condition_labels;
reference.num_directions = 2;
reference.num_conditions = numel(canonical_condition_labels);
reference.num_pair_types = numel(expected_pair_type_names);

for candidate_idx = 1:numel(session_dirs)
    session_dir = session_dirs{candidate_idx};
    candidate_report = struct( ...
        'file_name', {}, 'input_file', {}, 'passed', {}, 'reason', {});

    fprintf('\n[%d/%d] Searching %s\n', ...
        candidate_idx, numel(session_dirs), session_dir);

    try
        [input_file, candidate_report] = selectSessionInputFileLocal( ...
            session_dir, input_mat_pattern, canonical_condition_labels);

        rec = readOneSessionRSCLocal( ...
            session_dir, input_file, area_names, ...
            expected_pair_type_names, canonical_condition_labels, ...
            r_range_tolerance);
        rec.candidate_report = candidate_report;

        records{end + 1} = rec; %#ok<SAGROW>

    catch ME
        if ~skip_incomplete_sessions
            rethrow(ME);
        end

        skipped(end + 1).session_dir = session_dir; %#ok<SAGROW>
        skipped(end).input_pattern = input_mat_pattern;
        skipped(end).candidate_files = candidate_report;
        skipped(end).reason = ME.message;

        warning('sum_session_rsc:SkippedSession', ...
            'Skipping session: %s\nReason: %s', session_dir, ME.message);

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
    error('No valid session was loaded.');
end

num_sessions = numel(records);
for s = 1:num_sessions
    records{s}.session_index = s;
    records{s}.session_label = sprintf('S%d', s);
end

fprintf('\nLoaded %d valid session(s); skipped %d.\n', ...
    num_sessions, numel(skipped));
fprintf('\nSession mapping:\n');
for s = 1:num_sessions
    fprintf('  S%-3d -> %s\n', s, records{s}.session_name);
end

%% ==================== Flatten session-direction points ====================

num_directions = reference.num_directions;
num_conditions = reference.num_conditions;
num_pair_types = reference.num_pair_types;
num_observations = num_sessions * num_directions;

mean_points = nan(num_observations, num_conditions, num_pair_types);
sd_points = nan(num_observations, num_conditions, num_pair_types);
n_valid_pair_values = zeros( ...
    num_observations, num_conditions, num_pair_types);

observation_template = struct( ...
    'observation_index', [], ...
    'session_index', [], ...
    'session_label', '', ...
    'session_name', '', ...
    'session_dir', '', ...
    'input_file', '', ...
    'direction_slot', [], ...
    'direction_code', [], ...
    'direction_value', []);
observation_info = repmat( ...
    observation_template, 1, num_observations);

obs = 0;
for s = 1:num_sessions
    for d = 1:num_directions
        obs = obs + 1;

        mean_points(obs, :, :) = reshape( ...
            records{s}.condition_summary.mean_zscored_fisher(d, :, :), ...
            [1, num_conditions, num_pair_types]);
        sd_points(obs, :, :) = reshape( ...
            records{s}.condition_summary.sd_zscored_fisher(d, :, :), ...
            [1, num_conditions, num_pair_types]);
        n_valid_pair_values(obs, :, :) = reshape( ...
            records{s}.condition_summary.n_valid_pair_values(d, :, :), ...
            [1, num_conditions, num_pair_types]);

        observation_info(obs).observation_index = obs;
        observation_info(obs).session_index = s;
        observation_info(obs).session_label = records{s}.session_label;
        observation_info(obs).session_name = records{s}.session_name;
        observation_info(obs).session_dir = records{s}.session_dir;
        observation_info(obs).input_file = records{s}.input_file;
        observation_info(obs).direction_slot = d;
        observation_info(obs).direction_code = ...
            records{s}.direction_codes(d);
        observation_info(obs).direction_value = ...
            records{s}.direction_values(d);
    end
end

%% ======================= Bar centers and SEM ===============================

mean_panel_bar_center = nan(num_conditions, num_pair_types);
mean_panel_sem = nan(num_conditions, num_pair_types);
mean_panel_n = zeros(num_conditions, num_pair_types);

sd_panel_bar_center = nan(num_conditions, num_pair_types);
sd_panel_sem = nan(num_conditions, num_pair_types);
sd_panel_n = zeros(num_conditions, num_pair_types);

for c = 1:num_conditions
    for p = 1:num_pair_types
        [mean_panel_bar_center(c, p), mean_panel_sem(c, p), ...
            mean_panel_n(c, p)] = summarizeObservationPointsLocal( ...
            mean_points(:, c, p), bar_summary_stat);

        [sd_panel_bar_center(c, p), sd_panel_sem(c, p), ...
            sd_panel_n(c, p)] = summarizeObservationPointsLocal( ...
            sd_points(:, c, p), bar_summary_stat);
    end
end

%% =========================== Assemble output ===============================

MultiSessionRSC = struct();

MultiSessionRSC.meta.created_by = mfilename;
MultiSessionRSC.meta.created_on = datestr(now, 30);
MultiSessionRSC.meta.root_dir = root_dir;
MultiSessionRSC.meta.input_mat_pattern = input_mat_pattern;
MultiSessionRSC.meta.area_names = area_names;
MultiSessionRSC.meta.area_mapping_tag = area_mapping_tag;
MultiSessionRSC.meta.pair_type_names = reference.pair_type_names;
MultiSessionRSC.meta.condition_short_labels = ...
    reference.condition_short_labels;
MultiSessionRSC.meta.num_sessions = num_sessions;
MultiSessionRSC.meta.num_directions_per_session = num_directions;
MultiSessionRSC.meta.num_observations = num_observations;
MultiSessionRSC.meta.output_base_name = output_base_name;
MultiSessionRSC.meta.selected_input_files = cellfun( ...
    @(x) x.input_file, records, 'UniformOutput', false);
MultiSessionRSC.meta.source_stim_tags = cellfun( ...
    @(x) x.source_stim_tag, records, 'UniformOutput', false);
MultiSessionRSC.meta.candidate_admission_rule = [ ...
    'Filename must match the area-specific wildcard pattern; after load, ', ...
    'the file must contain exactly two directions, and each direction ', ...
    'must contain each of the 8 canonical condition labels exactly once. ', ...
    'Source condition order is ignored and reordered canonically.'];
MultiSessionRSC.meta.stim_tag_equality_check = ...
    'not performed; each selected source stim tag is stored per session';
MultiSessionRSC.meta.area_name_source_check = ...
    'not performed; area mapping is enforced only by the filename pattern';

MultiSessionRSC.meta.fisher_transform = ...
    'atanh(raw r_sc), applied only when abs(raw r_sc) < 1';
MultiSessionRSC.meta.fisher_boundary_rule = [ ...
    'Exact raw r_sc = +/-1 is retained in raw_rsc, while Fisher and ', ...
    'z-scored Fisher values are NaN and excluded; no finite clipping.'];
MultiSessionRSC.meta.normalization_rule = [ ...
    'Within each session, direction, and pair type, pool Fisher r_sc ', ...
    'from all 8 base conditions; use the pooled mean and sample SD to ', ...
    'z-score every valid pair value in those 8 conditions.'];
MultiSessionRSC.meta.direction_observation_rule = [ ...
    'Directions are normalized independently and then treated as ', ...
    'independent plotted observations; N sessions contribute 2N points.'];
MultiSessionRSC.meta.bar_summary_stat = bar_summary_stat;
MultiSessionRSC.meta.errorbar_definition = [ ...
    'SEM = sample SD of all finite plotted session-direction points ', ...
    'divided by sqrt(number of those finite points).'];
MultiSessionRSC.meta.sd_normalization = ...
    'sample SD, N-1 (MATLAB std(...,0))';
MultiSessionRSC.meta.dimension_names_distribution_cells = ...
    {'direction', 'condition', 'pair_type'};
MultiSessionRSC.meta.dimension_names_observation_arrays = ...
    {'session_direction_observation', 'condition', 'pair_type'};
MultiSessionRSC.meta.session_sorting = [ ...
    'Sort by the number following p in the parent session-folder name; ', ...
    'then by parent and catgt folder names.'];
MultiSessionRSC.meta.cross_session_direction_value_check = ...
    'not performed by design';

MultiSessionRSC.plot_settings.condition_group_width = ...
    condition_group_width;
MultiSessionRSC.plot_settings.bar_width_fraction = bar_width_fraction;
MultiSessionRSC.plot_settings.point_jitter_fraction = ...
    point_jitter_fraction;
MultiSessionRSC.plot_settings.bar_alpha = bar_alpha;
MultiSessionRSC.plot_settings.point_alpha = point_alpha;
MultiSessionRSC.plot_settings.point_size = point_size;
MultiSessionRSC.plot_settings.error_line_width = error_line_width;
MultiSessionRSC.plot_settings.error_cap_size = error_cap_size;
MultiSessionRSC.plot_settings.font_name = font_name;
MultiSessionRSC.plot_settings.font_size = font_size;

MultiSessionRSC.labels.conditions = reference.condition_short_labels;
MultiSessionRSC.labels.pair_types = reference.pair_type_names;
MultiSessionRSC.labels.areas = area_names;
MultiSessionRSC.colors.conditions = lines(num_conditions);

% Keep sessions as a cell array because different sessions can contain
% different neuron counts, pair counts, and source-metadata field layouts.
MultiSessionRSC.sessions.included = records;
MultiSessionRSC.sessions.skipped = skipped;

MultiSessionRSC.observations.info = observation_info;
MultiSessionRSC.observations.mean_zscored_fisher = mean_points;
MultiSessionRSC.observations.sd_zscored_fisher = sd_points;
MultiSessionRSC.observations.n_valid_pair_values = n_valid_pair_values;

MultiSessionRSC.plot_summary.mean_panel.bar_center = ...
    mean_panel_bar_center;
MultiSessionRSC.plot_summary.mean_panel.sem = mean_panel_sem;
MultiSessionRSC.plot_summary.mean_panel.n_valid_observations = mean_panel_n;
MultiSessionRSC.plot_summary.sd_panel.bar_center = sd_panel_bar_center;
MultiSessionRSC.plot_summary.sd_panel.sem = sd_panel_sem;
MultiSessionRSC.plot_summary.sd_panel.n_valid_observations = sd_panel_n;

%% ================================ Plot =====================================

fig_handle = gobjects(0);
if make_plot
    fig_handle = plotMultiSessionRSCLocal( ...
        MultiSessionRSC, condition_group_width, bar_width_fraction, ...
        point_jitter_fraction, bar_alpha, point_alpha, point_size, ...
        error_line_width, error_cap_size, font_name, font_size, ...
        figure_visible);
end

%% ================================ Save =====================================

output_base_path = fullfile(root_dir, output_base_name);
fig_path = [output_base_path, '.fig'];
png_path = [output_base_path, '.png'];
mat_path = [output_base_path, '.mat'];

MultiSessionRSC.meta.output_directory = root_dir;
MultiSessionRSC.meta.save_fig = save_fig;
MultiSessionRSC.meta.save_png = save_png;
MultiSessionRSC.meta.save_mat = save_mat;
MultiSessionRSC.meta.png_resolution = png_resolution;
MultiSessionRSC.meta.fig_file = ternaryTextLocal(save_fig, fig_path, '');
MultiSessionRSC.meta.png_file = ternaryTextLocal(save_png, png_path, '');
MultiSessionRSC.meta.mat_file = ternaryTextLocal(save_mat, mat_path, '');

if save_fig
    savefig(fig_handle, fig_path);
    fprintf('\nSaved FIG: %s\n', fig_path);
end

if save_png
    exportgraphics(fig_handle, png_path, 'Resolution', png_resolution);
    fprintf('Saved PNG: %s\n', png_path);
end

if save_mat
    fprintf(['Saving MAT with all raw, Fisher, and z-scored pair ', ...
             'distributions; this file can be large and may take time.\n']);
    save(mat_path, 'MultiSessionRSC', '-v7.3');
    fprintf('Saved MAT: %s\n', mat_path);
end

if close_after_save && ~isempty(fig_handle) && isgraphics(fig_handle)
    close(fig_handle);
end

fprintf('\nFinished sum_session_rsc.\n');

%% ============================ Local functions ==============================

function area_names = normalizeAreaNamesLocal(area_names)

if isstring(area_names)
    area_names = cellstr(area_names(:)');
elseif ischar(area_names)
    if size(area_names, 1) == 1
        area_names = {area_names};
    else
        area_names = reshape(cellstr(area_names), 1, []);
    end
elseif iscell(area_names)
    area_names = reshape(area_names, 1, []);
else
    error('area_names must be text or a cell array of text.');
end

if isempty(area_names)
    error('area_names cannot be empty.');
end

for g = 1:numel(area_names)
    value = area_names{g};
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('area_names{%d} must contain text.', g);
    end

    value = strtrim(char(string(value)));
    if isempty(value)
        error('area_names{%d} cannot be empty.', g);
    end
    area_names{g} = value;
end

end


function value = validateLogicalScalarLocal(value, variable_name)

if ~(isscalar(value) && (islogical(value) || isnumeric(value)) && ...
        isfinite(double(value)) && ismember(double(value), [0, 1]))
    error('%s must be true/false or 1/0.', variable_name);
end
value = logical(value);

end


function validateOpenUnitIntervalLocal(value, variable_name)

if ~(isscalar(value) && isnumeric(value) && isfinite(value) && ...
        value > 0 && value < 1)
    error('%s must be one finite scalar strictly between 0 and 1.', ...
        variable_name);
end

end


function validateClosedUnitIntervalLocal(value, variable_name)

if ~(isscalar(value) && isnumeric(value) && isfinite(value) && ...
        value >= 0 && value <= 1)
    error('%s must be one finite scalar between 0 and 1.', variable_name);
end

end


function input_mat_pattern = validateInputMatPatternLocal(input_mat_pattern)

input_mat_pattern = strtrim(char(string(input_mat_pattern)));
if isempty(input_mat_pattern)
    error('A nonempty input_mat_pattern was expected.');
end

[folder_part, name_part, extension_part] = fileparts(input_mat_pattern);
if ~isempty(folder_part)
    error('input_mat_pattern must not contain a folder.');
end
if isempty(extension_part)
    extension_part = '.mat';
elseif ~strcmpi(extension_part, '.mat')
    error('input_mat_pattern must have extension .mat.');
end

input_mat_pattern = [name_part, extension_part];

end


function tag = makeAreaMappingTagLocal(area_names)

parts = cell(1, numel(area_names));
for g = 1:numel(area_names)
    parts{g} = sprintf('G%02d_%s', g, ...
        makeSafeFileTagLocal(area_names{g}));
end
tag = strjoin(parts, '_');

end


function tag = makeSafeFileTagLocal(value)

tag = strtrim(char(string(value)));
tag = regexprep(tag, '[^A-Za-z0-9]+', '_');
tag = regexprep(tag, '^_+|_+$', '');
if isempty(tag)
    tag = 'x';
end

end


function pair_type_names = buildExpectedPairTypeNamesLocal(area_names)

num_groups = numel(area_names);
num_pair_types = num_groups + nchoosek(num_groups, 2);
pair_type_names = cell(1, num_pair_types);

p = 0;
for g = 1:num_groups
    p = p + 1;
    pair_type_names{p} = sprintf('%s-%s', ...
        area_names{g}, area_names{g});
end

for g1 = 1:(num_groups - 1)
    for g2 = (g1 + 1):num_groups
        p = p + 1;
        pair_type_names{p} = sprintf('%s-%s', ...
            area_names{g1}, area_names{g2});
    end
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
T = sortrows(T, {'session_number', 'session_name', 'catgt_name'});
session_dirs = T.session_dir(:)';

end


function session_number = extractSessionNumberFromNameLocal(session_name)

tokens = regexp(session_name, 'p(\d+)', 'tokens', 'once');
if isempty(tokens)
    session_number = inf;
else
    session_number = str2double(tokens{1});
    if ~isfinite(session_number)
        session_number = inf;
    end
end

end


function [input_file, candidate_report] = selectSessionInputFileLocal( ...
        session_dir, input_mat_pattern, canonical_condition_labels)

listing = dir(fullfile(session_dir, input_mat_pattern));
listing = listing(~[listing.isdir]);

candidate_report = struct( ...
    'file_name', {}, ...
    'input_file', {}, ...
    'passed', {}, ...
    'selected', {}, ...
    'reason', {});

if isempty(listing)
    error('No MAT file matches %s in %s.', ...
        input_mat_pattern, session_dir);
end

[~, order] = sort(lower(string({listing.name})));
listing = listing(order);

for k = 1:numel(listing)
    this_file = fullfile(listing(k).folder, listing(k).name);
    [passed, reason] = inspectCandidateRSCFileLocal( ...
        this_file, canonical_condition_labels);

    candidate_report(k).file_name = listing(k).name;
    candidate_report(k).input_file = this_file;
    candidate_report(k).passed = passed;
    candidate_report(k).selected = false;
    candidate_report(k).reason = reason;

    if passed
        fprintf('  PASS: %s\n', listing(k).name);
    else
        fprintf('  FAIL: %s\n', listing(k).name);
        fprintf('        %s\n', reason);
    end
end

valid_indices = find([candidate_report.passed]);

if isempty(valid_indices)
    detail_lines = cell(1, numel(candidate_report));
    for k = 1:numel(candidate_report)
        detail_lines{k} = sprintf('  %s -> %s', ...
            candidate_report(k).file_name, candidate_report(k).reason);
    end
    error(['No candidate file passed the 2-direction x 8-condition ', ...
           'label check in %s.\n%s'], ...
        session_dir, strjoin(detail_lines, newline));
end

if numel(valid_indices) == 1
    selected_report_index = valid_indices(1);
else
    fprintf(['\nMultiple candidate files passed in:\n  %s\n', ...
             'Choose the file to include for this session:\n'], session_dir);
    for option_idx = 1:numel(valid_indices)
        report_idx = valid_indices(option_idx);
        fprintf('  %d) %s\n', option_idx, ...
            candidate_report(report_idx).file_name);
    end
    fprintf('  0) Skip this session\n');

    while true
        answer_text = strtrim(input( ...
            sprintf('Enter 0-%d: ', numel(valid_indices)), 's'));
        answer_value = str2double(answer_text);

        if isfinite(answer_value) && answer_value == round(answer_value) && ...
                answer_value >= 0 && answer_value <= numel(valid_indices)
            break;
        end
        fprintf('Please enter one integer from 0 to %d.\n', ...
            numel(valid_indices));
    end

    if answer_value == 0
        error('sum_session_rsc:UserSkippedSession', ...
            'User skipped this session after multiple files passed: %s', ...
            session_dir);
    end
    selected_report_index = valid_indices(answer_value);
end

candidate_report(selected_report_index).selected = true;
input_file = candidate_report(selected_report_index).input_file;
fprintf('  SELECTED: %s\n', ...
    candidate_report(selected_report_index).file_name);

end


function [passed, reason] = inspectCandidateRSCFileLocal( ...
        input_file, canonical_condition_labels)

passed = false;
reason = '';

try
    loaded = load(input_file, 'RSCResults');
catch ME
    reason = sprintf('Could not load RSCResults: %s', ME.message);
    return;
end

if ~isfield(loaded, 'RSCResults')
    reason = 'Variable RSCResults is absent.';
    return;
end

[passed, reason] = assessCandidateRSCStructureLocal( ...
    loaded.RSCResults, canonical_condition_labels);

end


function [passed, reason, direction_codes, condition_lookup] = ...
        assessCandidateRSCStructureLocal(R, canonical_condition_labels)

passed = false;
reason = '';
direction_codes = [];
condition_lookup = [];

if ~(isstruct(R) && isscalar(R))
    reason = 'RSCResults is not one scalar struct.';
    return;
end
if ~isfield(R, 'conditions') || ~isstruct(R.conditions)
    reason = 'RSCResults.conditions is absent or is not a struct array.';
    return;
end

conditions = R.conditions;
if numel(conditions) ~= 16
    reason = sprintf('Found %d direction-condition entries; expected 16.', ...
        numel(conditions));
    return;
end
if ~isfield(conditions, 'direction_code')
    reason = 'RSCResults.conditions.direction_code is absent.';
    return;
end
if ~isfield(conditions, 'condition_short_label')
    reason = 'RSCResults.conditions.condition_short_label is absent.';
    return;
end

try
    all_direction_codes = [conditions.direction_code];
catch ME
    reason = sprintf('Could not read direction_code values: %s', ME.message);
    return;
end

if ~(isnumeric(all_direction_codes) && ...
        numel(all_direction_codes) == numel(conditions) && ...
        all(isfinite(all_direction_codes)))
    reason = 'direction_code must provide one finite numeric value per entry.';
    return;
end

direction_codes = sort(unique(all_direction_codes(:)'));
if numel(direction_codes) ~= 2
    reason = sprintf('Found %d distinct directions; expected 2.', ...
        numel(direction_codes));
    return;
end

num_directions = 2;
num_conditions = numel(canonical_condition_labels);
condition_lookup = zeros(num_directions, num_conditions);

for d = 1:num_directions
    source_indices = find(all_direction_codes == direction_codes(d));
    if numel(source_indices) ~= num_conditions
        reason = sprintf( ...
            'Direction %s contains %d conditions; expected 8.', ...
            formatNumberLocal(direction_codes(d)), numel(source_indices));
        return;
    end

    for j = 1:numel(source_indices)
        source_idx = source_indices(j);
        label_value = conditions(source_idx).condition_short_label;
        if ~(ischar(label_value) || ...
                (isstring(label_value) && isscalar(label_value)))
            reason = sprintf( ...
                'Condition label at source entry %d is not scalar text.', ...
                source_idx);
            return;
        end

        this_label = upper(strtrim(char(string(label_value))));
        canonical_idx = find(strcmpi( ...
            this_label, canonical_condition_labels), 1);
        if isempty(canonical_idx)
            reason = sprintf( ...
                'Direction %s contains unexpected condition label "%s".', ...
                formatNumberLocal(direction_codes(d)), this_label);
            return;
        end
        if condition_lookup(d, canonical_idx) ~= 0
            reason = sprintf( ...
                'Direction %s contains duplicate condition label "%s".', ...
                formatNumberLocal(direction_codes(d)), ...
                canonical_condition_labels{canonical_idx});
            return;
        end
        condition_lookup(d, canonical_idx) = source_idx;
    end

    if any(condition_lookup(d, :) == 0)
        missing_labels = canonical_condition_labels( ...
            condition_lookup(d, :) == 0);
        reason = sprintf( ...
            'Direction %s is missing condition label(s): %s.', ...
            formatNumberLocal(direction_codes(d)), ...
            strjoin(missing_labels, ', '));
        return;
    end
end

passed = true;
reason = ['Passed: exactly 2 directions, each containing the 8 required ', ...
          'condition labels once; source order is ignored.'];

end


function rec = readOneSessionRSCLocal( ...
        session_dir, input_file, expected_area_names, ...
        expected_pair_type_names, canonical_condition_labels, ...
        r_range_tolerance)

loaded = load(input_file, 'RSCResults');
R = loaded.RSCResults;

[passed, reason, direction_codes, condition_lookup] = ...
    assessCandidateRSCStructureLocal(R, canonical_condition_labels);
if ~passed
    error('Selected file no longer passes the admission check: %s', reason);
end

num_directions = 2;
num_conditions = numel(canonical_condition_labels);
num_pair_types = numel(expected_pair_type_names);

source_meta = struct();
source_stim_tag = '';
pair_types = struct([]);
if isfield(R, 'meta') && isstruct(R.meta)
    source_meta = R.meta;
    if isfield(R.meta, 'stim_tag')
        source_stim_tag = char(string(R.meta.stim_tag));
    end
    if isfield(R.meta, 'pair_types')
        pair_types = R.meta.pair_types;
    end
end

direction_values = nan(1, num_directions);
direction_labels = cell(1, num_directions);
condition_info_template = struct( ...
    'source_condition_index', [], ...
    'condition_id', [], ...
    'condition_metadata', struct(), ...
    'condition_long_label', '', ...
    'condition_short_label', '', ...
    'canonical_condition_index', [], ...
    'source_panel_condition_index', [], ...
    'direction_slot', [], ...
    'direction_code', [], ...
    'direction_value', [], ...
    'direction_label', '', ...
    'n_trials_original', [], ...
    'n_outlier_trials_union', [], ...
    'n_trials_kept', []);
condition_info = repmat( ...
    condition_info_template, num_directions, num_conditions);

for d = 1:num_directions
    first_condition = R.conditions(condition_lookup(d, 1));
    direction_values(d) = getNumericFieldOrNaNLocal( ...
        first_condition, 'direction_value');
    direction_labels{d} = getTextFieldOrEmptyLocal( ...
        first_condition, 'direction_label');

    for c = 1:num_conditions
        source_idx = condition_lookup(d, c);
        C = R.conditions(source_idx);

        condition_info(d, c).source_condition_index = source_idx;
        condition_info(d, c).condition_id = ...
            getFieldOrDefaultLocal(C, 'condition_id', []);
        condition_info(d, c).condition_metadata = ...
            getFieldOrDefaultLocal(C, 'condition_metadata', struct());
        condition_info(d, c).condition_long_label = ...
            getTextFieldOrEmptyLocal(C, 'condition_long_label');
        condition_info(d, c).condition_short_label = ...
            canonical_condition_labels{c};
        condition_info(d, c).canonical_condition_index = c;
        condition_info(d, c).source_panel_condition_index = ...
            getFieldOrDefaultLocal(C, 'panel_condition_index', []);
        condition_info(d, c).direction_slot = d;
        condition_info(d, c).direction_code = direction_codes(d);
        condition_info(d, c).direction_value = ...
            getNumericFieldOrNaNLocal(C, 'direction_value');
        condition_info(d, c).direction_label = ...
            getTextFieldOrEmptyLocal(C, 'direction_label');
        condition_info(d, c).n_trials_original = ...
            getFieldOrDefaultLocal(C, 'n_trials_original', []);
        condition_info(d, c).n_outlier_trials_union = ...
            getFieldOrDefaultLocal(C, 'n_outlier_trials_union', []);
        condition_info(d, c).n_trials_kept = ...
            getFieldOrDefaultLocal(C, 'n_trials_kept', []);
    end
end

raw_rsc = cell(num_directions, num_conditions, num_pair_types);
fisher_rsc = cell(num_directions, num_conditions, num_pair_types);
zscored_fisher_rsc = cell( ...
    num_directions, num_conditions, num_pair_types);
fisher_boundary_count = zeros( ...
    num_directions, num_conditions, num_pair_types);
n_pairs_by_condition = zeros( ...
    num_directions, num_conditions, num_pair_types);

for d = 1:num_directions
    for c = 1:num_conditions
        source_idx = condition_lookup(d, c);
        pair_results = R.conditions(source_idx).pair_type_results;

        for p = 1:num_pair_types
            raw_values = pair_results(p).rsc_values;
            if ~(isnumeric(raw_values) && isreal(raw_values) && ...
                    (isvector(raw_values) || isempty(raw_values)))
                error(['rsc_values for %s, direction %d, condition %s ', ...
                       'in %s must be one real numeric vector.'], ...
                    expected_pair_type_names{p}, d, ...
                    canonical_condition_labels{c}, input_file);
            end
            raw_values = raw_values(:);

            if any(~isfinite(raw_values))
                error(['Raw r_sc contains nonfinite values for %s, ', ...
                       'direction %d, condition %s in %s.'], ...
                    expected_pair_type_names{p}, d, ...
                    canonical_condition_labels{c}, input_file);
            end
            if any(raw_values < -1 - r_range_tolerance | ...
                    raw_values > 1 + r_range_tolerance)
                error(['Raw r_sc outside [-1,1] for %s, direction %d, ', ...
                       'condition %s in %s.'], ...
                    expected_pair_type_names{p}, d, ...
                    canonical_condition_labels{c}, input_file);
            end
            n_pairs_by_condition(d, c, p) = numel(raw_values);

            fisher_values = nan(size(raw_values));
            finite_fisher_mask = raw_values > -1 & raw_values < 1;
            fisher_values(finite_fisher_mask) = ...
                atanh(raw_values(finite_fisher_mask));

            boundary_count = sum(~finite_fisher_mask);
            fisher_boundary_count(d, c, p) = boundary_count;

            if boundary_count > 0
                warning('sum_session_rsc:FisherBoundary', ...
                    ['%s | direction code %s (value %s) | condition %s | ', ...
                     'pair type %s: %d raw r_sc value(s) equal or exceed ', ...
                     'the Fisher boundary +/-1 within tolerance. Raw values ', ...
                     'are retained; Fisher and z-scored values are NaN.'], ...
                    getSessionNameLocal(session_dir), ...
                    formatNumberLocal(direction_codes(d)), ...
                    formatNumberLocal(direction_values(d)), ...
                    canonical_condition_labels{c}, ...
                    expected_pair_type_names{p}, boundary_count);
            end

            raw_rsc{d, c, p} = raw_values;
            fisher_rsc{d, c, p} = fisher_values;
            zscored_fisher_rsc{d, c, p} = nan(size(raw_values));
        end
    end
end

n_pairs_by_type = reshape(n_pairs_by_condition(1, 1, :), ...
    1, num_pair_types);

normalization_template = struct( ...
    'direction_code', [], ...
    'direction_value', [], ...
    'pair_type_index', [], ...
    'pair_type_name', '', ...
    'n_unique_neuron_pairs', [], ...
    'n_conditions_pooled', num_conditions, ...
    'n_total_pooled_values', [], ...
    'n_valid_pooled_values', [], ...
    'n_excluded_fisher_boundary_values', [], ...
    'pooled_mean_fisher', [], ...
    'pooled_sample_sd_fisher', [], ...
    'pooled_z_mean_check', NaN, ...
    'pooled_z_sample_sd_check', NaN, ...
    'zscore_status', '');
normalization = repmat( ...
    normalization_template, num_directions, num_pair_types);

for d = 1:num_directions
    for p = 1:num_pair_types
        pooled_fisher = vertcat(fisher_rsc{d, :, p});
        valid_pooled = pooled_fisher(isfinite(pooled_fisher));

        normalization(d, p).direction_code = direction_codes(d);
        normalization(d, p).direction_value = direction_values(d);
        normalization(d, p).pair_type_index = p;
        normalization(d, p).pair_type_name = ...
            expected_pair_type_names{p};
        normalization(d, p).n_unique_neuron_pairs = n_pairs_by_type(p);
        normalization(d, p).n_total_pooled_values = numel(pooled_fisher);
        normalization(d, p).n_valid_pooled_values = numel(valid_pooled);
        normalization(d, p).n_excluded_fisher_boundary_values = ...
            sum(fisher_boundary_count(d, :, p));

        if numel(valid_pooled) < 2
            normalization(d, p).pooled_mean_fisher = ...
                meanOrNaNLocal(valid_pooled);
            normalization(d, p).pooled_sample_sd_fisher = NaN;
            normalization(d, p).zscore_status = ...
                'not computed: fewer than 2 valid pooled Fisher values';

            warning('sum_session_rsc:InsufficientPooledValues', ...
                ['%s | direction code %s (value %s) | pair type %s: ', ...
                 'only %d valid pooled Fisher value(s); z-score omitted.'], ...
                getSessionNameLocal(session_dir), ...
                formatNumberLocal(direction_codes(d)), ...
                formatNumberLocal(direction_values(d)), ...
                expected_pair_type_names{p}, numel(valid_pooled));
            continue;
        end

        pooled_mean = mean(valid_pooled);
        pooled_sd = std(valid_pooled, 0);
        normalization(d, p).pooled_mean_fisher = pooled_mean;
        normalization(d, p).pooled_sample_sd_fisher = pooled_sd;

        if ~(isfinite(pooled_sd) && pooled_sd > 0)
            normalization(d, p).zscore_status = ...
                'not computed: pooled Fisher SD is zero or nonfinite';

            warning('sum_session_rsc:ZeroPooledFisherSD', ...
                ['%s | direction code %s (value %s) | pair type %s: ', ...
                 'pooled Fisher SD is zero/nonfinite; z-score omitted.'], ...
                getSessionNameLocal(session_dir), ...
                formatNumberLocal(direction_codes(d)), ...
                formatNumberLocal(direction_values(d)), ...
                expected_pair_type_names{p});
            continue;
        end

        normalization(d, p).zscore_status = 'computed';

        for c = 1:num_conditions
            fisher_values = fisher_rsc{d, c, p};
            z_values = nan(size(fisher_values));
            valid_mask = isfinite(fisher_values);
            z_values(valid_mask) = ...
                (fisher_values(valid_mask) - pooled_mean) ./ pooled_sd;
            zscored_fisher_rsc{d, c, p} = z_values;
        end

        pooled_z = vertcat(zscored_fisher_rsc{d, :, p});
        pooled_z = pooled_z(isfinite(pooled_z));
        pooled_z_mean = mean(pooled_z);
        pooled_z_sd = std(pooled_z, 0);
        normalization(d, p).pooled_z_mean_check = pooled_z_mean;
        normalization(d, p).pooled_z_sample_sd_check = pooled_z_sd;

        check_tolerance = 1e-9;
        if abs(pooled_z_mean) > check_tolerance || ...
                abs(pooled_z_sd - 1) > check_tolerance
            error(['Internal z-score verification failed for %s, ', ...
                   'direction %s, pair type %s. Pooled z mean = %.12g, ', ...
                   'pooled z SD = %.12g.'], ...
                getSessionNameLocal(session_dir), ...
                formatNumberLocal(direction_codes(d)), ...
                expected_pair_type_names{p}, pooled_z_mean, pooled_z_sd);
        end
    end
end

mean_raw = nan(num_directions, num_conditions, num_pair_types);
sd_raw = nan(num_directions, num_conditions, num_pair_types);
n_valid_raw = zeros(num_directions, num_conditions, num_pair_types);
mean_fisher = nan(num_directions, num_conditions, num_pair_types);
sd_fisher = nan(num_directions, num_conditions, num_pair_types);
n_valid_fisher = zeros(num_directions, num_conditions, num_pair_types);
mean_z = nan(num_directions, num_conditions, num_pair_types);
sd_z = nan(num_directions, num_conditions, num_pair_types);
n_valid_z = zeros(num_directions, num_conditions, num_pair_types);

for d = 1:num_directions
    for c = 1:num_conditions
        for p = 1:num_pair_types
            [mean_raw(d, c, p), sd_raw(d, c, p), ...
                n_valid_raw(d, c, p)] = ...
                summarizeDistributionLocal(raw_rsc{d, c, p});

            [mean_fisher(d, c, p), sd_fisher(d, c, p), ...
                n_valid_fisher(d, c, p)] = ...
                summarizeDistributionLocal(fisher_rsc{d, c, p});

            [mean_z(d, c, p), sd_z(d, c, p), ...
                n_valid_z(d, c, p)] = ...
                summarizeDistributionLocal(zscored_fisher_rsc{d, c, p});
        end
    end
end

[parent_dir, catgt_name] = fileparts(session_dir);
[~, session_parent_name] = fileparts(parent_dir);

if isfield(source_meta, 'pair_types')
    source_meta = rmfield(source_meta, 'pair_types');
end

rec = struct();
rec.session_index = [];
rec.session_label = '';
rec.session_name = getSessionNameLocal(session_dir);
rec.session_parent_name = session_parent_name;
rec.catgt_folder_name = catgt_name;
rec.session_number = ...
    extractSessionNumberFromNameLocal(session_parent_name);
rec.session_dir = session_dir;
rec.input_file = input_file;
rec.source_stim_tag = source_stim_tag;
rec.source_meta = source_meta;
rec.area_names = expected_area_names;
rec.pair_type_names = expected_pair_type_names;
rec.pair_types = pair_types;
rec.n_pairs_by_type = n_pairs_by_type;
rec.n_pairs_by_condition = n_pairs_by_condition;
rec.num_directions = num_directions;
rec.direction_codes = direction_codes;
rec.direction_values = direction_values;
rec.direction_labels = direction_labels;
rec.condition_short_labels = canonical_condition_labels;
rec.condition_lookup_source_index = condition_lookup;
rec.condition_info = condition_info;
rec.raw_rsc = raw_rsc;
rec.fisher_rsc = fisher_rsc;
rec.zscored_fisher_rsc = zscored_fisher_rsc;
rec.fisher_boundary_count = fisher_boundary_count;
rec.normalization = normalization;
rec.condition_summary.mean_raw_rsc = mean_raw;
rec.condition_summary.sd_raw_rsc = sd_raw;
rec.condition_summary.n_valid_raw_values = n_valid_raw;
rec.condition_summary.mean_fisher_rsc = mean_fisher;
rec.condition_summary.sd_fisher_rsc = sd_fisher;
rec.condition_summary.n_valid_fisher_values = n_valid_fisher;
rec.condition_summary.mean_zscored_fisher = mean_z;
rec.condition_summary.sd_zscored_fisher = sd_z;
rec.condition_summary.n_valid_pair_values = n_valid_z;
rec.stim_tag_equality_check = 'not performed by design';
rec.area_name_source_check = 'not performed by design';
rec.cross_session_direction_value_check = 'not performed by design';

end


function value = getFieldOrDefaultLocal(S, field_name, default_value)

if isfield(S, field_name)
    value = S.(field_name);
else
    value = default_value;
end

end


function value = getNumericFieldOrNaNLocal(S, field_name)

value = getFieldOrDefaultLocal(S, field_name, NaN);
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    value = NaN;
end

end


function value = getTextFieldOrEmptyLocal(S, field_name)

value = getFieldOrDefaultLocal(S, field_name, '');
if ischar(value) || (isstring(value) && isscalar(value))
    value = strtrim(char(string(value)));
else
    value = '';
end

end


function [mean_value, sd_value, n_valid] = ...
        summarizeDistributionLocal(values)

values = values(:);
values = values(isfinite(values));
n_valid = numel(values);

if isempty(values)
    mean_value = NaN;
    sd_value = NaN;
else
    mean_value = mean(values);
    sd_value = std(values, 0);
end

end


function value = meanOrNaNLocal(values)

values = values(isfinite(values));
if isempty(values)
    value = NaN;
else
    value = mean(values);
end

end


function name = getSessionNameLocal(session_dir)

[parent_dir, catgt_name] = fileparts(session_dir);
[~, parent_name] = fileparts(parent_dir);
name = sprintf('%s/%s', parent_name, catgt_name);

end


function text_value = formatNumberLocal(value)

if ~(isscalar(value) && isnumeric(value) && isfinite(value))
    text_value = 'NaN';
elseif abs(value - round(value)) < 1e-10
    text_value = sprintf('%d', round(value));
else
    text_value = sprintf('%.6g', value);
end

end


function [center_value, sem_value, n_valid] = ...
        summarizeObservationPointsLocal(values, bar_summary_stat)

values = values(:);
values = values(isfinite(values));
n_valid = numel(values);

if isempty(values)
    center_value = NaN;
    sem_value = NaN;
    return;
end

switch bar_summary_stat
    case 'mean'
        center_value = mean(values);
    case 'median'
        center_value = median(values);
    otherwise
        error('Unknown bar_summary_stat: %s', bar_summary_stat);
end

if n_valid < 2
    sem_value = NaN;
else
    sem_value = std(values, 0) ./ sqrt(n_valid);
end

end


function fig_handle = plotMultiSessionRSCLocal( ...
        M, condition_group_width, bar_width_fraction, ...
        point_jitter_fraction, bar_alpha, point_alpha, point_size, ...
        error_line_width, error_cap_size, font_name, font_size, ...
        figure_visible)

mean_points = M.observations.mean_zscored_fisher;
sd_points = M.observations.sd_zscored_fisher;
mean_centers = M.plot_summary.mean_panel.bar_center;
mean_sem = M.plot_summary.mean_panel.sem;
sd_centers = M.plot_summary.sd_panel.bar_center;
sd_sem = M.plot_summary.sd_panel.sem;

condition_labels = M.labels.conditions;
pair_type_names = M.labels.pair_types;
condition_colors = M.colors.conditions;

num_conditions = numel(condition_labels);
num_pair_types = numel(pair_type_names);

if size(mean_points, 2) ~= num_conditions || ...
        size(mean_points, 3) ~= num_pair_types || ...
        ~isequal(size(mean_points), size(sd_points))
    error('Observation-array dimensions are incompatible with plot labels.');
end

condition_spacing = condition_group_width / num_conditions;
condition_offsets = ...
    ((1:num_conditions) - (num_conditions + 1) / 2) .* ...
    condition_spacing;
bar_width = condition_spacing * bar_width_fraction;
point_jitter_width = bar_width * point_jitter_fraction;

fig_handle = figure( ...
    'Color', 'w', ...
    'Visible', figure_visible, ...
    'Position', [80, 100, 1580, 800], ...
    'Name', 'Across-session r_sc summary');

tl = tiledlayout(fig_handle, 1, 2, ...
    'Padding', 'compact', 'TileSpacing', 'compact');
ax_mean = nexttile(tl, 1);
ax_sd = nexttile(tl, 2);
hold(ax_mean, 'on');
hold(ax_sd, 'on');

for p = 1:num_pair_types
    for c = 1:num_conditions
        x0 = p + condition_offsets(c);
        this_color = condition_colors(c, :);

        drawBarPointsSEMLocal( ...
            ax_mean, x0, mean_points(:, c, p), ...
            mean_centers(c, p), mean_sem(c, p), ...
            bar_width, point_jitter_width, this_color, ...
            bar_alpha, point_alpha, point_size, ...
            error_line_width, error_cap_size);

        drawBarPointsSEMLocal( ...
            ax_sd, x0, sd_points(:, c, p), ...
            sd_centers(c, p), sd_sem(c, p), ...
            bar_width, point_jitter_width, this_color, ...
            bar_alpha, point_alpha, point_size, ...
            error_line_width, error_cap_size);
    end
end

yline(ax_mean, 0, ':', ...
    'Color', [0.42, 0.42, 0.42], ...
    'LineWidth', 0.85, ...
    'HandleVisibility', 'off');

formatSummaryAxisLocal( ...
    ax_mean, pair_type_names, ...
    'Mean z-scored Fisher r_{sc}', ...
    'Mean of condition-wise pair distribution', ...
    font_name, font_size);
formatSummaryAxisLocal( ...
    ax_sd, pair_type_names, ...
    'SD of z-scored Fisher r_{sc}', ...
    'SD of condition-wise pair distribution', ...
    font_name, font_size);

legend_handles = gobjects(1, num_conditions);
for c = 1:num_conditions
    legend_handles(c) = scatter( ...
        ax_mean, nan, nan, point_size, 'o', ...
        'MarkerEdgeColor', condition_colors(c, :), ...
        'MarkerFaceColor', condition_colors(c, :), ...
        'LineWidth', 0.8);
end

lgd = legend(ax_mean, legend_handles, condition_labels, ...
    'Location', 'southoutside', ...
    'Orientation', 'horizontal', ...
    'NumColumns', min(4, num_conditions), ...
    'Box', 'off', ...
    'FontName', font_name, ...
    'FontSize', font_size - 1, ...
    'Interpreter', 'none');
lgd.Layout.Tile = 'south';

title_text = sprintf([ ...
    'Across-session noise correlation | %d sessions, %d direction ', ...
    'observations | bar: %s, error: SEM'], ...
    M.meta.num_sessions, M.meta.num_observations, ...
    M.meta.bar_summary_stat);
sgtitle(tl, title_text, ...
    'Interpreter', 'none', ...
    'FontName', font_name, ...
    'FontSize', font_size + 1);

end


function drawBarPointsSEMLocal( ...
        ax, x0, point_values, center_value, sem_value, ...
        bar_width, point_jitter_width, color_value, ...
        bar_alpha, point_alpha, point_size, ...
        error_line_width, error_cap_size)

if isfinite(center_value)
    x_left = x0 - bar_width / 2;
    x_right = x0 + bar_width / 2;

    hbar = patch(ax, ...
        [x_left, x_right, x_right, x_left], ...
        [0, 0, center_value, center_value], ...
        color_value, ...
        'EdgeColor', color_value, ...
        'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
    try
        hbar.FaceAlpha = bar_alpha;
    catch
    end

    if isfinite(sem_value)
        errorbar(ax, x0, center_value, sem_value, sem_value, ...
            'Color', [0.12, 0.12, 0.12], ...
            'LineStyle', 'none', ...
            'LineWidth', error_line_width, ...
            'CapSize', error_cap_size, ...
            'HandleVisibility', 'off');
    end
end

point_values = point_values(:);
point_values = point_values(isfinite(point_values));
num_points = numel(point_values);

if num_points < 1
    return;
elseif num_points == 1 || point_jitter_width == 0
    jitter = zeros(num_points, 1);
else
    jitter = linspace( ...
        -point_jitter_width / 2, point_jitter_width / 2, ...
        num_points)';
end

hpoints = scatter(ax, x0 + jitter, point_values, point_size, 'o', ...
    'MarkerEdgeColor', color_value, ...
    'MarkerFaceColor', color_value, ...
    'LineWidth', 0.75, ...
    'HandleVisibility', 'off');
try
    hpoints.MarkerFaceAlpha = point_alpha;
    hpoints.MarkerEdgeAlpha = point_alpha;
catch
end

end


function formatSummaryAxisLocal( ...
        ax, pair_type_names, y_label, panel_title, ...
        font_name, font_size)

num_pair_types = numel(pair_type_names);
set(ax, ...
    'XLim', [0.45, num_pair_types + 0.55], ...
    'XTick', 1:num_pair_types, ...
    'XTickLabel', pair_type_names, ...
    'TickLabelInterpreter', 'none', ...
    'FontName', font_name, ...
    'FontSize', font_size, ...
    'LineWidth', 1, ...
    'Layer', 'top', ...
    'Box', 'on', ...
    'YGrid', 'on', ...
    'XGrid', 'off', ...
    'GridAlpha', 0.16);

xlabel(ax, 'Neuron-pair type', ...
    'FontName', font_name, 'FontSize', font_size);
ylabel(ax, y_label, ...
    'Interpreter', 'tex', ...
    'FontName', font_name, 'FontSize', font_size);
title(ax, panel_title, ...
    'FontName', font_name, 'FontSize', font_size + 1);

end


function output = ternaryTextLocal(condition, true_text, false_text)

if condition
    output = true_text;
else
    output = false_text;
end

end
