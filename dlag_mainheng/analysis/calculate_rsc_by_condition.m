%% =========================================================================
% calculate_rsc_by_condition
%
% Purpose
% -------
% Calculate trial-by-trial spike-count noise correlation (r_sc) separately
% for every stimulus condition in one run of model_data_allruns.
%
% Core rules
% ----------
% 1) Always use raw_count_by_condition.
% 2) For every trial, sum all time bins to obtain one count response per
%    neuron.
% 3) Detect outlier trials separately within each condition. For every
%    neuron, an outlier is a response outside mean +/- N standard
%    deviations. Take the union across neurons and remove those trials from
%    every neuron in that condition. Detection is performed once only.
% 4) After condition-specific outlier-trial removal, identify neurons whose
%    response SD is zero in each condition. Take the UNION of those neurons
%    across ALL conditions and remove that union from EVERY condition.
%    Therefore every condition uses exactly the same neurons and exactly the
%    same ordered neuron pairs.
% 5) Within each condition, z-score every retained neuron's response across
%    the retained trials, then calculate Pearson r_sc for all within-area
%    and across-area neuron pairs.
% 6) Save outputs beside this program. FIG, PNG, and MAT saving are
%    controlled independently in the parameter section.
%
% Pair-type order
% ---------------
% For area_names = {'V1','MT'}:
%     V1-V1, MT-MT, V1-MT
%
% For area_names = {'A','B','C'}:
%     A-A, B-B, C-C, A-B, A-C, B-C
%
% Notes
% -----
% - MATLAB's sample SD normalization (N-1; std(...,0,...)) is used for
%   outlier detection, condition-wise z-scoring, and the SD of each r_sc
%   distribution.
% - Correlations involving any neuron in the across-condition zero-variance
%   union are excluded; they are never replaced by zero.
% =========================================================================

clc;
clear;
close all;

%% =============================== Parameters ===============================

% model_data_allruns MAT file. Relative paths are resolved from MATLAB's
% current folder, exactly as in train_dlag.m.
model_data_file = fullfile(pwd, 'model_data_allruns.mat');

% Select one run by exact stim_tag match.
stim_tag = '[Gpl2_2c_2sz_400_2_200isi]';

% Display names in model-group order. The number of names must equal the
% number of groups in raw_count_groupd (or groupd).
area_names = {'V1', 'MT'};

% One-pass outlier rule within each neuron and condition.
outlier_sd_threshold = 3;

% Output switches. All selected outputs are placed beside this program.
save_fig = false;
save_png = true;
save_mat = true;

% PNG export resolution.
png_resolution = 300;

% Leave empty for an automatic, collision-resistant name containing the
% stim_tag and all area names. If nonempty, enter a base filename only,
% without a folder or extension.
output_base_name = '';

% Figure appearance.
figure_visible = 'on';       % 'on' or 'off'
marker_size = 52;
% Width occupied by the 8 condition positions inside each pair-type group.
condition_group_width = 0.9;
% Small left/right separation between the two directions within one
% condition position. Both directions use identical filled markers.
direction_x_offset = 0.009;
font_name = 'Arial';
font_size = 12;

%% ============================= Validate input ==============================

area_names = normalizeAreaNamesLocal(area_names);

if ~(isscalar(outlier_sd_threshold) && isnumeric(outlier_sd_threshold) && ...
        isfinite(outlier_sd_threshold) && outlier_sd_threshold > 0)
    error('outlier_sd_threshold must be one positive finite numeric scalar.');
end

save_fig = validateLogicalScalarLocal(save_fig, 'save_fig');
save_png = validateLogicalScalarLocal(save_png, 'save_png');
save_mat = validateLogicalScalarLocal(save_mat, 'save_mat');

if ~(isscalar(png_resolution) && isnumeric(png_resolution) && ...
        isfinite(png_resolution) && png_resolution > 0)
    error('png_resolution must be one positive finite numeric scalar.');
end

if ~(isscalar(condition_group_width) && isnumeric(condition_group_width) && ...
        isfinite(condition_group_width) && condition_group_width > 0 && ...
        condition_group_width < 1)
    error('condition_group_width must be one finite numeric scalar between 0 and 1.');
end

if ~(isscalar(direction_x_offset) && isnumeric(direction_x_offset) && ...
        isfinite(direction_x_offset) && direction_x_offset >= 0)
    error('direction_x_offset must be one nonnegative finite numeric scalar.');
end

if ~(ischar(figure_visible) || (isstring(figure_visible) && isscalar(figure_visible)))
    error('figure_visible must be ''on'' or ''off''.');
end
figure_visible = lower(strtrim(char(string(figure_visible))));
if ~ismember(figure_visible, {'on', 'off'})
    error('figure_visible must be ''on'' or ''off''.');
end

script_full_path = mfilename('fullpath');
if isempty(script_full_path)
    script_dir = pwd;
    warning('calculate_rsc_by_condition:ScriptPathUnavailable', ...
        ['MATLAB did not return this script''s full path. Outputs will be ', ...
         'saved in the current folder: %s'], script_dir);
else
    script_dir = fileparts(script_full_path);
end

model_data_file = char(string(model_data_file));
if exist(model_data_file, 'file') ~= 2 && exist([model_data_file, '.mat'], 'file') == 2
    model_data_file = [model_data_file, '.mat'];
end
if exist(model_data_file, 'file') ~= 2
    error('model_data_file does not exist: %s', model_data_file);
end

fprintf('Reading model data from:\n%s\n', model_data_file);
loaded_data = load(model_data_file, 'model_data_allruns');
if ~isfield(loaded_data, 'model_data_allruns')
    error('Variable model_data_allruns is missing from %s.', model_data_file);
end
model_data_allruns = loaded_data.model_data_allruns;
clear loaded_data;

if ~iscell(model_data_allruns) || isempty(model_data_allruns)
    error('model_data_allruns must be a nonempty cell array.');
end

all_run_tags = getAllRunTagsLocal(model_data_allruns);
run_idx = find(strcmp(all_run_tags, stim_tag));
if isempty(run_idx)
    error('Requested stim_tag not found: %s', stim_tag);
end
if numel(run_idx) > 1
    error('Duplicate stim_tag found: %s', stim_tag);
end

this_run = model_data_allruns{run_idx};
data_field = 'raw_count';
condition_data_field = 'raw_count_by_condition';

if ~isfield(this_run, condition_data_field)
    error('Field %s is missing from model_data_allruns{%d}.', ...
        condition_data_field, run_idx);
end
if ~isfield(this_run, 'conditions_full')
    error('Field conditions_full is missing from model_data_allruns{%d}.', run_idx);
end

[groupd, groupd_field] = getGroupDimensionsLocal(this_run, data_field);
num_groups = numel(groupd);
if numel(area_names) ~= num_groups
    error(['area_names has %d entries, but %s contains %d model groups. ', ...
           'area_names must follow model-group order.'], ...
        numel(area_names), groupd_field, num_groups);
end

raw_count_by_condition = this_run.(condition_data_field);
conditions_full = this_run.conditions_full;
num_conditions = numel(raw_count_by_condition);

if num_conditions ~= numel(conditions_full)
    error(['%s contains %d conditions, whereas conditions_full contains %d.'], ...
        condition_data_field, num_conditions, numel(conditions_full));
end
if num_conditions < 1
    error('%s is empty.', condition_data_field);
end

group_rows = makeGroupRowRangesLocal(groupd);
num_neurons = sum(groupd);
group_unit_metadata = extractGroupUnitMetadataLocal( ...
    this_run, data_field, groupd_field, groupd, group_rows, area_names);

condition_ids = 1:num_conditions;
condition_map = buildConditionSummaryMapLocal(conditions_full, condition_ids);
validateCompleteConditionMapLocal(condition_map, num_conditions);

fprintf('\nSelected run index : %d\n', run_idx);
fprintf('Stim tag           : %s\n', stim_tag);
fprintf('Data field         : %s\n', data_field);
fprintf('Group dimensions   : %s (from %s)\n', mat2str(groupd), groupd_field);
fprintf('Areas              : %s\n', strjoin(area_names, ', '));
fprintf('Conditions         : %d\n', num_conditions);
fprintf('Outlier threshold  : mean +/- %.4g SD (one pass)\n\n', ...
    outlier_sd_threshold);

%% =========================================================================
% Pass 1
%   - Build one total-count response per neuron and trial.
%   - Detect condition-specific outlier trials and remove their neuron-wise
%     union.
%   - Detect zero-variance neurons after that trial removal.
%% =========================================================================

condition_template = struct( ...
    'condition_id', [], ...
    'condition_metadata', struct(), ...
    'condition_long_label', '', ...
    'condition_short_label', '', ...
    'panel_condition_index', [], ...
    'direction_value', [], ...
    'direction_code', [], ...
    'direction_label', '', ...
    'trial_ids_original', [], ...
    'n_trials_original', [], ...
    'trial_response_count', [], ...
    'pre_outlier_mean', [], ...
    'pre_outlier_sd', [], ...
    'outlier_mask_by_neuron', [], ...
    'outlier_count_by_neuron', [], ...
    'outlier_trial_mask_union', [], ...
    'outlier_trial_ids_union', [], ...
    'n_outlier_trials_union', [], ...
    'kept_trial_mask', [], ...
    'kept_trial_ids', [], ...
    'n_trials_kept', [], ...
    'post_outlier_mean', [], ...
    'post_outlier_sd', [], ...
    'zero_variance_mask_this_condition', [], ...
    'zero_variance_count_by_area_this_condition', [], ...
    'zscored_trial_response_global_kept_neurons', [], ...
    'pair_type_results', struct([]));

condition_results = repmat(condition_template, 1, num_conditions);
zero_variance_by_condition = false(num_neurons, num_conditions);
condition_zero_variance_count_by_area = zeros(num_groups, num_conditions);

for c = 1:num_conditions
    map_entry = condition_map.entries(c);
    if ~isfield(raw_count_by_condition(c), 'trials')
        error('%s(%d) is missing field trials.', condition_data_field, c);
    end
    condition_trials = raw_count_by_condition(c).trials;

    [trial_response_count, trial_ids] = buildTrialCountResponseLocal( ...
        condition_trials, num_neurons, c);

    n_trials = size(trial_response_count, 2);
    pre_mean = mean(trial_response_count, 2);
    pre_sd = std(trial_response_count, 0, 2);

    deviation = abs(bsxfun(@minus, trial_response_count, pre_mean));
    threshold_by_neuron = outlier_sd_threshold .* pre_sd;
    outlier_mask_by_neuron = bsxfun(@gt, deviation, threshold_by_neuron);

    % A neuron with zero SD before outlier removal has no trial outside a
    % nonzero threshold. It will be handled by the zero-variance rule below.
    outlier_mask_by_neuron(pre_sd == 0, :) = false;

    outlier_trial_mask_union = any(outlier_mask_by_neuron, 1);
    kept_trial_mask = ~outlier_trial_mask_union;

    if ~any(kept_trial_mask)
        error(['Condition %d (%s, direction %s) has no trials left after ', ...
               'the union of neuron-wise outlier trials was removed.'], ...
            c, map_entry.panelCondShortLabel, ...
            formatSummaryValueLocal(map_entry.stimDirValue));
    end

    retained_response = trial_response_count(:, kept_trial_mask);
    post_mean = mean(retained_response, 2);
    post_sd = std(retained_response, 0, 2);

    if any(~isfinite(post_mean)) || any(~isfinite(post_sd))
        error(['Condition %d contains a nonfinite post-outlier mean or SD. ', ...
               'The raw_count trial responses must be finite.'], c);
    end

    zero_mask = (post_sd == 0);
    zero_variance_by_condition(:, c) = zero_mask;

    for g = 1:num_groups
        condition_zero_variance_count_by_area(g, c) = ...
            sum(zero_mask(group_rows{g}));
    end

    condition_results(c).condition_id = c;
    condition_results(c).condition_metadata = conditions_full(c);
    condition_results(c).condition_long_label = map_entry.panelCondLabel;
    condition_results(c).condition_short_label = map_entry.panelCondShortLabel;
    condition_results(c).panel_condition_index = map_entry.panelCondIndex;
    condition_results(c).direction_value = map_entry.stimDirValue;
    condition_results(c).direction_code = map_entry.stimDirCode;
    condition_results(c).direction_label = map_entry.stimDirLabel;
    condition_results(c).trial_ids_original = trial_ids;
    condition_results(c).n_trials_original = n_trials;
    condition_results(c).trial_response_count = trial_response_count;
    condition_results(c).pre_outlier_mean = pre_mean;
    condition_results(c).pre_outlier_sd = pre_sd;
    condition_results(c).outlier_mask_by_neuron = outlier_mask_by_neuron;
    condition_results(c).outlier_count_by_neuron = ...
        sum(outlier_mask_by_neuron, 2);
    condition_results(c).outlier_trial_mask_union = outlier_trial_mask_union;
    condition_results(c).outlier_trial_ids_union = ...
        trial_ids(outlier_trial_mask_union);
    condition_results(c).n_outlier_trials_union = ...
        sum(outlier_trial_mask_union);
    condition_results(c).kept_trial_mask = kept_trial_mask;
    condition_results(c).kept_trial_ids = trial_ids(kept_trial_mask);
    condition_results(c).n_trials_kept = sum(kept_trial_mask);
    condition_results(c).post_outlier_mean = post_mean;
    condition_results(c).post_outlier_sd = post_sd;
    condition_results(c).zero_variance_mask_this_condition = zero_mask;
    condition_results(c).zero_variance_count_by_area_this_condition = ...
        condition_zero_variance_count_by_area(:, c)';

    fprintf(['Condition %2d  %-5s  dir=%-6s : trials %d, ', ...
             'union outliers %d, kept %d\n'], ...
        c, map_entry.panelCondShortLabel, ...
        formatSummaryValueLocal(map_entry.stimDirValue), ...
        n_trials, sum(outlier_trial_mask_union), sum(kept_trial_mask));
end

%% =========================================================================
% Across-condition zero-variance union
% The resulting fixed neuron mask and fixed pair list are used for every
% condition.
%% =========================================================================

zero_variance_union = any(zero_variance_by_condition, 2);
global_keep_neuron_mask = ~zero_variance_union;
global_kept_neuron_indices = find(global_keep_neuron_mask);

zero_variance_summary_by_area = buildZeroVarianceSummaryLocal( ...
    zero_variance_by_condition, zero_variance_union, group_rows, ...
    group_unit_metadata, area_names, condition_results);

fprintf('\nAcross-condition zero-variance union:\n');
for g = 1:num_groups
    this_summary = zero_variance_summary_by_area(g);
    fprintf('  Group %d, %s: %d of %d neurons removed; %d retained.\n', ...
        g, area_names{g}, this_summary.n_zero_variance_union, groupd(g), ...
        this_summary.n_retained);

    if this_summary.n_zero_variance_union > 0
        unit_id_text = '';
        if this_summary.unit_ids_available
            unit_id_text = sprintf(' Unit IDs: %s.', ...
                mat2str(this_summary.unit_ids(:)'));
        end

        warning('calculate_rsc_by_condition:ZeroVarianceNeuronUnion', ...
            ['After condition-specific outlier-trial removal, area %s ', ...
             '(group %d) has %d neuron(s) with zero variance in at least ', ...
             'one condition. Their across-condition UNION is removed from ', ...
             'EVERY condition so all conditions use identical neurons and ', ...
             'pairs. Group-local neuron indices: %s. Trigger conditions: ', ...
             '%s.%s'], ...
            area_names{g}, g, this_summary.n_zero_variance_union, ...
            mat2str(this_summary.group_local_indices(:)'), ...
            formatConditionTriggerListLocal( ...
                this_summary.trigger_condition_ids, condition_results), ...
            unit_id_text);
    end
end

% Rebuild pair definitions once with the fixed across-condition keep mask.
pair_types = buildFixedPairTypeDefinitionsLocal( ...
    area_names, group_rows, global_keep_neuron_mask);
pair_type_names = {pair_types.name};
num_pair_types = numel(pair_types);

fprintf('\nFixed pair counts used in every condition:\n');
for p = 1:num_pair_types
    fprintf('  %-16s : %d retained of %d possible (%d excluded)\n', ...
        pair_types(p).name, pair_types(p).n_pairs, ...
        pair_types(p).n_total_possible_pairs, ...
        pair_types(p).n_excluded_zero_variance_pairs);
end

%% =========================================================================
% Pass 2
%   - Z-score after condition-specific trial removal.
%   - Use the fixed, across-condition neuron union and pair definitions.
%   - Compute each condition's r_sc distributions and summary statistics.
%% =========================================================================

mean_rsc = nan(num_conditions, num_pair_types);
sd_rsc = nan(num_conditions, num_pair_types);
n_rsc_pairs = zeros(num_conditions, num_pair_types);

pair_result_template = struct( ...
    'pair_type_index', [], ...
    'pair_type_name', '', ...
    'rsc_values', [], ...
    'n_total_possible_pairs', [], ...
    'n_excluded_zero_variance_pairs', [], ...
    'n_pairs', [], ...
    'mean_rsc', [], ...
    'sd_rsc', []);

for c = 1:num_conditions
    kept_mask = condition_results(c).kept_trial_mask;
    retained_response = condition_results(c).trial_response_count(:, kept_mask);

    retained_response = retained_response(global_keep_neuron_mask, :);
    retained_mean = condition_results(c).post_outlier_mean( ...
        global_keep_neuron_mask);
    retained_sd = condition_results(c).post_outlier_sd( ...
        global_keep_neuron_mask);

    if any(retained_sd == 0)
        error(['Internal error: condition %d still contains a zero-SD ', ...
               'neuron after applying the across-condition union.'], c);
    end

    z_response = bsxfun(@rdivide, ...
        bsxfun(@minus, retained_response, retained_mean), retained_sd);

    if any(~isfinite(z_response(:)))
        error('Condition %d produced a nonfinite z-scored response.', c);
    end

    condition_results(c).zscored_trial_response_global_kept_neurons = ...
        z_response;

    pair_results = repmat(pair_result_template, 1, num_pair_types);

    for p = 1:num_pair_types
        r_values = computeFixedPairRSCValuesLocal( ...
            z_response, global_kept_neuron_indices, pair_types(p), c);

        if isempty(r_values)
            this_mean = NaN;
            this_sd = NaN;
        else
            this_mean = mean(r_values);
            this_sd = std(r_values, 0);
        end

        pair_results(p).pair_type_index = p;
        pair_results(p).pair_type_name = pair_types(p).name;
        pair_results(p).rsc_values = r_values(:)';
        pair_results(p).n_total_possible_pairs = ...
            pair_types(p).n_total_possible_pairs;
        pair_results(p).n_excluded_zero_variance_pairs = ...
            pair_types(p).n_excluded_zero_variance_pairs;
        pair_results(p).n_pairs = numel(r_values);
        pair_results(p).mean_rsc = this_mean;
        pair_results(p).sd_rsc = this_sd;

        mean_rsc(c, p) = this_mean;
        sd_rsc(c, p) = this_sd;
        n_rsc_pairs(c, p) = numel(r_values);
    end

    condition_results(c).pair_type_results = pair_results;
end

expected_pair_counts = [pair_types.n_pairs];
if any(any(bsxfun(@ne, n_rsc_pairs, expected_pair_counts)))
    error(['Internal error: pair counts are not identical across conditions. ', ...
           'The fixed pair rule was not preserved.']);
end

%% ================================ Plot =====================================

condition_colors = lines(numel(condition_map.meta.panelCondShortLabels));

fig_handle = plotRSCConditionSummaryLocal( ...
    mean_rsc, sd_rsc, condition_map, pair_types, condition_colors, ...
    condition_group_width, direction_x_offset, marker_size, ...
    font_name, font_size, ...
    figure_visible, stim_tag);

%% ============================ Assemble output ==============================

RSCResults = struct();

RSCResults.meta.created_by = mfilename;
RSCResults.meta.created_on = datestr(now, 30);
RSCResults.meta.source_model_data_file = model_data_file;
RSCResults.meta.run_index = run_idx;
RSCResults.meta.stim_tag = stim_tag;
RSCResults.meta.data_field = data_field;
RSCResults.meta.condition_data_field = condition_data_field;
RSCResults.meta.outlier_sd_threshold = outlier_sd_threshold;
RSCResults.meta.outlier_detection_iterations = 1;
RSCResults.meta.outlier_rule = [ ...
    'Within each condition and neuron, responses outside mean +/- threshold*SD; ', ...
    'remove the union of outlier trials from every neuron in that condition.'];
RSCResults.meta.zero_variance_rule = [ ...
    'After condition-specific outlier-trial removal, take the union of zero-SD ', ...
    'neurons across all conditions and remove that union from every condition.'];
RSCResults.meta.sd_normalization = 'sample SD, N-1 (MATLAB std(...,0,...))';
RSCResults.meta.correlation_definition = [ ...
    'Pearson correlation across retained trials after within-condition z-scoring.'];

RSCResults.meta.area_names = area_names;
RSCResults.meta.groupd = groupd;
RSCResults.meta.groupd_field = groupd_field;
RSCResults.meta.group_rows = group_rows;
RSCResults.meta.group_unit_metadata = group_unit_metadata;
RSCResults.meta.num_neurons_original = num_neurons;
RSCResults.meta.global_keep_neuron_mask = global_keep_neuron_mask;
RSCResults.meta.global_kept_neuron_indices = global_kept_neuron_indices;
RSCResults.meta.zero_variance_union_mask = zero_variance_union;
RSCResults.meta.zero_variance_union_indices = find(zero_variance_union);
RSCResults.meta.zero_variance_by_condition = zero_variance_by_condition;
RSCResults.meta.zero_variance_summary_by_area = ...
    zero_variance_summary_by_area;

RSCResults.meta.condition_map = condition_map;
RSCResults.meta.condition_colors = condition_colors;
RSCResults.meta.direction_marker_rule = ...
    ['Both directions = identical filled circles; two points per base ', ...
     'condition; no connecting lines and no direction-specific legend.'];
RSCResults.meta.plot_condition_order = ...
    condition_map.meta.panelCondShortLabels;
RSCResults.meta.plot_condition_group_width = condition_group_width;
RSCResults.meta.plot_direction_x_offset = direction_x_offset;
RSCResults.meta.pair_types = pair_types;
RSCResults.meta.pair_type_names = pair_type_names;

RSCResults.conditions = condition_results;

RSCResults.summary.condition_ids = condition_ids;
RSCResults.summary.condition_short_labels = ...
    {condition_results.condition_short_label};
RSCResults.summary.condition_long_labels = ...
    {condition_results.condition_long_label};
RSCResults.summary.direction_values = [condition_results.direction_value];
RSCResults.summary.direction_codes = [condition_results.direction_code];
RSCResults.summary.pair_type_names = pair_type_names;
RSCResults.summary.n_total_possible_pairs = ...
    [pair_types.n_total_possible_pairs];
RSCResults.summary.n_excluded_zero_variance_pairs = ...
    [pair_types.n_excluded_zero_variance_pairs];
RSCResults.summary.mean_rsc = mean_rsc;
RSCResults.summary.sd_rsc = sd_rsc;
RSCResults.summary.n_rsc_pairs = n_rsc_pairs;
RSCResults.summary.condition_zero_variance_count_by_area = ...
    condition_zero_variance_count_by_area;

%% =============================== Save ======================================

if isempty(output_base_name)
    output_base_name = makeAutomaticOutputBaseLocal(stim_tag, area_names);
else
    output_base_name = validateOutputBaseNameLocal(output_base_name);
end

output_base_path = fullfile(script_dir, output_base_name);
fig_path = [output_base_path, '.fig'];
png_path = [output_base_path, '.png'];
mat_path = [output_base_path, '.mat'];

RSCResults.meta.output_directory = script_dir;
RSCResults.meta.output_base_name = output_base_name;
RSCResults.meta.save_fig = save_fig;
RSCResults.meta.save_png = save_png;
RSCResults.meta.save_mat = save_mat;
RSCResults.meta.fig_file = ternaryTextLocal(save_fig, fig_path, '');
RSCResults.meta.png_file = ternaryTextLocal(save_png, png_path, '');
RSCResults.meta.mat_file = ternaryTextLocal(save_mat, mat_path, '');

if save_fig
    savefig(fig_handle, fig_path);
    fprintf('\nSaved FIG: %s\n', fig_path);
end

if save_png
    exportgraphics(fig_handle, png_path, 'Resolution', png_resolution);
    fprintf('Saved PNG: %s\n', png_path);
end

if save_mat
    save(mat_path, 'RSCResults', '-v7.3');
    fprintf('Saved MAT: %s\n', mat_path);
end

fprintf('\nFinished calculate_rsc_by_condition.\n');

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


function all_tags = getAllRunTagsLocal(model_data_allruns)

all_tags = cell(numel(model_data_allruns), 1);
for j = 1:numel(model_data_allruns)
    if ~isstruct(model_data_allruns{j}) || ...
            ~isfield(model_data_allruns{j}, 'stim_tag')
        error('stim_tag missing in model_data_allruns{%d}.', j);
    end
    all_tags{j} = char(string(model_data_allruns{j}.stim_tag));
end

end


function [groupd, groupd_field] = getGroupDimensionsLocal(run_entry, data_field)

specific_field = sprintf('%s_groupd', data_field);
if isfield(run_entry, specific_field)
    groupd = run_entry.(specific_field);
    groupd_field = specific_field;
elseif isfield(run_entry, 'groupd')
    groupd = run_entry.groupd;
    groupd_field = 'groupd';
else
    error('Cannot find %s or groupd in the selected run.', specific_field);
end

groupd = double(groupd(:)');
if isempty(groupd) || any(~isfinite(groupd)) || ...
        any(groupd <= 0) || any(groupd ~= round(groupd))
    error('%s must contain positive finite integer group sizes.', groupd_field);
end

end


function group_rows = makeGroupRowRangesLocal(groupd)

group_rows = cell(1, numel(groupd));
row_start = 1;
for g = 1:numel(groupd)
    row_end = row_start + groupd(g) - 1;
    group_rows{g} = row_start:row_end;
    row_start = row_end + 1;
end

end


function metadata = extractGroupUnitMetadataLocal( ...
        run_entry, data_field, groupd_field, groupd, group_rows, area_names)

num_groups = numel(groupd);
template = struct( ...
    'group_index', [], ...
    'area_name', '', ...
    'probe_index', NaN, ...
    'global_neuron_indices', [], ...
    'group_local_neuron_indices', [], ...
    'unit_ids', [], ...
    'unit_ids_available', false, ...
    'unit_depth_um', [], ...
    'unit_depth_available', false, ...
    'stored_groupname', {{}}, ...
    'stored_groupname_available', false);
metadata = repmat(template, 1, num_groups);

for g = 1:num_groups
    metadata(g).group_index = g;
    metadata(g).area_name = area_names{g};
    metadata(g).global_neuron_indices = group_rows{g};
    metadata(g).group_local_neuron_indices = 1:groupd(g);
    metadata(g).unit_ids = nan(groupd(g), 1);
    metadata(g).unit_depth_um = nan(groupd(g), 1);
    metadata(g).stored_groupname = repmat({''}, groupd(g), 1);
end

if ~isfield(run_entry, 'group_probe') || ...
        numel(run_entry.group_probe) ~= num_groups
    return;
end

group_probe = double(run_entry.group_probe(:)');
if any(~isfinite(group_probe)) || any(group_probe ~= round(group_probe))
    return;
end

for g = 1:num_groups
    metadata(g).probe_index = group_probe(g);
end

if strcmp(groupd_field, sprintf('%s_groupd', data_field))
    preferred_prefix = [data_field, '_'];
else
    preferred_prefix = '';
end

unique_probes = unique(group_probe, 'stable');
for p_idx = 1:numel(unique_probes)
    probe_number = unique_probes(p_idx);
    groups_this_probe = find(group_probe == probe_number);
    expected_count = sum(groupd(groups_this_probe));

    prefix = preferred_prefix;
    id_field = sprintf('%sprobe%d_usedunit_ids', prefix, probe_number);
    if ~isfield(run_entry, id_field) && ~isempty(prefix)
        prefix = '';
        id_field = sprintf('probe%d_usedunit_ids', probe_number);
    end

    if ~isfield(run_entry, id_field)
        continue;
    end

    ids = run_entry.(id_field);
    ids = double(ids(:));
    if numel(ids) ~= expected_count
        warning('calculate_rsc_by_condition:UnitMetadataCountMismatch', ...
            ['Cannot map unit IDs for probe %d: %s has %d entries, but ', ...
             'the selected groups require %d. Correlation calculations ', ...
             'will continue; warnings will still report group-local indices.'], ...
            probe_number, id_field, numel(ids), expected_count);
        continue;
    end

    depth_field = sprintf('%sprobe%d_usedunit_depth_um', prefix, probe_number);
    groupname_field = sprintf('%sprobe%d_usedunit_groupname', prefix, probe_number);

    depth_available = isfield(run_entry, depth_field) && ...
        numel(run_entry.(depth_field)) == expected_count;
    if depth_available
        raw_depths = run_entry.(depth_field);
        depths = double(raw_depths(:));
    else
        depths = nan(expected_count, 1);
    end

    groupname_available = isfield(run_entry, groupname_field) && ...
        numel(run_entry.(groupname_field)) == expected_count;
    if groupname_available
        raw_groupnames = run_entry.(groupname_field);
        raw_groupnames = cellstr(string(raw_groupnames(:)));
    else
        raw_groupnames = repmat({''}, expected_count, 1);
    end

    cursor = 1;
    for k = 1:numel(groups_this_probe)
        g = groups_this_probe(k);
        this_idx = cursor:(cursor + groupd(g) - 1);
        metadata(g).unit_ids = ids(this_idx);
        metadata(g).unit_ids_available = true;
        metadata(g).unit_depth_um = depths(this_idx);
        metadata(g).unit_depth_available = depth_available;
        metadata(g).stored_groupname = raw_groupnames(this_idx);
        metadata(g).stored_groupname_available = groupname_available;
        cursor = this_idx(end) + 1;
    end
end

end


function [trial_response, trial_ids] = buildTrialCountResponseLocal( ...
        trial_struct_array, expected_neurons, condition_id)

if ~isstruct(trial_struct_array) || isempty(trial_struct_array)
    error('Condition %d has no raw_count trials.', condition_id);
end
if ~isfield(trial_struct_array, 'y') || ~isfield(trial_struct_array, 'trialId')
    error('Condition %d trials must contain fields y and trialId.', condition_id);
end

num_trials = numel(trial_struct_array);
trial_response = nan(expected_neurons, num_trials);
trial_ids = nan(1, num_trials);

for t = 1:num_trials
    y = double(trial_struct_array(t).y);
    if ~ismatrix(y) || size(y, 1) ~= expected_neurons
        error(['Condition %d trial position %d has y size %s; expected ', ...
               '%d neurons by time bins.'], ...
            condition_id, t, mat2str(size(y)), expected_neurons);
    end
    if isempty(y) || size(y, 2) < 1
        error('Condition %d trial position %d has no time bins.', ...
            condition_id, t);
    end
    if any(~isfinite(y(:)))
        error(['Condition %d trialId %s contains nonfinite raw_count ', ...
               'values.'], condition_id, ...
            formatSummaryValueLocal(trial_struct_array(t).trialId));
    end

    trial_id = double(trial_struct_array(t).trialId);
    if ~(isscalar(trial_id) && isfinite(trial_id) && ...
            trial_id == round(trial_id))
        error('Condition %d trial position %d has an invalid trialId.', ...
            condition_id, t);
    end

    trial_response(:, t) = sum(y, 2);
    trial_ids(t) = trial_id;
end

if numel(unique(trial_ids)) ~= num_trials
    error('Condition %d contains invalid or duplicate trialId values.', condition_id);
end

end


function summary = buildZeroVarianceSummaryLocal( ...
        zero_by_condition, zero_union, group_rows, group_metadata, ...
        area_names, condition_results)

num_groups = numel(group_rows);
template = struct( ...
    'group_index', [], ...
    'area_name', '', ...
    'n_neurons_original', [], ...
    'n_zero_variance_union', [], ...
    'n_retained', [], ...
    'group_local_indices', [], ...
    'global_indices', [], ...
    'unit_ids_available', false, ...
    'unit_ids', [], ...
    'trigger_condition_ids', [], ...
    'trigger_condition_ids_by_neuron', {{}});
summary = repmat(template, 1, num_groups);

for g = 1:num_groups
    rows = group_rows{g};
    local_mask = zero_union(rows);
    local_indices = find(local_mask);
    global_indices = rows(local_indices);

    summary(g).group_index = g;
    summary(g).area_name = area_names{g};
    summary(g).n_neurons_original = numel(rows);
    summary(g).n_zero_variance_union = numel(local_indices);
    summary(g).n_retained = numel(rows) - numel(local_indices);
    summary(g).group_local_indices = local_indices(:)';
    summary(g).global_indices = global_indices(:)';

    if group_metadata(g).unit_ids_available
        summary(g).unit_ids_available = true;
        summary(g).unit_ids = group_metadata(g).unit_ids(local_indices);
    else
        summary(g).unit_ids_available = false;
        summary(g).unit_ids = [];
    end

    trigger_by_neuron = cell(1, numel(global_indices));
    all_trigger_conditions = [];
    for k = 1:numel(global_indices)
        trigger_ids = find(zero_by_condition(global_indices(k), :));
        trigger_by_neuron{k} = trigger_ids(:)';
        all_trigger_conditions = [all_trigger_conditions, trigger_ids]; %#ok<AGROW>
    end
    summary(g).trigger_condition_ids_by_neuron = trigger_by_neuron;
    summary(g).trigger_condition_ids = unique(all_trigger_conditions, 'stable');

    % Validate that every trigger refers to an existing condition result.
    if any(summary(g).trigger_condition_ids < 1) || ...
            any(summary(g).trigger_condition_ids > numel(condition_results))
        error('Internal zero-variance trigger condition index is invalid.');
    end
end

end


function text_value = formatConditionTriggerListLocal(condition_ids, condition_results)

if isempty(condition_ids)
    text_value = 'none';
    return;
end

parts = cell(1, numel(condition_ids));
for k = 1:numel(condition_ids)
    c = condition_ids(k);
    parts{k} = sprintf('%d(%s, dir=%s)', ...
        c, condition_results(c).condition_short_label, ...
        formatSummaryValueLocal(condition_results(c).direction_value));
end
text_value = strjoin(parts, ', ');

end


function pair_types = buildFixedPairTypeDefinitionsLocal( ...
        area_names, group_rows, global_keep_mask)

num_groups = numel(group_rows);
num_pair_types = num_groups + nchoosek(num_groups, 2);

template = struct( ...
    'index', [], ...
    'name', '', ...
    'group_indices', [], ...
    'area_names', {{}}, ...
    'is_within_area', false, ...
    'valid_global_indices_group1', [], ...
    'valid_global_indices_group2', [], ...
    'pair_global_indices', zeros(0, 2), ...
    'pair_group_local_indices', zeros(0, 2), ...
    'n_total_possible_pairs', [], ...
    'n_excluded_zero_variance_pairs', [], ...
    'n_pairs', []);
pair_types = repmat(template, 1, num_pair_types);

p = 0;
for g = 1:num_groups
    p = p + 1;
    rows = group_rows{g};
    valid_local = find(global_keep_mask(rows));
    valid_global = rows(valid_local);
    valid_global = valid_global(:);
    valid_local = valid_local(:);

    if numel(valid_global) >= 2
        [i, j] = find(triu(true(numel(valid_global)), 1));
        global_pairs = [valid_global(i), valid_global(j)];
        local_pairs = [valid_local(i), valid_local(j)];
    else
        global_pairs = zeros(0, 2);
        local_pairs = zeros(0, 2);
    end

    total_possible = numel(rows) * (numel(rows) - 1) / 2;

    pair_types(p).index = p;
    pair_types(p).name = sprintf('%s-%s', area_names{g}, area_names{g});
    pair_types(p).group_indices = [g, g];
    pair_types(p).area_names = {area_names{g}, area_names{g}};
    pair_types(p).is_within_area = true;
    pair_types(p).valid_global_indices_group1 = valid_global(:)';
    pair_types(p).valid_global_indices_group2 = valid_global(:)';
    pair_types(p).pair_global_indices = global_pairs;
    pair_types(p).pair_group_local_indices = local_pairs;
    pair_types(p).n_total_possible_pairs = total_possible;
    pair_types(p).n_pairs = size(global_pairs, 1);
    pair_types(p).n_excluded_zero_variance_pairs = ...
        total_possible - size(global_pairs, 1);
end

for g1 = 1:(num_groups - 1)
    for g2 = (g1 + 1):num_groups
        p = p + 1;
        rows1 = group_rows{g1};
        rows2 = group_rows{g2};

        valid_local1 = find(global_keep_mask(rows1));
        valid_local2 = find(global_keep_mask(rows2));
        valid_global1 = rows1(valid_local1);
        valid_global2 = rows2(valid_local2);

        valid_global1 = valid_global1(:);
        valid_global2 = valid_global2(:);
        valid_local1 = valid_local1(:);
        valid_local2 = valid_local2(:);

        if ~isempty(valid_global1) && ~isempty(valid_global2)
            [idx1, idx2] = ndgrid( ...
                1:numel(valid_global1), 1:numel(valid_global2));
            global_pairs = [valid_global1(idx1(:)), valid_global2(idx2(:))];
            local_pairs = [valid_local1(idx1(:)), valid_local2(idx2(:))];
        else
            global_pairs = zeros(0, 2);
            local_pairs = zeros(0, 2);
        end

        total_possible = numel(rows1) * numel(rows2);

        pair_types(p).index = p;
        pair_types(p).name = sprintf('%s-%s', ...
            area_names{g1}, area_names{g2});
        pair_types(p).group_indices = [g1, g2];
        pair_types(p).area_names = {area_names{g1}, area_names{g2}};
        pair_types(p).is_within_area = false;
        pair_types(p).valid_global_indices_group1 = valid_global1(:)';
        pair_types(p).valid_global_indices_group2 = valid_global2(:)';
        pair_types(p).pair_global_indices = global_pairs;
        pair_types(p).pair_group_local_indices = local_pairs;
        pair_types(p).n_total_possible_pairs = total_possible;
        pair_types(p).n_pairs = size(global_pairs, 1);
        pair_types(p).n_excluded_zero_variance_pairs = ...
            total_possible - size(global_pairs, 1);
    end
end

end


function r_values = computeFixedPairRSCValuesLocal( ...
        z_response, global_kept_indices, pair_definition, condition_id)

if pair_definition.n_pairs == 0
    r_values = zeros(0, 1);
    return;
end

num_trials = size(z_response, 2);
if num_trials < 2
    error(['Condition %d has fewer than two retained trials, so Pearson ', ...
           'correlation cannot be calculated.'], condition_id);
end

max_global_index = max(global_kept_indices);
global_to_zrow = zeros(max_global_index, 1);
global_to_zrow(global_kept_indices) = 1:numel(global_kept_indices);

global1 = pair_definition.valid_global_indices_group1;
global2 = pair_definition.valid_global_indices_group2;
zrow1 = global_to_zrow(global1);
zrow2 = global_to_zrow(global2);

if any(zrow1 == 0) || any(zrow2 == 0)
    error('Fixed pair definition contains a globally excluded neuron.');
end

Z1 = z_response(zrow1, :);
Z2 = z_response(zrow2, :);

if pair_definition.is_within_area
    correlation_matrix = (Z1 * Z1') ./ (num_trials - 1);
    upper_mask = triu(true(size(correlation_matrix)), 1);
    r_values = correlation_matrix(upper_mask);
else
    correlation_matrix = (Z1 * Z2') ./ (num_trials - 1);
    r_values = correlation_matrix(:);
end

if numel(r_values) ~= pair_definition.n_pairs
    error(['Condition %d pair count mismatch for %s: computed %d, ', ...
           'expected %d.'], condition_id, pair_definition.name, ...
        numel(r_values), pair_definition.n_pairs);
end

if any(~isfinite(r_values))
    error('Condition %d produced nonfinite r_sc values for %s.', ...
        condition_id, pair_definition.name);
end

numerical_tolerance = 1e-10;
if any(r_values < -1 - numerical_tolerance) || ...
        any(r_values > 1 + numerical_tolerance)
    error('Condition %d produced r_sc outside [-1,1] for %s.', ...
        condition_id, pair_definition.name);
end
r_values = min(max(r_values, -1), 1);

end


function fig_handle = plotRSCConditionSummaryLocal( ...
        mean_rsc, sd_rsc, condition_map, pair_types, condition_colors, ...
        condition_group_width, direction_x_offset, marker_size, ...
        font_name, font_size, figure_visible, stim_tag)

num_pair_types = numel(pair_types);
num_panel_conditions = numel(condition_map.meta.panelCondShortLabels);
num_directions = numel(condition_map.meta.stimDirValues);

if num_panel_conditions ~= 8 || num_directions ~= 2
    error(['The requested condition-mode plot requires 8 base conditions ', ...
           'and 2 directions.']);
end

condition_lookup = nan(num_panel_conditions, num_directions);
for k = 1:numel(condition_map.entries)
    entry = condition_map.entries(k);
    if ~isnan(condition_lookup(entry.panelCondIndex, entry.stimDirCode))
        error('Duplicate condition mapping for %s, direction code %d.', ...
            entry.panelCondShortLabel, entry.stimDirCode);
    end
    condition_lookup(entry.panelCondIndex, entry.stimDirCode) = ...
        entry.conditionId;
end
if any(isnan(condition_lookup(:)))
    error('Condition map is incomplete for the 8 conditions x 2 directions plot.');
end

fig_handle = figure( ...
    'Color', 'w', ...
    'Visible', figure_visible, ...
    'Position', [100, 100, 1500, 760], ...
    'Name', 'r_sc by condition');

tl = tiledlayout(fig_handle, 1, 2, ...
    'Padding', 'compact', 'TileSpacing', 'compact');
ax_mean = nexttile(tl, 1);
ax_sd = nexttile(tl, 2);

hold(ax_mean, 'on');
hold(ax_sd, 'on');

x_base = 1:num_pair_types;
condition_spacing = condition_group_width / num_panel_conditions;
condition_offsets = ...
    ((1:num_panel_conditions) - (num_panel_conditions + 1) / 2) * ...
    condition_spacing;
direction_offsets = [-direction_x_offset, direction_x_offset];

if direction_x_offset >= condition_spacing / 2
    error(['direction_x_offset must be smaller than half the spacing ', ...
           'between adjacent condition positions (currently %.6g).'], ...
        condition_spacing / 2);
end

for base_idx = 1:num_panel_conditions
    this_color = condition_colors(base_idx, :);

    for dir_idx = 1:num_directions
        condition_id = condition_lookup(base_idx, dir_idx);
        x_values = x_base + condition_offsets(base_idx) + ...
            direction_offsets(dir_idx);

        scatter(ax_mean, x_values, mean_rsc(condition_id, :), ...
            marker_size, ...
            'o', ...
            'MarkerEdgeColor', this_color, ...
            'MarkerFaceColor', this_color, ...
            'LineWidth', 1.15, ...
            'HandleVisibility', 'off');

        scatter(ax_sd, x_values, sd_rsc(condition_id, :), ...
            marker_size, ...
            'o', ...
            'MarkerEdgeColor', this_color, ...
            'MarkerFaceColor', this_color, ...
            'LineWidth', 1.15, ...
            'HandleVisibility', 'off');
    end
end

yline(ax_mean, 0, ':', 'Color', [0.45, 0.45, 0.45], ...
    'LineWidth', 0.8, 'HandleVisibility', 'off');

pair_names = {pair_types.name};
formatRSCAxisLocal(ax_mean, pair_names, ...
    'Mean r_{sc}', 'Mean of r_{sc} distribution', ...
    font_name, font_size);
formatRSCAxisLocal(ax_sd, pair_names, ...
    'SD of r_{sc}', 'SD of r_{sc} distribution', ...
    font_name, font_size);

legend_handles = gobjects(1, num_panel_conditions);
legend_labels = cell(1, num_panel_conditions);

for base_idx = 1:num_panel_conditions
    legend_handles(base_idx) = scatter(ax_mean, nan, nan, marker_size, 'o', ...
        'MarkerEdgeColor', condition_colors(base_idx, :), ...
        'MarkerFaceColor', condition_colors(base_idx, :), ...
        'LineWidth', 1.15);
    legend_labels{base_idx} = condition_map.meta.panelCondShortLabels{base_idx};
end

lgd = legend(ax_mean, legend_handles, legend_labels, ...
    'Location', 'southoutside', ...
    'Orientation', 'horizontal', ...
    'NumColumns', 4, ...
    'Box', 'off', ...
    'FontName', font_name, ...
    'FontSize', font_size - 1, ...
    'Interpreter', 'none');
lgd.Layout.Tile = 'south';

sgtitle(tl, sprintf('Noise correlation by condition | %s', stim_tag), ...
    'Interpreter', 'none', 'FontName', font_name, 'FontSize', font_size + 1);

end


function formatRSCAxisLocal(ax, pair_names, y_label, panel_title, ...
        font_name, font_size)

num_pairs = numel(pair_names);
set(ax, ...
    'XLim', [0.5, num_pairs + 0.5], ...
    'XTick', 1:num_pairs, ...
    'XTickLabel', pair_names, ...
    'TickLabelInterpreter', 'none', ...
    'FontName', font_name, ...
    'FontSize', font_size, ...
    'LineWidth', 1, ...
    'Box', 'on', ...
    'YGrid', 'on', ...
    'XGrid', 'off', ...
    'GridAlpha', 0.16);
xlabel(ax, 'Neuron-pair type', ...
    'FontName', font_name, 'FontSize', font_size);
ylabel(ax, y_label, ...
    'Interpreter', 'tex', 'FontName', font_name, 'FontSize', font_size);
title(ax, panel_title, ...
    'FontName', font_name, 'FontSize', font_size + 1);

end


function condition_map = buildConditionSummaryMapLocal( ...
        condition_full, condition_list)

if isempty(condition_full)
    error('condition_full is empty.');
end

n_all = numel(condition_full);
stim_name_all = strings(n_all, 1);
size_all = nan(n_all, 1);
contrast_all = nan(n_all, 1);
effective_direction_all = nan(n_all, 1);

for k = 1:n_all
    if ~isfield(condition_full(k), 'stim_name')
        error('condition_full(%d) missing field stim_name.', k);
    end
    if ~isfield(condition_full(k), 'size')
        error('condition_full(%d) missing field size.', k);
    end
    if ~isfield(condition_full(k), 'contrast')
        error('condition_full(%d) missing field contrast.', k);
    end

    current_stim = lower(string(condition_full(k).stim_name));
    stim_name_all(k) = current_stim;
    size_all(k) = condition_full(k).size;
    contrast_all(k) = condition_full(k).contrast;
    effective_direction_all(k) = ...
        getConditionEffectiveDirectionCanonicalLocal(condition_full(k), k);
end

all_stim = lower(unique(stim_name_all, 'stable'));
if all(ismember(["grating", "plaid"], all_stim))
    stim_labels = ["grating", "plaid"];
else
    if numel(all_stim) ~= 2
        error('Expected exactly 2 stimulus levels in condition_full.');
    end
    stim_labels = all_stim(:)';
end

size_values = sort(unique(size_all(:))');
if numel(size_values) ~= 2
    error('Expected exactly 2 size levels in condition_full.');
end

contrast_values_by_stim = struct();
for s = 1:2
    idx = (stim_name_all == stim_labels(s));
    contrast_values = sort(unique(contrast_all(idx))');
    if numel(contrast_values) ~= 2
        error('Stimulus %s does not have exactly 2 contrast levels.', ...
            char(stim_labels(s)));
    end
    contrast_values_by_stim.(char(stim_labels(s))) = contrast_values;
end

direction_values = unique(effective_direction_all( ...
    isfinite(effective_direction_all)));
direction_values = sort(direction_values(:)');
if numel(direction_values) ~= 2
    error(['Expected exactly 2 effective canonical direction values in ', ...
           'condition_full; found %d: %s.'], ...
        numel(direction_values), mat2str(direction_values));
end

direction_labels = {'stim_dir1', 'stim_dir2'};
condition_long_labels = { ...
    'grating-small-low', 'grating-small-high', ...
    'grating-large-low', 'grating-large-high', ...
    'plaid-small-low', 'plaid-small-high', ...
    'plaid-large-low', 'plaid-large-high'};
condition_short_labels = { ...
    'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
    'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};

entries = struct([]);
for ii = 1:numel(condition_list)
    condition_id = condition_list(ii);
    if condition_id < 1 || condition_id > n_all
        error('Condition ID %d is outside condition_full range.', condition_id);
    end

    current_stim = lower(string(condition_full(condition_id).stim_name));
    current_size = condition_full(condition_id).size;
    current_contrast = condition_full(condition_id).contrast;
    current_direction = getConditionEffectiveDirectionCanonicalLocal( ...
        condition_full(condition_id), condition_id);

    stim_code = find(strcmp(cellstr(stim_labels), char(current_stim)), 1);
    size_code = find(abs(size_values - current_size) < 1e-10, 1);
    current_contrast_levels = ...
        contrast_values_by_stim.(char(current_stim));
    contrast_code = find(abs(current_contrast_levels - current_contrast) < 1e-10, 1);
    direction_code = find(abs(direction_values - current_direction) < 1e-10, 1);

    if isempty(stim_code) || isempty(size_code) || ...
            isempty(contrast_code) || isempty(direction_code)
        error('Could not map condition ID %d into the requested condition grid.', ...
            condition_id);
    end

    panel_index = (stim_code - 1) * 4 + ...
        (size_code - 1) * 2 + contrast_code;

    entries(ii).conditionId = condition_id;
    entries(ii).stimName = char(current_stim);
    entries(ii).stimCode = stim_code;
    entries(ii).sizeValue = current_size;
    entries(ii).sizeCode = size_code;
    entries(ii).sizeLabel = ternaryLabelLocal(size_code, 'small', 'large');
    entries(ii).contrastValue = current_contrast;
    entries(ii).contrastCode = contrast_code;
    entries(ii).contrastLabel = ternaryLabelLocal(contrast_code, 'low', 'high');
    entries(ii).stimDirValue = current_direction;
    entries(ii).stimDirCode = direction_code;
    entries(ii).stimDirLabel = direction_labels{direction_code};
    entries(ii).panelCondIndex = panel_index;
    entries(ii).panelCondLabel = condition_long_labels{panel_index};
    entries(ii).panelCondShortLabel = condition_short_labels{panel_index};
end

condition_map = struct();
condition_map.entries = entries;
condition_map.meta.stimLabels = cellstr(stim_labels);
condition_map.meta.sizeValues = size_values;
condition_map.meta.contrastValuesByStim = contrast_values_by_stim;
condition_map.meta.stimDirLabels = direction_labels;
condition_map.meta.stimDirValues = direction_values;
condition_map.meta.panelCondLabels = condition_long_labels;
condition_map.meta.panelCondShortLabels = condition_short_labels;

end


function validateCompleteConditionMapLocal(condition_map, num_conditions)

if numel(condition_map.entries) ~= num_conditions
    error('Condition-map entry count does not match the number of conditions.');
end

lookup = zeros(8, 2);
for k = 1:numel(condition_map.entries)
    entry = condition_map.entries(k);
    if lookup(entry.panelCondIndex, entry.stimDirCode) ~= 0
        error('Duplicate 8-condition x 2-direction mapping at condition %d.', ...
            entry.conditionId);
    end
    lookup(entry.panelCondIndex, entry.stimDirCode) = entry.conditionId;
end

if any(lookup(:) == 0)
    error(['conditions_full does not contain exactly one condition for every ', ...
           'combination of 8 base conditions x 2 directions.']);
end

end


function direction = getConditionEffectiveDirectionCanonicalLocal( ...
        condition_entry, condition_id)

if ~isfield(condition_entry, 'stim_name')
    error('condition_full(%d) missing field stim_name.', condition_id);
end

current_stim = lower(string(condition_entry.stim_name));
if current_stim == "grating"
    if ~isfield(condition_entry, 'grating_dir')
        error('condition_full(%d) is grating but missing grating_dir.', ...
            condition_id);
    end
    direction = condition_entry.grating_dir;
elseif current_stim == "plaid"
    if ~isfield(condition_entry, 'plaid_dir')
        error('condition_full(%d) is plaid but missing plaid_dir.', ...
            condition_id);
    end
    direction = condition_entry.plaid_dir;
else
    error('Unsupported stim_name in condition_full(%d): %s', ...
        condition_id, char(current_stim));
end

direction = canonicalAngle360Local(direction);

end


function angle = canonicalAngle360Local(angle)

angle = double(angle);
finite_mask = isfinite(angle);
angle(finite_mask) = mod(angle(finite_mask), 360);

tolerance = 1e-10;
near_integer = finite_mask & abs(angle - round(angle)) < tolerance;
angle(near_integer) = round(angle(near_integer));
angle(finite_mask & abs(angle) < tolerance) = 0;
angle(finite_mask & abs(angle - 360) < tolerance) = 0;

end


function label = ternaryLabelLocal(code, label_1, label_2)

if code == 1
    label = label_1;
else
    label = label_2;
end

end


function text_value = formatSummaryValueLocal(value)

if ~isscalar(value) || ~isfinite(value)
    text_value = 'NaN';
elseif abs(value - round(value)) < 1e-10
    text_value = sprintf('%d', round(value));
else
    text_value = sprintf('%.4g', value);
end

end


function output_base = makeAutomaticOutputBaseLocal(stim_tag, area_names)

stim_file_tag = makeSafeFileTagLocal(stim_tag);
area_parts = cell(1, numel(area_names));
for g = 1:numel(area_names)
    area_parts{g} = sprintf('G%02d_%s', g, ...
        makeSafeFileTagLocal(area_names{g}));
end
output_base = sprintf('raw_count_rsc_by_condition_%s_%s', ...
    stim_file_tag, strjoin(area_parts, '_'));

end


function tag = makeSafeFileTagLocal(value)

tag = strtrim(char(string(value)));
tag = regexprep(tag, '[^A-Za-z0-9]+', '_');
tag = regexprep(tag, '^_+|_+$', '');
if isempty(tag)
    tag = 'x';
end

end


function output_base = validateOutputBaseNameLocal(output_base)

output_base = strtrim(char(string(output_base)));
if isempty(output_base)
    error('A nonempty output_base_name was expected.');
end

[folder_part, name_part, extension_part] = fileparts(output_base);
if ~isempty(folder_part)
    error(['output_base_name must be a filename only. Outputs are always ', ...
           'saved beside this program.']);
end
if ~isempty(extension_part)
    error('output_base_name must not contain a file extension.');
end
output_base = name_part;

end


function output = ternaryTextLocal(condition, true_text, false_text)

if condition
    output = true_text;
else
    output = false_text;
end

end
