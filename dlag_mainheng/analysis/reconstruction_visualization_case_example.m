%% reconstruction_visualization_case_example.m
% Plot a fixed-neuron reconstruction case example for one session.
%
% The loading, trial sorting, condition grouping, condition labels, and
% local/global neuron indexing follow reconstruction_visualization.m.
%
% One heatmap figure is created for each neural group. Each figure contains:
%   rows    = all entries in analysis_fields, in the specified order
%   columns = two user-specified local neuron IDs
%
% All panels within one group share one color scale. Color scales are not
% shared across groups. Condition labels and the "Condition / Trial" axis
% label appear only in the upper-left panel. Each reconstruction label is
% drawn once, to the left of the first-neuron column. The time axis appears
% only in the first-neuron panel for the last reconstruction.
%
% In addition, for the first selected neuron in each group, one trial-average
% figure is created for each condition. Each such figure contains one panel
% per analysis field and uses a common y scale across all of its panels.

clc;
clear;

%% ------------------------------------------------------------------------
% User parameters
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

% [] means pooled all-condition model.
% Example: 1:16 means condition-specific models, one model per condition.
data_condition = [];


% Width of one time bin. For raw_count models, all original and reconstructed
% values are multiplied by 1000/bin_width_ms for display in spikes/s (Hz).
% The value is checked against saved bin_size/bin_centers metadata.
bin_width_ms = 20;

% Display/file labels only. Their order must follow the DLAG model-group
% order. These names do not affect neuron selection and are not compared
% with any stored group or area names.
group_names = {'V1', 'MT'};

% Used to map trialId back to condition and to obtain short labels such as
% G-S-L, G-L-H, P-S-L, etc.
dat_file = fullfile('.', 'model_data_allruns');
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';

% Two LOCAL neuron IDs for each group. Replace these example values with
% the neuron IDs to be shown. The cell order is group 1, group 2, ... .
case_neuron_ids = { ...
    [125 173], ...  % Group 1 
    [36 165]  ...  % Group 2
    };

% Row order for the heatmap and panel order for trial-average figures.
% Any positive number of fields is supported, provided each field exists in
% seqEst and reconstruction_labels contains the same number of entries.
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

% Heatmap color scale. All panels in a group share the percentile-based
% limits below. Each group is scaled independently.
color_percentiles = [1 99];

% Heatmap and condition-guide options.
condition_gap_rows = 1;
draw_condition_boxes = true;
draw_condition_separators = true;
colormap_name = 'parula';

% Figure style.
figure_visible = 'on';
figure_width = 1000;
% Total heatmap height is calculated as this value times the number of
% analysis fields. The default 250 reproduces a height of 1250 for 5 rows
% and gives a height of 1500 for the current 6 rows.
heatmap_row_height_pixels = 250;
font_name = 'Arial';
axis_font_size = 9;
unit_font_size = 11;
reconstruction_font_size = 10;

% Main heatmap layout. The two neuron columns are separated by an explicit
% normalized figure-width gap. Reconstruction labels are figure-level text
% boxes and are drawn only once, to the left of the first neuron column.
layout_outer_position = [0.23 0.065 0.68 0.875];
unit_column_gap = 0.055;
reconstruction_row_gap = 0.012;
reconstruction_label_right = 0.100;
reconstruction_label_width = 0.095;
colorbar_position = [0.935 0.065 0.018 0.875];

% Trial-average figures: first selected neuron of each group, one figure per
% condition, with one panel per analysis field in a single row. Total figure
% width is calculated from trial_average_panel_width_pixels times the number
% of analysis fields.
plot_trial_average = true;
trial_average_error = 'sem';  % 'sem', 'std', or 'none'
trial_average_subfolder = 'trial_average_first_unit';
trial_average_panel_width_pixels = 330;
trial_average_figure_height = 360;
trial_average_line_width = 1.5;
trial_average_shade_color = [0.72 0.72 0.72];
trial_average_shade_alpha = 0.45;
trial_average_y_padding_fraction = 0.06;

% Save switches. SVG is enabled by default for vector-graphics editing.
save_fig = false;
save_svg = true;
save_png = false;
close_after_save = true;
png_dpi = 300;

%% ------------------------------------------------------------------------
% Main setup
% -------------------------------------------------------------------------

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

analysis_fields = normalizeFieldListLocal(analysis_fields);
reconstruction_labels = normalizeLabelListLocal(reconstruction_labels);
group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);

if numel(analysis_fields) ~= numel(reconstruction_labels)
    error(['analysis_fields and reconstruction_labels must have the ', ...
        'same length.']);
end

n_analysis_fields = numel(analysis_fields);

validateattributes(heatmap_row_height_pixels, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'heatmap_row_height_pixels');
validateattributes(trial_average_panel_width_pixels, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'trial_average_panel_width_pixels');

% Preserve approximately the same physical panel size as fields are added
% or removed. No plotting-function edits are needed when the list changes.
figure_height = round(heatmap_row_height_pixels .* n_analysis_fields);
trial_average_figure_width = round( ...
    trial_average_panel_width_pixels .* n_analysis_fields);

validateattributes(bin_width_ms, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'bin_width_ms');

trial_average_error = validatestring( ...
    lower(char(string(trial_average_error))), ...
    {'sem', 'std', 'none'}, mfilename, 'trial_average_error');

if isempty(data_condition)
    use_condition_mode = false;
    condition_list = [];
    modeTag = 'all-condition-model';
else
    use_condition_mode = true;
    condition_list = reshape(data_condition, 1, []);
    modeTag = 'condition-specific-models';
end

fprintf('Reading stimulus metadata from %s\n', dat_file);
Sdata = loadMatFileFlexibleLocal(dat_file, 'model_data_allruns');
if ~isfield(Sdata, 'model_data_allruns')
    error('%s does not contain model_data_allruns.', dat_file);
end

model_data_allruns = Sdata.model_data_allruns;
all_run_tags = getAllRunTagsLocal(model_data_allruns);
run_idx = find(strcmp(all_run_tags, stim_tag));

if isempty(run_idx)
    error('Requested stim_tag not found: %s', stim_tag);
end
if numel(run_idx) > 1
    error('Duplicate stim_tag found: %s', stim_tag);
end

this_run = model_data_allruns{run_idx};

if ~isfield(this_run, 'conditions_full')
    error('model_data_allruns{%d} is missing conditions_full.', run_idx);
end
if ~isfield(this_run, 'condition_index_per_trial_full')
    error('model_data_allruns{%d} is missing condition_index_per_trial_full.', run_idx);
end

condition_full = this_run.conditions_full;
condition_index_per_trial_full = this_run.condition_index_per_trial_full(:);

[response_scale_factor, response_axis_label] = ...
    getResponseDisplayInfoLocal(data_content, bin_width_ms, this_run);

%% ------------------------------------------------------------------------
% Load model data and organize trials into condition blocks
% -------------------------------------------------------------------------

if use_condition_mode
    dataBlocks = repmat(makeEmptyBlockLocal(), 1, numel(condition_list));
    yDims_ref = [];
    condition_labels = getConditionLabelsLocal(condition_full, condition_list);

    for cond_i = 1:numel(condition_list)
        this_condition = condition_list(cond_i);
        baseDir = ['./FA_Dlag_', data_content, '_condition', num2str(this_condition)];
        tempfname = sprintf('%s/mat_results/run%03d', baseDir, runIdx);

        fprintf('\n============================================================\n');
        fprintf('Loading condition-specific model: condition %d\n', this_condition);
        fprintf('Reading from %s\n', tempfname);

        modelData = loadBestModelDataLocal(tempfname);

        if isempty(yDims_ref)
            yDims_ref = modelData.yDims;
        elseif ~isequal(yDims_ref(:)', modelData.yDims(:)')
            error('yDims mismatch between condition-specific models.');
        end

        seqThis = sortSeqByTrialIdLocal(modelData.seqEst);
        warnIfConditionMismatchLocal( ...
            seqThis, this_condition, condition_index_per_trial_full);

        dataBlocks(cond_i).conditionId = this_condition;
        dataBlocks(cond_i).label = condition_labels{cond_i};
        dataBlocks(cond_i).seqEst = seqThis;
        dataBlocks(cond_i).sourceFolder = tempfname;
    end

    yDims = yDims_ref;
    saveDir = scriptDir;
else
    baseDir = ['./FA_Dlag_', data_content];
    tempfname = sprintf('%s/mat_results/run%03d', baseDir, runIdx);

    fprintf('\n============================================================\n');
    fprintf('Loading pooled all-condition model\n');
    fprintf('Reading from %s\n', tempfname);

    modelData = loadBestModelDataLocal(tempfname);
    yDims = modelData.yDims;

    condition_order = getConditionOrderFromSeqLocal( ...
        modelData.seqEst, condition_index_per_trial_full);
    condition_labels = getConditionLabelsLocal(condition_full, condition_order);

    dataBlocks = splitSeqByConditionLocal( ...
        modelData.seqEst, condition_order, condition_labels, ...
        condition_index_per_trial_full);

    saveDir = tempfname;
end

if isempty(yDims) || any(yDims <= 0)
    error('Invalid yDims.');
end

numGroups = numel(yDims);
validateGroupNameCountLocal(group_names, numGroups);
case_neuron_ids = validateCaseNeuronIdsLocal( ...
    case_neuron_ids, yDims, numGroups);

fprintf('\nFields and reconstruction labels:\n');
for f = 1:numel(analysis_fields)
    fprintf('  %-28s -> %s\n', ...
        analysis_fields{f}, reconstruction_labels{f});
end
fprintf('Number of analysis fields: %d\n', n_analysis_fields);
fprintf('Display response label: %s\n', response_axis_label);
fprintf('Bin width: %g ms\n', bin_width_ms);
fprintf('Output folder: %s\n', saveDir);

%% ------------------------------------------------------------------------
% Plot one N-field-by-2 heatmap per group and condition-average figures
% -------------------------------------------------------------------------

if plot_trial_average && (save_fig || save_svg || save_png)
    trialAverageSaveDir = fullfile(saveDir, trial_average_subfolder);
    if ~isfolder(trialAverageSaveDir)
        mkdir(trialAverageSaveDir);
    end
else
    trialAverageSaveDir = saveDir;
end

for groupIdx = 1:numGroups
    selectedLocalNeuronIds = case_neuron_ids{groupIdx};
    groupRows = getGroupRowsLocal(yDims, groupIdx);
    selectedGlobalRows = groupRows(selectedLocalNeuronIds);
    nNeurons = numel(selectedLocalNeuronIds);

    fprintf('\n============================================================\n');
    fprintf('%s: local neuron IDs %s\n', ...
        group_display_names{groupIdx}, mat2str(selectedLocalNeuronIds));

    allVals = collectValuesForColorLimitLocal( ...
        dataBlocks, analysis_fields, selectedGlobalRows);
    allVals = allVals .* response_scale_factor;
    climVals = robustColorLimitsLocal(allVals, color_percentiles);

    fprintf('%s shared color limit across all panels: [%g, %g]\n', ...
        group_display_names{groupIdx}, climVals(1), climVals(2));

    % The area label is included in the MATLAB figure-window name and the
    % saved filename only. It is intentionally not drawn inside the figure.
    figureName = sprintf('%s_case_example_%s_%s_%dneuron', ...
        data_content, modeTag, group_file_tags{groupIdx}, nNeurons);

    fig = plotCaseExampleGroupLocal( ...
        dataBlocks, analysis_fields, reconstruction_labels, ...
        selectedGlobalRows, selectedLocalNeuronIds, figureName, this_run, ...
        climVals, response_scale_factor, response_axis_label, bin_width_ms, ...
        condition_gap_rows, draw_condition_boxes, ...
        draw_condition_separators, colormap_name, figure_visible, ...
        figure_width, figure_height, font_name, axis_font_size, ...
        unit_font_size, reconstruction_font_size, ...
        layout_outer_position, unit_column_gap, reconstruction_row_gap, ...
        reconstruction_label_right, reconstruction_label_width, ...
        colorbar_position);

    fileBase = sanitizeFileNameLocal(figureName);

    if save_fig
        figFile = fullfile(saveDir, [fileBase, '.fig']);
        saveFigLocal(fig, figFile);
        fprintf('Saved FIG: %s\n', figFile);
    end

    if save_svg
        svgFile = fullfile(saveDir, [fileBase, '.svg']);
        saveSvgLocal(fig, svgFile);
        fprintf('Saved SVG: %s\n', svgFile);
    end

    if save_png
        pngFile = fullfile(saveDir, [fileBase, '.png']);
        savePngLocal(fig, pngFile, png_dpi);
        fprintf('Saved PNG: %s\n', pngFile);
    end

    if close_after_save
        close(fig);
    end

    if plot_trial_average
        plotAndSaveTrialAveragesLocal( ...
            dataBlocks, analysis_fields, reconstruction_labels, ...
            selectedGlobalRows(1), selectedLocalNeuronIds(1), ...
            group_file_tags{groupIdx}, data_content, modeTag, this_run, ...
            response_scale_factor, response_axis_label, bin_width_ms, ...
            trial_average_error, figure_visible, ...
            trial_average_figure_width, trial_average_figure_height, ...
            font_name, axis_font_size, trial_average_line_width, ...
            trial_average_shade_color, trial_average_shade_alpha, ...
            trial_average_y_padding_fraction, trialAverageSaveDir, ...
            save_fig, save_svg, save_png, png_dpi, close_after_save);
    end
end

fprintf('\nDone.\n');

%% ========================================================================
% Local functions
% ========================================================================

function fields = normalizeFieldListLocal(fields)
    if ischar(fields)
        fields = {fields};
    elseif isstring(fields)
        fields = cellstr(fields(:));
    elseif iscell(fields)
        fields = fields(:);
        for i = 1:numel(fields)
            if isstring(fields{i})
                fields{i} = char(fields{i});
            end
            if ~ischar(fields{i})
                error('analysis_fields{%d} must be a char or string.', i);
            end
        end
    else
        error('analysis_fields must be a char, string array, or cell array.');
    end

    fields = reshape(fields, 1, []);
    if isempty(fields)
        error('analysis_fields is empty.');
    end

    if numel(unique(fields, 'stable')) ~= numel(fields)
        error('analysis_fields must not contain duplicates.');
    end
end

function labels = normalizeLabelListLocal(labels)
    if ischar(labels)
        labels = {labels};
    elseif isstring(labels)
        labels = cellstr(labels(:));
    elseif iscell(labels)
        labels = labels(:);
        for i = 1:numel(labels)
            if isstring(labels{i})
                labels{i} = char(labels{i});
            end
            if ~ischar(labels{i})
                error(['reconstruction_labels{%d} must be a char or ', ...
                    'string.'], i);
            end
        end
    else
        error(['reconstruction_labels must be a char, string array, ', ...
            'or cell array.']);
    end

    labels = reshape(labels, 1, []);
end

function ids = validateCaseNeuronIdsLocal(ids, yDims, numGroups)
    if ~iscell(ids)
        error('case_neuron_ids must be a cell array with one entry per group.');
    end
    if numel(ids) ~= numGroups
        error(['case_neuron_ids contains %d group entries, but the model has ', ...
            '%d groups.'], numel(ids), numGroups);
    end

    ids = reshape(ids, 1, []);
    for g = 1:numGroups
        thisIds = ids{g};
        if ~isnumeric(thisIds) || ~isvector(thisIds)
            error('case_neuron_ids{%d} must be a numeric vector.', g);
        end

        thisIds = double(reshape(thisIds, 1, []));
        if numel(thisIds) ~= 2
            error(['case_neuron_ids{%d} must contain exactly two local ', ...
                'neuron IDs.'], g);
        end
        if any(~isfinite(thisIds)) || any(thisIds ~= round(thisIds)) || ...
                any(thisIds < 1)
            error('case_neuron_ids{%d} must contain positive integer IDs.', g);
        end
        if numel(unique(thisIds)) ~= numel(thisIds)
            error('case_neuron_ids{%d} contains duplicate neuron IDs.', g);
        end
        if any(thisIds > yDims(g))
            error(['case_neuron_ids{%d} requests neuron %d, but group %d ', ...
                'contains only %d neurons.'], ...
                g, max(thisIds), g, yDims(g));
        end

        ids{g} = thisIds;
    end
end

function block = makeEmptyBlockLocal()
    block = struct();
    block.conditionId = [];
    block.label = '';
    block.seqEst = [];
    block.sourceFolder = '';
end

function modelData = loadBestModelDataLocal(tempfname)
    bestFile = findOneFileLocal(tempfname, 'bestmodel*', true);
    fprintf('Loading best model: %s\n', bestFile);

    Sbest = load(bestFile);
    requiredVars = {'bestModel', 'res', 'seqEst'};

    for i = 1:numel(requiredVars)
        if ~isfield(Sbest, requiredVars{i})
            error('%s is missing variable %s.', bestFile, requiredVars{i});
        end
    end

    seqEst = Sbest.seqEst;
    if isempty(seqEst)
        error('seqEst is empty in %s.', bestFile);
    end

    yDims = getYDimsFromModelLocal( ...
        Sbest.bestModel, Sbest.res, seqEst, bestFile);

    modelData = struct();
    modelData.bestFile = bestFile;
    modelData.seqEst = seqEst;
    modelData.yDims = yDims;
end

function yDims = getYDimsFromModelLocal(bestModel, res, seqEst, sourceName)
    yDims = [];

    if isfield(res, 'estParams') && ...
            isfield(res.estParams, 'yDims') && ...
            ~isempty(res.estParams.yDims)
        yDims = res.estParams.yDims;
    elseif isfield(bestModel, 'yDims') && ~isempty(bestModel.yDims)
        yDims = bestModel.yDims;
    end

    if isempty(yDims)
        error('Could not determine yDims from %s.', sourceName);
    end

    yDims = reshape(double(yDims), 1, []);

    if ~isfield(seqEst, 'y')
        error('seqEst.y is missing in %s.', sourceName);
    end

    yDimObserved = size(seqEst(1).y, 1);
    if sum(yDims) ~= yDimObserved
        error('sum(yDims) = %d but size(seqEst(1).y,1) = %d in %s.', ...
            sum(yDims), yDimObserved, sourceName);
    end
end

function seqOut = sortSeqByTrialIdLocal(seqIn)
    if isempty(seqIn)
        seqOut = seqIn;
        return;
    end

    if isfield(seqIn, 'trialId')
        trialIds = arrayfun(@(s) s.trialId, seqIn);
        [~, ord] = sort(trialIds(:));
        seqOut = seqIn(ord);
    else
        seqOut = seqIn;
    end
end

function warnIfConditionMismatchLocal( ...
    seqEst, expectedCondition, condition_index_per_trial_full)

    if isempty(seqEst) || ~isfield(seqEst, 'trialId')
        warning('seqEst has no trialId. Cannot verify condition-specific trial membership.');
        return;
    end

    trialIds = arrayfun(@(s) s.trialId, seqEst);
    valid = trialIds >= 1 & trialIds <= numel(condition_index_per_trial_full);

    if ~all(valid)
        warning('Some trialId values are outside condition_index_per_trial_full.');
        return;
    end

    condIds = condition_index_per_trial_full(trialIds);
    if any(condIds ~= expectedCondition)
        warning(['Some trials in condition-specific model condition %d map to ', ...
            'different condition IDs according to trialId metadata.'], ...
            expectedCondition);
    end
end

function condition_order = getConditionOrderFromSeqLocal( ...
    seqEst, condition_index_per_trial_full)

    if ~isfield(seqEst, 'trialId')
        error(['seqEst is missing trialId. Cannot sort all-condition trials ', ...
            'by condition. model_data_prepar.m should have created trialId ', ...
            'for each trial.']);
    end

    trialIds = arrayfun(@(s) s.trialId, seqEst);
    if any(trialIds < 1) || ...
            any(trialIds > numel(condition_index_per_trial_full))
        error('Some seqEst trialId values are outside condition_index_per_trial_full.');
    end

    condIds = condition_index_per_trial_full(trialIds);
    condition_order = unique(condIds(:)', 'stable');
    condition_order = sort(condition_order);
end

function dataBlocks = splitSeqByConditionLocal( ...
    seqEst, condition_order, condition_labels, condition_index_per_trial_full)

    dataBlocks = repmat(makeEmptyBlockLocal(), 1, numel(condition_order));
    trialIds = arrayfun(@(s) s.trialId, seqEst);
    condIds = condition_index_per_trial_full(trialIds);

    for i = 1:numel(condition_order)
        c = condition_order(i);
        keep = find(condIds == c);

        if isempty(keep)
            seqThis = seqEst([]);
        else
            [~, ord] = sort(trialIds(keep));
            seqThis = seqEst(keep(ord));
        end

        dataBlocks(i).conditionId = c;
        dataBlocks(i).label = condition_labels{i};
        dataBlocks(i).seqEst = seqThis;
        dataBlocks(i).sourceFolder = '';
    end
end

function vals = collectValuesForColorLimitLocal( ...
    dataBlocks, analysis_fields, selectedRows)

    vals = [];

    for f = 1:numel(analysis_fields)
        fieldName = analysis_fields{f};

        for b = 1:numel(dataBlocks)
            seqEst = dataBlocks(b).seqEst;
            if isempty(seqEst)
                continue;
            end

            checkSeqFieldLocal(seqEst, fieldName, selectedRows);

            for tr = 1:numel(seqEst)
                Y = double(seqEst(tr).(fieldName));
                vals = [vals; reshape(Y(selectedRows, :), [], 1)]; %#ok<AGROW>
            end
        end
    end

    vals = vals(:);
    vals = vals(isfinite(vals));

    if isempty(vals)
        error('No finite values found for color limit computation.');
    end
end

function checkSeqFieldLocal(seqEst, fieldName, selectedRows)
    if ~isfield(seqEst, fieldName)
        error('Field %s is missing from seqEst.', fieldName);
    end

    for tr = 1:numel(seqEst)
        Y = seqEst(tr).(fieldName);

        if ~isnumeric(Y) && ~islogical(Y)
            error('seqEst(%d).%s must be numeric or logical.', tr, fieldName);
        end
        if ndims(Y) ~= 2
            error('seqEst(%d).%s must be a 2-D matrix.', tr, fieldName);
        end
        if max(selectedRows) > size(Y, 1)
            error(['seqEst(%d).%s has only %d rows, but selected row %d ', ...
                'is requested.'], ...
                tr, fieldName, size(Y, 1), max(selectedRows));
        end
    end
end

function climVals = robustColorLimitsLocal(vals, pct)
    vals = vals(:);
    vals = vals(isfinite(vals));

    if isempty(vals)
        error('Cannot compute color limits from empty values.');
    end

    pct = double(pct(:)');
    if numel(pct) ~= 2 || pct(1) < 0 || pct(2) > 100 || pct(1) >= pct(2)
        error(['color_percentiles must be [low high], with ', ...
            '0 <= low < high <= 100.']);
    end

    lo = percentileLocal(vals, pct(1));
    hi = percentileLocal(vals, pct(2));

    if ~isfinite(lo) || ~isfinite(hi)
        lo = min(vals);
        hi = max(vals);
    end

    if lo == hi
        padVal = max(1e-6, abs(lo) * 0.05);
        lo = lo - padVal;
        hi = hi + padVal;
    end

    climVals = [lo hi];
end

function q = percentileLocal(x, p)
    x = sort(x(:));
    x = x(isfinite(x));

    if isempty(x)
        q = NaN;
        return;
    end
    if p <= 0
        q = x(1);
        return;
    end
    if p >= 100
        q = x(end);
        return;
    end

    pos = 1 + (numel(x) - 1) * p / 100;
    lo = floor(pos);
    hi = ceil(pos);

    if lo == hi
        q = x(lo);
    else
        w = pos - lo;
        q = (1 - w) * x(lo) + w * x(hi);
    end
end

function [scaleFactor, axisLabel] = getResponseDisplayInfoLocal( ...
    dataContent, binWidthMs, runMeta)

    dataContent = lower(strtrim(char(string(dataContent))));

    if strcmp(dataContent, 'raw_count')
        checkBinWidthAgainstMetadataLocal(binWidthMs, runMeta);
        scaleFactor = 1000 ./ binWidthMs;
        axisLabel = 'Firing rate (Hz)';
    elseif strcmp(dataContent, 'raw_fr')
        checkBinWidthAgainstMetadataLocal(binWidthMs, runMeta);
        scaleFactor = 1;
        axisLabel = 'Firing rate (Hz)';
    else
        scaleFactor = 1;
        axisLabel = 'Response';
        warning(['data_content is %s rather than raw_count/raw_fr. ', ...
            'Response values will not be converted to firing rate.'], ...
            dataContent);
    end
end

function checkBinWidthAgainstMetadataLocal(binWidthMs, runMeta)
    savedBinWidthMs = [];

    if isfield(runMeta, 'bin_size') && ...
            isnumeric(runMeta.bin_size) && isscalar(runMeta.bin_size) && ...
            isfinite(runMeta.bin_size) && runMeta.bin_size > 0
        savedBinWidthMs = double(runMeta.bin_size) .* 1000;
    elseif isfield(runMeta, 'bin_centers') && ...
            isnumeric(runMeta.bin_centers) && ...
            numel(runMeta.bin_centers) >= 2
        centerDiffMs = diff(double(runMeta.bin_centers(:)')) .* 1000;
        centerDiffMs = centerDiffMs(isfinite(centerDiffMs) & centerDiffMs > 0);
        if ~isempty(centerDiffMs)
            savedBinWidthMs = median(centerDiffMs);
        end
    end

    if isempty(savedBinWidthMs)
        warning(['No valid saved bin_size/bin_centers metadata was found. ', ...
            'Using bin_width_ms = %g.'], binWidthMs);
        return;
    end

    tol = max(1e-6, 1e-6 .* max(abs([binWidthMs, savedBinWidthMs])));
    if abs(binWidthMs - savedBinWidthMs) > tol
        error(['bin_width_ms is %g ms, but the saved metadata indicates ', ...
            '%g ms. Correct bin_width_ms before converting counts to Hz.'], ...
            binWidthMs, savedBinWidthMs);
    end
end

function fig = plotCaseExampleGroupLocal( ...
    dataBlocks, analysisFields, reconstructionLabels, ...
    selectedGlobalRows, selectedLocalNeuronIds, figureName, runMeta, ...
    climVals, responseScaleFactor, responseAxisLabel, binWidthMs, ...
    conditionGapRows, drawConditionBoxes, ...
    drawConditionSeparators, colormapName, figureVisible, ...
    figureWidth, figureHeight, fontName, axisFontSize, ...
    unitFontSize, reconstructionFontSize, ...
    layoutOuterPosition, unitColumnGap, reconstructionRowGap, ...
    reconstructionLabelRight, reconstructionLabelWidth, ...
    colorbarPosition)

    nNeurons = numel(selectedGlobalRows);
    nFields = numel(analysisFields);

    if nNeurons ~= 2
        error('The heatmap layout requires exactly two selected neurons.');
    end

    validateattributes(layoutOuterPosition, {'numeric'}, ...
        {'vector', 'numel', 4, 'real', 'finite'}, ...
        mfilename, 'layout_outer_position');
    validateattributes(unitColumnGap, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, ...
        mfilename, 'unit_column_gap');
    validateattributes(reconstructionRowGap, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, ...
        mfilename, 'reconstruction_row_gap');
    validateattributes(reconstructionLabelRight, {'numeric'}, ...
        {'scalar', 'finite', '>', 0, '<', 1}, ...
        mfilename, 'reconstruction_label_right');
    validateattributes(reconstructionLabelWidth, {'numeric'}, ...
        {'scalar', 'finite', 'positive', '<', reconstructionLabelRight}, ...
        mfilename, 'reconstruction_label_width');
    validateattributes(colorbarPosition, {'numeric'}, ...
        {'vector', 'numel', 4, 'real', 'finite'}, ...
        mfilename, 'colorbar_position');

    plotWidth = layoutOuterPosition(3);
    plotHeight = layoutOuterPosition(4);
    columnWidth = (plotWidth - unitColumnGap) / nNeurons;
    rowHeight = ...
        (plotHeight - (nFields - 1) * reconstructionRowGap) / nFields;

    if columnWidth <= 0 || rowHeight <= 0
        error(['Main heatmap layout has non-positive panel dimensions. ', ...
            'Reduce unit_column_gap or reconstruction_row_gap.']);
    end

    fig = figure( ...
        'Name', figureName, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', figureVisible, ...
        'Position', [100, 100, figureWidth, figureHeight]);

    set(fig, ...
        'DefaultAxesFontName', fontName, ...
        'DefaultTextFontName', fontName);

    lastAx = [];
    axesGrid = gobjects(nFields, nNeurons);
    requestedPositions = nan(nFields, nNeurons, 4);

    for f = 1:nFields
        for n = 1:nNeurons
            fieldName = analysisFields{f};

            panelLeft = layoutOuterPosition(1) + ...
                (n - 1) * (columnWidth + unitColumnGap);
            panelBottom = layoutOuterPosition(2) + ...
                (nFields - f) * (rowHeight + reconstructionRowGap);
            panelPosition = ...
                [panelLeft, panelBottom, columnWidth, rowHeight];

            ax = axes(fig, 'Position', panelPosition); %#ok<LAXES>
            axesGrid(f, n) = ax;
            requestedPositions(f, n, :) = panelPosition;
            lastAx = ax;

            [M, blockInfo] = buildNeuronHeatmapMatrixLocal( ...
                dataBlocks, fieldName, selectedGlobalRows(n), ...
                conditionGapRows);
            M = M .* responseScaleFactor;

            [xValues, xLabelText] = ...
                getTimeAxisLocal(runMeta, size(M, 2), binWidthMs);
            xEdges = estimateXEdgesLocal(xValues);

            h = imagesc(ax, xValues, 1:size(M, 1), M);
            set(h, 'AlphaData', isfinite(M));

            set(ax, ...
                'CLim', climVals, ...
                'Color', [1 1 1], ...
                'YDir', 'reverse');

            applyColormapLocal(ax, colormapName);
            hold(ax, 'on');

            drawConditionGuidesLocal( ...
                ax, blockInfo, xEdges, drawConditionBoxes, ...
                drawConditionSeparators);

            xlim(ax, [xEdges(1), xEdges(end)]);
            ylim(ax, [0.5, size(M, 1) + 0.5]);

            % Unit labels appear once, above the two columns.
            if f == 1
                title(ax, sprintf('Neuron %d', selectedLocalNeuronIds(n)), ...
                    'Interpreter', 'none', ...
                    'FontName', fontName, ...
                    'FontSize', unitFontSize, ...
                    'FontWeight', 'normal');
            end

            % Show time only for first neuron and last reconstruction.
            showTimeAxis = n == 1 && f == nFields;

            if showTimeAxis
                xlabel(ax, xLabelText, ...
                    'Interpreter', 'none', ...
                    'FontName', fontName, ...
                    'FontSize', axisFontSize);
                set(ax, 'XColor', [0 0 0]);
            else
                xlabel(ax, '');
                set(ax, ...
                    'XTick', [], ...
                    'XTickLabel', {}, ...
                    'XColor', 'none');
            end

            % Show condition labels and their axis meaning only in the
            % upper-left panel (Original x first neuron).
            if f == 1 && n == 1
                set(ax, ...
                    'YTick', [blockInfo.centerRow], ...
                    'YTickLabel', {blockInfo.label}, ...
                    'YColor', [0 0 0], ...
                    'TickLabelInterpreter', 'none');
                ylabel(ax, 'Condition / Trial', ...
                    'Interpreter', 'none', ...
                    'FontName', fontName, ...
                    'FontSize', axisFontSize, ...
                    'FontWeight', 'normal');
            else
                ylabel(ax, '');
                set(ax, ...
                    'YTick', [], ...
                    'YTickLabel', {}, ...
                    'YColor', 'none');
            end

            cleanAxisLocal(ax, fontName, axisFontSize);
        end
    end

    % Add one shared colorbar without allowing it to resize only one panel.
    if ~isempty(lastAx) && isgraphics(lastAx)
        cb = colorbar(lastAx);
        cb.Position = colorbarPosition;
        cb.Label.String = responseAxisLabel;
        cb.Label.Interpreter = 'none';
        cb.FontName = fontName;
        cb.FontSize = axisFontSize;
        cb.TickDirection = 'out';
    end

    % Colorbar creation can resize its peer axis. Restore every requested
    % panel position and then add all row labels once beside column 1.
    drawnow;
    for f = 1:nFields
        for n = 1:nNeurons
            axesGrid(f, n).Position = ...
                reshape(requestedPositions(f, n, :), 1, 4);
        end
    end

    addAlignedReconstructionLabelsLocal( ...
        fig, axesGrid(:, 1), reconstructionLabels, ...
        reconstructionLabelRight, reconstructionLabelWidth, ...
        fontName, reconstructionFontSize);
end

function addAlignedReconstructionLabelsLocal( ...
    fig, firstNeuronAxes, reconstructionLabels, labelRight, labelWidth, ...
    fontName, fontSize)

    labelLeft = labelRight - labelWidth;

    for f = 1:numel(firstNeuronAxes)
        ax = firstNeuronAxes(f);
        oldUnits = ax.Units;
        ax.Units = 'normalized';
        axPos = ax.Position;
        ax.Units = oldUnits;

        labelHeight = min(0.05, 0.6 * axPos(4));
        labelBottom = axPos(2) + 0.5 * axPos(4) - 0.5 * labelHeight;

        annotation(fig, 'textbox', ...
            [labelLeft, labelBottom, labelWidth, labelHeight], ...
            'String', reconstructionLabels{f}, ...
            'Interpreter', 'none', ...
            'FontName', fontName, ...
            'FontSize', fontSize, ...
            'FontWeight', 'normal', ...
            'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'middle', ...
            'EdgeColor', 'none', ...
            'Margin', 0, ...
            'FitBoxToText', 'off');
    end
end

function plotAndSaveTrialAveragesLocal( ...
    dataBlocks, analysisFields, reconstructionLabels, ...
    neuronRow, localNeuronId, groupFileTag, dataContent, modeTag, runMeta, ...
    responseScaleFactor, responseAxisLabel, binWidthMs, errorMode, ...
    figureVisible, figureWidth, figureHeight, fontName, axisFontSize, ...
    meanLineWidth, shadeColor, shadeAlpha, yPaddingFraction, saveDir, ...
    saveFig, saveSvg, savePng, pngDpi, closeAfterSave)

    nonEmptyBlocks = find(arrayfun(@(b) ~isempty(b.seqEst), dataBlocks));
    if isempty(nonEmptyBlocks)
        warning('No non-empty conditions are available for trial-average plots.');
        return;
    end

    if numel(nonEmptyBlocks) ~= 16
        warning(['Expected 16 non-empty conditions for trial-average plots, ', ...
            'but found %d. One figure will be made for each available ', ...
            'condition.'], numel(nonEmptyBlocks));
    end

    fprintf(['Creating %d trial-average figures for %s, local neuron %d ', ...
        '(error = %s).\n'], ...
        numel(nonEmptyBlocks), groupFileTag, localNeuronId, errorMode);

    for ii = 1:numel(nonEmptyBlocks)
        b = nonEmptyBlocks(ii);
        block = dataBlocks(b);

        [meanCurves, errorCurves] = buildTrialAverageCurvesLocal( ...
            block.seqEst, analysisFields, neuronRow, ...
            responseScaleFactor, errorMode);

        [xValues, xLabelText] = ...
            getTimeAxisLocal(runMeta, size(meanCurves, 2), binWidthMs);

        conditionId = block.conditionId;
        conditionLabel = char(string(block.label));
        figureName = sprintf( ...
            '%s_trial_average_%s_%s_neuron%d_condition%02d_%s_%s', ...
            dataContent, modeTag, groupFileTag, localNeuronId, ...
            conditionId, conditionLabel, errorMode);

        fig = plotTrialAverageConditionLocal( ...
            meanCurves, errorCurves, xValues, xLabelText, ...
            reconstructionLabels, conditionLabel, figureName, ...
            responseAxisLabel, errorMode, figureVisible, ...
            figureWidth, figureHeight, fontName, axisFontSize, ...
            meanLineWidth, shadeColor, shadeAlpha, yPaddingFraction);

        fileBase = sanitizeFileNameLocal(figureName);

        if saveFig
            figFile = fullfile(saveDir, [fileBase, '.fig']);
            saveFigLocal(fig, figFile);
            fprintf('Saved FIG: %s\n', figFile);
        end

        if saveSvg
            svgFile = fullfile(saveDir, [fileBase, '.svg']);
            saveSvgLocal(fig, svgFile);
            fprintf('Saved SVG: %s\n', svgFile);
        end

        if savePng
            pngFile = fullfile(saveDir, [fileBase, '.png']);
            savePngLocal(fig, pngFile, pngDpi);
            fprintf('Saved PNG: %s\n', pngFile);
        end

        if closeAfterSave
            close(fig);
        end
    end
end

function [meanCurves, errorCurves] = buildTrialAverageCurvesLocal( ...
    seqEst, analysisFields, neuronRow, responseScaleFactor, errorMode)

    if isempty(seqEst)
        error('Cannot compute trial averages from an empty seqEst.');
    end

    nFields = numel(analysisFields);
    Tref = [];
    meanCurves = [];
    errorCurves = [];

    for f = 1:nFields
        fieldName = analysisFields{f};
        checkSeqFieldLocal(seqEst, fieldName, neuronRow);

        nTrials = numel(seqEst);
        T = size(seqEst(1).(fieldName), 2);

        if isempty(Tref)
            Tref = T;
            meanCurves = nan(nFields, Tref);
            errorCurves = nan(nFields, Tref);
        elseif T ~= Tref
            error(['Time length mismatch across fields while computing ', ...
                'trial-average curves.']);
        end

        trialMatrix = nan(nTrials, Tref);
        for tr = 1:nTrials
            Y = double(seqEst(tr).(fieldName));
            if size(Y, 2) ~= Tref
                error('Time length mismatch in seqEst(%d).%s.', tr, fieldName);
            end
            trialMatrix(tr, :) = ...
                Y(neuronRow, :) .* responseScaleFactor;
        end

        [mu, sd, nFinite] = finiteMeanStdLocal(trialMatrix);
        meanCurves(f, :) = mu;

        switch errorMode
            case 'sem'
                errorCurves(f, :) = sd ./ sqrt(nFinite);
                errorCurves(f, nFinite < 2) = NaN;
            case 'std'
                errorCurves(f, :) = sd;
            case 'none'
                errorCurves(f, :) = zeros(1, Tref);
            otherwise
                error('Unsupported trial-average error mode: %s', errorMode);
        end
    end
end

function [mu, sd, nFinite] = finiteMeanStdLocal(X)
    finiteMask = isfinite(X);
    nFinite = sum(finiteMask, 1);

    Xsum = X;
    Xsum(~finiteMask) = 0;
    mu = sum(Xsum, 1) ./ nFinite;
    mu(nFinite == 0) = NaN;

    centered = bsxfun(@minus, X, mu);
    centered(~finiteMask) = 0;
    denom = max(nFinite - 1, 1);
    sd = sqrt(sum(centered .^ 2, 1) ./ denom);
    sd(nFinite < 2) = NaN;
end

function fig = plotTrialAverageConditionLocal( ...
    meanCurves, errorCurves, xValues, xLabelText, ...
    reconstructionLabels, conditionLabel, figureName, ...
    responseAxisLabel, errorMode, figureVisible, ...
    figureWidth, figureHeight, fontName, axisFontSize, ...
    meanLineWidth, shadeColor, shadeAlpha, yPaddingFraction)

    validateattributes(shadeColor, {'numeric'}, ...
        {'vector', 'numel', 3, 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'trial_average_shade_color');
    validateattributes(shadeAlpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, ...
        mfilename, 'trial_average_shade_alpha');
    validateattributes(yPaddingFraction, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, ...
        mfilename, 'trial_average_y_padding_fraction');

    nFields = size(meanCurves, 1);
    if numel(reconstructionLabels) ~= nFields || ...
            ~isequal(size(errorCurves), size(meanCurves))
        error('Trial-average curve arrays and reconstruction labels disagree.');
    end

    lowerCurves = meanCurves - errorCurves;
    upperCurves = meanCurves + errorCurves;
    yLimits = sharedCurveYLimitsLocal( ...
        meanCurves, lowerCurves, upperCurves, yPaddingFraction);
    xEdges = estimateXEdgesLocal(xValues);

    fig = figure( ...
        'Name', figureName, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', figureVisible, ...
        'Position', [100, 100, figureWidth, figureHeight]);

    set(fig, ...
        'DefaultAxesFontName', fontName, ...
        'DefaultTextFontName', fontName);

    t = tiledlayout(fig, 1, nFields, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    axesList = gobjects(1, nFields);

    for f = 1:nFields
        ax = nexttile(t, f);
        axesList(f) = ax;
        hold(ax, 'on');

        mu = meanCurves(f, :);
        err = errorCurves(f, :);

        if ~strcmp(errorMode, 'none')
            drawShadedErrorLocal( ...
                ax, xValues, mu, err, shadeColor, shadeAlpha);
        end

        plot(ax, xValues, mu, '-', ...
            'Color', [0 0 0], ...
            'LineWidth', meanLineWidth, ...
            'HandleVisibility', 'off');

        xlim(ax, [xEdges(1), xEdges(end)]);
        ylim(ax, yLimits);

        title(ax, {conditionLabel; reconstructionLabels{f}}, ...
            'Interpreter', 'none', ...
            'FontName', fontName, ...
            'FontSize', axisFontSize + 1, ...
            'FontWeight', 'normal');

        if f > 1
            set(ax, 'YTickLabel', {});
        end

        cleanAxisLocal(ax, fontName, axisFontSize);
    end

    try
        xlabel(t, xLabelText, ...
            'Interpreter', 'none', ...
            'FontName', fontName, ...
            'FontSize', axisFontSize);
        ylabel(t, responseAxisLabel, ...
            'Interpreter', 'none', ...
            'FontName', fontName, ...
            'FontSize', axisFontSize);
    catch
        xlabel(axesList(ceil(nFields / 2)), xLabelText, ...
            'Interpreter', 'none', ...
            'FontName', fontName, ...
            'FontSize', axisFontSize);
        ylabel(axesList(1), responseAxisLabel, ...
            'Interpreter', 'none', ...
            'FontName', fontName, ...
            'FontSize', axisFontSize);
    end
end

function drawShadedErrorLocal(ax, xValues, mu, err, shadeColor, shadeAlpha)
    lowerBand = mu - err;
    upperBand = mu + err;
    valid = isfinite(xValues) & isfinite(lowerBand) & isfinite(upperBand);

    if ~any(valid)
        return;
    end

    xv = xValues(valid);
    lo = lowerBand(valid);
    hi = upperBand(valid);

    fill(ax, [xv, fliplr(xv)], [lo, fliplr(hi)], shadeColor, ...
        'FaceAlpha', shadeAlpha, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
end

function yLimits = sharedCurveYLimitsLocal( ...
    meanCurves, lowerCurves, upperCurves, paddingFraction)

    vals = [meanCurves(:); lowerCurves(:); upperCurves(:); 0];
    vals = vals(isfinite(vals));

    if isempty(vals)
        error('No finite values found for trial-average y limits.');
    end

    lo = min(vals);
    hi = max(vals);

    if lo == hi
        padValue = max(1, abs(lo) .* 0.05);
    else
        padValue = (hi - lo) .* paddingFraction;
    end

    yLimits = [lo - padValue, hi + padValue];
end

function [M, blockInfo] = buildNeuronHeatmapMatrixLocal( ...
    dataBlocks, fieldName, neuronRow, gapRows)

    M = [];
    blockInfo = struct( ...
        'conditionId', {}, ...
        'label', {}, ...
        'startRow', {}, ...
        'endRow', {}, ...
        'centerRow', {}, ...
        'nTrials', {});

    Tref = [];
    nonEmptyBlocks = find(arrayfun(@(b) ~isempty(b.seqEst), dataBlocks));

    if isempty(nonEmptyBlocks)
        error('No non-empty condition blocks found.');
    end

    for ii = 1:numel(nonEmptyBlocks)
        b = nonEmptyBlocks(ii);
        seqEst = dataBlocks(b).seqEst;

        checkSeqFieldLocal(seqEst, fieldName, neuronRow);

        nTrials = numel(seqEst);
        T = size(seqEst(1).(fieldName), 2);

        if isempty(Tref)
            Tref = T;
        elseif T ~= Tref
            error('Time length mismatch while building heatmap for field %s.', ...
                fieldName);
        end

        B = nan(nTrials, Tref);
        for tr = 1:nTrials
            Y = double(seqEst(tr).(fieldName));
            if size(Y, 2) ~= Tref
                error('Time length mismatch in seqEst(%d).%s.', ...
                    tr, fieldName);
            end
            B(tr, :) = Y(neuronRow, :);
        end

        startRow = size(M, 1) + 1;
        M = [M; B]; %#ok<AGROW>
        endRow = size(M, 1);

        blockInfo(end+1).conditionId = dataBlocks(b).conditionId; %#ok<AGROW>
        blockInfo(end).label = dataBlocks(b).label;
        blockInfo(end).startRow = startRow;
        blockInfo(end).endRow = endRow;
        blockInfo(end).centerRow = (startRow + endRow) / 2;
        blockInfo(end).nTrials = nTrials;

        if ii < numel(nonEmptyBlocks) && gapRows > 0
            M = [M; nan(gapRows, Tref)]; %#ok<AGROW>
        end
    end

    if isempty(M)
        error('No trials found for field %s.', fieldName);
    end
end

function drawConditionGuidesLocal( ...
    ax, blockInfo, xEdges, drawBoxes, drawSeparators)

    xLeft = xEdges(1);
    xRight = xEdges(end);
    xWidth = xRight - xLeft;

    for b = 1:numel(blockInfo)
        yTop = blockInfo(b).startRow - 0.5;
        yBottom = blockInfo(b).endRow + 0.5;

        if drawBoxes
            rectangle(ax, ...
                'Position', [xLeft, yTop, xWidth, yBottom - yTop], ...
                'EdgeColor', [0.25 0.25 0.25], ...
                'LineWidth', 0.5, ...
                'HandleVisibility', 'off');
        end

        if drawSeparators && b < numel(blockInfo)
            plot(ax, [xLeft, xRight], [yBottom, yBottom], '-', ...
                'Color', [0.25 0.25 0.25], ...
                'LineWidth', 0.5, ...
                'HandleVisibility', 'off');
        end
    end
end

function [xValues, xLabelText] = getTimeAxisLocal(runMeta, T, binWidthMs)
    xLabelText = 'Time (ms)';

    if isfield(runMeta, 'bin_centers') && ...
            isnumeric(runMeta.bin_centers) && ...
            numel(runMeta.bin_centers) == T
        % bin_centers are stored in seconds by processing_to_count_and_fr.
        xValues = double(runMeta.bin_centers(:)') .* 1000;
    elseif isfield(runMeta, 'analysis_window') && ...
            isnumeric(runMeta.analysis_window) && ...
            numel(runMeta.analysis_window) == 2
        startMs = double(runMeta.analysis_window(1)) .* 1000;
        xValues = startMs + ((1:T) - 0.5) .* binWidthMs;
    else
        xValues = ((1:T) - 0.5) .* binWidthMs;
    end
end

function xEdges = estimateXEdgesLocal(xValues)
    xValues = double(xValues(:)');

    if numel(xValues) == 1
        xEdges = [xValues(1) - 0.5, xValues(1) + 0.5];
        return;
    end

    dx = diff(xValues);
    dx = dx(isfinite(dx) & dx ~= 0);

    if isempty(dx)
        d = 1;
    else
        d = median(abs(dx));
    end

    xEdges = [xValues(1) - d/2, xValues(end) + d/2];
end

function requireFieldLocal(S, fieldName, sourceName)
    if ~isfield(S, fieldName)
        error('%s missing field %s.', sourceName, fieldName);
    end
end

function condition_labels = getConditionLabelsLocal( ...
    condition_full, condition_list)
    % Build short labels such as G-S-L, G-L-H, P-S-L, and P-L-H.
    % This follows reconstruction_visualization.m and intentionally performs
    % no duplicate-label handling.

    if isempty(condition_full)
        error('condition_full is empty.');
    end

    nAll = numel(condition_full);
    stimNameAll = cell(nAll, 1);
    sizeAll = nan(nAll, 1);
    contrastAll = nan(nAll, 1);
    effDirAll = nan(nAll, 1);

    for k = 1:nAll
        requireFieldLocal( ...
            condition_full(k), 'stim_name', sprintf('condition_full(%d)', k));
        requireFieldLocal( ...
            condition_full(k), 'size', sprintf('condition_full(%d)', k));
        requireFieldLocal( ...
            condition_full(k), 'contrast', sprintf('condition_full(%d)', k));

        stimNameAll{k} = lower(char(condition_full(k).stim_name));
        sizeAll(k) = condition_full(k).size;
        contrastAll(k) = condition_full(k).contrast;

        if strcmpi(stimNameAll{k}, 'plaid')
            requireFieldLocal( ...
                condition_full(k), 'plaid_dir', ...
                sprintf('condition_full(%d)', k));
            effDirAll(k) = condition_full(k).plaid_dir;
        elseif strcmpi(stimNameAll{k}, 'grating')
            requireFieldLocal( ...
                condition_full(k), 'grating_dir', ...
                sprintf('condition_full(%d)', k));
            effDirAll(k) = condition_full(k).grating_dir;
        else
            error('Unsupported stim_name in condition_full(%d): %s', ...
                k, stimNameAll{k});
        end
    end

    if any(strcmpi(stimNameAll, 'grating')) && ...
            any(strcmpi(stimNameAll, 'plaid'))
        stimLabels = {'grating', 'plaid'};
    else
        stimLabels = unique(stimNameAll, 'stable');
        if numel(stimLabels) ~= 2
            error('Expected exactly 2 stim levels in condition_full.');
        end
    end

    sizeVals = unique(sizeAll(isfinite(sizeAll)));
    sizeVals = sort(sizeVals);
    sizeVals = sizeVals(:)';

    if numel(sizeVals) ~= 2
        error('Expected exactly 2 size levels in condition_full.');
    end

    contrastValuesByStim = struct();
    for s = 1:numel(stimLabels)
        idx = strcmpi(stimNameAll, stimLabels{s});
        cvals = unique(contrastAll(idx));
        cvals = cvals(isfinite(cvals));
        cvals = sort(cvals);
        cvals = cvals(:)';

        if numel(cvals) ~= 2
            error('Stim %s does not have exactly 2 contrast levels.', ...
                stimLabels{s});
        end
        contrastValuesByStim.(stimLabels{s}) = cvals;
    end

    dirVals = unique(effDirAll(isfinite(effDirAll)));
    dirVals = sort(dirVals);
    dirVals = dirVals(:)';

    if numel(dirVals) ~= 2
        warning('Expected 2 effective direction values, but found %d.', ...
            numel(dirVals));
    end

    condShortLabels = { ...
        'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
        'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};

    condition_labels = cell(1, numel(condition_list));

    for ii = 1:numel(condition_list)
        condID = condition_list(ii);

        if condID < 1 || condID > nAll
            error('Condition ID %d is outside condition_full range.', condID);
        end

        currStim = lower(char(condition_full(condID).stim_name));
        currSize = condition_full(condID).size;
        currContrast = condition_full(condID).contrast;

        stimCode = find(strcmpi(stimLabels, currStim), 1);
        sizeCode = find(sizeVals == currSize, 1);
        currContrastLevels = contrastValuesByStim.(currStim);
        contrastCode = find(currContrastLevels == currContrast, 1);

        if isempty(stimCode) || isempty(sizeCode) || isempty(contrastCode)
            error('Could not map condition ID %d to short label.', condID);
        end

        panelCondIndex = ...
            (stimCode - 1) * 4 + (sizeCode - 1) * 2 + contrastCode;
        condition_labels{ii} = condShortLabels{panelCondIndex};
    end
end

function all_tags = getAllRunTagsLocal(model_data_allruns)
    all_tags = cell(numel(model_data_allruns), 1);

    for j = 1:numel(model_data_allruns)
        if ~isfield(model_data_allruns{j}, 'stim_tag')
            error('stim_tag missing in model_data_allruns{%d}.', j);
        end
        all_tags{j} = model_data_allruns{j}.stim_tag;
    end
end

function rows = getGroupRowsLocal(yDims, groupIdx)
    yDims = reshape(yDims, 1, []);

    if groupIdx < 1 || groupIdx > numel(yDims)
        error('Invalid groupIdx %d.', groupIdx);
    end

    starts = cumsum([1, yDims(1:end-1)]);
    ends = cumsum(yDims);
    rows = starts(groupIdx):ends(groupIdx);
end

function S = loadMatFileFlexibleLocal(fileBase, varargin)
    if exist(fileBase, 'file') == 2
        S = load(fileBase, varargin{:});
        return;
    end

    if ~endsWith(fileBase, '.mat')
        fileMat = [fileBase, '.mat'];
        if exist(fileMat, 'file') == 2
            S = load(fileMat, varargin{:});
            return;
        end
    end

    error('File not found: %s or %s.mat', fileBase, fileBase);
end

function filePath = findOneFileLocal(folderPath, pattern, required)
    if nargin < 3
        required = true;
    end

    if ~isfolder(folderPath)
        if required
            error('Folder not found: %s', folderPath);
        else
            filePath = '';
            return;
        end
    end

    d = dir(fullfile(folderPath, pattern));
    d = d(~[d.isdir]);

    if isempty(d)
        if required
            error('No file matching %s found in %s.', pattern, folderPath);
        else
            filePath = '';
            return;
        end
    end

    if numel(d) > 1
        names = {d.name};
        error('Multiple files matching %s found in %s: %s', ...
            pattern, folderPath, strjoin(names, ', '));
    end

    filePath = fullfile(folderPath, d(1).name);
end

function fileBase = sanitizeFileNameLocal(fileBase)
    badChars = {'/', '\', ':', '*', '?', '"', '<', '>', '|', ' '};

    for i = 1:numel(badChars)
        fileBase = strrep(fileBase, badChars{i}, '_');
    end
end

function saveFigLocal(fig, figFile)
    if exist('savefig', 'file') == 2
        savefig(fig, figFile);
    else
        saveas(fig, figFile);
    end
end

function saveSvgLocal(fig, svgFile)
    drawnow;

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, svgFile, ...
                'ContentType', 'vector', ...
                'BackgroundColor', 'white');
        else
            print(fig, svgFile, '-dsvg');
        end
    catch
        warning('SVG export failed. Falling back to saveas.');
        saveas(fig, svgFile);
    end
end

function savePngLocal(fig, pngFile, dpi)
    drawnow;

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, pngFile, ...
                'Resolution', dpi, ...
                'BackgroundColor', 'white');
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, pngFile, '-dpng', sprintf('-r%d', dpi));
        end
    catch
        warning('PNG export failed. Falling back to saveas.');
        saveas(fig, pngFile);
    end
end

function applyColormapLocal(ax, colormapName)
    try
        cmap = feval(colormapName, 256);
        colormap(ax, cmap);
    catch
        warning('Could not apply colormap %s. Using jet.', colormapName);
        colormap(ax, jet(256));
    end
end

function cleanAxisLocal(ax, fontName, fontSize)
    grid(ax, 'off');
    box(ax, 'off');

    set(ax, ...
        'TickDir', 'out', ...
        'LineWidth', 1, ...
        'FontName', fontName, ...
        'FontSize', fontSize);
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

function validateGroupNameCountLocal(group_names, numGroups)
    if numel(group_names) ~= numGroups
        error([ ...
            'group_names has %d entries, but the current DLAG model ', ...
            'contains %d groups. The order of group_names must follow ', ...
            'the model-group order.'], numel(group_names), numGroups);
    end
end

function [groupDisplayNames, groupFileTags] = ...
        buildGroupLabelsLocal(group_names)
    nGroups = numel(group_names);
    groupDisplayNames = cell(1, nGroups);
    groupFileTags = cell(1, nGroups);

    for g = 1:nGroups
        groupDisplayNames{g} = sprintf('Group %d: %s', g, group_names{g});
        groupFileTags{g} = sprintf( ...
            'G%02d_%s', g, makeSafeGroupNameTagLocal(group_names{g}));
    end
end

function tag = makeSafeGroupNameTagLocal(groupName)
    tag = strtrim(char(string(groupName)));
    tag = regexprep(tag, '[^A-Za-z0-9_-]+', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');

    if isempty(tag)
        tag = 'area';
    end
end
