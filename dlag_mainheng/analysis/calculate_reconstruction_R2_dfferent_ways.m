%% calculate_reconstruction_R2_dfferent_ways.m
% Compute neuron-wise reconstruction R2 using one of two grouping modes:
%   by_stimtype       : grating and plaid (original behavior)
%   by_three_features : stim type x size x contrast (eight groups)
%
% Run this script after data_reconstruction.m has added these fields to the
% corresponding bestmodel*.mat files:
%   seqEst.yRecon_use_all
%   seqEst.yRecon_use_across
%   seqEst.yRecon_use_within
%   seqEst.yRecon_use_feedforward
%   seqEst.yRecon_use_feedback
%
% Two model modes are supported independently of r2_split_mode:
%   1) data_condition = []
%        One all-condition model. Trials in seqEst are assigned to the
%        requested R2 groups by:
%          seqEst.trialId
%          model_data_allruns{run}.condition_index_per_trial_full
%          model_data_allruns{run}.conditions_full
%
%   2) data_condition = 1:16, or another nonempty condition list
%        One condition-specific model per condition. Selected conditions
%        assigned to the same requested R2 group are pooled before one R2
%        is computed.
%
% R2 definition:
%   R2 = 1 - RSS / TSS
%
% For each R2 group, TSS is computed around that group's pooled per-neuron
% mean across all selected trials, time bins, and conditions. In
% by_three_features mode, the two stimulus directions are pooled first;
% directional R2 values are not computed and averaged. R2 is not averaged
% across conditions. Negative R2 values are retained.
%
% Unit IDs are read from the same model_data_allruns entry used to prepare
% the reconstruction data. The saved group_probe and groupd arrays define
% how each probe-level unit-ID vector is split into model groups. No stored
% group/area name is read or compared. For nan_trial_strategy == 6,
% data-content-specific groupd and unit-ID fields are used; otherwise the
% standard groupd and probe unit-ID fields are used.
%
% Output variable:
%   stimtype_recon_R2
% The variable name is retained so existing by_stimtype downstream code and
% previously saved MAT files remain compatible.
%
% Main output fields:
%   by_stimtype:
%       stimtype_recon_R2.grating.<reconstruction>.neuron_by_group
%       stimtype_recon_R2.plaid.<reconstruction>.neuron_by_group
%   by_three_features:
%       stimtype_recon_R2.G_S_L.<reconstruction>.neuron_by_group
%       ... through stimtype_recon_R2.P_L_H
%   stimtype_recon_R2.unit_ids_by_group
%   stimtype_recon_R2.yDims
%
% Output filenames:
%   by_stimtype (original filename retained):
%       <data_content>_<model_mode>_stimtype_R2_<suffix>.mat
%   by_three_features:
%       <data_content>_<model_mode>_stszct_R2_<suffix>.mat
%
% Save location:
%   all_condition_model:
%       ./FA_Dlag_<data_content>/mat_results/runXXX/
%   condition_specific_models:
%       the folder containing this script

clc;
clear;

%% ------------------------------------------------------------------------
% User parameters
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

% Controls how trials/conditions are pooled before calculating R2.
r2_split_mode = 'by_three_features';
% Options:
%   'by_stimtype'       - original grating/plaid grouping
%   'by_three_features' - G-S-L, G-S-H, G-L-L, G-L-H,
%                         P-S-L, P-S-H, P-L-L, P-L-H

% [] uses one all-condition model.
% A nonempty vector uses condition-specific models and pools conditions
% assigned to the same group selected by r2_split_mode.
data_condition = [];
% Example:
% data_condition = 1:16;

runIdx = 1;

% Display/file labels only. Their order must follow the DLAG model-group
% order. These names do not affect trial, neuron, or R2 selection and are
% not compared with any stored group or area names.
group_names = {'V1', 'MT'};

% Metadata used to map trialId to stimulus type and to recover unit IDs in
% the already-defined model-group order.
dat_file = fullfile('.', 'model_data_allruns');
stim_tag = '[Gpl2_2c_2sz_400_2_200isi]';

%% ------------------------------------------------------------------------
% Reconstruction fields included in this analysis
% -------------------------------------------------------------------------

r2_specs = {
    'use_all',         'yRecon_use_all';
    'use_across',      'yRecon_use_across';
    'use_within',      'yRecon_use_within';
    'use_feedforward', 'yRecon_use_feedforward';
    'use_feedback',    'yRecon_use_feedback'
};

reconstruction_suffix = 'all_across_within_ff_fb';

%% ------------------------------------------------------------------------
% Main setup
% -------------------------------------------------------------------------

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

[r2_split_mode, split_file_tag] = ...
    normalizeR2SplitModeLocal(r2_split_mode);

if isempty(data_condition)
    use_condition_mode = false;
    condition_list = [];
    model_mode = 'all_condition_model';
else
    use_condition_mode = true;
    condition_list = double(data_condition(:)');
    model_mode = 'condition_specific_models';

    if any(~isfinite(condition_list)) || ...
            any(condition_list < 1) || ...
            any(condition_list ~= round(condition_list))
        error('data_condition must contain positive integer condition IDs.');
    end

    if numel(unique(condition_list)) ~= numel(condition_list)
        error('data_condition contains duplicate condition IDs.');
    end
end

group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);

output_file_name = sprintf('%s_%s_%s_R2_%s.mat', ...
    data_content, model_mode, split_file_tag, reconstruction_suffix);

fprintf('\n============================================================\n');
fprintf('Grouped reconstruction R2\n');
fprintf('data_content : %s\n', data_content);
fprintf('model_mode   : %s\n', model_mode);
fprintf('split_mode   : %s\n', r2_split_mode);
fprintf('file tag     : %s\n', split_file_tag);
fprintf('runIdx       : %d\n', runIdx);
fprintf('stim_tag     : %s\n', stim_tag);
fprintf('dat_file     : %s\n', dat_file);
fprintf('group labels :\n');
for g = 1:numel(group_names)
    fprintf('  %s\n', group_display_names{g});
end
fprintf('============================================================\n');

%% ------------------------------------------------------------------------
% Load model metadata
% -------------------------------------------------------------------------

Sdata = loadMatFileFlexibleLocal(dat_file, 'model_data_allruns');
if ~isfield(Sdata, 'model_data_allruns')
    error('%s does not contain model_data_allruns.', dat_file);
end

model_data_allruns = Sdata.model_data_allruns;
metadata_run_idx = findRunByStimTagLocal(model_data_allruns, stim_tag);
metadata_run = model_data_allruns{metadata_run_idx};

requireFieldLocal(metadata_run, 'conditions_full', ...
    sprintf('model_data_allruns{%d}', metadata_run_idx));
requireFieldLocal(metadata_run, 'condition_index_per_trial_full', ...
    sprintf('model_data_allruns{%d}', metadata_run_idx));

conditions_full = metadata_run.conditions_full;
condition_index_per_trial_full = ...
    double(metadata_run.condition_index_per_trial_full(:));

if isempty(conditions_full)
    error('conditions_full is empty.');
end
if isempty(condition_index_per_trial_full)
    error('condition_index_per_trial_full is empty.');
end
if any(~isfinite(condition_index_per_trial_full)) || ...
        any(condition_index_per_trial_full < 1) || ...
        any(condition_index_per_trial_full ~= round(condition_index_per_trial_full))
    error('condition_index_per_trial_full contains invalid condition IDs.');
end
if any(condition_index_per_trial_full > numel(conditions_full))
    error('condition_index_per_trial_full references conditions outside conditions_full.');
end

validateAllConditionStimNamesLocal(conditions_full);

[category_definitions, condition_category_fields] = ...
    buildR2CategoriesLocal(conditions_full, r2_split_mode);

category_fields = {category_definitions.field_name};
category_labels = {category_definitions.label};

[unit_ids_by_group, metadata_groupd, metadata_groupd_field] = ...
    getModelUnitIdsByGroupLocal(metadata_run, data_content);

%% ------------------------------------------------------------------------
% Locate model files and build source list
% -------------------------------------------------------------------------

[source_specs, saveDir] = buildSourceSpecsLocal( ...
    data_content, condition_list, use_condition_mode, runIdx, ...
    conditions_full, condition_category_fields, scriptDir);

if ~exist(saveDir, 'dir')
    error('Output directory does not exist: %s', saveDir);
end

outFile = fullfile(saveDir, output_file_name);

fprintf('\nModel sources:\n');
for i = 1:numel(source_specs)
    if isempty(source_specs(i).condition_id)
        fprintf('  all-condition model: %s\n', source_specs(i).best_file);
    else
        fprintf('  condition %d (%s; %s): %s\n', ...
            source_specs(i).condition_id, ...
            source_specs(i).stim_name, ...
            source_specs(i).category_field, ...
            source_specs(i).best_file);
    end
end
fprintf('Output file: %s\n', outFile);

%% ------------------------------------------------------------------------
% Validate all best-model files and establish yDims
% -------------------------------------------------------------------------

yDims_ref = [];

for i = 1:numel(source_specs)
    S = load(source_specs(i).best_file, 'bestModel', 'res', 'seqEst');

    requiredVars = {'bestModel', 'res', 'seqEst'};
    for v = 1:numel(requiredVars)
        if ~isfield(S, requiredVars{v})
            error('File %s is missing variable %s.', ...
                source_specs(i).best_file, requiredVars{v});
        end
    end

    if ~isfield(S.res, 'estParams')
        error('File %s is missing res.estParams.', source_specs(i).best_file);
    end

    yDims = normalizeYDimsLocal(S.res.estParams);

    if isempty(yDims_ref)
        yDims_ref = yDims;
    elseif ~isequal(yDims_ref, yDims)
        error(['The model in %s has yDims %s, whereas the first model has ' ...
            'yDims %s. The neuron populations are not identical.'], ...
            source_specs(i).best_file, mat2str(yDims), mat2str(yDims_ref));
    end

    checkSeqEstFieldsLocal(S.seqEst, r2_specs, sum(yDims));

    if use_condition_mode
        verifyConditionSpecificTrialsLocal( ...
            S.seqEst, source_specs(i).condition_id, ...
            condition_index_per_trial_full, source_specs(i).best_file);
    else
        verifyAllConditionTrialsLocal( ...
            S.seqEst, condition_index_per_trial_full, ...
            conditions_full, source_specs(i).best_file);
    end
end

validateGroupNameCountLocal(group_names, numel(yDims_ref));

if ~isequal(metadata_groupd, yDims_ref)
    error([ ...
        'The model metadata field %s contains group sizes %s, whereas ', ...
        'the reconstruction yDims is %s. Unit IDs cannot be aligned to ', ...
        'the reconstruction rows.'], ...
        metadata_groupd_field, mat2str(metadata_groupd), mat2str(yDims_ref));
end

for g = 1:numel(yDims_ref)
    if numel(unit_ids_by_group{g}) ~= yDims_ref(g)
        error(['%s neuron count mismatch between model_data_allruns ' ...
            'and reconstruction: %d unit IDs versus yDims(%d) = %d.'], ...
            group_display_names{g}, numel(unit_ids_by_group{g}), ...
            g, yDims_ref(g));
    end

    fprintf('  %s | neurons %d\n', ...
        group_display_names{g}, yDims_ref(g));
end

%% ------------------------------------------------------------------------
% Compute every requested R2 group independently
% -------------------------------------------------------------------------

stimtype_recon_R2 = struct();
stimtype_recon_R2.format_version = 'grouped_recon_R2_v2';
stimtype_recon_R2.data_content = data_content;
stimtype_recon_R2.model_mode = model_mode;
stimtype_recon_R2.r2_split_mode = r2_split_mode;
stimtype_recon_R2.split_file_tag = split_file_tag;
stimtype_recon_R2.data_condition = condition_list;
stimtype_recon_R2.runIdx = runIdx;
stimtype_recon_R2.stim_tag = stim_tag;
stimtype_recon_R2.metadata_run_idx = metadata_run_idx;
stimtype_recon_R2.dat_file = resolveMatFileLocal(dat_file);
stimtype_recon_R2.yDims = yDims_ref;
stimtype_recon_R2.group_names = group_names;
stimtype_recon_R2.group_display_names = group_display_names;
stimtype_recon_R2.group_file_tags = group_file_tags;
stimtype_recon_R2.unit_ids_by_group = unit_ids_by_group;
stimtype_recon_R2.unit_id_groupd_source_field = metadata_groupd_field;
stimtype_recon_R2.reconstruction_specs = r2_specs;
stimtype_recon_R2.reconstruction_suffix = reconstruction_suffix;
stimtype_recon_R2.source_files = {source_specs.best_file};
stimtype_recon_R2.category_fields = category_fields;
stimtype_recon_R2.category_labels = category_labels;
stimtype_recon_R2.category_definitions = category_definitions;

for s = 1:numel(category_definitions)
    category_def = category_definitions(s);
    category_field = category_def.field_name;
    category_label = category_def.label;

    fprintf('\n============================================================\n');
    fprintf('Computing pooled %s R2\n', category_label);
    fprintf('============================================================\n');

    [category_result, category_info] = computeOneCategoryR2Local( ...
        source_specs, category_def, use_condition_mode, ...
        condition_index_per_trial_full, ...
        condition_category_fields, ...
        r2_specs, yDims_ref);

    stimtype_recon_R2.(category_field) = category_result;
    stimtype_recon_R2.(category_field).info = category_info;

    fprintf('%s: %d trials, %d concatenated time samples, conditions %s\n', ...
        category_label, category_info.n_trials, ...
        category_info.n_time_samples, ...
        mat2str(category_info.condition_ids));
end

%% ------------------------------------------------------------------------
% Save
% -------------------------------------------------------------------------

fprintf('\nSaving grouped reconstruction R2:\n  %s\n', outFile);
save(outFile, 'stimtype_recon_R2', '-v7.3');
fprintf('Done.\n');

%% ========================================================================
% Local functions
% ========================================================================

function [mode, file_tag] = normalizeR2SplitModeLocal(mode)
    if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
        error('r2_split_mode must be a character vector or string scalar.');
    end

    mode = lower(strtrim(char(mode)));

    switch mode
        case 'by_stimtype'
            file_tag = 'stimtype';

        case 'by_three_features'
            file_tag = 'stszct';

        otherwise
            error(['Unknown r2_split_mode: %s. Valid options are ', ...
                '''by_stimtype'' and ''by_three_features''.'], mode);
    end
end

function [definitions, condition_category_fields] = ...
        buildR2CategoriesLocal(conditions_full, r2_split_mode)

    n_conditions = numel(conditions_full);
    stim_names = cell(n_conditions, 1);

    for condID = 1:n_conditions
        stim_names{condID} = ...
            getConditionStimNameLocal(conditions_full, condID);
    end

    definition_template = struct( ...
        'field_name', '', ...
        'label', '', ...
        'display_name', '', ...
        'stim_name', '', ...
        'size_label', '', ...
        'size_value', NaN, ...
        'contrast_label', '', ...
        'contrast_value', NaN, ...
        'condition_ids', []);

    switch r2_split_mode
        case 'by_stimtype'
            field_names = {'grating', 'plaid'};
            display_names = {'Grating', 'Plaid'};
            definitions = repmat(definition_template, 1, 2);
            condition_category_fields = cell(n_conditions, 1);

            for s = 1:2
                definitions(s).field_name = field_names{s};
                definitions(s).label = field_names{s};
                definitions(s).display_name = display_names{s};
                definitions(s).stim_name = field_names{s};
                definitions(s).condition_ids = ...
                    find(strcmp(stim_names, field_names{s}))';

                if isempty(definitions(s).condition_ids)
                    error('No %s condition exists in conditions_full.', ...
                        field_names{s});
                end
            end

            for condID = 1:n_conditions
                condition_category_fields{condID} = stim_names{condID};
            end

        case 'by_three_features'
            size_all = nan(n_conditions, 1);
            contrast_all = nan(n_conditions, 1);

            for condID = 1:n_conditions
                size_all(condID) = getConditionNumericFieldLocal( ...
                    conditions_full, condID, 'size');
                contrast_all(condID) = getConditionNumericFieldLocal( ...
                    conditions_full, condID, 'contrast');
            end

            stim_order = {'grating', 'plaid'};
            size_levels = sort(unique(size_all(:)'));

            if numel(size_levels) ~= 2
                error(['by_three_features requires exactly two finite ', ...
                    'size levels in conditions_full; found %d: %s.'], ...
                    numel(size_levels), mat2str(size_levels));
            end

            contrast_levels = cell(1, 2);

            for s = 1:2
                stim_mask = strcmp(stim_names, stim_order{s});

                if ~any(stim_mask)
                    error('No %s condition exists in conditions_full.', ...
                        stim_order{s});
                end

                contrast_levels{s} = sort(unique( ...
                    contrast_all(stim_mask)))';

                if numel(contrast_levels{s}) ~= 2
                    error(['by_three_features requires exactly two ', ...
                        'contrast levels for %s; found %d: %s.'], ...
                        stim_order{s}, numel(contrast_levels{s}), ...
                        mat2str(contrast_levels{s}));
                end
            end

            field_names = { ...
                'G_S_L', 'G_S_H', 'G_L_L', 'G_L_H', ...
                'P_S_L', 'P_S_H', 'P_L_L', 'P_L_H'};

            labels = { ...
                'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
                'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};

            display_names = { ...
                'Grating | small | low contrast', ...
                'Grating | small | high contrast', ...
                'Grating | large | low contrast', ...
                'Grating | large | high contrast', ...
                'Plaid | small | low contrast', ...
                'Plaid | small | high contrast', ...
                'Plaid | large | low contrast', ...
                'Plaid | large | high contrast'};

            size_labels = {'small', 'large'};
            contrast_labels = {'low', 'high'};
            definitions = repmat(definition_template, 1, 8);

            for s = 1:2
                for z = 1:2
                    for c = 1:2
                        category_idx = ...
                            (s - 1) * 4 + (z - 1) * 2 + c;

                        definitions(category_idx).field_name = ...
                            field_names{category_idx};
                        definitions(category_idx).label = ...
                            labels{category_idx};
                        definitions(category_idx).display_name = ...
                            display_names{category_idx};
                        definitions(category_idx).stim_name = ...
                            stim_order{s};
                        definitions(category_idx).size_label = ...
                            size_labels{z};
                        definitions(category_idx).size_value = ...
                            size_levels(z);
                        definitions(category_idx).contrast_label = ...
                            contrast_labels{c};
                        definitions(category_idx).contrast_value = ...
                            contrast_levels{s}(c);
                    end
                end
            end

            condition_category_fields = cell(n_conditions, 1);

            for condID = 1:n_conditions
                stim_code = find(strcmp( ...
                    stim_order, stim_names{condID}), 1, 'first');

                if isempty(stim_code)
                    error('Could not map condition %d stimulus type.', ...
                        condID);
                end

                size_code = find( ...
                    size_levels == size_all(condID), 1, 'first');
                contrast_code = find( ...
                    contrast_levels{stim_code} == contrast_all(condID), ...
                    1, 'first');

                if isempty(stim_code) || isempty(size_code) || ...
                        isempty(contrast_code)
                    error('Could not map condition %d to an stszct group.', ...
                        condID);
                end

                category_idx = ...
                    (stim_code - 1) * 4 + ...
                    (size_code - 1) * 2 + contrast_code;
                condition_category_fields{condID} = ...
                    field_names{category_idx};
            end

            for category_idx = 1:numel(definitions)
                definitions(category_idx).condition_ids = find(strcmp( ...
                    condition_category_fields, ...
                    definitions(category_idx).field_name))';

                if isempty(definitions(category_idx).condition_ids)
                    error(['No condition maps to required stszct group ', ...
                        '%s.'], definitions(category_idx).label);
                end
            end

        otherwise
            error('Unknown r2_split_mode: %s.', r2_split_mode);
    end
end

function value = getConditionNumericFieldLocal( ...
    conditions_full, condID, field_name)

    if iscell(conditions_full)
        cond = conditions_full{condID};
    else
        cond = conditions_full(condID);
    end

    if ~isstruct(cond) || ~isfield(cond, field_name)
        error('conditions_full condition %d is missing %s.', ...
            condID, field_name);
    end

    value = cond.(field_name);

    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error(['conditions_full condition %d field %s must be one ', ...
            'finite numeric scalar.'], condID, field_name);
    end

    value = double(value);
end

function [source_specs, saveDir] = buildSourceSpecsLocal( ...
    data_content, condition_list, use_condition_mode, runIdx, ...
    conditions_full, condition_category_fields, scriptDir)

    source_specs = struct( ...
        'condition_id', {}, ...
        'stim_name', {}, ...
        'category_field', {}, ...
        'best_file', {});

    if use_condition_mode
        for i = 1:numel(condition_list)
            condID = condition_list(i);

            if condID > numel(conditions_full)
                error('Condition ID %d exceeds conditions_full length %d.', ...
                    condID, numel(conditions_full));
            end

            stim_name = getConditionStimNameLocal(conditions_full, condID);

            baseDir = ['./FA_Dlag_', data_content, ...
                '_condition', num2str(condID)];
            tempfname = sprintf('%s/mat_results/run%03d', baseDir, runIdx);
            bestFile = findOneFileLocal(tempfname, 'bestmodel*', true);

            source_specs(end+1).condition_id = condID; %#ok<AGROW>
            source_specs(end).stim_name = stim_name;
            source_specs(end).category_field = ...
                condition_category_fields{condID};
            source_specs(end).best_file = bestFile;
        end

        saveDir = scriptDir;
    else
        baseDir = ['./FA_Dlag_', data_content];
        tempfname = sprintf('%s/mat_results/run%03d', baseDir, runIdx);
        bestFile = findOneFileLocal(tempfname, 'bestmodel*', true);

        source_specs(1).condition_id = [];
        source_specs(1).stim_name = 'mixed';
        source_specs(1).category_field = 'mixed';
        source_specs(1).best_file = bestFile;

        saveDir = tempfname;
    end
end

function [category_result, category_info] = computeOneCategoryR2Local( ...
    source_specs, category_def, use_condition_mode, ...
    condition_index_per_trial_full, condition_category_fields, ...
    r2_specs, yDims)

    category_field = category_def.field_name;
    category_label = category_def.label;

    yDim = sum(yDims);
    numGroups = numel(yDims);
    numSpecs = size(r2_specs, 1);

    sumY = cell(numSpecs, 1);
    countY = cell(numSpecs, 1);

    for r = 1:numSpecs
        sumY{r} = zeros(yDim, 1);
        countY{r} = zeros(yDim, 1);
    end

    nTrials = 0;
    nTimeSamples = 0;
    conditionIdsSeen = [];

    % First pass: pooled per-neuron means.
    for i = 1:numel(source_specs)
        S = load(source_specs(i).best_file, 'seqEst');

        [seqSel, condIdsSel] = selectSeqForCategoryLocal( ...
            S.seqEst, source_specs(i), category_field, ...
            use_condition_mode, condition_index_per_trial_full, ...
            condition_category_fields);

        if isempty(seqSel)
            continue;
        end

        Ytrue = [seqSel.y];

        if size(Ytrue, 1) ~= yDim
            error('Ytrue in %s has %d rows; expected %d.', ...
                source_specs(i).best_file, size(Ytrue, 1), yDim);
        end

        nTrials = nTrials + numel(seqSel);
        nTimeSamples = nTimeSamples + size(Ytrue, 2);
        conditionIdsSeen = [conditionIdsSeen, condIdsSel(:)']; %#ok<AGROW>

        for r = 1:numSpecs
            fieldName = r2_specs{r, 2};
            Ypred = [seqSel.(fieldName)];

            if ~isequal(size(Ytrue), size(Ypred))
                error('%s size does not match y in %s.', ...
                    fieldName, source_specs(i).best_file);
            end

            valid = isfinite(Ytrue) & isfinite(Ypred);
            Ytmp = Ytrue;
            Ytmp(~valid) = 0;

            sumY{r} = sumY{r} + sum(Ytmp, 2);
            countY{r} = countY{r} + sum(valid, 2);
        end
    end

    if nTrials == 0
        error(['No trials assigned to %s were found in the selected ', ...
            'model source(s).'], category_label);
    end

    muY = cell(numSpecs, 1);
    for r = 1:numSpecs
        mu = sumY{r} ./ countY{r};
        mu(countY{r} == 0) = NaN;
        muY{r} = mu;
    end

    % Second pass: pooled RSS and TSS.
    RSS = cell(numSpecs, 1);
    TSS = cell(numSpecs, 1);

    for r = 1:numSpecs
        RSS{r} = zeros(yDim, 1);
        TSS{r} = zeros(yDim, 1);
    end

    for i = 1:numel(source_specs)
        S = load(source_specs(i).best_file, 'seqEst');

        seqSel = selectSeqForCategoryLocal( ...
            S.seqEst, source_specs(i), category_field, ...
            use_condition_mode, condition_index_per_trial_full, ...
            condition_category_fields);

        if isempty(seqSel)
            continue;
        end

        Ytrue = [seqSel.y];

        for r = 1:numSpecs
            fieldName = r2_specs{r, 2};
            Ypred = [seqSel.(fieldName)];

            valid = isfinite(Ytrue) & isfinite(Ypred);

            D = Ytrue - repmat(muY{r}, 1, size(Ytrue, 2));
            E = Ytrue - Ypred;

            D(~valid) = 0;
            E(~valid) = 0;

            RSS{r} = RSS{r} + sum(E.^2, 2);
            TSS{r} = TSS{r} + sum(D.^2, 2);
        end
    end

    category_result = struct();

    for r = 1:numSpecs
        r2Name = r2_specs{r, 1};
        rss = RSS{r};
        tss = TSS{r};

        neuronR2 = computeNeuronFromSumsLocal(rss, tss);

        category_result.(r2Name).global_all = ...
            computeGlobalFromSumsLocal(rss, tss);
        category_result.(r2Name).global_by_group = nan(1, numGroups);
        category_result.(r2Name).neuron_by_group = cell(1, numGroups);
        category_result.(r2Name).valid_sample_count_by_group = ...
            cell(1, numGroups);

        for g = 1:numGroups
            rows = getGroupRowsLocal(yDims, g);

            category_result.(r2Name).global_by_group(g) = ...
                computeGlobalFromSumsLocal(rss(rows), tss(rows));
            category_result.(r2Name).neuron_by_group{g} = neuronR2(rows);
            category_result.(r2Name).valid_sample_count_by_group{g} = ...
                countY{r}(rows);
        end
    end

    category_info = struct();
    category_info.field_name = category_field;
    category_info.label = category_label;
    category_info.stim_name = category_def.stim_name;
    category_info.size_label = category_def.size_label;
    category_info.size_value = category_def.size_value;
    category_info.contrast_label = category_def.contrast_label;
    category_info.contrast_value = category_def.contrast_value;
    category_info.condition_ids = unique(conditionIdsSeen, 'stable');
    category_info.n_trials = nTrials;
    category_info.n_time_samples = nTimeSamples;
end

function [seqSel, condIdsSel] = selectSeqForCategoryLocal( ...
    seqEst, source_spec, category_field, use_condition_mode, ...
    condition_index_per_trial_full, condition_category_fields)

    if isempty(seqEst)
        seqSel = seqEst;
        condIdsSel = [];
        return;
    end

    if use_condition_mode
        if strcmp(source_spec.category_field, category_field)
            seqSel = seqEst;
            condIdsSel = repmat(source_spec.condition_id, 1, numel(seqSel));
        else
            seqSel = seqEst([]);
            condIdsSel = [];
        end
        return;
    end

    trialIds = getTrialIdsLocal(seqEst);
    condIds = condition_index_per_trial_full(trialIds);
    trial_category_fields = condition_category_fields(condIds);
    keep = strcmp(trial_category_fields, category_field);

    seqSel = seqEst(keep);
    condIdsSel = condIds(keep);
end

function verifyConditionSpecificTrialsLocal( ...
    seqEst, expectedCondition, condition_index_per_trial_full, sourceFile)

    trialIds = getTrialIdsLocal(seqEst);
    condIds = condition_index_per_trial_full(trialIds);

    if any(condIds ~= expectedCondition)
        bad = unique(condIds(condIds ~= expectedCondition));
        error(['Condition-specific model %s is expected to contain only ' ...
            'condition %d, but trialId metadata also maps to condition(s) %s.'], ...
            sourceFile, expectedCondition, mat2str(bad(:)'));
    end
end

function verifyAllConditionTrialsLocal( ...
    seqEst, condition_index_per_trial_full, conditions_full, sourceFile)

    trialIds = getTrialIdsLocal(seqEst);
    condIds = condition_index_per_trial_full(trialIds);

    for i = 1:numel(condIds)
        stim_name = getConditionStimNameLocal(conditions_full, condIds(i));
        if ~any(strcmp(stim_name, {'grating', 'plaid'}))
            error(['All-condition model %s contains trialId %d mapped to ' ...
                'unsupported stimulus type %s.'], ...
                sourceFile, trialIds(i), stim_name);
        end
    end
end

function trialIds = getTrialIdsLocal(seqEst)
    if isempty(seqEst)
        error('seqEst is empty.');
    end
    if ~isfield(seqEst, 'trialId')
        error(['seqEst is missing trialId. Stimulus type cannot be mapped ' ...
            'without trialId metadata.']);
    end

    trialIds = double(arrayfun(@(s) s.trialId, seqEst));
    trialIds = trialIds(:)';

    if any(~isfinite(trialIds)) || any(trialIds < 1) || ...
            any(trialIds ~= round(trialIds))
        error('seqEst.trialId contains invalid values.');
    end
end

function checkSeqEstFieldsLocal(seqEst, r2_specs, yDim)
    if isempty(seqEst)
        error('seqEst is empty.');
    end
    if ~isfield(seqEst, 'y')
        error('seqEst is missing field y.');
    end

    getTrialIdsLocal(seqEst);

    for n = 1:numel(seqEst)
        if isempty(seqEst(n).y)
            error('seqEst(%d).y is empty.', n);
        end
        if size(seqEst(n).y, 1) ~= yDim
            error('seqEst(%d).y has %d rows; expected %d.', ...
                n, size(seqEst(n).y, 1), yDim);
        end
    end

    for r = 1:size(r2_specs, 1)
        fieldName = r2_specs{r, 2};

        if ~isfield(seqEst, fieldName)
            error(['seqEst is missing reconstruction field %s. Run ' ...
                'data_reconstruction.m with the corresponding option first.'], ...
                fieldName);
        end

        for n = 1:numel(seqEst)
            if isempty(seqEst(n).(fieldName))
                error('seqEst(%d).%s is empty.', n, fieldName);
            end
            if ~isequal(size(seqEst(n).(fieldName)), size(seqEst(n).y))
                error('seqEst(%d).%s size does not match seqEst(%d).y.', ...
                    n, fieldName, n);
            end
        end
    end
end

function [unit_ids_by_group, groupd, groupd_field] = ...
        getModelUnitIdsByGroupLocal(metadata_run, data_content)
% Recover unit IDs in model-group order without using stored area names.
%
% model_data_prepar_with_trialshuffle.m stores one unit-ID vector per
% probe. Within each probe vector, units are concatenated in the same
% model-group order described by group_probe and groupd. Therefore a probe
% containing multiple area groups is split by their saved group sizes.

    requireFieldLocal(metadata_run, 'nan_trial_strategy', 'metadata run');
    requireFieldLocal(metadata_run, 'group_probe', 'metadata run');

    nan_trial_strategy = double(metadata_run.nan_trial_strategy);

    if ~isscalar(nan_trial_strategy) || ~isfinite(nan_trial_strategy)
        error('metadata_run.nan_trial_strategy must be one finite scalar.');
    end

    if nan_trial_strategy == 6
        groupd_field = sprintf('%s_groupd', data_content);
    else
        groupd_field = 'groupd';
    end

    requireFieldLocal(metadata_run, groupd_field, 'metadata run');

    groupd = double(metadata_run.(groupd_field));
    groupd = reshape(groupd, 1, []);

    group_probe = double(metadata_run.group_probe);
    group_probe = reshape(group_probe, 1, []);

    if isempty(groupd)
        error('metadata_run.%s is empty.', groupd_field);
    end

    if numel(group_probe) ~= numel(groupd)
        error([ ...
            'metadata_run.group_probe contains %d entries, whereas ', ...
            'metadata_run.%s contains %d group sizes.'], ...
            numel(group_probe), groupd_field, numel(groupd));
    end

    if any(~isfinite(groupd)) || any(groupd < 1) || ...
            any(groupd ~= round(groupd))
        error('metadata_run.%s must contain positive integer group sizes.', ...
            groupd_field);
    end

    if any(~isfinite(group_probe)) || any(group_probe < 0) || ...
            any(group_probe ~= round(group_probe))
        error('metadata_run.group_probe must contain nonnegative integer probe IDs.');
    end

    nGroups = numel(groupd);
    unit_ids_by_group = cell(1, nGroups);
    unique_probes = unique(group_probe, 'stable');

    for p = 1:numel(unique_probes)
        probe_id = unique_probes(p);

        if nan_trial_strategy == 6
            fieldName = sprintf('%s_probe%d_usedunit_ids', ...
                data_content, probe_id);
        else
            fieldName = sprintf('probe%d_usedunit_ids', probe_id);
        end

        if ~isfield(metadata_run, fieldName)
            error(['model_data_allruns entry is missing required unit-ID ', ...
                'field %s for data_content %s and nan_trial_strategy %g.'], ...
                fieldName, data_content, nan_trial_strategy);
        end

        ids = double(metadata_run.(fieldName));
        ids = ids(:);

        if isempty(ids)
            error('Unit-ID field %s is empty.', fieldName);
        end
        if any(~isfinite(ids))
            error('Unit-ID field %s contains nonfinite values.', fieldName);
        end
        if numel(unique(ids)) ~= numel(ids)
            error('Unit-ID field %s contains duplicate IDs.', fieldName);
        end

        group_indices = find(group_probe == probe_id);
        expected_count = sum(groupd(group_indices));

        if numel(ids) ~= expected_count
            error([ ...
                'Unit-ID field %s contains %d IDs, but model groups %s ', ...
                'assigned to that probe require %d IDs according to %s.'], ...
                fieldName, numel(ids), mat2str(group_indices), ...
                expected_count, groupd_field);
        end

        next_id = 1;

        for k = 1:numel(group_indices)
            g = group_indices(k);
            last_id = next_id + groupd(g) - 1;
            unit_ids_by_group{g} = ids(next_id:last_id);
            next_id = last_id + 1;
        end
    end

    if any(cellfun(@isempty, unit_ids_by_group))
        error('At least one model group did not receive unit IDs.');
    end
end

function validateAllConditionStimNamesLocal(conditions_full)
    for condID = 1:numel(conditions_full)
        stim_name = getConditionStimNameLocal(conditions_full, condID);
        if ~any(strcmp(stim_name, {'grating', 'plaid'}))
            error('Unsupported stim_name in conditions_full(%d): %s', ...
                condID, stim_name);
        end
    end
end

function stim_name = getConditionStimNameLocal(conditions_full, condID)
    if condID < 1 || condID > numel(conditions_full)
        error('Condition ID %d is outside conditions_full.', condID);
    end

    if iscell(conditions_full)
        cond = conditions_full{condID};
    else
        cond = conditions_full(condID);
    end

    if ~isstruct(cond) || ~isfield(cond, 'stim_name')
        error('conditions_full condition %d is missing stim_name.', condID);
    end

    stim_name = lower(strtrim(char(cond.stim_name)));
end

function yDims = normalizeYDimsLocal(params)
    if ~isfield(params, 'yDims') || isempty(params.yDims)
        error('res.estParams is missing yDims.');
    end

    yDims = double(params.yDims(:)');

    if any(~isfinite(yDims)) || any(yDims <= 0) || ...
            any(yDims ~= round(yDims))
        error('res.estParams.yDims must contain positive integers.');
    end
end

function R2 = computeGlobalFromSumsLocal(rss, tss)
    rssTotal = sum(rss(:));
    tssTotal = sum(tss(:));

    if isfinite(rssTotal) && isfinite(tssTotal) && tssTotal > 0
        R2 = 1 - rssTotal / tssTotal;
    else
        R2 = NaN;
    end
end

function R2 = computeNeuronFromSumsLocal(rss, tss)
    R2 = nan(numel(rss), 1);
    valid = isfinite(rss) & isfinite(tss) & tss > 0;
    R2(valid) = 1 - rss(valid) ./ tss(valid);
end

function rows = getGroupRowsLocal(yDims, groupIdx)
    startIdx = sum(yDims(1:groupIdx-1)) + 1;
    rows = startIdx:(startIdx + yDims(groupIdx) - 1);
end

function run_idx = findRunByStimTagLocal(model_data_allruns, stim_tag)
    if ~iscell(model_data_allruns)
        error('model_data_allruns must be a cell array.');
    end

    hits = [];
    for i = 1:numel(model_data_allruns)
        entry = model_data_allruns{i};
        if isempty(entry) || ~isstruct(entry) || ~isfield(entry, 'stim_tag')
            continue;
        end
        if strcmp(entry.stim_tag, stim_tag)
            hits(end+1) = i; %#ok<AGROW>
        end
    end

    if isempty(hits)
        error('stim_tag not found in model_data_allruns: %s', stim_tag);
    end
    if numel(hits) > 1
        error('Duplicate stim_tag found in model_data_allruns: %s', stim_tag);
    end

    run_idx = hits;
end

function requireFieldLocal(S, fieldName, sourceName)
    if ~isfield(S, fieldName)
        error('%s is missing field %s.', sourceName, fieldName);
    end
end

function filePath = resolveMatFileLocal(fileBase)
    if exist(fileBase, 'file') == 2
        filePath = fileBase;
        return;
    end

    if ~endsWith(fileBase, '.mat')
        candidate = [fileBase, '.mat'];
        if exist(candidate, 'file') == 2
            filePath = candidate;
            return;
        end
    end

    error('MAT file not found: %s', fileBase);
end

function S = loadMatFileFlexibleLocal(fileBase, varargin)
    filePath = resolveMatFileLocal(fileBase);
    S = load(filePath, varargin{:});
end

function fname = findOneFileLocal(parentDir, pattern, mustExist)
    if ~exist(parentDir, 'dir')
        error('Directory not found: %s', parentDir);
    end

    files = dir(fullfile(parentDir, pattern));
    files = files(~[files.isdir]);

    if isempty(files)
        if mustExist
            error('No %s file found in %s.', pattern, parentDir);
        else
            fname = '';
            return;
        end
    end

    [~, idx] = sort([files.datenum], 'descend');
    files = files(idx);
    fname = fullfile(parentDir, files(1).name);
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
