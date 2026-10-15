%% plot_dlag_results_for_each_condtion_mode_var.m
% Run the original post-fit DLAG analysis for SEPARATELY TRAINED condition
% models and add model-based variance components to each bestmodel MAT.
%
% Per model group, latent j, and neuron n:
%   varexp_raw.by_neuron{g}(n,j) = C_g(n,j)^2
%   independent_noise_var.by_neuron{g}(n) = R_g(n,n)
% The raw group sum and average PER NEURON are both saved. The old varexp
% (fraction of shared variance) is kept unchanged. varexp_total is the
% original DLAG function with total=true. Percentage values displayed by
% the companion script are 100 times these fractions.
% Run this script after train_dlag_by_condition.m. The matching dat_file,
% data_content, condition IDs, and runIdx must identify the same fits.
% Existing bestmodel variables, including reconstruction results appended by
% other analyses, are preserved; new fields are appended after model checks.
% -------------------------------------------------------------------------
clc;clear
dat_file = fullfile('.', 'model_data_allruns.mat');
% For shuffled results, set dat_file to the matching shuffled MAT and
% runIdx=2. Different data_content choices remain supported.
fprintf('Reading from %s \n',dat_file);
load(dat_file);
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';
data_content = 'demean_count_within_t_and_condition';  
data_condtion = 1:16; % condition-specific fits only; nonempty
usebest=1; %1 means use best xDim_total_fa,0 means use xDim_opt_fa 95% csve
runIdx = 1; % 1: original data; 2: independently shuffled units
reuse_existing_bestmodel = true; % append only new variance fields if available


% options:
% raw_count, raw_fr, z_within_trial, z_within_condition, 
% z_across_conditions, demean_count_within_trial, demean_fr_within_trial, demean_pooledsd_within_condition, demean_count_within_t_and_condition

% Extract all stim tags
all_run_tags = get_all_run_tags(model_data_allruns);


wanted_tag =stim_tag;


% Find the requested run by exact stim_tag match.
run_idx = find(strcmp(all_run_tags, wanted_tag));

if isempty(run_idx)
    error('Requested stim_tag not found %s', wanted_tag);
end

if numel(run_idx) > 1
    error('Duplicate stim_tag found %s', wanted_tag);
end


% -------------------------------------------------------------------------
% Get the selected run entry
% -------------------------------------------------------------------------
this_run = model_data_allruns{run_idx};

% Check the condition-specific data, without an all-condition branch.
condition_field = [data_content, '_by_condition'];
if ~isfield(this_run, condition_field)
    error('Field %s not found in model_data_allruns{%d}.', condition_field, run_idx);
end

% Bin width in ms
binWidth = this_run.bin_size * 1000;  % Sample period / spike count bin width, in units of time (e.g., ms)

% -------------------------------------------------------------------------
% Get yDims
% If nan_trial_strategy == 6, groupd is data-field-specific
% Otherwise use the shared groupd
% -------------------------------------------------------------------------
if isfield(this_run, 'nan_trial_strategy') && this_run.nan_trial_strategy == 6
    groupd_field = sprintf('%s_groupd', data_content);

    if ~isfield(this_run, groupd_field)
        error('For nan_trial_strategy == 6, field %s is missing.', groupd_field);
    end

    yDims = this_run.(groupd_field);  % Number of observed features (neurons) in each group (area)
else
    if ~isfield(this_run, 'groupd')
        error('Field groupd is missing in model_data_allruns{%d}.', run_idx);
    end

    yDims = this_run.groupd;  % Number of observed features (neurons) in each group (area)
end

xDims = {0:yDims(1)-1, 0:yDims(2)-1}; % Sweep over these dimensionalities


cond_list = data_condtion(:)';
if isempty(cond_list) || any(~isfinite(cond_list)) || ...
        any(cond_list ~= round(cond_list)) || ...
        any(cond_list < 1) || any(cond_list > numel(this_run.(condition_field))) || ...
        numel(unique(cond_list)) ~= numel(cond_list)
    error('data_condtion must be nonempty, unique valid condition IDs.');
end

[unit_ids_by_group, ids_yDims] = modelUnitIdsByGroupLocal(this_run, data_content);
if ~isequal(ids_yDims, reshape(double(yDims), 1, []))
    error('Metadata unit-ID group sizes do not match model group sizes.');
end

% ================== CONDITION LOOP START ==================
loop_range = cond_list;

for cond_i = 1:length(loop_range)

    cond_val = loop_range(cond_i);
    baseDir = ['./FA_Dlag_',data_content,'_condition',num2str(cond_val)];
    seqTrue = this_run.(condition_field)(cond_val).trials;
    if isempty(seqTrue)
        error('Condition %d contains no trials in %s.', cond_val, condition_field);
    end

rGroups = [1 2];          % For performance evaluation, we can regress group 2's activity with group 1

% If parallelize is true, all cross-validation folds and bootstrap samples
% will be analyzed in parallel using Matlab's parfor construct. 
% If you have access to multiple cores, this provides significant speedup.
parallelize = false;
numWorkers = 2;      % Adjust this to your computer's specs

tempfname = sprintf('%s/mat_results/run%03d', baseDir, runIdx);
if reuse_existing_bestmodel
    existing = dir(fullfile(tempfname,'bestmodel*'));
    existing = existing(~[existing.isdir]);
    existingBoot = dir(fullfile(tempfname,'bootstrapResults*'));
    existingBoot = existingBoot(~[existingBoot.isdir]);
    if numel(existing) > 1
        error('Multiple bestmodel files in %s; cannot select a unique model.',tempfname);
    end
    if numel(existingBoot) > 1
        error('Multiple bootstrapResults files in %s.',tempfname);
    end
    canReuse = numel(existing) == 1 && numel(existingBoot) == 1;
    if canReuse
        bootPath = fullfile(existingBoot(1).folder,existingBoot(1).name);
        canReuse = any(strcmp(who('-file',bootPath),'ambiguousIdxs'));
    end
    if canReuse
        existingPath = fullfile(existing(1).folder,existing(1).name);
        savedNames = who('-file',existingPath);
        if ~all(ismember({'res','varexp','bestModel','seqEst','gp_params'},savedNames))
            error('Existing %s lacks original bestmodel variables.',existingPath);
        end
        old = load(existingPath,'res','varexp','bestModel');
        if ~isfield(old.res,'estParams') || ...
                ~isequal(reshape(double(old.res.estParams.yDims),1,[]), ...
                          reshape(double(yDims),1,[])) || ...
                ~isequal(reshape(double(old.bestModel.xDim_within),1,[]), ...
                          reshape(double(old.res.estParams.xDim_within),1,[])) || ...
                old.bestModel.xDim_across ~= old.res.estParams.xDim_across
            error('Existing %s is inconsistent with selected run and group sizes.', ...
                existingPath);
        end
        [varexp_total,~] = computeVarExp_dlag(old.res.estParams,true);
        [varexp_raw,independent_noise_var] = ...
            computeRawVarianceLocal(old.res.estParams,unit_ids_by_group);
        varexp_raw.meta.condition_id = cond_val;
        varexp_raw.meta.data_content = data_content;
        varexp_raw.meta.runIdx = runIdx;
        varexp_raw.meta.stim_tag = stim_tag;
        verifyVarianceFractionsLocal(old.varexp,varexp_total, ...
            varexp_raw,independent_noise_var);
        save(existingPath,'varexp_total','varexp_raw', ...
            'independent_noise_var','-append');
        fprintf('Condition %d: appended variance to existing %s.\n', ...
            cond_val,existingPath);
        continue;
    end
    if numel(existing) == 1
        fprintf('Condition %d: bootstrap results missing; running full analysis.\n',cond_val);
    end
end
%% Inspect full cross-validation results
[cvResults, bestModels] = getCrossValResults_fa(runIdx, 'baseDir', baseDir);

% Plot cross-validated performance vs estimated dimensionality
plotPerfvsDim_fa(cvResults, ...
                 'bestModels', bestModels);

savefig([tempfname,'/FA_cv_results.fig'])
exportgraphics(gcf, [tempfname,'/FA_cv_results.png'])


if any(bestModels(:) == 1)
    % The original script left xDims_grid undefined in this case.
    if usebest == 0
        warning('At least one FA best dimension is zero; using FA best dimensions.');
    end
    xDim_total_fa = nan(1, numel(yDims));
    for groupIdx = 1:numel(yDims)
        xDim_total_fa(groupIdx) = cvResults{groupIdx}(bestModels(groupIdx)).xDim;
    end
    xDims_grid = construct_xDimsGrid(xDim_total_fa);
else


% Collect the optimal total dimensionality for each group.
numGroups = length(yDims);
xDim_total_fa = nan(1,numGroups);
for groupIdx = 1:numGroups
    xDim_total_fa(groupIdx) = cvResults{groupIdx}(bestModels(groupIdx)).xDim;
end

if usebest==1

xDims_grid = construct_xDimsGrid(xDim_total_fa);

elseif  usebest==0
%% here we are not use bestmodel, we use bestmodel with full data (cvResults.estParams), do LL' decomposition, to get lowest d can explain 0.95 shared var
%% code modified  decomposition and choose optd modified  CrossValFa and FactorAnalysisModelSelect(semedo paper)
csve=cell(length(yDims),1); %cumulative shared variance explained by the latent dimensions
 for groupIdx = 1:numGroups; 
% best factor number
if xDims{groupIdx}(bestModels(groupIdx)) == 0
    csve{groupIdx} = NaN;
else

    L = cvResults{groupIdx}(bestModels(groupIdx)).estParams.C;
    d = sort( eig( L*L' ), 'descend' );
    
    temp_cvLoss = (cumsum(d)/sum(d))';

    if xDims{groupIdx}(1) == 0
        temp_cvLoss = [0 temp_cvLoss];
        csve{groupIdx} = temp_cvLoss(xDims{groupIdx}+ 1);
    else
        csve{groupIdx} = temp_cvLoss(xDims{groupIdx});
    end
end

VAR_TRESHOLD = .95;  

if isnan(csve{groupIdx})
    xDim_opt_fa(groupIdx) = 0;
else
    xDim_opt_fa(groupIdx) = xDims{groupIdx}( find( csve{groupIdx} > VAR_TRESHOLD, 1 ) );   %d shared dimensionality 
end

 end

plotCSVEvsDim(csve, xDims, xDim_opt_fa);

savefig([tempfname,'/FA_cv_95dresults.fig'])
exportgraphics(gcf, [tempfname,'/FA_cv_95dresults.png'])

xDims_grid = construct_xDimsGrid(xDim_opt_fa);
end
%% Inspect cross-validation results
% Retrieve cross-validated results for all models in the results directory
[cvResults, ~] = getCrossValResults_dlag(runIdx, 'baseDir', baseDir);

% Plot a variety of performance metrics among the candidate models.
plotPerfvsDim_dlag(cvResults, 'xDims_grid', xDims_grid);

savefig([tempfname,'/Dlag_cv_results.fig'])
exportgraphics(gcf, [tempfname,'/Dlag_cv_results.png'])

% Select the model with the optimal number among candidates
bestModel = getNumAcrossDim_dlag(cvResults, xDims_grid);

%% =============================================================
% 3a) Evaluate how significantly each set of across-group delays
%     deviates from zero.
%  =============================================================

% Retrieve the best DLAG model
xDim_across = bestModel.xDim_across;
xDim_within = bestModel.xDim_within;
res = getModel_dlag(runIdx, xDim_across, xDim_within, 'baseDir', baseDir);

% Save all bootstrap results to a file
boot_fname = generate_inference_fname_dlag(runIdx, ...
                                           'bootstrapResults', ...
                                           xDim_across, ...
                                           xDim_within, ...
                                           'baseDir',baseDir);
numBootstrap = 100; % Number of bootstrap samples (the more the better)
delaySig = bootstrapDelaySignificance(seqTrue, ...
                                      res.estParams, ...
                                      numBootstrap, ...
                                      'parallelize', parallelize, ...
                                      'numWorkers', numWorkers);
% Label each delay as ambiguous (0) or unambiguous (1)
alpha = 0.05; % Significance level
ambiguousIdxs = find(delaySig >= alpha);
fprintf('Indexes of ambiguous delays: %s\n', num2str(ambiguousIdxs)); 


% Visualize non-zero and statistically ambiguous delays
gp_params=plotGPparams_dlag(res.estParams, binWidth, rGroups, ...
                  'plotAcross', true, ...
                  'plotWithin', false, ...
                  'units', 'ms', ...
                  'sig', delaySig, ...
                  'alpha', alpha);

if isempty(gp_params.DelayMatrix)
    gp_params.delays=[];
else
 gp_params.delays = gp_params.DelayMatrix(rGroups(2),:) ...
           - gp_params.DelayMatrix(rGroups(1),:);
end

savefig([tempfname,'/Delay_timescale_point_es_results.fig'])
exportgraphics(gcf, [tempfname,'/Delay_timescale_point_es_results.png'])

%% ================================================================
% 3b) Construct bootstrapped confidence intervals for latent delays
%     and timescales.
%  ================================================================

alpha = 0.05; % Construct (1-alpha) confidence intervals
bootParams = bootstrapGPparams(seqTrue, ...
                               res.estParams, ...
                               binWidth, ...
                               numBootstrap, ...
                               'alpha', alpha, ...
                               'parallelize', parallelize, ...
                               'numWorkers', numWorkers, ...
                               'segLength', Inf, ...
                               'tolLL', 1e-4, ...
                               'maxIters', 10);
save(boot_fname, 'delaySig','alpha',"ambiguousIdxs",'bootParams',"numBootstrap");
plotBootstrapGPparams_dlag(res.estParams, bootParams, binWidth, rGroups,...
                           'overlayParams', false);

savefig([tempfname,'/Delay_timescale_interval_es_results.fig'])
exportgraphics(gcf, [tempfname,'/Delay_timescale_interval_es_results.png'])

%%
% covType = 'rbf';          % Type of GP covariance kernel ('rbf' or 'sg')
% rGroups = [1 2];          % For performance evaluation, we can regress group 2's activity with group 1
% startTau = 2*binWidth;    % Initial timescale, in the same units of time as binWidth
% segLength = 25;           % Largest trial segment length, in no. of time points
% init_method = 'static';   % Initialize DLAG with fitted pCCA parameters
% learnDelays = true;       % Set to false if you want to fix delays at their initial value
% 
% 
% tolLL = 1e-8;             % Log-likelihood convergence tolerance
% freqLL = 1;               % Check for data log-likelihood convergence every freqLL EM iterations
% freqParam = 10;           % Store intermediate delay and timescale estimates every freqParam EM iterations
% minVarFrac = 0.001;       % Private noise variances will not be allowed to go below this value
% verbose = true;           % Toggle printed progress updates
% randomSeed = 0;           % Seed the random number generator, for reproducibility
% 
% % Plot training progress of various quantities. These plots can help with
% % troubleshooting, if necessary.
% plotFittingProgress(res, ...
%                     'freqLL', freqLL, ...
%                     'freqParam', freqParam, ...
%                     'units', 'ms');
% 


%% ========================================================
% Plot estimated latents
[seqEst, ~] = exactInferenceWithLL_dlag(seqTrue, res.estParams);
plotDimsVsTime_dlag(seqEst, 'xsm', res.estParams, res.binWidth, ...
                  'nPlotMax', 20, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);

savefig([tempfname,'/Raw_latents_res.fig'])
exportgraphics(gcf, [tempfname,'/Raw_latents_res.png'])

% 1c) Visually scale latent trajectories by various metrics
% =========================================================

% Scale by variance explained. Preserve the original variable and method.
total = false; % true: denominator is total variance; else shared variance
[varexp, domexp] = computeVarExp_dlag(res.estParams, total);
[varexp_total, ~] = computeVarExp_dlag(res.estParams, true);
[varexp_raw, independent_noise_var] = ...
    computeRawVarianceLocal(res.estParams, unit_ids_by_group);
varexp_raw.meta.condition_id = cond_val;
varexp_raw.meta.data_content = data_content;
varexp_raw.meta.runIdx = runIdx;
varexp_raw.meta.stim_tag = stim_tag;
verifyVarianceFractionsLocal(varexp, varexp_total, varexp_raw, independent_noise_var);
[seqEst, sortParams] = scaleByVarExp(seqEst, ...
                                     res.estParams, ...
                                     varexp.indiv, ...
                                     'sortDims', true);
plotDimsVsTime_dlag(seqEst, 'xve', sortParams, res.binWidth, ...
                  'nPlotMax', 20, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);

% Scale across-area latents by zero-delay correlation,  correlative mode
popcorr = computePopCorr_dlag(res.estParams);
[seqEst, sortParams] = scaleByCorr(seqEst, ...
                                   res.estParams, ...
                                   popcorr.lcorr, ...
                                   rGroups, ...
                                   'sortDims', true);
plotDimsVsTime_dlag(seqEst, 'xcorre', sortParams, res.binWidth, ...
                  'nPlotMax', 100, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);
% correlative mode is not dominent mode.


% Scale across-area latents by zero-delay covariance
popcov = computePopCov_dlag(res.estParams);
[seqEst, sortParams] = scaleByCov(seqEst, ...
                                   res.estParams, ...
                                   popcov.lcov, ...
                                   rGroups, ...
                                   'sortDims', true);
plotDimsVsTime_dlag(seqEst, 'xcve', sortParams, res.binWidth, ...
                  'nPlotMax', 20, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);



%% ================================================
% 1d) Project latents onto different types of modes
% =================================================

% Project latents onto dominant modes
seqEst = dominantProjection_dlag(seqEst, res.estParams, ...
                                 'includeAcross', true, ...
                                 'includeWithin', true);
plotDimsVsTime(seqEst, 'xdom', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across + max(xDim_within), ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms');

savefig([tempfname,'/Projection_dom_modes_res.fig'])
exportgraphics(gcf, [tempfname,'/Projection_dom_modes_res.png'])

% Project latents onto zero-delay correlative modes
seqEst = correlativeProjection_dlag(seqEst, res.estParams,...
                                    'orth', true);
plotDimsVsTime(seqEst, 'xcorr', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across, ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms'); 

savefig([tempfname,'/Projection_corr_modes_res.fig'])
exportgraphics(gcf, [tempfname,'/Projection_corr_modes_res.png'])

% Project latents onto zero-delay covariant modes
seqEst = covariantProjection_dlag(seqEst, res.estParams);
plotDimsVsTime(seqEst, 'xcov', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across, ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms'); 

savefig([tempfname,'/Projection_cov_modes_res.fig'])
exportgraphics(gcf, [tempfname,'/Projection_cov_modes_res.png'])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Project latents onto zero-delay predictive modes
seqEst = predictiveProjection_dlag(seqEst,res.estParams, ...
                                   'orth', false, ...
                                   'groupIdxs', rGroups);
% Note that the order of rows corrsponds to the order of rGroups, where
% rGroups(1) is the source group, and rGroups(2) is the target group.
plotDimsVsTime(seqEst, 'xpred', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across, ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms');

savefig([tempfname,'/Projection_pred_modes_res.fig'])
exportgraphics(gcf, [tempfname,'/Projection_pred_modes_res.png'])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Related to dominant/covariant modes, inspect the spectra of DLAG loading 
% matrices. These give the amount of shared variance / cross-covariance 
% explained by each mode.
cutoffPC = 0.95;
d_shared = findSharedDimCutoff_dlag(res.estParams, cutoffPC, 'plotSpec', true)

savefig([tempfname,'/varexp_acrosscovexp_dom_covariant_mode.fig'])
exportgraphics(gcf, [tempfname,'/varexp_acrosscovexp_dom_covariant_mode.png'])
% Save best model details  to a file
bestm_fname = generate_inference_fname_dlag(runIdx, ...
                                           'bestmodel', ...
                                           xDim_across, ...
                                           xDim_within, ...
                                           'baseDir',baseDir);

if isfile(bestm_fname)
    % Retain any previously saved reconstructions or other variables.
    previous = load(bestm_fname, 'res', 'varexp', 'bestModel');
    if ~isfield(previous, 'res') || ~isfield(previous.res, 'estParams') || ...
            ~isfield(previous, 'varexp') || ~isfield(previous, 'bestModel')
        error('Existing %s lacks res/varexp/bestModel; refusing to append.', bestm_fname);
    end
    if ~isequaln(previous.res.estParams.C, res.estParams.C) || ...
            ~isequaln(previous.res.estParams.R, res.estParams.R) || ...
            ~isequaln(previous.bestModel.xDim_across, bestModel.xDim_across) || ...
            ~isequaln(previous.bestModel.xDim_within, bestModel.xDim_within)
        error('Existing bestmodel parameters differ: %s. Refusing to mix models.', bestm_fname);
    end
    verifyVarianceFractionsLocal(previous.varexp, varexp_total, ...
        varexp_raw, independent_noise_var);
    save(bestm_fname, 'varexp_total', 'varexp_raw', ...
        'independent_noise_var', '-append');
else
    save(bestm_fname,"bestModel","res","seqEst","varexp","domexp", ...
        "popcorr","popcov","gp_params","cutoffPC","d_shared", ...
        'varexp_total','varexp_raw','independent_noise_var');
end
close all

end
end % ================== LOOP END ==================


% % % % % % % % % % % % % % % % % % % % %% =============================================================================================
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % %% will be used in the future
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % Visualize the top three modes in 3D space
% % % % % % % % % % % % % % % % % % % % xspec = 'xdom';  % Set to any of the mode types above
% % % % % % % % % % % % % % % % % % % % plotTraj(seqEst, xspec, ...
% % % % % % % % % % % % % % % % % % % %          'dimsToPlot', 9:11, ...
% % % % % % % % % % % % % % % % % % % %          'nPlotMax', 20, ...
% % % % % % % % % % % % % % % % % % % %          'plotSingle', true, ...
% % % % % % % % % % % % % % % % % % % %          'plotMean', false);     
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % %% ==========================================
% % % % % % % % % % % % % % % % % % % % % 1e) Denoise observations using a DLAG model
% % % % % % % % % % % % % % % % % % % % % ===========================================
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % Denoise observations
% % % % % % % % % % % % % % % % % % % % [seqEst, ~, ~, ~, ~, ~] = denoise_dlag(seqEst, res.estParams);
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % Compare PSTHs of raw observations to PSTHs of denoised observations
% % % % % % % % % % % % % % % % % % % % psth_raw = get_psth(seqEst, 'spec', 'y');
% % % % % % % % % % % % % % % % % % % % spec = sprintf('yDenoisedOrth%02d', sum(xDim_across + xDim_within));
% % % % % % % % % % % % % % % % % % % % psth_denoised = get_psth(seqEst, 'spec', spec);
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % Raster plots
% % % % % % % % % % % % % % % % % % % % plotSeqRaster(psth_raw, res.binWidth, 'units', 'ms');
% % % % % % % % % % % % % % % % % % % % plotSeqRaster(psth_denoised, res.binWidth, 'units', 'ms');
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % Heat maps
% % % % % % % % % % % % % % % % % % % % figure;
% % % % % % % % % % % % % % % % % % % % hold on;
% % % % % % % % % % % % % % % % % % % % imagesc(flipud(psth_raw));
% % % % % % % % % % % % % % % % % % % % colormap('pink');
% % % % % % % % % % % % % % % % % % % % colorbar;
% % % % % % % % % % % % % % % % % % % % axis square;
% % % % % % % % % % % % % % % % % % % % xlabel('Time (ms)');
% % % % % % % % % % % % % % % % % % % % ylabel('Neurons');
% % % % % % % % % % % % % % % % % % % % title(sprintf('PSTHs, raw'));
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % figure;
% % % % % % % % % % % % % % % % % % % % hold on;
% % % % % % % % % % % % % % % % % % % % imagesc(flipud(psth_denoised));
% % % % % % % % % % % % % % % % % % % % colormap('pink');
% % % % % % % % % % % % % % % % % % % % colorbar;
% % % % % % % % % % % % % % % % % % % % axis square;
% % % % % % % % % % % % % % % % % % % % xlabel('Time (ms)');
% % % % % % % % % % % % % % % % % % % % ylabel('Neurons');
% % % % % % % % % % % % % % % % % % % % title(sprintf('PSTHs, denoised'));
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % 


















function all_tags = get_all_run_tags(model_data_allruns)
%% =========================================================================
% get_all_run_tags
%
% Purpose:
%   Extract all stim_tag values from model_data_allruns.
%
% Input:
%   unit_condition_metrics : cell array
%       One entry per run.
%
% Output:
%   all_tags : cell array of char
%       Run labels for all runs in this ksDir.
% =========================================================================

all_tags = cell(numel(model_data_allruns), 1);

for j = 1:numel(model_data_allruns)
    if ~isfield(model_data_allruns{j}, 'stim_tag')
        error('stim_tag missing in unit_condition_metrics{%d}.', j);
    end
    all_tags{j} = model_data_allruns{j}.stim_tag;
end

end

function [raw, noise] = computeRawVarianceLocal(params, unitIds)
% Exact model variance decomposition at one time bin. DLAG's GP prior has
% unit marginal variance, so neuron n receives C(n,j)^2 from latent j.
% Across latents are represented once in EACH group's local latent block.
    if ~isfield(params, 'C') || ~isfield(params, 'R') || ...
            ~isfield(params, 'yDims') || ~isfield(params, 'xDim_across') || ...
            ~isfield(params, 'xDim_within')
        error('DLAG estParams must contain C, R, yDims and latent dimensions.');
    end
    y = reshape(double(params.yDims), 1, []);
    w = reshape(double(params.xDim_within), 1, []);
    a = double(params.xDim_across);
    nGroups = numel(y);
    if numel(unitIds) ~= nGroups || numel(w) ~= nGroups || ...
            ~isscalar(a) || a < 0 || a ~= round(a) || ...
            any(y < 1 | y ~= round(y)) || any(w < 0 | w ~= round(w))
        error('Inconsistent model dimensions or unit-ID group count.');
    end
    ld = a + w;
    C = double(params.C);
    R = double(params.R);
    if ~isequal(size(C), [sum(y), sum(ld)]) || ...
            ~isequal(size(R), [sum(y), sum(y)]) || ...
            any(~isfinite(C(:))) || any(~isfinite(R(:)))
        error('Unexpected or nonfinite estParams.C / estParams.R.');
    end
    rdiag = diag(R);
    offdiag = R - diag(rdiag);
    tol = 1e-10 * max(1, max(abs(rdiag)));
    if any(abs(offdiag(:)) > tol) || any(rdiag < -tol)
        error('estParams.R must be diagonal with nonnegative variances.');
    end
    rdiag(rdiag < 0) = 0; % roundoff tolerance only

    raw = struct();
    raw.meta.definition = 'C_g(n,j)^2, with unit marginal latent prior variance';
    raw.meta.xDim_across = a;
    raw.meta.xDim_within = w;
    raw.meta.yDims = y;
    raw.meta.sum_definition = 'sum over all model neurons in one group';
    raw.meta.mean_definition = 'sum divided by number of model neurons in that group';
    raw.unit_ids_by_group = cell(1,nGroups);
    raw.by_neuron = cell(1,nGroups);          % N_neuron x (across + within)
    raw.indiv = cell(1,nGroups);              % raw population sum per latent
    raw.mean_per_neuron = cell(1,nGroups);    % raw per-neuron mean per latent
    raw.n_neurons = y;
    raw.shared_sum = zeros(1,nGroups);
    raw.shared_mean = zeros(1,nGroups);
    raw.total_sum = zeros(1,nGroups);
    raw.total_mean = zeros(1,nGroups);

    noise = struct();
    noise.meta.definition = 'diag(estParams.R), independent observation noise';
    noise.unit_ids_by_group = cell(1,nGroups);
    noise.by_neuron = cell(1,nGroups);
    noise.sum = zeros(1,nGroups);
    noise.mean_per_neuron = zeros(1,nGroups);
    noise.fraction_total = nan(1,nGroups);

    yEnds = cumsum(y);
    lEnds = cumsum(ld);
    for g = 1:nGroups
        yStart = yEnds(g) - y(g) + 1;
        lStart = lEnds(g) - ld(g) + 1;
        obsIdx = yStart:yEnds(g);
        latIdx = lStart:lEnds(g);
        ids = double(unitIds{g}(:));
        if numel(ids) ~= y(g) || any(~isfinite(ids)) || ...
                numel(unique(ids)) ~= numel(ids)
            error('Unit IDs for group %d do not match its neuron rows.', g);
        end
        raw.unit_ids_by_group{g} = ids;
        raw.by_neuron{g} = C(obsIdx,latIdx).^2;
        raw.indiv{g} = sum(raw.by_neuron{g},1);
        raw.mean_per_neuron{g} = raw.indiv{g} / y(g);
        raw.shared_sum(g) = sum(raw.indiv{g});
        raw.shared_mean(g) = raw.shared_sum(g) / y(g);

        noise.unit_ids_by_group{g} = ids;
        noise.by_neuron{g} = rdiag(obsIdx);
        noise.sum(g) = sum(noise.by_neuron{g});
        noise.mean_per_neuron(g) = noise.sum(g) / y(g);
        raw.total_sum(g) = raw.shared_sum(g) + noise.sum(g);
        raw.total_mean(g) = raw.total_sum(g) / y(g);
        if raw.total_sum(g) > 0
            noise.fraction_total(g) = noise.sum(g) / raw.total_sum(g);
        end
    end
end

function verifyVarianceFractionsLocal(shared, total, raw, noise)
% Check the new interpretation against DLAG's own computeVarExp_dlag.
    if ~isfield(shared, 'indiv') || ~isfield(total, 'indiv') || ...
            ~iscell(shared.indiv) || ~iscell(total.indiv) || ...
            numel(shared.indiv) ~= numel(raw.indiv) || ...
            numel(total.indiv) ~= numel(raw.indiv)
        error('Unexpected DLAG varexp.indiv structure.');
    end
    for g = 1:numel(raw.indiv)
        if raw.shared_sum(g) > 0
            checkFractionLocal(shared.indiv{g}, ...
                raw.indiv{g} / raw.shared_sum(g), g, 'shared');
        end
        if raw.total_sum(g) > 0
            checkFractionLocal(total.indiv{g}, ...
                raw.indiv{g} / raw.total_sum(g), g, 'total');
            if abs(sum(raw.indiv{g})/raw.total_sum(g) + ...
                    noise.fraction_total(g) - 1) > 1e-9
                error('Shared + independent-noise fractions do not sum to 1.');
            end
        end
    end
end

function checkFractionLocal(actual, expected, g, kind)
    actual = double(actual(:));
    expected = double(expected(:));
    if numel(actual) ~= numel(expected) || ...
            any(~isfinite(actual)) || ...
            any(abs(actual - expected) > 1e-7)
        error(['Group %d: DLAG %s varexp differs from the ', ...
            'C.^2 population-sum definition. Refusing to save mismatched metrics.'], ...
            g, kind);
    end
end

function [unitIds, groupd] = modelUnitIdsByGroupLocal(runData, dataContent)
% Same probe-to-model-group splitting used by
% calculate_reconstruction_R2_dfferent_ways.m.
    if ~isfield(runData,'group_probe')
        error('Run metadata missing group_probe.');
    end
    if isfield(runData,'nan_trial_strategy') && runData.nan_trial_strategy == 6
        groupField = [dataContent, '_groupd'];
        prefix = [dataContent, '_'];
    else
        groupField = 'groupd';
        prefix = '';
    end
    if ~isfield(runData,groupField)
        error('Run metadata missing %s.',groupField);
    end
    groupd = reshape(double(runData.(groupField)),1,[]);
    probes = reshape(double(runData.group_probe),1,[]);
    if numel(probes) ~= numel(groupd) || any(groupd<1) || ...
            any(groupd ~= round(groupd)) || any(~isfinite(groupd)) || ...
            any(probes<0) || any(probes ~= round(probes)) || ...
            any(~isfinite(probes))
        error('Invalid groupd or group_probe metadata.');
    end
    unitIds = cell(1,numel(groupd));
    uniqueProbes = unique(probes,'stable');
    for k = 1:numel(uniqueProbes)
        probeId = uniqueProbes(k);
        fieldName = sprintf('%sprobe%d_usedunit_ids',prefix,probeId);
        if ~isfield(runData,fieldName)
            error('Run metadata missing %s.',fieldName);
        end
        ids = double(runData.(fieldName));
        ids = ids(:);
        groups = find(probes == probeId);
        if numel(ids) ~= sum(groupd(groups)) || ...
                any(~isfinite(ids)) || numel(unique(ids)) ~= numel(ids)
            error('Invalid unit IDs in %s.',fieldName);
        end
        first = 1;
        for j = 1:numel(groups)
            g = groups(j);
            last = first + groupd(g) - 1;
            unitIds{g} = ids(first:last);
            first = last+1;
        end
    end
end
