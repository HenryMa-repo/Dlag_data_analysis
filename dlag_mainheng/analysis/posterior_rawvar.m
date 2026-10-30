%% posterior_rawvar.m
% OBSERVED TOTAL EXTENSION (20261029): PosteriorRawVarTotal is appended to
% the SAME output MAT. Existing PosteriorRawVar/Extra/Noise/Total variables
% are reused and NEVER rewritten. No existing column order or value changes.
% Total = mean_t var_trial(seqEst.y,0): actual observed count variance, M-1.
% Total is NOT the sum Across+Within+Noise, nor All reconstruction variance.
% For the default residual input, removing each bin's fixed PSTH leaves this
% across-trial variance unchanged. No posterior uncertainty is added to Total;
% u0/u1 have the same Total for the same observations/trials/bins.
% Total stores .raw_var, .normalized_var=raw_var/mean_count, .rate_var=raw_var/dt^2,
% .normalized_rate_var=normalized_var/dt, their per-bin arrays and group
% summaries. Normalization is per neuron/condition BEFORE neuron averaging.
% Run var_stimuli_depended_balance_change.m to plot changes in % of Total.
% Existing six-category raw/normalized figures and their flags are unchanged.
%
% Per-session posterior raw variance, separately for every stimulus condition.
% RESIDUAL NOISE EXTENSION (20261028): an independent MAT variable
% PosteriorRawVarNoise is appended; existing PosteriorRawVar AND existing
% PosteriorRawVarExtra are NOT rewritten, reordered, or recalculated.
% Noise0 = mean_t var_trial(y - posterior_mean_All, 0), using M-1.
% Noise1 = Noise0 + mean_{trial,t} diag(C*Vsm*C'), all latents/full covariance.
% The u0/u1 filename selects BOTH latent and Noise uncertainty consistently.
% Mean normalization is per neuron/condition; count and rate versions are
% always saved. Noise is posterior residual variance, NOT fitted model R.
% Existing six-category single-session figures are retained unchanged.
% Run Varline_figure_plot.m for Within/Across/Noise or FF/FB/Noise figures.
%
% EXTENSION: All latent + normalization by MEAN SPIKE COUNT PER BIN.
% Both unnormalized and normalized values are always calculated and saved.
% The existing PosteriorRawVar variable keeps its original FIVE categories,
% fields and values. On an existing compatible MAT, a missing Extra is added;
% an existing Extra is reused without writeback. Noise is appended separately.
% On a first run, all four variables are created in the usual output MAT.
% Existing original five-category variance is reused, not recalculated.
%
% PosteriorRawVarExtra.labels = Across, Within, Feedforward, Feedback,
% Ambiguous, All. For each .condition(ci).group(g):
%   .raw_var                     : neuron x 6, unnormalized selected variance
%   .reconstruction_var          : neuron x 6, posterior-mean variance
%   .uncertainty_var             : neuron x 6, NaN when uncertainty is off
%   .mean_count                  : neuron x 1, original mean spikes per bin
%   .normalized_var              : raw_var ./ mean_count
%   .normalized_reconstruction_var / .normalized_uncertainty_var
%   .normalization_valid         : mean_count is finite and strictly positive
% Column 6 is All. Raw columns 1:5 are copied from PosteriorRawVar unchanged.
% .group(g).stim_dir(d) also stores condition-wise sums/means and valid counts.
% Full mean-count source identities and analysis-window metadata are retained.
% RATE EXTENSION: all six categories additionally have .rate_var (raw_var/dt^2),
% .rate_reconstruction_var, .rate_uncertainty_var, and .mean_rate=mean_count/dt.
% .normalized_rate_var = normalized_var/dt = Var(rate)/mean(rate), plus its
% reconstruction/uncertainty components, means and sums. dt is bin_size in
% SECONDS, read from metadata; it is never hard-coded. At dt=.02: x2500/x50.
% Existing complete PosteriorRawVarExtra count arrays are reused directly;
% models/reconstructions are not loaded again just to add these rate fields.
% Count figures/save flags are retained; rate results are saved for summaries.
%
% All variance is computed from saved yRecon_use_all (or its no-d form).
% If unavailable/incomplete, compute the WHOLE All response from saved C/xsm.
% Trial variance retains empirical Across-Within covariance. With uncertainty
% enabled, propagate the COMPLETE within-group Vsm block, including Across-
% Within posterior covariance. No fitting or posterior inference is rerun.
%
% Denominator: model_data_allruns{matching stim_tag}.raw_count, matched by
% model-group/probe/unit ID and ORIGINAL trialId to the variance trials.
% Average every matched trial and every matching analysis bin. Do not use
% residual data, Hz, pooled area FR, or reconstructed means as the denominator.
% Different neuron selections across data types (NaN strategy 6) are aligned
% by ID. Different trial/bin sets are never guessed or silently truncated.
% A missing/nonfinite/negative count or a saved raw_count_nanmask entry makes
% that neuron's denominator invalid for that condition; zero mean also has
% undefined normalized variance. Save NaN and report IDs, with no epsilon.
% Normalization occurs per neuron/condition BEFORE any population/direction
% averaging or feature subtraction. No Z-score is computed here.
% Single-session plots: six categories, with All FIRST, for each model group.
% Raw and mean-count-normalized figures have independent PNG/FIG/SVG flags.
% Setting all three flags false skips that figure family entirely.
% Both figures retain two direction panels and eight condition colors.
% Saved column order remains Across/Within/FF/FB/Ambiguous/All; display-only
% order is All/Across/Within/FF/FB/Ambiguous. No MAT fields are reordered.
%
% Start with an empty workspace in a session (catgt_*) folder.
%
% MODEL SELECTION (the same convention as data_reconstruction.m):
%   data_condition = 1:16 : load one model per selected condition.
%   data_condition = []   : load ONE all-condition model, then split its saved
%       trials using seqEst.trialId -> condition_index_per_trial_full.
%       ALL conditions in conditions_full are analyzed separately (16 total).
% data_condition is the only user setting that selects the model mode.
% Run data_reconstruction.m first with the matching data_condition,
% data_content and runIdx, with base and directional reconstructions enabled.
% The all-condition model is loaded/classified once; it is never refitted.
%
% For EACH neuron/category/condition, use ALL saved trials in that condition
% and ALL bins, with equal bin counts WITHIN that condition:
%   mean_t(var_r(reconstruction(r,t), 0))
% var(...,0) uses M-1, where M is THIS condition's trial count.
% Then average neuron variances for the plotted group value. Directions stay
% separate: eight stimulus combinations in each direction panel.
%
% uncertainty_included = 0: posterior-mean reconstruction variance only.
% uncertainty_included = 1: add mean_{r,t}(diag(C_K*Vsm(K,K,t)*C_K')).
% The uncertainty average uses only THIS condition's trials and bins, and
% includes off-diagonal latent covariance. This is the posterior expectation
% of the M-1 trial sample variance, conditional on fixed fitted parameters
% and independent model trials. Vsm is not required/evaluated for option 0;
% uncomputed uncertainty is saved as NaN. No observation noise R, variance
% percentages or DSL filtering are used.
%
% Categories: Across, Within, Feedforward, Feedback, Ambiguous.
% Prefer complete saved reconstructions. If only Ambiguous is absent or
% incomplete, compute that category from the SAME model's saved C and xsm.
% Sum its latent contributions BEFORE taking trial variance, retaining
% their empirical covariance. Empty categories have zero variance.
% No inference is rerun and no bestmodel is modified.
%
% Unit IDs are model-used neuron IDs in model-group order, recovered from
% model_data_allruns and checked against varexp_raw IDs when available.
% They are not invented kilosort identifiers.
%
% OUTPUT (new names do not overwrite the previous untagged eachcond files):
%   session_dir/each_condition_mode/posterior_rawvar/
%       postVar_<data_content>_rXXX_eachcond_u0.mat (or u1)
%   session_dir/all_condition_mode/posterior_rawvar/
%       postVar_<data_content>_rXXX_allcond_u0.mat (or u1)
% Figure names shorten data_content (e.g. dmTC); MAT filenames are unchanged.
% Figure tags: *_all6_raw_gXX (unnormalized) / *_all6_mc_gXX (normalized).
% PNG is exported to a temporary short path, then moved to the output folder;
% print is a fallback if exportgraphics fails. Repeating an identical setting
% appends missing Noise/Total only; every existing MAT variable is preserved.
% MAT variable PosteriorRawVar (v2 on a fresh run) stores the
% model mode, trial IDs, source paths, per-neuron/bin components and summaries.
% Readers: sum_sessions_latent_compare_var.m and GPL_class_rawvar.m.
% Defaults use residual data, run 1, and data_condition = [] for Varline.

clc; clear;

%% ---------------------------- USER SETTINGS ---------------------------
session_dir = pwd;  % Run inside the session (catgt_*) folder.
dat_file = fullfile(session_dir,'model_data_allruns.mat');
% For shuffled models, point dat_file at the matching shuffled metadata.
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;
data_condition = [];  % [] = all-condition model (Varline); 1:16 = each-condition models.
group_names = {'V1','MT'};  % Display labels in MODEL GROUP order.
uncertainty_included = 0;  % 0 = mean reconstruction only; 1 = add uncertainty.

save_mat = true;
make_plots = false;              % master switch for BOTH figure families

% UNNORMALIZED figures: all three false -> do not draw these figures.
save_png = false;
save_fig = false;
save_svg = false;

% MEAN-COUNT-NORMALIZED figures: all three false -> do not draw these figures.
save_png_normalized = false;
save_fig_normalized = false;
save_svg_normalized = false;
png_dpi = 300;
close_after_save = true;
figure_visible = 'on';

%% ------------------------- METADATA AND INPUT -------------------------
cfg = struct('session_dir',char(session_dir),'dat_file',char(dat_file), ...
    'stim_tag',char(stim_tag),'data_content',char(data_content),'runIdx',runIdx, ...
    'group_names',{cellstr(string(group_names(:)'))}, ...
    'uncertainty_included',uncertainty_included,'save_mat',save_mat, ...
    'make_plots',make_plots,'save_png',save_png,'save_fig',save_fig, ...
    'save_svg',save_svg,'save_png_normalized',save_png_normalized, ...
    'save_fig_normalized',save_fig_normalized,'save_svg_normalized',save_svg_normalized, ...
    'png_dpi',png_dpi,'close_after_save',close_after_save, ...
    'figure_visible',char(figure_visible));
cfg = validatePosteriorConfigLocal(cfg);
cfg = posteriorModelModeLocal(cfg,data_condition);
D = load(cfg.dat_file,'model_data_allruns');
requireFieldsLocal(D,{'model_data_allruns'},cfg.dat_file);
if ~iscell(D.model_data_allruns)
    error('model_data_allruns must be a cell array.');
end
tags = cellfun(@(s) char(s.stim_tag),D.model_data_allruns,'UniformOutput',false);
pos = find(strcmp(tags,cfg.stim_tag));
if numel(pos) ~= 1
    error('stim_tag must identify exactly one model_data_allruns entry.');
end
metadata = D.model_data_allruns{pos};
requireFieldsLocal(metadata,{'conditions_full'},'run metadata');
if strcmp(cfg.model_mode,'all_condition')
    condition_ids = 1:numel(metadata.conditions_full);
    if numel(condition_ids) ~= 16
        error('All-condition mode expects 16 conditions (eight stimulus combinations x two directions).');
    end
else
    condition_ids = cfg.data_condition;
end
cfg.condition_ids = condition_ids;
if any(condition_ids > numel(metadata.conditions_full))
    error('A condition ID exceeds conditions_full length.');
end
conditionMap = conditionMapLocal(metadata.conditions_full,condition_ids);
pairs = [[conditionMap.entries.featureCode]',[conditionMap.entries.dirCode]'];
if size(unique(pairs,'rows'),1) ~= numel(condition_ids)
    error('Duplicate stimulus/direction mapping in the requested conditions.');
end
[unitIds,metadata_yDims] = modelUnitIdsByGroupLocal(metadata,cfg.data_content);
if numel(cfg.group_names) ~= numel(metadata_yDims)
    error('group_names must follow the model group count/order.');
end
labels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
[output_dir,out_base,output_file] = extraOutputLocationLocal(cfg);
reuse_original = isfile(output_file);
cachedExtra = [];
if reuse_original
    S = load(output_file,'PosteriorRawVar');
    requireFieldsLocal(S,{'PosteriorRawVar'},output_file);
    PosteriorRawVar = S.PosteriorRawVar;
    clear S;
    validateOriginalForExtraLocal(PosteriorRawVar,conditionMap,unitIds,cfg);
    fprintf('Preserving existing variables; adding missing Noise/Total:\n  %s\n',output_file);
    cachedExtra = readCachedPosteriorExtraLocal(output_file,PosteriorRawVar,metadata,cfg);
end
if ~isempty(cachedExtra)
    PosteriorRawVarExtra = cachedExtra;
else
countSource = prepareMeanCountSourceLocal(metadata,unitIds,cfg);
AllConditions = struct([]);
ExtraConditions = struct([]);

%% ------------------------ READ SAVED RECONSTRUCTIONS ------------------
isAllCondition = strcmp(cfg.model_mode,'all_condition');
if isAllCondition
    runDir = fullfile(cfg.session_dir,['FA_Dlag_' cfg.data_content], ...
        'mat_results',sprintf('run%03d',cfg.runIdx));
    [B,params,classification,bestFile] = loadForPosteriorExtraLocal( ...
        runDir,metadata_yDims,unitIds,[],cfg,reuse_original);
    trialConditions = trialConditionIdsLocal(B.seqEst,metadata, ...
        numel(metadata.conditions_full),bestFile);
end
for ci = 1:numel(condition_ids)
    id = condition_ids(ci);
    if isAllCondition
        modelConditionId = [];
        seqForCondition = B.seqEst(trialConditions == id);
    else
        modelConditionId = id;
        runDir = fullfile(cfg.session_dir,sprintf('FA_Dlag_%s_condition%d', ...
            cfg.data_content,id),'mat_results',sprintf('run%03d',cfg.runIdx));
        [B,params,classification,bestFile] = loadForPosteriorExtraLocal( ...
            runDir,metadata_yDims,unitIds,id,cfg,reuse_original);
        seqForCondition = B.seqEst;
    end
    % Global trial IDs are required to align raw_count with the reconstruction.
    mappedIds = trialConditionIdsLocal(seqForCondition,metadata, ...
        numel(metadata.conditions_full),bestFile);
    if any(mappedIds ~= id)
        error('Saved trials in condition %d map to a different condition.',id);
    end
    fprintf('[%d/%d] %s, condition %d: %d trials\n', ...
        ci,numel(condition_ids),cfg.model_mode,id,numel(seqForCondition));
    if reuse_original
        oldIndex = find([PosteriorRawVar.condition.condition_id] == id);
        result = PosteriorRawVar.condition(oldIndex);
    else
        result = calculatePosteriorConditionLocal(seqForCondition,params,unitIds, ...
            classification,cfg,id);
        e = conditionMap.entries(ci);
        result.condition_id = id;
        result.feature_index = e.featureCode;
        result.direction_index = e.dirCode;
        result.direction_value = e.direction;
        result.condition_label = e.label;
        result.bestmodel_file = bestFile;
        result.classification = classification;
        result.model_mode = cfg.model_mode;
        result.model_condition_id = modelConditionId;
        if ci == 1
            AllConditions = result;
        else
            AllConditions(ci) = orderfields(result,AllConditions(1)); %#ok<SAGROW>
        end
    end
    validateConditionForExtraLocal(result,seqForCondition,params,unitIds,cfg);
    E = calculatePosteriorExtraConditionLocal( ...
        result,seqForCondition,params,countSource,cfg,bestFile);
    if ci == 1
        ExtraConditions = E;
    else
        ExtraConditions(ci) = orderfields(E,ExtraConditions(1)); %#ok<SAGROW>
    end
    clear seqForCondition;
    if ~isAllCondition, clear B; end
end
clear B countSource;

if ~reuse_original
    PosteriorRawVar = packPosteriorSessionLocal(AllConditions,conditionMap,labels,cfg);
end
PosteriorRawVarExtra = packPosteriorExtraLocal( ...
    ExtraConditions,PosteriorRawVar,metadata,cfg,output_file,reuse_original);
end
% Preserve an existing Extra EXACTLY, including its metadata/timestamps.
% The new summary can derive rate values from saved count arrays if needed.
write_extra = isempty(cachedExtra);
if write_extra
    PosteriorRawVarExtra = addPosteriorRateFieldsLocal(PosteriorRawVarExtra,metadata,cfg);
end
clear cachedExtra;
PosteriorRawVarNoise = readCachedObservedExtensionLocal( ...
    output_file,'PosteriorRawVarNoise',PosteriorRawVarExtra,cfg);
write_noise = isempty(PosteriorRawVarNoise);
if write_noise
    PosteriorRawVarNoise = calculatePosteriorNoiseLocal( ...
        PosteriorRawVar,PosteriorRawVarExtra,metadata,unitIds,metadata_yDims,cfg);
end
PosteriorRawVarTotal = readCachedObservedExtensionLocal( ...
    output_file,'PosteriorRawVarTotal',PosteriorRawVarExtra,cfg);
write_total = isempty(PosteriorRawVarTotal);
if write_total
    PosteriorRawVarTotal = calculatePosteriorTotalLocal( ...
        PosteriorRawVar,PosteriorRawVarExtra,PosteriorRawVarNoise, ...
        metadata,unitIds,metadata_yDims,cfg);
end
if cfg.save_mat || (cfg.make_plots && (cfg.save_png || cfg.save_fig || cfg.save_svg || ...
        cfg.save_png_normalized || cfg.save_fig_normalized || cfg.save_svg_normalized))
    if ~isfolder(output_dir)
        [ok,msg] = mkdir(output_dir);
        if ~ok, error('Cannot create output directory: %s',msg); end
    end
end
if cfg.save_mat
    if reuse_original
        % Save ONLY missing independent variables, never existing fields.
        appendNames={};
        if write_extra, appendNames{end+1}='PosteriorRawVarExtra'; end
        if write_noise, appendNames{end+1}='PosteriorRawVarNoise'; end
        if write_total, appendNames{end+1}='PosteriorRawVarTotal'; end
        if ~isempty(appendNames)
            currentNames=who('-file',output_file);
            if any(ismember(appendNames,currentNames))
                error('Output changed during calculation; rerun to reuse new variables safely.');
            end
            save(output_file,appendNames{:},'-append');
            fprintf('Appended %s; existing variables preserved:\n  %s\n',strjoin(appendNames,', '),output_file);
        else
            fprintf('All four variables already present; MAT file left untouched:\n  %s\n',output_file);
        end
    else
        if isfile(output_file)
            error('Output appeared during calculation; rerun to append safely: %s',output_file);
        end
        save(output_file,'PosteriorRawVar','PosteriorRawVarExtra', ...
            'PosteriorRawVarNoise','PosteriorRawVarTotal','-v7.3');
        fprintf('Saved latent, All, residual Noise and observed Total results:\n  %s\n',output_file);
    end
end
if cfg.make_plots
    for g = 1:numel(cfg.group_names)
        if cfg.save_png || cfg.save_fig || cfg.save_svg
            fig = plotPosteriorSessionLocal(PosteriorRawVarExtra,g,cfg,'raw');
            savePosteriorFigureLocal(fig,output_dir,sprintf('%s_all6_raw_g%02d',out_base,g),cfg);
        end
        if cfg.save_png_normalized || cfg.save_fig_normalized || cfg.save_svg_normalized
            fig = plotPosteriorSessionLocal(PosteriorRawVarExtra,g,cfg,'mean_count');
            normalizedCfg=cfg;
            normalizedCfg.save_png=cfg.save_png_normalized;
            normalizedCfg.save_fig=cfg.save_fig_normalized;
            normalizedCfg.save_svg=cfg.save_svg_normalized;
            savePosteriorFigureLocal(fig,output_dir, ...
                sprintf('%s_all6_mc_g%02d',out_base,g),normalizedCfg);
        end
    end
end
fprintf(['Done. Original five-category results preserved. All-latent raw variance ', ...
    'is in PosteriorRawVarExtra; Noise and observed Total are in their separate variables.\n']);


%% ----------------------------- FUNCTIONS ------------------------------
function cfg = posteriorModelModeLocal(cfg,dataCondition)
    if ~isnumeric(dataCondition) || ~isreal(dataCondition)
        error('data_condition must be [] or a vector of positive integer condition IDs.');
    end
    if isempty(dataCondition)
        cfg.data_condition = [];
        cfg.model_mode = 'all_condition';
        cfg.mode_tag = 'allcond';
        cfg.model_dir = 'all_condition_mode';
        cfg.model_description = 'All-condition model';
    else
        validateattributes(dataCondition,{'numeric'},{'vector','positive','integer','finite'});
        cfg.data_condition = double(dataCondition(:)');
        if numel(unique(cfg.data_condition)) ~= numel(cfg.data_condition)
            error('data_condition must contain unique IDs.');
        end
        cfg.model_mode = 'each_condition';
        cfg.mode_tag = 'eachcond';
        cfg.model_dir = 'each_condition_mode';
        cfg.model_description = 'Each-condition models';
    end
end

function [B,p,classification,bestFile] = loadPosteriorModelLocal(runDir,yDims,ids,conditionId,cfg)
    [B,p,bestFile] = loadPosteriorBaseForExtraLocal( ...
        runDir,yDims,ids,conditionId,cfg);
    if p.xDim_across == 0
        gp = struct('delays',[]);
        ambiguous = [];
    else
        gp = getGpParamsLocal(B,bestFile);
        bootFile = uniqueMatFileLocal(runDir,'bootstrapResults*');
        boot = load(bootFile,'ambiguousIdxs');
        requireFieldsLocal(boot,{'ambiguousIdxs'},bootFile);
        ambiguous = boot.ambiguousIdxs;
    end
    classification = classifyDlagLatentsLocal(p.xDim_across,gp,ambiguous);
end

function conditionIds = trialConditionIdsLocal(seq,metadata,nConditions,sourceFile)
% trialId indexes ORIGINAL metadata, not the position of a retained trial.
    requireFieldsLocal(metadata,{'condition_index_per_trial_full'},'run metadata');
    mapping = metadata.condition_index_per_trial_full;
    validateattributes(mapping,{'numeric'},{'real','vector','nonempty', ...
        'integer','positive','finite','<=',nConditions});
    if ~isstruct(seq) || isempty(seq) || ~isfield(seq,'trialId')
        error('Missing seqEst.trialId in %s; conditions cannot be assigned.',sourceFile);
    end
    ids = zeros(1,numel(seq));
    for r = 1:numel(seq)
        validateattributes(seq(r).trialId,{'numeric'}, ...
            {'real','scalar','positive','integer','finite','<=',numel(mapping)});
        ids(r) = double(seq(r).trialId);
    end
    if numel(unique(ids)) ~= numel(ids)
        error('Duplicate seqEst.trialId values in %s.',sourceFile);
    end
    conditionIds = reshape(double(mapping(ids)),1,[]);
end

function cfg = validatePosteriorConfigLocal(cfg)
    if ~isfolder(cfg.session_dir) || ~isfile(cfg.dat_file) || isempty(cfg.data_content)
        error('Check session_dir, dat_file and data_content.');
    end
    if any(ismember(cfg.data_content,['/' '\']))
        error('data_content must be a data label, not a path.');
    end
    validateattributes(cfg.runIdx,{'numeric'},{'scalar','positive','integer','finite'});
    flags = {'uncertainty_included','save_mat','make_plots','save_png', ...
        'save_fig','save_svg','save_png_normalized','save_fig_normalized', ...
        'save_svg_normalized','close_after_save'};
    for i = 1:numel(flags)
        v = cfg.(flags{i});
        if ~(isnumeric(v) || islogical(v)) || ~isscalar(v) || ~ismember(double(v),[0 1])
            error('%s must be 0 or 1.',flags{i});
        end
        cfg.(flags{i}) = logical(v);
    end
    validateattributes(cfg.png_dpi,{'numeric'},{'scalar','finite','positive'});
    if ~ismember(cfg.figure_visible,{'on','off'})
        error('figure_visible must be on or off.');
    end
    if isempty(cfg.group_names) || any(cellfun(@isempty,cfg.group_names))
        error('group_names must contain nonempty display labels.');
    end
end

function filename = uniqueMatFileLocal(folder,pattern)
    listing = dir(fullfile(folder,pattern));
    keep = false(size(listing));
    for i = 1:numel(listing)
        [~,~,ext] = fileparts(listing(i).name);
        keep(i) = ~listing(i).isdir && (isempty(ext) || strcmpi(ext,'.mat'));
    end
    listing = listing(keep);
    if numel(listing) ~= 1
        error('Expected exactly one %s MAT in %s; found %d.',pattern,folder,numel(listing));
    end
    filename = fullfile(listing(1).folder,listing(1).name);
end

function p = posteriorParamsLocal(B,expectedYDims)
    p = B.res.estParams;
    requireFieldsLocal(p,{'C','yDims'},'res.estParams');
    for f = {'xDim_across','xDim_within'}
        name = f{1};
        if ~isfield(p,name) || isempty(p.(name))
            if ~isfield(B,'bestModel') || ~isfield(B.bestModel,name)
                error('Missing model dimension %s.',name);
            end
            p.(name) = B.bestModel.(name);
        end
    end
    p.yDims = double(p.yDims(:)');
    p.xDim_across = double(p.xDim_across);
    p.xDim_within = double(p.xDim_within(:)');
    validateattributes(p.xDim_across,{'numeric'},{'scalar','nonnegative','integer','finite'});
    validateattributes(p.xDim_within,{'numeric'},{'vector','nonnegative','integer','finite'});
    if ~isequal(p.yDims,double(expectedYDims(:)')) || numel(p.xDim_within) ~= numel(p.yDims)
        error('Model dimensions disagree with the requested metadata.');
    end
    assertSizeLocal(p.C,[sum(p.yDims),sum(p.xDim_across+p.xDim_within)],'loading C');
    if ~isreal(p.C) || any(~isfinite(p.C(:)))
        error('Loading C must be real and finite.');
    end
end

function validateSavedIdsLocal(B,ids,id,cfg)
    if ~isfield(B,'varexp_raw'), return; end
    R = B.varexp_raw;
    requireFieldsLocal(R,{'meta','unit_ids_by_group'},'varexp_raw');
    requireFieldsLocal(R.meta,{'runIdx','data_content'},'varexp_raw.meta');
    if isempty(id)
        if isfield(R.meta,'condition_id') && ~isempty(R.meta.condition_id)
            error('An all-condition model contains condition-specific variance metadata.');
        end
    else
        requireFieldsLocal(R.meta,{'condition_id'},'varexp_raw.meta');
        if ~isequal(double(R.meta.condition_id),double(id))
            error('Saved variance condition ID disagrees with the requested model.');
        end
    end
    if R.meta.runIdx ~= cfg.runIdx || ...
            ~strcmp(char(R.meta.data_content),cfg.data_content) || numel(R.unit_ids_by_group) ~= numel(ids)
        error('Saved variance metadata disagree with this model.');
    end
    for g = 1:numel(ids)
        if ~isequal(double(R.unit_ids_by_group{g}(:)),double(ids{g}(:)))
            error('Saved model unit IDs/order disagree with metadata in group %d.',g);
        end
    end
end

function out = calculatePosteriorConditionLocal(seq,p,ids,classification,cfg,id)
    if ~isstruct(seq) || numel(seq) < 2
        error('Condition %d needs at least two saved trials.',id);
    end
    M = numel(seq); ny = sum(p.yDims);
    fields = {'yRecon_use_across','yRecon_use_within','yRecon_use_feedforward', ...
        'yRecon_use_feedback','yRecon_use_ambiguous'};
    % Constant d has no effect on variance. A saved no-d field is equivalent.
    for k = 1:2
        if ~isfield(seq,fields{k}) && isfield(seq,[fields{k} '_no_d'])
            fields{k} = [fields{k} '_no_d'];
        end
    end
    ambiguousCandidates = {'yRecon_use_ambiguous','yRecon_use_ambiguous_no_d'};
    for k = 1:numel(ambiguousCandidates)
        candidate = ambiguousCandidates{k};
        if isfield(seq,candidate) && all(arrayfun(@(s) ~isempty(s.(candidate)),seq))
            fields{5} = candidate;
            break;
        end
    end
    for k = 1:4
        if ~isfield(seq,fields{k})
            error(['Missing %s. Run data_reconstruction.m with base and ', ...
                'directional reconstruction enabled for condition %d.'],fields{k},id);
        end
    end
    T = size(seq(1).(fields{1}),2);
    if T < 1, error('Saved reconstruction has no time bins.'); end
    if isfield(seq,'T')
        for r = 1:M
            if ~isscalar(seq(r).T) || seq(r).T ~= T
                error('Trial bin counts must match; no truncation or trial dropping is performed.');
            end
        end
    end
    if isfield(seq,'trialId')
        trialIds = [seq.trialId];
        if numel(trialIds) ~= M || any(~isfinite(trialIds)) || numel(unique(trialIds)) ~= M
            error('trialId must provide one unique finite ID per saved trial.');
        end
    else
        trialIds = 1:M;
    end
    reconBin = nan(ny,T,5);
    saved = false(1,5);
    for k = 1:5
        if ~isfield(seq,fields{k}), continue; end
        if k == 5 && any(arrayfun(@(s) isempty(s.(fields{k})),seq))
            % Recompute the entire category if some trials lack it. Mixing
            % saved d+CX trials with fallback CX trials would introduce offsets.
            continue;
        end
        saved(k) = true;
        mu = zeros(ny,T); ss = zeros(ny,T);
        for r = 1:M
            Y = seq(r).(fields{k});
            if ~isnumeric(Y) || ~isreal(Y) || ~isequal(size(Y),[ny T]) || any(~isfinite(Y(:)))
                error('Condition %d, trial %d: %s must be finite neurons x common bins.',id,r,fields{k});
            end
            Y = double(Y);
            change = Y-mu;
            mu = mu+change/r;
            ss = ss+change.*(Y-mu);
        end
        reconBin(:,:,k) = max(ss/(M-1),0); % stable sample variance across trials
    end
    dims = p.xDim_across+p.xDim_within;
    meanV = [];
    if cfg.uncertainty_included
        meanV = averageVsmLocal(seq,sum(dims),T,id);
    end
    out = struct();
    out.n_trials = M; out.n_bins = T; out.trial_ids = trialIds;
    groupTemplate = posteriorGroupTemplateLocal();
    out.group = repmat(groupTemplate,1,numel(p.yDims));
    for g = 1:numel(p.yDims)
        rows = sum(p.yDims(1:g-1))+(1:p.yDims(g));
        offset = sum(dims(1:g-1));
        indices = {offset+(1:p.xDim_across), ...
            offset+(p.xDim_across+1:dims(g)), ...
            offset+classification.feedforwardIdx, ...
            offset+classification.feedbackIdx, ...
            offset+classification.ambiguousIdx};
        N = numel(rows);
        A = groupTemplate;
        A.name = cfg.group_names{g};
        A.unit_ids = double(ids{g}(:)); A.n_neurons = N;
        A.category_indices = indices;
        A.reconstruction_field_names = fields;
        A.counts = cellfun(@numel,indices); A.nLatents = dims(g);
        if dims(g) > 0, A.percent_latents = 100*A.counts/dims(g);
        else, A.percent_latents = zeros(1,5); end
        A.available = saved;
        A.status = repmat({'saved_reconstruction'},1,5);
        A.reconstruction_var_by_bin = reconBin(rows,:,:);
        A.uncertainty_var_by_bin = nan(N,T,5);
        for k = 1:5
            idx = indices{k};
            if isempty(idx)
                existing = A.reconstruction_var_by_bin(:,:,k);
                if saved(k) && any(existing(:)>1e-10)
                    error('Nonzero saved variance for an empty latent category; rerun data_reconstruction.');
                end
                A.reconstruction_var_by_bin(:,:,k) = zeros(N,T);
                A.available(k) = true;
                if ~saved(k), A.status{k} = 'known_zero_empty_category'; end
            elseif ~saved(k)
                if k ~= 5
                    error('Missing required saved reconstruction: %s.',fields{k});
                end
                A.reconstruction_var_by_bin(:,:,k) = ambiguousVarianceFromXsmLocal( ...
                    seq,double(p.C(rows,idx)),idx,sum(dims),T,id,g);
                A.available(k) = true;
                A.status{k} = 'computed_from_saved_C_xsm';
                A.reconstruction_field_names{k} = ''; % no saved field was used
                fprintf(['  Condition %d, group %d: Ambiguous variance computed ', ...
                    'from saved C and xsm (%d latents, %d trials).\n'],id,g,numel(idx),M);
            end
            if cfg.uncertainty_included
                Ck = double(p.C(rows,idx));
                U = zeros(N,T);
                for t = 1:T
                    S = meanV(idx,idx,t);
                    U(:,t) = sum((Ck*S).*Ck,2); % diag(Ck*S*Ck'), includes covariance
                end
                tol = 1e-9*max(1,max(abs(U(:))));
                if any(U(:) < -tol)
                    error('Negative propagated posterior variance beyond numerical tolerance.');
                end
                A.uncertainty_var_by_bin(:,:,k) = max(U,0);
            end
        end
        A.reconstruction_var = reshape(mean(A.reconstruction_var_by_bin,2),N,5);
        A.uncertainty_var = reshape(mean(A.uncertainty_var_by_bin,2),N,5);
        A.raw_var = A.reconstruction_var;
        if cfg.uncertainty_included
            A.raw_var = A.raw_var+A.uncertainty_var;
        end
        parts = {'raw','reconstruction','uncertainty'};
        for k = 1:numel(parts)
            name = parts{k};
            A.([name '_sum']) = sum(A.([name '_var']),1);
            A.([name '_mean']) = A.([name '_sum'])/N;
        end
        out.group(g) = orderfields(A,groupTemplate);
    end
end

function A = posteriorGroupTemplateLocal()
% Use the identical complete schema for every group, including first-group
% assignment and all branches (saved/fallback/empty, uncertainty off/on).
    A = struct('name','','unit_ids',[],'n_neurons',[], ...
        'category_indices',{{}},'reconstruction_field_names',{{}}, ...
        'counts',[],'nLatents',[],'percent_latents',[],'available',[], ...
        'status',{{}},'reconstruction_var_by_bin',[],'uncertainty_var_by_bin',[], ...
        'reconstruction_var',[],'uncertainty_var',[],'raw_var',[], ...
        'raw_sum',[],'raw_mean',[],'reconstruction_sum',[],'reconstruction_mean',[], ...
        'uncertainty_sum',[],'uncertainty_mean',[]);
end

function V = ambiguousVarianceFromXsmLocal(seq,Ck,idx,L,T,id,g)
% Only the missing Ambiguous category is reconstructed. idx indexes the
% correct group's across-latent replicas in the ORIGINAL C/xsm coordinates.
% Sum latent contributions BEFORE computing variance, keeping covariance.
    if ~isfield(seq,'xsm')
        error(['Condition %d group %d has no complete saved Ambiguous ', ...
            'reconstruction and seqEst.xsm is missing.'],id,g);
    end
    N = size(Ck,1); M = numel(seq);
    mu = zeros(N,T); ss = zeros(N,T);
    for r = 1:M
        X = seq(r).xsm;
        if ~isnumeric(X) || ~isreal(X) || ~isequal(size(X),[L T])
            error('Condition %d trial %d: xsm must be a real %d x %d array.',id,r,L,T);
        end
        X = double(X(idx,:));
        if any(~isfinite(X(:)))
            error('Condition %d trial %d: selected Ambiguous xsm contains nonfinite values.',id,r);
        end
        Y = Ck*X;
        if any(~isfinite(Y(:)))
            error('Condition %d trial %d: Ambiguous reconstruction is nonfinite.',id,r);
        end
        change = Y-mu;
        mu = mu+change/r;
        ss = ss+change.*(Y-mu);
    end
    V = max(ss/(M-1),0);
end

function V = averageVsmLocal(seq,L,T,id)
    if ~isfield(seq,'Vsm')
        error('uncertainty_included=1 but Vsm is missing in condition %d.',id);
    end
    V = zeros(L,L,T);
    for r = 1:numel(seq)
        S = seq(r).Vsm;
        if ~isnumeric(S) || ~isreal(S) || size(S,1) ~= L || size(S,2) ~= L || ...
                size(S,3) ~= T || ndims(S)>3 || any(~isfinite(S(:)))
            error('Condition %d trial %d: Vsm must be finite %d x %d x %d.',id,r,L,L,T);
        end
        S = double(S);
        if L > 0
            asym = S-permute(S,[2 1 3]);
            if max(abs(asym(:))) > 1e-8*max(1,max(abs(S(:))))
                error('Vsm is not symmetric in condition %d trial %d.',id,r);
            end
        end
        V = V+(S-V)/r;
    end
    V = (V+permute(V,[2 1 3]))/2;
    for t = 1:T
        if L > 0
            ev = eig(V(:,:,t));
            if min(ev) < -1e-9*max(1,max(abs(ev)))
                error('Mean Vsm is not positive semidefinite in condition %d bin %d.',id,t);
            end
        end
    end
end

function P = packPosteriorSessionLocal(results,map,labels,cfg)
    P = struct();
    P.format_version = 'posterior_rawvar_v2';
    P.labels = labels;
    P.meta.data_content = cfg.data_content; P.meta.runIdx = cfg.runIdx;
    P.meta.stim_tag = cfg.stim_tag; P.meta.group_names = cfg.group_names;
    P.meta.variance_source = 'posterior';
    P.meta.model_mode = cfg.model_mode;
    P.meta.mode_tag = cfg.mode_tag;
    P.meta.data_condition = cfg.data_condition;
    P.meta.trial_assignment = 'seqEst.trialId -> condition_index_per_trial_full in all-condition mode';
    P.meta.uncertainty_included = cfg.uncertainty_included;
    P.meta.DSL_filter = 'all_latents';
    P.meta.variance_method = 'across_trials_per_bin_mean_over_bins';
    P.meta.variance_normalization = 'M-1';
    P.meta.uncertainty_method = 'mean_trial_bin_diag_CK_VsmKK_CK_transpose';
    P.meta.conditionShortLabels = map.shortLabels;
    P.meta.dirValues = map.dirValues; P.meta.conditionMap = map;
    P.meta.created_on = datestr(now,30);
    P.meta.created_by = 'posterior_rawvar.m';
    P.meta.code_revision = '20261015_two_model_modes';
    P.meta.raw_unit = 'squared data_content units, averaged over neurons for plots';
    P.meta.missing_ambiguous_policy = 'compute from saved C and xsm if absent or incomplete; zero if empty';
    P.settings = cfg; P.condition = results;
    P.condition_ids = nan(8,2);
    for ci = 1:numel(results)
        A = results(ci);
        P.condition_ids(A.feature_index,A.direction_index) = A.condition_id;
    end
    P.group = repmat(struct('name','','stim_dir',struct([])),1,numel(cfg.group_names));
    for g = 1:numel(cfg.group_names)
        P.group(g).name = cfg.group_names{g};
        for d = 1:2
            A = struct('conditionIds',P.condition_ids(:,d),'raw_mean',nan(8,5), ...
                'raw_sum',nan(8,5),'reconstruction_mean',nan(8,5), ...
                'reconstruction_sum',nan(8,5),'uncertainty_mean',nan(8,5), ...
                'uncertainty_sum',nan(8,5),'counts',nan(8,5),'percent_latents',nan(8,5), ...
                'available',false(8,5),'n_neurons',nan(8,1), ...
                'nLatents',nan(8,1),'n_trials',nan(8,1),'n_bins',nan(8,1));
            vectors = {'raw_mean','raw_sum','reconstruction_mean','reconstruction_sum', ...
                'uncertainty_mean','uncertainty_sum','counts','percent_latents','available'};
            for ci = 1:numel(results)
                R = results(ci);
                if R.direction_index ~= d, continue; end
                p = R.feature_index; G = R.group(g);
                for k = 1:numel(vectors), A.(vectors{k})(p,:) = G.(vectors{k}); end
                A.n_neurons(p) = G.n_neurons; A.nLatents(p) = G.nLatents;
                A.n_trials(p) = R.n_trials; A.n_bins(p) = R.n_bins;
            end
            if d == 1
                P.group(g).stim_dir = A;
            else
                P.group(g).stim_dir(d) = orderfields(A,P.group(g).stim_dir(1));
            end
        end
    end
end

function fig = plotPosteriorSessionLocal(P,g,cfg,valueMode)
% Reorder columns ONLY for display; the saved six-column order is unchanged.
    plotLabels={'All','Across','Within','Feedforward','Feedback','Ambiguous'};
    [present,order]=ismember(plotLabels,P.labels);
    if numel(P.labels)~=6 || ~all(present) || numel(unique(order))~=6
        error('PosteriorRawVarExtra must contain the six expected latent labels.');
    end
    if strcmp(valueMode,'mean_count')
        meanField='normalized_mean';
        yLabel='Trial variance / mean spike count per bin';
    elseif strcmp(valueMode,'raw')
        meanField='raw_mean';
        yLabel='Trial variance per neuron';
    else
        error('Unknown posterior variance plot mode: %s.',valueMode);
    end
    fig = figure('Visible',cfg.figure_visible,'Position',[80 80 1500 820]);
    layout = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    values = [P.group(g).stim_dir(1).(meanField);P.group(g).stim_dir(2).(meanField)];
    good = values(isfinite(values));
    if isempty(good) || max(good)<=0, top = 1; else, top = 1.12*max(good); end
    colors = lines(8);
    for d = 1:2
        ax = nexttile(layout,d);
        A = P.group(g).stim_dir(d);
        % normalized_mean is mean(raw_var(neuron)/mean_count(neuron)),
        % calculated upstream per condition. Never divide population means.
        V=A.(meanField);
        bars = bar(ax,V(:,order)');
        for p = 1:numel(bars)
            bars(p).FaceColor = colors(p,:); bars(p).EdgeColor = 'none';
        end
        set(ax,'XTick',1:6,'XTickLabel',plotLabels,'TickLabelInterpreter','none');
        xtickangle(ax,30); ylim(ax,[0 top]);
        xlabel(ax,'Latent category'); ylabel(ax,yLabel);
        title(ax,sprintf('Stimulus direction %d = %g',d,P.meta.dirValues(d)));
        if d == 1, legendBars = bars; end
        box(ax,'off');
    end
    leg = legend(legendBars,P.meta.conditionShortLabels,'Location','southoutside', ...
        'Orientation','horizontal','Interpreter','none');
    leg.NumColumns = 4; leg.Layout.Tile = 'south';
    if cfg.uncertainty_included, mode = 'posterior mean + uncertainty';
    else, mode = 'posterior mean only'; end
    sgtitle(layout,sprintf('%s | %s | %s | %s | M-1 across trials, then mean over bins', ...
        cfg.group_names{g},cfg.data_content,cfg.model_description,mode), ...
        'Interpreter','none');
end


function savePosteriorFigureLocal(fig,folder,base,cfg)
    if ~(cfg.save_fig || cfg.save_png || cfg.save_svg), return; end
    if ~isfolder(folder)
        [ok,msg]=mkdir(folder);
        if ~ok, error('posterior_rawvar:FigureFolder','Cannot create figure directory %s: %s',folder,msg); end
    end
    % Only FIGURE filenames are shortened. Keep MAT names/variables unchanged.
    originalBase=base;
    tag=char(cfg.data_content);
    if strcmp(tag,'demean_count_within_t_and_condition')
        tag='dmTC';
    else
        safe=regexprep(tag,'[^A-Za-z0-9_]','_');
        if numel(safe)>24 || ~strcmp(safe,tag)
            tag=[safe(1:min(12,numel(safe))) '_' posteriorFigureHashLocal(tag)];
        else
            tag=safe;
        end
    end
    base=strrep(base,char(cfg.data_content),tag);
    if numel(fullfile(folder,[base '.png']))>=240
        % Preserve a visible group suffix; hash the complete original name
        % so content/run/mode/u/group selections remain distinct.
        suffix=regexp(originalBase,'_g\d+$','match','once');
        base=['pV_' posteriorFigureHashLocal(originalBase) suffix];
    end
    if cfg.save_fig, savefig(fig,fullfile(folder,[base '.fig'])); end
    if cfg.save_png
        target=fullfile(folder,[base '.png']);
        % The PNG encoder writes to a short temporary path, avoiding native
        % PNG-library problems with a long/Unicode destination path.
        temporary=[tempname '.png'];
        temporaryCleanup=onCleanup(@()removePosteriorTempLocal(temporary)); %#ok<NASGU>
        drawnow;
        usedPrint=false;
        try
            exportgraphics(fig,temporary,'Resolution',cfg.png_dpi);
            validatePosteriorPngFileLocal(temporary);
        catch exportError
            removePosteriorTempLocal(temporary);
            oldPaperMode=get(fig,'PaperPositionMode');
            paperCleanup=onCleanup(@()set(fig,'PaperPositionMode',oldPaperMode)); %#ok<NASGU>
            set(fig,'PaperPositionMode','auto');
            try
                print(fig,temporary,'-dpng',sprintf('-r%g',cfg.png_dpi));
                validatePosteriorPngFileLocal(temporary);
                usedPrint=true;
            catch printError
                error('posterior_rawvar:PngExportFailed', ...
                    ['Cannot export PNG even to temporary path %s.\n', ...
                    'Requested destination: %s\nexportgraphics: %s\nprint: %s'], ...
                    temporary,target,exportError.message,printError.message);
            end
            clear paperCleanup; % Restore while the figure is still open.
        end
        [ok,msg]=movefile(temporary,target,'f');
        if ~ok
            error('posterior_rawvar:PngMoveFailed', ...
                ['PNG was generated, but cannot be saved to:\n  %s\n%s\n', ...
                'Check folder write permission, free space, a file lock, or the full path length.'],target,msg);
        end
        if usedPrint
            fprintf('Saved PNG (print fallback): %s\n',target);
        else
            fprintf('Saved PNG: %s\n',target);
        end
    end
    if cfg.save_svg
        set(fig,'Renderer','painters','PaperPositionMode','auto');
        print(fig,fullfile(folder,[base '.svg']),'-dsvg','-painters');
    end
    if cfg.close_after_save, close(fig); end
end

function hash = posteriorFigureHashLocal(value)
% Small deterministic name hash; no Java/toolbox dependency.
    h=0;
    codes=double(char(value));
    for k=1:numel(codes), h=mod(131*h+codes(k),4294967296); end
    hash=lower(dec2hex(h,8));
end

function validatePosteriorPngFileLocal(filename)
    info=dir(filename);
    if isempty(info) || info(1).isdir || info(1).bytes==0
        error('posterior_rawvar:EmptyPng','PNG exporter did not create a nonempty file: %s',filename);
    end
end

function removePosteriorTempLocal(filename)
    if isfile(filename), delete(filename); end
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

function latentClass = classifyDlagLatentsLocal(xDim_across, gp_params, ambiguousIdxs)

if ~isfield(gp_params, 'delays')
    error('gp_params must contain field delays.');
end

if ~isscalar(xDim_across) || xDim_across < 0 || mod(xDim_across, 1) ~= 0
    error('xDim_across must be a nonnegative integer scalar.');
end

acrossDelay = reshape(gp_params.delays, 1, []);

if numel(acrossDelay) < xDim_across
    error('gp_params.delays has fewer entries than xDim_across.');
end

acrossDelay = acrossDelay(1:xDim_across);

if isempty(ambiguousIdxs)
    ambiguousIdxs = [];
elseif islogical(ambiguousIdxs)
    ambiguousIdxs = find(ambiguousIdxs);
end

ambiguousIdxs = unique(ambiguousIdxs(:)');
ambiguousIdxs = ambiguousIdxs(ambiguousIdxs >= 1 & ambiguousIdxs <= xDim_across);

acrossIdx = 1:xDim_across;
zeroOrNaNIdx = acrossIdx((acrossDelay == 0) | isnan(acrossDelay));
ambiguousAll = unique([ambiguousIdxs, zeroOrNaNIdx]);

ffIdx = find(acrossDelay > 0);
fbIdx = find(acrossDelay < 0);

ffIdx = setdiff(ffIdx, ambiguousAll);
fbIdx = setdiff(fbIdx, ambiguousAll);

coveredAcross = unique([ffIdx, fbIdx, ambiguousAll]);
missingAcross = setdiff(acrossIdx, coveredAcross);

if ~isempty(missingAcross)
    ambiguousAll = unique([ambiguousAll, missingAcross]);
end

latentClass = struct();
latentClass.categoryLabels = {'Across', 'Within', 'Feedforward', 'Feedback', 'Ambiguous'};
latentClass.acrossDelay = acrossDelay;
latentClass.acrossIdx = acrossIdx;
latentClass.feedforwardIdx = ffIdx;
latentClass.feedbackIdx = fbIdx;
latentClass.ambiguousIdx = ambiguousAll;
end

function gp_params = getGpParamsLocal(Sbest, bestFile)

if isfield(Sbest, 'gp_params') && ~isempty(Sbest.gp_params)
    gp_params = Sbest.gp_params;
    return;
end

if isfield(Sbest, 'res') && isfield(Sbest.res, 'estParams') && ...
        isfield(Sbest.res.estParams, 'gp_params') && ...
        ~isempty(Sbest.res.estParams.gp_params)
    gp_params = Sbest.res.estParams.gp_params;
    return;
end

if isfield(Sbest, 'bestModel') && isfield(Sbest.bestModel, 'gp_params') && ...
        ~isempty(Sbest.bestModel.gp_params)
    gp_params = Sbest.bestModel.gp_params;
    return;
end

error('gp_params not found in %s.', bestFile);
end

function requireFieldsLocal(S,names,context)
    if ~isstruct(S) || ~isscalar(S)
        error('%s must be a scalar struct.',context);
    end
    for k = 1:numel(names)
        if ~isfield(S,names{k})
            error('%s lacks %s.',context,names{k});
        end
    end
end

function assertSizeLocal(A,sz,context)
    if ~isequal(size(A),sz)
        error('%s has size [%s]; expected [%s].',context,num2str(size(A)),num2str(sz));
    end
end


function [folder,base,filename] = extraOutputLocationLocal(cfg)
    folder = fullfile(cfg.session_dir,cfg.model_dir,'posterior_rawvar');
    base = sprintf('postVar_%s_r%03d_%s_u%d',cfg.data_content,cfg.runIdx, ...
        cfg.mode_tag,cfg.uncertainty_included);
    filename = fullfile(folder,[base '.mat']);
    if ~isfile(filename) && strcmp(cfg.model_mode,'each_condition')
        oldBase = sprintf('postVar_%s_r%03d_u%d', ...
            cfg.data_content,cfg.runIdx,cfg.uncertainty_included);
        oldFile = fullfile(folder,[oldBase '.mat']);
        if isfile(oldFile)
            base = oldBase;
            filename = oldFile;
        end
    end
end

function [B,p,classification,bestFile] = loadForPosteriorExtraLocal( ...
        runDir,yDims,ids,conditionId,cfg,reuseOriginal)
    if reuseOriginal
        % The original five-category classification/results are already saved.
        % All and mean-count normalization do not need bootstrap classification.
        [B,p,bestFile] = loadPosteriorBaseForExtraLocal( ...
            runDir,yDims,ids,conditionId,cfg);
        classification = struct();
    else
        [B,p,classification,bestFile] = loadPosteriorModelLocal( ...
            runDir,yDims,ids,conditionId,cfg);
    end
end

function [B,p,bestFile] = loadPosteriorBaseForExtraLocal(runDir,yDims,ids,conditionId,cfg)
    bestFile = uniqueMatFileLocal(runDir,'bestmodel*');
    fprintf('Loading %s: %s\n',cfg.model_description,bestFile);
    available = who('-file',bestFile);
    requested = {'bestModel','res','seqEst','gp_params','varexp_raw'};
    requested = requested(ismember(requested,available));
    if ~all(ismember({'res','seqEst'},requested))
        error('Bestmodel lacks res or seqEst: %s',bestFile);
    end
    B = load(bestFile,requested{:});
    requireFieldsLocal(B.res,{'estParams'},'res');
    p = posteriorParamsLocal(B,yDims);
    validateSavedIdsLocal(B,ids,conditionId,cfg);
end

function validateOriginalForExtraLocal(P,map,ids,cfg)
    requireFieldsLocal(P,{'format_version','labels','meta','condition_ids','condition','group'}, ...
        'existing PosteriorRawVar');
    labels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
    if ~isequal(cellstr(string(P.labels(:)')),labels)
        error('Existing PosteriorRawVar must retain its original five-category order.');
    end
    requireFieldsLocal(P.meta,{'data_content','runIdx','stim_tag','group_names', ...
        'variance_source','uncertainty_included','DSL_filter','variance_method', ...
        'variance_normalization'},'existing PosteriorRawVar.meta');
    if ~strcmp(char(P.meta.data_content),cfg.data_content) || ...
            ~isequal(double(P.meta.runIdx),double(cfg.runIdx)) || ...
            ~strcmp(char(P.meta.stim_tag),cfg.stim_tag) || ...
            ~strcmp(char(P.meta.variance_source),'posterior') || ...
            ~isequal(double(P.meta.uncertainty_included),double(cfg.uncertainty_included)) || ...
            ~strcmp(char(P.meta.DSL_filter),'all_latents') || ...
            ~strcmp(char(P.meta.variance_method),'across_trials_per_bin_mean_over_bins') || ...
            ~strcmp(char(P.meta.variance_normalization),'M-1')
        error('Existing posterior settings differ; original MAT was not modified: %s',cfg.data_content);
    end
    if ~isequal(cellstr(string(P.meta.group_names(:)')),cfg.group_names)
        error('Existing posterior group names/order differ from the requested groups.');
    end
    if isfield(P.meta,'model_mode')
        if ~strcmp(char(P.meta.model_mode),cfg.model_mode)
            error('Existing posterior model_mode differs from the requested mode.');
        end
    elseif ~strcmp(cfg.model_mode,'each_condition') || ...
            ~strcmp(char(P.format_version),'posterior_rawvar_eachcond_v1')
        error('Existing posterior file has no compatible model-mode provenance.');
    end
    if ~isstruct(P.condition) || isempty(P.condition) || ...
            ~isfield(P.condition,'condition_id')
        error('Existing PosteriorRawVar has no condition records.');
    end
    oldIds = double([P.condition.condition_id]);
    if numel(unique(oldIds)) ~= numel(oldIds) || ...
            ~isequal(sort(oldIds),sort(cfg.condition_ids))
        error(['Existing MAT and data_condition contain different condition sets. ', ...
            'Select the same conditions to extend this MAT; it was not modified.']);
    end
    wanted = nan(8,2);
    for j = 1:numel(map.entries)
        e = map.entries(j);
        wanted(e.featureCode,e.dirCode) = e.conditionId;
        R = P.condition(oldIds == e.conditionId);
        requireFieldsLocal(R,{'feature_index','direction_index','direction_value','group'}, ...
            'existing condition');
        if R.feature_index ~= e.featureCode || R.direction_index ~= e.dirCode || ...
                R.direction_value ~= e.direction || numel(R.group) ~= numel(ids)
            error('Condition %d mapping/group count disagrees with the current metadata.',e.conditionId);
        end
        for g = 1:numel(ids)
            requireFieldsLocal(R.group(g),{'unit_ids','n_neurons'},'existing posterior group');
            if ~isequal(double(R.group(g).unit_ids(:)),double(ids{g}(:))) || ...
                    R.group(g).n_neurons ~= numel(ids{g})
                error('Condition %d group %d: existing model neuron IDs/order differ.',e.conditionId,g);
            end
        end
    end
    if ~isequaln(double(P.condition_ids),wanted)
        error('Existing condition_ids matrix disagrees with the current stimulus mapping.');
    end
end

function ids = extraTrialIdsLocal(seq,context)
    if ~isstruct(seq) || isempty(seq) || ~isfield(seq,'trialId')
        error('%s requires saved original trialId values for mean-count alignment.',context);
    end
    ids = zeros(1,numel(seq));
    for r = 1:numel(seq)
        v = seq(r).trialId;
        if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ...
                ~isfinite(v) || v < 1 || v ~= round(v)
            error('%s has an invalid original trialId at position %d.',context,r);
        end
        ids(r) = double(v);
    end
    if numel(unique(ids)) ~= numel(ids)
        error('%s has duplicate original trialId values.',context);
    end
end

function S = prepareMeanCountSourceLocal(metadata,modelIds,cfg)
    requireFieldsLocal(metadata,{'raw_count','condition_index_per_trial_full'}, ...
        'model_data_allruns run for mean count');
    [rawIds,rawDims] = modelUnitIdsByGroupLocal(metadata,'raw_count');
    if numel(rawIds) ~= numel(modelIds)
        error('raw_count and model data have different model-group counts.');
    end
    S = struct();
    S.trials = metadata.raw_count;
    S.trial_ids = extraTrialIdsLocal(S.trials,'raw_count');
    S.condition_index = double(metadata.condition_index_per_trial_full(:)');
    if any(S.trial_ids > numel(S.condition_index))
        error('raw_count trialId exceeds condition_index_per_trial_full.');
    end
    S.n_rows = sum(rawDims);
    S.model_rows = cell(1,numel(modelIds));
    S.raw_unit_ids_by_group = rawIds;
    for g = 1:numel(modelIds)
        [ok,loc] = ismember(double(modelIds{g}(:)),double(rawIds{g}(:)));
        if ~all(ok)
            error('Group %d: model unit IDs missing from raw_count: %s', ...
                g,mat2str(double(modelIds{g}(~ok))'));
        end
        S.model_rows{g} = sum(rawDims(1:g-1)) + loc;
    end
    S.mask_trials = struct([]);
    S.mask_trial_ids = [];
    if isfield(metadata,'raw_count_nanmask') && ~isempty(metadata.raw_count_nanmask)
        S.mask_trials = metadata.raw_count_nanmask;
        S.mask_trial_ids = extraTrialIdsLocal(S.mask_trials,'raw_count_nanmask');
    end
    S.dat_file = cfg.dat_file;
    fprintf('Mean-count denominator: raw_count, aligned by group/unit ID and original trialId.\n');
end

function validateConditionForExtraLocal(R,seq,p,ids,cfg)
    requireFieldsLocal(R,{'condition_id','n_trials','n_bins','trial_ids','group'}, ...
        'condition reused for posterior extension');
    trialIds = extraTrialIdsLocal(seq,'seqEst');
    if numel(seq) < 2 || R.n_trials ~= numel(seq) || ...
            ~isequal(sort(double(R.trial_ids(:)')),sort(trialIds))
        error('Condition %d: current trials differ from the original variance trials.',R.condition_id);
    end
    validateattributes(R.n_bins,{'numeric'},{'scalar','integer','positive','finite'});
    if isfield(seq,'T')
        for r = 1:numel(seq)
            if ~isscalar(seq(r).T) || seq(r).T ~= R.n_bins
                error('Condition %d: current bin count differs from the original variance.',R.condition_id);
            end
        end
    end
    if numel(R.group) ~= numel(p.yDims)
        error('Condition %d: current and original group counts differ.',R.condition_id);
    end
    for g = 1:numel(ids)
        A = R.group(g);
        requireFieldsLocal(A,{'unit_ids','n_neurons','raw_var','reconstruction_var', ...
            'uncertainty_var','nLatents','counts','category_indices'},'original group variance');
        N = numel(ids{g});
        if ~isequal(double(A.unit_ids(:)),double(ids{g}(:))) || ...
                A.n_neurons ~= N || p.yDims(g) ~= N || ...
                A.nLatents ~= p.xDim_across+p.xDim_within(g)
            error('Condition %d group %d: neuron IDs or dimensions changed.',R.condition_id,g);
        end
        dims = p.xDim_across+p.xDim_within;
        offset = sum(dims(1:g-1));
        if ~isequal(double(A.category_indices{1}(:)'),offset+(1:p.xDim_across)) || ...
                ~isequal(double(A.category_indices{2}(:)'), ...
                offset+(p.xDim_across+1:dims(g)))
            error('Condition %d group %d: original latent partition differs from the model.',R.condition_id,g);
        end
        for f = {'raw_var','reconstruction_var','uncertainty_var'}
            assertSizeLocal(A.(f{1}),[N 5],['original ' f{1}]);
            if ~isnumeric(A.(f{1})) || ~isreal(A.(f{1}))
                error('Original %s must be real numeric.',f{1});
            end
        end
        if any(~isfinite(A.raw_var(:))) || any(A.raw_var(:)<0) || ...
                any(~isfinite(A.reconstruction_var(:))) || any(A.reconstruction_var(:)<0)
            error('Original raw/reconstruction variance contains invalid values.');
        end
        expected = double(A.reconstruction_var);
        if cfg.uncertainty_included
            if any(~isfinite(A.uncertainty_var(:))) || any(A.uncertainty_var(:)<0)
                error('Original uncertainty is invalid while uncertainty_included=1.');
            end
            expected = expected+double(A.uncertainty_var);
        end
        difference = double(A.raw_var)-expected;
        if max(abs(difference(:))) > 1e-8*max(1,max(abs(expected(:))))
            error('Original raw variance does not match its reconstruction/uncertainty components.');
        end
    end
end

function [means,validSamples,sourcePositions] = meanCountsForConditionLocal(S,seq,T,id)
    trialIds = extraTrialIdsLocal(seq,'seqEst');
    [ok,sourcePositions] = ismember(trialIds,S.trial_ids);
    if ~all(ok)
        error('Condition %d: reconstruction trial IDs missing from raw_count: %s', ...
            id,mat2str(trialIds(~ok)));
    end
    if any(S.condition_index(trialIds) ~= id)
        error('Mean-count trial IDs do not belong to condition %d.',id);
    end
    maskPositions = [];
    if ~isempty(S.mask_trials)
        [ok,maskPositions] = ismember(trialIds,S.mask_trial_ids);
        if ~all(ok), error('raw_count_nanmask lacks some condition %d trial IDs.',id); end
    end
    ng = numel(S.model_rows);
    totals = cell(1,ng);
    validSamples = cell(1,ng);
    for g = 1:ng
        totals{g} = zeros(numel(S.model_rows{g}),1);
        validSamples{g} = zeros(numel(S.model_rows{g}),1);
    end
    for r = 1:numel(trialIds)
        A = S.trials(sourcePositions(r));
        if ~isfield(A,'y') || ~isnumeric(A.y) || ~isreal(A.y)
            error('raw_count trial %d has no real numeric y array.',trialIds(r));
        end
        assertSizeLocal(A.y,[S.n_rows T],'raw_count versus reconstruction bins');
        if isfield(A,'T') && (~isscalar(A.T) || A.T ~= T)
            error('raw_count trial %d has a different analysis bin count.',trialIds(r));
        end
        missing = false(S.n_rows,T);
        if ~isempty(maskPositions)
            Q = S.mask_trials(maskPositions(r));
            if ~isfield(Q,'y'), error('raw_count_nanmask trial %d lacks y.',trialIds(r)); end
            assertSizeLocal(Q.y,[S.n_rows T],'raw_count_nanmask');
            if ~isreal(Q.y) || any(~ismember(double(Q.y(:)),[0 1]))
                error('raw_count_nanmask must contain only 0 or 1.');
            end
            missing = logical(Q.y);
        end
        for g = 1:ng
            rows = S.model_rows{g};
            Y = double(A.y(rows,:));
            good = isfinite(Y) & Y>=0 & ~missing(rows,:);
            validSamples{g} = validSamples{g}+sum(good,2);
            Y(~good) = 0; % only accumulate; an incomplete denominator becomes NaN below
            totals{g} = totals{g}+sum(Y,2);
        end
    end
    expectedSamples = numel(trialIds)*T;
    means = cell(1,ng);
    for g = 1:ng
        means{g} = totals{g}/expectedSamples;
        means{g}(validSamples{g}~=expectedSamples | ~isfinite(means{g})) = NaN;
    end
end

function [V,field,status] = allReconstructionVarianceLocal(seq,p,T,id)
% Use one representation for ALL trials. Mixing d+CX with CX would add offsets.
    N = sum(p.yDims);
    L = size(p.C,2);
    M = numel(seq);
    field = '';
    candidates = {'yRecon_use_all','yRecon_use_all_no_d'};
    for k = 1:numel(candidates)
        f = candidates{k};
        if isfield(seq,f) && all(arrayfun(@(s) ~isempty(s.(f)),seq))
            field = f;
            break;
        end
    end
    if ~isempty(field)
        status = 'saved_reconstruction';
    elseif L == 0
        V = zeros(N,T);
        status = 'known_zero_empty_category';
        return;
    elseif isfield(seq,'xsm')
        status = 'computed_from_saved_C_xsm';
    else
        error(['Condition %d: no complete saved All reconstruction or xsm. ', ...
            'Run data_reconstruction with the base reconstruction enabled.'],id);
    end
    mu = zeros(N,T);
    ss = zeros(N,T);
    C = double(p.C);
    for r = 1:M
        if ~isempty(field)
            Y = seq(r).(field);
            if ~isnumeric(Y) || ~isreal(Y)
                error('Condition %d trial %d: All reconstruction must be real numeric.',id,r);
            end
            assertSizeLocal(Y,[N T],'All reconstruction');
            Y = double(Y);
        else
            X = seq(r).xsm;
            if ~isnumeric(X) || ~isreal(X)
                error('Condition %d trial %d: xsm must be real numeric.',id,r);
            end
            assertSizeLocal(X,[L T],'All latent xsm');
            if any(~isfinite(X(:)))
                error('Condition %d trial %d: xsm contains nonfinite values.',id,r);
            end
            Y = C*double(X);
        end
        if any(~isfinite(Y(:)))
            error('Condition %d trial %d: All reconstruction contains nonfinite values.',id,r);
        end
        change = Y-mu;
        mu = mu+change/r;
        ss = ss+change.*(Y-mu);
    end
    V = max(ss/(M-1),0);
end

function E = calculatePosteriorExtraConditionLocal(R,seq,p,countSource,cfg,bestFile)
    id = R.condition_id;
    T = R.n_bins;
    [meanCount,validSamples,countPositions] = ...
        meanCountsForConditionLocal(countSource,seq,T,id);
    [allReconBin,allField,allStatus] = allReconstructionVarianceLocal(seq,p,T,id);
    L = size(p.C,2);
    meanV = [];
    if cfg.uncertainty_included && L>0
        meanV = averageVsmLocal(seq,L,T,id);
    end
    E = struct();
    fields = {'condition_id','feature_index','direction_index','direction_value', ...
        'condition_label','n_trials','n_bins','trial_ids'};
    for k = 1:numel(fields), E.(fields{k}) = R.(fields{k}); end
    E.bestmodel_file = bestFile;
    E.model_mode = cfg.model_mode;
    E.mean_count_trial_ids = extraTrialIdsLocal(seq,'seqEst');
    E.mean_count_source_trial_positions = countPositions;
    E.mean_count_expected_samples = numel(seq)*T;
    template = posteriorExtraGroupTemplateLocal();
    E.group = repmat(template,1,numel(p.yDims));
    dims = p.xDim_across+p.xDim_within;
    for g = 1:numel(p.yDims)
        old = R.group(g);
        rows = sum(p.yDims(1:g-1))+(1:p.yDims(g));
        N = numel(rows);
        G = template;
        G.name = old.name;
        G.unit_ids = double(old.unit_ids(:));
        G.n_neurons = N;
        G.counts = [reshape(old.counts,1,[]) dims(g)];
        G.nLatents = dims(g);
        G.all_latent_indices = sum(dims(1:g-1))+(1:dims(g));
        G.all_reconstruction_field = allField;
        G.all_reconstruction_status = allStatus;
        G.all_reconstruction_var_by_bin = allReconBin(rows,:);
        G.all_uncertainty_var_by_bin = nan(N,T);
        if dims(g) == 0
            if any(G.all_reconstruction_var_by_bin(:)>1e-10)
                error('Condition %d group %d: All variance is nonzero with zero latents.',id,g);
            end
            G.all_reconstruction_var_by_bin = zeros(N,T);
            G.all_reconstruction_status = 'known_zero_empty_category';
        end
        if cfg.uncertainty_included
            U = zeros(N,T);
            if L>0 && dims(g)>0
                C = double(p.C(rows,:));
                for t = 1:T
                    % Full C/Vsm propagation includes Across-Within covariance.
                    U(:,t) = sum((C*meanV(:,:,t)).*C,2);
                end
            end
            if any(~isfinite(U(:)))
                error('All posterior uncertainty is nonfinite in condition %d group %d.',id,g);
            end
            if any(U(:)<-1e-9*max(1,max(abs(U(:)))))
                error('All posterior uncertainty is negative beyond tolerance.');
            end
            G.all_uncertainty_var_by_bin = max(U,0);
        end
        allRecon = mean(G.all_reconstruction_var_by_bin,2);
        allUncertainty = mean(G.all_uncertainty_var_by_bin,2);
        allRaw = allRecon;
        if cfg.uncertainty_included, allRaw = allRaw+allUncertainty; end
        % Copy original columns exactly; never replace them with recomputation.
        G.raw_var = [old.raw_var allRaw];
        G.reconstruction_var = [old.reconstruction_var allRecon];
        G.uncertainty_var = [old.uncertainty_var allUncertainty];
        G.mean_count = meanCount{g};
        G.mean_count_valid_samples = validSamples{g};
        G.mean_count_source_rows = countSource.model_rows{g};
        G.normalization_valid = isfinite(G.mean_count) & G.mean_count>0;
        G.normalization_excluded_unit_ids = G.unit_ids(~G.normalization_valid);
        G.n_valid_mean_count = nnz(G.normalization_valid);
        G.normalized_var = normalizeByMeanCountLocal(G.raw_var,G.mean_count);
        G.normalized_reconstruction_var = ...
            normalizeByMeanCountLocal(G.reconstruction_var,G.mean_count);
        G.normalized_uncertainty_var = ...
            normalizeByMeanCountLocal(G.uncertainty_var,G.mean_count);
        for k = 1:3
            parts = {'raw','reconstruction','uncertainty'};
            part = parts{k};
            G.([part '_sum']) = sum(G.([part '_var']),1);
            G.([part '_mean']) = G.([part '_sum'])/N;
        end
        [G.normalized_sum,G.normalized_mean,G.normalized_n_neurons] = ...
            summarizeNormalizedRowsLocal(G.normalized_var);
        [G.normalized_reconstruction_sum,G.normalized_reconstruction_mean,unused] = ...
            summarizeNormalizedRowsLocal(G.normalized_reconstruction_var); %#ok<ASGLU>
        [G.normalized_uncertainty_sum,G.normalized_uncertainty_mean,unused] = ...
            summarizeNormalizedRowsLocal(G.normalized_uncertainty_var); %#ok<ASGLU>
        if ~all(G.normalization_valid)
            zeroIds = G.unit_ids(G.mean_count==0);
            badIds = G.unit_ids(~isfinite(G.mean_count));
            warning('posterior_rawvar:InvalidMeanCount', ...
                ['Condition %d, %s: normalized variance is NaN for %d/%d neurons. ', ...
                'Zero-mean model-used unit IDs: %s. Invalid/missing-count IDs: %s.'], ...
                id,cfg.group_names{g},nnz(~G.normalization_valid),N, ...
                mat2str(zeroIds'),mat2str(badIds'));
        end
        E.group(g) = orderfields(G,template);
        fprintf('  %s: All=%s; valid mean-count denominator %d/%d neurons.\n', ...
            cfg.group_names{g},G.all_reconstruction_status,G.n_valid_mean_count,N);
    end
end

function G = posteriorExtraGroupTemplateLocal()
    G = struct('name','','unit_ids',[],'n_neurons',[], ...
        'counts',[],'nLatents',[],'all_latent_indices',[], ...
        'all_reconstruction_field','','all_reconstruction_status','', ...
        'all_reconstruction_var_by_bin',[],'all_uncertainty_var_by_bin',[], ...
        'raw_var',[],'reconstruction_var',[],'uncertainty_var',[], ...
        'mean_count',[],'mean_count_valid_samples',[],'mean_count_source_rows',[], ...
        'normalization_valid',[],'normalization_excluded_unit_ids',[], ...
        'n_valid_mean_count',[], ...
        'normalized_var',[],'normalized_reconstruction_var',[],'normalized_uncertainty_var',[], ...
        'raw_sum',[],'raw_mean',[],'reconstruction_sum',[],'reconstruction_mean',[], ...
        'uncertainty_sum',[],'uncertainty_mean',[], ...
        'normalized_sum',[],'normalized_mean',[],'normalized_n_neurons',[], ...
        'normalized_reconstruction_sum',[],'normalized_reconstruction_mean',[], ...
        'normalized_uncertainty_sum',[],'normalized_uncertainty_mean',[]);
end

function Y = normalizeByMeanCountLocal(X,denominator)
    d = double(denominator(:));
    d(~isfinite(d) | d<=0) = NaN;
    Y = bsxfun(@rdivide,double(X),d);
end

function [total,average,n] = summarizeNormalizedRowsLocal(X)
% A group mean is mean(neuron variance / neuron mean count), not a ratio
% of two group means. An entirely undefined column remains NaN.
    good = isfinite(X);
    n = sum(good,1);
    Y = X;
    Y(~good) = 0;
    total = sum(Y,1);
    total(n==0) = NaN;
    average = total./n;
end

function X = packPosteriorExtraLocal(results,P,metadata,cfg,filename,reused)
    X = struct();
    X.format_version = 'posterior_rawvar_extra_v1';
    X.labels = {'Across','Within','Feedforward','Feedback','Ambiguous','All'};
    X.meta = P.meta;
    X.meta.created_by = 'posterior_rawvar.m';
    X.meta.created_on = datestr(now,30);
    X.meta.code_revision = '20261022_all_latents_mean_count_append';
    X.meta.model_mode = cfg.model_mode;
    X.meta.mode_tag = cfg.mode_tag;
    X.meta.data_condition = cfg.data_condition;
    X.meta.original_variable = 'PosteriorRawVar';
    X.meta.original_format_version = P.format_version;
    X.meta.original_created_on = '';
    if isfield(P.meta,'created_on'), X.meta.original_created_on = P.meta.created_on; end
    X.meta.original_reused_without_recalculation = logical(reused);
    X.meta.original_file = filename;
    X.meta.raw_unit = 'squared model data_content units';
    X.meta.normalized_unit = 'squared model data_content units / mean spikes per bin';
    X.meta.mean_count_source_file = cfg.dat_file;
    X.meta.mean_count_source_field = 'raw_count';
    X.meta.mean_count_source_stim_tag = cfg.stim_tag;
    X.meta.mean_count_definition = 'Mean original spike count over matched variance trials and all matching analysis bins';
    X.meta.mean_count_unit = 'spikes_per_bin';
    X.meta.mean_count_missing_policy = 'Any missing/invalid count sample -> NaN denominator; no sample dropping';
    X.meta.zero_mean_count_policy = 'Undefined normalized variance -> NaN; no epsilon or zero substitution';
    X.meta.response_normalizations = {'none','mean_count'};
    X.meta.response_normalization_fields = {'raw_var','normalized_var'};
    X.meta.normalization_order = 'Divide each neuron/condition variance before neuron/direction averaging and feature differences';
    X.meta.all_variance_method = 'Variance of the summed All response, with empirical cross-latent covariance';
    X.meta.all_uncertainty_method = 'Full diag(C*mean_trial(Vsm)*C'') per bin, including Across-Within posterior covariance';
    X.meta.zscore = 'Not computed; All must not enter the legacy five-category Z reference';
    X.meta.id_definition = 'Same model-used group/probe/unit IDs as PosteriorRawVar; rows aligned to raw_count by these IDs';
    X.meta.bin_size = NaN;
    X.meta.analysis_window = [];
    X.meta.bin_edges = [];
    X.meta.bin_centers = [];
    for f = {'bin_size','analysis_window','bin_edges','bin_centers','group_probe','group_name'}
        if isfield(metadata,f{1}), X.meta.(f{1}) = metadata.(f{1}); end
    end
    X.settings = cfg;
    X.condition_ids = P.condition_ids;
    X.condition = results;
    X.dimension_names.per_neuron_variance = {'neuron','latent_category'};
    X.dimension_names.all_variance_by_bin = {'neuron','time_bin'};
    X.dimension_names.summary = {'stimulus_combination','latent_category'};
    X.group = repmat(struct('name','','stim_dir',struct([])),1,numel(cfg.group_names));
    vectors = {'raw_mean','raw_sum','reconstruction_mean','reconstruction_sum', ...
        'uncertainty_mean','uncertainty_sum','normalized_mean','normalized_sum', ...
        'normalized_reconstruction_mean','normalized_reconstruction_sum', ...
        'normalized_uncertainty_mean','normalized_uncertainty_sum', ...
        'normalized_n_neurons','counts'};
    for g = 1:numel(cfg.group_names)
        X.group(g).name = cfg.group_names{g};
        for d = 1:2
            A = struct('conditionIds',X.condition_ids(:,d));
            for k = 1:numel(vectors), A.(vectors{k}) = nan(8,6); end
            A.n_neurons = nan(8,1);
            A.n_valid_mean_count = nan(8,1);
            A.n_trials = nan(8,1);
            A.n_bins = nan(8,1);
            for ci = 1:numel(results)
                R = results(ci);
                if R.direction_index ~= d, continue; end
                row = R.feature_index;
                G = R.group(g);
                for k = 1:numel(vectors), A.(vectors{k})(row,:) = G.(vectors{k}); end
                A.n_neurons(row) = G.n_neurons;
                A.n_valid_mean_count(row) = G.n_valid_mean_count;
                A.n_trials(row) = R.n_trials;
                A.n_bins(row) = R.n_bins;
            end
            if d == 1
                X.group(g).stim_dir = A;
            else
                X.group(g).stim_dir(d) = orderfields(A,X.group(g).stim_dir(1));
            end
        end
    end
end

function X = readCachedPosteriorExtraLocal(filename,P,metadata,cfg)
% An existing complete count extension is authoritative for this conversion.
% Reuse its means/variances; do not load models, xsm or Vsm again.
    X=[];
    if ~ismember('PosteriorRawVarExtra',who('-file',filename)), return; end
    S=load(filename,'PosteriorRawVarExtra'); X=S.PosteriorRawVarExtra;
    requireFieldsLocal(X,{'format_version','meta','labels','condition_ids','condition','group'}, ...
        'cached PosteriorRawVarExtra');
    if ~strcmp(char(X.format_version),'posterior_rawvar_extra_v1') || ...
            ~isequal(X.labels,{'Across','Within','Feedforward','Feedback','Ambiguous','All'})
        error('Existing PosteriorRawVarExtra has an unsupported format/column order: %s',filename);
    end
    requireFieldsLocal(X.meta,{'data_content','runIdx','model_mode','uncertainty_included', ...
        'original_created_on','mean_count_source_field','mean_count_source_stim_tag'},'cached Extra.meta');
    if ~strcmp(char(X.meta.data_content),cfg.data_content) || X.meta.runIdx~=cfg.runIdx || ...
            ~strcmp(char(X.meta.model_mode),cfg.model_mode) || ...
            double(X.meta.uncertainty_included)~=double(cfg.uncertainty_included) || ...
            ~strcmp(char(X.meta.mean_count_source_field),'raw_count') || ...
            ~strcmp(char(X.meta.mean_count_source_stim_tag),cfg.stim_tag) || ...
            ~isequal(X.condition_ids,P.condition_ids) || numel(X.condition)~=numel(P.condition)
        error('Cached count results do not match this mode/content/run/u/condition selection: %s',filename);
    end
    if isfield(P.meta,'created_on') && ~strcmp(char(X.meta.original_created_on),char(P.meta.created_on))
        error('Cached Extra belongs to a different original result: %s',filename);
    end
    dt=dvBinSecondsLocal(metadata,'model_data_allruns');
    olddt=dvBinSecondsLocal(X.meta,'cached Extra.meta');
    if abs(dt-olddt)>1e-9*dt, error('Cached count results use a different bin width.'); end
    ids=[X.condition.condition_id];
    if numel(unique(ids))~=numel(ids), error('Duplicate cached Extra condition IDs.'); end
    for ci=1:numel(P.condition)
        A=P.condition(ci); k=find(ids==A.condition_id);
        if numel(k)~=1, error('Cached Extra is missing condition %d.',A.condition_id); end
        B=X.condition(k);
        if B.direction_index~=A.direction_index || B.feature_index~=A.feature_index || ...
                B.direction_value~=A.direction_value || B.n_trials~=A.n_trials || B.n_bins~=A.n_bins || ...
                ~isequal(B.trial_ids,A.trial_ids) || numel(B.group)~=numel(A.group)
            error('Cached Extra trial/condition identities disagree with the original result.');
        end
        for g=1:numel(A.group)
            old=A.group(g); G=B.group(g); N=numel(old.unit_ids);
            if ~isequal(G.unit_ids,old.unit_ids) || G.n_neurons~=old.n_neurons
                error('Cached Extra neuron identities disagree with the original result.');
            end
            for f={'raw_var','reconstruction_var','uncertainty_var'}
                assertSizeLocal(G.(f{1}),[N 6],['cached Extra.' f{1}]);
                if ~isequaln(G.(f{1})(:,1:5),old.(f{1}))
                    error('Cached Extra first five columns differ from the original %s.',f{1});
                end
            end
            assertSizeLocal(G.mean_count,[N 1],'cached mean_count');
            for f={'raw','reconstruction','uncertainty'}
                if strcmp(f{1},'raw'), dest='normalized_var'; else, dest=['normalized_' f{1} '_var']; end
                expected=normalizeByMeanCountLocal(G.([f{1} '_var']),G.mean_count);
                assertSizeLocal(G.(dest),[N 6],['cached ' dest]);
                if ~isequaln(expected,G.(dest)), error('Cached normalized count values are inconsistent.'); end
            end
        end
    end
    fprintf('Reusing saved six-category results without changing the saved Extra variable.\n');
end

function X = addPosteriorRateFieldsLocal(X,metadata,cfg)
    if ~contains(lower(cfg.data_content),'count')
        error('Rate conversion requires count-based data_content, such as demean_count_within_t_and_condition.');
    end
    dt=dvBinSecondsLocal(metadata,'model_data_allruns');
    X.meta.bin_size_seconds=dt;
    X.meta.rate_unit='(spikes/second)^2';
    X.meta.normalized_rate_unit='spikes/second';
    X.meta.rate_mean_response_unit='spikes/second';
    X.meta.rate_normalization_denominator='mean_rate';
    X.meta.rate_variance_definition='rate_var = raw_var / bin_size_seconds^2';
    X.meta.rate_normalized_definition='normalized_rate_var = normalized_var / bin_size_seconds';
    X.meta.mean_rate_definition='mean_rate = mean_count / bin_size_seconds';
    X.meta.rate_conversion_created_on=datestr(now,30);
    X.meta.rate_conversion_source='Existing six-category count arrays; no latent reconstruction or refit';
    for ci=1:numel(X.condition)
        X.condition(ci).group=posteriorRateFieldsLocal(X.condition(ci).group,dt);
    end
    for g=1:numel(X.group)
        X.group(g).stim_dir=posteriorRateFieldsLocal(X.group(g).stim_dir,dt);
    end
end

function A = posteriorRateFieldsLocal(A,dt)
% Add fields to the WHOLE struct array; never assign dissimilar elements.
    source={'raw_var','reconstruction_var','uncertainty_var', ...
        'raw_sum','raw_mean','reconstruction_sum','reconstruction_mean','uncertainty_sum','uncertainty_mean', ...
        'all_reconstruction_var_by_bin','all_uncertainty_var_by_bin', ...
        'normalized_var','normalized_reconstruction_var','normalized_uncertainty_var', ...
        'normalized_sum','normalized_mean','normalized_reconstruction_sum', ...
        'normalized_reconstruction_mean','normalized_uncertainty_sum','normalized_uncertainty_mean'};
    target={'rate_var','rate_reconstruction_var','rate_uncertainty_var', ...
        'rate_sum','rate_mean','rate_reconstruction_sum','rate_reconstruction_mean','rate_uncertainty_sum','rate_uncertainty_mean', ...
        'all_rate_reconstruction_var_by_bin','all_rate_uncertainty_var_by_bin', ...
        'normalized_rate_var','normalized_rate_reconstruction_var','normalized_rate_uncertainty_var', ...
        'normalized_rate_sum','normalized_rate_mean','normalized_rate_reconstruction_sum', ...
        'normalized_rate_reconstruction_mean','normalized_rate_uncertainty_sum','normalized_rate_uncertainty_mean'};
    power=[2*ones(1,11) ones(1,9)];
    for k=1:numel(source)
        if ~isfield(A,source{k}), continue; end
        for j=1:numel(A), A(j).(target{k})=A(j).(source{k})/dt^power(k); end
    end
    if isfield(A,'mean_count')
        for j=1:numel(A), A(j).mean_rate=A(j).mean_count/dt; end
    end
end

function dt = dvBinSecondsLocal(meta,context)
% processing_to_count_and_fr stores bin_size/bin_edges/bin_centers in SECONDS.
    dt=NaN;
    if isfield(meta,'bin_size_seconds') && ~isempty(meta.bin_size_seconds)
        dt=double(meta.bin_size_seconds);
    elseif isfield(meta,'bin_size') && ~isempty(meta.bin_size)
        dt=double(meta.bin_size);
    end
    if ~isnumeric(dt) || ~isreal(dt) || ~isscalar(dt) || ~isfinite(dt) || dt<=0
        error('variance_units:BinWidth', ...
            '%s must provide a finite positive bin_size in seconds; no bin width is guessed.',context);
    end
    if isfield(meta,'bin_size') && isnumeric(meta.bin_size) && ...
            isscalar(meta.bin_size) && isfinite(meta.bin_size) && ...
            abs(double(meta.bin_size)-dt)>1e-9*max(dt,eps)
        error('variance_units:BinWidth','bin_size and bin_size_seconds disagree in %s.',context);
    end
    for f={'bin_edges','bin_centers'}
        if ~isfield(meta,f{1}) || isempty(meta.(f{1})), continue; end
        v=double(meta.(f{1}));
        if ~isreal(v) || ~isvector(v) || any(~isfinite(v(:)))
            error('variance_units:BinWidth','Invalid %s in %s.',f{1},context);
        end
        if numel(v)>1 && any(abs(diff(v(:))-dt)>1e-7*max(dt,eps))
            error('variance_units:BinWidth','%s does not match bin_size in seconds in %s.',f{1},context);
        end
    end
end


function Q = calculatePosteriorNoiseLocal(P,X,metadata,ids,yDims,cfg)
% Expected M-1 sample variance of y-C*x-d, conditional on fixed parameters.
% For independent trial posteriors, the correction is MEAN trial covariance,
% not sum/(M-1). Off-diagonal latent covariance is retained. No model R is used.
    Q = struct();
    Q.format_version = 'posterior_rawvar_noise_v1';
    Q.labels = {'Noise'};
    Q.meta = X.meta;
    Q.meta.created_on = datestr(now,30);
    Q.meta.created_by = 'posterior_rawvar.m';
    Q.meta.code_revision = '20261028_posterior_residual_noise';
    Q.meta.noise_definition = 'posterior_residual_y_minus_all';
    Q.meta.residual_method = 'mean_t_var_trial_seqEst_y_minus_posterior_mean_All_Mminus1';
    Q.meta.uncertainty_method = 'mean_trial_bin_diag_full_C_Vsm_C_transpose';
    Q.meta.uncertainty_included = cfg.uncertainty_included;
    Q.meta.original_variable = 'PosteriorRawVar';
    Q.meta.extra_variable = 'PosteriorRawVarExtra';
    Q.meta.extra_created_on = X.meta.created_on;
    Q.meta.bin_size_seconds = dvBinSecondsLocal(metadata,'model_data_allruns');
    Q.meta.count_unit = 'spikes_per_bin_squared';
    Q.meta.rate_unit = '(spikes/second)^2';
    Q.meta.normalized_count_unit = 'spikes_per_bin';
    Q.meta.normalized_rate_unit = 'spikes/second';
    Q.meta.rate_variance_definition = 'rate_var = raw_var / bin_size_seconds^2';
    Q.meta.rate_normalized_definition = 'normalized_rate_var = normalized_var / bin_size_seconds';
    Q.meta.noise_is_model_R = false;
    Q.meta.uncertainty_assumption = 'Fixed fitted parameters; independent posterior trials';
    Q.settings = cfg;
    Q.condition_ids = X.condition_ids;
    Q.condition = struct([]);
    isAll = strcmp(cfg.model_mode,'all_condition');
    if isAll
        runDir = fullfile(cfg.session_dir,['FA_Dlag_' cfg.data_content], ...
            'mat_results',sprintf('run%03d',cfg.runIdx));
        [B,p,bestFile] = loadPosteriorBaseForExtraLocal(runDir,yDims,ids,[],cfg);
        cond = trialConditionIdsLocal(B.seqEst,metadata,numel(metadata.conditions_full),bestFile);
    end
    for ci = 1:numel(X.condition)
        E = X.condition(ci); id = E.condition_id;
        if isAll
            seq = B.seqEst(cond==id);
        else
            runDir = fullfile(cfg.session_dir,sprintf('FA_Dlag_%s_condition%d',cfg.data_content,id), ...
                'mat_results',sprintf('run%03d',cfg.runIdx));
            [B,p,bestFile] = loadPosteriorBaseForExtraLocal(runDir,yDims,ids,id,cfg);
            seq = B.seqEst;
        end
        old = P.condition([P.condition.condition_id]==id);
        validateConditionForExtraLocal(old,seq,p,ids,cfg);
        if any(trialConditionIdsLocal(seq,metadata,numel(metadata.conditions_full),bestFile)~=id)
            error('Noise: trial-to-condition mapping disagrees in condition %d.',id);
        end
        [residualBin,allBin,reconField] = noiseResidualBinsLocal(seq,p,E.n_bins,id);
        C = struct();
        for f = {'condition_id','feature_index','direction_index','direction_value', ...
                'condition_label','n_trials','n_bins','trial_ids'}
            C.(f{1}) = E.(f{1});
        end
        C.bestmodel_file = bestFile;
        C.model_mode = cfg.model_mode;
        C.reconstruction_field = reconField;
        C.observation_field = 'seqEst.y';
        groups = cell(1,numel(yDims));
        for g = 1:numel(yDims)
            A = E.group(g);
            rows = sum(yDims(1:g-1))+(1:yDims(g));
            % A stale model/reconstruction must not be mixed with cached variance.
            noiseNearLocal(mean(allBin(rows,:),2),A.reconstruction_var(:,6), ...
                sprintf('saved All reconstruction, condition %d group %d',id,g));
            if isfield(A,'all_reconstruction_var_by_bin')
                noiseNearLocal(allBin(rows,:),A.all_reconstruction_var_by_bin, ...
                    sprintf('saved All per-bin variance, condition %d group %d',id,g));
            end
            G = struct('name',A.name,'unit_ids',A.unit_ids,'n_neurons',A.n_neurons);
            G.residual_var_by_bin = residualBin(rows,:);
            G.uncertainty_var_by_bin = nan(size(G.residual_var_by_bin));
            if cfg.uncertainty_included
                % All's correction is exactly the residual's posterior correction.
                requireFieldsLocal(A,{'all_uncertainty_var_by_bin'},'saved All uncertainty');
                U = double(A.all_uncertainty_var_by_bin);
                assertSizeLocal(U,[numel(rows) E.n_bins],'Noise uncertainty');
                if any(~isfinite(U(:)) | U(:)<0)
                    error('Saved All uncertainty is invalid in condition %d group %d.',id,g);
                end
                noiseNearLocal(mean(U,2),A.uncertainty_var(:,6),'saved All uncertainty average');
                G.uncertainty_var_by_bin = U;
            end
            G.residual_var = mean(G.residual_var_by_bin,2);
            G.uncertainty_var = mean(G.uncertainty_var_by_bin,2);
            G.raw_var_by_bin = G.residual_var_by_bin;
            G.raw_var = G.residual_var;
            if cfg.uncertainty_included
                G.raw_var_by_bin = G.raw_var_by_bin+G.uncertainty_var_by_bin;
                G.raw_var = G.raw_var+G.uncertainty_var;
            end
            G.mean_count = A.mean_count; % exact same neuron/condition denominator
            G.mean_rate = G.mean_count/Q.meta.bin_size_seconds;
            G.normalization_valid = isfinite(G.mean_count) & G.mean_count>0;
            G.normalization_excluded_unit_ids = G.unit_ids(~G.normalization_valid);
            G.n_valid_mean_count = nnz(G.normalization_valid);
            G.normalized_var = normalizeByMeanCountLocal(G.raw_var,G.mean_count);
            G.normalized_residual_var = normalizeByMeanCountLocal(G.residual_var,G.mean_count);
            G.normalized_uncertainty_var = normalizeByMeanCountLocal(G.uncertainty_var,G.mean_count);
            countFields = {'raw_var','residual_var','uncertainty_var','raw_var_by_bin', ...
                'residual_var_by_bin','uncertainty_var_by_bin','normalized_var', ...
                'normalized_residual_var','normalized_uncertainty_var'};
            rateFields = {'rate_var','rate_residual_var','rate_uncertainty_var','rate_var_by_bin', ...
                'rate_residual_var_by_bin','rate_uncertainty_var_by_bin','normalized_rate_var', ...
                'normalized_rate_residual_var','normalized_rate_uncertainty_var'};
            for k = 1:numel(countFields)
                power = 2; if k>=7, power=1; end
                G.(rateFields{k}) = G.(countFields{k})/Q.meta.bin_size_seconds^power;
            end
            % Each summary is computed AFTER per-neuron normalization.
            names = {'raw','residual','uncertainty','normalized','normalized_residual', ...
                'normalized_uncertainty','rate','rate_residual','rate_uncertainty', ...
                'normalized_rate','normalized_rate_residual','normalized_rate_uncertainty'};
            for k = 1:numel(names)
                key = names{k};
                [total,avg,n] = summarizeNormalizedRowsLocal(G.([key '_var']));
                G.([key '_sum'])=total; G.([key '_mean'])=avg; G.([key '_n_neurons'])=n;
            end
            groups{g} = G;
        end
        C.group = [groups{:}];
        if ci==1, Q.condition=C; else, Q.condition(ci)=orderfields(C,Q.condition(1)); end
        fprintf('  Residual Noise: condition %d, %d trials, u%d (old latent results unchanged).\n', ...
            id,E.n_trials,cfg.uncertainty_included);
    end
    Q.group = repmat(struct('name','','stim_dir',struct([])),1,numel(yDims));
    for g = 1:numel(yDims)
        Q.group(g).name = cfg.group_names{g};
        dirs = cell(1,2);
        for d = 1:2
            D = struct('conditionIds',Q.condition_ids(:,d),'n_neurons',nan(8,1), ...
                'n_trials',nan(8,1),'n_bins',nan(8,1));
            for k = 1:numel(names)
                for suffix = {'_sum','_mean','_n_neurons'}
                    D.([names{k} suffix{1}]) = nan(8,1);
                end
            end
            for ci = 1:numel(Q.condition)
                E = Q.condition(ci); if E.direction_index~=d, continue; end
                row=E.feature_index; G=E.group(g);
                D.n_neurons(row)=G.n_neurons; D.n_trials(row)=E.n_trials; D.n_bins(row)=E.n_bins;
                for k=1:numel(names)
                    for suffix={'_sum','_mean','_n_neurons'}
                        f=[names{k} suffix{1}]; D.(f)(row)=G.(f);
                    end
                end
            end
            dirs{d}=D;
        end
        Q.group(g).stim_dir=[dirs{:}];
    end
end

function [V,allV,field,totalV] = noiseResidualBinsLocal(seq,p,T,id)
% Choose one All representation for every trial. Constant d cancels in each
% per-bin trial variance, so no-d and C*xsm fallbacks are exactly equivalent.
    ny=sum(p.yDims); L=size(p.C,2); M=numel(seq);
    if M<2 || ~isfield(seq,'y'), error('Noise needs seqEst.y and at least two trials.'); end
    field='';
    for candidate={'yRecon_use_all','yRecon_use_all_no_d'}
        f=candidate{1};
        if isfield(seq,f) && all(arrayfun(@(s) ~isempty(s.(f)),seq))
            field=f; break;
        end
    end
    if isempty(field) && L>0 && ~isfield(seq,'xsm')
        error('Noise: condition %d lacks All reconstruction and xsm.',id);
    end
    mu=zeros(ny,T); ss=mu; amu=mu; ass=mu;
    ymu=mu; yss=mu;
    for r=1:M
        Y=seq(r).y;
        assertSizeLocal(Y,[ny T],'Noise observation y');
        if ~isnumeric(Y) || ~isreal(Y) || any(~isfinite(Y(:)))
            error('Noise: condition %d trial %d has invalid observation y.',id,r);
        end
        if ~isempty(field)
            H=seq(r).(field);
        elseif L==0
            H=zeros(ny,T);
        else
            X=seq(r).xsm; assertSizeLocal(X,[L T],'Noise xsm');
            if ~isnumeric(X) || ~isreal(X) || any(~isfinite(X(:)))
                error('Noise: invalid xsm in condition %d trial %d.',id,r);
            end
            H=double(p.C)*double(X);
        end
        assertSizeLocal(H,[ny T],'Noise All reconstruction');
        if ~isnumeric(H) || ~isreal(H) || any(~isfinite(H(:)))
            error('Noise: invalid All reconstruction in condition %d trial %d.',id,r);
        end
        if nargout>=4
            Y=double(Y); dy=Y-ymu; ymu=ymu+dy/r; yss=yss+dy.*(Y-ymu);
        end
        H=double(H); R=double(Y)-H;
        delta=R-mu; mu=mu+delta/r; ss=ss+delta.*(R-mu);
        delta=H-amu; amu=amu+delta/r; ass=ass+delta.*(H-amu);
    end
    V=max(ss/(M-1),0); allV=max(ass/(M-1),0);
    totalV=[]; if nargout>=4, totalV=max(yss/(M-1),0); end
    if isempty(field), field='computed_C_xsm_no_d'; end
end

function noiseNearLocal(A,B,label)
    A=double(A); B=double(B);
    if ~isequal(size(A),size(B)) || any(~isfinite(A(:))) || any(~isfinite(B(:)))
        error('Noise: incompatible %s.',label);
    end
    if ~isempty(A) && max(abs(A(:)-B(:)))>1e-8*max(1,max(abs(B(:))))
        error(['Noise does not match %s. The model/reconstruction may have changed ', ...
            'since the latent variances were saved. Existing results were not modified.'],label);
    end
end

function S = readCachedObservedExtensionLocal(file,variable,X,cfg)
% Never overwrite an existing Noise/Total variable, including its metadata.
    S=[];
    if ~isfile(file) || ~ismember(variable,who('-file',file)), return; end
    loaded=load(file,variable); S=loaded.(variable);
    isTotal=strcmp(variable,'PosteriorRawVarTotal');
    if isTotal, kind='total'; else, kind='noise'; end
    requireFieldsLocal(S,{'format_version','meta','labels','condition_ids','condition','group'},variable);
    if ~strcmp(S.format_version,['posterior_rawvar_' kind '_v1'])
        error('Unsupported existing %s; it was not modified.',variable);
    end
    requireFieldsLocal(S.meta,{'extra_created_on','model_mode','data_content','runIdx', ...
        'uncertainty_included','variance_method','variance_normalization'},[variable '.meta']);
    if ~strcmp(S.meta.extra_created_on,X.meta.created_on) || ...
            ~strcmp(S.meta.model_mode,cfg.model_mode) || ~strcmp(S.meta.data_content,cfg.data_content) || ...
            S.meta.runIdx~=cfg.runIdx || ~isequaln(S.condition_ids,X.condition_ids) || ...
            numel(S.condition)~=numel(X.condition) || ...
            ~strcmp(S.meta.variance_method,'across_trials_per_bin_mean_over_bins') || ...
            ~strcmp(S.meta.variance_normalization,'M-1')
        error('Existing %s does not match the saved latent result; it was not modified.',variable);
    end
    if isTotal
        requireFieldsLocal(S.meta,{'source_uncertainty_included','total_definition'},'Total.meta');
        if S.meta.uncertainty_included~=0 || ...
                double(S.meta.source_uncertainty_included)~=double(cfg.uncertainty_included) || ...
                ~strcmp(S.meta.total_definition,'observed_y_trial_variance') || ~isequal(S.labels,{'Total'})
            error('Existing Total must be observed variance without posterior uncertainty.');
        end
    else
        if double(S.meta.uncertainty_included)~=double(cfg.uncertainty_included) || ...
                ~strcmp(S.meta.noise_definition,'posterior_residual_y_minus_all') || ...
                ~strcmp(S.meta.uncertainty_method,'mean_trial_bin_diag_full_C_Vsm_C_transpose') || ...
                ~isequal(S.labels,{'Noise'})
            error('Existing Noise does not match the selected residual/u definition.');
        end
    end
    dt=dvBinSecondsLocal(X.meta,'Extra.meta'); sdt=dvBinSecondsLocal(S.meta,[variable '.meta']);
    if abs(dt-sdt)>1e-9*dt, error('Existing %s bin width differs from Extra.',variable); end
    cids=[S.condition.condition_id];
    if numel(unique(cids))~=numel(cids) || ~isequal(sort(cids),sort([X.condition.condition_id]))
        error('Existing %s condition records are inconsistent.',variable);
    end
    for ci=1:numel(X.condition)
        E=X.condition(ci); C=S.condition(cids==E.condition_id);
        for f={'feature_index','direction_index','direction_value','n_trials','n_bins','trial_ids','model_mode'}
            if ~isequaln(C.(f{1}),E.(f{1})), error('%s has mismatched %s.',variable,f{1}); end
        end
        if numel(C.group)~=numel(E.group), error('%s group count differs.',variable); end
        for g=1:numel(E.group)
            A=E.group(g); B=C.group(g); N=numel(A.unit_ids);
            if ~isequal(B.unit_ids,A.unit_ids) || B.n_neurons~=N || ~isequaln(B.mean_count,A.mean_count)
                error('%s neuron IDs/count/mean-count differ from Extra.',variable);
            end
            assertSizeLocal(B.raw_var,[N 1],[variable '.raw_var']);
            assertSizeLocal(B.raw_var_by_bin,[N E.n_bins],[variable '.raw_var_by_bin']);
            if any(~isfinite(B.raw_var_by_bin(:)) | B.raw_var_by_bin(:)<0)
                error('%s contains invalid per-bin variance.',variable);
            end
            noiseNearLocal(B.raw_var,mean(B.raw_var_by_bin,2),[variable ' bin average']);
            if ~isTotal
                expected=B.residual_var;
                if cfg.uncertainty_included
                    noiseNearLocal(B.uncertainty_var,A.uncertainty_var(:,6),'Noise versus All uncertainty');
                    expected=expected+B.uncertainty_var;
                end
                noiseNearLocal(B.raw_var,expected,'cached Noise selected variance');
            end
            countExpected=normalizeByMeanCountLocal(B.raw_var,A.mean_count);
            if ~isequaln(B.normalized_var,countExpected) || ...
                    ~isequaln(B.rate_var,B.raw_var/dt^2) || ...
                    ~isequaln(B.normalized_rate_var,countExpected/dt)
                error('Existing %s count/rate normalization is inconsistent.',variable);
            end
        end
    end
    fprintf('Reusing %s without rewriting any of its fields.\n',variable);
end

function O = calculatePosteriorTotalLocal(P,X,Q,metadata,ids,yDims,cfg)
% Actual observed per-bin M-1 trial variance. NOT All reconstruction and NOT
% the sum of component variances. Observations y are fixed under the posterior:
% no uncertainty correction is added, so Total is identical for u0/u1 on the
% same trials. A fixed per-bin PSTH subtraction leaves this variance unchanged.
    if ~contains(lower(cfg.data_content),'count')
        error('Observed count/rate Total requires count-based model observations.');
    end
    O=struct('format_version','posterior_rawvar_total_v1','labels',{{'Total'}});
    O.meta=struct();
    keep={'data_content','runIdx','stim_tag','group_names','model_mode','mode_tag', ...
        'data_condition','trial_assignment','variance_method','variance_normalization', ...
        'conditionShortLabels','dirValues','conditionMap','bin_size','analysis_window', ...
        'bin_edges','bin_centers','group_probe','group_name','mean_count_source_file', ...
        'mean_count_source_field','mean_count_source_stim_tag','mean_count_definition', ...
        'mean_count_unit','mean_count_missing_policy','zero_mean_count_policy', ...
        'normalization_order','id_definition'};
    for k=1:numel(keep)
        if isfield(X.meta,keep{k}), O.meta.(keep{k})=X.meta.(keep{k}); end
    end
    dt=dvBinSecondsLocal(metadata,'model_data_allruns');
    O.meta.created_on=datestr(now,30);
    O.meta.created_by='posterior_rawvar.m';
    O.meta.code_revision='20261029_observed_total_append';
    O.meta.variance_source='observed';
    O.meta.total_definition='observed_y_trial_variance';
    O.meta.observation_field='seqEst.y';
    O.meta.total_method='mean_t_var_trial_seqEst_y_Mminus1';
    O.meta.uncertainty_included=false;
    O.meta.source_uncertainty_included=cfg.uncertainty_included;
    O.meta.uncertainty_method='none_observed_data';
    O.meta.original_variable='PosteriorRawVar';
    O.meta.extra_variable='PosteriorRawVarExtra';
    O.meta.extra_created_on=X.meta.created_on;
    O.meta.bin_size_seconds=dt;
    O.meta.count_unit='spikes_per_bin_squared';
    O.meta.raw_unit='spikes_per_bin_squared';
    O.meta.rate_unit='(spikes/second)^2';
    O.meta.normalized_count_unit='spikes_per_bin';
    O.meta.normalized_rate_unit='spikes/second';
    O.meta.rate_variance_definition='rate_var = raw_var / bin_size_seconds^2';
    O.meta.rate_normalized_definition='normalized_rate_var = normalized_var / bin_size_seconds';
    O.meta.total_is_component_sum=false;
    O.settings=cfg;
    O.dimension_names.per_neuron_variance={'neuron','Total'};
    O.dimension_names.variance_by_bin={'neuron','time_bin'};
    O.condition_ids=X.condition_ids;
    conditionRecords=cell(1,numel(X.condition));
    isAll=strcmp(cfg.model_mode,'all_condition');
    if isAll
        runDir=fullfile(cfg.session_dir,['FA_Dlag_' cfg.data_content], ...
            'mat_results',sprintf('run%03d',cfg.runIdx));
        [B,p,bestFile]=loadPosteriorBaseForExtraLocal(runDir,yDims,ids,[],cfg);
        cond=trialConditionIdsLocal(B.seqEst,metadata,numel(metadata.conditions_full),bestFile);
    end
    for ci=1:numel(X.condition)
        E=X.condition(ci); id=E.condition_id;
        if isAll
            seq=B.seqEst(cond==id);
        else
            runDir=fullfile(cfg.session_dir,sprintf('FA_Dlag_%s_condition%d',cfg.data_content,id), ...
                'mat_results',sprintf('run%03d',cfg.runIdx));
            [B,p,bestFile]=loadPosteriorBaseForExtraLocal(runDir,yDims,ids,id,cfg);
            seq=B.seqEst;
        end
        old=P.condition([P.condition.condition_id]==id);
        validateConditionForExtraLocal(old,seq,p,ids,cfg);
        if any(trialConditionIdsLocal(seq,metadata,numel(metadata.conditions_full),bestFile)~=id)
            error('Total: trial-to-condition mapping disagrees in condition %d.',id);
        end
        [residualBin,allBin,reconField,totalBin]=noiseResidualBinsLocal(seq,p,E.n_bins,id);
        Qc=Q.condition([Q.condition.condition_id]==id);
        C=struct();
        for f={'condition_id','feature_index','direction_index','direction_value', ...
                'condition_label','n_trials','n_bins','trial_ids'}
            C.(f{1})=E.(f{1});
        end
        C.bestmodel_file=bestFile; C.model_mode=cfg.model_mode;
        C.observation_field='seqEst.y'; C.checked_reconstruction_field=reconField;
        groupRecords=cell(1,numel(yDims));
        for g=1:numel(yDims)
            A=E.group(g); rows=sum(yDims(1:g-1))+(1:yDims(g));
            noiseNearLocal(mean(allBin(rows,:),2),A.reconstruction_var(:,6),'Total source versus saved All');
            if isfield(A,'all_reconstruction_var_by_bin')
                noiseNearLocal(allBin(rows,:),A.all_reconstruction_var_by_bin,'Total source versus saved All bins');
            end
            noiseNearLocal(residualBin(rows,:),Qc.group(g).residual_var_by_bin,'Total source versus saved Noise');
            G=struct('name',A.name,'unit_ids',A.unit_ids,'n_neurons',A.n_neurons);
            G.raw_var_by_bin=totalBin(rows,:);
            G.raw_var=mean(G.raw_var_by_bin,2);
            G.mean_count=A.mean_count;
            G.mean_rate=G.mean_count/dt;
            G.normalization_valid=isfinite(G.mean_count)&G.mean_count>0;
            G.normalization_excluded_unit_ids=G.unit_ids(~G.normalization_valid);
            G.n_valid_mean_count=nnz(G.normalization_valid);
            G.normalized_var=normalizeByMeanCountLocal(G.raw_var,G.mean_count);
            G.normalized_var_by_bin=normalizeByMeanCountLocal(G.raw_var_by_bin,G.mean_count);
            G.rate_var=G.raw_var/dt^2;
            G.rate_var_by_bin=G.raw_var_by_bin/dt^2;
            G.normalized_rate_var=G.normalized_var/dt;
            G.normalized_rate_var_by_bin=G.normalized_var_by_bin/dt;
            names={'raw','normalized','rate','normalized_rate'};
            for k=1:numel(names)
                key=names{k}; [total,avg,n]=summarizeNormalizedRowsLocal(G.([key '_var']));
                G.([key '_sum'])=total; G.([key '_mean'])=avg; G.([key '_n_neurons'])=n;
            end
            groupRecords{g}=G;
        end
        C.group=[groupRecords{:}]; conditionRecords{ci}=C;
        fprintf('  Observed Total: condition %d, %d trials (M-1); no posterior uncertainty added.\n',id,E.n_trials);
    end
    O.condition=[conditionRecords{:}];
    groupRecords=cell(1,numel(yDims));
    for g=1:numel(yDims)
        G=struct('name',cfg.group_names{g}); dirs=cell(1,2);
        for d=1:2
            D=struct('conditionIds',O.condition_ids(:,d),'n_neurons',nan(8,1), ...
                'n_trials',nan(8,1),'n_bins',nan(8,1),'n_valid_mean_count',nan(8,1));
            for k=1:numel(names)
                for suffix={'_sum','_mean','_n_neurons'}, D.([names{k} suffix{1}])=nan(8,1); end
            end
            for ci=1:numel(O.condition)
                E=O.condition(ci); if E.direction_index~=d, continue; end
                row=E.feature_index; A=E.group(g);
                D.n_neurons(row)=A.n_neurons; D.n_trials(row)=E.n_trials; D.n_bins(row)=E.n_bins;
                D.n_valid_mean_count(row)=A.n_valid_mean_count;
                for k=1:numel(names)
                    for suffix={'_sum','_mean','_n_neurons'}
                        key=[names{k} suffix{1}]; D.(key)(row)=A.(key);
                    end
                end
            end
            dirs{d}=D;
        end
        G.stim_dir=[dirs{:}]; groupRecords{g}=G;
    end
    O.group=[groupRecords{:}];
end
