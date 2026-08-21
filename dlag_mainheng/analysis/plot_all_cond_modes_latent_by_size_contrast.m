%% plot_all_cond_modes_latent_by_size_contrast.m
%
% Plot condition-averaged DLAG latent trajectories in four panels:
%   1) stimulus direction 1, curves colored by size
%   2) stimulus direction 2, curves colored by size
%   3) stimulus direction 1, curves colored by contrast
%   4) stimulus direction 2, curves colored by contrast
%
% Every panel retains all eight stim_name x size x contrast condition
% trajectories. The program changes only the color grouping; it does not
% average together conditions that share the same size or contrast.
%
% One four-panel figure is saved for every group-latent pair. This also
% means that an across-area latent has one figure for each group, so every
% saved figure always contains exactly four panels.
%
% The plotting layout, mean +/- SEM calculation, condition order, direction
% definition, DSL labels, and file-loading conventions follow
% Anova_latents_for_all_conds_used_dlag.m.
%
% Figures are saved under:
% tempfname/latent_condition_analysis_split_by_dir/
%     latent_timecourses_by_size_contrast/

clc;
clear;
close all;

%% ---------------- User parameters --------------------------------------

dat_file = '.\model_data_allruns';

stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';

data_content = 'raw_count';
% options:
% raw_count
% raw_fr
% z_within_trial
% z_within_condition
% z_across_conditions
% demean_count_within_trial
% demean_fr_within_trial
% demean_pooledsd_within_condition

runIdx = 1;

% Display/file labels only. Their order must follow the DLAG model-group
% order. These names do not affect run selection, group/latent selection,
% or any calculation, and they are not compared with stored group names.
group_names = {'V1', 'MT'};

% Red-blue comparison colors. Rows correspond to the two levels in
% ascending numeric order. The SEM shade uses the same color as its mean
% curve with FaceAlpha below, following the reference-program logic.
size_colors = [ ...
    0.00 0.45 0.74; ...  % S: blue
    0.85 0.10 0.10];     % L: red

contrast_colors = [ ...
    0.00 0.45 0.74; ...  % L: blue
    0.85 0.10 0.10];     % H: red

line_width = 1.5;
sem_face_alpha = 0.15;

figure_position = [80 60 1600 1100];
figure_visible = 'on';

save_fig = true;
save_png = true;
export_resolution = 300;

% true  : close each figure after saving
% false : leave generated figures open
close_figure_after_saving = true;

%% ---------------- Load data and model results ---------------------------

fprintf('Reading from %s\n', dat_file);

Sdata = load(dat_file, 'model_data_allruns');

if ~isfield(Sdata, 'model_data_allruns')
    error('The data file does not contain model_data_allruns: %s', dat_file);
end

model_data_allruns = Sdata.model_data_allruns;
all_run_tags = get_all_run_tags_local(model_data_allruns);
run_idx = find(strcmp(all_run_tags, stim_tag));

if isempty(run_idx)
    error('Requested stim_tag not found: %s', stim_tag);
end

if numel(run_idx) > 1
    error('Duplicate stim_tag found: %s', stim_tag);
end

if ~isfield(model_data_allruns{run_idx}, 'conditions_full')
    error('model_data_allruns{%d} is missing conditions_full.', run_idx);
end

condition_full = model_data_allruns{run_idx}.conditions_full;

baseDir = ['./FA_Dlag_', data_content];
tempfname = sprintf('%s/mat_results/run%03d', baseDir, runIdx);

if ~exist(tempfname, 'dir')
    error('DLAG result directory does not exist: %s', tempfname);
end

statsFile = fullfile(tempfname, 'DSL_and_latent_category_stats.mat');

if ~exist(statsFile, 'file')
    error('Required file does not exist: %s', statsFile);
end

Sstats = load( ...
    statsFile, ...
    'DSL', ...
    'bestModel', ...
    'gp_params', ...
    'ambiguousIdxs');

requiredStatsFields = {'DSL', 'bestModel', 'gp_params', 'ambiguousIdxs'};

for field_i = 1:numel(requiredStatsFields)
    thisField = requiredStatsFields{field_i};

    if ~isfield(Sstats, thisField)
        error('The file %s is missing variable %s.', statsFile, thisField);
    end
end

bestFiles = dir(fullfile(tempfname, 'bestmodel*'));
bestFiles = bestFiles(~[bestFiles.isdir]);

if isempty(bestFiles)
    error('No bestmodel* file was found in %s.', tempfname);
end

if numel(bestFiles) > 1
    [~, order] = sort({bestFiles.name});
    bestFiles = bestFiles(order);

    warning( ...
        'Multiple bestmodel* files found. Using %s.', ...
        bestFiles(1).name);
end

bestFile = fullfile(tempfname, bestFiles(1).name);
Sbest = load(bestFile, 'seqEst');

if ~isfield(Sbest, 'seqEst')
    error('The bestmodel file does not contain seqEst: %s', bestFile);
end

seqEst = Sbest.seqEst;
bestModel = Sstats.bestModel;
gp_params = Sstats.gp_params;
ambiguousIdxs = Sstats.ambiguousIdxs;
DSL = Sstats.DSL;

%% ---------------- Validate dimensions and labels ------------------------

if ~isfield(bestModel, 'xDim_across') || ...
        ~isfield(bestModel, 'xDim_within')

    error('bestModel must contain xDim_across and xDim_within.');
end

xDim_across = double(bestModel.xDim_across);
xDim_within = double(bestModel.xDim_within(:)');
numGroups = numel(xDim_within);
localDims = xDim_across + xDim_within;

group_names = normalize_group_names_local(group_names);
validate_group_name_count_local(group_names, numGroups);
[groupDisplayNames, groupFileTags] = ...
    build_group_labels_local(group_names);

validate_dsl_local(DSL, localDims, numGroups);

if isempty(seqEst)
    error('seqEst is empty.');
end

if ~isfield(seqEst, 'xsm')
    error('seqEst is missing xsm.');
end

trialLengths = arrayfun(@(s) size(s.xsm, 2), seqEst);

if any(trialLengths ~= trialLengths(1))
    error('All seqEst trials must have the same number of time bins.');
end

T = trialLengths(1);
tAxis = 1:T;

trialMeta = build_trial_metadata_local(condition_full, seqEst);
acrossCategory = classify_across_latents_local( ...
    gp_params, ...
    ambiguousIdxs, ...
    xDim_across);

[tauAcross, tauWithin] = get_gp_timescales_local( ...
    gp_params, ...
    xDim_across, ...
    xDim_within);

blockStart = cumsum([1, localDims(1:end-1)]);

%% ---------------- Output folder ----------------------------------------

outDir = fullfile( ...
    tempfname, ...
    'latent_condition_analysis_split_by_dir', ...
    'latent_timecourses_by_size_contrast');

ensure_dir_local(outDir);

fprintf('Saving figures to %s\n', outDir);

%% ---------------- Plot every group-latent pair --------------------------

for g = 1:numGroups
    for l = 1:localDims(g)
        rowIdx = blockStart(g) + l - 1;
        X = zeros(numel(seqEst), T);

        for trial_i = 1:numel(seqEst)
            X(trial_i, :) = seqEst(trial_i).xsm(rowIdx, :);
        end

        latentInfo = make_latent_info_local( ...
            g, ...
            group_names{g}, ...
            groupDisplayNames{g}, ...
            groupFileTags{g}, ...
            l, ...
            xDim_across, ...
            acrossCategory, ...
            tauAcross, ...
            tauWithin, ...
            DSL);

        meanTimeByDir = cell(1, 2);
        semTimeByDir = cell(1, 2);

        for d = 1:2
            subsetMask = ...
                trialMeta.valid & ...
                trialMeta.stimDirCode == d;

            [meanTimeByDir{d}, semTimeByDir{d}] = ...
                compute_condition_timecourses_local( ...
                    X, ...
                    trialMeta.condIdx, ...
                    subsetMask, ...
                    8);
        end

        plot_one_group_latent_local( ...
            latentInfo, ...
            meanTimeByDir, ...
            semTimeByDir, ...
            trialMeta, ...
            tAxis, ...
            size_colors, ...
            contrast_colors, ...
            line_width, ...
            sem_face_alpha, ...
            figure_position, ...
            figure_visible, ...
            outDir, ...
            save_fig, ...
            save_png, ...
            export_resolution, ...
            close_figure_after_saving);
    end
end

fprintf('Finished plotting all group-latent pairs.\n');

%% ========================================================================
%% Local functions
%% ========================================================================

function all_tags = get_all_run_tags_local(model_data_allruns)

all_tags = cell(numel(model_data_allruns), 1);

for j = 1:numel(model_data_allruns)
    if ~isfield(model_data_allruns{j}, 'stim_tag')
        error('stim_tag missing in model_data_allruns{%d}.', j);
    end

    all_tags{j} = model_data_allruns{j}.stim_tag;
end

end


function validate_dsl_local(DSL, localDims, numGroups)

requiredFields = { ...
    'logical', ...
    'logical_bystimdir', ...
    'logical_bystimnamedir', ...
    'logical_bycondition'};

if ~isstruct(DSL)
    error('DSL must be a struct.');
end

for field_i = 1:numel(requiredFields)
    thisField = requiredFields{field_i};

    if ~isfield(DSL, thisField)
        error('DSL must contain field DSL.%s.', thisField);
    end

    if ~iscell(DSL.(thisField)) || ...
            numel(DSL.(thisField)) ~= numGroups

        error('DSL.%s must have one cell per group.', thisField);
    end

    for g = 1:numGroups
        if numel(DSL.(thisField){g}) ~= localDims(g)
            error( ...
                ['DSL.%s{%d} length does not match ', ...
                 'xDim_across + xDim_within(%d).'], ...
                thisField, ...
                g, ...
                g);
        end
    end
end

end


function trialMeta = build_trial_metadata_local(condition_full, seqEst)

Ntr = numel(seqEst);

if isfield(seqEst, 'trialId')
    trialId = [seqEst.trialId]';
else
    trialId = (1:Ntr)';
end

stimName = strings(Ntr, 1);
sizeValue = nan(Ntr, 1);
contrastRaw = nan(Ntr, 1);
effectiveDir = nan(Ntr, 1);

for k = 1:numel(condition_full)
    requiredFields = { ...
        'trial_indices', ...
        'stim_name', ...
        'size', ...
        'contrast'};

    for field_i = 1:numel(requiredFields)
        thisField = requiredFields{field_i};

        if ~isfield(condition_full(k), thisField)
            error( ...
                'condition_full(%d) is missing field %s.', ...
                k, ...
                thisField);
        end
    end

    theseIds = condition_full(k).trial_indices(:);
    tf = ismember(trialId, theseIds);
    currStim = lower(string(condition_full(k).stim_name));

    stimName(tf) = currStim;
    sizeValue(tf) = condition_full(k).size;
    contrastRaw(tf) = condition_full(k).contrast;
    effectiveDir(tf) = ...
        get_condition_effective_dir_canonical_local(condition_full(k), k);
end

assigned = ...
    stimName ~= "" & ...
    isfinite(sizeValue) & ...
    isfinite(contrastRaw) & ...
    isfinite(effectiveDir);

if any(~assigned)
    warning( ...
        ['Some seqEst trials could not be assigned completely. ', ...
         'They will be excluded.']);
end

allStim = lower(unique(stimName(assigned), 'stable'));

if all(ismember(["grating", "plaid"], allStim))
    stimLabels = ["grating", "plaid"];
else
    if numel(allStim) ~= 2
        error('Expected exactly two stimulus-name levels.');
    end

    stimLabels = allStim(:)';
end

stimCode = nan(Ntr, 1);

for s = 1:2
    stimCode(stimName == stimLabels(s)) = s;
end

sizeValues = sort(unique(sizeValue(assigned)))';

if numel(sizeValues) ~= 2
    error('Expected exactly two size values.');
end

sizeCode = nan(Ntr, 1);
sizeCode(sizeValue == sizeValues(1)) = 1;
sizeCode(sizeValue == sizeValues(2)) = 2;

contrastCode = nan(Ntr, 1);
contrastValuesByStim = struct();

for s = 1:2
    idx = assigned & stimCode == s;
    contrastValues = sort(unique(contrastRaw(idx)))';

    if numel(contrastValues) ~= 2
        error( ...
            'Stim %s does not have exactly two contrast levels.', ...
            char(stimLabels(s)));
    end

    contrastCode(idx & contrastRaw == contrastValues(1)) = 1;
    contrastCode(idx & contrastRaw == contrastValues(2)) = 2;

    contrastValuesByStim.(char(stimLabels(s))) = contrastValues;
end

dirValues = sort(unique(effectiveDir(assigned)))';

if numel(dirValues) ~= 2
    error( ...
        ['Expected exactly two effective canonical stimulus directions, ', ...
         'found %d: %s.'], ...
        numel(dirValues), ...
        mat2str(dirValues));
end

stimDirCode = nan(Ntr, 1);
tol = max(1e-10, 1e-8 * max(1, max(abs(dirValues))));

stimDirCode(abs(effectiveDir - dirValues(1)) < tol) = 1;
stimDirCode(abs(effectiveDir - dirValues(2)) < tol) = 2;

valid = ...
    assigned & ...
    isfinite(stimCode) & ...
    isfinite(sizeCode) & ...
    isfinite(contrastCode) & ...
    isfinite(stimDirCode);

condIdx = nan(Ntr, 1);
condIdx(valid) = ...
    (stimCode(valid) - 1) * 4 + ...
    (sizeCode(valid) - 1) * 2 + ...
    contrastCode(valid);

trialMeta = struct();
trialMeta.trialId = trialId;
trialMeta.stimName = cellstr(stimName);
trialMeta.stimCode = stimCode;
trialMeta.stimLabels = cellstr(stimLabels);
trialMeta.sizeValue = sizeValue;
trialMeta.sizeCode = sizeCode;
trialMeta.sizeValues = sizeValues;
trialMeta.contrastRaw = contrastRaw;
trialMeta.contrastCode = contrastCode;
trialMeta.contrastValuesByStim = contrastValuesByStim;
trialMeta.effectiveDirValue = effectiveDir;
trialMeta.stimDirCode = stimDirCode;
trialMeta.stimDirLabels = {'stim_dir1', 'stim_dir2'};
trialMeta.stimDirValues = dirValues;
trialMeta.valid = valid;
trialMeta.condIdx = condIdx;
trialMeta.condShortLabels = { ...
    'G-S-L', ...
    'G-S-H', ...
    'G-L-L', ...
    'G-L-H', ...
    'P-S-L', ...
    'P-S-H', ...
    'P-L-L', ...
    'P-L-H'};

% Condition-order lookup used to color the eight retained curves.
trialMeta.conditionSizeCode = [1 1 2 2 1 1 2 2];
trialMeta.conditionContrastCode = [1 2 1 2 1 2 1 2];

end


function acrossCategory = classify_across_latents_local( ...
    gp_params, ...
    ambiguousIdxs, ...
    xDim_across)

if xDim_across == 0
    acrossCategory = cell(1, 0);
    return;
end

if ~isfield(gp_params, 'delays')
    error('gp_params is missing delays.');
end

acrossDelay = reshape(double(gp_params.delays), 1, []);

if numel(acrossDelay) < xDim_across
    error('gp_params.delays has fewer entries than xDim_across.');
end

acrossDelay = acrossDelay(1:xDim_across);

if islogical(ambiguousIdxs)
    if numel(ambiguousIdxs) == xDim_across
        ambiguousIdxs = find(ambiguousIdxs);
    else
        ambiguousIdxs = find(ambiguousIdxs(:));
    end
end

ambiguousIdxs = unique(double(ambiguousIdxs(:)'));
ambiguousIdxs = ambiguousIdxs( ...
    isfinite(ambiguousIdxs) & ...
    ambiguousIdxs == round(ambiguousIdxs) & ...
    ambiguousIdxs >= 1 & ...
    ambiguousIdxs <= xDim_across);

acrossCategory = repmat({''}, 1, xDim_across);

for a = 1:xDim_across
    if ismember(a, ambiguousIdxs) || ...
            ~isfinite(acrossDelay(a)) || ...
            acrossDelay(a) == 0

        acrossCategory{a} = 'ambiguous';
    elseif acrossDelay(a) > 0
        acrossCategory{a} = 'feedforward';
    else
        acrossCategory{a} = 'feedback';
    end
end

end


function [tauAcross, tauWithin] = get_gp_timescales_local( ...
    gp_params, ...
    xDim_across, ...
    xDim_within)

if ~isfield(gp_params, 'tau_across')
    error('gp_params is missing tau_across.');
end

if ~isfield(gp_params, 'tau_within')
    error('gp_params is missing tau_within.');
end

tauAcross = reshape(double(gp_params.tau_across), 1, []);

if numel(tauAcross) < xDim_across
    error('gp_params.tau_across has fewer entries than xDim_across.');
end

tauAcross = tauAcross(1:xDim_across);

if ~iscell(gp_params.tau_within) || ...
        numel(gp_params.tau_within) < numel(xDim_within)

    error('gp_params.tau_within must contain one cell per group.');
end

tauWithin = cell(1, numel(xDim_within));

for g = 1:numel(xDim_within)
    thisTau = reshape(double(gp_params.tau_within{g}), 1, []);

    if numel(thisTau) < xDim_within(g)
        error( ...
            ['gp_params.tau_within{%d} has fewer entries than ', ...
             'xDim_within(%d).'], ...
            g, ...
            g);
    end

    tauWithin{g} = thisTau(1:xDim_within(g));
end

end


function latentInfo = make_latent_info_local( ...
    groupIdx, ...
    groupName, ...
    groupDisplayName, ...
    groupFileTag, ...
    localIdx, ...
    xDim_across, ...
    acrossCategory, ...
    tauAcross, ...
    tauWithin, ...
    DSL)

latentInfo = struct();
latentInfo.groupIndex = groupIdx;
latentInfo.groupName = groupName;
latentInfo.groupDisplayName = groupDisplayName;
latentInfo.groupFileTag = groupFileTag;
latentInfo.localLatentIndex = localIdx;

if localIdx <= xDim_across
    latentInfo.latentType = 'across';
    latentInfo.acrossIndex = localIdx;
    latentInfo.withinIndex = [];
    latentInfo.acrossCategory = acrossCategory{localIdx};
    latentInfo.timescale = tauAcross(localIdx);
    latentInfo.latentLine = sprintf( ...
        'Across latent %d (%s)', ...
        localIdx, ...
        acrossCategory{localIdx});
else
    withinIdx = localIdx - xDim_across;
    latentInfo.latentType = 'within';
    latentInfo.acrossIndex = [];
    latentInfo.withinIndex = withinIdx;
    latentInfo.acrossCategory = '';
    latentInfo.timescale = tauWithin{groupIdx}(withinIdx);
    latentInfo.latentLine = sprintf('Within latent %d', withinIdx);
end

latentInfo.timescaleLine = sprintf( ...
    'Timescale = %s ms', ...
    format_value_local(latentInfo.timescale));

latentInfo.dslLabel = dsl_keep_remove_label_local( ...
    DSL.logical{groupIdx}(localIdx), ...
    'alltrials');

latentInfo.dslByStimDirLabel = dsl_keep_remove_label_local( ...
    DSL.logical_bystimdir{groupIdx}(localIdx), ...
    'bystimdir');

latentInfo.dslByStimNameDirLabel = dsl_keep_remove_label_local( ...
    DSL.logical_bystimnamedir{groupIdx}(localIdx), ...
    'bystimnamedir');

latentInfo.dslByConditionLabel = dsl_keep_remove_label_local( ...
    DSL.logical_bycondition{groupIdx}(localIdx), ...
    'bycondition');

end


function [meanTime, semTime] = compute_condition_timecourses_local( ...
    X, ...
    condIdx, ...
    subsetMask, ...
    nCond)

T = size(X, 2);
meanTime = nan(nCond, T);
semTime = nan(nCond, T);

subsetMask = logical(subsetMask(:));

for c = 1:nCond
    idx = find(subsetMask & condIdx == c);

    if isempty(idx)
        continue;
    end

    Xc = X(idx, :);
    meanTime(c, :) = mean(Xc, 1, 'omitnan');

    if size(Xc, 1) > 1
        semTime(c, :) = ...
            std(Xc, 0, 1, 'omitnan') ./ sqrt(size(Xc, 1));
    else
        semTime(c, :) = zeros(1, T);
    end
end

end


function plot_one_group_latent_local( ...
    latentInfo, ...
    meanTimeByDir, ...
    semTimeByDir, ...
    trialMeta, ...
    tAxis, ...
    sizeColors, ...
    contrastColors, ...
    lineWidth, ...
    semFaceAlpha, ...
    figurePosition, ...
    figureVisible, ...
    outDir, ...
    saveFig, ...
    savePng, ...
    exportResolution, ...
    closeFigureAfterSaving)

if strcmp(latentInfo.latentType, 'across')
    baseName = sanitize_filename_local(sprintf( ...
        '%s_A%03d_%s_by_size_contrast_tc', ...
        latentInfo.groupFileTag, ...
        latentInfo.acrossIndex, ...
        latentInfo.acrossCategory));
else
    baseName = sanitize_filename_local(sprintf( ...
        '%s_W%03d_by_size_contrast_tc', ...
        latentInfo.groupFileTag, ...
        latentInfo.withinIndex));
end

fig = figure( ...
    'Color', 'w', ...
    'Position', figurePosition, ...
    'Visible', figureVisible, ...
    'Name', baseName, ...
    'NumberTitle', 'off');

tl = tiledlayout( ...
    fig, ...
    2, ...
    2, ...
    'Padding', 'compact', ...
    'TileSpacing', 'compact');

for panelIdx = 1:4
    if panelIdx <= 2
        d = panelIdx;
        colorMode = 'size';
        conditionLevelCode = trialMeta.conditionSizeCode;
        colorTable = sizeColors;
        legendLabels = {'S', 'L'};
    else
        d = panelIdx - 2;
        colorMode = 'contrast';
        conditionLevelCode = trialMeta.conditionContrastCode;
        colorTable = contrastColors;
        legendLabels = {'L', 'H'};
    end

    ax = nexttile(tl, panelIdx);
    hold(ax, 'on');

    plot_mean_sem_curves_by_level_local( ...
        ax, ...
        tAxis, ...
        meanTimeByDir{d}, ...
        semTimeByDir{d}, ...
        conditionLevelCode, ...
        colorTable, ...
        lineWidth, ...
        semFaceAlpha);

    dirTitle = sprintf( ...
        '%s = %s', ...
        trialMeta.stimDirLabels{d}, ...
        format_value_local(trialMeta.stimDirValues(d)));

    titleLines = { ...
        sprintf('%s | %s | colored by %s', ...
            latentInfo.groupDisplayName, dirTitle, colorMode), ...
        latentInfo.latentLine, ...
        latentInfo.timescaleLine, ...
        latentInfo.dslLabel, ...
        latentInfo.dslByStimDirLabel, ...
        latentInfo.dslByStimNameDirLabel, ...
        latentInfo.dslByConditionLabel};

    title(ax, titleLines, 'Interpreter', 'none');
    xlabel(ax, 'Time bin');
    ylabel(ax, 'Latent response');
    box(ax, 'off');

    % One compact category legend per row. The trajectories themselves
    % remain the eight original condition curves.
    if panelIdx == 1 || panelIdx == 3
        legendHandles = gobjects(1, 2);

        for levelIdx = 1:2
            legendHandles(levelIdx) = plot( ...
                ax, ...
                NaN, ...
                NaN, ...
                'LineWidth', lineWidth, ...
                'Color', colorTable(levelIdx, :));
        end

        legend( ...
            ax, ...
            legendHandles, ...
            legendLabels, ...
            'Interpreter', 'none', ...
            'Location', 'best', ...
            'Box', 'off');
    end
end

if strcmp(latentInfo.latentType, 'across')
    overallTitle = sprintf( ...
        '%s | Across latent %d | size- and contrast-colored time courses', ...
        latentInfo.groupDisplayName, ...
        latentInfo.acrossIndex);
else
    overallTitle = sprintf( ...
        '%s | Within latent %d | size- and contrast-colored time courses', ...
        latentInfo.groupDisplayName, ...
        latentInfo.withinIndex);
end

sgtitle(tl, overallTitle, 'Interpreter', 'none');

if saveFig
    savefig(fig, fullfile(outDir, [baseName, '.fig']));
end

if savePng
    exportgraphics( ...
        fig, ...
        fullfile(outDir, [baseName, '.png']), ...
        'Resolution', exportResolution);
end

if closeFigureAfterSaving && isgraphics(fig)
    close(fig);
end

end


function plot_mean_sem_curves_by_level_local( ...
    ax, ...
    tAxis, ...
    meanTime, ...
    semTime, ...
    conditionLevelCode, ...
    colorTable, ...
    lineWidth, ...
    semFaceAlpha)

for c = 1:size(meanTime, 1)
    m = meanTime(c, :);
    s = semTime(c, :);

    if all(~isfinite(m))
        continue;
    end

    levelCode = conditionLevelCode(c);

    if ~ismember(levelCode, 1:2)
        error('Condition %d has an invalid color level code.', c);
    end

    thisColor = colorTable(levelCode, :);
    upper = m + s;
    lower = m - s;

    fill( ...
        ax, ...
        [tAxis, fliplr(tAxis)], ...
        [upper, fliplr(lower)], ...
        thisColor, ...
        'FaceAlpha', semFaceAlpha, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off');

    plot( ...
        ax, ...
        tAxis, ...
        m, ...
        'LineWidth', lineWidth, ...
        'Color', thisColor, ...
        'HandleVisibility', 'off');
end

end


function out = dsl_keep_remove_label_local(flag, modeName)

switch lower(modeName)
    case 'alltrials'
        stem = 'DSL';

    case 'bystimdir'
        stem = 'DSL(by stim_dir)';

    case 'bystimnamedir'
        stem = 'DSL(by stim_name x stim_dir)';

    case 'bycondition'
        stem = 'DSL(by condition)';

    otherwise
        error('Unknown DSL mode: %s', modeName);
end

if flag ~= 0
    out = [stem, ' keep'];
else
    out = [stem, ' remove'];
end

end


function d = get_condition_effective_dir_canonical_local(cond, condID)

if ~isfield(cond, 'stim_name')
    error('condition_full(%d) is missing stim_name.', condID);
end

currStim = lower(string(cond.stim_name));

if currStim == "grating"
    if ~isfield(cond, 'grating_dir')
        error( ...
            ['condition_full(%d) is grating but is missing ', ...
             'grating_dir.'], ...
            condID);
    end

    d = cond.grating_dir;
elseif currStim == "plaid"
    if ~isfield(cond, 'plaid_dir')
        error( ...
            ['condition_full(%d) is plaid but is missing ', ...
             'plaid_dir.'], ...
            condID);
    end

    d = cond.plaid_dir;
else
    error( ...
        'Unsupported stim_name in condition_full(%d): %s', ...
        condID, ...
        char(currStim));
end

d = canonical_angle_360_local(d);

end


function a = canonical_angle_360_local(a)

a = double(a);
finiteMask = isfinite(a);
a(finiteMask) = mod(a(finiteMask), 360);

tol = 1e-10;
nearInteger = finiteMask & abs(a - round(a)) < tol;
a(nearInteger) = round(a(nearInteger));
a(finiteMask & abs(a) < tol) = 0;
a(finiteMask & abs(a - 360) < tol) = 0;

end


function s = format_value_local(v)

if ~isfinite(v)
    s = 'NaN';
elseif abs(v - round(v)) < 1e-10
    s = sprintf('%d', round(v));
else
    s = sprintf('%.4g', v);
end

end


function out = sanitize_filename_local(in)

out = regexprep(in, '[^a-zA-Z0-9_\-]', '_');
out = regexprep(out, '_+', '_');

end


function group_names = normalize_group_names_local(group_names)

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


function validate_group_name_count_local(group_names, numGroups)

if numel(group_names) ~= numGroups
    error([ ...
        'group_names has %d entries, but bestModel.xDim_within ', ...
        'contains %d DLAG groups. The order of group_names must ', ...
        'follow the model-group order.'], ...
        numel(group_names), ...
        numGroups);
end

end


function [groupDisplayNames, groupFileTags] = ...
        build_group_labels_local(group_names)

nGroups = numel(group_names);
groupDisplayNames = cell(1, nGroups);
groupFileTags = cell(1, nGroups);

for g = 1:nGroups
    groupDisplayNames{g} = sprintf( ...
        'Group %d: %s', ...
        g, ...
        group_names{g});

    areaToken = sanitize_filename_local(group_names{g});
    areaToken = regexprep(areaToken, '^_+|_+$', '');

    if isempty(areaToken)
        areaToken = 'area';
    end

    groupFileTags{g} = sprintf('G%02d_%s', g, areaToken);
end

end


function ensure_dir_local(folderPath)

if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end

end
