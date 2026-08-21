%% sum_GPL_index_by_area.m
% Pool area-specific GPL selectivity and pattern/component indices across
% sessions using an explicit model-group/probe/area mapping.
% Revision: 2026-08-20b
%
% Run GPL_analysis_by_area.m first for every session/probe. This script reads
% the resulting probe-level unit_gpl_results.mat or
% unit_gpl_results_sponsub.mat files and extracts each model group from
% gpl_results.group using gpl_results.group_indices.
%
% The following independent figures are generated:
%   1) one pooled OSI distribution containing all requested model groups;
%   2) one pooled direction-selectivity-index distribution containing all
%      requested model groups;
%   3) one pattern/component Fisher-Z scatter and PI distribution per group.
%
% OSI and DSI means are marked by short colored arrows above the bars.
% OSI/DSI legends report each group's valid neuron count; each PI panel
% reports its own group's valid PI neuron count in black in the upper-right
% corner. Pattern-index means are saved but are not drawn.
%
% Plot encoding:
%   color = model group;
%   marker shape in the Fisher-Z scatter = GPL class:
%       pattern       : circle
%       component     : square
%       unclassified  : upward triangle
%
% Every neuron is pooled directly. Session identity is saved in the MAT
% output but is intentionally not encoded by color shade in any figure.
% Invalid GPL-classification neurons remain in the saved alignment data but
% are excluded from the Fisher-Z scatter and PI distribution.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';

% -------------------------------------------------------------------------
% GPL result selection and explicit model-group mapping
% -------------------------------------------------------------------------

% Array position is the model-group index. For example:
%   Group 1 -> probe 0 -> V1
%   Group 2 -> probe 0 -> V2
%   Group 3 -> probe 1 -> V1
% The mapping must match the one used by GPL_analysis_by_area.m.
group_probes = [0, 1];
group_names = {'V1', 'MT'};

% Must match subtract_spontaneous in GPL_analysis_by_area.m.
subtract_spontaneous = true;

% -------------------------------------------------------------------------
% Saving and figure settings
% -------------------------------------------------------------------------

save_mat = true;

% save_figure controls both MATLAB FIG and vector SVG output.
save_figure = true;

figure_visible = 'on';             % 'on' or 'off'
close_after_save = true;

% One RGB row per model group.
group_colors = [
    0.0000, 0.4470, 0.7410;
    0.8500, 0.3250, 0.0980;
];

font_name = 'Arial';
axis_font_size = 9;
legend_font_size = 9;
axis_line_width = 0.9;

% -------------------------------------------------------------------------
% OSI and direction-selectivity distribution settings
% -------------------------------------------------------------------------

% OSI uses narrower bins than DSI. All group bars together occupy this
% fraction of each bin, so 0.96 leaves only a small gap between neighboring
% bin groups while keeping the model groups side by side.
osi_bin_edges = 0:0.05:1;
dsi_bin_edges = 0:0.10:1;
distribution_bin_fill_fraction = 0.96;
distribution_bar_alpha = 0.88;

% GPL_analysis.m uses a final >1.6 category for spontaneous-subtracted DI.
use_di_upper_overflow = true;
di_regular_max_sponsub = 1.6;

% Mean is shown by a short colored arrow at the mean x position, with the
% numeric mean written beside the arrow.
show_distribution_mean = true;

mean_line_width = 1.45;
mean_value_decimal_places = 2;

% One row per model group. Each row is [arrow start, arrow tip, text] as a
% fraction of the y-axis upper limit. The program automatically reserves
% enough vertical space above the bars for the lowest arrow.
distribution_mean_arrow_y_fraction = [
    0.94, 0.84, 0.97;
    0.78, 0.68, 0.81
];

% Keep the group-count legend inside the distribution axes so the figure
% does not reserve extra space on the right.
distribution_legend_location = 'northeast';
distribution_figure_size_inches = [6.7, 4.2];

% Axis wording requested for the summary. The stored GPL field remains DI.
direction_index_axis_label = 'Direction selectivity index (DSI)';

% -------------------------------------------------------------------------
% Pattern/component settings
% -------------------------------------------------------------------------

class_names = {'pattern', 'component', 'unclassified'};
class_display_names = {'Pattern', 'Component', 'Unclassified'};
class_markers = {'o', 's', '^'};

class_scatter_size = 34;
class_scatter_alpha = 0.68;
class_scatter_line_width = 0.70;

class_boundary_line_style = '--';
class_boundary_line_width = 1.0;

% Empty means determine one shared limit from all groups.
z_axis_limits = [];
pi_axis_limits = [];

pi_num_bins = 12;
pi_bar_width = 0.82;
pi_bar_alpha = 0.88;

show_pattern_index_neuron_count = true;

% Match the useful lower-right placement of the original GPL_analysis
% pattern/component scatter legend, but make the location deterministic.
class_legend_location = 'southeast';
pattern_figure_size_inches = [9.3, 4.0];

%% ======================== FIXED INPUT RULES ===========================
% These are safety rules, not routine user options:
%   - scan kilosort* immediately below each requested probe directory;
%   - allow exactly one GPL result file per session/probe;
%   - load each probe-level MAT only once even if it contains several groups;
%   - accept a session only when all requested groups are valid;
%   - require matching numeric GPL analysis/classification metadata across
%     accepted files;
%   - do not require gpl_stim_tag, target_stim_tag, or baseline_stim_tag to
%     match across sessions. Each file's tags are retained only as metadata.

kilosort_folder_pattern = 'kilosort*';
metadata_numeric_tolerance = 1e-10;

%% ======================== VALIDATE SETTINGS ============================

if ~isfolder(root_dir)
    error('root_dir does not exist: %s', root_dir);
end

group_names = normalizeTextCellLocal(group_names, 'group_names');
group_probes = double(group_probes(:)');
nGroups = numel(group_names);

if nGroups == 0 || numel(group_probes) ~= nGroups
    error('group_probes and group_names must have the same nonzero length.');
end

if any(~isfinite(group_probes)) || any(group_probes < 0) || ...
        any(group_probes ~= round(group_probes))
    error(['group_probes must contain finite nonnegative integer probe IDs. ', ...
        'Repeated probe IDs are allowed.']);
end

for g = 1:nGroups
    duplicate_pair = group_probes(1:g-1) == group_probes(g) & ...
        strcmp(group_names(1:g-1), group_names{g});
    if any(duplicate_pair)
        error(['The same probe/area pair appears more than once: probe %d, ', ...
            'area %s.'], group_probes(g), group_names{g});
    end
end

validateattributes(group_colors, {'numeric'}, ...
    {'size', [nGroups, 3], '>=', 0, '<=', 1}, ...
    mfilename, 'group_colors');

validateLogicalScalarLocal(subtract_spontaneous, 'subtract_spontaneous');
validateLogicalScalarLocal(save_mat, 'save_mat');
validateLogicalScalarLocal(save_figure, 'save_figure');
validateLogicalScalarLocal(close_after_save, 'close_after_save');
validateLogicalScalarLocal(use_di_upper_overflow, ...
    'use_di_upper_overflow');
validateLogicalScalarLocal(show_distribution_mean, ...
    'show_distribution_mean');
validateLogicalScalarLocal(show_pattern_index_neuron_count, ...
    'show_pattern_index_neuron_count');

subtract_spontaneous = logical(subtract_spontaneous);
save_mat = logical(save_mat);
save_figure = logical(save_figure);
close_after_save = logical(close_after_save);
use_di_upper_overflow = logical(use_di_upper_overflow);
show_distribution_mean = logical(show_distribution_mean);
show_pattern_index_neuron_count = ...
    logical(show_pattern_index_neuron_count);

if ~any(strcmpi(char(figure_visible), {'on', 'off'}))
    error('figure_visible must be ''on'' or ''off''.');
end
figure_visible = lower(char(figure_visible));

osi_bin_edges = validateUniformBinEdgesLocal( ...
    osi_bin_edges, 'osi_bin_edges', metadata_numeric_tolerance);
dsi_bin_edges = validateUniformBinEdgesLocal( ...
    dsi_bin_edges, 'dsi_bin_edges', metadata_numeric_tolerance);

validateattributes(distribution_bin_fill_fraction, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<=', 1}, ...
    mfilename, 'distribution_bin_fill_fraction');
validateattributes(distribution_bar_alpha, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
    mfilename, 'distribution_bar_alpha');
validateattributes(di_regular_max_sponsub, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'di_regular_max_sponsub');
validateattributes(metadata_numeric_tolerance, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'}, ...
    mfilename, 'metadata_numeric_tolerance');
validateattributes(pi_num_bins, {'numeric'}, ...
    {'scalar', 'integer', 'finite', '>=', 3}, ...
    mfilename, 'pi_num_bins');
validateattributes(mean_value_decimal_places, {'numeric'}, ...
    {'scalar', 'integer', 'finite', '>=', 0, '<=', 6}, ...
    mfilename, 'mean_value_decimal_places');
validateattributes(distribution_mean_arrow_y_fraction, {'numeric'}, ...
    {'size', [nGroups, 3], 'real', 'finite', '>=', 0, '<=', 1}, ...
    mfilename, 'distribution_mean_arrow_y_fraction');
if any(distribution_mean_arrow_y_fraction(:, 1) <= ...
        distribution_mean_arrow_y_fraction(:, 2)) || ...
        any(distribution_mean_arrow_y_fraction(:, 3) < ...
        distribution_mean_arrow_y_fraction(:, 1))
    error(['Each distribution_mean_arrow_y_fraction row must be ' ...
        '[start, tip, text], with start > tip and text >= start.']);
end

if numel(class_names) ~= 3 || ...
        numel(class_display_names) ~= 3 || ...
        numel(class_markers) ~= 3
    error(['class_names, class_display_names, and class_markers must each ' ...
        'contain pattern, component, and unclassified entries.']);
end

class_names = normalizeTextCellLocal(class_names, 'class_names');
class_display_names = normalizeTextCellLocal( ...
    class_display_names, 'class_display_names');
class_markers = normalizeTextCellLocal(class_markers, 'class_markers');

z_axis_limits = validateOptionalAxisLimitsLocal( ...
    z_axis_limits, 'z_axis_limits');
pi_axis_limits = validateOptionalAxisLimitsLocal( ...
    pi_axis_limits, 'pi_axis_limits');

group_file_tags = cell(1, nGroups);
group_display_names = cell(1, nGroups);
for g = 1:nGroups
    group_file_tags{g} = sprintf('Group%d_%s', ...
        g, makeSafeFileTagLocal(group_names{g}));
    group_display_names{g} = sprintf('Group %d: %s', ...
        g, group_names{g});
end

mapping_file_tag = strjoin(group_file_tags, '_');

if subtract_spontaneous
    gpl_mat_name = 'unit_gpl_results_sponsub.mat';
    result_mode_tag = 'sponsub';
else
    gpl_mat_name = 'unit_gpl_results.mat';
    result_mode_tag = 'raw';
end

group_out_prefix = sprintf('sum_GPL_index_by_area_%s', result_mode_tag);
out_base = sprintf('%s_%s', ...
    group_out_prefix, mapping_file_tag);

fprintf('Root dir                    : %s\n', root_dir);
fprintf('GPL input file               : %s\n', gpl_mat_name);
fprintf('Spontaneous subtraction      : %d\n', subtract_spontaneous);
fprintf('Requested model groups:\n');
for g = 1:nGroups
    fprintf('  Group %d -> probe %d -> %s\n', ...
        g, group_probes(g), group_names{g});
end
fprintf('Require all groups/session   : 1\n');
fprintf('Require matching numeric metadata: 1\n');
fprintf('Require matching stim tags       : 0\n');
fprintf('Output base                  : %s\n', out_base);

%% ======================= FIND SESSION FOLDERS ==========================

session_dirs = findCatgtSessionDirsLocal(root_dir);

if isempty(session_dirs)
    error('No catgt_* session folders were found under root_dir: %s', ...
        root_dir);
end

num_session_candidates = numel(session_dirs);
session_map = repmat(struct( ...
    'session_index', [], ...
    'session_label', '', ...
    'session_name', '', ...
    'session_dir', '', ...
    'included', false), num_session_candidates, 1);

for si = 1:num_session_candidates
    [~, catgt_name] = fileparts(session_dirs{si});
    parent_dir = fileparts(session_dirs{si});
    [~, session_name] = fileparts(parent_dir);

    session_map(si).session_index = si;
    session_map(si).session_label = sprintf('S%d', si);
    session_map(si).session_name = session_name;
    session_map(si).session_dir = session_dirs{si};

    if isempty(session_name)
        session_map(si).session_name = catgt_name;
    end
end

fprintf('Found %d candidate catgt_* session folders.\n', ...
    num_session_candidates);

%% ======================== READ ALL SESSIONS ============================

records = struct([]);
reference_metadata = struct([]);

skipped_sessions = struct( ...
    'session_index', {}, ...
    'session_name', {}, ...
    'session_dir', {}, ...
    'reason', {});

skipped_files = struct( ...
    'session_index', {}, ...
    'session_name', {}, ...
    'group_index', {}, ...
    'group_name', {}, ...
    'input_file', {}, ...
    'reason', {});

requested_unique_probes = unique(group_probes, 'stable');

for si = 1:num_session_candidates

    session_dir = session_dirs{si};
    session_name = session_map(si).session_name;
    session_label = session_map(si).session_label;

    fprintf('\n[%d/%d] Reading %s (%s)\n', ...
        si, num_session_candidates, session_name, session_label);

    session_records = struct([]);
    group_record_count = zeros(1, nGroups);
    session_reasons = {};
    local_reference = reference_metadata;

    for probe_list_idx = 1:numel(requested_unique_probes)

        probe_id = requested_unique_probes(probe_list_idx);
        probe_group_indices = find(group_probes == probe_id);
        probe_group_text = strjoin( ...
            group_display_names(probe_group_indices), ', ');

        try
            input_files = findGPLFilesForProbeLocal( ...
                session_dir, probe_id, kilosort_folder_pattern, ...
                gpl_mat_name);
        catch ME
            input_files = {};
            session_reasons{end + 1} = sprintf( ...
                'probe %d (%s): %s', ...
                probe_id, probe_group_text, ME.message); %#ok<SAGROW>
        end

        if isempty(input_files)
            if ~any(contains(session_reasons, ...
                    sprintf('probe %d (', probe_id)))
                session_reasons{end + 1} = sprintf( ...
                    'probe %d (%s): no %s file found', ...
                    probe_id, probe_group_text, gpl_mat_name); %#ok<SAGROW>
            end
            continue;
        end

        fprintf('  Probe %d, groups %s: %d input file(s)\n', ...
            probe_id, mat2str(probe_group_indices), numel(input_files));

        for fi = 1:numel(input_files)

            input_file = input_files{fi};

            try
                [probe_records, probe_metadata] = ...
                    readOneGPLProbeFileLocal( ...
                    input_file, ...
                    si, session_label, session_name, session_dir, ...
                    probe_group_indices, group_probes, group_names, ...
                    probe_id, subtract_spontaneous);

                candidate_reference = local_reference;
                for rr = 1:numel(probe_records)
                    if isempty(candidate_reference)
                        candidate_reference = probe_metadata(rr);
                    else
                        assertMatchingNonTagMetadataLocal( ...
                            probe_metadata(rr), candidate_reference, ...
                            metadata_numeric_tolerance, input_file);
                    end
                end

                local_reference = candidate_reference;

                if isempty(session_records)
                    session_records = probe_records(:);
                else
                    first_new = numel(session_records) + 1;
                    session_records( ...
                        first_new:first_new + numel(probe_records) - 1, 1) = ...
                        probe_records(:);
                end

                for rr = 1:numel(probe_records)
                    rec = probe_records(rr);
                    g = rec.group_index;
                    group_record_count(g) = group_record_count(g) + 1;

                    fprintf(['    loaded %s | neurons %d | valid OSI %d | ' ...
                        'valid DSI %d | P/C/U/I = %d/%d/%d/%d\n'], ...
                        group_display_names{g}, ...
                        rec.n_neurons, ...
                        sum(isfinite(rec.OSI)), ...
                        sum(isfinite(rec.DI)), ...
                        sum(rec.is_pattern), ...
                        sum(rec.is_component), ...
                        sum(rec.is_unclassified), ...
                        sum(rec.is_invalid));

                    if any(rec.is_invalid)
                        warning(['%d invalid GPL-classification neuron(s) ', ...
                            'for %s in %s. They will be excluded from the ', ...
                            'Fisher-Z and PI plots.'], ...
                            sum(rec.is_invalid), ...
                            group_display_names{g}, input_file);
                    end
                end

            catch ME
                for gg = reshape(probe_group_indices, 1, [])
                    skipped_files(end + 1) = makeSkippedFileLocal( ...
                        si, session_name, gg, group_names{gg}, ...
                        input_file, ME.message); %#ok<SAGROW>
                end

                session_reasons{end + 1} = sprintf( ...
                    'probe %d (%s): %s', ...
                    probe_id, probe_group_text, ME.message); %#ok<SAGROW>

                warning('Skipping probe-level GPL file: %s\nReason: %s', ...
                    input_file, ME.message);
            end
        end
    end

    for g = 1:nGroups
        if group_record_count(g) == 0
            session_reasons{end + 1} = sprintf( ...
                '%s / probe %d has no valid GPL group result', ...
                group_display_names{g}, group_probes(g)); %#ok<SAGROW>
        elseif group_record_count(g) > 1
            session_reasons{end + 1} = sprintf( ...
                '%s has %d GPL group records; expected exactly one', ...
                group_display_names{g}, group_record_count(g)); %#ok<SAGROW>
        end
    end

    reject_session = isempty(session_records) || ...
        any(group_record_count ~= 1);

    if reject_session
        if isempty(session_reasons)
            session_reasons = {'no valid GPL records'};
        end

        reason = strjoin(unique(session_reasons, 'stable'), ' | ');
        skipped_sessions(end + 1) = makeSkippedSessionLocal( ...
            si, session_name, session_dir, reason); %#ok<SAGROW>

        warning('Skipping session %s: %s', session_name, reason);
        continue;
    end

    if isempty(records)
        records = session_records(:);
    else
        first_new = numel(records) + 1;
        records(first_new:first_new + numel(session_records) - 1, 1) = ...
            session_records(:);
    end

    if isempty(reference_metadata)
        reference_metadata = local_reference;
    end

    session_map(si).included = true;
end

if isempty(records)
    error('No valid GPL result files were loaded.');
end

included_session_indices = find([session_map.included]);

fprintf('\nLoaded %d GPL group record(s) from %d session(s).\n', ...
    numel(records), numel(included_session_indices));
fprintf('Skipped %d session(s) and %d input file(s).\n', ...
    numel(skipped_sessions), numel(skipped_files));

%% ======================= BUILD POOLED VALUES ===========================

group_pool_cell = cell(1, nGroups);

for g = 1:nGroups
    this_pool = buildOneGroupPoolLocal( ...
        records, g, group_names{g}, group_probes(g));
    this_pool.group_display_name = group_display_names{g};
    this_pool.group_file_tag = group_file_tags{g};

    if isempty(this_pool.unit_id)
        error('No neurons were pooled for %s.', group_names{g});
    end

    group_pool_cell{g} = this_pool;

    fprintf(['%s pooled neurons: %d | sessions: %d | valid OSI: %d | ' ...
        'valid DSI: %d | P/C/U/I: %d/%d/%d/%d\n'], ...
        group_display_names{g}, ...
        numel(this_pool.unit_id), ...
        numel(unique(this_pool.session_index)), ...
        sum(isfinite(this_pool.OSI)), ...
        sum(isfinite(this_pool.DI)), ...
        sum(this_pool.is_pattern), ...
        sum(this_pool.is_component), ...
        sum(this_pool.is_unclassified), ...
        sum(this_pool.is_invalid));
end

group_pool = [group_pool_cell{:}];
clear group_pool_cell this_pool;

warnRepeatedUnitIdsLocal(group_pool, group_display_names);

osi_values = cell(1, nGroups);
di_values = cell(1, nGroups);
for g = 1:nGroups
    osi_values{g} = group_pool(g).OSI;
    di_values{g} = group_pool(g).DI;
end

osi_distribution = buildMultiGroupDistributionLocal( ...
    osi_values, osi_bin_edges, []);

if subtract_spontaneous && use_di_upper_overflow
    di_overflow_limit = di_regular_max_sponsub;
else
    di_overflow_limit = [];
end

di_distribution = buildMultiGroupDistributionLocal( ...
    di_values, dsi_bin_edges, di_overflow_limit);

[z_limits_shared, pi_limits_shared, pi_edges_shared] = ...
    determinePatternAxesLocal( ...
    group_pool, z_axis_limits, pi_axis_limits, pi_num_bins);

pi_distribution = buildPIDistributionLocal( ...
    group_pool, pi_edges_shared);

pi_y_max = max(pi_distribution.probability(:));
if isempty(pi_y_max) || ~isfinite(pi_y_max) || pi_y_max <= 0
    pi_y_limits_shared = [0, 0.1];
else
    pi_y_limits_shared = [0, 1.12 * pi_y_max];
end

%% =========================== OUTPUT STRUCT =============================

GPLIndexSummary = struct();

GPLIndexSummary.meta = struct();
GPLIndexSummary.meta.program = 'sum_GPL_index_by_area.m';
GPLIndexSummary.meta.revision = '2026-08-20b';
GPLIndexSummary.meta.root_dir = root_dir;
GPLIndexSummary.meta.gpl_mat_name = gpl_mat_name;
GPLIndexSummary.meta.subtract_spontaneous = subtract_spontaneous;
GPLIndexSummary.meta.num_groups = nGroups;
GPLIndexSummary.meta.group_probes = group_probes;
GPLIndexSummary.meta.group_names = group_names;
GPLIndexSummary.meta.group_display_names = group_display_names;
GPLIndexSummary.meta.group_file_tags = group_file_tags;
GPLIndexSummary.meta.mapping_file_tag = mapping_file_tag;
GPLIndexSummary.meta.output_base = out_base;
GPLIndexSummary.meta.class_names = class_names;
GPLIndexSummary.meta.class_markers = class_markers;
GPLIndexSummary.meta.direction_index_source_field = ...
    'gpl_results.group(local_group_index).grating.DI';
GPLIndexSummary.meta.direction_index_display_name = 'DSI';
GPLIndexSummary.meta.require_all_groups_per_session = true;
GPLIndexSummary.meta.require_matching_metadata = true;
GPLIndexSummary.meta.require_matching_stim_tags = false;
GPLIndexSummary.meta.tag_handling = [ ...
    'gpl_stim_tag, target_stim_tag, and baseline_stim_tag are retained ' ...
    'per record but are not compared across files or sessions'];
GPLIndexSummary.meta.multiple_gpl_file_action = 'error';
GPLIndexSummary.meta.metadata_numeric_tolerance = ...
    metadata_numeric_tolerance;
GPLIndexSummary.meta.num_session_folders_found = ...
    num_session_candidates;
GPLIndexSummary.meta.num_sessions_included = ...
    numel(included_session_indices);
GPLIndexSummary.meta.num_sessions_skipped = ...
    numel(skipped_sessions);
GPLIndexSummary.meta.num_group_records_loaded = numel(records);
GPLIndexSummary.meta.num_probe_files_loaded = ...
    numel(unique({records.input_file}, 'stable'));
GPLIndexSummary.meta.num_skipped_group_file_records = numel(skipped_files);
% Retain the old field name for scripts that already read this summary.
GPLIndexSummary.meta.num_record_files_skipped = numel(skipped_files);
GPLIndexSummary.meta.session_visual_encoding = ...
    'none; neurons are pooled directly within each group';

GPLIndexSummary.reference_metadata = reference_metadata;
GPLIndexSummary.session_map = session_map;
GPLIndexSummary.included_session_indices = included_session_indices(:);
GPLIndexSummary.records = records;
GPLIndexSummary.skipped_sessions = skipped_sessions;
GPLIndexSummary.skipped_files = skipped_files;
GPLIndexSummary.group = group_pool;

GPLIndexSummary.distribution = struct();
GPLIndexSummary.distribution.OSI = osi_distribution;
GPLIndexSummary.distribution.DI = di_distribution;
GPLIndexSummary.distribution.PI = pi_distribution;

GPLIndexSummary.plot = struct();
GPLIndexSummary.plot.group_colors = group_colors;
GPLIndexSummary.plot.osi_bin_edges = osi_bin_edges;
GPLIndexSummary.plot.dsi_bin_edges = dsi_bin_edges;
GPLIndexSummary.plot.distribution_bin_fill_fraction = ...
    distribution_bin_fill_fraction;
GPLIndexSummary.plot.di_overflow_limit = di_overflow_limit;
GPLIndexSummary.plot.z_axis_limits_shared = z_limits_shared;
GPLIndexSummary.plot.pi_axis_limits_shared = pi_limits_shared;
GPLIndexSummary.plot.pi_bin_edges_shared = pi_edges_shared;
GPLIndexSummary.plot.pi_y_limits_shared = pi_y_limits_shared;
GPLIndexSummary.plot.mean_value_decimal_places = ...
    mean_value_decimal_places;
GPLIndexSummary.plot.distribution_mean_arrow_y_fraction = ...
    distribution_mean_arrow_y_fraction;
GPLIndexSummary.plot.show_distribution_mean = ...
    show_distribution_mean;
GPLIndexSummary.plot.show_pattern_index_neuron_count = ...
    show_pattern_index_neuron_count;

mat_file = fullfile(root_dir, [out_base, '_summary.mat']);

osi_base = fullfile(root_dir, [out_base, '_OSI_distribution']);
dsi_base = fullfile(root_dir, [out_base, '_DSI_distribution']);

pattern_bases = cell(1, nGroups);
for g = 1:nGroups
    pattern_bases{g} = fullfile(root_dir, sprintf( ...
        '%s_%s_pattern_component', ...
        group_out_prefix, group_file_tags{g}));
end

GPLIndexSummary.output_files = struct();
GPLIndexSummary.output_files.mat = mat_file;
GPLIndexSummary.output_files.OSI_fig = [osi_base, '.fig'];
GPLIndexSummary.output_files.OSI_svg = [osi_base, '.svg'];
GPLIndexSummary.output_files.DSI_fig = [dsi_base, '.fig'];
GPLIndexSummary.output_files.DSI_svg = [dsi_base, '.svg'];
GPLIndexSummary.output_files.pattern_component = repmat( ...
    struct( ...
    'group_index', [], ...
    'probe_id', [], ...
    'group_name', '', ...
    'group_file_tag', '', ...
    'fig', '', ...
    'svg', ''), 1, nGroups);

for g = 1:nGroups
    GPLIndexSummary.output_files.pattern_component(g).group_index = g;
    GPLIndexSummary.output_files.pattern_component(g).probe_id = ...
        group_probes(g);
    GPLIndexSummary.output_files.pattern_component(g).group_name = ...
        group_names{g};
    GPLIndexSummary.output_files.pattern_component(g).group_file_tag = ...
        group_file_tags{g};
    GPLIndexSummary.output_files.pattern_component(g).fig = ...
        [pattern_bases{g}, '.fig'];
    GPLIndexSummary.output_files.pattern_component(g).svg = ...
        [pattern_bases{g}, '.svg'];
end

if save_mat
    save(mat_file, 'GPLIndexSummary', '-v7.3');
    fprintf('Saved MAT: %s\n', mat_file);
else
    fprintf('MAT saving is disabled.\n');
end

%% ============================== PLOT ===================================

figures = gobjects(2 + nGroups, 1);

figures(1) = plotMultiGroupDistributionLocal( ...
    osi_distribution, ...
    group_display_names, group_colors, ...
    'Orientation selectivity index (OSI)', ...
    figure_visible, distribution_figure_size_inches, ...
    distribution_bin_fill_fraction, distribution_bar_alpha, ...
    show_distribution_mean, ...
    mean_line_width, ...
    mean_value_decimal_places, ...
    distribution_mean_arrow_y_fraction, ...
    distribution_legend_location, ...
    font_name, axis_font_size, legend_font_size, axis_line_width);

figures(2) = plotMultiGroupDistributionLocal( ...
    di_distribution, ...
    group_display_names, group_colors, ...
    direction_index_axis_label, ...
    figure_visible, distribution_figure_size_inches, ...
    distribution_bin_fill_fraction, distribution_bar_alpha, ...
    show_distribution_mean, ...
    mean_line_width, ...
    mean_value_decimal_places, ...
    distribution_mean_arrow_y_fraction, ...
    distribution_legend_location, ...
    font_name, axis_font_size, legend_font_size, axis_line_width);

for g = 1:nGroups
    figures(2 + g) = plotOneGroupPatternComponentLocal( ...
        group_pool(g), ...
        group_display_names{g}, ...
        group_colors(g, :), ...
        class_names, class_display_names, class_markers, ...
        reference_metadata.pattern_z_threshold, ...
        z_limits_shared, ...
        pi_distribution.centers, ...
        pi_distribution.probability(:, g), ...
        pi_distribution.n(g), ...
        pi_limits_shared, pi_y_limits_shared, ...
        figure_visible, pattern_figure_size_inches, ...
        class_scatter_size, class_scatter_alpha, ...
        class_scatter_line_width, ...
        class_boundary_line_style, class_boundary_line_width, ...
        pi_bar_width, pi_bar_alpha, ...
        show_pattern_index_neuron_count, ...
        class_legend_location, ...
        font_name, axis_font_size, legend_font_size, axis_line_width);
end

if save_figure
    saveFigurePairLocal( ...
        figures(1), [osi_base, '.fig'], [osi_base, '.svg']);
    saveFigurePairLocal( ...
        figures(2), [dsi_base, '.fig'], [dsi_base, '.svg']);

    for g = 1:nGroups
        saveFigurePairLocal( ...
            figures(2 + g), ...
            [pattern_bases{g}, '.fig'], ...
            [pattern_bases{g}, '.svg']);
    end
else
    fprintf('Figure saving is disabled.\n');
end

if close_after_save
    close(figures(ishandle(figures)));
end

fprintf('\nDone.\n');

%% ========================================================================
% Local functions
% ========================================================================

function values = normalizeTextCellLocal(values, variable_name)

    if isstring(values)
        values = cellstr(values(:)');
    elseif ischar(values)
        if size(values, 1) == 1
            values = {values};
        else
            values = reshape(cellstr(values), 1, []);
        end
    elseif iscategorical(values)
        values = cellstr(string(values(:)'));
    elseif iscell(values)
        values = reshape(values, 1, []);
    else
        error('%s must be text or a cell array of text.', variable_name);
    end

    for k = 1:numel(values)
        if ~(ischar(values{k}) || ...
                (isstring(values{k}) && isscalar(values{k})))
            error('%s{%d} must contain text.', variable_name, k);
        end

        values{k} = strtrim(char(string(values{k})));

        if isempty(values{k})
            error('%s{%d} cannot be empty.', variable_name, k);
        end
    end
end

function validateLogicalScalarLocal(value, variable_name)

    if ~(islogical(value) || isnumeric(value)) || ...
            ~isscalar(value) || ~isfinite(double(value)) || ...
            ~ismember(double(value), [0, 1])
        error('%s must be one logical scalar.', variable_name);
    end
end

function edges = validateUniformBinEdgesLocal( ...
        edges, variable_name, tolerance)

    edges = double(edges(:)');

    if numel(edges) < 2 || any(~isfinite(edges)) || ...
            any(diff(edges) <= 0)
        error('%s must be strictly increasing and finite.', variable_name);
    end

    widths = diff(edges);
    reference_width = median(widths);

    if any(abs(widths - reference_width) > max(tolerance, 1e-12))
        error('%s must have constant spacing.', variable_name);
    end
end

function limits = validateOptionalAxisLimitsLocal(limits, variable_name)

    if isempty(limits)
        limits = [];
        return;
    end

    limits = double(limits(:)');

    if numel(limits) ~= 2 || any(~isfinite(limits)) || ...
            limits(2) <= limits(1)
        error('%s must be empty or a finite increasing two-value vector.', ...
            variable_name);
    end
end

function session_dirs = findCatgtSessionDirsLocal(root_dir)
% Recursively locate catgt_* folders and sort by the number after p in the
% parent session folder name. Alphabetical order breaks numeric ties.

    listing = dir(fullfile(root_dir, '**', 'catgt_*'));
    keep = [listing.isdir] & startsWith({listing.name}, 'catgt_');
    listing = listing(keep);

    session_dirs = cell(numel(listing), 1);

    for k = 1:numel(listing)
        session_dirs{k} = fullfile(listing(k).folder, listing(k).name);
    end

    if isempty(session_dirs)
        return;
    end

    session_dirs = unique(session_dirs, 'stable');
    lower_dirs = cellfun(@lower, session_dirs, 'UniformOutput', false);
    [~, alphabetical_order] = sort(lower_dirs);
    session_dirs = session_dirs(alphabetical_order);

    p_number = inf(numel(session_dirs), 1);

    for k = 1:numel(session_dirs)
        parent_dir = fileparts(session_dirs{k});
        [~, session_name] = fileparts(parent_dir);
        token = regexp(session_name, 'p(\d+)', 'tokens', 'once');

        if ~isempty(token)
            parsed = str2double(token{1});

            if isfinite(parsed)
                p_number(k) = parsed;
            end
        end
    end

    [~, numeric_order] = sort(p_number, 'ascend');
    session_dirs = session_dirs(numeric_order);
end

function input_files = findGPLFilesForProbeLocal( ...
        session_dir, probe_id, kilosort_folder_pattern, gpl_mat_name)

    [~, catgt_name] = fileparts(session_dir);
    run_g = regexprep(catgt_name, '^catgt_', '');

    if strcmp(run_g, catgt_name) || isempty(run_g)
        error('Session folder does not have a valid catgt_ prefix: %s', ...
            session_dir);
    end

    exact_probe_dir = fullfile( ...
        session_dir, sprintf('%s_imec%d', run_g, probe_id));

    if isfolder(exact_probe_dir)
        probe_dir = exact_probe_dir;
    else
        candidates = dir(fullfile( ...
            session_dir, sprintf('%s*_imec%d', run_g, probe_id)));
        candidates = candidates([candidates.isdir]);

        if isempty(candidates)
            error('Probe directory not found under %s for imec%d.', ...
                session_dir, probe_id);
        end

        if numel(candidates) > 1
            names = strjoin({candidates.name}, ', ');
            error('Multiple probe directories match imec%d: %s', ...
                probe_id, names);
        end

        probe_dir = fullfile(candidates(1).folder, candidates(1).name);
    end

    ks_listing = dir(fullfile(probe_dir, kilosort_folder_pattern));
    ks_listing = ks_listing([ks_listing.isdir]);

    if isempty(ks_listing)
        error('No %s directory found under %s.', ...
            kilosort_folder_pattern, probe_dir);
    end

    [~, order] = sort(lower({ks_listing.name}));
    ks_listing = ks_listing(order);

    input_files = {};

    for k = 1:numel(ks_listing)
        candidate = fullfile( ...
            ks_listing(k).folder, ks_listing(k).name, gpl_mat_name);

        if isfile(candidate)
            input_files{end + 1, 1} = candidate; %#ok<AGROW>
        end
    end

    if numel(input_files) > 1
        error(['Multiple GPL result files were found for probe %d. ' ...
            'The source is ambiguous:\n%s'], ...
            probe_id, strjoin(input_files, '\n'));
    end
end

function [records, metadata] = readOneGPLProbeFileLocal( ...
        input_file, ...
        session_index, session_label, session_name, session_dir, ...
        expected_group_indices, expected_group_probes, ...
        expected_group_names, expected_probe_id, ...
        expected_baseline_subtracted)
% Load one probe-level MAT once, validate the complete model mapping, and
% extract every requested model group stored for this probe.

    S = load(input_file, 'gpl_results');

    if ~isfield(S, 'gpl_results') || ~isstruct(S.gpl_results)
        error('%s does not contain a valid gpl_results struct.', input_file);
    end

    P = S.gpl_results;
    required_probe_fields = { ...
        'format_version', 'probe_id', ...
        'group_indices', 'group_probes', 'group_names', ...
        'model_group_indices', 'model_group_probes', ...
        'model_group_names', 'baseline_subtracted', 'group'};
    requireFieldsLocal(P, required_probe_fields, ...
        'probe-level gpl_results', input_file);

    if ~strcmp(char(string(P.format_version)), 'grouped_by_probe_v1')
        error(['Unsupported gpl_results.format_version in %s: %s. ', ...
            'Run GPL_analysis_by_area.m with grouped probe output.'], ...
            input_file, char(string(P.format_version)));
    end

    probe_id = double(P.probe_id);
    if ~isscalar(probe_id) || ~isfinite(probe_id) || ...
            probe_id ~= expected_probe_id
        error('Expected probe %d but probe-level gpl_results.probe_id is %s.', ...
            expected_probe_id, numericValueToTextLocal(probe_id));
    end

    n_groups = numel(expected_group_names);
    stored_model_indices = double(P.model_group_indices(:)');
    stored_model_probes = double(P.model_group_probes(:)');
    stored_model_names = normalizeTextCellLocal( ...
        P.model_group_names, 'gpl_results.model_group_names');

    if ~isequal(stored_model_indices, 1:n_groups)
        error(['gpl_results.model_group_indices does not equal 1:%d in %s.'], ...
            n_groups, input_file);
    end
    if ~isequal(stored_model_probes, double(expected_group_probes(:)'))
        error('The complete model group-probe mapping differs in %s.', ...
            input_file);
    end
    if ~isequal(stored_model_names, reshape(expected_group_names, 1, []))
        error('The complete model group-area mapping differs in %s.', ...
            input_file);
    end

    stored_group_indices = double(P.group_indices(:)');
    stored_group_probes = double(P.group_probes(:)');
    stored_group_names = normalizeTextCellLocal( ...
        P.group_names, 'gpl_results.group_names');
    expected_group_indices = double(expected_group_indices(:)');

    if ~isequal(stored_group_indices, expected_group_indices)
        error(['Probe %d should contain model groups %s, but %s stores %s.'], ...
            expected_probe_id, mat2str(expected_group_indices), ...
            input_file, mat2str(stored_group_indices));
    end
    if ~isequal(stored_group_probes, ...
            expected_group_probes(expected_group_indices))
        error('The probe-local group_probes mapping differs in %s.', ...
            input_file);
    end
    if ~isequal(stored_group_names, ...
            expected_group_names(expected_group_indices))
        error('The probe-local group_names mapping differs in %s.', ...
            input_file);
    end
    if numel(P.group) ~= numel(expected_group_indices)
        error(['gpl_results.group has %d entries but probe %d should ', ...
            'contain %d requested groups.'], ...
            numel(P.group), expected_probe_id, ...
            numel(expected_group_indices));
    end

    baseline_value = P.baseline_subtracted;
    if ~(islogical(baseline_value) || isnumeric(baseline_value)) || ...
            ~isscalar(baseline_value) || ...
            ~isfinite(double(baseline_value)) || ...
            ~ismember(double(baseline_value), [0, 1]) || ...
            logical(baseline_value) ~= expected_baseline_subtracted
        error(['Probe-level gpl_results.baseline_subtracted does not ', ...
            'match the requested mode in %s.'], input_file);
    end

    records = struct([]);
    metadata = struct([]);

    for local_idx = 1:numel(expected_group_indices)
        group_index = expected_group_indices(local_idx);
        matching_entry = find(stored_group_indices == group_index);

        if numel(matching_entry) ~= 1
            error(['Model group %d was not found exactly once in ', ...
                'gpl_results.group_indices for %s.'], ...
                group_index, input_file);
        end

        G = P.group(matching_entry);
        [this_record, this_metadata] = readOneGPLGroupStructLocal( ...
            G, input_file, ...
            session_index, session_label, session_name, session_dir, ...
            group_index, expected_group_names{group_index}, ...
            expected_probe_id, expected_baseline_subtracted);

        if isempty(records)
            records = this_record;
            metadata = this_metadata;
        else
            records(end + 1, 1) = this_record; %#ok<AGROW>
            metadata(end + 1, 1) = this_metadata; %#ok<AGROW>
        end
    end
end

function [rec, metadata] = readOneGPLGroupStructLocal( ...
        G, input_file, ...
        session_index, session_label, session_name, session_dir, ...
        group_index, expected_group_name, expected_probe_id, ...
        expected_baseline_subtracted)

    required_top = { ...
        'model_group_index', 'probe_id', 'group_name', 'area_name', ...
        'used_unit_ids', ...
        'gpl_stim_tag', 'target_stim_tag', ...
        'analysis_window', 'bin_size', ...
        'pattern_z_threshold', 'baseline_subtracted', ...
        'plaid_component_separation_deg', 'grating', 'plaid'};

    requireFieldsLocal(G, required_top, 'gpl_results', input_file);

    stored_group_index = double(G.model_group_index);
    if ~isscalar(stored_group_index) || ~isfinite(stored_group_index) || ...
            stored_group_index ~= group_index
        error(['Expected model group %d but the stored group entry has ', ...
            'model_group_index %s.'], ...
            group_index, numericValueToTextLocal(stored_group_index));
    end

    probe_id = double(G.probe_id);
    if ~isscalar(probe_id) || ~isfinite(probe_id) || ...
            probe_id ~= expected_probe_id
        error('Expected probe %d but gpl_results.probe_id is %s.', ...
            expected_probe_id, numericValueToTextLocal(probe_id));
    end

    stored_group_name = char(string(G.group_name));
    if ~strcmp(stored_group_name, expected_group_name)
        error('Expected %s but gpl_results.group_name is %s.', ...
            expected_group_name, stored_group_name);
    end

    stored_area_name = char(string(G.area_name));
    if ~strcmp(stored_area_name, expected_group_name)
        error('Expected area %s but gpl_results.area_name is %s.', ...
            expected_group_name, stored_area_name);
    end

    baseline_value = G.baseline_subtracted;
    if ~(islogical(baseline_value) || isnumeric(baseline_value)) || ...
            ~isscalar(baseline_value) || ...
            ~isfinite(double(baseline_value)) || ...
            ~ismember(double(baseline_value), [0, 1])
        error('gpl_results.baseline_subtracted must be one logical scalar.');
    end

    baseline_subtracted = logical(baseline_value);
    if baseline_subtracted ~= expected_baseline_subtracted
        error(['gpl_results.baseline_subtracted does not match the requested ' ...
            'mode for %s.'], input_file);
    end

    unit_ids = numericColumnLocal(G.used_unit_ids, ...
        'gpl_results.used_unit_ids', input_file);

    if isempty(unit_ids)
        error('gpl_results.used_unit_ids is empty in %s.', input_file);
    end

    if any(~isfinite(unit_ids)) || ...
            numel(unique(unit_ids)) ~= numel(unit_ids)
        error('used_unit_ids must be finite and unique in %s.', input_file);
    end

    n_neurons = numel(unit_ids);

    requireFieldsLocal(G.grating, {'DI', 'OSI'}, ...
        'gpl_results.grating', input_file);
    requireFieldsLocal(G.plaid, ...
        {'Zp', 'Zc', 'PI', ...
         'is_pattern', 'is_component', 'is_unclassified'}, ...
        'gpl_results.plaid', input_file);

    DI = requireLengthLocal(numericColumnLocal( ...
        G.grating.DI, 'gpl_results.grating.DI', input_file), ...
        n_neurons, 'gpl_results.grating.DI', input_file);

    OSI = requireLengthLocal(numericColumnLocal( ...
        G.grating.OSI, 'gpl_results.grating.OSI', input_file), ...
        n_neurons, 'gpl_results.grating.OSI', input_file);

    Zp = requireLengthLocal(numericColumnLocal( ...
        G.plaid.Zp, 'gpl_results.plaid.Zp', input_file), ...
        n_neurons, 'gpl_results.plaid.Zp', input_file);

    Zc = requireLengthLocal(numericColumnLocal( ...
        G.plaid.Zc, 'gpl_results.plaid.Zc', input_file), ...
        n_neurons, 'gpl_results.plaid.Zc', input_file);

    PI = requireLengthLocal(numericColumnLocal( ...
        G.plaid.PI, 'gpl_results.plaid.PI', input_file), ...
        n_neurons, 'gpl_results.plaid.PI', input_file);

    is_pattern = logicalColumnLocal( ...
        G.plaid.is_pattern, n_neurons, ...
        'gpl_results.plaid.is_pattern', input_file);
    is_component = logicalColumnLocal( ...
        G.plaid.is_component, n_neurons, ...
        'gpl_results.plaid.is_component', input_file);
    is_unclassified = logicalColumnLocal( ...
        G.plaid.is_unclassified, n_neurons, ...
        'gpl_results.plaid.is_unclassified', input_file);

    overlap_count = double(is_pattern) + ...
        double(is_component) + double(is_unclassified);

    if any(overlap_count > 1)
        error(['Stored GPL class masks overlap for %d neuron(s) in %s.'], ...
            sum(overlap_count > 1), input_file);
    end

    if isfield(G.plaid, 'is_invalid')
        stored_invalid = logicalColumnLocal( ...
            G.plaid.is_invalid, n_neurons, ...
            'gpl_results.plaid.is_invalid', input_file);
    else
        stored_invalid = false(n_neurons, 1);
    end

    finite_pattern_inputs = isfinite(Zp) & isfinite(Zc) & isfinite(PI);
    force_invalid = stored_invalid | ~finite_pattern_inputs;

    is_pattern(force_invalid) = false;
    is_component(force_invalid) = false;
    is_unclassified(force_invalid) = false;

    is_invalid = ~(is_pattern | is_component | is_unclassified);

    class_label = strings(n_neurons, 1);
    class_label(is_pattern) = 'pattern';
    class_label(is_component) = 'component';
    class_label(is_unclassified) = 'unclassified';
    class_label(is_invalid) = 'invalid';

    metadata = extractMetadataLocal(G, input_file);

    rec = struct();
    rec.session_index = session_index;
    rec.session_label = session_label;
    rec.session_name = session_name;
    rec.session_dir = session_dir;
    rec.group_index = group_index;
    rec.group_name = expected_group_name;
    rec.probe_id = expected_probe_id;
    rec.input_file = input_file;
    rec.kilosort_dir = fileparts(input_file);
    rec.n_neurons = n_neurons;
    rec.unit_ids = unit_ids;
    rec.DI = DI;
    rec.OSI = OSI;
    rec.Zp = Zp;
    rec.Zc = Zc;
    rec.PI = PI;
    rec.is_pattern = is_pattern;
    rec.is_component = is_component;
    rec.is_unclassified = is_unclassified;
    rec.is_invalid = is_invalid;
    rec.class_label = class_label;
    rec.metadata = metadata;
end

function requireFieldsLocal(S, required_fields, structure_name, input_file)

    if ~isstruct(S)
        error('%s is not a struct in %s.', structure_name, input_file);
    end

    for k = 1:numel(required_fields)
        if ~isfield(S, required_fields{k})
            error('%s is missing field %s in %s.', ...
                structure_name, required_fields{k}, input_file);
        end
    end
end

function values = numericColumnLocal(values, field_name, input_file)

    if ~(isnumeric(values) || islogical(values))
        error('%s must be numeric in %s.', field_name, input_file);
    end

    values = double(values(:));
end

function values = requireLengthLocal( ...
        values, required_length, field_name, input_file)

    if numel(values) ~= required_length
        error('%s has %d values; expected %d in %s.', ...
            field_name, numel(values), required_length, input_file);
    end
end

function mask = logicalColumnLocal( ...
        values, required_length, field_name, input_file)

    if ~(islogical(values) || isnumeric(values))
        error('%s must be logical or numeric in %s.', ...
            field_name, input_file);
    end

    values = values(:);

    if numel(values) ~= required_length
        error('%s has %d values; expected %d in %s.', ...
            field_name, numel(values), required_length, input_file);
    end

    if isnumeric(values) && ...
            (any(~isfinite(values)) || any(~ismember(values, [0, 1])))
        error('%s must contain only 0/1 values in %s.', ...
            field_name, input_file);
    end

    mask = logical(values);
end

function metadata = extractMetadataLocal(G, input_file)

    metadata = struct();
    metadata.gpl_stim_tag = char(string(G.gpl_stim_tag));
    metadata.target_stim_tag = char(string(G.target_stim_tag));
    metadata.analysis_window = double(G.analysis_window(:)');
    metadata.bin_size = double(G.bin_size);
    metadata.pattern_z_threshold = double(G.pattern_z_threshold);
    metadata.baseline_subtracted = logical(G.baseline_subtracted);
    metadata.plaid_component_separation_deg = ...
        double(G.plaid_component_separation_deg);
    metadata.reference_file = input_file;

    if metadata.baseline_subtracted
        if ~isfield(G, 'baseline') || ~isstruct(G.baseline)
            error('gpl_results.baseline is missing or invalid in %s.', ...
                input_file);
        end

        requireFieldsLocal(G.baseline, ...
            {'stim_tag', 'analysis_window', 'bin_size'}, ...
            'gpl_results.baseline', input_file);

        metadata.baseline_stim_tag = ...
            char(string(G.baseline.stim_tag));
        metadata.baseline_analysis_window = ...
            double(G.baseline.analysis_window(:)');
        metadata.baseline_bin_size = double(G.baseline.bin_size);

        if numel(metadata.baseline_analysis_window) ~= 2 || ...
                any(~isfinite(metadata.baseline_analysis_window))
            error(['gpl_results.baseline.analysis_window must contain two ' ...
                'finite values in %s.'], input_file);
        end

        if ~isscalar(metadata.baseline_bin_size) || ...
                ~isfinite(metadata.baseline_bin_size)
            error(['gpl_results.baseline.bin_size must be one finite scalar ' ...
                'in %s.'], input_file);
        end
    else
        metadata.baseline_stim_tag = '';
        metadata.baseline_analysis_window = [];
        metadata.baseline_bin_size = [];
    end

    if numel(metadata.analysis_window) ~= 2 || ...
            any(~isfinite(metadata.analysis_window))
        error('gpl_results.analysis_window must contain two finite values.');
    end

    scalar_fields = { ...
        'bin_size', ...
        'pattern_z_threshold', ...
        'plaid_component_separation_deg'};

    for k = 1:numel(scalar_fields)
        f = scalar_fields{k};
        if ~isscalar(metadata.(f)) || ~isfinite(metadata.(f))
            error('gpl_results.%s must be one finite scalar.', f);
        end
    end

    if ~isscalar(metadata.baseline_subtracted)
        error('gpl_results.baseline_subtracted must be scalar.');
    end
end

function assertMatchingNonTagMetadataLocal( ...
        metadata, reference, tolerance, input_file)
% Compare only analysis/classification settings that affect whether pooled
% values are directly comparable. Stimulus tags identify session-specific
% runs and therefore are intentionally not compared here.

    numeric_fields = { ...
        'analysis_window', ...
        'bin_size', ...
        'pattern_z_threshold', ...
        'plaid_component_separation_deg'};

    for k = 1:numel(numeric_fields)
        f = numeric_fields{k};

        if ~sameNumericVectorLocal(metadata.(f), reference.(f), tolerance)
            error('%s differs from the reference in %s.', f, input_file);
        end
    end

    if metadata.baseline_subtracted ~= reference.baseline_subtracted
        error('baseline_subtracted differs from the reference in %s.', ...
            input_file);
    end

    if metadata.baseline_subtracted
        if ~sameNumericVectorLocal( ...
                metadata.baseline_analysis_window, ...
                reference.baseline_analysis_window, tolerance)
            error(['baseline_analysis_window differs from the reference ' ...
                'in %s.'], input_file);
        end

        if ~sameNumericVectorLocal( ...
                metadata.baseline_bin_size, ...
                reference.baseline_bin_size, tolerance)
            error('baseline_bin_size differs from the reference in %s.', ...
                input_file);
        end
    end
end

function tf = sameNumericVectorLocal(a, b, tolerance)

    a = double(a(:));
    b = double(b(:));

    if numel(a) ~= numel(b) || any(~isfinite(a)) || any(~isfinite(b))
        tf = false;
        return;
    end

    scale = max(1, max(abs([a; b])));
    tf = all(abs(a - b) <= tolerance * scale + eps(scale));
end

function skipped = makeSkippedFileLocal( ...
        session_index, session_name, group_index, group_name, ...
        input_file, reason)

    skipped = struct();
    skipped.session_index = session_index;
    skipped.session_name = session_name;
    skipped.group_index = group_index;
    skipped.group_name = group_name;
    skipped.input_file = input_file;
    skipped.reason = reason;
end

function skipped = makeSkippedSessionLocal( ...
        session_index, session_name, session_dir, reason)

    skipped = struct();
    skipped.session_index = session_index;
    skipped.session_name = session_name;
    skipped.session_dir = session_dir;
    skipped.reason = reason;
end

function pool = buildOneGroupPoolLocal( ...
        records, group_index, group_name, probe_id)

    pool = struct();
    pool.group_index = group_index;
    pool.group_name = group_name;
    pool.probe_id = probe_id;
    pool.session_index = zeros(0, 1);
    pool.record_index = zeros(0, 1);
    pool.unit_id = zeros(0, 1);
    pool.DI = zeros(0, 1);
    pool.OSI = zeros(0, 1);
    pool.Zp = zeros(0, 1);
    pool.Zc = zeros(0, 1);
    pool.PI = zeros(0, 1);
    pool.is_pattern = false(0, 1);
    pool.is_component = false(0, 1);
    pool.is_unclassified = false(0, 1);
    pool.is_invalid = false(0, 1);
    pool.class_label = strings(0, 1);

    for r = 1:numel(records)
        if records(r).group_index ~= group_index
            continue;
        end

        n = records(r).n_neurons;
        pool.session_index = [pool.session_index; ...
            repmat(records(r).session_index, n, 1)]; %#ok<AGROW>
        pool.record_index = [pool.record_index; ...
            repmat(r, n, 1)]; %#ok<AGROW>
        pool.unit_id = [pool.unit_id; records(r).unit_ids]; %#ok<AGROW>
        pool.DI = [pool.DI; records(r).DI]; %#ok<AGROW>
        pool.OSI = [pool.OSI; records(r).OSI]; %#ok<AGROW>
        pool.Zp = [pool.Zp; records(r).Zp]; %#ok<AGROW>
        pool.Zc = [pool.Zc; records(r).Zc]; %#ok<AGROW>
        pool.PI = [pool.PI; records(r).PI]; %#ok<AGROW>
        pool.is_pattern = [pool.is_pattern; ...
            records(r).is_pattern]; %#ok<AGROW>
        pool.is_component = [pool.is_component; ...
            records(r).is_component]; %#ok<AGROW>
        pool.is_unclassified = [pool.is_unclassified; ...
            records(r).is_unclassified]; %#ok<AGROW>
        pool.is_invalid = [pool.is_invalid; ...
            records(r).is_invalid]; %#ok<AGROW>
        pool.class_label = [pool.class_label; ...
            records(r).class_label]; %#ok<AGROW>
    end

    pool.stats = struct();
    pool.stats.DI = metricStatsLocal(pool.DI);
    pool.stats.OSI = metricStatsLocal(pool.OSI);
    pool.stats.Zp = metricStatsLocal(pool.Zp(~pool.is_invalid));
    pool.stats.Zc = metricStatsLocal(pool.Zc(~pool.is_invalid));
    pool.stats.PI = metricStatsLocal(pool.PI(~pool.is_invalid));
    pool.stats.class_count = struct( ...
        'pattern', sum(pool.is_pattern), ...
        'component', sum(pool.is_component), ...
        'unclassified', sum(pool.is_unclassified), ...
        'invalid', sum(pool.is_invalid));
end

function stats = metricStatsLocal(values)

    values = double(values(:));
    values = values(isfinite(values));

    stats = struct();
    stats.n = numel(values);

    if isempty(values)
        stats.mean = NaN;
        stats.median = NaN;
        stats.sd = NaN;
        stats.min = NaN;
        stats.max = NaN;
    else
        stats.mean = mean(values);
        stats.median = median(values);
        stats.sd = std(values);
        stats.min = min(values);
        stats.max = max(values);
    end
end

function warnRepeatedUnitIdsLocal(group_pool, group_names)
% Unit IDs are only expected to be unique within one Kilosort result file.
% Warn when the same ID appears in multiple records for one session/group;
% do not remove it because distinct Kilosort folders may be intentional.

    for g = 1:numel(group_pool)
        sessions = unique(group_pool(g).session_index);

        for si = reshape(sessions, 1, [])
            take = group_pool(g).session_index == si;
            ids = group_pool(g).unit_id(take);
            rec = group_pool(g).record_index(take);
            [unique_ids, ~, map] = unique(ids);

            for u = 1:numel(unique_ids)
                these_records = unique(rec(map == u));

                if numel(these_records) > 1
                    warning(['%s session index %d contains unit ID %g in ' ...
                        'multiple GPL record files. All occurrences are ' ...
                        'retained.'], ...
                        group_names{g}, si, unique_ids(u));
                    break;
                end
            end
        end
    end
end

function dist = buildMultiGroupDistributionLocal( ...
        values_by_group, base_bin_edges, overflow_limit)

    base_bin_edges = double(base_bin_edges(:)');
    bin_width = median(diff(base_bin_edges));
    n_groups = numel(values_by_group);

    if n_groups < 1
        error('values_by_group must contain at least one model group.');
    end

    if isempty(overflow_limit)
        edges = base_bin_edges;
        centers = (edges(1:end - 1) + edges(2:end)) ./ 2;
        counts = zeros(numel(centers), n_groups);
        probability = zeros(numel(centers), n_groups);
        overflow_count = zeros(1, n_groups);
        outside_count = zeros(1, n_groups);

        for g = 1:n_groups
            values = finiteColumnLocal(values_by_group{g});
            counts(:, g) = histcounts(values, edges)';
            outside_count(g) = sum(values < edges(1) | values > edges(end));

            if ~isempty(values)
                probability(:, g) = counts(:, g) ./ numel(values);
            end
        end

        x_limits = [edges(1), edges(end)];
        tick_step = max(0.2, 2 * bin_width);
        tick_values = edges(1):tick_step:edges(end);

        if isempty(tick_values) || tick_values(end) < edges(end) - eps
            tick_values(end + 1) = edges(end); %#ok<AGROW>
        end

        tick_labels = arrayfun(@(x) sprintf('%g', x), ...
            tick_values, 'UniformOutput', false);
        overflow_center = [];
        regular_edges = edges;
    else
        n_regular_float = overflow_limit / bin_width;
        n_regular = round(n_regular_float);

        if abs(n_regular_float - n_regular) > 1e-10 || ...
                abs(base_bin_edges(1)) > 1e-10
            error(['The DI overflow limit must be an integer multiple of ' ...
                'the selectivity-bin width, and edges must begin at zero.']);
        end

        regular_edges = (0:n_regular) .* bin_width;
        regular_edges(end) = overflow_limit;
        regular_centers = ...
            (regular_edges(1:end - 1) + regular_edges(2:end)) ./ 2;
        overflow_center = overflow_limit + 1.5 .* bin_width;
        centers = [regular_centers, overflow_center];
        counts = zeros(numel(centers), n_groups);
        probability = zeros(numel(centers), n_groups);
        overflow_count = zeros(1, n_groups);
        outside_count = zeros(1, n_groups);

        for g = 1:n_groups
            values = finiteColumnLocal(values_by_group{g});
            regular_counts = histcounts(values, regular_edges);
            regular_counts(1) = regular_counts(1) + ...
                sum(values < regular_edges(1));
            overflow_count(g) = sum(values > overflow_limit);
            counts(:, g) = [regular_counts, overflow_count(g)]';

            if ~isempty(values)
                probability(:, g) = counts(:, g) ./ numel(values);
            end
        end

        x_limits = [0, overflow_center + 0.60 .* bin_width];
        numeric_ticks = [0, 0.4, 0.8, 1.2, overflow_limit];
        numeric_ticks = unique(numeric_ticks( ...
            numeric_ticks >= 0 & numeric_ticks <= overflow_limit), ...
            'stable');
        tick_values = [numeric_ticks, overflow_center];
        tick_labels = arrayfun(@(x) sprintf('%g', x), ...
            numeric_ticks, 'UniformOutput', false);
        tick_labels{end + 1} = sprintf('>%g', overflow_limit);
    end

    n = zeros(1, n_groups);
    mean_value = nan(1, n_groups);
    median_value = nan(1, n_groups);
    mean_display = nan(1, n_groups);
    median_display = nan(1, n_groups);

    for g = 1:n_groups
        values = finiteColumnLocal(values_by_group{g});
        n(g) = numel(values);

        if isempty(values)
            continue;
        end

        mean_value(g) = mean(values);
        median_value(g) = median(values);
        mean_display(g) = mapStatisticToDisplayLocal( ...
            mean_value(g), x_limits, overflow_limit, overflow_center);
        median_display(g) = mapStatisticToDisplayLocal( ...
            median_value(g), x_limits, overflow_limit, overflow_center);
    end

    dist = struct();
    dist.base_bin_edges = base_bin_edges;
    dist.regular_edges = regular_edges;
    dist.bin_width = bin_width;
    dist.centers = centers(:);
    dist.counts = counts;
    dist.probability = probability;
    dist.n = n;
    dist.mean = mean_value;
    dist.median = median_value;
    dist.mean_display_position = mean_display;
    dist.median_display_position = median_display;
    dist.overflow_limit = overflow_limit;
    dist.overflow_center = overflow_center;
    dist.overflow_count = overflow_count;
    dist.outside_regular_range_count = outside_count;
    dist.x_limits = x_limits;
    dist.x_tick = tick_values;
    dist.x_tick_label = tick_labels;
end

function values = finiteColumnLocal(values)

    values = double(values(:));
    values = values(isfinite(values));
end

function x_display = mapStatisticToDisplayLocal( ...
        value, x_limits, overflow_limit, overflow_center)

    if ~isempty(overflow_limit) && value > overflow_limit
        x_display = overflow_center;
    else
        x_display = min(max(value, x_limits(1)), x_limits(2));
    end
end

function [z_limits, pi_limits, pi_edges] = determinePatternAxesLocal( ...
        group_pool, z_limits_user, pi_limits_user, pi_num_bins)

    plotted_z = [];
    plotted_pi = [];

    for g = 1:numel(group_pool)
        plotted = ~group_pool(g).is_invalid;
        valid_z = plotted & isfinite(group_pool(g).Zp) & ...
            isfinite(group_pool(g).Zc);
        valid_pi = plotted & isfinite(group_pool(g).PI);

        plotted_z = [plotted_z; ...
            group_pool(g).Zp(valid_z); ...
            group_pool(g).Zc(valid_z)]; %#ok<AGROW>
        plotted_pi = [plotted_pi; ...
            group_pool(g).PI(valid_pi)]; %#ok<AGROW>
    end

    if isempty(z_limits_user)
        if isempty(plotted_z)
            z_limits = [-1, 4];
        else
            z_lo = min(-1, floor(min(plotted_z) - 0.5));
            z_hi = max(4, ceil(max(plotted_z) + 0.5));

            if z_hi <= z_lo
                z_hi = z_lo + 1;
            end

            z_limits = [z_lo, z_hi];
        end
    else
        z_limits = z_limits_user;
    end

    if isempty(pi_limits_user)
        if isempty(plotted_pi)
            pi_limit = 2;
        else
            pi_limit = max(2, ceil(max(abs(plotted_pi)) + 0.5));
        end

        pi_limits = [-pi_limit, pi_limit];
    else
        pi_limits = pi_limits_user;
    end

    pi_edges = linspace(pi_limits(1), pi_limits(2), pi_num_bins + 1);
end

function dist = buildPIDistributionLocal(group_pool, pi_edges)

    centers = (pi_edges(1:end - 1) + pi_edges(2:end)) ./ 2;
    n_groups = numel(group_pool);
    counts = zeros(numel(centers), n_groups);
    probability = zeros(numel(centers), n_groups);
    n = zeros(1, n_groups);
    mean_value = nan(1, n_groups);
    outside_count = zeros(1, n_groups);

    for g = 1:n_groups
        take = ~group_pool(g).is_invalid & isfinite(group_pool(g).PI);
        values = group_pool(g).PI(take);
        n(g) = numel(values);
        counts(:, g) = histcounts(values, pi_edges)';
        outside_count(g) = sum( ...
            values < pi_edges(1) | values > pi_edges(end));

        if n(g) > 0
            probability(:, g) = counts(:, g) ./ n(g);
            mean_value(g) = mean(values);
        end
    end

    dist = struct();
    dist.edges = pi_edges;
    dist.centers = centers(:);
    dist.counts = counts;
    dist.probability = probability;
    dist.n = n;
    dist.mean = mean_value;
    dist.outside_range_count = outside_count;
end

function fig = plotMultiGroupDistributionLocal( ...
        dist, group_names, group_colors, x_label_text, ...
        figure_visible, figure_size_inches, ...
        bin_fill_fraction, bar_alpha, ...
        show_mean, ...
        mean_line_width, ...
        mean_value_decimal_places, mean_arrow_y_fraction, ...
        legend_location, ...
        font_name, axis_font_size, legend_font_size, axis_line_width)

    fig = figure( ...
        'Visible', figure_visible, ...
        'Color', 'w', ...
        'Units', 'inches', ...
        'Position', [1, 1, figure_size_inches], ...
        'Renderer', 'painters');

    ax = axes(fig);
    hold(ax, 'on');

    n_groups = numel(group_names);
    if size(dist.probability, 2) ~= n_groups || ...
            size(group_colors, 1) ~= n_groups || ...
            size(mean_arrow_y_fraction, 1) ~= n_groups
        error(['Distribution values, group names, colors, and mean-arrow ', ...
            'positions must contain the same number of groups.']);
    end

    bars = drawCompactGroupedBarsLocal( ...
        ax, dist.centers, dist.probability, dist.bin_width, ...
        bin_fill_fraction, group_colors, bar_alpha);

    max_probability = max(dist.probability(:));
    if isempty(max_probability) || ~isfinite(max_probability) || ...
            max_probability <= 0
        y_limits = [0, 0.1];
    else
        if show_mean
            lowest_arrow_tip = min(mean_arrow_y_fraction(:, 2));
            bar_height_fraction = max(0.20, ...
                min(0.90, lowest_arrow_tip - 0.05));
        else
            bar_height_fraction = 0.92;
        end
        y_limits = [0, max_probability ./ bar_height_fraction];
    end

    ylim(ax, y_limits);
    xlim(ax, dist.x_limits);

    if show_mean
        for g = 1:n_groups
            if isfinite(dist.mean_display_position(g))
                plotMeanArrowLocal( ...
                    ax, ...
                    dist.mean_display_position(g), dist.mean(g), ...
                    group_colors(g, :), ...
                    y_limits, mean_arrow_y_fraction(g, :), ...
                    mean_line_width, mean_value_decimal_places, ...
                    font_name, axis_font_size);
            end
        end
    end

    legend_handles = gobjects(0, 1);
    legend_labels = {};

    for g = 1:n_groups
        legend_handles(end + 1, 1) = bars(g); %#ok<AGROW>
        legend_labels{end + 1} = sprintf('%s = %d', ...
            group_names{g}, dist.n(g)); %#ok<AGROW>
    end

    legend(ax, legend_handles, legend_labels, ...
        'Location', legend_location, ...
        'Box', 'off', ...
        'TextColor', 'k', ...
        'FontName', font_name, ...
        'FontSize', legend_font_size, ...
        'Interpreter', 'none');

    set(ax, ...
        'XTick', dist.x_tick, ...
        'XTickLabel', dist.x_tick_label, ...
        'TickLabelInterpreter', 'none', ...
        'TickDir', 'out', ...
        'TickLength', [0.018, 0.018], ...
        'Box', 'off', ...
        'FontName', font_name, ...
        'FontSize', axis_font_size, ...
        'LineWidth', axis_line_width, ...
        'XColor', 'k', ...
        'YColor', 'k', ...
        'Layer', 'top');

    xlabel(ax, x_label_text, ...
        'FontName', font_name, 'Interpreter', 'none');
    ylabel(ax, 'Proportion of cells', ...
        'FontName', font_name, 'Interpreter', 'none');

    grid(ax, 'off');
    set(findall(fig, '-property', 'FontName'), 'FontName', font_name);
end

function bars = drawCompactGroupedBarsLocal( ...
        ax, centers, probability, bin_width, bin_fill_fraction, ...
        group_colors, bar_alpha)
% Draw side-by-side group bars within each histogram bin. Using explicit
% patch geometry makes the space between neighboring bins independent of
% MATLAB's grouped-bar layout. All group bars together fill the requested
% fraction of one bin.

    centers = double(centers(:));
    probability = double(probability);
    num_bins = numel(centers);
    num_groups = size(probability, 2);

    if size(probability, 1) ~= num_bins
        error('Histogram centers and probability rows must have equal size.');
    end

    if num_groups < 1 || ...
            ~isequal(size(group_colors), [num_groups, 3])
        error(['Compact grouped bars require one RGB color row for every ', ...
            'model group.']);
    end

    grouped_width = bin_width .* bin_fill_fraction;
    one_bar_width = grouped_width ./ num_groups;
    grouped_left = centers - grouped_width ./ 2;
    bars = gobjects(num_groups, 1);

    for g = 1:num_groups
        left = grouped_left + (g - 1) .* one_bar_width;
        right = left + one_bar_width;
        height = probability(:, g);

        vertices = zeros(4 .* num_bins, 2);
        faces = zeros(num_bins, 4);

        for b = 1:num_bins
            idx = (b - 1) .* 4 + (1:4);
            vertices(idx, :) = [ ...
                left(b),  0; ...
                right(b), 0; ...
                right(b), height(b); ...
                left(b),  height(b)];
            faces(b, :) = idx;
        end

        bars(g) = patch( ...
            ax, ...
            'Faces', faces, ...
            'Vertices', vertices, ...
            'FaceColor', group_colors(g, :), ...
            'EdgeColor', 'none');

        try
            bars(g).FaceAlpha = bar_alpha;
        catch
            % FaceAlpha is unavailable in some older MATLAB releases.
        end
    end
end

function fig = plotOneGroupPatternComponentLocal( ...
        pool, group_name, this_color, ...
        class_names, class_display_names, class_markers, ...
        z_threshold, z_limits, ...
        pi_centers, pi_probability, pi_n, ...
        pi_limits, pi_y_limits, ...
        figure_visible, figure_size_inches, ...
        scatter_size, scatter_alpha, scatter_line_width, ...
        boundary_line_style, boundary_line_width, ...
        pi_bar_width, pi_bar_alpha, ...
        show_pi_neuron_count, ...
        legend_location, ...
        font_name, axis_font_size, legend_font_size, axis_line_width)

    fig = figure( ...
        'Name', sprintf('%s GPL pattern/component summary', group_name), ...
        'NumberTitle', 'off', ...
        'Visible', figure_visible, ...
        'Color', 'w', ...
        'Units', 'inches', ...
        'Position', [1, 1, figure_size_inches], ...
        'Renderer', 'painters');

    tl = tiledlayout(fig, 1, 2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    ax_scatter = nexttile(tl, 1);
    hold(ax_scatter, 'on');

    class_handles = gobjects(3, 1);

    % Draw unclassified first, then component, then pattern, so the more
    % specific classes remain visible when points overlap.
    draw_order = [3, 2, 1];

    for d = 1:numel(draw_order)
        c = draw_order(d);
        mask = pool.(['is_', class_names{c}]) & ...
            isfinite(pool.Zc) & isfinite(pool.Zp);

        class_handles(c) = scatterClassLocal( ...
            ax_scatter, ...
            pool.Zc(mask), pool.Zp(mask), ...
            scatter_size, class_markers{c}, this_color, ...
            scatter_alpha, scatter_line_width, ...
            class_display_names{c});
    end

    plotZClassificationBoundariesLocal( ...
        ax_scatter, z_limits, z_threshold, ...
        boundary_line_style, boundary_line_width);

    xlim(ax_scatter, z_limits);
    ylim(ax_scatter, z_limits);
    axis(ax_scatter, 'square');

    xlabel(ax_scatter, 'Component correlation (Z_c)', ...
        'FontName', font_name, 'Interpreter', 'tex');
    ylabel(ax_scatter, 'Pattern correlation (Z_p)', ...
        'FontName', font_name, 'Interpreter', 'tex');

    legend(ax_scatter, class_handles, class_display_names, ...
        'Location', legend_location, ...
        'Box', 'off', ...
        'Color', 'w', ...
        'EdgeColor', [0.35, 0.35, 0.35], ...
        'FontName', font_name, ...
        'FontSize', legend_font_size, ...
        'Interpreter', 'none');

    cleanAxisLocal( ...
        ax_scatter, font_name, axis_font_size, axis_line_width);

    ax_pi = nexttile(tl, 2);
    hold(ax_pi, 'on');

    h_bar = bar(ax_pi, pi_centers, pi_probability, pi_bar_width, ...
        'FaceColor', this_color, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off');

    try
        h_bar.FaceAlpha = pi_bar_alpha;
    catch
        % FaceAlpha is unavailable in some older MATLAB releases.
    end

    xlim(ax_pi, pi_limits);
    ylim(ax_pi, pi_y_limits);

    if show_pi_neuron_count
        text(ax_pi, 0.985, 0.985, ...
            sprintf('%s = %d', group_name, pi_n), ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'top', ...
            'Color', 'k', ...
            'BackgroundColor', 'w', ...
            'Margin', 1, ...
            'FontName', font_name, ...
            'FontSize', axis_font_size, ...
            'Interpreter', 'none');
    end

    xlabel(ax_pi, 'Pattern index (Z_p - Z_c)', ...
        'FontName', font_name, 'Interpreter', 'tex');
    ylabel(ax_pi, 'Proportion of cells', ...
        'FontName', font_name, 'Interpreter', 'none');

    cleanAxisLocal(ax_pi, font_name, axis_font_size, axis_line_width);
    set(findall(fig, '-property', 'FontName'), 'FontName', font_name);
end

function plotMeanArrowLocal( ...
        ax, x_display, mean_value, color, y_limits, y_fraction, ...
        line_width, decimal_places, font_name, font_size)
% Draw a short downward arrow at the mean x coordinate.

    if ~isfinite(x_display) || ~isfinite(mean_value)
        return;
    end

    y_span = diff(y_limits);
    if ~isfinite(y_span) || y_span <= 0
        return;
    end

    y_start = y_limits(1) + y_fraction(1) .* y_span;
    y_tip = y_limits(1) + y_fraction(2) .* y_span;
    y_text = y_limits(1) + y_fraction(3) .* y_span;

    quiver(ax, x_display, y_start, 0, y_tip - y_start, 0, ...
        'Color', color, ...
        'LineWidth', line_width, ...
        'MaxHeadSize', 0.85, ...
        'HandleVisibility', 'off');

    current_x_limits = xlim(ax);
    x_fraction = (x_display - current_x_limits(1)) ./ ...
        diff(current_x_limits);

    if x_fraction <= 0.16
        horizontal_alignment = 'left';
    elseif x_fraction >= 0.84
        horizontal_alignment = 'right';
    else
        horizontal_alignment = 'center';
    end

    text(ax, x_display, y_text, ...
        sprintf('mean = %.*f', decimal_places, mean_value), ...
        'HorizontalAlignment', horizontal_alignment, ...
        'VerticalAlignment', 'bottom', ...
        'Color', color, ...
        'BackgroundColor', 'w', ...
        'Margin', 1, ...
        'FontName', font_name, ...
        'FontSize', font_size, ...
        'Interpreter', 'none', ...
        'Clipping', 'on');
end

function h = scatterClassLocal( ...
        ax, x, y, marker_size, marker_shape, color, ...
        alpha_value, line_width, display_name)

    try
        h = scatter(ax, x, y, marker_size, marker_shape, ...
            'MarkerFaceColor', color, ...
            'MarkerEdgeColor', color, ...
            'MarkerFaceAlpha', alpha_value, ...
            'MarkerEdgeAlpha', min(1, alpha_value + 0.20), ...
            'LineWidth', line_width, ...
            'DisplayName', display_name);
    catch
        h = scatter(ax, x, y, marker_size, marker_shape, ...
            'MarkerFaceColor', color, ...
            'MarkerEdgeColor', color, ...
            'LineWidth', line_width, ...
            'DisplayName', display_name);
    end
end

function plotZClassificationBoundariesLocal( ...
        ax, z_limits, threshold, line_style, line_width)
% Same piecewise boundaries used by GPL_analysis.m.

    lo = z_limits(1);
    hi = z_limits(2);

    line_args = { ...
        'LineStyle', line_style, ...
        'Color', [0, 0, 0], ...
        'LineWidth', line_width, ...
        'HandleVisibility', 'off'};

    % Pattern boundary: horizontal for Zc <= 0 and diagonal for Zc >= 0.
    if lo < 0 && threshold >= lo && threshold <= hi
        plot(ax, [lo, min(0, hi)], [threshold, threshold], ...
            line_args{:});
    end

    x_start = max(0, lo);
    x_end = min(hi, hi - threshold);

    if x_end > x_start
        x = linspace(x_start, x_end, 200);
        plot(ax, x, x + threshold, line_args{:});
    end

    % Component boundary: vertical for Zp <= 0 and diagonal for Zp >= 0.
    if lo < 0 && threshold >= lo && threshold <= hi
        plot(ax, [threshold, threshold], [lo, min(0, hi)], ...
            line_args{:});
    end

    x_start = max(threshold, lo);
    x_end = hi;

    if x_end > x_start
        x = linspace(x_start, x_end, 200);
        y = x - threshold;
        keep = y >= lo & y <= hi;
        plot(ax, x(keep), y(keep), line_args{:});
    end
end

function cleanAxisLocal(ax, font_name, font_size, line_width)

    set(ax, ...
        'TickDir', 'out', ...
        'TickLength', [0.018, 0.018], ...
        'Box', 'off', ...
        'FontName', font_name, ...
        'FontSize', font_size, ...
        'LineWidth', line_width, ...
        'XColor', 'k', ...
        'YColor', 'k', ...
        'Layer', 'top');

    grid(ax, 'off');
end

function saveFigurePairLocal(fig, fig_file, svg_file)

    savefig(fig, fig_file);

    try
        exportgraphics(fig, svg_file, ...
            'ContentType', 'vector', ...
            'BackgroundColor', 'none');
    catch
        print(fig, svg_file, '-dsvg', '-painters');
    end

    fprintf('Saved FIG: %s\n', fig_file);
    fprintf('Saved SVG: %s\n', svg_file);
end

function tag = makeSafeFileTagLocal(value)

    tag = char(string(value));
    tag = strtrim(tag);
    tag = regexprep(tag, '[^A-Za-z0-9]+', '_');
    tag = regexprep(tag, '^_+|_+$', '');

    if isempty(tag)
        tag = 'x';
    end
end

function text_value = numericValueToTextLocal(value)

    if isnumeric(value) && isscalar(value)
        text_value = sprintf('%.12g', value);
    else
        text_value = '<nonscalar or nonnumeric>';
    end
end
