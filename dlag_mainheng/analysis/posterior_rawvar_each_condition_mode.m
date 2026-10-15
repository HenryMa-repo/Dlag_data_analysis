%% posterior_rawvar_each_condition_mode.m
% Per-session variance of posterior-mean reconstructions.
% Run data_reconstruction.m with data_condition = 1:16 first. This script
% reads its ordinary yRecon_use_* fields in each bestmodel. If the saved
% Ambiguous reconstruction is absent or incomplete, ONLY that category is
% reconstructed from the SAME model's saved C and seqEst.xsm. This script
% does not rerun inference, refit, or modify a bestmodel.
%
% For EACH neuron/category/condition, use ALL trials and ALL saved bins:
%   mean_t(var_r(saved_reconstruction(r,t), 0))
% var(...,0) uses M-1, where M is the trial count of this condition.
% Do not subtract each trial's temporal mean. Do not pool trials and bins.
% Then average these neuron variances to obtain the plotted group value.
% Directions remain separate (eight conditions in each direction panel).
%
% uncertainty_included = 0: posterior-mean reconstruction variance only.
% uncertainty_included = 1: add mean_{r,t}(C_K * Vsm(K,K,t) * C_K').
% The full same-time covariance, INCLUDING off-diagonal latent terms, is
% used. This is the posterior expectation of the M-1 trial sample variance,
% conditional on fixed fitted parameters and independent model trials.
% No observation noise R, percentages, or DSL filtering are used.
% With option 0, Vsm is not required or evaluated. Uncomputed uncertainty
% is stored as NaN, not as zero. With option 1, both components are saved.
%
% Categories: Across, Within, Feedforward, Feedback, Ambiguous.
% The current data_reconstruction.m may not save yRecon_use_ambiguous.
% A complete saved yRecon_use_ambiguous (or its _no_d variant) is preferred.
% Otherwise, for each model group and trial, compute C(:,K)*xsm(K,:), where
% K contains that group's Ambiguous indices. The variance of the SUMMED
% reconstruction retains empirical covariance between Ambiguous latents.
% Constant d is omitted in this fallback because it does not affect variance.
% Empty latent categories have known zero variance and do not require xsm.
% Fallback provenance is recorded in group.status{5}; uncertainty_included
% also applies to this category via its complete Vsm(K,K,t) block.
%
% Unit IDs are the model-used neuron IDs in model group order, aligned to
% model_data_allruns and (when available) varexp_raw.unit_ids_by_group.
% They are not invented kilosort identifiers. The summary scripts retain
% the existing strict GPL group/ID alignment checks.
%
% Output: session_dir/each_condition_mode/posterior_rawvar/
%   postVar_<data_content>_rXXX_u0.mat (or u1)
% MAT variable PosteriorRawVar contains per-neuron/per-bin components,
% final per-neuron variances, counts, IDs, source paths, and the plotted
% sum/mean summaries. No original result is overwritten.
% Defaults use residual data, run 1, and condition IDs 1:16.

clc; clear;

%% ---------------------------- USER SETTINGS ---------------------------
session_dir = pwd;  % Run inside the session (catgt_*) folder.
dat_file = fullfile(session_dir,'model_data_allruns.mat');
% For shuffled models, point dat_file at the matching shuffled metadata.
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;
data_condition = 1:16;  % Each-condition IDs only; [] is NOT all-condition.
group_names = {'V1','MT'};  % Display labels in MODEL GROUP order.
uncertainty_included = 0;  % 0 = mean reconstruction only; 1 = add uncertainty.

save_mat = true;
make_plots = true;
save_png = true;
save_fig = false;
save_svg = false;
png_dpi = 300;
close_after_save = true;
figure_visible = 'on';

%% ------------------------- METADATA AND INPUT -------------------------
cfg = struct('session_dir',char(session_dir),'dat_file',char(dat_file), ...
    'stim_tag',char(stim_tag),'data_content',char(data_content),'runIdx',runIdx, ...
    'group_names',{cellstr(string(group_names(:)'))}, ...
    'uncertainty_included',uncertainty_included,'save_mat',save_mat, ...
    'make_plots',make_plots,'save_png',save_png,'save_fig',save_fig, ...
    'save_svg',save_svg,'png_dpi',png_dpi,'close_after_save',close_after_save, ...
    'figure_visible',char(figure_visible));
cfg = validatePosteriorConfigLocal(cfg);
validateattributes(data_condition,{'numeric'},{'vector','nonempty','integer','positive','finite'});
condition_list = double(data_condition(:)');
if numel(unique(condition_list)) ~= numel(condition_list)
    error('data_condition must contain unique IDs.');
end
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
if any(condition_list > numel(metadata.conditions_full))
    error('A condition ID exceeds conditions_full length.');
end
conditionMap = conditionMapLocal(metadata.conditions_full,condition_list);
pairs = [[conditionMap.entries.featureCode]',[conditionMap.entries.dirCode]'];
if size(unique(pairs,'rows'),1) ~= numel(condition_list)
    error('Duplicate stimulus/direction mapping in the requested conditions.');
end
[unitIds,metadata_yDims] = modelUnitIdsByGroupLocal(metadata,cfg.data_content);
if numel(cfg.group_names) ~= numel(metadata_yDims)
    error('group_names must follow the model group count/order.');
end
labels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
AllConditions = struct([]);

%% ------------------------ READ SAVED RECONSTRUCTIONS ------------------
for ci = 1:numel(condition_list)
    id = condition_list(ci);
    runDir = fullfile(cfg.session_dir,sprintf('FA_Dlag_%s_condition%d', ...
        cfg.data_content,id),'mat_results',sprintf('run%03d',cfg.runIdx));
    bestFile = uniqueMatFileLocal(runDir,'bestmodel*');
    fprintf('[%d/%d] condition %d: %s\n',ci,numel(condition_list),id,bestFile);
    B = load(bestFile,'bestModel','res','seqEst','gp_params','varexp_raw');
    requireFieldsLocal(B,{'res','seqEst'},bestFile);
    requireFieldsLocal(B.res,{'estParams'},'res');
    params = posteriorParamsLocal(B,metadata_yDims);
    validateSavedIdsLocal(B,unitIds,id,cfg);
    if params.xDim_across == 0
        gp = struct('delays',[]);
        ambiguous = [];
    else
        gp = getGpParamsLocal(B,bestFile);
        bootFile = uniqueMatFileLocal(runDir,'bootstrapResults*');
        boot = load(bootFile,'ambiguousIdxs');
        requireFieldsLocal(boot,{'ambiguousIdxs'},bootFile);
        ambiguous = boot.ambiguousIdxs;
    end
    classification = classifyDlagLatentsLocal(params.xDim_across,gp,ambiguous);
    result = calculatePosteriorConditionLocal(B.seqEst,params,unitIds, ...
        classification,cfg,id);
    e = conditionMap.entries(ci);
    result.condition_id = id;
    result.feature_index = e.featureCode;
    result.direction_index = e.dirCode;
    result.direction_value = e.direction;
    result.condition_label = e.label;
    result.bestmodel_file = bestFile;
    result.classification = classification;
    if ci == 1
        % Establish the complete field schema before indexed assignment.
        AllConditions = result;
    else
        AllConditions(ci) = orderfields(result,AllConditions(1)); %#ok<SAGROW>
    end
    clear B;
end

PosteriorRawVar = packPosteriorSessionLocal(AllConditions,conditionMap,labels,cfg);
output_dir = fullfile(cfg.session_dir,'each_condition_mode','posterior_rawvar');
out_base = sprintf('postVar_%s_r%03d_u%d',cfg.data_content,cfg.runIdx, ...
    cfg.uncertainty_included);
if cfg.save_mat || (cfg.make_plots && (cfg.save_png || cfg.save_fig || cfg.save_svg))
    if ~isfolder(output_dir)
        [ok,msg] = mkdir(output_dir);
        if ~ok, error('Cannot create output directory: %s',msg); end
    end
end
if cfg.save_mat
    output_file = fullfile(output_dir,[out_base '.mat']);
    save(output_file,'PosteriorRawVar','-v7.3');
    fprintf('Saved %s\n',output_file);
end
if cfg.make_plots
    for g = 1:numel(cfg.group_names)
        fig = plotPosteriorSessionLocal(PosteriorRawVar,g,cfg);
        savePosteriorFigureLocal(fig,output_dir,sprintf('%s_g%02d',out_base,g),cfg);
    end
end
fprintf('Done. M-1 variance across trials at each bin, then mean over bins.\n');

%% ----------------------------- FUNCTIONS ------------------------------
function cfg = validatePosteriorConfigLocal(cfg)
    if ~isfolder(cfg.session_dir) || ~isfile(cfg.dat_file) || isempty(cfg.data_content)
        error('Check session_dir, dat_file and data_content.');
    end
    if any(ismember(cfg.data_content,['/' '\']))
        error('data_content must be a data label, not a path.');
    end
    validateattributes(cfg.runIdx,{'numeric'},{'scalar','positive','integer','finite'});
    flags = {'uncertainty_included','save_mat','make_plots','save_png', ...
        'save_fig','save_svg','close_after_save'};
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
    requireFieldsLocal(R.meta,{'condition_id','runIdx','data_content'},'varexp_raw.meta');
    if R.meta.condition_id ~= id || R.meta.runIdx ~= cfg.runIdx || ...
            ~strcmp(char(R.meta.data_content),cfg.data_content) || numel(R.unit_ids_by_group) ~= numel(ids)
        error('Saved variance metadata disagree with this model/condition.');
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
    P.format_version = 'posterior_rawvar_eachcond_v1';
    P.labels = labels;
    P.meta.data_content = cfg.data_content; P.meta.runIdx = cfg.runIdx;
    P.meta.stim_tag = cfg.stim_tag; P.meta.group_names = cfg.group_names;
    P.meta.variance_source = 'posterior';
    P.meta.uncertainty_included = cfg.uncertainty_included;
    P.meta.DSL_filter = 'all_latents';
    P.meta.variance_method = 'across_trials_per_bin_mean_over_bins';
    P.meta.variance_normalization = 'M-1';
    P.meta.uncertainty_method = 'mean_trial_bin_diag_CK_VsmKK_CK_transpose';
    P.meta.conditionShortLabels = map.shortLabels;
    P.meta.dirValues = map.dirValues; P.meta.conditionMap = map;
    P.meta.created_on = datestr(now,30);
    P.meta.created_by = 'posterior_rawvar_each_condition_mode.m';
    P.meta.code_revision = '20261014_ambiguous_xsm_struct_fix';
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

function fig = plotPosteriorSessionLocal(P,g,cfg)
    fig = figure('Visible',cfg.figure_visible,'Position',[80 80 1500 820]);
    layout = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    values = [P.group(g).stim_dir(1).raw_mean;P.group(g).stim_dir(2).raw_mean];
    good = values(isfinite(values));
    if isempty(good) || max(good)<=0, top = 1; else, top = 1.12*max(good); end
    colors = lines(8);
    for d = 1:2
        ax = nexttile(layout,d);
        A = P.group(g).stim_dir(d);
        bars = bar(ax,A.raw_mean');
        for p = 1:numel(bars)
            bars(p).FaceColor = colors(p,:); bars(p).EdgeColor = 'none';
        end
        set(ax,'XTick',1:5,'XTickLabel',P.labels,'TickLabelInterpreter','none');
        xtickangle(ax,30); ylim(ax,[0 top]);
        xlabel(ax,'Latent category'); ylabel(ax,'Trial variance per neuron');
        title(ax,sprintf('Stimulus direction %d = %g',d,P.meta.dirValues(d)));
        if d == 1, legendBars = bars; end
        box(ax,'off');
    end
    leg = legend(legendBars,P.meta.conditionShortLabels,'Location','southoutside', ...
        'Orientation','horizontal','Interpreter','none');
    leg.NumColumns = 4; leg.Layout.Tile = 'south';
    if cfg.uncertainty_included, mode = 'posterior mean + uncertainty';
    else, mode = 'posterior mean only'; end
    sgtitle(layout,sprintf('%s | %s | %s | M-1 across trials, then mean over bins', ...
        cfg.group_names{g},cfg.data_content,mode),'Interpreter','none');
end

function savePosteriorFigureLocal(fig,folder,base,cfg)
    if cfg.save_fig, savefig(fig,fullfile(folder,[base '.fig'])); end
    if cfg.save_png
        exportgraphics(fig,fullfile(folder,[base '.png']),'Resolution',cfg.png_dpi);
    end
    if cfg.save_svg
        set(fig,'Renderer','painters','PaperPositionMode','auto');
        print(fig,fullfile(folder,[base '.svg']),'-dsvg','-painters');
    end
    if cfg.close_after_save && (cfg.save_fig || cfg.save_png || cfg.save_svg), close(fig); end
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

