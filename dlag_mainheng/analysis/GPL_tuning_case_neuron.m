%% =========================================================================
% GPL_tuning_case_neuron
%
% Plot selected neurons from an existing GPL_analysis_by_area result MAT.
% Run this SCRIPT from an empty workspace; it loads its own input files.
%
% IMPORTANT ID DEFINITION
% - A neuron ID is its 1-based LOCAL position within its target MODEL GROUP,
%   as used by reconstruction_visualization_case_example for the same target
%   run and retained unit population. It is not a Kilosort cluster ID, a
%   global row across groups, or the position in a depth-sorted tuning grid.
% - target_unit_index maps each saved tuning row to that original local ID.
%   Missing GPL neurons leave gaps; cells are never renumbered.
% - With nan_trial_strategy == 6, the existing GPL analysis selects the
%   target raw_fr population. Local IDs agree with reconstruction when its
%   retained population is the same. No model population is changed here.
%
% INPUT / OUTPUT
% - Input is unit_gpl_results.mat or unit_gpl_results_sponsub.mat in the
%   corresponding probe/kilosort* folder, selected by subtract_spontaneous.
% - Compatible with the existing grouped_by_probe_v1 result structure.
%   The input MAT is read only; no MAT is created or rewritten by this script.
% - One figure per requested neuron: grating on the left, plaid on the right.
%   Grating shows DI and OSI; plaid shows PI. Saved indices are not recomputed.
% - Response is mean firing rate over the saved GPL analysis window, in
%   spikes/s (Hz), not spike count. In sponsub mode, both the mean and the
%   SD/SEM use the already saved trial-wise baseline-subtracted responses.
% - Save SVG, PNG and FIG independently. Outputs go beside the input MAT,
%   which is also where GPL_analysis_by_area saves its tuning grids. Saved
%   absolute .ksDir/.files paths are not used, so moved sessions still work.
% - Filename includes model group, area, local ID, error type and _sponsub
%   when applicable, e.g. Group1_V1_neuron125_tuning_SD_sponsub.svg.
% - Different groups may request different numbers of cells; [] skips a
%   group. A target neuron absent from GPL data is reported and skipped.
% =========================================================================

clc;
clear;

%% ----------------------- User parameters -----------------------
root_folder = 'I:\np_data';
runName = 'RafiL001p0120';
runind = 1;

% All model groups, in their original model-group order. Keep these equal
% to the mapping used when generating the GPL result MATs.
group_probes = [0, 1];
group_names = {'V1', 'MT'};

% One entry per model group. Any number of local IDs, or [] to skip.
% Example: {[125 173], []} plots only the two Group-1 neurons.
case_neuron_ids = { ...
    [125 173], ...  % Group 1: V1
    [36 165]   ...  % Group 2: MT; replace with [] to skip
    };

% Check stimulus identities against the selected saved analysis.
gpl_stim_tag = '[dir12_gpl_2_200isi_fixedphase]';
target_stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';

% true: load unit_gpl_results_sponsub.mat and plot sponsub curves.
% false: load unit_gpl_results.mat and plot raw firing-rate curves.
% This uses saved results; it never recalculates baseline or indices.
subtract_spontaneous = true;
gpl_mat_name = 'unit_gpl_results.mat';

% Error band: 'SEM' or 'SD'. Both are already present in the input MAT.
error_method = 'SD';

save_svg = true;
save_png = true;
save_fig = true;
close_after_save = false;
figure_visibility = 'on';

figure_width = 1000;
figure_height = 460;
axis_font_size = 11;
panel_title_font_size = 12;
curve_line_width = 1.5;
png_dpi = 300;

%% ----------------------- Validate user parameters -----------------------
group_names = normalize_text_list_local(group_names, 'group_names');
group_names = reshape(group_names, 1, []);
if ~isnumeric(group_probes) || ~isreal(group_probes) || ...
        ~isvector(group_probes) || isempty(group_probes)
    error('group_probes must be a nonempty numeric vector.');
end
group_probes = double(group_probes(:)');
if numel(group_names) ~= numel(group_probes) || ...
        any(~isfinite(group_probes)) || any(group_probes < 0) || ...
        any(group_probes ~= round(group_probes))
    error('Group names and finite nonnegative integer probe IDs must match.');
end
for g = 1:numel(group_names)
    if any(group_probes(1:g-1) == group_probes(g) & ...
            strcmp(group_names(1:g-1), group_names{g}))
        error('Repeated probe/area pair: probe %d, area %s.', ...
            group_probes(g), group_names{g});
    end
end
if ~iscell(case_neuron_ids) || numel(case_neuron_ids) ~= numel(group_names)
    error('case_neuron_ids must have one cell entry per model group.');
end
case_neuron_ids = reshape(case_neuron_ids, 1, []);
for g = 1:numel(case_neuron_ids)
    ids = case_neuron_ids{g};
    if ~isnumeric(ids) || ~isreal(ids) || (~isempty(ids) && ~isvector(ids)) || ...
            any(~isfinite(ids(:))) || any(ids(:) < 1) || ...
            any(ids(:) ~= round(ids(:))) || numel(unique(ids)) ~= numel(ids)
        error('case_neuron_ids{%d} must contain unique positive integer IDs, or [].', g);
    end
    case_neuron_ids{g} = double(ids(:)');
end

logical_names = {'subtract_spontaneous', 'save_svg', 'save_png', ...
    'save_fig', 'close_after_save'};
logical_values = {subtract_spontaneous, save_svg, save_png, ...
    save_fig, close_after_save};
for k = 1:numel(logical_names)
    if ~islogical(logical_values{k}) || ~isscalar(logical_values{k})
        error('%s must be one logical scalar (true or false).', logical_names{k});
    end
end
error_method = upper(char(error_method));
if ~any(strcmp(error_method, {'SEM', 'SD'}))
    error('error_method must be ''SEM'' or ''SD''.');
end
if ~any(strcmp(lower(char(figure_visibility)), {'on', 'off'}))
    error('figure_visibility must be ''on'' or ''off''.');
end
validateattributes(runind, {'numeric'}, {'real', 'scalar', 'finite', 'integer', 'nonnegative'});
validateattributes(figure_width, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});
validateattributes(figure_height, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});
validateattributes(axis_font_size, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});
validateattributes(panel_title_font_size, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});
validateattributes(curve_line_width, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});
validateattributes(png_dpi, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});

active_groups = find(~cellfun(@isempty, case_neuron_ids));
if isempty(active_groups)
    fprintf('All case_neuron_ids entries are empty; no tuning figures requested.\n');
    return;
end

%% ----------------------- Locate the saved GPL results -----------------------
run_g = sprintf('%s_g%d', runName, runind);
cat_folder = fullfile(root_folder, run_g, ['catgt_' run_g]);
if subtract_spontaneous
    output_suffix = '_sponsub';
    response_axis_label = 'Baseline-subtracted firing rate (spikes/s)';
    state_label = 'baseline subtracted';
else
    output_suffix = '';
    response_axis_label = 'Firing rate (spikes/s)';
    state_label = 'raw firing rate';
end
input_mat_name = append_suffix_before_extension_local(gpl_mat_name, output_suffix);
probes_to_process = unique(group_probes(active_groups), 'stable');
num_figures_created = 0;

for probe_idx = 1:numel(probes_to_process)
    this_probe = probes_to_process(probe_idx);
    this_group_indices = active_groups(group_probes(active_groups) == this_probe);
    probe_folder = fullfile(cat_folder, sprintf('%s_imec%d', run_g, this_probe));
    if ~isfolder(probe_folder)
        warning('Probe folder not found; skipping probe %d: %s', this_probe, probe_folder);
        continue;
    end
    folders = dir(fullfile(probe_folder, 'kilosort*'));
    folders = folders([folders.isdir]);
    [~, folder_order] = sort(lower({folders.name}));
    folders = folders(folder_order);
    if isempty(folders)
        warning('No kilosort* folders found under %s.', probe_folder);
        continue;
    end

    for ks_idx = 1:numel(folders)
        ksDir = fullfile(folders(ks_idx).folder, folders(ks_idx).name);
        input_file = fullfile(ksDir, input_mat_name);
        fprintf('\nReading %s\n', input_file);
        try
            if ~isfile(input_file)
                error('GPL tuning MAT not found: %s. Save this analysis mode first.', input_file);
            end
            S = load(input_file, 'gpl_results');
            if ~isfield(S, 'gpl_results')
                error('gpl_results is missing from %s.', input_file);
            end
            gpl_results = S.gpl_results;
            validate_gpl_file_local(gpl_results, this_probe, ...
                group_probes, group_names, gpl_stim_tag, target_stim_tag, ...
                subtract_spontaneous);
        catch ME
            fprintf(2, 'Could not read GPL results: %s\n', ME.message);
            continue;
        end

        for model_group_index = this_group_indices
            try
                stored_group_indices = [gpl_results.group.model_group_index];
                match = find(stored_group_indices == model_group_index);
                if numel(match) ~= 1
                    error('Expected one stored entry for model group %d; found %d.', ...
                        model_group_index, numel(match));
                end
                result = gpl_results.group(match);
                if ~isequal(double(result.probe_id), this_probe) || ...
                        ~strcmp(char(result.group_name), group_names{model_group_index})
                    error('Stored probe/area does not match model group %d.', model_group_index);
                end
                local_ids = get_model_local_ids_local(result);
                requested_ids = case_neuron_ids{model_group_index};
                if any(requested_ids > numel(result.target_unit_ids))
                    error(['Group %d contains %d target neurons; requested IDs %s ', ...
                        'are outside that model-local range.'], ...
                        model_group_index, numel(result.target_unit_ids), ...
                        mat2str(requested_ids(requested_ids > numel(result.target_unit_ids))));
                end
                [found, selected_rows] = ismember(requested_ids, local_ids);
                if any(~found)
                    warning(['Group %d (%s): no GPL tuning for target local IDs %s. ', ...
                        'These target neurons are absent from the saved GPL rows; skipping them.'], ...
                        model_group_index, group_names{model_group_index}, ...
                        mat2str(requested_ids(~found)));
                end
                selected_rows = selected_rows(found);
                selected_ids = requested_ids(found);
                if isempty(selected_rows)
                    continue;
                end
                [grating_mean, grating_error] = get_tuning_display_local( ...
                    result.grating, error_method, subtract_spontaneous);
                [plaid_mean, plaid_error] = get_tuning_display_local( ...
                    result.plaid, error_method, subtract_spontaneous);
                group_file_tag = sprintf('Group%d_%s', model_group_index, ...
                    make_filename_safe_local(group_names{model_group_index}));

                for neuron_idx = 1:numel(selected_rows)
                    row = selected_rows(neuron_idx);
                    local_id = selected_ids(neuron_idx);
                    fig = figure('Color', 'w', 'Visible', figure_visibility, ...
                        'Position', [80 80 figure_width figure_height]);
                    figure_title = sprintf('Group %d: %s | local ID %d | %s (%s)', ...
                        model_group_index, group_names{model_group_index}, ...
                        local_id, state_label, error_method);
                    set(fig, 'Name', figure_title, 'NumberTitle', 'off');
                    ax_grating = axes('Parent', fig, ...
                        'Position', [0.10 0.18 0.35 0.60]);
                    draw_tuning_panel_local(ax_grating, ...
                        result.grating.directions, grating_mean(row, :), ...
                        grating_error(row, :), 'Grating direction (deg)', ...
                        response_axis_label, ...
                        sprintf('Grating | ID %d\nDI=%.3f  OSI=%.3f', ...
                        local_id, result.grating.DI(row), result.grating.OSI(row)), ...
                        axis_font_size, panel_title_font_size, curve_line_width);
                    ax_plaid = axes('Parent', fig, ...
                        'Position', [0.60 0.18 0.35 0.60]);
                    draw_tuning_panel_local(ax_plaid, ...
                        result.plaid.directions, plaid_mean(row, :), ...
                        plaid_error(row, :), 'Plaid direction (deg)', ...
                        response_axis_label, ...
                        sprintf('Plaid | ID %d\nPI=%.3f', local_id, result.plaid.PI(row)), ...
                        axis_font_size, panel_title_font_size, curve_line_width);
                    sgtitle(figure_title, 'Interpreter', 'none', ...
                        'FontWeight', 'normal', 'FontSize', panel_title_font_size);

                    file_base = sprintf('%s_neuron%d_tuning_%s%s', ...
                        group_file_tag, local_id, error_method, output_suffix);
                    output_base = fullfile(ksDir, file_base);
                    save_case_figure_local(fig, output_base, ...
                        save_svg, save_png, save_fig, png_dpi, close_after_save);
                    num_figures_created = num_figures_created + 1;
                    fprintf('  Group %d (%s), local ID %d: figure ready.\n', ...
                        model_group_index, group_names{model_group_index}, local_id);
                end
            catch ME
                fprintf(2, 'Error for Group %d (%s), %s:\n%s\n', ...
                    model_group_index, group_names{model_group_index}, ksDir, ...
                    getReport(ME, 'extended', 'hyperlinks', 'off'));
            end
        end
    end
end
fprintf('\nDone. Created %d single-neuron tuning figure(s).\n', num_figures_created);

%% ======================= Local functions =======================

function validate_gpl_file_local(result, probe_id, group_probes, group_names, ...
        gpl_stim_tag, target_stim_tag, sponsub)
% Match the selected file to its probe, stimuli, analysis mode and groups.

    required = {'probe_id', 'group', 'model_group_probes', ...
        'model_group_names', 'gpl_stim_tag', 'target_stim_tag', 'baseline_subtracted'};
    if ~isstruct(result) || ~isscalar(result)
        error('gpl_results must be one structure.');
    end
    for k = 1:numel(required)
        if ~isfield(result, required{k})
            error('GPL MAT is missing field %s.', required{k});
        end
    end
    if ~isequal(double(result.probe_id), probe_id)
        error('The GPL MAT probe ID differs from the requested probe.');
    end
    if ~isscalar(result.baseline_subtracted) || ...
            ~isequal(logical(result.baseline_subtracted), sponsub)
        error('The GPL MAT baseline mode differs from subtract_spontaneous.');
    end
    if ~strcmp(char(result.gpl_stim_tag), gpl_stim_tag) || ...
            ~strcmp(char(result.target_stim_tag), target_stim_tag)
        error('The GPL MAT stimulus tags differ from the requested tags.');
    end
    stored_names = normalize_text_list_local(result.model_group_names, ...
        'gpl_results.model_group_names');
    if ~isequal(double(result.model_group_probes(:)'), group_probes) || ...
            ~isequal(reshape(stored_names, 1, []), group_names)
        error('group_probes/group_names must match the saved model-group mapping.');
    end
    if isempty(result.group) || ~isstruct(result.group) || ...
            ~isfield(result.group, 'model_group_index')
        error('The GPL MAT does not contain grouped model-group results.');
    end
end

function local_ids = get_model_local_ids_local(result)
% Use the original target positions, not compact GPL row/panel numbers.

    required = {'target_unit_index', 'target_unit_ids', 'used_unit_ids', 'grating', 'plaid'};
    for k = 1:numel(required)
        if ~isfield(result, required{k})
            error('GPL group result is missing field %s.', required{k});
        end
    end
    local_ids = double(result.target_unit_index(:));
    target_ids = double(result.target_unit_ids(:));
    used_ids = double(result.used_unit_ids(:));
    nUnit = size(result.grating.mean_fr, 1);
    if numel(local_ids) ~= nUnit || numel(used_ids) ~= nUnit || ...
            size(result.plaid.mean_fr, 1) ~= nUnit || ...
            any(~isfinite(local_ids)) || any(local_ids ~= round(local_ids)) || ...
            any(local_ids < 1 | local_ids > numel(target_ids)) || ...
            numel(unique(local_ids)) ~= numel(local_ids)
        error('Invalid target-model local ID mapping in GPL results.');
    end
    if ~isequal(target_ids(local_ids), used_ids)
        error('Saved target-unit and used-unit IDs do not agree.');
    end
    if any([numel(result.grating.DI), numel(result.grating.OSI), ...
            numel(result.plaid.PI)] ~= nUnit)
        error('Saved index vectors do not match the tuning rows.');
    end
end

function [mean_fr, err_fr] = get_tuning_display_local(tuning, error_method, sponsub)
% Select the saved mean and matching trial-wise SD/SEM, always in spikes/s.

    if sponsub
        prefix = 'sponsub_';
    else
        prefix = '';
    end
    mean_field = [prefix 'mean_fr'];
    if strcmpi(error_method, 'SD')
        error_field = [prefix 'sd_fr'];
    else
        error_field = [prefix 'sem_fr'];
    end
    if ~isfield(tuning, mean_field) || ~isfield(tuning, error_field)
        error('The requested saved tuning fields %s/%s are missing.', mean_field, error_field);
    end
    mean_fr = double(tuning.(mean_field));
    err_fr = double(tuning.(error_field));
    if isempty(mean_fr) || ~isequal(size(mean_fr), size(err_fr)) || ...
            size(mean_fr, 1) ~= size(tuning.mean_fr, 1) || ...
            size(mean_fr, 2) ~= numel(tuning.directions)
        error('Saved tuning means/errors have invalid or inconsistent dimensions.');
    end
end

function draw_tuning_panel_local(ax, directions, mean_fr, err_fr, ...
        x_label, y_label, panel_title, axis_font_size, title_font_size, line_width)
% Match the compact tuning-grid style, adding readable axes and labels.

    directions = double(directions(:)');
    mean_fr = double(mean_fr(:)');
    err_fr = double(err_fr(:)');
    if numel(directions) ~= numel(mean_fr) || numel(mean_fr) ~= numel(err_fr)
        error('Direction, response and error-band lengths differ.');
    end
    hold(ax, 'on');
    upper_fr = mean_fr + err_fr;
    lower_fr = mean_fr - err_fr;
    valid = isfinite(directions) & isfinite(upper_fr) & isfinite(lower_fr);
    if sum(valid) >= 2
        x_band = directions(valid);
        upper_use = upper_fr(valid);
        lower_use = lower_fr(valid);
        fill(ax, [x_band fliplr(x_band)], [upper_use fliplr(lower_use)], ...
            [0.75 0.75 0.75], 'EdgeColor', 'none');
    end
    plot(ax, directions, mean_fr, 'Color', [0 0 0], 'LineWidth', line_width);
    xlim(ax, [0 360]);
    set(ax, 'XTick', 0:90:360, 'FontSize', axis_font_size);
    xlabel(ax, x_label, 'Interpreter', 'none');
    ylabel(ax, y_label, 'Interpreter', 'none');
    title(ax, panel_title, 'Interpreter', 'none', ...
        'FontWeight', 'normal', 'FontSize', title_font_size);
    box(ax, 'off');

    % Include negative means/error bands and retain an independent scale
    % for each panel, just as in the original tuning-grid figures.
    values = [mean_fr(:); lower_fr(:); upper_fr(:)];
    values = values(isfinite(values));
    if isempty(values)
        limits = [-0.5 0.5];
    else
        lower_limit = min(values);
        upper_limit = max(values);
        value_range = upper_limit - lower_limit;
        if value_range <= eps(max(abs([lower_limit upper_limit 1])))
            padding = 0.1 * max(abs([lower_limit upper_limit]));
            if padding == 0
                padding = 0.5;
            end
        else
            padding = 0.1 * value_range;
        end
        limits = [lower_limit - padding, upper_limit + padding];
    end
    ylim(ax, limits);
end

function save_case_figure_local(fig, output_base, save_svg, save_png, save_fig, dpi, close_after_save)
% print -dsvg works on MATLAB releases without exportgraphics SVG support.

    if save_fig
        savefig(fig, [output_base '.fig']);
    end
    if save_svg
        print(fig, [output_base '.svg'], '-dsvg', '-painters');
    end
    if save_png
        print(fig, [output_base '.png'], '-dpng', sprintf('-r%d', round(dpi)));
    end
    if close_after_save
        close(fig);
    end
end

function filename = append_suffix_before_extension_local(filename, suffix)
    [folder, stem, extension] = fileparts(char(filename));
    if isempty(stem)
        error('gpl_mat_name must name a MAT file.');
    end
    if isempty(extension)
        extension = '.mat';
    end
    if ~strcmpi(extension, '.mat') || ~isempty(folder)
        error('gpl_mat_name must be a MAT basename, without a directory.');
    end
    filename = [stem suffix extension];
end

function names = normalize_text_list_local(raw_names, parameter_name)
    if isstring(raw_names)
        names = cellstr(raw_names(:));
    elseif ischar(raw_names)
        if size(raw_names, 1) == 1
            names = {raw_names};
        else
            names = cellstr(raw_names);
        end
    elseif iscategorical(raw_names)
        names = cellstr(string(raw_names(:)));
    elseif iscell(raw_names)
        names = raw_names(:);
    else
        error('%s must be text or a cell array of text.', parameter_name);
    end
    for k = 1:numel(names)
        value = names{k};
        if isstring(value) && isscalar(value)
            value = char(value);
        end
        if ~ischar(value) || isempty(strtrim(value))
            error('%s{%d} must be nonempty text.', parameter_name, k);
        end
        names{k} = strtrim(value);
    end
end

function safe_name = make_filename_safe_local(value)
    safe_name = regexprep(strtrim(char(value)), '[^A-Za-z0-9_-]+', '_');
    safe_name = regexprep(safe_name, '_+', '_');
    safe_name = regexprep(safe_name, '^_+|_+$', '');
    if isempty(safe_name)
        error('Area name must contain at least one portable filename character.');
    end
end
