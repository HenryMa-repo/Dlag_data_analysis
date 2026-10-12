%% SHOW_LOADING_EXAMPLE
% Plot example DLAG loading-weight vectors from saved model results.
%
% This is a SCRIPT, not a function. Place this file in a session folder and
% run it after plot_dlag_results has already generated/saved bestmodel*.mat.
% The MATLAB workspace may be completely empty. Following the loading
% convention used by the other analysis scripts, this script constructs
% the exact FA_Dlag_*/mat_results/runXXX folder from the model-selection
% settings below, then reads res.estParams from its newest bestmodel* file.
%
% The figure contains:
%   - two randomly selected across-area latents;
%   - two randomly selected within-V1 latents;
%   - two randomly selected within-MT latents.
%
% For an across latent, the corresponding V1 and MT loading columns are
% combined into one vector spanning all recorded neurons. For a within
% latent, the complete loading column is plotted as stored in estParams.C.
% Thus, weights in the other area are not artificially hidden or replaced:
% if the DLAG loading is zero there, it is displayed as zero (white).
%
%% ======================== MODEL SELECTION =============================
data_content = 'demean_count_within_t_and_condition';
% Examples:
% raw_count, raw_fr, z_within_trial, z_within_condition,
% z_across_conditions, demean_count_within_trial,
% demean_fr_within_trial, demean_pooledsd_within_condition,
% demean_count_within_t_and_condition

data_condition = [];
% []: pooled all-condition model
% A single positive integer (for example, 3): condition-specific model
% This corresponds to data_condtion in the current plot_dlag_results.m
% (that script currently spells the variable name without the second "i").

runIdx = 1;
% 1: data; 2: independently shuffled units in the current workflow.
% =====================================================================

%% =========================== SAVE OPTIONS ============================
save_fig = false;   % Save an editable MATLAB .fig file
save_svg = true;   % Save an editable vector .svg file (older MATLAB compatible)
save_png = false;   % Save a 300-dpi .png file
close_after_save = false;
% true: close the figure after requested files have been saved
% false: leave the figure open for inspection or manual editing
% =====================================================================

scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    error('show_loading_example:UnknownScriptLocation', ...
        ['MATLAB could not determine the location of this script. ', ...
         'Save show_loading_example.m in the session folder before running it.']);
end

sessionFolder = fileparts(scriptPath);
if isempty(sessionFolder)
    sessionFolder = pwd;
end
areaNames = {'V1', 'MT'};
numExamplesPerType = 2;

% Preserve the user's random-number-generator state. Selection is random
% on every run, but this script does not alter subsequent random draws.
previousRng = rng;
rngCleanup = onCleanup(@() rng(previousRng)); %#ok<NASGU>
rng('shuffle');

%% Load and validate the fitted DLAG model saved on disk
[estParams, modelSource, runDir] = loadSavedDlagModel( ...
    sessionFolder, data_content, data_condition, runIdx);
validateDlagModel(estParams);

if numel(estParams.yDims) ~= 2
    error('show_loading_example:TwoGroupsRequired', ...
        ['This program expects exactly two neural populations. ', ...
         'The selected model contains %d groups.'], numel(estParams.yDims));
end

yDims = double(estParams.yDims(:)');
xDimAcross = double(estParams.xDim_across);
xDimWithin = double(estParams.xDim_within(:)');
C = double(estParams.C);

if numel(xDimWithin) ~= 2
    error('show_loading_example:BadWithinDimensions', ...
        'estParams.xDim_within must contain one entry for V1 and one for MT.');
end

expectedRows = sum(yDims);
expectedColumns = 2 * xDimAcross + sum(xDimWithin);
if size(C,1) ~= expectedRows || size(C,2) ~= expectedColumns
    error('show_loading_example:UnexpectedCSize', ...
        ['Unexpected size for estParams.C. Expected %d-by-%d from ', ...
         'yDims, xDim_across, and xDim_within, but found %d-by-%d.'], ...
        expectedRows, expectedColumns, size(C,1), size(C,2));
end

if xDimAcross < 1 || any(xDimWithin < 1)
    error('show_loading_example:MissingLatentType', ...
        ['The selected model must contain at least one across latent and ', ...
         'at least one within latent in each area.']);
end

if xDimAcross < numExamplesPerType
    warning('show_loading_example:FewerAcrossLatents', ...
        'Only %d across latent(s) are available; plotting all of them.', ...
        xDimAcross);
end
for groupIdx = 1:2
    if xDimWithin(groupIdx) < numExamplesPerType
        warning('show_loading_example:FewerWithinLatents', ...
            'Only %d within-%s latent(s) are available; plotting all of them.', ...
            xDimWithin(groupIdx), areaNames{groupIdx});
    end
end

%% Randomly select example latent dimensions
acrossIdx = randomSubset(xDimAcross, numExamplesPerType);
withinIdx = cell(1,2);
withinIdx{1} = randomSubset(xDimWithin(1), numExamplesPerType);
withinIdx{2} = randomSubset(xDimWithin(2), numExamplesPerType);

% Observation blocks contain neurons; latent blocks contain, for each
% area, [across latents, within-area latents]. This is the ordering used by
% DLAG's estParams.C.
obsStarts = [1, 1 + cumsum(yDims(1:end-1))];
obsEnds = cumsum(yDims);
latentBlockSizes = xDimAcross + xDimWithin;
latentStarts = [1, 1 + cumsum(latentBlockSizes(1:end-1))];

numRows = numel(acrossIdx) + numel(withinIdx{1}) + numel(withinIdx{2});
loadingRows = zeros(numRows, sum(yDims));
rowLabels = cell(numRows,1);
rowType = zeros(numRows,1); % 1: across, 2: within V1, 3: within MT

rowCounter = 0;

% Each across latent has one loading column in each area's latent block.
% The two columns are summed because their nonzero observation blocks are
% complementary, yielding one vector over all V1 and MT neurons.
for exampleIdx = 1:numel(acrossIdx)
    latentIdx = acrossIdx(exampleIdx);
    acrossColumns = latentStarts + latentIdx - 1;

    rowCounter = rowCounter + 1;
    loadingRows(rowCounter,:) = sum(C(:,acrossColumns),2)';
    rowLabels{rowCounter} = sprintf('Across %d', latentIdx);
    rowType(rowCounter) = 1;
end

% Within-area columns are used in their complete stored form. Values in
% the other area's neuron block are therefore whatever estParams.C stores
% there (normally exact zeros in DLAG's block-structured observation model).
for groupIdx = 1:2
    for exampleIdx = 1:numel(withinIdx{groupIdx})
        latentIdx = withinIdx{groupIdx}(exampleIdx);
        withinColumn = latentStarts(groupIdx) + xDimAcross + latentIdx - 1;

        rowCounter = rowCounter + 1;
        loadingRows(rowCounter,:) = C(:,withinColumn)';
        rowLabels{rowCounter} = sprintf('Within %s %d', ...
            areaNames{groupIdx}, latentIdx);
        rowType(rowCounter) = groupIdx + 1;
    end
end

%% Plot loading weights
colorLimit = max(abs(loadingRows(:)));
if ~isfinite(colorLimit) || colorLimit <= 0
    colorLimit = 1;
end

colorMap = blueWhiteRedMap(257);

figureHeight = max(360, 62 * numRows + 125);
fig = figure( ...
    'Color', 'w', ...
    'Renderer', 'painters', ...
    'Name', 'DLAG loading examples', ...
    'NumberTitle', 'off', ...
    'Position', [100 100 1200 figureHeight]);

ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.18 0.16 0.68 0.72]);
hold(ax, 'on');
colormap(ax, colorMap);
caxis(ax, [-colorLimit colorLimit]);

% Draw every heat-map cell as a vector rectangle. This keeps the colored
% cells editable and avoids embedding the heat map as a raster in SVG.
for rowIdx = 1:numRows
    for neuronIdx = 1:sum(yDims)
        faceColor = valueToColor(loadingRows(rowIdx,neuronIdx), ...
            colorLimit, colorMap);
        patch(ax, ...
            [neuronIdx-0.5 neuronIdx+0.5 neuronIdx+0.5 neuronIdx-0.5], ...
            [rowIdx-0.5 rowIdx-0.5 rowIdx+0.5 rowIdx+0.5], ...
            faceColor, ...
            'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
end

% Outer border and boundary between the two neural populations.
rectangle(ax, ...
    'Position', [0.5 0.5 sum(yDims) numRows], ...
    'EdgeColor', [0.30 0.30 0.30], ...
    'LineWidth', 0.8, ...
    'FaceColor', 'none');

populationBoundary = yDims(1) + 0.5;
plot(ax, [populationBoundary populationBoundary], [0.5 numRows+0.5], ...
    '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.3, ...
    'HandleVisibility', 'off');

% Separate across, within-V1, and within-MT row groups.
rowGroupEnds = cumsum([numel(acrossIdx), ...
                       numel(withinIdx{1}), ...
                       numel(withinIdx{2})]);
for boundaryIdx = 1:(numel(rowGroupEnds)-1)
    yBoundary = rowGroupEnds(boundaryIdx) + 0.5;
    plot(ax, [0.5 sum(yDims)+0.5], [yBoundary yBoundary], ...
        '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
end

xlim(ax, [0.5 sum(yDims)+0.5]);
ylim(ax, [0.5 numRows+0.5]);
set(ax, ...
    'YDir', 'reverse', ...
    'XAxisLocation', 'top', ...
    'XTick', [mean([obsStarts(1), obsEnds(1)]), ...
              mean([obsStarts(2), obsEnds(2)])], ...
    'XTickLabel', areaNames, ...
    'YTick', 1:numRows, ...
    'YTickLabel', rowLabels, ...
    'TickLength', [0 0], ...
    'FontName', 'Arial', ...
    'FontSize', 12, ...
    'LineWidth', 0.8, ...
    'Box', 'off', ...
    'Layer', 'top');

ax.XAxis.FontWeight = 'bold';
ylabel(ax, 'Latent', 'FontName', 'Arial', 'FontSize', 13, ...
    'FontWeight', 'bold');

cb = colorbar(ax, 'eastoutside');
cb.Ticks = [-colorLimit, 0, colorLimit];
cb.TickLabels = {'Negative', '0', 'Positive'};
cb.FontName = 'Arial';
cb.FontSize = 11;
cb.Label.String = 'Loading weight';
cb.Label.FontName = 'Arial';
cb.Label.FontSize = 12;

% Keep useful provenance on the figure without adding visible poster text.
setappdata(fig, 'model_source', modelSource);
setappdata(fig, 'across_latent_indices', acrossIdx);
setappdata(fig, 'within_V1_latent_indices', withinIdx{1});
setappdata(fig, 'within_MT_latent_indices', withinIdx{2});
setappdata(fig, 'loading_rows', loadingRows);
setappdata(fig, 'row_type', rowType);

fprintf('\nshow_loading_example\n');
fprintf('  Model source: %s\n', modelSource);
fprintf('  Across latent indices: %s\n', mat2str(acrossIdx));
fprintf('  Within V1 latent indices: %s\n', mat2str(withinIdx{1}));
fprintf('  Within MT latent indices: %s\n', mat2str(withinIdx{2}));

%% Save requested formats
if save_fig || save_svg || save_png
    outputFolder = fullfile(runDir, 'loading_example');
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    filenameStem = sprintf('loading_example_A%s_WV1%s_WMT%s', ...
        indexTag(acrossIdx), indexTag(withinIdx{1}), indexTag(withinIdx{2}));
    outputBase = fullfile(outputFolder, filenameStem);

    if save_fig
        savefig(fig, [outputBase '.fig']);
        fprintf('  Saved: %s\n', [outputBase '.fig']);
    end

    if save_svg
        svgFile = [outputBase '.svg'];
        % Older MATLAB releases do not accept SVG as an exportgraphics
        % format. The painters renderer keeps the patch cells, lines, and
        % text as editable vector objects in the SVG.
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, svgFile, '-dsvg', '-painters');
        fprintf('  Saved: %s\n', svgFile);
    end

    if save_png
        exportgraphics(fig, [outputBase '.png'], ...
            'Resolution', 300, ...
            'BackgroundColor', 'white');
        fprintf('  Saved: %s\n', [outputBase '.png']);
    end

    if close_after_save
        close(fig);
    end
end

%% =====================================================================
function [estParams, modelSource, runDir] = loadSavedDlagModel( ...
        sessionFolder, data_content, data_condition, runIdx)
% Follow the same bestmodel-loading convention as the other analysis
% scripts. Nothing is read from the base workspace, and seqEst is not
% loaded because only loading weights are needed here.

if ~(ischar(data_content) || (isstring(data_content) && isscalar(data_content)))
    error('show_loading_example:BadDataContent', ...
        'data_content must be a character vector or scalar string.');
end
data_content = strtrim(char(data_content));
if isempty(data_content)
    error('show_loading_example:EmptyDataContent', ...
        'data_content cannot be empty.');
end

if ~(isscalar(runIdx) && isnumeric(runIdx) && isfinite(runIdx) && ...
        runIdx >= 1 && runIdx == round(runIdx))
    error('show_loading_example:BadRunIndex', ...
        'runIdx must be a positive integer scalar.');
end

if isempty(data_condition)
    baseDirName = ['FA_Dlag_', data_content];
    modelModeLabel = 'pooled all-condition';
elseif isscalar(data_condition) && isnumeric(data_condition) && ...
        isfinite(data_condition) && data_condition >= 1 && ...
        data_condition == round(data_condition)
    baseDirName = sprintf('FA_Dlag_%s_condition%d', ...
        data_content, data_condition);
    modelModeLabel = sprintf('condition %d', data_condition);
else
    error('show_loading_example:BadDataCondition', ...
        ['data_condition must be [] for the pooled model or one positive ', ...
         'integer for a condition-specific model.']);
end

baseDir = fullfile(sessionFolder, baseDirName);
runDir = fullfile(baseDir, 'mat_results', sprintf('run%03d', runIdx));

if ~isfolder(runDir)
    error('show_loading_example:RunDirectoryNotFound', ...
        ['The selected model directory does not exist:\n%s\n', ...
         'Check data_content, data_condition, and runIdx.'], runDir);
end

bestmodelFiles = dir(fullfile(runDir, 'bestmodel*'));
bestmodelFiles = bestmodelFiles(~[bestmodelFiles.isdir]);
if isempty(bestmodelFiles)
    error('show_loading_example:BestModelNotFound', ...
        ['No bestmodel* file was found in:\n%s\n', ...
         'Run plot_dlag_results for these exact model settings first.'], ...
        runDir);
end

% Match findOneFileLocal in the existing analysis scripts: when more than
% one bestmodel* file exists in the selected run directory, use the newest.
[~, newestOrder] = sort([bestmodelFiles.datenum], 'descend');
bestmodelFiles = bestmodelFiles(newestOrder);
bestmodelFile = fullfile(runDir, bestmodelFiles(1).name);

fprintf('\nSelected model settings:\n');
fprintf('  data_content: %s\n', data_content);
fprintf('  training mode: %s\n', modelModeLabel);
fprintf('  runIdx: %d\n', runIdx);
fprintf('Loading best model:\n  %s\n', bestmodelFile);

% Load only the variables needed for the loading panel. In particular,
% avoid loading seqEst, which may be large.
Sbest = load(bestmodelFile, 'res', 'bestModel');

if ~isfield(Sbest, 'res') || ~isstruct(Sbest.res) || ...
        ~isfield(Sbest.res, 'estParams')
    error('show_loading_example:MissingEstParams', ...
        'The selected file is missing res.estParams:\n%s', bestmodelFile);
end

if isfield(Sbest, 'bestModel')
    bestModel = Sbest.bestModel;
else
    bestModel = [];
end

estParams = normalizeParamDimsLocal(Sbest.res.estParams, bestModel);
modelSource = sprintf('%s -> res.estParams', bestmodelFile);
end


function params = normalizeParamDimsLocal(params, bestModel)
% Match the dimension-normalization logic used by data_reconstruction.m.
if ~isstruct(params) || ~isscalar(params)
    error('show_loading_example:InvalidEstParams', ...
        'res.estParams must be a scalar structure.');
end

if ~isfield(params, 'C')
    error('show_loading_example:MissingC', ...
        'res.estParams must contain loading matrix C.');
end

if ~isfield(params, 'yDims') || isempty(params.yDims)
    error('show_loading_example:MissingYDims', ...
        'res.estParams must contain yDims.');
end

params.yDims = reshape(params.yDims, 1, []);
numGroups = numel(params.yDims);

if ~isfield(params, 'xDim_across') || isempty(params.xDim_across)
    if ~isempty(bestModel) && isstruct(bestModel) && ...
            isfield(bestModel, 'xDim_across')
        params.xDim_across = bestModel.xDim_across;
    else
        error('show_loading_example:MissingAcrossDimension', ...
            ['xDim_across was found in neither res.estParams nor ', ...
             'bestModel.']);
    end
end

if ~isscalar(params.xDim_across)
    error('show_loading_example:BadAcrossDimension', ...
        'xDim_across must be a scalar for standard DLAG.');
end
params.xDim_across = double(params.xDim_across);

if ~isfield(params, 'xDim_within') || isempty(params.xDim_within)
    if ~isempty(bestModel) && isstruct(bestModel) && ...
            isfield(bestModel, 'xDim_within')
        params.xDim_within = bestModel.xDim_within;
    else
        error('show_loading_example:MissingWithinDimension', ...
            ['xDim_within was found in neither res.estParams nor ', ...
             'bestModel.']);
    end
end

params.xDim_within = reshape(params.xDim_within, 1, []);
if isscalar(params.xDim_within) && numGroups > 1
    params.xDim_within = repmat(params.xDim_within, 1, numGroups);
end
if numel(params.xDim_within) ~= numGroups
    error('show_loading_example:BadWithinDimension', ...
        'xDim_within must contain one entry per neural population.');
end
params.xDim_within = double(params.xDim_within);
end


function validateDlagModel(estParams)
if ~isValidDlagParams(estParams)
    error('show_loading_example:InvalidModel', ...
        ['The selected structure is not a complete DLAG parameter ', ...
         'structure. Required fields are C, xDim_across, ', ...
         'xDim_within, and yDims.']);
end

if ~isnumeric(estParams.C) || ndims(estParams.C) ~= 2
    error('show_loading_example:InvalidLoadingMatrix', ...
        'estParams.C must be a numeric two-dimensional loading matrix.');
end
end


function tf = isValidDlagParams(params)
tf = isstruct(params) && isscalar(params) && ...
     isfield(params, 'C') && ...
     isfield(params, 'xDim_across') && ...
     isfield(params, 'xDim_within') && ...
     isfield(params, 'yDims');
end


function selected = randomSubset(numAvailable, numRequested)
numSelected = min(numAvailable, numRequested);
selected = randperm(numAvailable, numSelected);
end


function cmap = blueWhiteRedMap(numColors)
% A perceptually simple diverging map: negative blue, zero white,
% positive red. Use an odd number of entries so exact zero is pure white.
if mod(numColors,2) == 0
    numColors = numColors + 1;
end

negativeColor = [0.18 0.36 0.68];
zeroColor = [1.00 1.00 1.00];
positiveColor = [0.78 0.18 0.24];

halfCount = (numColors + 1) / 2;
negativeHalf = [ ...
    linspace(negativeColor(1), zeroColor(1), halfCount)', ...
    linspace(negativeColor(2), zeroColor(2), halfCount)', ...
    linspace(negativeColor(3), zeroColor(3), halfCount)'];
positiveHalf = [ ...
    linspace(zeroColor(1), positiveColor(1), halfCount)', ...
    linspace(zeroColor(2), positiveColor(2), halfCount)', ...
    linspace(zeroColor(3), positiveColor(3), halfCount)'];

cmap = [negativeHalf; positiveHalf(2:end,:)];
end


function color = valueToColor(value, colorLimit, colorMap)
normalizedValue = (value + colorLimit) / (2 * colorLimit);
normalizedValue = min(max(normalizedValue, 0), 1);
colorIdx = 1 + round(normalizedValue * (size(colorMap,1)-1));
color = colorMap(colorIdx,:);
end


function tag = indexTag(indices)
pieces = arrayfun(@(x) sprintf('%02d', x), indices, ...
    'UniformOutput', false);
tag = strjoin(pieces, '-');
end
