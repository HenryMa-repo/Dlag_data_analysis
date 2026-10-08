%% check_high_R2_cell_reconstruction.m
% Find high-R2 neurons in one recording session and visualize their
% single-trial original responses and reconstructions in one large figure.
%
% IMPORTANT: NEURON-ID DEFINITION
% -------------------------------------------------------------------------
% Every neuron ID displayed or written by this program is a MODEL-LOCAL
% neuron ID: the 1-based row index within one DLAG model group/area after
% unit selection. Thus, valid IDs for group g are 1:yDims(g). These IDs are
% the row positions used by:
%   stimtype_recon_R2.<category>.<reconstruction>.neuron_by_group{g}
% and are NOT Kilosort/Phy cluster IDs. The corresponding global seqEst row
% is obtained internally by adding the sizes of all preceding model groups.
%
% This script is intended to be run separately inside each session, in the
% same way as reconstruction_visualization_case_example.m and
% plot_GPL_class_reconstruction_R2_by_area.m.
%
% Required prior outputs:
%   1) data_reconstruction.m must have added these fields to seqEst:
%        yRecon_use_all
%        yRecon_use_across
%        yRecon_use_within
%        yRecon_use_feedforward
%        yRecon_use_feedback
%   2) calculate_reconstruction_R2_dfferent_ways.m must have produced the
%      by_three_features (stszct) grouped-R2 MAT file.
%
% Selection rule:
%   A neuron is selected when its finite use_all R2 is strictly greater
%   than high_r2_threshold in at least one of the eight stimulus categories.
%   A neuron that passes in multiple categories is still plotted only once.
%
% One figure is produced per selected neuron:
%   rows = G-S-L, G-S-H, G-L-L, G-L-H,
%          P-S-L, P-S-H, P-L-L, P-L-H
%   columns = Original, All latents, Across-area, Within-area,
%             Feedforward, Feedback
%
% Direction is ignored exactly as in the grouped-R2 calculation: the two
% direction conditions belonging to one row are pooled before trials are
% selected. All six columns in a row use exactly the same selected trials.
% No trial average is computed or drawn.
%
% The R2 printed under each reconstruction label is read directly from the
% saved grouped-R2 MAT. It was calculated from all available trials in both
% directions for that category; it is NOT recalculated from the subset of
% individual trials displayed in the figure.

clc;
clear;

%% ========================== USER SETTINGS ==============================

data_content = 'demean_count_within_t_and_condition';
% Common options:
%   raw_count
%   raw_fr
%   z_within_trial
%   z_within_condition
%   z_across_conditions
%   demean_count_within_trial
%   demean_fr_within_trial
%   demean_pooledsd_within_condition
%   demean_count_within_t_and_condition

% This visualization requires the eight direction-pooled stimulus groups.
r2_split_mode = 'by_three_features';

% [] means one pooled all-condition model.
% A nonempty vector means condition-specific models, matching the R2 file.
data_condition = [];

% DLAG result-folder index.
runIdx = 1; % 1 means data, 2 means shuffle all units independently

reconstruction_suffix = 'all_across_within_ff_fb';

% Leave empty to construct the R2 path in the same way as
% plot_GPL_class_reconstruction_R2_by_area.m.
r2_file_override = '';

% Metadata used to map seqEst.trialId to the original conditions.
dat_file = fullfile('.', 'model_data_allruns');
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';

% Display/file labels only. The order must match the DLAG model-group order.
group_names = {'V1', 'MT'};

% A neuron passes when use_all R2 is STRICTLY greater than this value in
% at least one of the eight direction-pooled stimulus categories.
high_r2_threshold = 0.99;

% Use Inf to draw every available trial in each direction-pooled category.
% Otherwise, the requested number is randomly selected once per category
% and shared by all fields, neurons, and areas.
n_individual_trials_to_plot = 50;
individual_trial_random_seed = 1;
individual_trial_line_width = 0.5;

% raw_count is converted to spikes/s using this bin width. The setting is
% checked against saved bin_size/bin_centers metadata.
bin_width_ms = 20;

% Every condition row has one shared y scale across all six columns,
% matching the old one-condition-at-a-time individual-trial figures.
y_padding_fraction = 0.06;

% Figure style.
figure_visible = 'on';
figure_width = 1900;
figure_height = 2100;
font_name = 'Arial';
axis_font_size = 7;
panel_title_font_size = 8;
main_title_font_size = 12;

% Save options. Outputs are placed below the R2-result folder.
output_subfolder = 'high_R2_cell_reconstruction';
save_fig = false;
save_svg = false;
save_png = true;
close_after_save = true;
png_dpi = 300;

%% ======================= FIXED FIELD DEFINITIONS =======================

analysis_fields = { ...
    'y', ...
    'yRecon_use_all', ...
    'yRecon_use_across', ...
    'yRecon_use_within', ...
    'yRecon_use_feedforward', ...
    'yRecon_use_feedback'};

reconstruction_labels = { ...
    'Original', ...
    'All latents', ...
    'Across-area', ...
    'Within-area', ...
    'Feedforward', ...
    'Feedback'};

r2_field_names = { ...
    'use_all', ...
    'use_across', ...
    'use_within', ...
    'use_feedforward', ...
    'use_feedback'};

%% ============================ SETUP ====================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

session_dir = pwd;
[~, session_name] = fileparts(session_dir);

group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);

[r2_split_mode, split_file_tag, category_fields, category_labels] = ...
    getR2SplitConfigLocal(r2_split_mode);

if ~strcmp(r2_split_mode, 'by_three_features')
    error(['check_high_R2_cell_reconstruction requires ', ...
        'r2_split_mode = ''by_three_features''.']);
end

validateUserSettingsLocal( ...
    data_content, data_condition, runIdx, reconstruction_suffix, ...
    r2_file_override, dat_file, stim_tag, group_names, ...
    high_r2_threshold, n_individual_trials_to_plot, ...
    individual_trial_random_seed, individual_trial_line_width, ...
    bin_width_ms, y_padding_fraction, figure_visible, ...
    figure_width, figure_height, font_name, axis_font_size, ...
    panel_title_font_size, main_title_font_size, output_subfolder, ...
    save_fig, save_svg, save_png, close_after_save, png_dpi);

condition_list = double(reshape(data_condition, 1, []));
use_condition_mode = ~isempty(condition_list);

if use_condition_mode
    model_mode = 'condition_specific_models';
    mode_file_tag = 'condspec';
    default_r2_dir = script_dir;
else
    model_mode = 'all_condition_model';
    mode_file_tag = 'allcond';
    default_r2_dir = sprintf( ...
        './FA_Dlag_%s/mat_results/run%03d', ...
        data_content, runIdx);
end

r2_file_name = sprintf('%s_%s_%s_R2_%s.mat', ...
    data_content, model_mode, split_file_tag, reconstruction_suffix);

if isempty(r2_file_override)
    r2_file = fullfile(default_r2_dir, r2_file_name);
else
    r2_file = char(r2_file_override);
end

if ~isfile(r2_file)
    error(['Grouped R2 file not found: %s\nRun ', ...
        'calculate_reconstruction_R2_dfferent_ways.m first.'], r2_file);
end

r2_result_dir = fileparts(r2_file);
if isempty(r2_result_dir)
    r2_result_dir = pwd;
end

output_dir = fullfile(r2_result_dir, output_subfolder);

if save_fig || save_svg || save_png
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
end

fprintf('\n============================================================\n');
fprintf('Check high-R2 neuron reconstruction\n');
fprintf('Session              : %s\n', session_name);
fprintf('Data content         : %s\n', data_content);
fprintf('Model mode           : %s\n', model_mode);
fprintf('R2 split mode        : %s\n', r2_split_mode);
fprintf('R2 threshold         : use_all R2 > %.12g\n', ...
    high_r2_threshold);
fprintf('Neuron ID definition : model-local index within each area\n');
fprintf('Trials per row       : %s\n', ...
    numberOrInfTextLocal(n_individual_trials_to_plot));
fprintf('R2 file              : %s\n', r2_file);
fprintf('Output folder        : %s\n', output_dir);
fprintf('============================================================\n');

%% ======================= LOAD SESSION METADATA =========================

Smeta = loadMatFileFlexibleLocal(dat_file, 'model_data_allruns');

if ~isfield(Smeta, 'model_data_allruns')
    error('%s does not contain model_data_allruns.', dat_file);
end

model_data_allruns = Smeta.model_data_allruns;
all_run_tags = getAllRunTagsLocal(model_data_allruns);
metadata_run_idx = find(strcmp(all_run_tags, stim_tag));

if isempty(metadata_run_idx)
    error('Requested stim_tag was not found in model_data_allruns: %s', ...
        stim_tag);
end

if numel(metadata_run_idx) > 1
    error('Duplicate stim_tag entries were found: %s', stim_tag);
end

run_metadata = model_data_allruns{metadata_run_idx};
requireFieldLocal(run_metadata, 'conditions_full', ...
    sprintf('model_data_allruns{%d}', metadata_run_idx));
requireFieldLocal(run_metadata, 'condition_index_per_trial_full', ...
    sprintf('model_data_allruns{%d}', metadata_run_idx));

conditions_full = run_metadata.conditions_full;
condition_index_per_trial_full = double( ...
    run_metadata.condition_index_per_trial_full(:));

validateConditionMetadataLocal( ...
    conditions_full, condition_index_per_trial_full);

[response_scale_factor, response_axis_label] = ...
    getResponseDisplayInfoLocal( ...
    data_content, bin_width_ms, run_metadata);

%% ============================ LOAD R2 ==================================

Sr2 = load(r2_file, 'stimtype_recon_R2');

if ~isfield(Sr2, 'stimtype_recon_R2')
    error('%s does not contain stimtype_recon_R2.', r2_file);
end

stimtype_recon_R2 = Sr2.stimtype_recon_R2;

validateStimtypeR2Local( ...
    stimtype_recon_R2, data_content, model_mode, r2_split_mode, ...
    split_file_tag, condition_list, runIdx, reconstruction_suffix, ...
    category_fields, category_labels, r2_field_names);

yDims = double(stimtype_recon_R2.yDims(:)');
num_groups = numel(yDims);

if numel(group_names) ~= num_groups
    error(['group_names contains %d entries, but the R2 file contains ', ...
        '%d model groups.'], numel(group_names), num_groups);
end

category_definitions = buildCategoryDefinitionsLocal( ...
    stimtype_recon_R2, category_fields, category_labels, ...
    numel(conditions_full));

%% ================= LOAD AND POOL RECONSTRUCTION TRIALS =================

[category_blocks, loaded_yDims] = loadCategoryBlocksLocal( ...
    data_content, runIdx, use_condition_mode, ...
    category_definitions, condition_index_per_trial_full, ...
    analysis_fields);

if ~isequal(reshape(loaded_yDims, 1, []), yDims)
    error(['The reconstruction model yDims %s do not match the R2-file ', ...
        'yDims %s.'], mat2str(loaded_yDims), mat2str(yDims));
end

selected_trial_indices = selectIndividualTrialsLocal( ...
    category_blocks, n_individual_trials_to_plot, ...
    individual_trial_random_seed);

%% =================== FIND AND PLOT HIGH-R2 NEURONS ====================

num_figures = 0;

for g = 1:num_groups
    use_all_by_category = nan(yDims(g), numel(category_fields));

    for c = 1:numel(category_fields)
        use_all_by_category(:, c) = getGroupR2VectorLocal( ...
            stimtype_recon_R2.(category_fields{c}), ...
            'use_all', g);
    end

    high_mask = any( ...
        isfinite(use_all_by_category) & ...
        use_all_by_category > high_r2_threshold, 2);
    local_neuron_ids = find(high_mask);

    fprintf('\n%s: %d/%d neurons have use_all R2 > %.12g.\n', ...
        group_display_names{g}, numel(local_neuron_ids), ...
        yDims(g), high_r2_threshold);

    group_rows = getGroupRowsLocal(yDims, g);

    for n = 1:numel(local_neuron_ids)
        local_neuron_id = local_neuron_ids(n);
        global_neuron_row = group_rows(local_neuron_id);

        r2_matrix = collectNeuronR2MatrixLocal( ...
            stimtype_recon_R2, category_fields, ...
            r2_field_names, g, local_neuron_id);

        figure_name = sprintf( ...
            '%s | %s | model-local neuron %d', ...
            session_name, group_display_names{g}, local_neuron_id);

        fig = plotHighR2NeuronLocal( ...
            category_blocks, selected_trial_indices, ...
            analysis_fields, reconstruction_labels, r2_matrix, ...
            global_neuron_row, local_neuron_id, ...
            group_display_names{g}, session_name, ...
            high_r2_threshold, response_scale_factor, ...
            response_axis_label, run_metadata, bin_width_ms, ...
            figure_name, figure_visible, figure_width, figure_height, ...
            font_name, axis_font_size, panel_title_font_size, ...
            main_title_font_size, individual_trial_line_width, ...
            y_padding_fraction);

        threshold_tag = numericFileTagLocal(high_r2_threshold);
        file_base = sprintf( ...
            'highR2_%s_%s_localN%d_thr%s', ...
            mode_file_tag, group_file_tags{g}, ...
            local_neuron_id, threshold_tag);
        file_base = sanitizeFileNameLocal(file_base);

        if save_fig
            fig_file = fullfile(output_dir, [file_base, '.fig']);
            saveFigLocal(fig, fig_file);
            fprintf('Saved FIG: %s\n', fig_file);
        end

        if save_svg
            svg_file = fullfile(output_dir, [file_base, '.svg']);
            saveSvgLocal(fig, svg_file);
            fprintf('Saved SVG: %s\n', svg_file);
        end

        if save_png
            png_file = fullfile(output_dir, [file_base, '.png']);
            savePngLocal(fig, png_file, png_dpi);
            fprintf('Saved PNG: %s\n', png_file);
        end

        if close_after_save && (save_fig || save_svg || save_png)
            close(fig);
        end

        num_figures = num_figures + 1;
    end
end

fprintf('\nDone. Generated %d high-R2 neuron figure(s).\n', num_figures);

%% ======================================================================
% Local functions
% =======================================================================

function validateUserSettingsLocal( ...
    data_content, data_condition, runIdx, reconstruction_suffix, ...
    r2_file_override, dat_file, stim_tag, group_names, ...
    high_r2_threshold, n_individual_trials_to_plot, ...
    individual_trial_random_seed, individual_trial_line_width, ...
    bin_width_ms, y_padding_fraction, figure_visible, ...
    figure_width, figure_height, font_name, axis_font_size, ...
    panel_title_font_size, main_title_font_size, output_subfolder, ...
    save_fig, save_svg, save_png, close_after_save, png_dpi)

    requireNonemptyTextLocal(data_content, 'data_content');
    requireNonemptyTextLocal(reconstruction_suffix, ...
        'reconstruction_suffix');
    requireNonemptyTextLocal(dat_file, 'dat_file');
    requireNonemptyTextLocal(stim_tag, 'stim_tag');
    requireNonemptyTextLocal(font_name, 'font_name');
    requireNonemptyTextLocal(output_subfolder, 'output_subfolder');

    if ~(isempty(r2_file_override) || ...
            ischar(r2_file_override) || ...
            (isstring(r2_file_override) && isscalar(r2_file_override)))
        error('r2_file_override must be empty or one text scalar.');
    end

    validateattributes(runIdx, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, ...
        mfilename, 'runIdx');

    if ~isempty(data_condition)
        validateattributes(data_condition, {'numeric'}, ...
            {'vector', 'integer', 'positive', 'finite'}, ...
            mfilename, 'data_condition');

        if numel(unique(data_condition)) ~= numel(data_condition)
            error('data_condition contains duplicate condition IDs.');
        end
    end

    if ~iscell(group_names) || isempty(group_names)
        error('group_names must be a nonempty cell array of text.');
    end

    validateattributes(high_r2_threshold, {'numeric'}, ...
        {'scalar', 'real', 'finite'}, ...
        mfilename, 'high_r2_threshold');
    validatePositiveIntegerOrInfLocal( ...
        n_individual_trials_to_plot, ...
        'n_individual_trials_to_plot');
    validateattributes(individual_trial_random_seed, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'integer', 'nonnegative', ...
        '<=', 2^32 - 1}, ...
        mfilename, 'individual_trial_random_seed');
    validateattributes(individual_trial_line_width, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'individual_trial_line_width');
    validateattributes(bin_width_ms, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'bin_width_ms');
    validateattributes(y_padding_fraction, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, ...
        mfilename, 'y_padding_fraction');

    assertTextOptionLocal(figure_visible, {'on', 'off'}, ...
        'figure_visible');

    numeric_positive = { ...
        figure_width, figure_height, axis_font_size, ...
        panel_title_font_size, main_title_font_size, png_dpi};
    numeric_names = { ...
        'figure_width', 'figure_height', 'axis_font_size', ...
        'panel_title_font_size', 'main_title_font_size', 'png_dpi'};

    for i = 1:numel(numeric_positive)
        validateattributes(numeric_positive{i}, {'numeric'}, ...
            {'scalar', 'real', 'finite', 'positive'}, ...
            mfilename, numeric_names{i});
    end

    validateLogicalScalarLocal(save_fig, 'save_fig');
    validateLogicalScalarLocal(save_svg, 'save_svg');
    validateLogicalScalarLocal(save_png, 'save_png');
    validateLogicalScalarLocal(close_after_save, 'close_after_save');
end

function validatePositiveIntegerOrInfLocal(value, variable_name)
    valid = isnumeric(value) && isscalar(value) && isreal(value) && ...
        ((isfinite(value) && value >= 1 && value == round(value)) || ...
        (isinf(value) && value > 0));

    if ~valid
        error('%s must be a positive integer or Inf.', variable_name);
    end
end

function validateLogicalScalarLocal(value, variable_name)
    valid = (islogical(value) || isnumeric(value)) && ...
        isscalar(value) && isfinite(double(value)) && ...
        ismember(double(value), [0, 1]);

    if ~valid
        error('%s must be one logical scalar.', variable_name);
    end
end

function requireNonemptyTextLocal(value, variable_name)
    valid = ischar(value) || (isstring(value) && isscalar(value));

    if ~valid || isempty(strtrim(char(value)))
        error('%s must be nonempty text.', variable_name);
    end
end

function assertTextOptionLocal(value, valid_options, variable_name)
    requireNonemptyTextLocal(value, variable_name);
    value = lower(strtrim(char(value)));

    if ~any(strcmp(value, valid_options))
        error('%s must be one of: %s.', ...
            variable_name, strjoin(valid_options, ', '));
    end
end

function [mode, file_tag, category_fields, category_labels] = ...
        getR2SplitConfigLocal(mode)

    requireNonemptyTextLocal(mode, 'r2_split_mode');
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
            error('Unknown r2_split_mode: %s.', mode);
    end
end

function validateConditionMetadataLocal( ...
    conditions_full, condition_index_per_trial_full)

    if isempty(conditions_full)
        error('conditions_full is empty.');
    end

    if isempty(condition_index_per_trial_full) || ...
            any(~isfinite(condition_index_per_trial_full)) || ...
            any(condition_index_per_trial_full < 1) || ...
            any(condition_index_per_trial_full ~= ...
            round(condition_index_per_trial_full)) || ...
            any(condition_index_per_trial_full > numel(conditions_full))
        error('condition_index_per_trial_full contains invalid IDs.');
    end
end

function validateStimtypeR2Local( ...
    R, expected_data_content, expected_model_mode, ...
    expected_split_mode, expected_split_file_tag, ...
    expected_condition_list, expected_run_idx, ...
    expected_reconstruction_suffix, category_fields, category_labels, ...
    r2_field_names)

    required_top = { ...
        'data_content', ...
        'model_mode', ...
        'yDims', ...
        'unit_ids_by_group'};

    for i = 1:numel(required_top)
        if ~isfield(R, required_top{i})
            error('stimtype_recon_R2 is missing field %s.', ...
                required_top{i});
        end
    end

    if ~strcmp(char(R.data_content), expected_data_content)
        error('R2 data_content is %s; expected %s.', ...
            char(R.data_content), expected_data_content);
    end

    if ~strcmp(char(R.model_mode), expected_model_mode)
        error('R2 model_mode is %s; expected %s.', ...
            char(R.model_mode), expected_model_mode);
    end

    if ~isfield(R, 'r2_split_mode') || ...
            ~strcmp(lower(strtrim(char(R.r2_split_mode))), ...
            expected_split_mode)
        error(['The R2 file does not match r2_split_mode = %s. ', ...
            'Recalculate it with the updated calculation program.'], ...
            expected_split_mode);
    end

    if isfield(R, 'split_file_tag') && ...
            ~strcmp(char(R.split_file_tag), expected_split_file_tag)
        error('R2 split_file_tag is %s; expected %s.', ...
            char(R.split_file_tag), expected_split_file_tag);
    end

    if isfield(R, 'data_condition')
        stored_condition_list = double(reshape(R.data_condition, 1, []));
        if ~isequal(stored_condition_list, expected_condition_list)
            error('R2 data_condition does not match the current setting.');
        end
    end

    if isfield(R, 'runIdx') && ...
            double(R.runIdx) ~= double(expected_run_idx)
        error('R2 runIdx is %g; expected %g.', ...
            double(R.runIdx), double(expected_run_idx));
    end

    if isfield(R, 'reconstruction_suffix') && ...
            ~strcmp(char(R.reconstruction_suffix), ...
            expected_reconstruction_suffix)
        error('R2 reconstruction_suffix is %s; expected %s.', ...
            char(R.reconstruction_suffix), ...
            expected_reconstruction_suffix);
    end

    if isfield(R, 'category_fields')
        stored_fields = normalizeTextCellLocal( ...
            R.category_fields, 'R.category_fields');
        if ~isequal(stored_fields, reshape(category_fields, 1, []))
            error('R2 category_fields have an unexpected order.');
        end
    end

    if isfield(R, 'category_labels')
        stored_labels = normalizeTextCellLocal( ...
            R.category_labels, 'R.category_labels');
        if ~isequal(stored_labels, reshape(category_labels, 1, []))
            error('R2 category_labels have an unexpected order.');
        end
    end

    yDims = double(R.yDims(:)');
    if isempty(yDims) || any(~isfinite(yDims)) || ...
            any(yDims < 1) || any(yDims ~= round(yDims))
        error('R2 yDims must contain positive finite integers.');
    end

    if ~iscell(R.unit_ids_by_group) || ...
            numel(R.unit_ids_by_group) ~= numel(yDims)
        error('R2 unit_ids_by_group has the wrong group count.');
    end

    for g = 1:numel(yDims)
        if numel(R.unit_ids_by_group{g}) ~= yDims(g)
            error(['R2 unit_ids_by_group{%d} contains %d entries, ', ...
                'but yDims(%d) is %d.'], ...
                g, numel(R.unit_ids_by_group{g}), g, yDims(g));
        end
    end

    for c = 1:numel(category_fields)
        category_field = category_fields{c};

        if ~isfield(R, category_field) || ...
                ~isstruct(R.(category_field))
            error('R2 is missing category %s.', category_field);
        end

        for f = 1:numel(r2_field_names)
            r2_field = r2_field_names{f};

            if ~isfield(R.(category_field), r2_field) || ...
                    ~isstruct(R.(category_field).(r2_field)) || ...
                    ~isfield(R.(category_field).(r2_field), ...
                    'neuron_by_group')
                error('R2 is missing %s.%s.neuron_by_group.', ...
                    category_field, r2_field);
            end

            by_group = ...
                R.(category_field).(r2_field).neuron_by_group;

            if ~iscell(by_group) || numel(by_group) ~= numel(yDims)
                error('%s.%s.neuron_by_group has the wrong group count.', ...
                    category_field, r2_field);
            end

            for g = 1:numel(yDims)
                if ~isnumeric(by_group{g}) || ...
                        numel(by_group{g}) ~= yDims(g)
                    error(['%s.%s group %d contains an invalid ', ...
                        'neuron R2 vector.'], ...
                        category_field, r2_field, g);
                end
            end
        end
    end
end

function values = normalizeTextCellLocal(values, variable_name)
    if isstring(values)
        values = cellstr(values);
    elseif ischar(values)
        values = {values};
    elseif iscell(values)
        for i = 1:numel(values)
            requireNonemptyTextLocal(values{i}, ...
                sprintf('%s{%d}', variable_name, i));
            values{i} = char(values{i});
        end
    else
        error('%s must be text or a cell array of text.', variable_name);
    end

    values = reshape(values, 1, []);
end

function definitions = buildCategoryDefinitionsLocal( ...
    R, category_fields, category_labels, num_conditions)

    template = struct( ...
        'field_name', '', ...
        'label', '', ...
        'condition_ids', []);
    definitions = repmat(template, 1, numel(category_fields));
    all_condition_ids = [];

    for c = 1:numel(category_fields)
        category_field = category_fields{c};
        category_result = R.(category_field);

        if ~isfield(category_result, 'info') || ...
                ~isstruct(category_result.info) || ...
                ~isfield(category_result.info, 'condition_ids')
            error(['R2 category %s is missing info.condition_ids. ', ...
                'Recalculate the R2 file with the current program.'], ...
                category_field);
        end

        condition_ids = double(reshape( ...
            category_result.info.condition_ids, 1, []));

        if numel(condition_ids) ~= 2 || ...
                any(~isfinite(condition_ids)) || ...
                any(condition_ids < 1) || ...
                any(condition_ids ~= round(condition_ids)) || ...
                any(condition_ids > num_conditions) || ...
                numel(unique(condition_ids)) ~= 2
            error(['R2 category %s must contain exactly two distinct ', ...
                'valid direction-condition IDs. Found: %s.'], ...
                category_field, mat2str(condition_ids));
        end

        definitions(c).field_name = category_field;
        definitions(c).label = category_labels{c};
        definitions(c).condition_ids = condition_ids;
        all_condition_ids = [all_condition_ids, condition_ids]; %#ok<AGROW>
    end

    if numel(unique(all_condition_ids)) ~= numel(all_condition_ids)
        error(['The eight R2 categories do not contain disjoint ', ...
            'direction-condition IDs.']);
    end
end

function [category_blocks, yDims_ref] = loadCategoryBlocksLocal( ...
    data_content, runIdx, use_condition_mode, definitions, ...
    condition_index_per_trial_full, analysis_fields)

    category_blocks = repmat( ...
        makeEmptyCategoryBlockLocal(), 1, numel(definitions));
    yDims_ref = [];

    if ~use_condition_mode
        model_folder = sprintf( ...
            './FA_Dlag_%s/mat_results/run%03d', ...
            data_content, runIdx);
        model_data = loadBestModelDataLocal(model_folder);
        yDims_ref = model_data.yDims;
        seqEst = reshape(model_data.seqEst, 1, []);
        trial_ids = getTrialIdsLocal( ...
            seqEst, numel(condition_index_per_trial_full));
        condition_ids = ...
            condition_index_per_trial_full(trial_ids);

        for c = 1:numel(definitions)
            keep = ismember( ...
                condition_ids, definitions(c).condition_ids);
            seq_this = sortSeqByTrialIdLocal(seqEst(keep));

            if isempty(seq_this)
                error('No reconstruction trials were found for %s.', ...
                    definitions(c).label);
            end

            category_blocks(c).field_name = ...
                definitions(c).field_name;
            category_blocks(c).label = definitions(c).label;
            category_blocks(c).condition_ids = ...
                definitions(c).condition_ids;
            category_blocks(c).seqEst = seq_this;
            category_blocks(c).source_folders = {model_folder};
        end
    else
        for c = 1:numel(definitions)
            seq_combined = [];
            source_folders = cell(1, ...
                numel(definitions(c).condition_ids));

            for j = 1:numel(definitions(c).condition_ids)
                condition_id = definitions(c).condition_ids(j);
                model_folder = sprintf( ...
                    './FA_Dlag_%s_condition%d/mat_results/run%03d', ...
                    data_content, condition_id, runIdx);
                model_data = loadBestModelDataLocal(model_folder);

                if isempty(yDims_ref)
                    yDims_ref = model_data.yDims;
                elseif ~isequal(reshape(model_data.yDims, 1, []), ...
                        reshape(yDims_ref, 1, []))
                    error(['yDims differ across condition-specific ', ...
                        'models.']);
                end

                seq_this = sortSeqByTrialIdLocal( ...
                    reshape(model_data.seqEst, 1, []));
                trial_ids = getTrialIdsLocal( ...
                    seq_this, numel(condition_index_per_trial_full));
                mapped_conditions = ...
                    condition_index_per_trial_full(trial_ids);

                if any(mapped_conditions ~= condition_id)
                    error(['Condition-specific model %s contains trials ', ...
                        'that do not map to condition %d.'], ...
                        model_data.best_file, condition_id);
                end

                seq_combined = [seq_combined, seq_this]; %#ok<AGROW>
                source_folders{j} = model_folder;
            end

            seq_combined = sortSeqByTrialIdLocal(seq_combined);

            if isempty(seq_combined)
                error('No reconstruction trials were found for %s.', ...
                    definitions(c).label);
            end

            category_blocks(c).field_name = ...
                definitions(c).field_name;
            category_blocks(c).label = definitions(c).label;
            category_blocks(c).condition_ids = ...
                definitions(c).condition_ids;
            category_blocks(c).seqEst = seq_combined;
            category_blocks(c).source_folders = source_folders;
        end
    end

    if isempty(yDims_ref)
        error('No reconstruction model was loaded.');
    end

    total_neurons = sum(yDims_ref);

    for c = 1:numel(category_blocks)
        validateSeqFieldsLocal( ...
            category_blocks(c).seqEst, analysis_fields, ...
            total_neurons, category_blocks(c).label);

        fprintf(['%s: pooled condition IDs %s, %d trials ', ...
            '(directions ignored).\n'], ...
            category_blocks(c).label, ...
            mat2str(category_blocks(c).condition_ids), ...
            numel(category_blocks(c).seqEst));
    end
end

function block = makeEmptyCategoryBlockLocal()
    block = struct();
    block.field_name = '';
    block.label = '';
    block.condition_ids = [];
    block.seqEst = [];
    block.source_folders = {};
end

function model_data = loadBestModelDataLocal(model_folder)
    best_file = findOneFileLocal(model_folder, 'bestmodel*', true);
    fprintf('Loading best model: %s\n', best_file);

    Sbest = load(best_file);
    required_variables = {'bestModel', 'res', 'seqEst'};

    for i = 1:numel(required_variables)
        if ~isfield(Sbest, required_variables{i})
            error('%s is missing variable %s.', ...
                best_file, required_variables{i});
        end
    end

    if isempty(Sbest.seqEst)
        error('seqEst is empty in %s.', best_file);
    end

    yDims = getYDimsFromModelLocal( ...
        Sbest.bestModel, Sbest.res, Sbest.seqEst, best_file);

    model_data = struct();
    model_data.best_file = best_file;
    model_data.seqEst = Sbest.seqEst;
    model_data.yDims = yDims;
end

function yDims = getYDimsFromModelLocal( ...
    best_model, res, seqEst, source_name)

    yDims = [];

    if isfield(res, 'estParams') && ...
            isfield(res.estParams, 'yDims') && ...
            ~isempty(res.estParams.yDims)
        yDims = res.estParams.yDims;
    elseif isfield(best_model, 'yDims') && ...
            ~isempty(best_model.yDims)
        yDims = best_model.yDims;
    end

    if isempty(yDims)
        error('Could not determine yDims from %s.', source_name);
    end

    yDims = reshape(double(yDims), 1, []);

    if isempty(yDims) || any(~isfinite(yDims)) || ...
            any(yDims < 1) || any(yDims ~= round(yDims))
        error('Invalid yDims in %s.', source_name);
    end

    if ~isfield(seqEst, 'y')
        error('seqEst.y is missing in %s.', source_name);
    end

    if sum(yDims) ~= size(seqEst(1).y, 1)
        error(['sum(yDims) = %d, but size(seqEst(1).y,1) = %d ', ...
            'in %s.'], sum(yDims), size(seqEst(1).y, 1), source_name);
    end
end

function seq_out = sortSeqByTrialIdLocal(seq_in)
    if isempty(seq_in)
        seq_out = seq_in;
        return;
    end

    seq_in = reshape(seq_in, 1, []);
    trial_ids = getTrialIdsLocal(seq_in, Inf);
    [~, order] = sort(trial_ids);
    seq_out = seq_in(order);
end

function trial_ids = getTrialIdsLocal(seqEst, max_trial_id)
    if isempty(seqEst) || ~isfield(seqEst, 'trialId')
        error('seqEst must contain trialId for every trial.');
    end

    trial_ids = double(arrayfun(@(s) s.trialId, seqEst));
    trial_ids = reshape(trial_ids, 1, []);

    invalid = ~isfinite(trial_ids) | trial_ids < 1 | ...
        trial_ids ~= round(trial_ids);

    if isfinite(max_trial_id)
        invalid = invalid | trial_ids > max_trial_id;
    end

    if any(invalid)
        error('seqEst contains invalid trialId values.');
    end

    if numel(unique(trial_ids)) ~= numel(trial_ids)
        error('seqEst contains duplicate trialId values.');
    end
end

function validateSeqFieldsLocal( ...
    seqEst, analysis_fields, total_neurons, category_label)

    if isempty(seqEst)
        error('%s contains no reconstruction trials.', category_label);
    end

    reference_time_length = [];

    for f = 1:numel(analysis_fields)
        field_name = analysis_fields{f};

        if ~isfield(seqEst, field_name)
            error('%s seqEst is missing field %s.', ...
                category_label, field_name);
        end

        for tr = 1:numel(seqEst)
            Y = seqEst(tr).(field_name);

            if ~isnumeric(Y) || ndims(Y) ~= 2 || ...
                    size(Y, 1) ~= total_neurons
                error(['%s seqEst(%d).%s has invalid dimensions. ', ...
                    'Expected %d neuron rows.'], ...
                    category_label, tr, field_name, total_neurons);
            end

            if isempty(reference_time_length)
                reference_time_length = size(Y, 2);
            elseif size(Y, 2) ~= reference_time_length
                error(['Time length differs across trials or fields in ', ...
                    '%s.'], category_label);
            end
        end
    end
end

function selected_trial_indices = selectIndividualTrialsLocal( ...
    category_blocks, n_trials_to_plot, random_seed)

    selected_trial_indices = cell(1, numel(category_blocks));
    random_stream = RandStream( ...
        'mt19937ar', 'Seed', double(random_seed));

    fprintf(['Selecting individual trials once per direction-pooled ', ...
        'category (requested = %s, seed = %d).\n'], ...
        numberOrInfTextLocal(n_trials_to_plot), random_seed);

    for c = 1:numel(category_blocks)
        n_available = numel(category_blocks(c).seqEst);

        if isinf(n_trials_to_plot) || ...
                n_trials_to_plot >= n_available
            selection = 1:n_available;
        else
            selection = sort(randperm( ...
                random_stream, n_available, n_trials_to_plot));
        end

        selected_trial_indices{c} = selection;
        all_trial_ids = arrayfun( ...
            @(s) s.trialId, category_blocks(c).seqEst);

        fprintf(['  %s: selected %d/%d trials; trialId = %s\n'], ...
            category_blocks(c).label, numel(selection), n_available, ...
            mat2str(all_trial_ids(selection)));
    end
end

function vec = getGroupR2VectorLocal( ...
    category_result, field_name, group_idx)

    if ~isfield(category_result, field_name) || ...
            ~isfield(category_result.(field_name), 'neuron_by_group')
        error('R2 category is missing %s.neuron_by_group.', field_name);
    end

    by_group = category_result.(field_name).neuron_by_group;

    if ~iscell(by_group) || group_idx > numel(by_group)
        error('%s.neuron_by_group does not contain group %d.', ...
            field_name, group_idx);
    end

    vec = double(by_group{group_idx}(:));
end

function r2_matrix = collectNeuronR2MatrixLocal( ...
    R, category_fields, r2_field_names, group_idx, local_neuron_id)

    r2_matrix = nan(numel(category_fields), numel(r2_field_names));

    for c = 1:numel(category_fields)
        for f = 1:numel(r2_field_names)
            vec = getGroupR2VectorLocal( ...
                R.(category_fields{c}), ...
                r2_field_names{f}, group_idx);
            r2_matrix(c, f) = vec(local_neuron_id);
        end
    end
end

function fig = plotHighR2NeuronLocal( ...
    category_blocks, selected_trial_indices, ...
    analysis_fields, reconstruction_labels, r2_matrix, ...
    global_neuron_row, local_neuron_id, ...
    group_display_name, session_name, high_r2_threshold, ...
    response_scale_factor, response_axis_label, ...
    run_metadata, bin_width_ms, figure_name, figure_visible, ...
    figure_width, figure_height, font_name, axis_font_size, ...
    panel_title_font_size, main_title_font_size, line_width, ...
    y_padding_fraction)

    num_categories = numel(category_blocks);
    num_fields = numel(analysis_fields);

    if num_fields ~= 6 || ...
            numel(reconstruction_labels) ~= num_fields
        error(['This figure requires Original plus exactly five ', ...
            'reconstruction fields.']);
    end

    if ~isequal(size(r2_matrix), [num_categories, num_fields - 1])
        error('The neuron R2 matrix has incompatible dimensions.');
    end

    if numel(selected_trial_indices) ~= num_categories
        error('selected_trial_indices has the wrong category count.');
    end

    curve_data = cell(1, num_categories);
    x_values_by_category = cell(1, num_categories);
    y_limits_by_category = cell(1, num_categories);
    x_label_text = '';

    for c = 1:num_categories
        curves = buildIndividualTrialCurvesLocal( ...
            category_blocks(c).seqEst, ...
            selected_trial_indices{c}, analysis_fields, ...
            global_neuron_row, response_scale_factor);
        curve_data{c} = curves;

        [x_values, this_x_label] = getTimeAxisLocal( ...
            run_metadata, size(curves, 3), bin_width_ms);
        x_values_by_category{c} = x_values;

        if isempty(x_label_text)
            x_label_text = this_x_label;
        elseif ~strcmp(x_label_text, this_x_label)
            error('Time-axis labels differ across categories.');
        end

        y_limits_by_category{c} = sharedValuesYLimitsLocal( ...
            curves, y_padding_fraction);
    end

    fig = figure( ...
        'Name', figure_name, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', figure_visible, ...
        'Position', [50, 50, figure_width, figure_height]);

    set(fig, ...
        'DefaultAxesFontName', font_name, ...
        'DefaultTextFontName', font_name);

    layout = tiledlayout(fig, num_categories, num_fields, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');
    axes_grid = gobjects(num_categories, num_fields);

    for c = 1:num_categories
        curves = curve_data{c};
        x_values = x_values_by_category{c};
        x_edges = estimateXEdgesLocal(x_values);
        n_selected = size(curves, 2);
        n_time = size(curves, 3);

        for f = 1:num_fields
            ax = nexttile(layout, (c - 1) * num_fields + f);
            axes_grid(c, f) = ax;
            hold(ax, 'on');

            curves_this_field = reshape( ...
                curves(f, :, :), n_selected, n_time);
            plot(ax, x_values(:), curves_this_field.', '-', ...
                'Color', [0, 0, 0], ...
                'LineWidth', line_width, ...
                'HandleVisibility', 'off');

            xlim(ax, [x_edges(1), x_edges(end)]);
            ylim(ax, y_limits_by_category{c});

            if f == 1
                r2_text = ' ';
            else
                r2_text = formatR2TitleLocal(r2_matrix(c, f - 1));
            end

            title(ax, { ...
                category_blocks(c).label; ...
                reconstruction_labels{f}; ...
                r2_text}, ...
                'Interpreter', 'tex', ...
                'FontName', font_name, ...
                'FontSize', panel_title_font_size, ...
                'FontWeight', 'normal');

            if f > 1
                set(ax, 'YTickLabel', {});
            end

            if c < num_categories
                set(ax, 'XTickLabel', {});
            end

            cleanAxisLocal(ax, font_name, axis_font_size);
        end
    end

    use_all_r2 = r2_matrix(:, 1);
    qualifying = find( ...
        isfinite(use_all_r2) & use_all_r2 > high_r2_threshold);
    qualifying_parts = cell(1, numel(qualifying));

    for i = 1:numel(qualifying)
        c = qualifying(i);
        qualifying_parts{i} = sprintf('%s=%.4f', ...
            category_blocks(c).label, use_all_r2(c));
    end

    title_line_1 = sprintf( ...
        '%s | %s | model-local neuron %d', ...
        session_name, group_display_name, local_neuron_id);
    title_line_2 = sprintf( ...
        'Selected by use-all R2 > %.4g: %s', ...
        high_r2_threshold, strjoin(qualifying_parts, ', '));

    try
        title(layout, {title_line_1; title_line_2}, ...
            'Interpreter', 'none', ...
            'FontName', font_name, ...
            'FontSize', main_title_font_size, ...
            'FontWeight', 'bold');
    catch
        sgtitle(fig, {title_line_1; title_line_2}, ...
            'Interpreter', 'none', ...
            'FontName', font_name, ...
            'FontSize', main_title_font_size, ...
            'FontWeight', 'bold');
    end

    try
        xlabel(layout, x_label_text, ...
            'Interpreter', 'none', ...
            'FontName', font_name, ...
            'FontSize', axis_font_size + 1);
        ylabel(layout, response_axis_label, ...
            'Interpreter', 'none', ...
            'FontName', font_name, ...
            'FontSize', axis_font_size + 1);
    catch
        xlabel(axes_grid(end, ceil(num_fields / 2)), x_label_text, ...
            'Interpreter', 'none', ...
            'FontName', font_name, ...
            'FontSize', axis_font_size + 1);
        ylabel(axes_grid(ceil(num_categories / 2), 1), ...
            response_axis_label, ...
            'Interpreter', 'none', ...
            'FontName', font_name, ...
            'FontSize', axis_font_size + 1);
    end
end

function curves = buildIndividualTrialCurvesLocal( ...
    seqEst, selected_trial_indices, analysis_fields, neuron_row, ...
    response_scale_factor)

    if isempty(seqEst)
        error('Cannot build individual-trial curves from empty seqEst.');
    end

    selected_trial_indices = reshape(selected_trial_indices, 1, []);

    if isempty(selected_trial_indices) || ...
            any(~isfinite(selected_trial_indices)) || ...
            any(selected_trial_indices < 1) || ...
            any(selected_trial_indices ~= round(selected_trial_indices)) || ...
            any(selected_trial_indices > numel(seqEst)) || ...
            numel(unique(selected_trial_indices)) ~= ...
            numel(selected_trial_indices)
        error('Selected individual-trial indices are invalid.');
    end

    num_fields = numel(analysis_fields);
    num_selected = numel(selected_trial_indices);
    reference_time_length = [];
    curves = [];

    for f = 1:num_fields
        field_name = analysis_fields{f};
        checkSeqFieldLocal(seqEst, field_name, neuron_row);
        time_length = size( ...
            seqEst(selected_trial_indices(1)).(field_name), 2);

        if isempty(reference_time_length)
            reference_time_length = time_length;
            curves = nan( ...
                num_fields, num_selected, reference_time_length);
        elseif time_length ~= reference_time_length
            error('Time length differs across reconstruction fields.');
        end

        for k = 1:num_selected
            trial_idx = selected_trial_indices(k);
            Y = double(seqEst(trial_idx).(field_name));

            if size(Y, 2) ~= reference_time_length
                error('Time length differs in seqEst(%d).%s.', ...
                    trial_idx, field_name);
            end

            curves(f, k, :) = reshape( ...
                Y(neuron_row, :) .* response_scale_factor, ...
                1, 1, reference_time_length);
        end
    end
end

function checkSeqFieldLocal(seqEst, field_name, neuron_row)
    if ~isfield(seqEst, field_name)
        error('seqEst is missing field %s.', field_name);
    end

    for tr = 1:numel(seqEst)
        Y = seqEst(tr).(field_name);

        if ~isnumeric(Y) || ndims(Y) ~= 2
            error('seqEst(%d).%s must be a numeric 2-D matrix.', ...
                tr, field_name);
        end

        if neuron_row > size(Y, 1)
            error(['seqEst(%d).%s contains only %d rows, but global ', ...
                'neuron row %d was requested.'], ...
                tr, field_name, size(Y, 1), neuron_row);
        end
    end
end

function text_value = formatR2TitleLocal(value)
    if isfinite(value)
        text_value = sprintf('R^2 = %.4f', value);
    elseif isnan(value)
        text_value = 'R^2 = NaN';
    elseif value > 0
        text_value = 'R^2 = Inf';
    else
        text_value = 'R^2 = -Inf';
    end
end

function y_limits = sharedValuesYLimitsLocal(values, padding_fraction)
    vals = [double(values(:)); 0];
    vals = vals(isfinite(vals));

    if isempty(vals)
        error('No finite values are available for curve y limits.');
    end

    low_value = min(vals);
    high_value = max(vals);

    if low_value == high_value
        padding = max(1, abs(low_value) .* 0.05);
    else
        padding = (high_value - low_value) .* padding_fraction;
    end

    y_limits = [low_value - padding, high_value + padding];
end

function [x_values, x_label_text] = getTimeAxisLocal( ...
    run_metadata, time_length, bin_width_ms)

    x_label_text = 'Time (ms)';

    if isfield(run_metadata, 'bin_centers') && ...
            isnumeric(run_metadata.bin_centers) && ...
            numel(run_metadata.bin_centers) == time_length
        x_values = double(run_metadata.bin_centers(:)') .* 1000;
    elseif isfield(run_metadata, 'analysis_window') && ...
            isnumeric(run_metadata.analysis_window) && ...
            numel(run_metadata.analysis_window) == 2
        start_ms = double(run_metadata.analysis_window(1)) .* 1000;
        x_values = start_ms + ...
            ((1:time_length) - 0.5) .* bin_width_ms;
    else
        x_values = ((1:time_length) - 0.5) .* bin_width_ms;
    end
end

function x_edges = estimateXEdgesLocal(x_values)
    x_values = double(x_values(:)');

    if numel(x_values) == 1
        x_edges = [x_values(1) - 0.5, x_values(1) + 0.5];
        return;
    end

    spacing = diff(x_values);
    spacing = spacing(isfinite(spacing) & spacing ~= 0);

    if isempty(spacing)
        step = 1;
    else
        step = median(abs(spacing));
    end

    x_edges = [ ...
        x_values(1) - step / 2, ...
        x_values(end) + step / 2];
end

function [scale_factor, axis_label] = getResponseDisplayInfoLocal( ...
    data_content, bin_width_ms, run_metadata)

    content = lower(strtrim(char(data_content)));

    if strcmp(content, 'raw_count')
        checkBinWidthAgainstMetadataLocal( ...
            bin_width_ms, run_metadata);
        scale_factor = 1000 ./ bin_width_ms;
        axis_label = 'Firing rate (Hz)';
    elseif strcmp(content, 'raw_fr')
        checkBinWidthAgainstMetadataLocal( ...
            bin_width_ms, run_metadata);
        scale_factor = 1;
        axis_label = 'Firing rate (Hz)';
    else
        scale_factor = 1;
        axis_label = 'Response';
        warning(['data_content is %s rather than raw_count/raw_fr. ', ...
            'Response values will not be converted to firing rate.'], ...
            data_content);
    end
end

function checkBinWidthAgainstMetadataLocal( ...
    bin_width_ms, run_metadata)

    saved_bin_width_ms = [];

    if isfield(run_metadata, 'bin_size') && ...
            isnumeric(run_metadata.bin_size) && ...
            isscalar(run_metadata.bin_size) && ...
            isfinite(run_metadata.bin_size) && ...
            run_metadata.bin_size > 0
        saved_bin_width_ms = double(run_metadata.bin_size) .* 1000;
    elseif isfield(run_metadata, 'bin_centers') && ...
            isnumeric(run_metadata.bin_centers) && ...
            numel(run_metadata.bin_centers) >= 2
        differences_ms = diff( ...
            double(run_metadata.bin_centers(:)')) .* 1000;
        differences_ms = differences_ms( ...
            isfinite(differences_ms) & differences_ms > 0);

        if ~isempty(differences_ms)
            saved_bin_width_ms = median(differences_ms);
        end
    end

    if isempty(saved_bin_width_ms)
        warning(['No valid saved bin_size/bin_centers metadata was ', ...
            'found. Using bin_width_ms = %g.'], bin_width_ms);
        return;
    end

    tolerance = max( ...
        1e-6, 1e-6 .* max(abs([bin_width_ms, saved_bin_width_ms])));

    if abs(bin_width_ms - saved_bin_width_ms) > tolerance
        error(['bin_width_ms is %g ms, but saved metadata indicates ', ...
            '%g ms.'], bin_width_ms, saved_bin_width_ms);
    end
end

function rows = getGroupRowsLocal(yDims, group_idx)
    yDims = reshape(double(yDims), 1, []);

    if group_idx < 1 || group_idx > numel(yDims)
        error('Invalid model-group index: %d.', group_idx);
    end

    starts = cumsum([1, yDims(1:end-1)]);
    stops = cumsum(yDims);
    rows = starts(group_idx):stops(group_idx);
end

function cleanAxisLocal(ax, font_name, font_size)
    grid(ax, 'off');
    box(ax, 'off');

    set(ax, ...
        'TickDir', 'out', ...
        'LineWidth', 1, ...
        'FontName', font_name, ...
        'FontSize', font_size, ...
        'Layer', 'top');
end

function text_value = numberOrInfTextLocal(value)
    if isinf(value)
        text_value = 'Inf';
    else
        text_value = sprintf('%d', value);
    end
end

function tag = numericFileTagLocal(value)
    tag = sprintf('%.6g', value);
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '+', '');
    tag = strrep(tag, '.', 'p');
end

function all_tags = getAllRunTagsLocal(model_data_allruns)
    if ~iscell(model_data_allruns) || isempty(model_data_allruns)
        error('model_data_allruns must be a nonempty cell array.');
    end

    all_tags = cell(numel(model_data_allruns), 1);

    for i = 1:numel(model_data_allruns)
        if ~isstruct(model_data_allruns{i}) || ...
                ~isfield(model_data_allruns{i}, 'stim_tag')
            error('stim_tag is missing in model_data_allruns{%d}.', i);
        end

        all_tags{i} = char(model_data_allruns{i}.stim_tag);
    end
end

function requireFieldLocal(S, field_name, source_name)
    if ~isfield(S, field_name)
        error('%s is missing field %s.', source_name, field_name);
    end
end

function S = loadMatFileFlexibleLocal(file_base, varargin)
    if isfile(file_base)
        S = load(file_base, varargin{:});
        return;
    end

    if ~endsWith(file_base, '.mat')
        file_mat = [file_base, '.mat'];
        if isfile(file_mat)
            S = load(file_mat, varargin{:});
            return;
        end
    end

    error('File not found: %s or %s.mat', file_base, file_base);
end

function file_path = findOneFileLocal(folder_path, pattern, required)
    if nargin < 3
        required = true;
    end

    if ~isfolder(folder_path)
        if required
            error('Folder not found: %s', folder_path);
        end

        file_path = '';
        return;
    end

    listing = dir(fullfile(folder_path, pattern));
    listing = listing(~[listing.isdir]);

    if isempty(listing)
        if required
            error('No file matching %s was found in %s.', ...
                pattern, folder_path);
        end

        file_path = '';
        return;
    end

    if numel(listing) > 1
        error('Multiple files matching %s were found in %s: %s', ...
            pattern, folder_path, strjoin({listing.name}, ', '));
    end

    file_path = fullfile(folder_path, listing(1).name);
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
        requireNonemptyTextLocal(group_names{g}, ...
            sprintf('group_names{%d}', g));
        group_names{g} = strtrim(char(group_names{g}));
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
    tag = strtrim(char(group_name));
    tag = regexprep(tag, '[^A-Za-z0-9_-]+', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');

    if isempty(tag)
        tag = 'area';
    end
end

function file_base = sanitizeFileNameLocal(file_base)
    bad_characters = {'/', '\', ':', '*', '?', '"', '<', '>', '|', ' '};

    for i = 1:numel(bad_characters)
        file_base = strrep(file_base, bad_characters{i}, '_');
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
