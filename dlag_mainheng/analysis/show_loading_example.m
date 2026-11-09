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
% The figure contains across-area, within-V1, and within-MT latents.
% Choose random or manual selection in LATENT SELECTION below. Random
% mode selects two examples per type by default. Manual mode builds the
% original row panel in the order entered for each type, then rotates
% the complete panel 90 degrees clockwise, as if rotated in PowerPoint.
% Each loading is therefore vertical, V1 is above MT, and the original
% top-to-bottom latent order now runs RIGHT TO LEFT. Text stays upright.
% The latent labels are above the panel, the area labels are on the right,
% and the horizontal colorbar is below the panel. All text is 30 pt.
% Indices are 1-based within each latent type in the saved model, not
% neuron IDs or global column indices of estParams.C.
%
% For an across latent, the corresponding V1 and MT loading columns are
% combined into one vector spanning all recorded neurons. For a within
% latent, the complete loading column is plotted as stored in estParams.C.
% Thus, weights in the other area are not artificially hidden or replaced:
% if the DLAG loading is zero there, it is displayed as zero (white).
% Color clipping affects only the displayed colors. All selected loadings
% remain in the figure, and its saved loading arrays retain their values.
% The line-thickness scale controls the height of each neuron's colored
% strip by resizing the heat-map region, with upright 30-pt text.
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

%% ========================= LATENT SELECTION ==========================
selection_mode = 'manual';
% 'random': randomly select numExamplesPerType latents from each type
% 'manual': use the three index vectors below in the original row order
% The clockwise rotation displays that original order from right to left.

numExamplesPerType = 2; % Used only when selection_mode = 'random'

manual_across_idx = [3 1];
manual_within_V1_idx = [28 1];
manual_within_MT_idx = [23 10];
% Manual indices are local to each latent type:
%   across:    1 ... estParams.xDim_across
%   within V1: 1 ... estParams.xDim_within(1)
%   within MT: 1 ... estParams.xDim_within(2)
% Enter a nonempty vector for each type; the three lengths may differ.
% For example, [28 1] places within-V1 latent 28 to the RIGHT of latent 1
% after clockwise rotation, matching the original panel rotated as a whole.
% =====================================================================

%% =========================== POSTER STYLE ============================
poster_font_size = 30; % Applies to every label and all colorbar text
% =====================================================================

%% ===================== COLOR CLIP / LINE THICKNESS ===================
color_clip_enabled = true;
color_clip_percentile = 98;
% true: use the chosen percentile of ABSOLUTE NONZERO selected weights
% as the color limit L. Use the same symmetric [-L, L] scale for all
% columns. Weights <= -L or >= L use the deepest blue or red; no weight
% is deleted or changed. Structural zeros in the other area are excluded
% from percentile estimation and are still plotted as white.
% Lower percentile -> stronger color clipping (for example, 95).
% 100, or color_clip_enabled = false, uses the largest absolute weight.

weight_line_thickness_scale = 1.0;
% Vertical thickness of each neuron's weight strip relative to this
% script's previous figure: 1 = original, 2 = double, 0.5 = half.
% Any positive scalar is allowed. The heat-map height and figure height
% adapt together, so neighboring strips remain distinct without overlap.
% Figure width, font size, and the space for labels/colorbar are retained.
% =====================================================================

%% =========================== SAVE OPTIONS ============================
save_fig = true;   % Save an editable MATLAB .fig file
save_svg = true;   % Save an editable vector .svg file (older MATLAB compatible)
save_png = false;   % Save a 300-dpi .png file
close_after_save = true;
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

%% Select example latent dimensions
if ~(ischar(selection_mode) || ...
        (isstring(selection_mode) && isscalar(selection_mode)))
    error('show_loading_example:BadSelectionMode', ...
        'selection_mode must be ''random'' or ''manual''.');
end
selection_mode = lower(strtrim(char(selection_mode)));

withinIdx = cell(1,2);
switch selection_mode
    case 'random'
        validateattributes(numExamplesPerType, {'numeric'}, ...
            {'scalar', 'real', 'finite', 'integer', 'positive'}, ...
            mfilename, 'numExamplesPerType');

        % Preserve the original random-selection behavior.
        previousRng = rng;
        rngCleanup = onCleanup(@() rng(previousRng)); %#ok<NASGU>
        rng('shuffle');

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

        acrossIdx = randomSubset(xDimAcross, numExamplesPerType);
        withinIdx{1} = randomSubset(xDimWithin(1), numExamplesPerType);
        withinIdx{2} = randomSubset(xDimWithin(2), numExamplesPerType);

    case 'manual'
        acrossIdx = validateManualIndices( ...
            manual_across_idx, xDimAcross, 'manual_across_idx');
        withinIdx{1} = validateManualIndices( ...
            manual_within_V1_idx, xDimWithin(1), 'manual_within_V1_idx');
        withinIdx{2} = validateManualIndices( ...
            manual_within_MT_idx, xDimWithin(2), 'manual_within_MT_idx');

    otherwise
        error('show_loading_example:BadSelectionMode', ...
            'selection_mode must be ''random'' or ''manual''.');
end

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

%% Plot loading weights: rotate the complete original panel clockwise
validateattributes(weight_line_thickness_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'weight_line_thickness_scale');
if ~(islogical(color_clip_enabled) && isscalar(color_clip_enabled))
    error('show_loading_example:BadColorClipOption', ...
        'color_clip_enabled must be true or false.');
end

% Estimate one common color limit from magnitudes. Ignore structural zeros
% when estimating the percentile; still draw every weight, including zero.
nonzeroAbsWeights = abs(loadingRows(:));
nonzeroAbsWeights = nonzeroAbsWeights( ...
    isfinite(nonzeroAbsWeights) & nonzeroAbsWeights > 0);
if isempty(nonzeroAbsWeights)
    unclippedColorLimit = 1;
else
    unclippedColorLimit = max(nonzeroAbsWeights);
end
colorLimit = unclippedColorLimit;
if color_clip_enabled
    validateattributes(color_clip_percentile, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<=', 100}, ...
        mfilename, 'color_clip_percentile');
    if ~isempty(nonzeroAbsWeights)
        colorLimit = percentileLinearLocal( ...
            nonzeroAbsWeights, color_clip_percentile);
    end
end
numColorClippedWeights = nnz(abs(loadingRows) > colorLimit);

colorMap = blueWhiteRedMap(257);

% This is a true clockwise rotation, not just a matrix transpose:
% original (row, neuron) -> displayed (neuron, numRows + 1 - row).
% Keep loadingRows/rowLabels/rowType in their original order for provenance.
loadingColumns = rot90(loadingRows, -1);
columnOrder = numRows:-1:1;
columnLabels = rowLabels(columnOrder);
columnType = rowType(columnOrder);

% Swap the original figure's width/height and scale both dimensions
% uniformly for 30-pt text. This retains the rotated panel's proportions.
originalFigureHeight = max(360, 62 * numRows + 125);
posterScale = poster_font_size / 12;
figureWidth = round(originalFigureHeight * posterScale);
figureHeight = round(1200 * posterScale);
fig = figure( ...
    'Color', 'w', ...
    'Renderer', 'painters', ...
    'Name', 'DLAG loading examples', ...
    'NumberTitle', 'off', ...
    'Units', 'pixels', ...
    'Position', [100 100 figureWidth figureHeight]);

% Clockwise rotation of the original normalized axes position
% [0.18 0.16 0.68 0.72]: [y, 1-x-width, height, width].
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.16 0.14 0.72 0.68]);
hold(ax, 'on');
colormap(ax, colorMap);
caxis(ax, [-colorLimit colorLimit]);

% Draw every heat-map cell as a vector rectangle. This keeps the colored
% cells editable and avoids embedding the heat map as a raster in SVG.
for columnIdx = 1:numRows
    for neuronIdx = 1:sum(yDims)
        faceColor = valueToColor(loadingColumns(neuronIdx,columnIdx), ...
            colorLimit, colorMap);
        patch(ax, ...
            [columnIdx-0.5 columnIdx+0.5 columnIdx+0.5 columnIdx-0.5], ...
            [neuronIdx-0.5 neuronIdx-0.5 neuronIdx+0.5 neuronIdx+0.5], ...
            faceColor, ...
            'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
end

% Outer border and boundary between the two neural populations.
rectangle(ax, ...
    'Position', [0.5 0.5 numRows sum(yDims)], ...
    'EdgeColor', [0.30 0.30 0.30], ...
    'LineWidth', 0.8, ...
    'FaceColor', 'none');

populationBoundary = yDims(1) + 0.5;
plot(ax, [0.5 numRows+0.5], [populationBoundary populationBoundary], ...
    '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.3, ...
    'HandleVisibility', 'off');

% The original horizontal group boundaries become vertical boundaries.
columnGroupEnds = find(diff(columnType) ~= 0);
for boundaryIdx = 1:numel(columnGroupEnds)
    xBoundary = columnGroupEnds(boundaryIdx) + 0.5;
    plot(ax, [xBoundary xBoundary], [0.5 sum(yDims)+0.5], ...
        '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
end

xlim(ax, [0.5 numRows+0.5]);
ylim(ax, [0.5 sum(yDims)+0.5]);
set(ax, ...
    'XDir', 'normal', ...
    'YDir', 'reverse', ...
    'XAxisLocation', 'top', ...
    'YAxisLocation', 'right', ...
    'XTick', 1:numRows, ...
    'XTickLabel', [], ...
    'YTick', [mean([obsStarts(1), obsEnds(1)]), ...
              mean([obsStarts(2), obsEnds(2)])], ...
    'YTickLabel', areaNames, ...
    'XTickLabelRotation', 0, ...
    'YTickLabelRotation', 0, ...
    'TickDir', 'out', ...
    'TickLength', [0 0], ...
    'FontName', 'Arial', ...
    'FontSize', poster_font_size, ...
    'LineWidth', 0.8, ...
    'Box', 'off', ...
    'Layer', 'top');

ax.YAxis.FontWeight = 'bold';

% The original right-side colorbar rotates to the bottom. Its negative
% end is on the left and its positive end on the right after rotation.
cb = colorbar(ax, 'southoutside');
cb.Ticks = [-colorLimit, 0, colorLimit];
cb.TickLabels = {'Negative', '0', 'Positive'};
cb.FontName = 'Arial';
cb.FontSize = poster_font_size;
cb.Direction = 'normal';
cb.Label.String = 'Loading weight';
cb.Label.FontName = 'Arial';
cb.Label.FontSize = poster_font_size;
cb.Label.Rotation = 0;

% Each colored rectangle spans one neuron row. Scale the physical height
% of that row by resizing only the heat-map region. Reserve the original
% space above and below it for fixed-size text and the colorbar.
if weight_line_thickness_scale ~= 1
    drawnow;
    originalFigurePosition = get(fig, 'Position');
    originalAxesPosition = get(ax, 'Position');
    set(cb, 'Units', 'normalized');
    originalColorbarPosition = get(cb, 'Position');

    originalHeatmapHeight = originalAxesPosition(4) * originalFigurePosition(4);
    resizedFigureHeight = originalFigurePosition(4) + ...
        originalHeatmapHeight * (weight_line_thickness_scale - 1);
    heightFraction = originalFigurePosition(4) / resizedFigureHeight;

    resizedAxesPosition = originalAxesPosition;
    resizedAxesPosition(2) = originalAxesPosition(2) * heightFraction;
    resizedAxesPosition(4) = originalAxesPosition(4) * ...
        weight_line_thickness_scale * heightFraction;
    resizedColorbarPosition = originalColorbarPosition;
    resizedColorbarPosition([2 4]) = ...
        originalColorbarPosition([2 4]) * heightFraction;

    resizedFigurePosition = originalFigurePosition;
    resizedFigurePosition(4) = resizedFigureHeight;
    set(fig, 'Position', resizedFigurePosition);
    set(cb, 'Position', resizedColorbarPosition);
    set(ax, 'Position', resizedAxesPosition);
end

% Use ordinary text objects for reliable upright, two-line labels in
% older MATLAB releases. The complete original labels are retained;
% only the line break changes (for example, "Within" above "V1 28").
% Compensate for the heat-map height change so text spacing stays fixed.
columnLabelY = 1 + 0.015 / weight_line_thickness_scale;
latentLabelY = 1 + 0.09 / weight_line_thickness_scale;
for columnIdx = 1:numRows
    fullLabel = columnLabels{columnIdx};
    firstSpace = find(fullLabel == ' ', 1, 'first');
    if isempty(firstSpace)
        labelLines = {fullLabel};
    else
        labelLines = {fullLabel(1:firstSpace-1); fullLabel(firstSpace+1:end)};
    end
    text('Parent', ax, 'Units', 'normalized', ...
        'Position', [(columnIdx - 0.5) / numRows, columnLabelY, 0], ...
        'String', labelLines, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'Rotation', 0, ...
        'FontName', 'Arial', ...
        'FontSize', poster_font_size, ...
        'Interpreter', 'none', ...
        'Clipping', 'off');
end

latentLabel = xlabel(ax, 'Latent', ...
    'FontName', 'Arial', 'FontSize', poster_font_size, ...
    'FontWeight', 'bold', 'Rotation', 0);
set(latentLabel, 'Units', 'normalized', 'Position', [0.5 latentLabelY 0], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

% Keep useful provenance on the figure without adding visible poster text.
setappdata(fig, 'model_source', modelSource);
setappdata(fig, 'selection_mode', selection_mode);
setappdata(fig, 'across_latent_indices', acrossIdx);
setappdata(fig, 'within_V1_latent_indices', withinIdx{1});
setappdata(fig, 'within_MT_latent_indices', withinIdx{2});
setappdata(fig, 'loading_rows', loadingRows);
setappdata(fig, 'row_type', rowType);
setappdata(fig, 'loading_columns', loadingColumns);
setappdata(fig, 'column_order', columnOrder);
setappdata(fig, 'column_labels', columnLabels);
setappdata(fig, 'column_type', columnType);
setappdata(fig, 'rotation_degrees_clockwise', 90);
setappdata(fig, 'color_clip_enabled', color_clip_enabled);
setappdata(fig, 'color_clip_percentile', color_clip_percentile);
setappdata(fig, 'color_limit', colorLimit);
setappdata(fig, 'unclipped_color_limit', unclippedColorLimit);
setappdata(fig, 'num_color_clipped_weights', numColorClippedWeights);
setappdata(fig, 'weight_line_thickness_scale', weight_line_thickness_scale);

fprintf('\nshow_loading_example\n');
fprintf('  Model source: %s\n', modelSource);
fprintf('  Selection mode: %s\n', selection_mode);
fprintf('  Across latent indices: %s\n', mat2str(acrossIdx));
fprintf('  Within V1 latent indices: %s\n', mat2str(withinIdx{1}));
fprintf('  Within MT latent indices: %s\n', mat2str(withinIdx{2}));
fprintf('  Display: 90 degrees clockwise; V1 above MT.\n');
fprintf('  Columns from left to right: %s\n', strjoin(columnLabels(:)', ' | '));
if color_clip_enabled
    fprintf('  Color clip: absolute nonzero-weight percentile %g\n', ...
        color_clip_percentile);
else
    fprintf('  Color clip: disabled\n');
end
fprintf('  Color scale: [%g, %g]; largest absolute weight: %g\n', ...
    -colorLimit, colorLimit, unclippedColorLimit);
fprintf('  Weights beyond the color limits: %d (colors saturated)\n', ...
    numColorClippedWeights);
fprintf('  Weight-strip thickness scale: %g\n', weight_line_thickness_scale);

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


function selected = validateManualIndices(indices, numAvailable, settingName)
% Validate without sorting so manual row order is preserved.
if ~(isnumeric(indices) && isreal(indices) && isvector(indices) && ...
        ~isempty(indices) && all(isfinite(indices(:))) && ...
        all(indices(:) == round(indices(:))))
    error('show_loading_example:BadManualIndices', ...
        '%s must be a nonempty vector of finite integer latent indices.', ...
        settingName);
end

selected = double(indices(:)');
if any(selected < 1 | selected > numAvailable)
    error('show_loading_example:ManualIndexOutOfRange', ...
        ['%s = %s contains an unavailable latent index. ', ...
         'Valid indices for this type in the selected model are 1 through %d.'], ...
        settingName, mat2str(selected), numAvailable);
end

if numel(unique(selected)) ~= numel(selected)
    error('show_loading_example:DuplicateManualIndices', ...
        '%s contains repeated latent indices: %s.', ...
        settingName, mat2str(selected));
end
end


function value = percentileLinearLocal(values, percentile)
% Linear interpolation of sorted values (no Statistics Toolbox required).
% Caller supplies a nonempty vector and 0 < percentile <= 100.
values = sort(double(values(:)));
rankPosition = 1 + (numel(values) - 1) * (percentile / 100);
lowerIndex = floor(rankPosition);
upperIndex = ceil(rankPosition);
fraction = rankPosition - lowerIndex;
value = values(lowerIndex) + ...
    fraction * (values(upperIndex) - values(lowerIndex));
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
