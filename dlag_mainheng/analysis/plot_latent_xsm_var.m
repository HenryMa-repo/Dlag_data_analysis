%% plot_latent_xsm_var.m
% Plot the trial-to-trial variance of inferred DLAG latents for ONE session.
% Run this script from the session folder; an empty workspace is sufficient.
% It reads condition-specific bestmodel*.mat files created by
% plot_dlag_results_for_each_condtion_mode_var.m (older bestmodel files also
% work if they contain bestModel, seqEst and gp_params), together with the
% matching bootstrapResults*.mat files for the ambiguous latent indices.
%
% For each independently fitted condition, group, and local latent j:
%   v_j(t) = var({seqEst(tr).xsm(row_j,t) : trials valid at time t}, 0);
%   meanVar_j = mean(v_j(t) over time bins with >= 2 valid trials).
% MATLAB's var(...,0) uses the sample variance (N-1 denominator). The
% within-condition mean trajectory is removed at EACH time bin before the
% variance is calculated. Posterior covariance, loadings C and the R noise
% matrix do not enter this metric. Each area has its OWN xsm row for an
% across-area latent, and the two areas are plotted separately.
%
% The 16 fitted conditions map to eight stimulus labels (type-size-contrast).
% Each direction-specific model is processed on its own. For plotting, its
% individual latent meanVar_j values are put together with those from the
% other direction with the same stimulus label AND latent category. They
% are not first averaged or summed across directions. Bars show the mean of
% these pooled latent values; overlaid dots show the individual latents.
% The five categories overlap: Across contains FF/FB/Ambiguous, while
% Across + Within contains all latents. Do not sum the five plotted bars.
%
% Saves one MAT summary for later session-level analyses, and one figure
% per model group. Does not modify any bestmodel or bootstrap MAT file.

clc; clear;

%% ------------------------------- Settings -----------------------------
dat_file = fullfile('.', 'model_data_allruns.mat');
% For shuffled models, select their matching data MAT and set runIdx = 2.
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;                    % 1: original data; 2: shuffled data
data_condtion = 1:16;          % IDs of separately fitted condition models
group_names = {'V1','MT'};     % names in the model's group order

save_mat = true;
save_png = true;
save_fig = false;
png_dpi = 300;
close_after_save = true;
show_individual_latent_points = true;

%% ---------------------------- Input checks ----------------------------
if isempty(data_condtion) || ~isnumeric(data_condtion) || ...
        any(~isfinite(data_condtion)) || ...
        any(data_condtion ~= round(data_condtion)) || ...
        any(data_condtion < 1) || ...
        numel(unique(data_condtion)) ~= numel(data_condtion)
    error('data_condtion must contain unique positive condition IDs.');
end
if ~isscalar(runIdx) || ~isnumeric(runIdx) || ~isfinite(runIdx) || ...
        runIdx < 1 || runIdx ~= round(runIdx)
    error('runIdx must be a positive integer.');
end
if ~isnumeric(png_dpi) || ~isscalar(png_dpi) || ...
        ~isfinite(png_dpi) || png_dpi <= 0
    error('png_dpi must be positive.');
end
input = load(dat_file,'model_data_allruns');
if ~isfield(input,'model_data_allruns')
    error('%s lacks model_data_allruns.',dat_file);
end
runTags = cellfun(@(s) char(s.stim_tag),input.model_data_allruns, ...
    'UniformOutput',false);
runPos = find(strcmp(runTags,stim_tag));
if numel(runPos) ~= 1
    error('stim_tag must match exactly one model_data_allruns entry.');
end
metadata = input.model_data_allruns{runPos};
if ~isfield(metadata,'conditions_full')
    error('Selected run lacks conditions_full.');
end
condition_list = reshape(double(data_condtion),1,[]);
if any(condition_list > numel(metadata.conditions_full))
    error('Condition IDs exceed conditions_full length.');
end
conditionMap = conditionMapLocal(metadata.conditions_full,condition_list);
group_names = cellstr(string(group_names(:)'));
if isempty(group_names) || any(cellfun(@isempty,group_names))
    error('group_names must contain one nonempty name per model group.');
end

%% ----------------- One independent fit per condition ------------------
AllConditionResults = struct([]);
categoryLabels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
for ci = 1:numel(condition_list)
    conditionId = condition_list(ci);
    baseDir = sprintf('FA_Dlag_%s_condition%d',data_content,conditionId);
    resultDir = fullfile(baseDir,'mat_results',sprintf('run%03d',runIdx));
    bestFile = exactlyOneFileLocal(resultDir,'bestmodel*');
    bootFile = exactlyOneFileLocal(resultDir,'bootstrapResults*');
    B = load(bestFile,'bestModel','seqEst','gp_params');
    P = load(bootFile,'ambiguousIdxs');
    if ~all(isfield(B,{'bestModel','seqEst','gp_params'}))
        error('Missing bestModel, seqEst or gp_params in %s.',bestFile);
    end
    if ~isfield(P,'ambiguousIdxs')
        error('Missing ambiguousIdxs in %s.',bootFile);
    end
    if ~isstruct(B.seqEst) || isempty(B.seqEst) || ...
            ~isfield(B.seqEst,'xsm')
        error('No inferred seqEst.xsm trials in %s.',bestFile);
    end
    a = double(B.bestModel.xDim_across);
    w = reshape(double(B.bestModel.xDim_within),1,[]);
    if ~isscalar(a) || ~isfinite(a) || a < 0 || a ~= round(a) || ...
            isempty(w) || any(~isfinite(w)) || ...
            any(w < 0) || any(w ~= round(w)) || numel(w) ~= numel(group_names)
        error('Model latent dimensions/group names disagree in %s.',bestFile);
    end
    localDims = a + w;
    totalDims = sum(localDims);
    if ci > 1 && numel(AllConditionResults(1).group) ~= numel(w)
        error('Model group count differs between condition fits.');
    end

    class = classifyLatentsLocal(a,B.gp_params,P.ambiguousIdxs);
    [varByTime,nTrialsByTime,meanVar] = xsmTrialVarianceLocal( ...
        B.seqEst,totalDims,bestFile);
    entry = conditionMap.entries(ci);

    AllConditionResults(ci).condition = conditionId;
    AllConditionResults(ci).featureCode = entry.featureCode;
    AllConditionResults(ci).dirCode = entry.dirCode;
    AllConditionResults(ci).direction = entry.direction;
    AllConditionResults(ci).label = entry.label;
    AllConditionResults(ci).bestmodel_file = bestFile;
    AllConditionResults(ci).bootstrap_file = bootFile;
    AllConditionResults(ci).nTrials = numel(B.seqEst);
    AllConditionResults(ci).timeBinCount = size(varByTime,2);
    AllConditionResults(ci).xDim_across = a;
    AllConditionResults(ci).xDim_within = w;
    AllConditionResults(ci).classification = class;

    rowStarts = 1 + [0,cumsum(localDims(1:end-1))];
    for g = 1:numel(w)
        localRows = rowStarts(g) + (0:localDims(g)-1);
        masks = categoryMasksLocal(localDims(g),a,class);
        G.name = group_names{g};
        G.localRows = localRows;
        G.varByTime = varByTime(localRows,:);
        G.nTrialsByTime = nTrialsByTime(localRows,:);
        G.meanVar = meanVar(localRows);
        G.validTimeBins = sum(isfinite(G.varByTime),2);
        for k = 1:numel(categoryLabels)
            localIdx = find(masks{k});
            G.category(k).name = categoryLabels{k};
            G.category(k).localLatentIdx = localIdx;
            G.category(k).values = reshape(G.meanVar(localIdx),1,[]);
        end
        AllConditionResults(ci).group(g) = G;
        clear G;
    end
    fprintf('Condition %02d (%s, direction %g): %d trials.\n', ...
        conditionId,entry.label,entry.direction,numel(B.seqEst));
end

%% ---------------- Pool calculated latent values for the plot ----------
SummaryXsmVar = summarizeConditionsLocal( ...
    AllConditionResults,conditionMap,group_names,categoryLabels, ...
    data_content,runIdx,stim_tag);

if save_mat
    summaryFile = sprintf('%s_run%03d_latent_xsm_var.mat',data_content,runIdx);
    save(summaryFile,'AllConditionResults','SummaryXsmVar', ...
        'condition_list','conditionMap','data_content','runIdx', ...
        'stim_tag','group_names','-v7.3');
    fprintf('Saved %s\n',summaryFile);
end

if save_png || save_fig
    for g = 1:numel(group_names)
        fig = plotGroupedDistributionsLocal( ...
            SummaryXsmVar.group(g),categoryLabels, ...
            conditionMap.shortLabels,show_individual_latent_points);
        safeGroup = regexprep(lower(group_names{g}),'[^a-z0-9]+','_');
        figureName = sprintf('%s_run%03d_xsmvar_g%d_%s', ...
            data_content,runIdx,g,safeGroup);
        saveFigureLocal(fig,'.',figureName, ...
            save_png,save_fig,png_dpi,close_after_save);
    end
end

%% ============================== Helpers ===============================
function path = exactlyOneFileLocal(folder,pattern)
    d = dir(fullfile(folder,pattern));
    d = d(~[d.isdir]);
    if numel(d) ~= 1
        error('Expected exactly one %s in %s, found %d.',pattern,folder,numel(d));
    end
    path = fullfile(d(1).folder,d(1).name);
end

function C = classifyLatentsLocal(acrossDim,gp_params,ambiguousIdxs)
% Same delay/significance classification as latent_compare_for_each_condtion_mode.
    if acrossDim == 0
        d = [];
    else
        if ~isfield(gp_params,'delays') || ...
                numel(gp_params.delays) < acrossDim
            error('gp_params.delays is missing or shorter than xDim_across.');
        end
        d = reshape(double(gp_params.delays),1,[]);
        d = d(1:acrossDim);
    end
    ambiguousIdxs = reshape(double(ambiguousIdxs),1,[]);
    ambiguousIdxs = unique(ambiguousIdxs( ...
        isfinite(ambiguousIdxs) & ambiguousIdxs >= 1 & ...
        ambiguousIdxs <= acrossDim & ambiguousIdxs == round(ambiguousIdxs)));
    ambiguous = unique([ambiguousIdxs,find(~isfinite(d) | d == 0)]);
    ff = setdiff(find(d > 0),ambiguous);
    fb = setdiff(find(d < 0),ambiguous);
    ambiguous = unique([ambiguous, ...
        setdiff(1:acrossDim,[ff,fb,ambiguous])]);
    C.delays = d;
    C.acrossIdx = 1:acrossDim;
    C.feedforwardIdx = ff;
    C.feedbackIdx = fb;
    C.ambiguousIdx = ambiguous;
end

function masks = categoryMasksLocal(localDim,acrossDim,C)
    masks = cell(1,5);
    for j = 1:5
        masks{j} = false(1,localDim);
    end
    masks{1}(1:acrossDim) = true;
    masks{2}(acrossDim+1:end) = true;
    masks{3}(C.feedforwardIdx) = true;
    masks{4}(C.feedbackIdx) = true;
    masks{5}(C.ambiguousIdx) = true;
end

function [V,N,meanVar] = xsmTrialVarianceLocal(seqEst,nRows,bestFile)
% Online sample variance across trials at each bin (supports unequal T).
    nTrials = numel(seqEst);
    trialLengths = zeros(1,nTrials);
    for tr = 1:nTrials
        X = seqEst(tr).xsm;
        if ~isnumeric(X) || ~isreal(X) || ndims(X) ~= 2 || ...
                size(X,1) ~= nRows || isempty(X)
            error('Unexpected seqEst(%d).xsm dimensions in %s.',tr,bestFile);
        end
        trialLengths(tr) = size(X,2);
    end
    maxT = max(trialLengths);
    N = zeros(nRows,maxT);
    mu = zeros(nRows,maxT);
    M2 = zeros(nRows,maxT);
    for tr = 1:nTrials
        T = trialLengths(tr);
        X = double(seqEst(tr).xsm);
        valid = isfinite(X);
        oldN = N(:,1:T);
        newN = oldN + double(valid);
        oldMu = mu(:,1:T);
        delta = X - oldMu;
        delta(~valid) = 0;
        newMu = oldMu + delta ./ max(newN,1);
        delta2 = X - newMu;
        delta2(~valid) = 0;
        M2(:,1:T) = M2(:,1:T) + delta .* delta2;
        mu(:,1:T) = newMu;
        N(:,1:T) = newN;
    end
    V = M2 ./ max(N-1,1);
    V(N < 2) = NaN;
    meanVar = mean(V,2,'omitnan');
end

function S = summarizeConditionsLocal(allResults,map,groupNames,labels, ...
        dataContent,runIdx,stimTag)
    S.labels = labels;
    S.meta.data_content = dataContent;
    S.meta.runIdx = runIdx;
    S.meta.stim_tag = stimTag;
    S.meta.group_names = groupNames;
    S.meta.conditionShortLabels = map.shortLabels;
    S.meta.dirValues = map.dirValues;
    S.meta.definition = ['For each latent: sample variance of xsm across ' ...
        'trials at each time bin, then mean of defined time-bin variances.'];
    S.meta.pooling = ['Independently compute each direction/condition model; ' ...
        'concatenate individual latent values of the two directions for ' ...
        'the same stimulus label/category; bar = mean of these values.'];
    S.meta.unit = 'latent xsm units squared';
    S.meta.categoryOverlap = ...
        'Across includes Feedforward, Feedback, and Ambiguous.';
    for g = 1:numel(groupNames)
        S.group(g).name = groupNames{g};
        S.group(g).mean = nan(8,numel(labels));
        S.group(g).median = nan(8,numel(labels));
        S.group(g).nLatents = zeros(8,numel(labels));
        for p = 1:8
            S.group(g).condition(p).label = map.shortLabels{p};
            for k = 1:numel(labels)
                empty = struct('name',labels{k},'values',[], ...
                    'conditionIds',[],'directionCodes',[], ...
                    'localLatentIdx',[],'n',0,'mean',NaN,'median',NaN);
                S.group(g).condition(p).category(k) = empty;
            end
        end
    end
    for ci = 1:numel(allResults)
        A = allResults(ci);
        p = A.featureCode;
        for g = 1:numel(groupNames)
            for k = 1:numel(labels)
                source = A.group(g).category(k);
                dst = S.group(g).condition(p).category(k);
                vals = reshape(source.values,1,[]);
                n = numel(vals);
                dst.values = [dst.values,vals];
                dst.conditionIds = [dst.conditionIds, ...
                    repmat(A.condition,1,n)];
                dst.directionCodes = [dst.directionCodes, ...
                    repmat(A.dirCode,1,n)];
                dst.localLatentIdx = [dst.localLatentIdx, ...
                    reshape(source.localLatentIdx,1,[])];
                S.group(g).condition(p).category(k) = dst;
            end
        end
    end
    for g = 1:numel(groupNames)
        for p = 1:8
            for k = 1:numel(labels)
                dst = S.group(g).condition(p).category(k);
                vals = dst.values(isfinite(dst.values));
                dst.n = numel(vals);
                if ~isempty(vals)
                    dst.mean = mean(vals);
                    dst.median = median(vals);
                end
                S.group(g).condition(p).category(k) = dst;
                S.group(g).mean(p,k) = dst.mean;
                S.group(g).median(p,k) = dst.median;
                S.group(g).nLatents(p,k) = dst.n;
            end
        end
    end
end

function map = conditionMapLocal(full,ids)
% Identical stimulus and direction convention to the companion script.
    n = numel(full);
    names = strings(n,1);
    sizes = nan(n,1);
    contrasts = nan(n,1);
    dirs = nan(n,1);
    for j = 1:n
        if ~isfield(full(j),'stim_name') || ~isfield(full(j),'size') || ...
                ~isfield(full(j),'contrast')
            error('Incomplete condition metadata at condition %d.',j);
        end
        names(j) = lower(string(full(j).stim_name));
        sizes(j) = double(full(j).size);
        contrasts(j) = double(full(j).contrast);
        if names(j) == "grating"
            dirs(j) = full(j).grating_dir;
        elseif names(j) == "plaid"
            dirs(j) = full(j).plaid_dir;
        else
            error('Unsupported stimulus type at condition %d.',j);
        end
    end
    dirs = mod(dirs,360);
    dirs(abs(dirs-360)<1e-10 | abs(dirs)<1e-10) = 0;
    dirs(abs(dirs-round(dirs))<1e-10) = ...
        round(dirs(abs(dirs-round(dirs))<1e-10));
    dirValues = unique(dirs(isfinite(dirs)))';
    sizeValues = unique(sizes(isfinite(sizes)))';
    if numel(dirValues) ~= 2 || numel(sizeValues) ~= 2
        error('Expected two stimulus directions and two sizes.');
    end
    types = ["grating","plaid"];
    levels = cell(1,2);
    for t = 1:2
        levels{t} = unique(contrasts(names == types(t) & isfinite(contrasts)))';
        if numel(levels{t}) ~= 2
            error('Expected two contrast levels for each stimulus type.');
        end
    end
    short = {'G-S-L','G-S-H','G-L-L','G-L-H', ...
             'P-S-L','P-S-H','P-L-L','P-L-H'};
    entries = repmat(struct('conditionId',NaN,'featureCode',NaN, ...
        'dirCode',NaN,'direction',NaN,'label',''),1,numel(ids));
    for i = 1:numel(ids)
        c = ids(i);
        stimCode = find(names(c) == types);
        if numel(stimCode) ~= 1
            error('Condition %d has an invalid stimulus type.',c);
        end
        sizeCode = find(abs(sizes(c)-sizeValues)<1e-10);
        contrastCode = find(abs(contrasts(c)-levels{stimCode})<1e-10);
        dirCode = find(abs(dirs(c)-dirValues)<1e-10);
        if numel(sizeCode) ~= 1 || numel(contrastCode) ~= 1 || ...
                numel(dirCode) ~= 1
            error('Condition %d has an invalid feature/direction mapping.',c);
        end
        p = (stimCode-1)*4 + (sizeCode-1)*2 + contrastCode;
        entries(i).conditionId = c;
        entries(i).featureCode = p;
        entries(i).dirCode = dirCode;
        entries(i).direction = dirs(c);
        entries(i).label = short{p};
    end
    assignments = [[entries.featureCode]',[entries.dirCode]'];
    if size(unique(assignments,'rows'),1) ~= size(assignments,1)
        error('Duplicate stimulus label/direction assignment.');
    end
    map.entries = entries;
    map.shortLabels = short;
    map.dirValues = dirValues;
end

function fig = plotGroupedDistributionsLocal(G,labels,conditions,showPoints)
    colors = lines(8);
    fig = figure('Position',[80,80,1500,750]);
    ax = axes(fig);
    hold(ax,'on');
    bars = bar(ax,G.mean');  % categories x 8 conditions
    for p = 1:8
        bars(p).FaceColor = colors(p,:);
        bars(p).EdgeColor = 'none';
    end
    if showPoints
        for p = 1:8
            for k = 1:numel(labels)
                vals = G.condition(p).category(k).values;
                vals = vals(isfinite(vals));
                if isempty(vals)
                    continue;
                end
                xCenter = bars(p).XEndPoints(k);
                x = xCenter + 0.025 * linspace(-1,1,numel(vals));
                plot(ax,x,vals,'k.','MarkerSize',9, ...
                    'HandleVisibility','off');
            end
        end
    end
    set(ax,'XTick',1:numel(labels),'XTickLabel',labels);
    xtickangle(ax,30);
    xlabel(ax,'Latent category');
    ylabel(ax,'Latent xsm variance across trials (mean over time)');
    title(ax,sprintf('%s - inferred latent trial variance',G.name), ...
        'Interpreter','none');
    finiteVals = G.mean(isfinite(G.mean));
    if showPoints
        for p = 1:8
            for k = 1:numel(labels)
                x = G.condition(p).category(k).values;
                finiteX = x(isfinite(x));
                finiteVals = [finiteVals; finiteX(:)]; %#ok<AGROW>
            end
        end
    end
    if isempty(finiteVals) || max(finiteVals) <= 0
        ylim(ax,[0,1]);
    else
        ylim(ax,[0,1.12*max(finiteVals)]);
    end
    legend(ax,bars,conditions,'Location','southoutside', ...
        'Orientation','horizontal','NumColumns',4);
    box(ax,'off');
end

function saveFigureLocal(fig,folder,name,savePNG,saveFIG,dpi,closeAfter)
    if saveFIG
        savefig(fig,fullfile(folder,[name,'.fig']));
    end
    if savePNG
        drawnow;
        exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',dpi);
    end
    if closeAfter
        close(fig);
    end
end
