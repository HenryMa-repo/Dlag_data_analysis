%% sum_GPL_class_R2.m
% Summarize neuron-wise reconstruction R2 across sessions after grouping
% neurons by spontaneous-subtracted GPL classification.
%
% The script follows the same multi-session workflow as the other
% session_summary programs:
%   1) scan root_dir/session_folder/catgt_*;
%   2) sort sessions by the number following "p" in session_folder;
%   3) load every valid session and label it S1, S2, ...;
%   4) retain the real folder-to-S-number mapping in the saved MAT file;
%   5) skip invalid sessions with a warning and record the reason.
%
% Four figures are generated:
%   Group 1 - grating
%   Group 1 - plaid
%   Group 2 - grating
%   Group 2 - plaid
%
% Each figure has three class blocks:
%   pattern cell, component cell, unclassified cell.
%
% Within each class block, every neuron contributes one connected
% trajectory in this order:
%   all -> across -> within -> FF -> FB.
%
% A neuron is connected only to itself. Sessions use progressively darker
% shades of the corresponding group color. Invalid GPL neurons remain in
% all population and unit-ID alignment checks, but are not plotted.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';

% -------------------------------------------------------------------------
% Reconstruction R2 settings
% -------------------------------------------------------------------------

data_content = 'raw_count';
% Common options:
%   raw_count
%   raw_fr
%   z_within_trial
%   z_within_condition
%   z_across_conditions
%   demean_count_within_trial
%   demean_fr_within_trial
%   demean_pooledsd_within_condition

model_mode = 'all_condition_model';
% Options:
%   'all_condition_model'
%   'condition_specific_models'

runIdx = 1;

reconstruction_suffix = 'all_across_within_ff_fb';

% -------------------------------------------------------------------------
% GPL settings
% -------------------------------------------------------------------------

% Group order must match reconstruction yDims and unit_ids_by_group.
probes = [0, 1];
group_labels = {'Group 1', 'Group 2'};

% Spontaneous-subtracted GPL classification file.
gpl_mat_name = 'unit_gpl_results_sponsub.mat';

% -------------------------------------------------------------------------
% Save settings
% -------------------------------------------------------------------------

save_mat = true;
save_fig = false;
save_svg = true;
save_png = true;
close_after_save = true;

figure_visible = 'on';
% 'on' or 'off'

png_dpi = 400;
print_full_error_report = false;

% -------------------------------------------------------------------------
% Plot settings
% -------------------------------------------------------------------------

% Same base colors and session-lightness progression as the other
% multi-session summary scripts.
group_colors_base = [ ...
    0.0000, 0.4470, 0.7410; ...
    0.8500, 0.3250, 0.0980];

session_color_lightness_start = 0.65;
session_color_lightness_end = 0.05;

% Neuron trajectory appearance.
trajectory_line_width = 0.75;
trajectory_line_alpha = 0.38;
trajectory_marker_size = 13;
trajectory_marker_alpha = 0.62;

% Horizontal layout.
within_class_step = 1.0;
between_class_gap = 1.7;

% Article-figure typography and dimensions.
font_name = 'Arial';
axis_font_size = 11;
class_label_font_size = 10;
title_font_size = 12;
legend_font_size = 10;
axis_line_width = 1;

figure_height = 720;
figure_width_min = 1400;
figure_width_per_session = 45;
figure_width_max = 2400;

% Fixed plotting order and labels.
class_names = {'pattern', 'component', 'unclassified'};
class_labels = {'Pattern cell', 'Component cell', 'Unclassified cell'};

field_names = { ...
    'use_all', ...
    'use_across', ...
    'use_within', ...
    'use_feedforward', ...
    'use_feedback'};

field_labels = {'all', 'across', 'within', 'FF', 'FB'};
stim_types = {'grating', 'plaid'};

%% ======================= VALIDATE SETTINGS =============================

validateUserSettingsLocal( ...
    root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, probes, group_labels, gpl_mat_name, ...
    group_colors_base, session_color_lightness_start, ...
    session_color_lightness_end, figure_visible, ...
    class_names, class_labels, field_names, field_labels, stim_types);

model_tag = makeModelTagLocal(model_mode);
output_base = sprintf('%s_%s_GPLclass_R2_%s', ...
    data_content, model_tag, reconstruction_suffix);

fprintf('\n============================================================\n');
fprintf('Across-session GPL-class reconstruction R2 summary\n');
fprintf('Root dir              : %s\n', root_dir);
fprintf('Data content          : %s\n', data_content);
fprintf('Model mode            : %s\n', model_mode);
fprintf('Run index             : %d\n', runIdx);
fprintf('GPL MAT               : %s\n', gpl_mat_name);
fprintf('Output base           : %s\n', output_base);
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
            session_dir, data_content, model_mode, runIdx, ...
            reconstruction_suffix, probes, group_labels, ...
            gpl_mat_name, field_names, stim_types, reference);

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

fprintf('\nSession mapping used in figures:\n');

for s = 1:num_sessions
    fprintf('  %-4s -> %s/%s\n', ...
        records{s}.session_label, ...
        records{s}.session_parent_name, ...
        records{s}.catgt_name);
end

%% ======================= BUILD AND SAVE SUMMARY ========================

session_colors_by_group = makeSessionColorsByGroupLocal( ...
    group_colors_base, num_sessions, ...
    session_color_lightness_start, session_color_lightness_end);

MultiSessionGPLClassR2 = buildMultiSessionSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, probes, group_labels, gpl_mat_name, ...
    class_names, class_labels, field_names, field_labels, stim_types, ...
    output_base, group_colors_base, session_colors_by_group, ...
    session_color_lightness_start, session_color_lightness_end);

if save_mat
    mat_file = fullfile(root_dir, [output_base, '.mat']);
    save(mat_file, 'MultiSessionGPLClassR2', '-v7.3');
    fprintf('\nSaved MAT:\n  %s\n', mat_file);
end

%% ======================= PLOT FOUR FIGURES =============================

figure_width = min(figure_width_max, ...
    max(figure_width_min, ...
    figure_width_min + figure_width_per_session * max(0, num_sessions - 1)));

fig_handles = gobjects(numel(probes), numel(stim_types));

for g = 1:numel(probes)
    for st = 1:numel(stim_types)
        stim_name = stim_types{st};

        fig = plotOneSummaryLocal( ...
            records, g, stim_name, group_labels{g}, ...
            class_names, class_labels, field_labels, ...
            session_colors_by_group, ...
            within_class_step, between_class_gap, ...
            trajectory_line_width, trajectory_line_alpha, ...
            trajectory_marker_size, trajectory_marker_alpha, ...
            font_name, axis_font_size, class_label_font_size, ...
            title_font_size, legend_font_size, axis_line_width, ...
            figure_visible, figure_width, figure_height);

        fig_handles(g, st) = fig;

        figure_base = sprintf('%s_g%d_%s', ...
            output_base, g, stim_name);

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

fprintf('\nDone.\n');

%% =======================================================================
% Local functions
% ========================================================================

function validateUserSettingsLocal( ...
    root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, probes, group_labels, gpl_mat_name, ...
    group_colors_base, light_start, light_end, figure_visible, ...
    class_names, class_labels, field_names, field_labels, stim_types)

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
    assertStringOptionLocal(figure_visible, {'on', 'off'}, ...
        'figure_visible');

    validateattributes(runIdx, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, ...
        mfilename, 'runIdx');

    if ~isnumeric(probes) || ~isvector(probes) || isempty(probes)
        error('probes must be a nonempty numeric vector.');
    end

    probes = double(probes(:)');

    if any(~isfinite(probes)) || any(probes ~= round(probes)) || ...
            any(probes < 0) || numel(unique(probes)) ~= numel(probes)
        error('probes must contain unique nonnegative integer probe IDs.');
    end

    if ~iscell(group_labels) || numel(group_labels) ~= numel(probes)
        error('group_labels must contain one label per probe.');
    end

    for g = 1:numel(group_labels)
        requireNonemptyTextLocal(group_labels{g}, ...
            sprintf('group_labels{%d}', g));
    end

    if size(group_colors_base, 1) < numel(probes) || ...
            size(group_colors_base, 2) ~= 3 || ...
            any(~isfinite(group_colors_base(:))) || ...
            any(group_colors_base(:) < 0) || ...
            any(group_colors_base(:) > 1)
        error(['group_colors_base must contain one finite RGB row in ', ...
            '[0,1] per group.']);
    end

    if ~isscalar(light_start) || ~isscalar(light_end) || ...
            ~isfinite(light_start) || ~isfinite(light_end) || ...
            light_start < 0 || light_start > 1 || ...
            light_end < 0 || light_end > 1
        error('Session lightness values must lie in [0,1].');
    end

    validateParallelLabelListsLocal( ...
        class_names, class_labels, 'class_names', 'class_labels');
    validateParallelLabelListsLocal( ...
        field_names, field_labels, 'field_names', 'field_labels');

    if ~iscell(stim_types) || isempty(stim_types)
        error('stim_types must be a nonempty cell array.');
    end

    for st = 1:numel(stim_types)
        requireNonemptyTextLocal(stim_types{st}, ...
            sprintf('stim_types{%d}', st));
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
    session_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, probes, group_labels, ...
    gpl_mat_name, field_names, stim_types, reference)

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
        reconstruction_suffix);

    if ~isfile(r2_file)
        error('Required reconstruction R2 file not found: %s', r2_file);
    end

    S = load(r2_file, 'stimtype_recon_R2');

    if ~isfield(S, 'stimtype_recon_R2')
        error('%s does not contain stimtype_recon_R2.', r2_file);
    end

    R = S.stimtype_recon_R2;

    validateStimtypeR2Local( ...
        R, data_content, model_mode, probes, field_names, stim_types, ...
        r2_file);

    reference = validateOrInitializeReferenceLocal( ...
        reference, R, probes, group_labels, field_names, stim_types, ...
        session_dir);

    num_groups = numel(probes);

    empty_group = struct( ...
        'group_index', [], ...
        'group_label', '', ...
        'probe_id', [], ...
        'unit_ids', [], ...
        'gpl_file', '', ...
        'class_info', struct(), ...
        'stim', struct());

    groups = repmat(empty_group, 1, num_groups);

    fprintf('  R2 file: %s\n', r2_file);

    for g = 1:num_groups
        model_ids = double(R.unit_ids_by_group{g}(:));

        [gpl_file, gpl_results] = loadOneGplFileLocal( ...
            session_dir, run_g, probes(g), gpl_mat_name);

        class_info = validateAndExtractClassesLocal( ...
            gpl_results, model_ids, g, probes(g), ...
            group_labels{g}, gpl_file);

        groups(g).group_index = g;
        groups(g).group_label = char(group_labels{g});
        groups(g).probe_id = probes(g);
        groups(g).unit_ids = model_ids;
        groups(g).gpl_file = gpl_file;
        groups(g).class_info = class_info;

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            r2_matrix = nan(numel(model_ids), numel(field_names));

            for f = 1:numel(field_names)
                r2_matrix(:, f) = getGroupR2VectorLocal( ...
                    R.(stim_name), field_names{f}, g);
            end

            groups(g).stim.(stim_name).r2_matrix = r2_matrix;
        end

        fprintf(['  %s / probe %d: pattern=%d, component=%d, ', ...
            'unclassified=%d, invalid=%d\n'], ...
            group_labels{g}, probes(g), ...
            sum(class_info.pattern), ...
            sum(class_info.component), ...
            sum(class_info.unclassified), ...
            sum(class_info.invalid));
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

function r2_file = resolveR2FileLocal( ...
    session_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix)

    file_name = sprintf('%s_%s_stimtype_R2_%s.mat', ...
        data_content, model_mode, reconstruction_suffix);

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
    R, expected_content, expected_mode, probes, field_names, ...
    stim_types, source_file)

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

    y_dims = double(R.yDims(:)');
    num_groups = numel(probes);

    if numel(y_dims) ~= num_groups || ...
            any(~isfinite(y_dims)) || ...
            any(y_dims ~= round(y_dims)) || ...
            any(y_dims < 1)
        error('%s: yDims does not match probes or is invalid.', ...
            source_file);
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
    reference, R, probes, group_labels, field_names, stim_types, ...
    session_dir)

    if isempty(fieldnames(reference))
        reference.num_groups = numel(R.yDims);
        reference.probes = double(probes(:)');
        reference.group_labels = reshape(group_labels, 1, []);
        reference.field_names = reshape(field_names, 1, []);
        reference.stim_types = reshape(stim_types, 1, []);
        return;
    end

    if numel(R.yDims) ~= reference.num_groups
        error('%s: number of groups differs across sessions.', ...
            session_dir);
    end

    if ~isequal(double(probes(:)'), reference.probes)
        error('%s: probe order differs across sessions.', session_dir);
    end

    if ~isequal(reshape(group_labels, 1, []), ...
            reference.group_labels) || ...
            ~isequal(reshape(field_names, 1, []), ...
            reference.field_names) || ...
            ~isequal(reshape(stim_types, 1, []), ...
            reference.stim_types)
        error('%s: plotting labels or field order differ across sessions.', ...
            session_dir);
    end
end

function vec = getGroupR2VectorLocal(stim_result, field_name, group_idx)
    by_group = stim_result.(field_name).neuron_by_group;
    vec = double(by_group{group_idx}(:));
end

function [gpl_file, gpl_results] = loadOneGplFileLocal( ...
    session_dir, run_g, probe_id, gpl_mat_name)

    probe_folder = fullfile(session_dir, ...
        sprintf('%s_imec%d', run_g, probe_id));

    if ~isfolder(probe_folder)
        error('Probe folder not found: %s', probe_folder);
    end

    d = dir(fullfile(probe_folder, 'kilosort*', gpl_mat_name));
    d = d(~[d.isdir]);

    if isempty(d)
        error('No %s found under %s/kilosort*.', ...
            gpl_mat_name, probe_folder);
    end

    if numel(d) > 1
        paths = arrayfun(@(x) fullfile(x.folder, x.name), ...
            d, 'UniformOutput', false);

        error('Multiple GPL files found for probe %d:\n%s', ...
            probe_id, strjoin(paths, '\n'));
    end

    gpl_file = fullfile(d(1).folder, d(1).name);
    S = load(gpl_file, 'gpl_results');

    if ~isfield(S, 'gpl_results')
        error('%s does not contain gpl_results.', gpl_file);
    end

    gpl_results = S.gpl_results;
end

function info = validateAndExtractClassesLocal( ...
    G, model_ids, group_idx, probe_id, group_label, gpl_file)

    if ~isfield(G, 'used_unit_ids') || ~isfield(G, 'plaid')
        error('%s lacks used_unit_ids or plaid classification.', ...
            gpl_file);
    end

    if ~isfield(G, 'baseline_subtracted') || ...
            ~isscalar(G.baseline_subtracted) || ...
            ~logical(G.baseline_subtracted)
        error('%s is not marked baseline_subtracted = true.', gpl_file);
    end

    gpl_ids = double(G.used_unit_ids(:));
    model_ids = double(model_ids(:));

    if numel(gpl_ids) ~= numel(model_ids)
        error(['Neuron-count mismatch for Group %d (%s, probe %d): ', ...
            'reconstruction=%d, GPL=%d.'], ...
            group_idx, group_label, probe_id, ...
            numel(model_ids), numel(gpl_ids));
    end

    if numel(unique(gpl_ids)) ~= numel(gpl_ids) || ...
            numel(unique(model_ids)) ~= numel(model_ids)
        error('Duplicate unit IDs found for Group %d (%s).', ...
            group_idx, group_label);
    end

    if ~isequal(sort(gpl_ids), sort(model_ids))
        error(['GPL/reconstruction unit-ID sets differ for Group %d ', ...
            '(%s, probe %d).'], ...
            group_idx, group_label, probe_id);
    end

    if ~isequal(gpl_ids, model_ids)
        error(['GPL/reconstruction unit-ID order differs for Group %d ', ...
            '(%s, probe %d).'], ...
            group_idx, group_label, probe_id);
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
            'for Group %d (%s). Affected IDs: %s'], ...
            group_idx, group_label, summarizeIdsLocal(bad_ids));
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

function M = buildMultiSessionSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, probes, group_labels, gpl_mat_name, ...
    class_names, class_labels, field_names, field_labels, stim_types, ...
    output_base, group_colors_base, session_colors_by_group, ...
    light_start, light_end)

    num_sessions = numel(records);
    num_groups = numel(probes);

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

    M = struct();

    M.meta.root_dir = root_dir;
    M.meta.data_content = data_content;
    M.meta.model_mode = model_mode;
    M.meta.runIdx = runIdx;
    M.meta.reconstruction_suffix = reconstruction_suffix;
    M.meta.gpl_mat_name = gpl_mat_name;
    M.meta.output_base = output_base;
    M.meta.num_sessions = num_sessions;
    M.meta.num_groups = num_groups;
    M.meta.num_stim_types = numel(stim_types);
    M.meta.num_reconstruction_fields = numel(field_names);

    M.settings.probes = probes;
    M.settings.group_colors_base = group_colors_base;
    M.settings.session_color_lightness_start = light_start;
    M.settings.session_color_lightness_end = light_end;

    M.labels.group = reshape(group_labels, 1, []);
    M.labels.session = {session_info.session_label};
    M.labels.class_name = reshape(class_names, 1, []);
    M.labels.class = reshape(class_labels, 1, []);
    M.labels.reconstruction_field_name = reshape(field_names, 1, []);
    M.labels.reconstruction_field = reshape(field_labels, 1, []);
    M.labels.stimulus = reshape(stim_types, 1, []);

    M.sessions.included = session_info;
    M.sessions.skipped = skipped;

    M.session_data = [records{:}];
    M.plot.session_colors_by_group = session_colors_by_group;

    M.dimension_names.r2_matrix = { ...
        'neuron', 'reconstruction_field'};

    M.notes.trajectory_order = ...
        'all -> across -> within -> feedforward -> feedback';
    M.notes.classification_source = ...
        'spontaneous-subtracted GPL plaid classification';
    M.notes.invalid_neurons = [ ...
        'Invalid neurons remain in alignment checks and saved data, ', ...
        'but are excluded from figures.'];
    M.notes.session_sorting = [ ...
        'Sessions are sorted by the number following p in the parent ', ...
        'session folder name, then by parent and CatGT folder name.'];
end

function session_colors = makeSessionColorsByGroupLocal( ...
    group_colors, num_sessions, light_start, light_end)

    num_groups = size(group_colors, 1);
    session_colors = nan(num_groups, num_sessions, 3);

    if num_sessions == 1
        lightness = light_end;
    else
        lightness = linspace(light_start, light_end, num_sessions);
    end

    for g = 1:num_groups
        base = group_colors(g, :);

        for s = 1:num_sessions
            f = lightness(s);
            session_colors(g, s, :) = ...
                (1 - f) .* base + f .* [1, 1, 1];
        end
    end
end

function fig = plotOneSummaryLocal( ...
    records, group_idx, stim_name, group_label, ...
    class_names, class_labels, field_labels, ...
    session_colors_by_group, within_step, class_gap, ...
    line_width, line_alpha, marker_size, marker_alpha, ...
    font_name, axis_font_size, class_font_size, ...
    title_font_size, legend_font_size, axis_line_width, ...
    figure_visible, figure_width, figure_height)

    num_sessions = numel(records);
    num_classes = numel(class_names);
    num_fields = numel(field_labels);

    block_width = (num_fields - 1) * within_step;
    x_by_class = cell(1, num_classes);

    for c = 1:num_classes
        x0 = 1 + (c - 1) * (block_width + class_gap);
        x_by_class{c} = x0 + (0:num_fields - 1) * within_step;
    end

    all_values = [];

    for s = 1:num_sessions
        G = records{s}.group(group_idx);
        plotted_mask = ...
            G.class_info.pattern | ...
            G.class_info.component | ...
            G.class_info.unclassified;

        Y = G.stim.(stim_name).r2_matrix;
        this_values = Y(plotted_mask, :);
        all_values = [all_values; this_values(:)]; %#ok<AGROW>
    end

    y_limits = paddedLimitsLocal(all_values, [-1, 1]);

    figure_name = sprintf('%s %s GPL-class R2 summary', ...
        group_label, stimulusDisplayNameLocal(stim_name));

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
    set(ax, 'Position', [0.065, 0.235, 0.78, 0.69]);

    x_left = x_by_class{1}(1) - 0.55 * within_step;
    x_right = x_by_class{end}(end) + 0.55 * within_step;

    if y_limits(1) < 0 && y_limits(2) > 0
        plot(ax, [x_left, x_right], [0, 0], 'k--', ...
            'LineWidth', 1, 'HandleVisibility', 'off');
    end

    for c = 1:(num_classes - 1)
        separator_x = ...
            0.5 * (x_by_class{c}(end) + x_by_class{c + 1}(1));

        plot(ax, [separator_x, separator_x], y_limits, '-', ...
            'Color', [0.75, 0.75, 0.75], ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    for s = 1:num_sessions
        G = records{s}.group(group_idx);
        color_value = reshape( ...
            session_colors_by_group(group_idx, s, :), 1, 3);

        for c = 1:num_classes
            class_mask = G.class_info.(class_names{c});
            Y = G.stim.(stim_name).r2_matrix(class_mask, :);

            drawTrajectorySetLocal( ...
                ax, x_by_class{c}, Y, color_value, ...
                line_width, line_alpha, marker_size, marker_alpha);
        end
    end

    all_x = [x_by_class{:}];
    tick_labels = repmat(field_labels, 1, num_classes);

    set(ax, ...
        'XLim', [x_left, x_right], ...
        'YLim', y_limits, ...
        'XTick', all_x, ...
        'XTickLabel', tick_labels, ...
        'TickLabelInterpreter', 'none');

    ylabel(ax, 'Reconstruction R^2', ...
        'Interpreter', 'tex', ...
        'FontName', font_name, ...
        'FontSize', axis_font_size, ...
        'FontWeight', 'normal');

    title(ax, sprintf('%s | %s', ...
        group_label, stimulusDisplayNameLocal(stim_name)), ...
        'Interpreter', 'none', ...
        'FontName', font_name, ...
        'FontSize', title_font_size, ...
        'FontWeight', 'bold');

    cleanAxisLocal(ax, font_name, axis_font_size, axis_line_width);

    % Sparse second row of x-axis labels: one centered class label per block.
    y_text = y_limits(1) - 0.135 * diff(y_limits);

    for c = 1:num_classes
        text(ax, mean(x_by_class{c}), y_text, class_labels{c}, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', ...
            'Interpreter', 'none', ...
            'Clipping', 'off', ...
            'FontName', font_name, ...
            'FontSize', class_font_size, ...
            'FontWeight', 'normal');
    end

    session_labels = cell(1, num_sessions);

    for s = 1:num_sessions
        session_labels{s} = records{s}.session_label;
    end

    addSessionLegendLocal( ...
        ax, session_colors_by_group, group_idx, session_labels, ...
        line_width, marker_size, font_name, legend_font_size);

    hold(ax, 'off');
end

function drawTrajectorySetLocal( ...
    ax, x_values, Y, color_value, line_width, line_alpha, ...
    marker_size, marker_alpha)

    if isempty(Y)
        return;
    end

    Y = double(Y);

    try
        plot(ax, x_values, Y', '-', ...
            'Color', [color_value, line_alpha], ...
            'LineWidth', line_width, ...
            'HandleVisibility', 'off');
    catch
        mixed_line_color = ...
            1 - line_alpha .* (1 - color_value);

        plot(ax, x_values, Y', '-', ...
            'Color', mixed_line_color, ...
            'LineWidth', line_width, ...
            'HandleVisibility', 'off');
    end

    x_matrix = repmat(x_values, size(Y, 1), 1);
    valid = isfinite(Y);

    if ~any(valid(:))
        return;
    end

    try
        scatter(ax, x_matrix(valid), Y(valid), marker_size, 'o', ...
            'MarkerFaceColor', color_value, ...
            'MarkerEdgeColor', color_value, ...
            'MarkerFaceAlpha', marker_alpha, ...
            'MarkerEdgeAlpha', marker_alpha, ...
            'HandleVisibility', 'off');
    catch
        mixed_marker_color = ...
            1 - marker_alpha .* (1 - color_value);

        scatter(ax, x_matrix(valid), Y(valid), marker_size, 'o', ...
            'MarkerFaceColor', mixed_marker_color, ...
            'MarkerEdgeColor', mixed_marker_color, ...
            'HandleVisibility', 'off');
    end
end

function addSessionLegendLocal( ...
    ax, session_colors_by_group, group_idx, session_labels, ...
    line_width, marker_size, font_name, font_size)

    num_sessions = numel(session_labels);
    h = gobjects(num_sessions, 1);

    for s = 1:num_sessions
        color_value = reshape( ...
            session_colors_by_group(group_idx, s, :), 1, 3);

        h(s) = plot(ax, NaN, NaN, '-o', ...
            'Color', color_value, ...
            'MarkerFaceColor', color_value, ...
            'MarkerEdgeColor', color_value, ...
            'LineWidth', max(1, line_width), ...
            'MarkerSize', max(3, sqrt(marker_size)), ...
            'DisplayName', session_labels{s});
    end

    lgd = legend(ax, h, session_labels, ...
        'Location', 'eastoutside', ...
        'Box', 'off', ...
        'Interpreter', 'none', ...
        'FontName', font_name, ...
        'FontSize', font_size);

    try
        lgd.Title.String = 'Session';
        lgd.Title.FontWeight = 'normal';
    catch
    end

    if num_sessions > 10
        try
            lgd.NumColumns = 2;
        catch
        end
    end

    try
        lgd.AutoUpdate = 'off';
    catch
    end
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

function label = stimulusDisplayNameLocal(stim_name)
    stim_name = char(stim_name);

    if isempty(stim_name)
        label = '';
        return;
    end

    label = lower(stim_name);
    label(1) = upper(label(1));
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
