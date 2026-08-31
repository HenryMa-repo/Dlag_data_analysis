%% sum_GPL_class_deltaR2_by_area.m
% Summarize neuron-wise reconstruction delta R2 across sessions after
% grouping neurons by spontaneous-subtracted GPL classification.
%
% For every neuron and stimulus type, this script computes:
%   acr_vs_wit = R2(use_across)      - R2(use_within)
%   ff_vs_fb   = R2(use_feedforward) - R2(use_feedback)
%
% Z-scoring is performed separately for every session and model group/area.
% Within one session-area, one common mean and one common sample SD are
% calculated after pooling all finite raw delta values from:
%   - all plotted GPL classes: pattern, component, unclassified;
%   - both delta types: acr_vs_wit, ff_vs_fb;
%   - both stimulus types: grating, plaid.
% The same mean and SD are then applied to all four delta vectors in that
% session-area. V1 and MT (or other supplied model groups) are never mixed.
%
% Invalid GPL neurons remain in all population/unit-ID alignment checks and
% in session_data, but they are excluded from the z-score pool and figures.
%
% Four figures are produced for the usual two-group, two-stimulus setup:
%   Group 1 grating, Group 1 plaid, Group 2 grating, Group 2 plaid.
% Each figure contains six violins in three class blocks:
%   Pattern:      acr vs. wit, FF vs. FB
%   Component:    acr vs. wit, FF vs. FB
%   Unclassified: acr vs. wit, FF vs. FB
%
% Every plotted point is one neuron delta. Sessions are pooled without
% session-specific color, legend, or connecting line. The saved MAT retains
% the original session identity, raw deltas, z-scored deltas, and the exact
% z-score mean/SD used for every session-area.

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

% Must match the source file produced by
% calculate_stimtype_reconstruction_R2.m.
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
save_svg = true;
save_png = true;
close_after_save = true;

figure_visible = 'on';
% 'on' or 'off'

png_dpi = 400;
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
% Area colors and layout
% -------------------------------------------------------------------------

% Same area colors as sum_GPL_class_R2_by_area.m.
group_colors_base = [ ...
    0.0000, 0.4470, 0.7410; ...
    0.8500, 0.3250, 0.0980];

within_class_step = 1.0;
between_class_gap = 1.7;

% Article-figure typography and dimensions.
font_name = 'Arial';
axis_font_size = 11;
class_label_font_size = 10;
title_font_size = 12;
axis_line_width = 1;

figure_width = 1200;
figure_height = 720;

% -------------------------------------------------------------------------
% Fixed labels and source-field definitions
% -------------------------------------------------------------------------

class_names = {'pattern', 'component', 'unclassified'};
class_labels = {'Pattern cell', 'Component cell', 'Unclassified cell'};
class_markers = {'o', 's', '^'};

stim_types = {'grating', 'plaid'};

source_r2_field_names = { ...
    'use_across', ...
    'use_within', ...
    'use_feedforward', ...
    'use_feedback'};

source_r2_field_labels = {'across', 'within', 'FF', 'FB'};

delta_names = {'acr_vs_wit', 'ff_vs_fb'};
delta_labels = {'acr vs. wit', 'ff vs. fb'};

delta_positive_fields = {'use_across', 'use_feedforward'};
delta_negative_fields = {'use_within', 'use_feedback'};

%% ======================= VALIDATE SETTINGS =============================

group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);
mapping_file_tag = strjoin(group_file_tags, '_');

validateUserSettingsLocal( ...
    root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, group_names, gpl_mat_name, ...
    group_colors_base, figure_visible, ...
    class_names, class_labels, class_markers, ...
    source_r2_field_names, source_r2_field_labels, ...
    delta_names, delta_labels, ...
    delta_positive_fields, delta_negative_fields, stim_types, ...
    violin_summary_type, ...
    save_mat, save_fig, save_svg, save_png, close_after_save, ...
    png_dpi, violin_width, violin_face_alpha, ...
    show_violin_points, violin_point_size, ...
    violin_point_jitter_width, violin_point_alpha, ...
    within_class_step, between_class_gap, ...
    figure_width, figure_height);

model_tag = makeModelTagLocal(model_mode);
output_prefix = sprintf( ...
    '%s_%s_GPLclass_deltaR2_zscore_acr_vs_wit_ff_vs_fb', ...
    data_content, model_tag);
output_base = sprintf('%s_%s', output_prefix, mapping_file_tag);

fprintf('\n============================================================\n');
fprintf('Across-session GPL-class delta R2 summary by area\n');
fprintf('Root dir              : %s\n', root_dir);
fprintf('Data content          : %s\n', data_content);
fprintf('Model mode            : %s\n', model_mode);
fprintf('Run index             : %d\n', runIdx);
fprintf('GPL MAT               : %s\n', gpl_mat_name);
fprintf('Delta 1               : across - within\n');
fprintf('Delta 2               : feedforward - feedback\n');
fprintf(['Z-score pool          : within each session x area, ', ...
    'all P/C/U neurons x 2 deltas x 2 stimuli\n']);
fprintf('Z-score SD            : sample SD (N-1 normalization)\n');
fprintf('Violin summary bar    : %s\n', violin_summary_type);
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
            session_dir, data_content, model_mode, runIdx, ...
            reconstruction_suffix, group_names, group_display_names, ...
            group_file_tags, gpl_mat_name, ...
            source_r2_field_names, delta_names, ...
            delta_positive_fields, delta_negative_fields, ...
            stim_types, reference);

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
    records, skipped, root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, ...
    source_r2_field_names, source_r2_field_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, ...
    output_prefix, output_base, group_colors_base, ...
    violin_summary_type);

if save_mat
    mat_file = fullfile(root_dir, [output_base, '.mat']);
    save(mat_file, 'MultiSessionGPLClassDeltaR2', '-v7.3');
    fprintf('\nSaved MAT:\n  %s\n', mat_file);
end

%% ======================= PLOT GROUP FIGURES ============================

fig_handles = gobjects(numel(group_names), numel(stim_types));

for g = 1:numel(group_names)
    for st = 1:numel(stim_types)
        stim_name = stim_types{st};

        fig = plotOneDeltaSummaryLocal( ...
            MultiSessionGPLClassDeltaR2.pooled(g), ...
            stim_name, group_display_names{g}, ...
            class_names, class_labels, class_markers, ...
            delta_names, delta_labels, group_colors_base(g, :), ...
            violin_summary_type, violin_width, violin_face_alpha, ...
            show_violin_points, violin_point_size, ...
            violin_point_jitter_width, violin_point_alpha, ...
            within_class_step, between_class_gap, ...
            font_name, axis_font_size, class_label_font_size, ...
            title_font_size, axis_line_width, ...
            figure_visible, figure_width, figure_height);

        fig_handles(g, st) = fig;

        figure_base = sprintf('%s_%s_%s', ...
            output_prefix, group_file_tags{g}, stim_name);

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
    reconstruction_suffix, group_names, gpl_mat_name, ...
    group_colors_base, figure_visible, ...
    class_names, class_labels, class_markers, ...
    source_field_names, source_field_labels, ...
    delta_names, delta_labels, ...
    delta_positive_fields, delta_negative_fields, stim_types, ...
    violin_summary_type, ...
    save_mat, save_fig, save_svg, save_png, close_after_save, ...
    png_dpi, violin_width, violin_face_alpha, ...
    show_violin_points, violin_point_size, ...
    violin_point_jitter_width, violin_point_alpha, ...
    within_class_step, between_class_gap, ...
    figure_width, figure_height)

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

    if ~iscell(group_names) || isempty(group_names)
        error('group_names must be a nonempty cell array of text.');
    end

    for g = 1:numel(group_names)
        requireNonemptyTextLocal(group_names{g}, ...
            sprintf('group_names{%d}', g));
    end

    if size(group_colors_base, 1) < numel(group_names) || ...
            size(group_colors_base, 2) ~= 3 || ...
            any(~isfinite(group_colors_base(:))) || ...
            any(group_colors_base(:) < 0) || ...
            any(group_colors_base(:) > 1)
        error(['group_colors_base must contain one finite RGB row in ', ...
            '[0,1] per group.']);
    end

    validateParallelLabelListsLocal( ...
        class_names, class_labels, 'class_names', 'class_labels');

    for c = 1:numel(class_names)
        if ~isvarname(char(class_names{c}))
            error('class_names{%d} must be a valid MATLAB field name.', c);
        end
    end
    validateParallelLabelListsLocal( ...
        source_field_names, source_field_labels, ...
        'source_r2_field_names', 'source_r2_field_labels');
    validateParallelLabelListsLocal( ...
        delta_names, delta_labels, 'delta_names', 'delta_labels');

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

    for st = 1:numel(stim_types)
        requireNonemptyTextLocal(stim_types{st}, ...
            sprintf('stim_types{%d}', st));

        if ~isvarname(char(stim_types{st}))
            error('stim_types{%d} must be a valid MATLAB field name.', st);
        end
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
    validateattributes(within_class_step, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, ...
        mfilename, 'within_class_step');
    validateattributes(between_class_gap, {'numeric'}, ...
        {'scalar', 'nonnegative', 'finite'}, ...
        mfilename, 'between_class_gap');
    validateattributes(figure_width, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'figure_width');
    validateattributes(figure_height, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'figure_height');
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
    session_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, gpl_mat_name, source_field_names, delta_names, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, reference)

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
    num_groups = numel(group_names);

    validateStimtypeR2Local( ...
        R, data_content, model_mode, num_groups, source_field_names, ...
        stim_types, r2_file);

    reference = validateOrInitializeReferenceLocal( ...
        reference, R, group_names, group_display_names, ...
        group_file_tags, source_field_names, delta_names, ...
        stim_types, session_dir);

    empty_group = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'unit_ids', [], ...
        'gpl_file', '', ...
        'class_info', struct(), ...
        'zscore', struct(), ...
        'stim', struct());

    groups = repmat(empty_group, 1, num_groups);

    fprintf('  R2 file: %s\n', r2_file);

    [gpl_group_by_index, gpl_file_by_index] = ...
        loadGplGroupsByModelIndexLocal( ...
        session_dir, gpl_mat_name, num_groups);

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
            source_r2_matrix = nan( ...
                numel(model_ids), numel(source_field_names));

            for f = 1:numel(source_field_names)
                source_r2_matrix(:, f) = getGroupR2VectorLocal( ...
                    R.(stim_name), source_field_names{f}, g);
            end

            raw_delta_matrix = nan( ...
                numel(model_ids), numel(delta_names));

            for d = 1:numel(delta_names)
                positive_idx = find(strcmp( ...
                    source_field_names, delta_positive_fields{d}), ...
                    1, 'first');
                negative_idx = find(strcmp( ...
                    source_field_names, delta_negative_fields{d}), ...
                    1, 'first');

                if isempty(positive_idx) || isempty(negative_idx)
                    error('Could not resolve source fields for delta %s.', ...
                        delta_names{d});
                end

                raw_delta_matrix(:, d) = ...
                    source_r2_matrix(:, positive_idx) - ...
                    source_r2_matrix(:, negative_idx);
            end

            groups(g).stim.(stim_name).source_r2_matrix = ...
                source_r2_matrix;
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

        zscore_pool = [];

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            this_delta = groups(g).stim.(stim_name).raw_delta_matrix;
            this_delta = this_delta(plotted_mask, :);
            zscore_pool = [zscore_pool; this_delta(:)]; %#ok<AGROW>
        end

        num_possible = numel(zscore_pool);
        zscore_pool = zscore_pool(isfinite(zscore_pool));

        if numel(zscore_pool) < 2
            error(['%s has fewer than two finite delta R2 values in ', ...
                'the session-area z-score pool.'], ...
                group_display_names{g});
        end

        pool_mean = mean(zscore_pool);
        pool_sd = std(zscore_pool, 0);

        if ~isfinite(pool_mean) || ~isfinite(pool_sd) || pool_sd <= 0
            error(['%s has an invalid or zero sample SD in the ', ...
                'session-area delta R2 z-score pool.'], ...
                group_display_names{g});
        end

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            raw_delta_matrix = ...
                groups(g).stim.(stim_name).raw_delta_matrix;
            groups(g).stim.(stim_name).z_delta_matrix = ...
                (raw_delta_matrix - pool_mean) ./ pool_sd;

            for d = 1:numel(delta_names)
                groups(g).stim.(stim_name).z_delta.( ...
                    delta_names{d}) = ...
                    groups(g).stim.(stim_name).z_delta_matrix(:, d);
            end
        end

        groups(g).zscore.pool_mean = pool_mean;
        groups(g).zscore.pool_sd = pool_sd;
        groups(g).zscore.std_normalization = 0;
        groups(g).zscore.n_finite = numel(zscore_pool);
        groups(g).zscore.n_possible = num_possible;
        groups(g).zscore.n_nonfinite = ...
            num_possible - numel(zscore_pool);
        groups(g).zscore.pooling_scope = [ ...
            'all finite P/C/U neuron delta values pooled across ', ...
            'acr_vs_wit, ff_vs_fb, grating, and plaid within ', ...
            'this session and model group/area'];

        fprintf(['  %s: pattern=%d, component=%d, ', ...
            'unclassified=%d, invalid=%d, ', ...
            'z-mean=%.6g, z-SD=%.6g, z-N=%d/%d\n'], ...
            group_display_names{g}, ...
            sum(class_info.pattern), ...
            sum(class_info.component), ...
            sum(class_info.unclassified), ...
            sum(class_info.invalid), ...
            pool_mean, pool_sd, numel(zscore_pool), num_possible);
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
    R, expected_content, expected_mode, expected_num_groups, field_names, ...
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
    source_field_names, delta_names, stim_types, session_dir)

    if isempty(fieldnames(reference))
        reference.num_groups = numel(R.yDims);
        reference.group_names = reshape(group_names, 1, []);
        reference.group_display_names = ...
            reshape(group_display_names, 1, []);
        reference.group_file_tags = reshape(group_file_tags, 1, []);
        reference.source_field_names = ...
            reshape(source_field_names, 1, []);
        reference.delta_names = reshape(delta_names, 1, []);
        reference.stim_types = reshape(stim_types, 1, []);
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
            ~isequal(reshape(source_field_names, 1, []), ...
            reference.source_field_names) || ...
            ~isequal(reshape(delta_names, 1, []), ...
            reference.delta_names) || ...
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
    records, skipped, root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, ...
    source_field_names, source_field_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, ...
    output_prefix, output_base, group_colors_base, ...
    violin_summary_type)

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
        'pooling_scope', '');

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
                C.finite_count_raw_by_delta = ...
                    sum(isfinite(raw_delta_matrix), 1);
                C.finite_count_z_by_delta = ...
                    sum(isfinite(z_delta_matrix), 1);

                pooled(g).stim.(stim_name).class.(class_name) = C;
            end
        end
    end

    M = struct();

    M.meta.format_version = 'GPL_class_deltaR2_by_area_v1';
    M.meta.root_dir = root_dir;
    M.meta.data_content = data_content;
    M.meta.model_mode = model_mode;
    M.meta.runIdx = runIdx;
    M.meta.reconstruction_suffix = reconstruction_suffix;
    M.meta.gpl_mat_name = gpl_mat_name;
    M.meta.output_prefix = output_prefix;
    M.meta.output_base = output_base;
    M.meta.mapping_file_tag = mapping_file_tag;
    M.meta.num_sessions = num_sessions;
    M.meta.num_groups = num_groups;
    M.meta.num_stim_types = numel(stim_types);
    M.meta.num_delta_types = numel(delta_names);

    M.settings.group_colors_base = group_colors_base;
    M.settings.violin_summary_type = violin_summary_type;
    M.settings.zscore_std_normalization = 0;

    M.labels.group = reshape(group_display_names, 1, []);
    M.labels.group_name = reshape(group_names, 1, []);
    M.labels.group_display_name = reshape(group_display_names, 1, []);
    M.labels.group_file_tag = reshape(group_file_tags, 1, []);
    M.labels.session = {session_info.session_label};
    M.labels.class_name = reshape(class_names, 1, []);
    M.labels.class = reshape(class_labels, 1, []);
    M.labels.class_marker = reshape(class_markers, 1, []);
    M.labels.source_r2_field_name = ...
        reshape(source_field_names, 1, []);
    M.labels.source_r2_field = ...
        reshape(source_field_labels, 1, []);
    M.labels.delta_name = reshape(delta_names, 1, []);
    M.labels.delta = reshape(delta_labels, 1, []);
    M.labels.delta_positive_field = ...
        reshape(delta_positive_fields, 1, []);
    M.labels.delta_negative_field = ...
        reshape(delta_negative_fields, 1, []);
    M.labels.stimulus = reshape(stim_types, 1, []);

    M.sessions.included = session_info;
    M.sessions.skipped = skipped;

    M.session_data = [records{:}];
    M.zscore_by_session_area = zscore_by_session_area;
    M.pooled = pooled;

    M.dimension_names.source_r2_matrix = { ...
        'neuron', 'source_r2_field'};
    M.dimension_names.raw_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.z_delta_matrix = {'neuron', 'delta_type'};

    M.notes.delta_definition = [ ...
        'acr_vs_wit = use_across R2 - use_within R2; ', ...
        'ff_vs_fb = use_feedforward R2 - use_feedback R2'];
    M.notes.zscore_definition = [ ...
        'For every session and area/model group separately, one mean and ', ...
        'one sample SD are calculated from all finite raw delta values ', ...
        'after pooling pattern/component/unclassified neurons, both ', ...
        'delta types, and grating/plaid. The same mean and SD are applied ', ...
        'to all four delta vectors in that session-area.'];
    M.notes.invalid_neurons = [ ...
        'Invalid neurons remain in alignment checks and session_data, ', ...
        'but are excluded from the z-score pool and pooled figures.'];
    M.notes.classification_source = [ ...
        'Spontaneous-subtracted GPL plaid classification selected from ', ...
        'nested GPL group entries by model_group_index.'];
    M.notes.session_plot_encoding = [ ...
        'Session identity is retained in the MAT but is not encoded by ', ...
        'color, shade, legend, or connecting lines in the figures.'];
end

function fig = plotOneDeltaSummaryLocal( ...
    pooled_group, stim_name, group_display_name, ...
    class_names, class_labels, class_markers, ...
    delta_names, delta_labels, this_color, ...
    summary_type, violin_width, violin_face_alpha, ...
    show_points, point_size, point_jitter_width, point_alpha, ...
    within_step, class_gap, ...
    font_name, axis_font_size, class_font_size, ...
    title_font_size, axis_line_width, ...
    figure_visible, figure_width, figure_height)

    num_classes = numel(class_names);
    num_deltas = numel(delta_names);
    block_width = (num_deltas - 1) * within_step;
    x_by_class = cell(1, num_classes);

    for c = 1:num_classes
        x0 = 1 + (c - 1) * (block_width + class_gap);
        x_by_class{c} = x0 + (0:num_deltas - 1) * within_step;
    end

    all_values = [];

    for c = 1:num_classes
        C = pooled_group.stim.(stim_name).class.(class_names{c});

        for d = 1:num_deltas
            vals = C.z_delta_matrix(:, d);
            all_values = [all_values; vals(isfinite(vals))]; %#ok<AGROW>
        end
    end

    y_limits = paddedLimitsLocal(all_values, [-3, 3]);

    figure_name = sprintf('%s %s GPL-class delta R2', ...
        group_display_name, stimulusDisplayNameLocal(stim_name));

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
    set(ax, 'Position', [0.085, 0.235, 0.89, 0.69]);

    x_left = x_by_class{1}(1) - 0.60 * within_step;
    x_right = x_by_class{end}(end) + 0.60 * within_step;

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

    for c = 1:num_classes
        C = pooled_group.stim.(stim_name).class.(class_names{c});

        for d = 1:num_deltas
            vals = C.z_delta_matrix(:, d);

            drawOneViolinLocal( ...
                ax, vals, x_by_class{c}(d), ...
                violin_width, this_color, violin_face_alpha, ...
                summary_type, show_points, point_size, ...
                point_jitter_width, point_alpha, class_markers{c});
        end
    end

    all_x = [x_by_class{:}];
    tick_labels = repmat(delta_labels, 1, num_classes);

    set(ax, ...
        'XLim', [x_left, x_right], ...
        'YLim', y_limits, ...
        'XTick', all_x, ...
        'XTickLabel', tick_labels, ...
        'TickLabelInterpreter', 'none');

    ylabel(ax, 'Z-scored \DeltaR^2', ...
        'Interpreter', 'tex', ...
        'FontName', font_name, ...
        'FontSize', axis_font_size, ...
        'FontWeight', 'normal');

    title(ax, sprintf('%s | %s', ...
        group_display_name, stimulusDisplayNameLocal(stim_name)), ...
        'Interpreter', 'none', ...
        'FontName', font_name, ...
        'FontSize', title_font_size, ...
        'FontWeight', 'bold');

    cleanAxisLocal(ax, font_name, axis_font_size, axis_line_width);

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

    hold(ax, 'off');
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
