%% latent_compare_for_each_condtion_mode.m
% Compare model-based variance across separately trained condition models.
% Run plot_dlag_results_for_each_condtion_mode_var.m first, in the same
% session directory. This is a script: an empty MATLAB workspace is fine.
%
% Input for condition c: FA_Dlag_<data_content>_condition<c>/mat_results/
%                         runXXX/bestmodel*.mat and bootstrapResults*.mat.
% Each brain area is handled separately; stimulus direction is NOT pooled.
% The eight stimulus labels, in both direction panels, are:
%   G-S-L G-S-H G-L-L G-L-H P-S-L P-S-H P-L-L P-L-H.
%
% Raw values in the plots are mean PER MODEL NEURON, i.e. the group-wide
% sum of C(n,j)^2 divided by its neuron count. The independent-noise raw
% value is sum(diag(R_g))/N_g. Raw sums are also saved in the MAT files.
% sharedPct = 100 * categoryRaw / sum(raw for selected shared latents)
% totalPct  = 100 * categoryRaw / (selected shared raw + ALL neuron R)
% For DSL-filtered results, the total denominator is FILTERED shared + R;
% the filtered-total plots are therefore labelled accordingly.
% Across and Within partition shared; FF/FB/Ambiguous partition Across.
% These five displayed latent categories OVERLAP and must not be stacked.
% DSL.logical is reproduced from the original Latents_compare.m, including
% the rule for jointly retaining across latents in both groups.

clc; clear;

%% ------------------------------- Settings -----------------------------
dat_file = fullfile('.', 'model_data_allruns.mat');
% Change this to the shuffled model_data_allruns MAT when runIdx = 2.
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';
data_content = 'demean_count_within_t_and_condition';
% Other data_content values are supported if matching condition fits exist.
runIdx = 1;                   % 1: original data; 2: shuffled data
data_condtion = 1:16;         % condition-specific model IDs only
group_names = {'V1','MT'};    % display names in model-group order
DSL_threshold = 0.3;

save_mat = true;
save_png = true;
save_fig = false;
png_dpi = 300;
close_after_save = true;
plot_individual_condition_figures = false; % extra per-condition bar plots
plot_individual_DSL_histograms = true;

%% ------------------------------- Input --------------------------------
if isempty(data_condtion) || any(~isfinite(data_condtion)) || ...
        any(data_condtion ~= round(data_condtion)) || any(data_condtion < 1) || ...
        numel(unique(data_condtion)) ~= numel(data_condtion)
    error('data_condtion must contain unique positive condition IDs.');
end
if ~isscalar(DSL_threshold) || ~isfinite(DSL_threshold) || ...
        ~isscalar(runIdx) || ~isfinite(runIdx) || ...
        runIdx < 1 || runIdx ~= round(runIdx)
    error('Invalid DSL_threshold or runIdx.');
end
if ~(isnumeric(png_dpi) && isscalar(png_dpi) && ...
        isfinite(png_dpi) && png_dpi > 0)
    error('png_dpi must be a positive number.');
end
input = load(dat_file, 'model_data_allruns');
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
condition_full = metadata.conditions_full;
condition_list = reshape(double(data_condtion),1,[]);
if any(condition_list > numel(condition_full))
    error('Condition IDs exceed conditions_full length.');
end
conditionMap = conditionMapLocal(condition_full,condition_list);
group_names = cellstr(string(group_names(:)'));
if isempty(group_names) || any(cellfun(@isempty,group_names))
    error('group_names must contain one nonempty label per model group.');
end
make_plots = save_png || save_fig;
AllConditionResults = struct([]);

%% -------------------- Each independently fitted condition -------------
for ci = 1:numel(condition_list)
    this_condition = condition_list(ci);
    baseDir = sprintf('FA_Dlag_%s_condition%d',data_content,this_condition);
    resultDir = fullfile(baseDir,'mat_results',sprintf('run%03d',runIdx));
    bestFile = exactlyOneFileLocal(resultDir,'bestmodel*');
    bootFile = exactlyOneFileLocal(resultDir,'bootstrapResults*');
    B = load(bestFile,'bestModel','seqEst','varexp','varexp_total', ...
        'varexp_raw','independent_noise_var','gp_params');
    needed = {'bestModel','seqEst','varexp','varexp_total', ...
        'varexp_raw','independent_noise_var','gp_params'};
    for k = 1:numel(needed)
        if ~isfield(B,needed{k})
            error('Missing %s in %s; run plot_dlag_results_for_each_condtion_mode_var.m first.', ...
                needed{k},bestFile);
        end
    end
    P = load(bootFile,'ambiguousIdxs');
    if ~isfield(P,'ambiguousIdxs')
        error('Missing ambiguousIdxs in %s.',bootFile);
    end
    raw = B.varexp_raw;
    noise = B.independent_noise_var;
    if ~isfield(raw,'meta') || ~isfield(raw.meta,'condition_id') || ...
            raw.meta.condition_id ~= this_condition || ...
            ~strcmp(char(raw.meta.data_content),data_content) || ...
            raw.meta.runIdx ~= runIdx
        error('Variance metadata do not match condition %d in %s.', ...
            this_condition,bestFile);
    end
    nGroups = numel(raw.by_neuron);
    if numel(group_names) ~= nGroups || numel(noise.by_neuron) ~= nGroups || ...
            numel(B.bestModel.xDim_within) ~= nGroups
        error('Model-group counts disagree in %s.',bestFile);
    end
    if ci > 1 && numel(AllConditionResults(1).Stats.group) ~= nGroups
        error('Model-group count changed across conditions.');
    end
    acrossDim = B.bestModel.xDim_across;
    withinDims = reshape(B.bestModel.xDim_within,1,[]);

    % Same DSL computation and across-group joint keep rule as old script.
    [DSL,DSL_hist_stats] = computeDSLOriginalLocal( ...
        acrossDim,withinDims,B.seqEst,DSL_threshold,group_names);
    classification = classifyLatentsLocal( ...
        acrossDim,B.gp_params,P.ambiguousIdxs);

    Stats = struct();
    Stats.labels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
    Stats.meta.condition_id = this_condition;
    Stats.meta.group_names = group_names;
    Stats.meta.xDim_across = acrossDim;
    Stats.meta.xDim_within = withinDims;
    Stats.meta.DSL_threshold = DSL_threshold;
    Stats.meta.filtered_total_definition = 'retained shared variance plus all independent noise';
    Stats.classification = classification;

    for g = 1:nGroups
        localDim = acrossDim + withinDims(g);
        if ci > 1 && ~isequal( ...
                AllConditionResults(1).Stats.group(g).unit_ids(:), ...
                raw.unit_ids_by_group{g}(:))
            error('Model neuron IDs/order changed across conditions in group %d.',g);
        end
        if size(raw.by_neuron{g},1) ~= raw.n_neurons(g) || ...
                size(raw.by_neuron{g},2) ~= localDim || ...
                numel(noise.by_neuron{g}) ~= raw.n_neurons(g) || ...
                numel(raw.indiv{g}) ~= localDim || ...
                numel(B.varexp.indiv{g}) ~= localDim || ...
                numel(B.varexp_total.indiv{g}) ~= localDim || ...
                numel(DSL.logical{g}) ~= localDim
            error('Variance/DSL dimensions disagree for condition %d group %d.', ...
                this_condition,g);
        end
        if raw.shared_sum(g) > 0
            expected = raw.indiv{g} / raw.shared_sum(g);
            if any(abs(expected(:) - B.varexp.indiv{g}(:)) > 1e-7)
                error('Original varexp mismatch in %s, group %d.',bestFile,g);
            end
        end
        masks = categoryMasksLocal(localDim,acrossDim,classification);
        Stats.group(g).name = group_names{g};
        Stats.group(g).unit_ids = raw.unit_ids_by_group{g};
        Stats.group(g).n_neurons = raw.n_neurons(g);
        Stats.group(g).DSL_keep_mask = logical(DSL.logical{g});
        Stats.group(g).all = groupSummaryLocal(raw,noise,g, ...
            true(1,localDim),masks,Stats.labels);
        Stats.group(g).filtered = groupSummaryLocal(raw,noise,g, ...
            logical(DSL.logical{g}),masks,Stats.labels);

        if make_plots && plot_individual_DSL_histograms
            f = plotDSLHistogramLocal(DSL_hist_stats(g), ...
                sprintf('%s - condition %02d DSL',group_names{g},this_condition));
            saveFigureLocal(f,resultDir, ...
                sprintf('ecv_c%02d_g%d_DSL',this_condition,g), ...
                save_png,save_fig,png_dpi,close_after_save);
        end
        if make_plots && plot_individual_condition_figures
            modes = {'all','filtered'};
            for mi = 1:numel(modes)
                mode = modes{mi};
                S = Stats.group(g).(mode);
                specs = {'raw_mean','percent_shared','percent_total','percent_latents'};
                for si = 1:numel(specs)
                    spec = specs{si};
                    lbl = Stats.labels;
                    if ismember(spec,{'raw_mean','percent_total'})
                        lbl{end+1} = 'Independent noise';
                    end
                    f = figure('Position',[100,100,1100,540]);
                    bar(S.(spec),'FaceColor',[0.45,0.45,0.45]);
                    set(gca,'XTick',1:numel(lbl),'XTickLabel',lbl);
                    xtickangle(30); ylabel(metricLabelLocal(spec,mode));
                    title(sprintf('%s, condition %02d, %s', ...
                        group_names{g},this_condition,mode),'Interpreter','none');
                    saveFigureLocal(f,resultDir, ...
                        sprintf('ecv_c%02d_g%d_%s_%s',this_condition,g,mode,spec), ...
                        save_png,save_fig,png_dpi,close_after_save);
                end
            end
        end
    end

    if save_mat
        save(fullfile(resultDir,'eachcond_variance_DSL_stats.mat'), ...
            'Stats','DSL','DSL_hist_stats','this_condition', ...
            'data_content','runIdx','group_names','-v7.3');
    end
    AllConditionResults(ci).condition = this_condition;
    AllConditionResults(ci).Stats = Stats;
    AllConditionResults(ci).DSL = DSL;
    AllConditionResults(ci).DSL_hist_stats = DSL_hist_stats;
    AllConditionResults(ci).bestmodel_file = bestFile;
    fprintf('Processed condition %d (%d/%d).\n', ...
        this_condition,ci,numel(condition_list));
end

%% ---------------------- Eight features x two directions ---------------
SummaryDSL = summarizeDSLAllConditionsLocal( ...
    AllConditionResults,DSL_threshold,group_names);
SummaryVariance = summarizeConditionsLocal( ...
    AllConditionResults,conditionMap,group_names,data_content,runIdx,DSL_threshold);
if save_mat
    summaryFile = sprintf('%s_run%03d_eachcond_variance_DSL_summary.mat', ...
        data_content,runIdx);
    save(summaryFile,'AllConditionResults','SummaryDSL','SummaryVariance', ...
        'condition_list','conditionMap','data_content','runIdx', ...
        'stim_tag','DSL_threshold','group_names','-v7.3');
    fprintf('Saved %s\n',summaryFile);
end

if make_plots
    for g = 1:numel(group_names)
        pooled = SummaryDSL.group(g).histogram;
        f = plotDSLHistogramLocal(pooled, ...
            sprintf('%s DSL distribution (all selected conditions)',group_names{g}));
        saveFigureLocal(f,'.', ...
            sprintf('%s_run%03d_ecv_g%d_DSL_all',data_content,runIdx,g), ...
            save_png,save_fig,png_dpi,close_after_save);
    end
    modes = {'all','filtered'};
    specs = {'raw_mean','percent_shared','percent_total','percent_latents'};
    for g = 1:numel(group_names)
        safeGroup = regexprep(lower(group_names{g}),'[^a-z0-9]+','_');
        for mi = 1:numel(modes)
            mode = modes{mi};
            for si = 1:numel(specs)
                spec = specs{si};
                labels = SummaryVariance.labels;
                if ismember(spec,{'raw_mean','percent_total'})
                    labels{end+1} = 'Independent noise';
                end
                D1 = SummaryVariance.group(g).(mode).stim_dir(1).(spec);
                D2 = SummaryVariance.group(g).(mode).stim_dir(2).(spec);
                fig = plotTwoDirectionBarsLocal(D1,D2,labels, ...
                    SummaryVariance.meta.conditionShortLabels, ...
                    SummaryVariance.meta.dirTitles, ...
                    sprintf('%s - %s - %s',group_names{g},mode,spec), ...
                    metricLabelLocal(spec,mode));
                filename = sprintf('%s_run%03d_ecv_g%d_%s_%s_%s', ...
                    data_content,runIdx,g,safeGroup,mode,spec);
                saveFigureLocal(fig,'.',filename, ...
                    save_png,save_fig,png_dpi,close_after_save);
            end
        end
    end
end

function S = summarizeDSLAllConditionsLocal(allResults,threshold,groupNames)
    S.meta.conditions = [allResults.condition];
    S.meta.threshold = threshold;
    S.meta.group_names = groupNames;
    for g = 1:numel(groupNames)
        vals = [];
        condIds = [];
        for ci = 1:numel(allResults)
            x = allResults(ci).DSL.indiv{g};
            x = x(isfinite(x));
            vals = [vals,x]; %#ok<AGROW>
            condIds = [condIds, ...
                repmat(allResults(ci).condition,1,numel(x))]; %#ok<AGROW>
        end
        S.group(g).name = groupNames{g};
        S.group(g).values = vals;
        S.group(g).conditionMembership = condIds;
        S.group(g).histogram = histogramStatsLocal(vals,threshold);
    end
end

%% ============================ Helpers ==================================
function path = exactlyOneFileLocal(folder,pattern)
    d = dir(fullfile(folder,pattern));
    d = d(~[d.isdir]);
    if numel(d) ~= 1
        error('Expected exactly one %s in %s, found %d.',pattern,folder,numel(d));
    end
    path = fullfile(d(1).folder,d(1).name);
end

function C = classifyLatentsLocal(acrossDim,gp_params,ambiguousIdxs)
    if acrossDim == 0
        d = [];
    else
        if ~isfield(gp_params,'delays') || ...
                numel(gp_params.delays) < acrossDim
            error('gp_params.delays is missing or shorter than xDim_across.');
        end
        d = reshape(gp_params.delays,1,[]);
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

function S = groupSummaryLocal(raw,noise,g,keep,masks,labels)
    keep = reshape(logical(keep),1,[]);
    meanLat = reshape(raw.mean_per_neuron{g},1,[]);
    sumLat = reshape(raw.indiv{g},1,[]);
    if numel(meanLat) ~= numel(keep) || numel(sumLat) ~= numel(keep)
        error('Latent keep mask has the wrong length in group %d.',g);
    end
    K = numel(masks);
    vMean = zeros(1,K);
    vSum = zeros(1,K);
    counts = zeros(1,K);
    for j = 1:K
        idx = keep & masks{j};
        vMean(j) = sum(meanLat(idx));
        vSum(j) = sum(sumLat(idx));
        counts(j) = nnz(idx);
    end
    sharedMean = sum(meanLat(keep));
    sharedSum = sum(sumLat(keep));
    noiseMean = noise.mean_per_neuron(g);
    noiseSum = noise.sum(g);
    totalMean = sharedMean + noiseMean;
    totalSum = sharedSum + noiseSum;
    S.labels = labels;
    S.keepMask = keep;
    S.nLatents = nnz(keep);
    S.n_neurons = raw.n_neurons(g);
    S.counts = counts;
    S.raw_mean = [vMean,noiseMean];
    S.raw_sum = [vSum,noiseSum];
    S.denominator.shared_mean = sharedMean;
    S.denominator.shared_sum = sharedSum;
    S.denominator.total_mean = totalMean;
    S.denominator.total_sum = totalSum;
    S.percent_shared = nan(1,K); % R has no shared-percent entry
    S.percent_total = nan(1,K+1);
    if sharedMean > 0
        S.percent_shared = 100 * vMean / sharedMean;
    end
    if totalMean > 0
        S.percent_total = 100 * S.raw_mean / totalMean;
    end
    if nnz(keep) > 0
        S.percent_latents = 100 * counts / nnz(keep);
    else
        S.percent_latents = zeros(1,K);
    end
    if abs(sharedSum / raw.n_neurons(g) - sharedMean) > ...
            1e-8 * max(1,sharedMean) || ...
            abs(totalSum / raw.n_neurons(g) - totalMean) > ...
            1e-8 * max(1,totalMean)
        error('Raw sums and per-neuron means do not agree.');
    end
    tol = 1e-8 * max(1,totalMean);
    if abs(vMean(1) + vMean(2) - sharedMean) > tol || ...
            abs(vMean(3) + vMean(4) + vMean(5) - vMean(1)) > tol
        error('Across/Within or FF/FB/Ambiguous variance does not partition.');
    end
end

function S = summarizeConditionsLocal(allResults,map,groupNames,dataContent,runIdx,threshold)
    nGroups = numel(groupNames);
    S.labels = allResults(1).Stats.labels;
    S.meta.data_content = dataContent;
    S.meta.runIdx = runIdx;
    S.meta.DSL_threshold = threshold;
    S.meta.conditionMap = map;
    S.meta.conditionShortLabels = map.shortLabels;
    S.meta.dirValues = map.dirValues;
    S.meta.dirTitles = {sprintf('stim dir1 = %g',map.dirValues(1)), ...
                        sprintf('stim dir2 = %g',map.dirValues(2))};
    S.meta.group_names = groupNames;
    S.meta.rawUnit = 'squared units of the selected data_content per model neuron';
    S.meta.filteredTotal = 'retained shared variance plus all independent noise';
    modes = {'all','filtered'};
    for g = 1:nGroups
        S.group(g).name = groupNames{g};
        for mi = 1:2
            mode = modes{mi};
            for d = 1:2
                V = struct();
                V.conditionIds = nan(8,1);
                V.n_neurons = nan(8,1);
                V.raw_mean = nan(8,6);
                V.raw_sum = nan(8,6);
                V.percent_shared = nan(8,5);
                V.percent_total = nan(8,6);
                V.percent_latents = nan(8,5);
                V.counts = nan(8,5);
                V.nLatents = nan(8,1);
                V.shared_mean = nan(8,1);
                V.total_mean = nan(8,1);
                for ci = 1:numel(allResults)
                    cond = allResults(ci).condition;
                    idx = find([map.entries.conditionId] == cond);
                    if numel(idx) ~= 1
                        error('Cannot map condition %d exactly once.',cond);
                    end
                    e = map.entries(idx);
                    if e.dirCode ~= d
                        continue;
                    end
                    p = e.featureCode;
                    if ~isnan(V.conditionIds(p))
                        error('Duplicate direction/feature condition assignment.');
                    end
                    A = allResults(ci).Stats.group(g).(mode);
                    V.conditionIds(p) = cond;
                    V.n_neurons(p) = A.n_neurons;
                    V.raw_mean(p,:) = A.raw_mean;
                    V.raw_sum(p,:) = A.raw_sum;
                    V.percent_shared(p,:) = A.percent_shared;
                    V.percent_total(p,:) = A.percent_total;
                    V.percent_latents(p,:) = A.percent_latents;
                    V.counts(p,:) = A.counts;
                    V.nLatents(p) = A.nLatents;
                    V.shared_mean(p) = A.denominator.shared_mean;
                    V.total_mean(p) = A.denominator.total_mean;
                end
                S.group(g).(mode).stim_dir(d) = V;
            end
        end
    end
end

function map = conditionMapLocal(full,ids)
% Match the original Latents_compare mapping, including angle wrapping.
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
        sizeCode = find(abs(sizes(c)-sizeValues)<1e-10);
        contrastCode = find(abs(contrasts(c)-levels{stimCode})<1e-10);
        dirCode = find(abs(dirs(c)-dirValues)<1e-10);
        if numel(stimCode) ~= 1 || numel(sizeCode) ~= 1 || ...
                numel(contrastCode) ~= 1 || numel(dirCode) ~= 1
            error('Condition %d has an invalid feature/direction mapping.',c);
        end
        p = (stimCode-1)*4 + (sizeCode-1)*2 + contrastCode;
        entries(i).conditionId = c;
        entries(i).featureCode = p;
        entries(i).dirCode = dirCode;
        entries(i).direction = dirs(c);
        entries(i).label = short{p};
    end
    map.entries = entries;
    map.shortLabels = short;
    map.dirValues = dirValues;
end

function fig = plotTwoDirectionBarsLocal(A,B,labels,conditions,panels,titleText,yText)
    colors = lines(8);
    fig = figure('Position',[80,80,1500,820]);
    layout = tiledlayout(fig,1,2,'Padding','compact', ...
        'TileSpacing','compact');
    for d = 1:2
        ax = nexttile(layout,d);
        if d == 1
            values = A;
        else
            values = B;
        end
        bars = bar(ax,values');
        for j = 1:numel(bars)
            bars(j).FaceColor = colors(j,:);
            bars(j).EdgeColor = 'none';
        end
        set(ax,'XTick',1:numel(labels),'XTickLabel',labels);
        xtickangle(ax,30);
        xlabel(ax,'Variance component');
        ylabel(ax,yText);
        title(ax,panels{d});
        finiteVals = [A(isfinite(A));B(isfinite(B))];
        if isempty(finiteVals) || max(finiteVals)<=0
            top = 1;
        else
            top = max(finiteVals)*1.12;
        end
        if contains(yText,'(%)')
            top = max(100,top);
        end
        ylim(ax,[0,top]);
        if d == 1
            legendBars = bars;
        end
    end
    legendHandle = legend(legendBars,conditions,'Location','southoutside', ...
        'Orientation','horizontal');
    legendHandle.NumColumns = 4;
    legendHandle.Layout.Tile = 'south';
    sgtitle(layout,titleText,'Interpreter','none');
end

function label = metricLabelLocal(spec,mode)
    switch spec
        case 'raw_mean'
            label = 'Raw model variance per neuron';
        case 'percent_shared'
            label = 'Percentage of retained shared variance (%)';
        case 'percent_total'
            if strcmp(mode,'filtered')
                label = 'Percentage of filtered shared + independent noise (%)';
            else
                label = 'Percentage of model total variance (%)';
            end
        case 'percent_latents'
            label = 'Percentage of retained latents (%)';
        otherwise
            error('Unknown metric %s.',spec);
    end
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

function fig = plotDSLHistogramLocal(H,titleText)
    fig = figure('Position',[100,100,750,500]);
    bar(H.centers,H.percentages,1);
    xline(H.threshold,'--','LineWidth',1.5);
    xlabel('DSL'); ylabel('Percentage of latents (%)');
    title(titleText,'Interpreter','none');
    xlim([H.edges(1),H.edges(end)]);
end

function H = histogramStatsLocal(vals,threshold)
    vals = vals(isfinite(vals));
    width = 0.05;
    if isempty(vals)
        vals = [0,1];
        nValid = 0;
    else
        nValid = numel(vals);
    end
    first = min(floor(min(vals)/width)*width, ...
        floor(threshold/width)*width)-width;
    last = max(ceil(max(vals)/width)*width, ...
        ceil(threshold/width)*width)+width;
    edges = first:width:last;
    if numel(edges)<2
        edges = [first,first+width];
    end
    H.values = vals(1:nValid);
    H.edges = edges;
    H.centers = edges(1:end-1)+diff(edges)/2;
    H.counts = histcounts(H.values,edges);
    H.percentages = zeros(size(H.counts));
    if nValid>0
        H.percentages = 100 * H.counts / nValid;
    end
    H.threshold = threshold;
end

function [DSL,histStats] = computeDSLOriginalLocal(a,w,seqEst,threshold,groupNames)
% Identical scoring and threshold/AND semantics to Latents_compare.m.
    w = reshape(w,1,[]);
    localDims = a+w;
    nGroups = numel(w);
    if isempty(seqEst) || numel(groupNames) ~= nGroups
        error('Invalid DSL input: empty trials or group-name mismatch.');
    end
    for tr = 1:numel(seqEst)
        if ~isfield(seqEst(tr),'xsm') || ...
                size(seqEst(tr).xsm,1) ~= sum(localDims) || ...
                size(seqEst(tr).xsm,2) < 2
            error('seqEst(%d).xsm has unexpected dimensions.',tr);
        end
    end
    if isfield(seqEst,'trialId')
        try
            [~,ord] = sort([seqEst.trialId]);
            seqEst = seqEst(ord);
        catch
        end
    end
    nTrials = numel(seqEst);
    lengthPerTrial = arrayfun(@(s) size(s.xsm,2),seqEst);
    tmin = min(lengthPerTrial);
    tmax = max(lengthPerTrial);
    lags = -(tmin-1):(tmin-1);
    start = 1 + [0,cumsum(localDims(1:end-1))];
    DSL.indiv = cell(1,nGroups);
    DSL.rawlogical = cell(1,nGroups);
    DSL.logical = cell(1,nGroups);
    DSL.meta.group_names = groupNames;
    DSL.meta.threshold = threshold;
    for g = 1:nGroups
        DSL.indiv{g} = nan(1,localDims(g));
        DSL.rawlogical{g} = zeros(1,localDims(g));
        for j = 1:localDims(g)
            row = start(g)+j-1;
            X = zeros(nTrials,tmax);
            M = false(nTrials,tmax);
            for tr = 1:nTrials
                x = seqEst(tr).xsm(row,:);
                T = numel(x);
                X(tr,1:T) = x;
                M(tr,1:T) = true;
            end
            ACG = meanACGOriginalLocal(X,M,lags);
            if nTrials >= 2
                CCG = meanCCGOriginalLocal(X,M,lags);
            else
                CCG = nan(1,numel(lags));
            end
            if all(isnan(ACG)) || all(isnan(CCG))
                score = NaN;
            else
                numerator = trapz(lags,abs(ACG-CCG));
                denominator = trapz(lags,abs(ACG));
                if ~isfinite(denominator) || denominator <= eps
                    score = NaN;
                else
                    score = 1-numerator/denominator;
                end
            end
            DSL.indiv{g}(j) = score;
            DSL.rawlogical{g}(j) = isnan(score) || score<threshold;
        end
        DSL.logical{g} = DSL.rawlogical{g};
    end
    for j = 1:a
        commonKeep = true;
        for g = 1:nGroups
            commonKeep = commonKeep && (DSL.rawlogical{g}(j)==1);
        end
        for g = 1:nGroups
            DSL.logical{g}(j) = commonKeep;
        end
    end
    histStats = repmat(histogramStatsLocal([],threshold),1,nGroups);
    for g = 1:nGroups
        histStats(g) = histogramStatsLocal(DSL.indiv{g},threshold);
    end
end

function ACG = meanACGOriginalLocal(X,M,lags)
    nTrials = size(X,1);
    ACG = nan(1,numel(lags));
    den = sum((X.^2).*M,2);
    valid = den>eps;
    for k = 1:numel(lags)
        lag = lags(k);
        if lag>=0
            A = X(:,1+lag:end);
            B = X(:,1:end-lag);
            V = M(:,1+lag:end) & M(:,1:end-lag);
        else
            e = -lag;
            A = X(:,1:end-e);
            B = X(:,1+e:end);
            V = M(:,1:end-e) & M(:,1+e:end);
        end
        numerator = sum((A.*B).*V,2);
        correlation = nan(nTrials,1);
        correlation(valid) = numerator(valid)./den(valid);
        ACG(k) = mean(correlation,'omitnan');
    end
end

function CCG = meanCCGOriginalLocal(X,M,lags)
    X1 = X(1:end-1,:);
    X2 = X(2:end,:);
    M1 = M(1:end-1,:);
    M2 = M(2:end,:);
    nPairs = size(X1,1);
    CCG = nan(1,numel(lags));
    den = sqrt(sum((X1.^2).*M1,2).*sum((X2.^2).*M2,2));
    valid = den>eps;
    for k = 1:numel(lags)
        lag = lags(k);
        if lag>=0
            A = X1(:,1+lag:end);
            B = X2(:,1:end-lag);
            V = M1(:,1+lag:end) & M2(:,1:end-lag);
        else
            e = -lag;
            A = X1(:,1:end-e);
            B = X2(:,1+e:end);
            V = M1(:,1:end-e) & M2(:,1+e:end);
        end
        numerator = sum((A.*B).*V,2);
        correlation = nan(nPairs,1);
        correlation(valid) = numerator(valid)./den(valid);
        CCG(k) = mean(correlation,'omitnan');
    end
end
