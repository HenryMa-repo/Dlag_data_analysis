%% Varline_figure_plot.m
% All-condition-model POSTERIOR only. Inputs are READ ONLY. No posterior
% recalculation is needed for this update; it uses the saved Noise extension.
%
% LAYOUT: 3 stimulus-feature rows x 8 columns. Each of the FIRST SIX panels
% has its OWN independent y scale (no axis sharing across components/areas):
% V1 Within | V1 Across | V1 Noise | MT Within | MT Across | MT Noise |
% Within percentage difference | Across percentage difference.
% component_pair='ff_fb' substitutes FF/FB for Within/Across.
% comparison_plot_mode='paired': two endpoints and connecting lines.
% comparison_plot_mode='delta' : one violin of FIRST MINUS SECOND per panel:
% Grating-Plaid, Small-Large, Low-High. One delta per neuron or session x dir.
%
% REFERENCE-MATCHING AVERAGING / MISSING VALUES (independent per component):
% neuron: mean BOTH directions at each condition (a missing dir -> NaN);
% then form the four matched first-minus-second differences; average FINITE
% matches, just as GPL_class_deltaVar_figure_plot_by_neuron. No matching
% pair -> NaN. Paired endpoints use the SAME finite matches on both sides.
% session: first mean FINITE selected neuron values separately per condition
% and direction; then mean ALL FOUR matched differences (missing one -> NaN),
% just as GPL_class_deltaVar_figure_plot. The two directions stay separate.
% Each condition can have its own valid neuron population. PCU pools actual
% P/C/U neurons with equal per-neuron weight, not equal class weights.
% Noise is an additional component; its missingness does NOT filter latent
% deltas. Matching input settings/populations/sessions gives the reference
% raw stimulus-feature delta values, including its missing-value convention.
% This comparison concerns raw DeltaVar, not the reference Z-score figures.
%
% NORMALIZATION is ALWAYS per neuron/condition before any averaging:
% count -> V/mean_count; rate -> V_rate/mean_rate. Rate conversion uses dt
% in seconds: raw_rate=raw_count/dt^2; normalized_rate=normalized_count/dt.
% Existing latent/Noise u0/u1 files control uncertainty; no model R is used.
%
% PERCENTAGE DIRECTION IS UNCHANGED (SECOND MINUS FIRST):
%   pct_X=100*(X_second-X_first)/X_first
%   D_X=pct_X-pct_Noise, in percentage POINTS. Last two columns are area
% histograms of D_X. Average endpoints FIRST, calculate percentages SECOND.
% A zero/invalid first endpoint -> NaN percentage; never use an epsilon.
%
% Paired mode: individual lines are light; summary lines are dark.
% show_session_individual_lines and show_neuron_individual_lines independently
% control ALL valid session or neuron pairs. summary_center selects mean/median;
% error_type selects SEM/SD/none for the paired endpoints only. SEM=SD/sqrt(N)
% across observations (not a median confidence interval).
% Delta mode: reference violin outline, density-dependent dot spread, Tukey
% IQR/whiskers and a horizontal center line (chosen by summary_center).
% Zoom/inset options affect display only; ALL finite deltas enter tests.
% Both units use two-sided tests against zero. Nominal P; no cluster correction.
%
% VarlineResults v2 retains every observation identity, matched values,
% endpoint pairs, FIRST-minus-SECOND paired_change, SECOND-minus-FIRST
% percentages and tests. Output names include s8 + paired/delta, so prior
% four-column outputs are not overwritten. Old posterior MATs are untouched.

clc; clear;

%% -------------------------- USER SETTINGS -----------------------------
root_dir = 'I:\np_data';
session_dirs = {};  % {}: discover catgt_* at root or one folder below root.
                    % Or provide explicit full session-folder paths.
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;
uncertainty_included = 0; % 0: mean reconstruction/residual; 1: BOTH include uncertainty
summary_unit = 'session'; % 'neuron' or 'session' (session means session x direction)
comparison_plot_mode = 'delta'; % 'paired' or 'delta'; first SIX panels only
component_pair = 'within_across'; % 'within_across' or 'ff_fb'; Noise is always included
variance_normalization = 'mean_count'; % 'none' or 'mean_count' (mean RESPONSE)
variance_unit = 'count'; % 'count' or 'rate'; normalized rate uses mean RATE
neuron_population = 'all_neurons'; % 'all_neurons' (includes GPL-invalid) or 'pcu_neurons'
group_names = {'V1','MT'}; % exactly two areas, in MODEL GROUP order
gpl_mat_name = 'unit_gpl_results_sponsub.mat'; % required only for pcu_neurons
skip_missing_sessions = true; % report missing results/Noise; malformed inputs still error

summary_center = 'median'; % 'mean' or 'median'; center of summary line / violin
% This controls DISPLAY across neurons or session-directions. Condition and
% direction averaging that defines an observation always uses MEAN.
error_type = 'sem';      % 'sem', 'std', or 'none'; PAIRED plots only
show_session_individual_lines = true; % applies only to summary_unit='session'
show_neuron_individual_lines = true; % PAIRED neuron mode only; false shows summaries only
run_statistics = true;
test_method = 'signrank'; % 'signrank' or 'ttest', always two-sided versus zero
significance_alpha = 0.05;
show_p_values = true; % show nominal two-sided P for delta violins and percentage panels

% Area color never indicates component or individual/summary status.
area_colors = [0.0000 0.4470 0.7410; 0.8500 0.3250 0.0980];
component_line_styles = {'-','--',':'}; % Within/Across/Noise, or FF/FB/Noise
component_markers = {'o','s','^'};
individual_gray = 0.86; individual_line_width = 0.6;
summary_gray = 0.20; summary_line_width = 3.0;
summary_marker_size = 10;
% DELTA violin style follows GPL_class_deltaVar_figure_plot_by_neuron.
poster_outlier_mode = 'zoom_inset'; % 'zoom_inset' or 'full_range'
poster_show_inset = false; % false hides full-range inset, adds _noInset to delta filenames
poster_central_percentile = 80;
poster_point_size = 9; poster_point_alpha = 0.45;
poster_point_jitter_width = 0.12;
poster_violin_width = 0.25; poster_violin_alpha = 0.18;
poster_violin_point_spread_gain = 1.3;
poster_violin_point_edge_fraction = 0.90;
histogram_num_bins = 25;
histogram_normalization = 'probability'; % 'probability' or 'count'
histogram_alpha = 0.40;
font_name = 'Arial'; font_size = 15;
figure_width = 4800; figure_height = 900; % eight columns, poster font size 30
figure_visible = 'on';
make_plots = true;
save_mat = false;
save_png = false; save_fig = false; save_svg = false;
png_dpi = 300;
close_after_save = false;
output_dir = ''; % '' -> root_dir/all_condition_mode/Varline_figure_plot

%% ------------------------------ LOAD ----------------------------------
cfg = struct();
settingNames = {'root_dir','session_dirs','data_content','runIdx','uncertainty_included', ...
    'summary_unit','comparison_plot_mode','component_pair','variance_normalization','variance_unit','neuron_population', ...
    'group_names','gpl_mat_name','skip_missing_sessions','summary_center','error_type', ...
    'show_session_individual_lines','show_neuron_individual_lines','run_statistics','test_method','significance_alpha', ...
    'show_p_values','area_colors','component_line_styles','component_markers', ...
    'individual_gray','individual_line_width','summary_gray','summary_line_width', ...
    'summary_marker_size','poster_outlier_mode','poster_show_inset','poster_central_percentile', ...
    'poster_point_size','poster_point_alpha','poster_point_jitter_width','poster_violin_width', ...
    'poster_violin_alpha','poster_violin_point_spread_gain','poster_violin_point_edge_fraction', ...
    'histogram_num_bins','histogram_normalization', ...
    'histogram_alpha','font_name','font_size','figure_width', ...
    'figure_height','figure_visible','make_plots','save_mat','save_png','save_fig','save_svg', ...
    'png_dpi','close_after_save','output_dir'};
for k=1:numel(settingNames), cfg.(settingNames{k})=eval(settingNames{k}); end
cfg=vlValidateConfigLocal(cfg);
if strcmp(cfg.component_pair,'within_across')
    cfg.component_labels={'Within','Across','Noise'};
    cfg.input_component_labels={'Within','Across'};
else
    cfg.component_labels={'FF','FB','Noise'};
    cfg.input_component_labels={'Feedforward','Feedback'};
end
sessions=vlSessionDirsLocal(cfg);
records={}; skipped=struct('session_dir',{},'reason',{});
for s=1:numel(sessions)
    file=fullfile(sessions{s},'all_condition_mode','posterior_rawvar', ...
        sprintf('postVar_%s_r%03d_allcond_u%d.mat',cfg.data_content,cfg.runIdx,cfg.uncertainty_included));
    reason='';
    if ~isfile(file)
        reason=['Missing posterior file: ' file];
    elseif ~all(ismember({'PosteriorRawVarExtra','PosteriorRawVarNoise'},who('-file',file)))
        reason=['Missing Extra/Noise. Rerun updated posterior_rawvar with data_condition=[]: ' file];
    end
    if ~isempty(reason)
        if ~cfg.skip_missing_sessions, error('%s',reason); end
        warning('Varline:MissingSession','%s',reason);
        skipped(end+1)=struct('session_dir',sessions{s},'reason',reason); %#ok<SAGROW>
        continue;
    end
    fprintf('[%d/%d] %s\n',s,numel(sessions),sessions{s});
    try
        R=vlReadSessionLocal(sessions{s},file,cfg);
    catch ME
        context=MException('Varline:InvalidInput','Invalid input in %s:\n%s',sessions{s},ME.message);
        context=addCause(context,ME); % Retain the original failing function/line.
        throw(context);
    end
    records{end+1}=R; %#ok<SAGROW>
end
if isempty(records)
    error(['No complete sessions. Run updated posterior_rawvar.m with data_condition=[] ', ...
        'and matching data_content/runIdx/uncertainty_included; check root_dir.']);
end
records=[records{:}];

%% ----------------------- PAIRS AND STATISTICS -------------------------
features=vlFeatureDefinitionsLocal();
VarlineResults=struct();
VarlineResults.format_version='varline_posterior_v2';
VarlineResults.meta=struct('created_on',datestr(now,30),'created_by','Varline_figure_plot.m', ...
    'model_mode','all_condition','variance_source','posterior','observation_unit',cfg.summary_unit, ...
    'uncertainty_included',cfg.uncertainty_included,'noise_definition','posterior_residual_y_minus_all', ...
    'percentage_definition','100*(second-first)/first; difference = latent percentage - Noise percentage', ...
    'normalization_order','per neuron/condition BEFORE all averaging', ...
    'delta_definition','FIRST minus SECOND: G-P; Small-Large; Low-High', ...
    'pair_validity','Reference rules per observation unit; components filtered independently', ...
    'reference_neuron','mean both dirs, then finite mean of matched first-minus-second differences', ...
    'reference_session','finite neuron mean per condition/dir, then mean all four matched differences', ...
    'layout','3 feature rows x 8 columns; independent component/area axes', ...
    'test_tail','both','p_adjustment','none (nominal)','cluster_adjustment','none');
VarlineResults.settings=cfg;
VarlineResults.sessions=records;
VarlineResults.skipped_sessions=skipped;
featureRecords=cell(1,numel(features));
for f=1:numel(features)
    F=features(f); areaRecords=cell(1,2);
    for g=1:2
        A=vlCollectPairsLocal(records,g,F,cfg);
        A=vlPercentagesAndTestsLocal(A,cfg);
        areaRecords{g}=A;
        fprintf('%s | %s: %d observations; finite deltas %d/%d/%d; percentage comparisons %d/%d\n', ...
            F.name,cfg.group_names{g},size(A.endpoints,1),sum(isfinite(A.paired_change),1), ...
            sum(isfinite(A.percent_difference_from_noise),1));
    end
    F.area=[areaRecords{:}];
    featureRecords{f}=F;
end
VarlineResults.feature=[featureRecords{:}];

%% ----------------------------- OUTPUT ---------------------------------
if isempty(cfg.output_dir)
    cfg.output_dir=fullfile(cfg.root_dir,'all_condition_mode','Varline_figure_plot');
end
VarlineResults.settings.output_dir=cfg.output_dir;
base=vlOutputNameLocal(cfg);
if cfg.save_mat || (cfg.make_plots && (cfg.save_png || cfg.save_fig || cfg.save_svg))
    if ~isfolder(cfg.output_dir)
        [ok,msg]=mkdir(cfg.output_dir); if ~ok, error('Cannot create output folder: %s',msg); end
    end
end
if cfg.save_mat
    save(fullfile(cfg.output_dir,[base '.mat']),'VarlineResults','-v7.3');
    fprintf('Saved paired values, percentage differences, identities and tests: %s.mat\n',base);
end
if cfg.make_plots
    fig=vlPlotLocal(VarlineResults,cfg);
    vlSaveFigureLocal(fig,cfg.output_dir,base,cfg);
end
fprintf('Done: %d sessions loaded; %d missing sessions reported.\n',numel(records),numel(skipped));

%% --------------------------- LOCAL FUNCTIONS --------------------------
function cfg=vlValidateConfigLocal(cfg)
    options={'summary_unit',{'neuron','session'}; 'comparison_plot_mode',{'paired','delta'}; ...
        'poster_outlier_mode',{'zoom_inset','full_range'}; 'component_pair',{'within_across','ff_fb'}; ...
        'variance_normalization',{'none','mean_count'}; 'variance_unit',{'count','rate'}; ...
        'neuron_population',{'all_neurons','pcu_neurons'}; 'summary_center',{'mean','median'}; ...
        'error_type',{'sem','std','none'}; 'test_method',{'signrank','ttest'}; ...
        'histogram_normalization',{'probability','count'}; 'figure_visible',{'on','off'}};
    for k=1:size(options,1)
        key=options{k,1}; value=lower(strtrim(char(cfg.(key))));
        if ~ismember(value,options{k,2}), error('Invalid %s: %s',key,value); end
        cfg.(key)=value;
    end
    cfg.root_dir=char(cfg.root_dir); cfg.data_content=char(cfg.data_content);
    cfg.output_dir=char(cfg.output_dir); cfg.font_name=char(cfg.font_name);
    cfg.group_names=cellstr(string(cfg.group_names(:)'));
    if ~isfolder(cfg.root_dir), error('root_dir does not exist: %s',cfg.root_dir); end
    if isempty(cfg.data_content) || any(ismember(cfg.data_content,['/' '\']))
        error('data_content must be a nonempty data label.');
    end
    if numel(cfg.group_names)~=2 || any(cellfun(@isempty,cfg.group_names))
        error('This eight-column layout requires exactly two group_names in model order.');
    end
    validateattributes(cfg.runIdx,{'numeric'},{'scalar','positive','integer','finite'});
    flags={'uncertainty_included','skip_missing_sessions','show_session_individual_lines','show_neuron_individual_lines', ...
        'run_statistics','show_p_values','poster_show_inset','make_plots','save_mat', ...
        'save_png','save_fig','save_svg','close_after_save'};
    for k=1:numel(flags)
        v=cfg.(flags{k});
        if ~(isnumeric(v)||islogical(v)) || ~isscalar(v) || ~ismember(double(v),[0 1])
            error('%s must be true/false or 0/1.',flags{k});
        end
        cfg.(flags{k})=logical(v);
    end
    validateattributes(cfg.area_colors,{'numeric'},{'size',[2 3],'real','finite','>=',0,'<=',1});
    for key={'individual_gray','summary_gray','histogram_alpha','poster_point_alpha','poster_violin_alpha'}
        validateattributes(cfg.(key{1}),{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
    end
    for key={'individual_line_width','summary_line_width','summary_marker_size','font_size', ...
            'figure_width','figure_height','png_dpi','poster_point_size','poster_violin_width', ...
            'poster_violin_point_spread_gain'}
        validateattributes(cfg.(key{1}),{'numeric'},{'scalar','real','finite','positive'});
    end
    validateattributes(cfg.histogram_num_bins,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(cfg.significance_alpha,{'numeric'},{'scalar','real','>',0,'<',1});
    validateattributes(cfg.poster_central_percentile,{'numeric'},{'scalar','real','finite','>',0,'<=',100});
    validateattributes(cfg.poster_point_jitter_width,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(cfg.poster_violin_point_edge_fraction,{'numeric'},{'scalar','real','finite','>',0,'<=',1});
    cfg.component_line_styles=cellstr(string(cfg.component_line_styles(:)'));
    cfg.component_markers=cellstr(string(cfg.component_markers(:)'));
    if numel(cfg.component_line_styles)~=3 || ...
            ~all(ismember(cfg.component_line_styles,{'-','--',':','-.'}))
        error('Provide three valid component_line_styles.');
    end
    if numel(cfg.component_markers)~=3 || ...
            ~all(ismember(cfg.component_markers,{'o','s','^','v','d','p','h','+','x','*','.'}))
        error('Provide three valid component_markers.');
    end
    if cfg.run_statistics && exist(cfg.test_method,'file')~=2
        error('%s requires Statistics and Machine Learning Toolbox; install it or set run_statistics=false.',cfg.test_method);
    end
end

function dirs=vlSessionDirsLocal(cfg)
    if ~isempty(cfg.session_dirs)
        dirs=cellstr(string(cfg.session_dirs(:)));
    else
        [~,name]=fileparts(cfg.root_dir);
        if startsWith(name,'catgt_')
            dirs={cfg.root_dir};
        else
            a=dir(fullfile(cfg.root_dir,'catgt_*'));
            b=dir(fullfile(cfg.root_dir,'*','catgt_*')); listing=[a(:);b(:)];
            listing=listing([listing.isdir]); dirs=cell(numel(listing),1);
            for k=1:numel(listing), dirs{k}=fullfile(listing(k).folder,listing(k).name); end
        end
    end
    dirs=unique(dirs,'stable');
    if isempty(dirs), error('No catgt_* sessions found under root_dir. Or set session_dirs explicitly.'); end
    numbers=nan(numel(dirs),1); labels=cell(size(dirs));
    for k=1:numel(dirs)
        if ~isfolder(dirs{k}), error('Session folder does not exist: %s',dirs{k}); end
        [parent,leaf]=fileparts(dirs{k}); [~,parent]=fileparts(parent);
        labels{k}=[parent '/' leaf]; token=regexp(parent,'p(\d+)','tokens','once');
        if isempty(token), numbers(k)=Inf; else, numbers(k)=str2double(token{1}); end
    end
    T=table(numbers(:),labels(:),dirs(:),'VariableNames',{'number','label','folder'});
    T=sortrows(T,{'number','label'}); dirs=T.folder;
end

function R=vlReadSessionLocal(sessionDir,file,cfg)
    S=load(file,'PosteriorRawVarExtra','PosteriorRawVarNoise');
    X=S.PosteriorRawVarExtra; Q=S.PosteriorRawVarNoise;
    vlRequireLocal(X,{'format_version','meta','labels','condition_ids','condition'},'Extra');
    vlRequireLocal(Q,{'format_version','meta','labels','condition_ids','condition'},'Noise');
    if ~strcmp(X.format_version,'posterior_rawvar_extra_v1') || ...
            ~strcmp(Q.format_version,'posterior_rawvar_noise_v1')
        error('Unsupported Extra/Noise version. Use the supplied posterior_rawvar.m.');
    end
    for M={X.meta,Q.meta}
        m=M{1};
        vlRequireLocal(m,{'model_mode','data_condition','variance_source','data_content','runIdx', ...
            'uncertainty_included','conditionShortLabels','dirValues','variance_method','variance_normalization'},'metadata');
        if ~strcmp(m.model_mode,'all_condition') || ~isempty(m.data_condition) || ...
                ~strcmp(m.variance_source,'posterior') || ~strcmp(m.data_content,cfg.data_content) || ...
                m.runIdx~=cfg.runIdx || double(m.uncertainty_included)~=double(cfg.uncertainty_included)
            error('Only matching all-condition posterior content/run/u files are supported.');
        end
        if ~strcmp(m.variance_method,'across_trials_per_bin_mean_over_bins') || ...
                ~strcmp(m.variance_normalization,'M-1')
            error('Require per-bin trial sample variance (M-1), averaged over bins.');
        end
    end
    if ~strcmp(Q.meta.noise_definition,'posterior_residual_y_minus_all') || ...
            ~strcmp(Q.meta.uncertainty_method,'mean_trial_bin_diag_full_C_Vsm_C_transpose')
        error('Noise must use the posterior residual definition with the full All uncertainty.');
    end
    if ~strcmp(Q.meta.extra_created_on,X.meta.created_on)
        error('Noise was computed against a different Extra result. Rerun posterior_rawvar.');
    end
    expected={'G-S-L','G-S-H','G-L-L','G-L-H','P-S-L','P-S-H','P-L-L','P-L-H'};
    labels=cellstr(string(X.meta.conditionShortLabels(:)'));
    rowOrder=vlLabelOrderLocal(expected,labels);
    columns=vlLabelOrderLocal(cfg.input_component_labels,X.labels);
    vlLabelOrderLocal({'Across','Within','Feedforward','Feedback','Ambiguous','All'},X.labels);
    allColumn=vlLabelOrderLocal({'All'},X.labels);
    vlSizeLocal(X.condition_ids,[8 2],'Extra condition_ids');
    if ~isequaln(X.condition_ids,Q.condition_ids) || numel(X.condition)~=16 || numel(Q.condition)~=16 || ...
            numel(unique(X.condition_ids(:)))~=16 || any(~isfinite(X.condition_ids(:)))
        error('Require all 16 matching conditions in Extra and Noise.');
    end
    xIds=[X.condition.condition_id]; qIds=[Q.condition.condition_id];
    if ~isequal(sort(xIds(:)),sort(X.condition_ids(:))) || ~isequal(sort(qIds(:)),sort(xIds(:)))
        error('Condition records do not match the saved condition map.');
    end
    dt=vlBinSecondsLocal(X.meta); qdt=vlBinSecondsLocal(Q.meta);
    if abs(dt-qdt)>1e-9*dt, error('Extra and Noise use different bin widths.'); end
    dirValues=double(X.meta.dirValues(:)');
    if numel(dirValues)~=2 || numel(unique(dirValues))~=2 || any(~isfinite(dirValues)) || ...
            ~isequal(dirValues,double(Q.meta.dirValues(:)'))
        error('Require the same two directions in Extra and Noise.');
    end
    R=struct('session_dir',sessionDir,'source_file',file,'bin_size_seconds',dt, ...
        'direction_values',dirValues,'condition_ids',X.condition_ids(rowOrder,:));
    groupRecords=cell(1,2); % Collect full structs before constructing the array.
    gplGroups={}; gplFiles={};
    if strcmp(cfg.neuron_population,'pcu_neurons')
        [gplGroups,gplFiles]=loadGplGroupsByModelIndexLocal(sessionDir,cfg.gpl_mat_name,2);
    end
    for g=1:2
        first=X.condition(1).group(g); ids=vlIdsLocal(first.unit_ids); n=numel(ids);
        values=nan(n,8,2,3);
        for d=1:2
            for c=1:8
                id=X.condition_ids(rowOrder(c),d);
                E=X.condition(xIds==id); F=Q.condition(qIds==id);
                if E.feature_index~=rowOrder(c) || E.direction_index~=d || E.direction_value~=dirValues(d) || ...
                        F.feature_index~=E.feature_index || F.direction_index~=d || F.direction_value~=E.direction_value || ...
                        E.n_trials~=F.n_trials || E.n_bins~=F.n_bins || E.n_trials<2 || ...
                        ~isequal(E.trial_ids,F.trial_ids) || numel(E.group)~=2 || numel(F.group)~=2 || ...
                        ~strcmp(E.bestmodel_file,X.condition(1).bestmodel_file) || ...
                        ~strcmp(E.model_mode,'all_condition') || ~strcmp(F.model_mode,'all_condition')
                    error('Condition/direction/model/trial identities disagree.');
                end
                A=E.group(g); B=F.group(g);
                if ~isequal(vlIdsLocal(A.unit_ids),ids) || ~isequal(vlIdsLocal(B.unit_ids),ids)
                    error('Neuron IDs/order change across conditions or between Extra and Noise.');
                end
                if A.n_neurons~=n || B.n_neurons~=n
                    error('Saved neuron counts disagree with unit IDs.');
                end
                vlSizeLocal(A.raw_var,[n numel(X.labels)],'latent raw_var');
                vlSizeLocal(A.reconstruction_var,[n numel(X.labels)],'latent reconstruction_var');
                vlSizeLocal(A.uncertainty_var,[n numel(X.labels)],'latent uncertainty_var');
                vlSizeLocal(B.raw_var,[n 1],'Noise raw_var');
                vlSizeLocal(B.residual_var,[n 1],'Noise residual_var');
                vlSizeLocal(B.uncertainty_var,[n 1],'Noise uncertainty_var');
                vlNearLocal(A.mean_count,B.mean_count,'latent/Noise mean_count',true);
                vlNonnegativeLocal(A.raw_var,'latent variance'); vlNonnegativeLocal(B.raw_var,'Noise variance');
                vlNonnegativeLocal(A.reconstruction_var,'latent reconstruction variance');
                vlNonnegativeLocal(B.residual_var,'empirical residual variance');
                latentExpected=double(A.reconstruction_var); noiseExpected=double(B.residual_var);
                if cfg.uncertainty_included
                    vlNonnegativeLocal(A.uncertainty_var,'latent uncertainty');
                    vlNonnegativeLocal(B.uncertainty_var,'Noise uncertainty');
                    vlNearLocal(B.uncertainty_var,A.uncertainty_var(:,allColumn),'Noise versus All uncertainty',false);
                    latentExpected=latentExpected+double(A.uncertainty_var);
                    noiseExpected=noiseExpected+double(B.uncertainty_var);
                end
                vlNearLocal(A.raw_var,latentExpected,'latent selected variance',false);
                vlNearLocal(B.raw_var,noiseExpected,'Noise selected variance',false);
                LV=vlSelectedVarianceLocal(A,dt,cfg); NV=vlSelectedVarianceLocal(B,dt,cfg);
                values(:,c,d,:)=reshape([LV(:,columns) NV],n,1,1,3);
            end
        end
        selected=true(n,1); classCode=zeros(n,1);
        if strcmp(cfg.neuron_population,'pcu_neurons')
            I=validateAndExtractClassesLocal(gplGroups{g},ids,cfg.group_names{g},gplFiles{g});
            selected=I.pattern|I.component|I.unclassified;
            classCode(I.pattern)=1; classCode(I.component)=2; classCode(I.unclassified)=3;
            classCode(I.invalid)=4;
        end
        nByCondition=reshape(sum(isfinite(values(selected,:,:,:)),1),8,2,3);
        G=struct('name',cfg.group_names{g},'unit_ids',ids,'condition_variance',values, ...
            'population_selected_mask',selected,'class_code',classCode, ...
            'n_selected_neurons',nnz(selected),'n_valid_neurons_by_condition',nByCondition);
        groupRecords{g}=G;
        fprintf('  %s: selected %d neurons; reference missing-value rules applied per component.\n', ...
            G.name,G.n_selected_neurons);
    end
    R.group=[groupRecords{:}];
end

function V=vlSelectedVarianceLocal(G,dt,cfg)
    V=double(G.raw_var);
    if strcmp(cfg.variance_normalization,'mean_count')
        vlSizeLocal(G.mean_count,[size(V,1) 1],'mean_count');
        denominator=double(G.mean_count); denominator(~isfinite(denominator)|denominator<=0)=NaN;
        expected=bsxfun(@rdivide,V,denominator);
        vlNearLocal(G.normalized_var,expected,'per-neuron normalized variance',true);
        V=double(G.normalized_var); rateField='normalized_rate_var'; power=1;
    else
        rateField='rate_var'; power=2;
    end
    if strcmp(cfg.variance_unit,'rate')
        expected=V/dt^power;
        if isfield(G,rateField)
            vlNearLocal(G.(rateField),expected,rateField,true); V=double(G.(rateField));
        else
            V=expected; % old Extra remains read-only; derive missing rate in memory
        end
    end
end

function F=vlFeatureDefinitionsLocal()
    F=struct('name',{'Stimulus','Size','Contrast'},'tag',{'GP','SL','LH'}, ...
        'endpoint_labels',{{'Grating','Plaid'},{'Small','Large'},{'Low','High'}}, ...
        'first_conditions',{[1 2 3 4],[1 2 5 6],[1 3 5 7]}, ...
        'second_conditions',{[5 6 7 8],[3 4 7 8],[2 4 6 8]});
end

function A=vlCollectPairsLocal(records,g,F,cfg)
% Compute the reference deltas directly, not as a difference of population
% medians. Endpoint means use the identical accepted feature matches.
    A=struct('name',cfg.group_names{g},'endpoints',zeros(0,2,3), ...
        'paired_change',zeros(0,3),'matched_first',zeros(0,4,3), ...
        'matched_second',zeros(0,4,3),'matched_differences',zeros(0,4,3), ...
        'n_matched_conditions',zeros(0,3),'session_index',zeros(0,1), ...
        'direction_index',zeros(0,1),'direction_value',zeros(0,1), ...
        'unit_id',zeros(0,1),'unit_row_index',zeros(0,1),'class_code',zeros(0,1), ...
        'n_neurons_per_observation',zeros(0,3),'legend_neuron_count',0, ...
        'legend_neuron_count_by_component',zeros(1,3),'n_sessions',0);
    pairParts={}; deltaParts={}; firstParts={}; secondParts={}; countParts={};
    sessionIndex=zeros(0,1); directionIndex=zeros(0,1); directionValue=zeros(0,1);
    unitId=zeros(0,1); unitRow=zeros(0,1); classCode=zeros(0,1); neuronCount=zeros(0,3);
    for s=1:numel(records)
        G=records(s).group(g); X=G.condition_variance; selected=G.population_selected_mask;
        if strcmp(cfg.summary_unit,'neuron')
            n=nnz(selected); if n==0, continue; end
            % Same order as loadNeuronVarianceLocal in the neuron reference:
            % ordinary mean over BOTH dirs first; missing dir propagates NaN.
            V=reshape(mean(X(selected,:,:,:),3),n,8,3);
            left=V(:,F.first_conditions,:); right=V(:,F.second_conditions,:);
            matchedDelta=left-right;
            delta=reshape(vlFiniteMeanLocal(matchedDelta,2),n,3);
            good=isfinite(matchedDelta);
            pairedLeft=left; pairedRight=right;
            pairedLeft(~good)=NaN; pairedRight(~good)=NaN;
            Y=nan(n,2,3);
            Y(:,1,:)=vlFiniteMeanLocal(pairedLeft,2);
            Y(:,2,:)=vlFiniteMeanLocal(pairedRight,2);
            pairParts{end+1}=Y; deltaParts{end+1}=delta; %#ok<AGROW>
            firstParts{end+1}=left; secondParts{end+1}=right; %#ok<AGROW>
            countParts{end+1}=reshape(sum(good,2),n,3); %#ok<AGROW>
            sessionIndex=[sessionIndex;repmat(s,n,1)]; %#ok<AGROW>
            directionIndex=[directionIndex;nan(n,1)]; directionValue=[directionValue;nan(n,1)]; %#ok<AGROW>
            unitId=[unitId;G.unit_ids(selected)]; unitRow=[unitRow;find(selected)]; %#ok<AGROW>
            classCode=[classCode;G.class_code(selected)]; %#ok<AGROW>
            neuronCount=[neuronCount;double(isfinite(delta))]; %#ok<AGROW>
        else
            for d=1:2
                % Same as dvUpgradeSessionInputLocal: neuron mean independently
                % within each condition/source, omitting nonfinite values.
                if any(selected)
                    V=reshape(vlFiniteMeanLocal(X(selected,:,d,:),1),8,3);
                else
                    V=nan(8,3);
                end
                left=reshape(V(F.first_conditions,:),1,4,3);
                right=reshape(V(F.second_conditions,:),1,4,3);
                matchedDelta=left-right;
                % Same as calculateFeaturesLocal in the session reference:
                % ordinary mean of all FOUR matches; any missing -> NaN.
                delta=reshape(mean(matchedDelta,2),1,3);
                Y=nan(1,2,3);
                Y(1,1,:)=mean(left,2); Y(1,2,:)=mean(right,2);
                for k=1:3
                    if ~isfinite(delta(k)), Y(1,:,k)=NaN; end
                end
                pairParts{end+1}=Y; deltaParts{end+1}=delta; %#ok<AGROW>
                firstParts{end+1}=left; secondParts{end+1}=right; %#ok<AGROW>
                countParts{end+1}=reshape(sum(isfinite(matchedDelta),2),1,3); %#ok<AGROW>
                sessionIndex=[sessionIndex;s]; directionIndex=[directionIndex;d]; %#ok<AGROW>
                directionValue=[directionValue;records(s).direction_values(d)]; %#ok<AGROW>
                unitId=[unitId;NaN]; unitRow=[unitRow;NaN]; classCode=[classCode;NaN]; %#ok<AGROW>
                counts=zeros(1,3);
                for k=1:3
                    if isfinite(delta(k))
                        counts(k)=nnz(selected & any(isfinite(X(:,:,d,k)),2));
                    end
                end
                neuronCount=[neuronCount;counts]; %#ok<AGROW>
            end
        end
    end
    if ~isempty(pairParts)
        A.endpoints=cat(1,pairParts{:}); A.paired_change=cat(1,deltaParts{:});
        A.matched_first=cat(1,firstParts{:}); A.matched_second=cat(1,secondParts{:});
        A.matched_differences=A.matched_first-A.matched_second;
        A.n_matched_conditions=cat(1,countParts{:});
    end
    A.session_index=sessionIndex; A.direction_index=directionIndex; A.direction_value=directionValue;
    A.unit_id=unitId; A.unit_row_index=unitRow; A.class_code=classCode;
    A.n_neurons_per_observation=neuronCount;
    if strcmp(cfg.summary_unit,'neuron') && strcmp(cfg.neuron_population,'pcu_neurons') && ~isempty(unitId)
        % Reference PCU order is class -> session -> original model row.
        [~,order]=sortrows([classCode sessionIndex unitRow],[1 2 3]);
        rowFields={'endpoints','paired_change','matched_first','matched_second','matched_differences', ...
            'n_matched_conditions','session_index','direction_index','direction_value', ...
            'unit_id','unit_row_index','class_code','n_neurons_per_observation'};
        for j=1:numel(rowFields)
            name=rowFields{j}; B=A.(name); A.(name)=B(order,:,:);
        end
    end
    valid=isfinite(A.paired_change);
    A.n_sessions=numel(unique(A.session_index(any(valid,2))));
    for k=1:3
        A.legend_neuron_count_by_component(k)=vlUsedNeuronCountLocal(A,records,g,valid(:,k),cfg,k);
    end
    A.legend_neuron_count=vlUsedNeuronCountLocal(A,records,g,valid,cfg,1:3);
end

function y=vlFiniteMeanLocal(X,dim)
% Identical finite-value mean rule used by the two reference programs.
    keep=isfinite(X); count=sum(keep,dim); X(~keep)=0;
    y=sum(X,dim)./count; y(count==0)=NaN;
end

function n=vlUsedNeuronCountLocal(A,records,g,valid,cfg,components)
% Legend n always counts actual contributing neurons, once per session/unit.
% Session populations may differ across conditions; count their UNION only
% for the valid observations/components included in this panel.
    if size(valid,2)==1 && numel(components)>1
        valid=repmat(valid,1,numel(components));
    end
    if size(valid,2)~=numel(components), error('Invalid component validity mask.'); end
    if strcmp(cfg.summary_unit,'neuron'), n=nnz(any(valid,2)); return; end
    n=0; active=any(valid,2);
    for s=unique(A.session_index(active))'
        G=records(s).group(g); N=numel(G.unit_ids); used=false(N,1);
        obs=find(active & A.session_index==s);
        for o=obs(:)'
            d=A.direction_index(o); selectedComponents=components(valid(o,:));
            X=reshape(G.condition_variance(:,:,d,selectedComponents),N,[]);
            used=used | (G.population_selected_mask & any(isfinite(X),2));
        end
        n=n+nnz(used);
    end
end

function A=vlPercentagesAndTestsLocal(A,cfg)
    n=size(A.endpoints,1);
    first=reshape(A.endpoints(:,1,:),n,3); second=reshape(A.endpoints(:,2,:),n,3);
    % paired_change was computed from matched differences in reference order.
    % Preserve that exact averaging order; endpoints agree up to roundoff.
    endpointDelta=first-second;
    if ~isequal(isnan(A.paired_change),isnan(endpointDelta))
        error('Matched deltas and paired endpoints have different missing values.');
    end
    goodDelta=isfinite(A.paired_change) & isfinite(endpointDelta);
    scaleValues=[first(goodDelta);second(goodDelta)];
    if ~isempty(scaleValues)
        scale=max(1,max(abs(scaleValues)));
        if any(abs(A.paired_change(goodDelta)-endpointDelta(goodDelta))>1e-10*scale)
            error('Matched deltas and paired endpoints disagree beyond numerical roundoff.');
        end
    end
    A.percent_change=nan(n,3);
    good=isfinite(first)&isfinite(second)&first>0;
    A.percent_change(good)=100*(second(good)-first(good))./first(good);
    A.percent_change(~isfinite(A.percent_change))=NaN;
    A.percent_difference_from_noise=bsxfun(@minus,A.percent_change(:,1:2),A.percent_change(:,3));
    A.percent_difference_from_noise(~isfinite(A.percent_difference_from_noise))=NaN;
    A.invalid_percentage_baseline=~good;
    A.center=nan(2,3); A.error=nan(2,3);
    A.delta_center=nan(1,3); deltaTests=cell(1,3); percentTests=cell(1,2);
    for k=1:3
        for e=1:2
            [A.center(e,k),A.error(e,k)]=vlCenterErrorLocal(A.endpoints(:,e,k),cfg);
        end
        [A.delta_center(k),~]=vlCenterErrorLocal(A.paired_change(:,k),cfg);
        deltaTests{k}=vlTestLocal(A.paired_change(:,k),cfg);
    end
    for k=1:2
        percentTests{k}=vlTestLocal(A.percent_difference_from_noise(:,k),cfg);
    end
    A.stats=struct('paired_change',[deltaTests{:}], ...
        'percent_difference_from_noise',[percentTests{:}]);
end

function [center,err]=vlCenterErrorLocal(x,cfg)
    x=double(x(:)); x=x(isfinite(x)); center=NaN; err=NaN;
    if isempty(x), return; end
    if strcmp(cfg.summary_center,'mean'), center=mean(x); else, center=median(x); end
    if strcmp(cfg.error_type,'none'), err=0;
    elseif numel(x)>1
        err=std(x,0);
        if strcmp(cfg.error_type,'sem'), err=err/sqrt(numel(x)); end
    end
end

function T=vlTestLocal(x,cfg)
    x=x(isfinite(x)); x=x(:);
    T=struct('method',cfg.test_method,'tail','both','n',numel(x),'n_nonzero',nnz(x), ...
        'mean',NaN,'median',NaN,'p',NaN,'significant',false,'alpha',cfg.significance_alpha);
    if isempty(x), return; end
    T.mean=mean(x); T.median=median(x);
    if ~cfg.run_statistics, return; end
    if strcmp(cfg.test_method,'ttest') && numel(x)<2, return; end
    if all(x==0)
        T.p=1;
    elseif strcmp(cfg.test_method,'signrank')
        T.p=signrank(x,0,'tail','both');
    elseif std(x,0)==0
        T.p=0;
    else
        [~,T.p]=ttest(x,0,'Tail','both','Alpha',cfg.significance_alpha);
    end
    T.significant=isfinite(T.p)&&T.p<cfg.significance_alpha;
end

function fig=vlPlotLocal(R,cfg)
    fig=figure('Color','w','Visible',cfg.figure_visible,'Units','pixels', ...
        'Position',[40 40 cfg.figure_width cfg.figure_height]);
    layout=tiledlayout(fig,3,8,'TileSpacing','loose','Padding','loose');
    insetJobs={};
    for f=1:3
        F=R.feature(f);
        for g=1:2
            for k=1:3
                col=(g-1)*3+k;
                ax=nexttile(layout,(f-1)*8+col);
                if strcmp(cfg.comparison_plot_mode,'paired')
                    vlPairedPanelLocal(ax,F.area(g),F,cfg,g,k);
                else
                    job=vlDeltaPanelLocal(ax,F.area(g),F,cfg,g,k,f);
                    if ~isempty(job), insetJobs{end+1}=job; end %#ok<AGROW>
                end
            end
        end
        for k=1:2
            ax=nexttile(layout,(f-1)*8+6+k);
            vlHistogramPanelLocal(ax,F,R.sessions,cfg,k);
        end
    end
    set(findall(fig,'-property','FontName'),'FontName',cfg.font_name);
    set(findall(fig,'-property','FontSize'),'FontSize',cfg.font_size);
    drawnow; % Finalize tile geometry before positioning optional inset axes.
    for j=1:numel(insetJobs)
        vlDrawDeltaInsetLocal(fig,insetJobs{j},cfg);
    end
    drawnow;
end

function vlPairedPanelLocal(ax,A,F,cfg,g,k)
% ONE area/component per axis. No source shares this y range.
    hold(ax,'on'); color=cfg.area_colors(g,:);
    gray=cfg.summary_gray*[1 1 1]; light=cfg.individual_gray*[1 1 1];
    n=size(A.endpoints,1); Y=reshape(A.endpoints(:,:,k),n,2);
    good=all(isfinite(Y),2); Y=Y(good,:); extrema=0;
    showIndividuals=(strcmp(cfg.summary_unit,'session') && cfg.show_session_individual_lines) || ...
        (strcmp(cfg.summary_unit,'neuron') && cfg.show_neuron_individual_lines);
    if showIndividuals && ~isempty(Y)
        plot(ax,[1 2],Y','Color',light,'LineStyle',cfg.component_line_styles{k}, ...
            'LineWidth',cfg.individual_line_width,'HandleVisibility','off');
        extrema=[extrema;Y(:)];
    end
    y=A.center(:,k)'; err=A.error(:,k)';
    if ~strcmp(cfg.error_type,'none')
        errorbar(ax,[1 2],y,err,'LineStyle','none','Color',gray,'LineWidth',1.4, ...
            'CapSize',9,'HandleVisibility','off');
    end
    h=plot(ax,[1 2],y,'Color',gray,'LineStyle',cfg.component_line_styles{k}, ...
        'LineWidth',cfg.summary_line_width,'Marker',cfg.component_markers{k}, ...
        'MarkerSize',cfg.summary_marker_size,'MarkerFaceColor',color,'MarkerEdgeColor',color);
    finiteErr=err; finiteErr(~isfinite(finiteErr))=0;
    extrema=[extrema;y(:);y(:)-finiteErr(:);y(:)+finiteErr(:)];
    legend(ax,h,sprintf('%s: n=%d',cfg.group_names{g},A.legend_neuron_count_by_component(k)), ...
        'Location','northwest','Box','off','Interpreter','none','FontSize',cfg.font_size);
    set(ax,'XLim',[0.65 2.35],'XTick',[1 2],'XTickLabel',F.endpoint_labels);
    extrema=extrema(isfinite(extrema));
    if isempty(extrema) || max(extrema)==min(extrema)
        ylim(ax,[0 1]);
    else
        lo=min(0,min(extrema)); hi=max(extrema); span=hi-lo;
        ylim(ax,[lo-0.04*span hi+0.30*span]);
    end
    title(ax,{[F.name ' | ' cfg.group_names{g}],cfg.component_labels{k}}, ...
        'Interpreter','none','FontWeight','normal');
    ylabel(ax,vlYAxisLabelLocal(cfg),'Interpreter','none');
    vlAxesStyleLocal(ax,cfg);
    ax.UserData=struct('component',cfg.component_labels{k},'area',cfg.group_names{g}, ...
        'observation_unit',cfg.summary_unit,'n_pairs',nnz(good),'mode','paired');
end

function job=vlDeltaPanelLocal(ax,A,F,cfg,g,k,f)
% One violin per area/component, using the reference density/point painters.
    job=[]; hold(ax,'on'); color=cfg.area_colors(g,:);
    vals=double(A.paired_change(:,k)); vals=vals(isfinite(vals));
    [limit,fullLimit,isZoom]=vlDeltaLimitsLocal(vals,cfg);
    drawInset=isZoom && cfg.poster_show_inset;
    painter=struct('violin_width',cfg.poster_violin_width,'violin_alpha',cfg.poster_violin_alpha);
    halfSpan=max(0.65,1.4*cfg.poster_violin_width);
    xlimits=[1-halfSpan 1+halfSpan];
    if drawInset, xlimits(2)=1+1.9*halfSpan; end % reserve room at upper right
    plot(ax,xlimits,[0 0],'--','Color',[0.6 0.6 0.6], ...
        'LineWidth',0.8,'HandleVisibility','off');
    jitter=zeros(size(vals));
    if ~isempty(vals)
        profile=posterDrawSummaryLocal(ax,1,vals,painter,color,limit);
        jitter=posterViolinJitterLocal(vals,profile,cfg.poster_point_jitter_width, ...
            cfg.poster_violin_width,cfg.poster_violin_point_spread_gain, ...
            cfg.poster_violin_point_edge_fraction,10000*f+100*g+k);
        visible=abs(vals)<=limit;
        posterScatterLocal(ax,1+jitter(visible),vals(visible),color, ...
            cfg.poster_point_size,cfg.poster_point_alpha);
        posterDrawInnerMarksLocal(ax,1,vals,A.delta_center(k));
    end
    set(ax,'XLim',xlimits,'YLim',[-limit limit],'XTick',1, ...
        'XTickLabel',cfg.component_labels(k),'TickLabelInterpreter','none');
    ylabel(ax,['\Delta ' vlYAxisLabelLocal(cfg)],'Interpreter','tex');
    xlabel(ax,[F.endpoint_labels{1} ' - ' F.endpoint_labels{2}],'Interpreter','none');
    caption=[F.name ' | ' cfg.group_names{g} ' | ' cfg.component_labels{k}];
    if cfg.run_statistics && cfg.show_p_values
        p=A.stats.paired_change(k).p;
        if isfinite(p)
            pText=[posterPValueTextLocal(p) '  ' posterStarsLocal(p,cfg.significance_alpha)];
        else
            pText='\bfP\rm = NA';
        end
        title(ax,{caption,pText},'Interpreter','tex','FontWeight','normal');
    else
        title(ax,caption,'Interpreter','none','FontWeight','normal');
    end
    h=plot(ax,NaN,NaN,'o','LineStyle','none','MarkerSize',7, ...
        'MarkerFaceColor',color,'MarkerEdgeColor','none');
    legend(ax,h,sprintf('%s: n=%d',cfg.group_names{g},A.legend_neuron_count_by_component(k)), ...
        'Location','southoutside','Box','off','Interpreter','none','FontSize',cfg.font_size);
    vlAxesStyleLocal(ax,cfg);
    ax.UserData=struct('component',cfg.component_labels{k},'area',cfg.group_names{g}, ...
        'observation_unit',cfg.summary_unit,'n_deltas',numel(vals),'mode','delta', ...
        'delta_direction','first_minus_second','main_abs_limit',limit,'full_abs_limit',fullLimit, ...
        'points_outside_main_axis',sum(abs(vals)>limit),'inset_drawn',drawInset, ...
        'statistics',A.stats.paired_change(k));
    if drawInset
        job=struct('main_axes',ax,'values',vals,'jitter',jitter,'color',color, ...
            'full_limit',fullLimit,'xlimits',[1-halfSpan 1+halfSpan]);
    end
end

function [limit,fullLimit,isZoom]=vlDeltaLimitsLocal(vals,cfg)
% Reference robust symmetric scale, computed independently for EACH panel.
    isZoom=false;
    if isempty(vals), limit=0.1; fullLimit=0.1; return; end
    fullLimit=1.08*max(abs(vals));
    if strcmp(cfg.poster_outlier_mode,'zoom_inset')
        limit=1.12*posterEmpiricalPercentileLocal(abs(vals),cfg.poster_central_percentile);
        [q1,q3,lo,hi]=posterTukeySummaryLocal(vals);
        limit=max(limit,1.1*max(abs([median(vals) q1 q3])));
        limit=max(limit,1.08*max(abs([lo hi])));
        % If mean is chosen for the center mark, it must also remain visible.
        if strcmp(cfg.summary_center,'mean'), limit=max(limit,1.1*abs(mean(vals))); end
        limit=max(limit,min(fullLimit,0.002));
        isZoom=any(abs(vals)>limit);
    else
        limit=fullLimit;
    end
    if ~isfinite(limit) || limit<=0, limit=0.1; end
    if ~isfinite(fullLimit) || fullLimit<=0, fullLimit=limit; end
    if ~isZoom, limit=max(limit,fullLimit); end
end

function vlDrawDeltaInsetLocal(fig,J,cfg)
% Full-range scatter inset follows the reference; no observations are removed
% from the stored deltas or tests when the main violin is zoomed.
    ax=J.main_axes; oldUnits=ax.Units; ax.Units='normalized'; pos=ax.Position; ax.Units=oldUnits;
    rect=[pos(1)+0.65*pos(3),pos(2)+0.66*pos(4),0.30*pos(3),0.29*pos(4)];
    inset=axes('Parent',fig,'Units','normalized','Position',rect,'Color',[0.98 0.98 0.98]);
    hold(inset,'on');
    plot(inset,J.xlimits,[0 0],'--','Color',[0.6 0.6 0.6], ...
        'LineWidth',0.6,'HandleVisibility','off');
    posterScatterLocal(inset,1+J.jitter,J.values,J.color,max(2,cfg.poster_point_size*0.65),0.35);
    set(inset,'XLim',J.xlimits,'YLim',[-J.full_limit J.full_limit], ...
        'XTick',[],'YTick',[-J.full_limit 0 J.full_limit], ...
        'YAxisLocation','right','FontName',cfg.font_name,'FontSize',cfg.font_size, ...
        'TickDir','out','Box','off','LineWidth',1,'YColor',[0.4 0.4 0.4]);
    inset.UserData=struct('mode','delta_full_range_inset','n_values',numel(J.values));
end

function vlHistogramPanelLocal(ax,F,records,cfg,k)
    hold(ax,'on'); values=cell(1,2); valid=cell(1,2);
    for g=1:2
        valid{g}=isfinite(F.area(g).percent_difference_from_noise(:,k));
        values{g}=F.area(g).percent_difference_from_noise(valid{g},k);
    end
    allValues=vertcat(values{:});
    if isempty(allValues)
        edges=linspace(-1,1,cfg.histogram_num_bins+1);
    else
        lo=min([0;allValues]); hi=max([0;allValues]);
        if lo==hi, lo=lo-1; hi=hi+1; end
        pad=0.035*(hi-lo); edges=linspace(lo-pad,hi+pad,cfg.histogram_num_bins+1);
    end
    h=gobjects(2,1); labels=cell(1,2); peak=0;
    for g=1:2
        % Explicit common edges and counts keep empty distributions well-defined.
        counts=histcounts(values{g},edges);
        if strcmp(cfg.histogram_normalization,'probability') && ~isempty(values{g})
            counts=counts/numel(values{g});
        end
        h(g)=histogram(ax,'BinEdges',edges,'BinCounts',counts, ...
            'FaceColor',cfg.area_colors(g,:),'FaceAlpha',cfg.histogram_alpha,'EdgeColor','none');
        if ~isempty(counts), peak=max(peak,max(counts)); end
        usedN=vlUsedNeuronCountLocal(F.area(g),records,g,valid{g},cfg,[k 3]);
        labels{g}=sprintf('%s: n=%d',cfg.group_names{g},usedN);
    end
    xline(ax,0,'--','Color',[0.25 0.25 0.25],'LineWidth',1.3,'HandleVisibility','off');
    xlim(ax,edges([1 end]));
    if peak==0, peak=1; end
    ylim(ax,[0 1.45*peak]);
    legend(ax,h,labels,'Location','northeast','Box','off','Interpreter','none','FontSize',cfg.font_size);
    title(ax,[F.name ' | ' cfg.component_labels{k}],'Interpreter','none','FontWeight','normal');
    xlabel(ax,[cfg.component_labels{k} ' - Noise (pp)'],'Interpreter','none');
    if strcmp(cfg.histogram_normalization,'probability'), ylabel(ax,'Fraction');
    else, ylabel(ax,'Observations'); end
    if cfg.run_statistics && cfg.show_p_values
        for g=1:2
            p=F.area(g).stats.percent_difference_from_noise(k).p;
            if ~isfinite(p), label='P = NA';
            elseif p<0.001, label=sprintf('P = %.1e',p);
            else, label=sprintf('P = %.3f',p); end
            text(ax,0.03,0.95-0.09*(g-1),label,'Units','normalized', ...
                'VerticalAlignment','top','Color',cfg.area_colors(g,:), ...
                'FontName',cfg.font_name,'FontSize',cfg.font_size,'Interpreter','none');
        end
    end
    vlAxesStyleLocal(ax,cfg);
end



function label=vlYAxisLabelLocal(cfg)
    normalized=strcmp(cfg.variance_normalization,'mean_count');
    if strcmp(cfg.variance_unit,'rate')
        if normalized, label='Variance / mean rate (spikes/s)';
        else, label='Rate variance (spikes/s)^2'; end
    else
        if normalized, label='Variance / mean count';
        else, label='Count variance'; end
    end
end

function vlAxesStyleLocal(ax,cfg)
    set(ax,'FontName',cfg.font_name,'FontSize',cfg.font_size, ...
        'TickDir','out','Box','off','LineWidth',1.2,'Layer','top', ...
        'XColor',[0.2 0.2 0.2],'YColor',[0.2 0.2 0.2], ...
        'TitleFontSizeMultiplier',1,'LabelFontSizeMultiplier',1);
    grid(ax,'off');
end

function base=vlOutputNameLocal(cfg)
    if strcmp(cfg.variance_normalization,'none'), normTag='raw'; else, normTag='mean'; end
    if strcmp(cfg.neuron_population,'all_neurons'), popTag='allN'; else, popTag='pcuN'; end
    content=cfg.data_content;
    if strcmp(content,'demean_count_within_t_and_condition')
        content='dmTC';
    else
        safe=regexprep(content,'[^A-Za-z0-9_]','_');
        if numel(safe)>16 || ~strcmp(content,safe), safe=[safe(1:min(10,end)) '_' vlHashLocal(content)]; end
        content=safe;
    end
    base=sprintf('Varline_%s_r%03d_allcond_u%d_%s_%s_%s_%s_%s_%s_%s', ...
        content,cfg.runIdx,cfg.uncertainty_included,cfg.summary_unit,cfg.component_pair, ...
        cfg.variance_unit,normTag,popTag,cfg.summary_center,cfg.error_type);
    base=[base '_s8_' cfg.comparison_plot_mode];
    if strcmp(cfg.comparison_plot_mode,'delta')
        if strcmp(cfg.poster_outlier_mode,'full_range'), base=[base '_full'];
        else, base=[base '_zoom']; end
        if ~cfg.poster_show_inset, base=[base '_noInset']; end
    end
    if ~cfg.run_statistics, base=[base '_noStats'];
    else, base=[base '_' cfg.test_method]; end
    if cfg.show_p_values && cfg.run_statistics, base=[base '_P']; end
    if strcmp(cfg.comparison_plot_mode,'paired') && strcmp(cfg.summary_unit,'session') && ~cfg.show_session_individual_lines
        base=[base '_summaryOnly'];
    end
    if strcmp(cfg.comparison_plot_mode,'paired') && strcmp(cfg.summary_unit,'neuron') && cfg.show_neuron_individual_lines
        base=[base '_neuronLines'];
    end
end

function vlSaveFigureLocal(fig,folder,base,cfg)
% Short temporary paths avoid the PNG-library destination-path failure.
    if cfg.save_fig || cfg.save_png || cfg.save_svg
        if numel(fullfile(folder,[base '.png']))>=240
            base=['Varline_' cfg.summary_unit '_' cfg.component_pair '_' vlHashLocal(base)];
        end
        drawnow;
        if cfg.save_fig, savefig(fig,fullfile(folder,[base '.fig'])); end
        if cfg.save_png
            temporary=[tempname '.png']; cleaner=onCleanup(@()vlRemoveTempLocal(temporary)); %#ok<NASGU>
            try
                exportgraphics(fig,temporary,'Resolution',cfg.png_dpi);
                vlNonemptyFileLocal(temporary);
            catch exportError
                vlRemoveTempLocal(temporary);
                set(fig,'PaperPositionMode','auto');
                try
                    print(fig,temporary,'-dpng',sprintf('-r%g',cfg.png_dpi));
                    vlNonemptyFileLocal(temporary);
                catch printError
                    error('Varline:PngExport','PNG export failed. exportgraphics: %s\nprint: %s', ...
                        exportError.message,printError.message);
                end
            end
            [ok,msg]=movefile(temporary,fullfile(folder,[base '.png']),'f');
            if ~ok, error('PNG destination could not be written: %s',msg); end
            clear cleaner;
        end
        if cfg.save_svg
            temporary=[tempname '.svg']; cleaner=onCleanup(@()vlRemoveTempLocal(temporary)); %#ok<NASGU>
            set(fig,'Renderer','painters','PaperPositionMode','auto');
            print(fig,temporary,'-dsvg','-painters'); vlNonemptyFileLocal(temporary);
            [ok,msg]=movefile(temporary,fullfile(folder,[base '.svg']),'f');
            if ~ok, error('SVG destination could not be written: %s',msg); end
            clear cleaner;
        end
        fprintf('Saved figures: %s\n',fullfile(folder,base));
        if cfg.close_after_save, close(fig); end
    end
end

function vlNonemptyFileLocal(file)
    d=dir(file); if isempty(d) || d.bytes==0, error('Exporter did not create a nonempty file: %s',file); end
end

function vlRemoveTempLocal(file)
    if isfile(file), delete(file); end
end

function hash=vlHashLocal(text)
    v=0; text=double(char(text));
    for k=1:numel(text), v=mod(131*v+text(k),4294967296); end
    hash=lower(dec2hex(v,8));
end

function order=vlLabelOrderLocal(wanted,actual)
    actual=cellstr(string(actual(:)')); wanted=cellstr(string(wanted(:)'));
    if numel(unique(actual))~=numel(actual), error('Duplicate input labels.'); end
    [ok,order]=ismember(wanted,actual);
    if ~all(ok), error('Required input labels are missing: %s',strjoin(wanted(~ok),', ')); end
end

function ids=vlIdsLocal(ids)
    ids=double(ids(:));
    if any(~isfinite(ids) | ids~=round(ids)) || numel(unique(ids))~=numel(ids) || isempty(ids)
        error('Require nonempty unique finite integer neuron IDs.');
    end
end

function vlSizeLocal(A,shape,label)
    sz=size(A); sz(end+1:numel(shape))=1;
    if ~isequal(sz,shape), error('%s has unexpected dimensions.',label); end
end

function vlRequireLocal(S,fields,label)
    if ~isstruct(S), error('%s must be a struct.',label); end
    for k=1:numel(fields)
        if ~isfield(S,fields{k}), error('%s is missing %s.',label,fields{k}); end
    end
end

function vlNonnegativeLocal(A,label)
    if ~isnumeric(A) || ~isreal(A) || any(~isfinite(A(:))) || any(A(:)<0)
        error('%s must be finite nonnegative real variance.',label);
    end
end

function vlNearLocal(A,B,label,allowNaN)
    if ~isnumeric(A) || ~isnumeric(B) || ~isreal(A) || ~isreal(B) || ~isequal(size(A),size(B))
        error('Invalid shape/type in %s.',label);
    end
    A=double(A); B=double(B);
    if any(isinf(A(:))) || any(isinf(B(:))) || ~isequal(isnan(A),isnan(B)) || ...
            (~allowNaN && any(isnan(A(:))))
        error('Invalid/mismatched nonfinite values in %s.',label);
    end
    good=isfinite(A); a=A(good); b=B(good);
    if ~isempty(a) && max(abs(a-b))>1e-8*max(1,max(abs(b)))
        error('Inconsistent %s.',label);
    end
end

function dt=vlBinSecondsLocal(meta)
    if isfield(meta,'bin_size_seconds'), dt=double(meta.bin_size_seconds);
    elseif isfield(meta,'bin_size'), dt=double(meta.bin_size);
    else, error('Missing bin_size in seconds.'); end
    validateattributes(dt,{'numeric'},{'scalar','real','finite','positive'});
    if isfield(meta,'bin_size') && abs(double(meta.bin_size)-dt)>1e-9*dt
        error('bin_size and bin_size_seconds disagree.');
    end
    for f={'bin_edges','bin_centers'}
        if ~isfield(meta,f{1}) || isempty(meta.(f{1})), continue; end
        v=double(meta.(f{1}));
        if ~isvector(v) || any(~isfinite(v(:))) || any(abs(diff(v(:))-dt)>1e-7*dt)
            error('Invalid analysis-bin metadata in %s.',f{1});
        end
    end
end


function [gpl_group_by_index, gpl_file_by_index] = ...
    loadGplGroupsByModelIndexLocal( ...
    session_dir, gpl_mat_name, num_groups)
% Load every probe-level GPL MAT at most once and map its nested group
% entries to the reconstruction group order. Only model_group_index is used
% for mapping. Stored group/area names and user-supplied probe IDs are not
% read for data selection or consistency checks.

    d = dir(fullfile( ...
        session_dir, ...
        '*_imec*', ...
        'kilosort*', ...
        gpl_mat_name));

    d = d(~[d.isdir]);

    if isempty(d)
        error(['No %s was found under any *_imec*/kilosort* folder ', ...
            'in %s. Run GPL_analysis_by_area.m first.'], ...
            gpl_mat_name, session_dir);
    end

    paths = cell(1, numel(d));
    for i = 1:numel(d)
        paths{i} = fullfile(d(i).folder, d(i).name);
    end

    [paths, sort_order] = sort(paths);
    d = d(sort_order);

    gpl_group_by_index = cell(1, num_groups);
    gpl_file_by_index = cell(1, num_groups);

    for file_idx = 1:numel(d)
        gpl_file = paths{file_idx};
        S = load(gpl_file, 'gpl_results');

        if ~isfield(S, 'gpl_results') || ...
                ~isstruct(S.gpl_results) || ...
                ~isscalar(S.gpl_results)
            error('%s does not contain one valid gpl_results struct.', ...
                gpl_file);
        end

        P = S.gpl_results;

        if ~isfield(P, 'format_version') || ...
                ~(ischar(P.format_version) || ...
                (isstring(P.format_version) && isscalar(P.format_version))) || ...
                ~strcmp(char(P.format_version), 'grouped_by_probe_v1')
            error(['Unsupported GPL result format in %s. This program ', ...
                'requires the grouped probe-level output produced by ', ...
                'GPL_analysis_by_area.m.'], gpl_file);
        end

        if ~isfield(P, 'group') || ~isstruct(P.group) || isempty(P.group)
            error('%s is missing nonempty gpl_results.group.', gpl_file);
        end

        for local_group_idx = 1:numel(P.group)
            G = P.group(local_group_idx);

            if ~isfield(G, 'model_group_index') || ...
                    ~isnumeric(G.model_group_index) || ...
                    ~isscalar(G.model_group_index) || ...
                    ~isfinite(double(G.model_group_index)) || ...
                    double(G.model_group_index) ~= ...
                    round(double(G.model_group_index))
                error(['%s contains a nested GPL group with an invalid ', ...
                    'model_group_index.'], gpl_file);
            end

            group_idx = double(G.model_group_index);

            if group_idx < 1 || group_idx > num_groups
                error(['%s contains model_group_index %d, but the ', ...
                    'reconstruction contains groups 1:%d.'], ...
                    gpl_file, group_idx, num_groups);
            end

            if ~isempty(gpl_group_by_index{group_idx})
                error(['Model group %d was found in more than one GPL ', ...
                    'group entry. The classification source is ambiguous:\n', ...
                    '%s\n%s'], ...
                    group_idx, gpl_file_by_index{group_idx}, gpl_file);
            end

            gpl_group_by_index{group_idx} = G;
            gpl_file_by_index{group_idx} = gpl_file;
        end
    end

    missing_groups = find(cellfun(@isempty, gpl_group_by_index));

    if ~isempty(missing_groups)
        error(['No GPL group entry was found for model group(s) %s in ', ...
            '%s.'], mat2str(missing_groups), session_dir);
    end

    fprintf('  GPL source files found: %d\n', numel(d));
end

function info = validateAndExtractClassesLocal( ...
    G, model_ids, group_display_name, gpl_file)

    if ~isfield(G, 'used_unit_ids') || ~isfield(G, 'plaid')
        error('%s lacks used_unit_ids or plaid classification.', ...
            gpl_file);
    end

    if ~isfield(G, 'baseline_subtracted') || ...
            ~(islogical(G.baseline_subtracted) || ...
            isnumeric(G.baseline_subtracted)) || ...
            ~isscalar(G.baseline_subtracted) || ...
            ~isfinite(double(G.baseline_subtracted)) || ...
            ~ismember(double(G.baseline_subtracted), [0, 1]) || ...
            ~logical(G.baseline_subtracted)
        error('%s is not marked baseline_subtracted = true.', gpl_file);
    end

    gpl_ids = double(G.used_unit_ids(:));
    model_ids = double(model_ids(:));

    if numel(gpl_ids) ~= numel(model_ids)
        error(['Neuron-count mismatch for %s: ', ...
            'reconstruction=%d, GPL=%d.'], ...
            group_display_name, ...
            numel(model_ids), numel(gpl_ids));
    end

    if numel(unique(gpl_ids)) ~= numel(gpl_ids) || ...
            numel(unique(model_ids)) ~= numel(model_ids)
        error('Duplicate unit IDs found for %s.', group_display_name);
    end

    if ~isequal(sort(gpl_ids), sort(model_ids))
        error('GPL/reconstruction unit-ID sets differ for %s.', ...
            group_display_name);
    end

    if ~isequal(gpl_ids, model_ids)
        error('GPL/reconstruction unit-ID order differs for %s.', ...
            group_display_name);
    end

    required_masks = { ...
        'is_pattern', ...
        'is_component', ...
        'is_unclassified', ...
        'is_invalid'};

    masks = cell(size(required_masks));

    for i = 1:numel(required_masks)
        mask_name = required_masks{i};

        if ~isfield(G.plaid, mask_name)
            error('%s is missing gpl_results.plaid.%s.', ...
                gpl_file, mask_name);
        end

        this_mask = G.plaid.(mask_name);
        masks{i} = logical(this_mask(:));

        if numel(masks{i}) ~= numel(model_ids)
            error('GPL class mask %s has the wrong length.', ...
                mask_name);
        end
    end

    class_count = zeros(numel(model_ids), 1);

    for i = 1:numel(masks)
        class_count = class_count + double(masks{i});
    end

    if any(class_count ~= 1)
        bad_ids = model_ids(class_count ~= 1);

        error(['GPL classes are not mutually exclusive and exhaustive ', ...
            'for %s. Affected IDs: %s'], ...
            group_display_name, summarizeIdsLocal(bad_ids));
    end

    info = struct();
    info.unit_ids = model_ids;
    info.pattern = masks{1};
    info.component = masks{2};
    info.unclassified = masks{3};
    info.invalid = masks{4};
end

function s = summarizeIdsLocal(ids)
    ids = ids(:)';

    if isempty(ids)
        s = 'none';
    elseif numel(ids) <= 20
        s = mat2str(ids);
    else
        s = sprintf('%s ... (%d total)', ...
            mat2str(ids(1:20)), numel(ids));
    end
end



function label = posterPValueTextLocal(p)
    prefix = '\bfP\rm'; % Bold only the P, not the value or stars.
    if p < 0.001
        label = [prefix, '<0.001'];
    else
        label = sprintf('%s=%.3g', prefix, p);
    end
end

function stars = posterStarsLocal(p, alpha)
    if p >= alpha
        stars = 'ns';
    elseif p < 0.0001
        stars = '****';
    elseif p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    else
        stars = '*';
    end
end

function value = posterEmpiricalPercentileLocal(vals, percent)
% Empirical lower order statistic, so one extreme point cannot alone set
% the axis height in a small sample. No Statistics Toolbox is required.
    vals = sort(vals(isfinite(vals)));
    if isempty(vals)
        value = NaN;
        return;
    end
    rank = max(1, min(numel(vals), floor(numel(vals) * percent / 100)));
    value = vals(rank);
end

function value = posterInterpolatedPercentileLocal(vals, percent)
% Use interpolated quartiles for descriptive statistics. The more robust
% lower-order percentile above is reserved for the main-axis zoom limit.
    vals = sort(vals(isfinite(vals)));
    rank = 1 + (numel(vals) - 1) * percent / 100;
    lower_rank = floor(rank);
    upper_rank = ceil(rank);
    value = vals(lower_rank) + (rank - lower_rank) * ...
        (vals(upper_rank) - vals(lower_rank));
end

function profile = posterDrawSummaryLocal( ...
    ax, x0, vals, config, area_color, ylimit)
% Return exactly the violin contour used for centered point spreading.
    profile = struct('y', [], 'half_width', []);
    within_axis = vals(abs(vals) <= ylimit);
    if numel(within_axis) <= 1 || max(within_axis) <= min(within_axis)
        return;
    end
    [density, yy] = estimateDensityLocal(within_axis);
    valid = isfinite(density(:)) & isfinite(yy(:));
    density = double(density(valid));
    yy = double(yy(valid));
    if numel(yy) <= 1 || max(density) <= 0
        return;
    end
    [yy, idx] = sort(yy);
    density = max(density(idx), 0);
    [yy, idx] = unique(yy, 'stable');
    density = density(idx);
    if numel(yy) < 30
        kernel = [1, 4, 6, 4, 1] / 16;
        density = conv(density, kernel, 'same');
        grid_y = linspace(min(within_axis), ...
            max(within_axis), 100)';
        density = max(0, interp1(yy, density, grid_y, 'linear', 0));
        yy = grid_y;
    end
    if max(density) <= 0
        return;
    end
    half_width = density ./ max(density) .* config.violin_width;
    yy = yy(:);
    half_width = half_width(:);
    profile.y = yy;
    profile.half_width = half_width;
    % Explicit columns avoid accidental horizontal colored patch edges.
    patch(ax, [x0 - half_width; x0 + flipud(half_width)], ...
        [yy; flipud(yy)], area_color, ...
        'FaceAlpha', config.violin_alpha, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    plot(ax, x0 - half_width, yy, '-', 'Color', area_color, ...
        'LineWidth', 0.9, 'HandleVisibility', 'off');
    plot(ax, x0 + half_width, yy, '-', 'Color', area_color, ...
        'LineWidth', 0.9, 'HandleVisibility', 'off');
end

function jitter = posterViolinJitterLocal( ...
    vals, profile, base_width, violin_width, gain, edge_fraction, seed)
% Like densityAwareJitterLocal in the source: a CENTERED uniform random
% offset, narrower where the density is lower. Gain scales all spreads.
    jitter = zeros(numel(vals), 1);
    if numel(profile.y) < 2
        return;
    end
    contour_width = interp1(profile.y, profile.half_width, ...
        vals(:), 'linear', 0);
    contour_width(~isfinite(contour_width)) = 0;
    contour_width = max(0, contour_width);
    density_ratio = min(1, contour_width ./ violin_width);
    density_floor = 0.08; % matches densityAwareJitterLocal
    density_factor = density_floor + ...
        (1 - density_floor) .* density_ratio;
    local_spread = base_width .* gain .* density_factor;
    local_spread = min(local_spread, edge_fraction .* contour_width);
    stream = RandStream('mt19937ar', 'Seed', seed);
    jitter = (2 .* rand(stream, numel(vals), 1) - 1) .* ...
        local_spread;
end

function [q1, q3, whisker_low, whisker_high] = ...
        posterTukeySummaryLocal(vals)
% Whiskers end at the most extreme OBSERVED inliers, not at a theoretical
% Q1/Q3 +/- 1.5*IQR position that may contain no measured observation.
    q1 = posterInterpolatedPercentileLocal(vals, 25);
    q3 = posterInterpolatedPercentileLocal(vals, 75);
    iqr_value = q3 - q1;
    inliers = vals(vals >= q1 - 1.5 * iqr_value & ...
        vals <= q3 + 1.5 * iqr_value);
    whisker_low = min(inliers);
    whisker_high = max(inliers);
end

function posterDrawInnerMarksLocal(ax, x0, vals, center)
% Black Q1-Q3 bar, thin observed Tukey whiskers, horizontal selected mean/median mark.
    [q1, q3, whisker_low, whisker_high] = ...
        posterTukeySummaryLocal(vals);
    ink = [0, 0, 0];
    plot(ax, [x0, x0], [whisker_low, whisker_high], '-', ...
        'Color', ink, 'LineWidth', 1.1, 'HandleVisibility', 'off');
    for v = [whisker_low, whisker_high]
        plot(ax, [x0 - 0.06, x0 + 0.06], [v, v], '-', ...
            'Color', ink, 'LineWidth', 1.1, 'HandleVisibility', 'off');
    end
    plot(ax, [x0, x0], [q1, q3], '-', ...
        'Color', ink, 'LineWidth', 5, 'HandleVisibility', 'off');
    plot(ax, [x0 - 0.19, x0 + 0.19], ...
        [center, center], '-', ...
        'Color', [1, 1, 1], 'LineWidth', 4.5, ...
        'HandleVisibility', 'off');
    plot(ax, [x0 - 0.2, x0 + 0.2], ...
        [center, center], '-', ...
        'Color', ink, 'LineWidth', 2.3, ...
        'HandleVisibility', 'off');
end

function posterScatterLocal(ax, x, y, area_color, point_size, alpha)
    if isempty(y)
        return;
    end
    try
        scatter(ax, x, y, point_size, 'o', ...
            'MarkerFaceColor', area_color, ...
            'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', alpha, 'HandleVisibility', 'off');
    catch
        lighter = 1 - alpha * (1 - area_color);
        scatter(ax, x, y, point_size, 'o', ...
            'MarkerFaceColor', lighter, ...
            'MarkerEdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
end

function [f, xi] = estimateDensityLocal(vals)

    vals = vals(:);
    vals = vals(isfinite(vals));

    if isempty(vals) || numel(vals) < 2 || max(vals) == min(vals)
        f = [];
        xi = [];
        return;
    end

    if exist('ksdensity', 'file') == 2
        try
            [f, xi] = ksdensity(vals, 'NumPoints', 100);
            return;
        catch
            % Fall through to histogram fallback.
        end
    end

    num_bins = min(20, max(5, round(sqrt(numel(vals)))));

    try
        [counts, edges] = histcounts( ...
            vals, num_bins, 'Normalization', 'pdf');
    catch
        [counts, edges] = histcounts(vals, num_bins);
        bin_width = mean(diff(edges));

        if sum(counts) <= 0 || ~isfinite(bin_width) || bin_width <= 0
            f = [];
            xi = [];
            return;
        end

        counts = counts ./ (sum(counts) * bin_width);
    end

    xi = edges(1:end-1) + diff(edges) / 2;
    f = counts;

    valid = isfinite(f) & isfinite(xi);
    f = f(valid);
    xi = xi(valid);
end
