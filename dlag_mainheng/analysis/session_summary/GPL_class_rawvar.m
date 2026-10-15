%% GPL_class_rawvar.m
% Across-session balance of MODEL variance in Pattern/Component/Unclassified
% neurons, using separately fitted each-condition DLAG models.
% This is a standalone script; start with an empty workspace.
%
% Prerequisites, in each root_dir/*/catgt_* session:
%   plot_dlag_results_for_each_condtion_mode_var.m
%   latent_compare_for_each_condtion_mode.m
%   GPL_analysis_by_area.m -> unit_gpl_results_sponsub.mat
% All summary MAT/FIG/PNG/SVG files go to root_dir/each_condition_mode.
%
% First SUM variance over latents of a category, then average over neurons
% belonging to one GPL class (invalid excluded). Differences are:
%   acr_vs_wit = mean-per-neuron Across variance - Within variance
%   ff_vs_fb   = mean-per-neuron Feedforward variance - Feedback variance
% No averaging across latent dimensions and no variance/R2 normalization.
% Across contains FF, FB and Ambiguous. Independent noise is retained in
% saved class variance summaries but does not enter these differences.
%
% condition_display_mode controls STIMULUS display in THIS program:
%   separate : display eight stimulus-condition distributions, each with
%              two direction points per session, within every class x delta.
%   pooled   : average the eight condition deltas WITHIN each direction;
%              one session then contributes TWO points per class x delta.
%              These are equally weighted eight-condition means, not a
%              concatenation of the sixteen deltas.
%   pool     : alias of pooled.
% Neuron classes remain separate in both modes.
%
% A point represents a class average, not a single neuron. The two stimulus
% directions are calculated in their own models and retained separately.
% A missing cell class gives NaN and contributes no point. A category with
% no retained latents has zero variance when the cell class is present.
% Require all eight conditions in both directions; incomplete sessions are
% skipped with a reason instead of averaging fewer than eight conditions.
%
% DSL_filter selects all_latents or the saved DSL_filtered masks. Filtered
% across latents use the same joint keep rule as latent_compare.
% Raw deltas, full class variance summaries, both display representations,
% neuron counts and source session/direction IDs are always saved in MAT.

% Added source selection:
%   variance_source = 'model'     : existing C^2 / R results and DSL support.
%   variance_source = 'posterior' : run posterior_rawvar_each_condition_mode.m
%       first in every session. Uses its saved neuron category variances;
%       M-1 across trials per bin, then mean over bins. No model reload or
%       reconstruction, no DSL filtering, and no independent-noise category.
%   uncertainty_included = 0 / 1 : selects the matching posterior u0/u1 file.
%       Ignored for MODEL source. Mismatched/missing inputs are not mixed.
% Posterior category variances are not additive across latent categories.
% Missing nonempty Ambiguous reconstructions remain NaN; existing categories
% and A-W / FF-FB differences continue to work. An absent cell class is NaN.
% Both sources save to root_dir/each_condition_mode with source-specific names.
% Statements about C^2, R and variance additivity above apply only to MODEL.

clc; clear;

%% ============================ USER SETTINGS ===========================
root_dir = 'I:\np_data';
data_content = 'demean_count_within_t_and_condition';
runIdx = 1;                          % 1 = data; 2 = independently shuffled data
group_names = {'V1','MT'};            % display labels in MODEL GROUP order
gpl_mat_name = 'unit_gpl_results_sponsub.mat';
variance_source = 'model';          % 'model' or 'posterior'
uncertainty_included = 0;           % posterior only: 0 = no; 1 = yes

DSL_filter = 'all_latents';           % 'all_latents' or 'DSL_filtered'
condition_display_mode = 'separate';  % 'separate' or 'pooled' (STIMULUS conditions)

save_mat = true;
save_fig = false;
save_png = true;
save_svg = false;
png_dpi = 300;
close_after_save = true;
make_plots = true;
figure_visible = 'on';
print_full_error_report = false;

plot_style = 'points_median';         % 'points_median', 'bar_points', 'violin'
plot_show_mean = struct('bar_points',true,'violin',false,'points_median',false);
plot_show_median = struct('bar_points',false,'violin',true,'points_median',true);
point_size = 50;
point_alpha = 0.70;
point_jitter_width = 0.08;
violin_width = 0.28;
violin_alpha = 0.28;
bar_width = 0.48;
bar_alpha = 0.90;
mean_marker_size = 5;
median_marker_size = 6;
median_line_width = 2;
condition_colors = lines(8);
pooled_condition_color = [0.35 0.35 0.35];
condition_step = 0.70;
between_delta_gap = 1.35;
between_class_gap = 2.10;
font_name = 'Arial';
axis_font_size = 11;
figure_width = 1900;
figure_height = 780;

%% ============================== CONFIG ================================
cfg = struct('root_dir',root_dir,'data_content',data_content,'runIdx',runIdx, ...
    'group_names',{group_names},'gpl_mat_name',gpl_mat_name, ...
    'variance_source',variance_source,'uncertainty_included',uncertainty_included, ...
    'condition_display_mode',condition_display_mode,'DSL_filter',DSL_filter, ...
    'save_mat',save_mat,'save_fig',save_fig,'save_png',save_png,'save_svg',save_svg, ...
    'png_dpi',png_dpi,'close_after_save',close_after_save,'make_plots',make_plots, ...
    'figure_visible',figure_visible,'print_full_error_report',print_full_error_report, ...
    'plot_style',plot_style,'plot_show_mean',plot_show_mean,'plot_show_median',plot_show_median, ...
    'point_size',point_size,'point_alpha',point_alpha,'point_jitter_width',point_jitter_width, ...
    'violin_width',violin_width,'violin_alpha',violin_alpha,'bar_width',bar_width, ...
    'bar_alpha',bar_alpha,'mean_marker_size',mean_marker_size, ...
    'median_marker_size',median_marker_size,'median_line_width',median_line_width, ...
    'condition_colors',condition_colors,'pooled_condition_color',pooled_condition_color, ...
    'condition_step',condition_step,'between_delta_gap',between_delta_gap, ...
    'between_class_gap',between_class_gap,'font_name',font_name,'axis_font_size',axis_font_size, ...
    'figure_width',figure_width,'figure_height',figure_height);
cfg = normalizeConfigLocal(cfg);
cfg = normalizeVarianceSourceLocal(cfg);
cfg.delta_names = {'acr_vs_wit','ff_vs_fb'};
cfg.delta_labels = {'acr vs. wit','ff vs. fb'};
cfg.delta_definitions = {'Across - Within','Feedforward - Feedback'};

%% ======================== READ AND CALCULATE ==========================
[records,skipped] = loadSessionsLocal(cfg,true);
out_base = sprintf('GPLrawVar_%s_r%03d_%s_%s_%s_%s', ...
    safeTagLocal(cfg.data_content),cfg.runIdx,cfg.mapping_tag, ...
    cfg.condition_display_mode,filterTagLocal(cfg,records),cfg.plot_style);
out_base = [out_base '_' cfg.source_tag];
MultiSessionRawVar = packRawDeltaSummaryLocal(records,skipped,cfg,out_base);
if cfg.save_mat || (cfg.make_plots && (cfg.save_fig || cfg.save_png || cfg.save_svg))
    ensureOutputDirLocal(cfg.output_dir);
end
if cfg.save_mat
    filename = fullfile(cfg.output_dir,[out_base '.mat']);
    save(filename,'MultiSessionRawVar','-v7.3');
    fprintf('Saved %s\n',filename);
end

%% ================================= PLOT ===============================
if cfg.make_plots
    for g = 1:numel(cfg.group_names)
        fig = plotRawDeltaSummaryLocal(MultiSessionRawVar,g,cfg);
        saveFigureLocal(fig,cfg.output_dir,sprintf('%s_g%02d',out_base,g),cfg);
    end
end
fprintf('Done: %d sessions. Each class/delta has two direction observations per session.\n', ...
    numel(records));

function M = packRawDeltaSummaryLocal(records,skipped,cfg,outBase)
    ns = numel(records); ng = numel(cfg.group_names);
    M = struct();
    M.values_separate = nan(2*ns,ng,3,8,2);
    M.values_pooled = nan(2*ns,ng,3,2);
    K = size(records{1}.group(1).population(1).raw_mean,2);
    M.raw_variance_mean = nan(2*ns,ng,3,8,K);
    M.raw_variance_sum = nan(2*ns,ng,3,8,K);
    M.n_neurons = nan(2*ns,ng,3,8);
    M.condition_ids = nan(2*ns,8);
    for s = 1:ns
        for d = 1:2
            obs = 2*(s-1)+d;
            M.condition_ids(obs,:) = records{s}.condition_ids(:,d)';
            for g = 1:ng
                for c = 1:3
                    B = records{s}.group(g).population(c);
                    V = B.raw_mean(:,:,d);
                    D = V(:,[1 3])-V(:,[2 4]);
                    M.values_separate(obs,g,c,:,:) = reshape(D,[1 1 1 8 2]);
                    % Full, equally weighted mean across all eight conditions.
                    % An absent class remains NaN; do not silently omit conditions.
                    avg = mean(D,1);
                    M.values_pooled(obs,g,c,:) = reshape(avg,[1 1 1 2]);
                    M.raw_variance_mean(obs,g,c,:,:) = reshape(V,[1 1 1 8 K]);
                    M.raw_variance_sum(obs,g,c,:,:) = reshape(B.raw_sum(:,:,d),[1 1 1 8 K]);
                    M.n_neurons(obs,g,c,:) = reshape(B.n_neurons(:,d),[1 1 1 8]);
                end
            end
        end
    end
    M.dimension_names_separate = {'session_direction','model_group','cell_class', ...
        'stimulus_condition','delta_type'};
    M.dimension_names_pooled = {'session_direction','model_group','cell_class','delta_type'};
    M.dimension_names_variance = {'session_direction','model_group','cell_class', ...
        'stimulus_condition','variance_category'};
    if strcmp(cfg.condition_display_mode,'separate')
        M.values = M.values_separate;
        M.dimension_names = M.dimension_names_separate;
    else
        M.values = M.values_pooled;
        M.dimension_names = M.dimension_names_pooled;
    end
    M.labels.groups = cfg.group_display_names;
    M.labels.classes = cfg.class_labels;
    M.labels.conditions = cfg.condition_labels;
    M.labels.delta_names = cfg.delta_names;
    M.labels.delta_definitions = cfg.delta_definitions;

    M.labels.variance = cfg.latent_labels;
    if strcmp(cfg.variance_source,'model'), M.labels.variance{6} = 'Independent noise'; end
    M.observation_info = observationInfoLocal(records);
    M.session_data = records;
    M.skipped_sessions = skipped;
    M.settings = cfg;
    M.meta.created_by = 'GPL_class_rawvar.m';
    M.meta.created_on = datestr(now,30);
    M.meta.output_base = outBase;
    M.meta.num_sessions = ns;
    M.meta.num_direction_observations = 2*ns;
    M.meta.pooled_definition = 'mean of eight stimulus-condition deltas within each session-direction';
    M.meta.raw_definition = 'sum over category latents and selected class neurons / class neuron count';
    M.meta.delta_unit = 'squared units of data_content per neuron';
    M.meta.invalid_neurons = 'excluded from class means; retained in source ID alignment';
    M.meta.variance_source = cfg.variance_source;
    M.meta.uncertainty_included = cfg.uncertainty_included_effective;
    if strcmp(cfg.variance_source,'posterior')
        M.meta.raw_definition = 'mean of class neuron trial variances; each computed per bin with M-1, then averaged over bins';
        M.meta.variance_method = 'across_trials_per_bin_mean_over_bins';
        M.meta.variance_normalization = 'M-1';
    end
    M.n_points_separate = reshape(sum(isfinite(M.values_separate),1),[ng 3 8 2]);
    M.n_points_pooled = reshape(sum(isfinite(M.values_pooled),1),[ng 3 2]);
end

function fig = plotRawDeltaSummaryLocal(M,g,cfg)
    separate = strcmp(cfg.condition_display_mode,'separate');
    nCond = 1+7*separate;
    positions = zeros(3,2,nCond);
    centers = zeros(3,2);
    classCenters = zeros(1,3);
    cursor = 1;
    for c = 1:3
        for k = 1:2
            xs = cursor+(0:nCond-1)*cfg.condition_step;
            positions(c,k,:) = reshape(xs,[1 1 nCond]);
            centers(c,k) = mean(xs);
            cursor = xs(end)+cfg.between_delta_gap;
        end
        classCenters(c) = mean(centers(c,:));
        cursor = cursor+cfg.between_class_gap;
    end
    fig = figure('Visible',cfg.figure_visible, ...
        'Position',[100 100 cfg.figure_width cfg.figure_height]);
    ax = axes(fig,'Position',[0.075 0.27 0.90 0.60]); hold(ax,'on');
    for c = 1:3
        for k = 1:2
            for p = 1:nCond
                if separate
                    y = reshape(M.values_separate(:,g,c,p,k),[],1);
                    color = cfg.condition_colors(p,:);
                else
                    y = reshape(M.values_pooled(:,g,c,k),[],1);
                    color = cfg.pooled_condition_color;
                end
                drawDistributionLocal(ax,positions(c,k,p),y,color,cfg,1, ...
                    100000*g+10000*c+100*k+p);
            end
        end
    end
    ticks = reshape(centers',1,[]);
    tickLabels = repmat(cfg.delta_labels,1,3);
    set(ax,'XTick',ticks,'XTickLabel',tickLabels,'TickLabelInterpreter','none', ...
        'FontName',cfg.font_name,'FontSize',cfg.axis_font_size);
    xl = [min(positions(:))-0.6,max(positions(:))+0.6];
    xlim(ax,xl);
    if separate
        values = reshape(M.values_separate(:,g,:,:,:),[],1);
        displayText = 'Eight conditions separately; two directions per session';
    else
        values = reshape(M.values_pooled(:,g,:,:),[],1);
        displayText = 'Mean over eight conditions within each direction; two points per session';
    end
    finite = values(isfinite(values));
    if isempty(finite) || all(finite == 0)
        yl = [-1 1];
    else
        lo = min([0;finite]); hi = max([0;finite]);
        margin = 0.08*(hi-lo);
        yl = [lo-margin,hi+margin];
    end
    ylim(ax,yl);
    yline(ax,0,'--','Color',[0.55 0.55 0.55],'HandleVisibility','off');
    for c = 1:3
        xn = (classCenters(c)-xl(1))/diff(xl);
        text(ax,xn,-0.105,cfg.class_labels{c},'Units','normalized', ...
            'HorizontalAlignment','center','VerticalAlignment','top', ...
            'FontName',cfg.font_name,'FontSize',cfg.axis_font_size,'Clipping','off');
    end
    ylabel(ax,cfg.delta_y_label,'Interpreter','none');
    title(ax,{sprintf('%s | %s | %s',cfg.group_display_names{g},cfg.data_content,[cfg.source_tag ' | ' cfg.DSL_filter]), ...
        sprintf('%s (%d sessions)',displayText,M.meta.num_sessions)},'Interpreter','none');
    grid(ax,'on'); box(ax,'off');
    if separate
        addConditionLegendLocal(ax,cfg);
        leg = legend(ax);
        leg.Units = 'normalized';
        leg.Position = [0.20 0.045 0.64 0.075];
        ax.Position = [0.075 0.27 0.90 0.60];
    end
end

%% ========================== Local functions ===========================
function cfg = normalizeConfigLocal(cfg)
    cfg.root_dir = char(cfg.root_dir);
    cfg.data_content = strtrim(char(cfg.data_content));
    if ~isfolder(cfg.root_dir) || isempty(cfg.data_content)
        error('Check root_dir and data_content.');
    end
    validateattributes(cfg.runIdx, {'numeric'}, ...
        {'scalar','integer','positive','finite'}, mfilename, 'runIdx');
    cfg.group_names = normalizeGroupNamesLocal(cfg.group_names);
    cfg.condition_labels = {'G-S-L','G-S-H','G-L-L','G-L-H', ...
        'P-S-L','P-S-H','P-L-L','P-L-H'};
    cfg.latent_labels = {'Across','Within','Feedforward','Feedback','Ambiguous'};
    cfg.class_names = {'pattern','component','unclassified'};
    cfg.class_labels = {'Pattern cell','Component cell','Unclassified cell'};
    cfg.class_tags = {'P','C','U'};
    switch lower(strtrim(char(cfg.DSL_filter)))
        case 'all_latents'
            cfg.DSL_filter = 'all_latents';
            cfg.source_field = 'all';
        case 'dsl_filtered'
            cfg.DSL_filter = 'DSL_filtered';
            cfg.source_field = 'filtered';
        otherwise
            error('DSL_filter must be all_latents or DSL_filtered.');
    end
    cfg.condition_display_mode = lower(strtrim(char(cfg.condition_display_mode)));
    if strcmp(cfg.condition_display_mode,'pool')
        cfg.condition_display_mode = 'pooled';
    end
    if ~ismember(cfg.condition_display_mode,{'separate','pooled'})
        error('condition_display_mode must be separate or pooled (pool is an alias).');
    end
    cfg.plot_style = lower(strtrim(char(cfg.plot_style)));
    if ~ismember(cfg.plot_style,{'points_median','bar_points','violin'})
        error('plot_style must be points_median, bar_points or violin.');
    end
    if ~isfield(cfg.plot_show_mean,cfg.plot_style) || ...
            ~isfield(cfg.plot_show_median,cfg.plot_style)
        error('plot_show_mean and plot_show_median must define each plot style.');
    end
    cfg.show_mean = logical(cfg.plot_show_mean.(cfg.plot_style));
    cfg.show_median = logical(cfg.plot_show_median.(cfg.plot_style));
    flags = {'make_plots','save_mat','save_fig','save_png','save_svg', ...
        'close_after_save','print_full_error_report','show_mean','show_median'};
    for k = 1:numel(flags)
        x = cfg.(flags{k});
        if ~isscalar(x) || ~isfinite(double(x)) || ~ismember(double(x),[0 1])
            error('%s must be a logical scalar.',flags{k});
        end
    end
    if ~ismember(char(cfg.figure_visible),{'on','off'})
        error('figure_visible must be on or off.');
    end
    validateattributes(cfg.png_dpi,{'numeric'},{'scalar','positive','finite'});
    assertSizeLocal(cfg.condition_colors,[8 3],'condition_colors');
    if any(~isfinite(cfg.condition_colors(:)) | cfg.condition_colors(:)<0 | cfg.condition_colors(:)>1)
        error('condition_colors must contain RGB values between zero and one.');
    end
    positive = {'point_size','violin_width','bar_width','mean_marker_size', ...
        'median_marker_size','median_line_width','figure_width','figure_height'};
    for k = 1:numel(positive)
        validateattributes(cfg.(positive{k}),{'numeric'},{'scalar','positive','finite'});
    end
    validateattributes(cfg.point_jitter_width,{'numeric'},{'scalar','nonnegative','finite'});
    alphaNames = {'point_alpha','violin_alpha','bar_alpha'};
    for k = 1:numel(alphaNames)
        validateattributes(cfg.(alphaNames{k}),{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
    end
    cfg.output_dir = fullfile(cfg.root_dir,'each_condition_mode');
    cfg.group_tags = cell(1,numel(cfg.group_names));
    cfg.group_display_names = cell(size(cfg.group_tags));
    for g = 1:numel(cfg.group_names)
        cfg.group_tags{g} = sprintf('G%02d_%s',g,safeTagLocal(cfg.group_names{g}));
        cfg.group_display_names{g} = sprintf('Group %d: %s',g,cfg.group_names{g});
    end
    cfg.mapping_tag = strjoin(cfg.group_tags,'_');
end

function [records,skipped] = loadSessionsLocal(cfg,needClasses)
    d = dir(fullfile(cfg.root_dir,'*','catgt_*'));
    d = d([d.isdir]);
    paths = arrayfun(@(x) fullfile(x.folder,x.name),d,'UniformOutput',false);
    paths = sort(unique(paths));
    if isempty(paths)
        error('No session folders found at %s/*/catgt_*.',cfg.root_dir);
    end
    records = {};
    skipped = struct('session_dir',{},'reason',{});
    for k = 1:numel(paths)
        fprintf('[%d/%d] %s\n',k,numel(paths),paths{k});
        try
            rec = readSessionLocal(paths{k},cfg,needClasses);
            if strcmp(cfg.source_field,'filtered') && ~isempty(records)
                if abs(rec.DSL_threshold-records{1}.DSL_threshold) > 1e-12
                    error('DSL threshold differs from the first included session.');
                end
            end
            records{end+1} = rec; %#ok<SAGROW>
        catch ME
            skipped(end+1) = struct('session_dir',paths{k},'reason',ME.message); %#ok<SAGROW>
            warning('Skipping %s\n%s',paths{k},ME.message);
            if cfg.print_full_error_report
                fprintf('%s\n',getReport(ME,'extended','hyperlinks','off'));
            end
        end
    end
    if isempty(records)
        error('No valid sessions. See the listed file/metadata errors above.');
    end
    fprintf('Included %d sessions; skipped %d.\n',numel(records),numel(skipped));
end

function rec = readSessionLocal(sessionDir,cfg,needClasses)
    if strcmp(cfg.variance_source,'posterior')
        rec = readPosteriorSessionLocal(sessionDir,cfg,needClasses);
        return;
    end
    summaryFile = fullfile(sessionDir,sprintf( ...
        '%s_run%03d_eachcond_variance_DSL_summary.mat',cfg.data_content,cfg.runIdx));
    if ~isfile(summaryFile)
        error('Missing %s. Run latent_compare_for_each_condtion_mode.m first.',summaryFile);
    end
    if needClasses
        S = load(summaryFile,'SummaryVariance','AllConditionResults');
        requireFieldsLocal(S,{'SummaryVariance','AllConditionResults'},summaryFile);
    else
        S = load(summaryFile,'SummaryVariance');
        requireFieldsLocal(S,{'SummaryVariance'},summaryFile);
    end
    V = S.SummaryVariance;
    requireFieldsLocal(V,{'meta','labels','group'},summaryFile);
    requireFieldsLocal(V.meta,{'data_content','runIdx','conditionShortLabels', ...
        'dirValues','DSL_threshold'},'SummaryVariance.meta');
    if ~strcmp(char(V.meta.data_content),cfg.data_content) || V.meta.runIdx ~= cfg.runIdx
        error('Summary data_content/runIdx does not match the requested input.');
    end
    ng = numel(cfg.group_names);
    if numel(V.group) ~= ng
        error('Summary has %d groups, but group_names has %d.',numel(V.group),ng);
    end
    [ok,rowOrder] = ismember(cfg.condition_labels,cellstr(string(V.meta.conditionShortLabels)));
    if ~all(ok) || numel(V.meta.conditionShortLabels) ~= 8 || numel(unique(rowOrder)) ~= 8
        error('Expected exactly the eight G-S-L through P-L-H labels.');
    end
    [ok,colOrder] = ismember(cfg.latent_labels,cellstr(string(V.labels)));
    if ~all(ok) || numel(V.labels) ~= 5 || numel(unique(colOrder)) ~= 5
        error('Expected Across, Within, Feedforward, Feedback and Ambiguous categories.');
    end
    dirs = double(V.meta.dirValues(:)');
    if numel(dirs) ~= 2 || any(~isfinite(dirs)) || numel(unique(dirs)) ~= 2
        error('Expected two distinct stimulus directions.');
    end
    validateattributes(V.meta.DSL_threshold,{'numeric'},{'scalar','finite'});
    rec = struct();
    rec.session_dir = sessionDir;
    [parent,name] = fileparts(sessionDir);
    [~,parentName] = fileparts(parent);
    rec.session_name = [parentName '/' name];
    rec.summary_file = summaryFile;
    rec.direction_values = dirs;
    rec.condition_labels = cfg.condition_labels;
    rec.DSL_threshold = double(V.meta.DSL_threshold);
    rec.condition_ids = nan(8,2);
    rec.bestmodel_files = cell(8,2);
    rec.group = struct([]);
    for g = 1:ng
        requireFieldsLocal(V.group(g),{cfg.source_field},'SummaryVariance.group');
        G = V.group(g).(cfg.source_field);
        requireFieldsLocal(G,{'stim_dir'},'SummaryVariance selected filter');
        if numel(G.stim_dir) ~= 2
            error('Each group must have exactly two stim_dir entries.');
        end
        B = emptyVarianceBlockLocal('all_neurons','All neurons (including invalid)');
        for d = 1:2
            A = G.stim_dir(d);
            requireFieldsLocal(A,{'conditionIds','n_neurons','raw_mean','raw_sum', ...
                'percent_shared','percent_total','percent_latents','counts', ...
                'nLatents','shared_mean','total_mean'},'SummaryVariance stim_dir');
            ids = reshape(double(A.conditionIds),[],1);
            if numel(ids) ~= 8 || any(~isfinite(ids) | ids<1 | ids~=round(ids))
                error('Every direction must contain eight valid condition IDs.');
            end
            ids = ids(rowOrder);
            if g == 1
                rec.condition_ids(:,d) = ids;
            elseif ~isequal(rec.condition_ids(:,d),ids)
                error('Condition IDs differ between model groups.');
            end
            cols6 = [colOrder,6];
            fields6 = {'raw_mean','raw_sum','percent_total'};
            fields5 = {'percent_shared','percent_latents','counts'};
            for k = 1:numel(fields6)
                x = double(A.(fields6{k}));
                assertSizeLocal(x,[8 6],fields6{k});
                B.(fields6{k})(:,:,d) = x(rowOrder,cols6);
            end
            for k = 1:numel(fields5)
                x = double(A.(fields5{k}));
                assertSizeLocal(x,[8 5],fields5{k});
                B.(fields5{k})(:,:,d) = x(rowOrder,colOrder);
            end
            fields1 = {'n_neurons','nLatents','shared_mean','total_mean'};
            for k = 1:numel(fields1)
                x = double(A.(fields1{k})(:));
                assertSizeLocal(x,[8 1],fields1{k});
                B.(fields1{k})(:,d) = x(rowOrder);
            end
            B.shared_sum(:,d) = sum(B.raw_sum(:,1:2,d),2);
            B.total_sum(:,d) = B.shared_sum(:,d)+B.raw_sum(:,6,d);
            validateSavedBlockLocal(B,d);
        end
        if any(B.n_neurons(:) ~= B.n_neurons(1))
            error('Model neuron count changes across conditions within group %d.',g);
        end
        rec.group(g).name = cfg.group_names{g};
        rec.group(g).population = B;
    end
    if numel(unique(rec.condition_ids(:))) ~= 16
        error('Expected 16 distinct direction-condition IDs.');
    end
    rec.population_names = {'all_neurons'};
    rec.population_labels = {'All neurons (including invalid)'};
    if ~needClasses
        return;
    end

    [gplGroups,gplFiles] = loadGplGroupsByModelIndexLocal( ...
        sessionDir,cfg.gpl_mat_name,ng);
    original = S.AllConditionResults;
    if ~isstruct(original) || ~isfield(original,'condition')
        error('AllConditionResults lacks per-condition metadata.');
    end
    originalIds = [original.condition];
    if numel(unique(originalIds)) ~= numel(originalIds)
        error('Duplicate condition entries in AllConditionResults.');
    end
    for g = 1:ng
        rec.group(g).all_neurons = rec.group(g).population;
        blocks = repmat(emptyVarianceBlockLocal('',''),1,3);
        for c = 1:3
            blocks(c).name = cfg.class_names{c};
            blocks(c).label = cfg.class_labels{c};
        end
        rec.group(g).population = blocks;
    end
    rec.population_names = cfg.class_names;
    rec.population_labels = cfg.class_labels;
    for d = 1:2
        for p = 1:8
            id = rec.condition_ids(p,d);
            ci = find(originalIds == id);
            if numel(ci) ~= 1
                error('Missing condition %d in AllConditionResults.',id);
            end
            st = original(ci).Stats;
            requireFieldsLocal(st,{'meta','group','classification'},'Stats');
            requireFieldsLocal(st.meta,{'condition_id','xDim_across','xDim_within'},'Stats.meta');
            if st.meta.condition_id ~= id || numel(st.group) ~= ng
                error('Stats metadata does not match condition %d.',id);
            end
            modelFile = resolveBestmodelLocal(sessionDir,cfg,id,original(ci));
            rec.bestmodel_files{p,d} = modelFile;
            A = load(modelFile,'varexp_raw','independent_noise_var');
            requireFieldsLocal(A,{'varexp_raw','independent_noise_var'},modelFile);
            raw = A.varexp_raw;
            noise = A.independent_noise_var;
            requireFieldsLocal(raw,{'meta','by_neuron','unit_ids_by_group'},'varexp_raw');
            requireFieldsLocal(noise,{'by_neuron','unit_ids_by_group'},'independent_noise_var');
            requireFieldsLocal(raw.meta,{'condition_id','data_content','runIdx', ...
                'xDim_across','xDim_within'},'varexp_raw.meta');
            if raw.meta.condition_id ~= id || raw.meta.runIdx ~= cfg.runIdx || ...
                    ~strcmp(char(raw.meta.data_content),cfg.data_content)
                error('Variance metadata mismatch in %s.',modelFile);
            end
            if ~isequal(raw.meta.xDim_across,st.meta.xDim_across) || ...
                    ~isequal(raw.meta.xDim_within(:),st.meta.xDim_within(:)) || ...
                    numel(raw.by_neuron) ~= ng || numel(noise.by_neuron) ~= ng
                error('Latent/group dimensions disagree with saved category results.');
            end
            for g = 1:ng
                X = double(raw.by_neuron{g});
                R = double(noise.by_neuron{g}(:));
                ids = double(raw.unit_ids_by_group{g}(:));
                requireFieldsLocal(st.group(g),{'unit_ids','DSL_keep_mask'},'Stats.group');
                localDim = st.meta.xDim_across+st.meta.xDim_within(g);
                assertSizeLocal(X,[numel(ids),localDim],'varexp_raw.by_neuron');
                if numel(R) ~= numel(ids) || any(~isfinite(X(:)) | X(:)<0) || ...
                        any(~isfinite(R) | R<0) || isempty(ids) || ...
                        numel(unique(ids)) ~= numel(ids) || any(~isfinite(ids))
                    error('Invalid per-neuron variance, noise or IDs in %s.',modelFile);
                end
                if ~isequal(ids,double(st.group(g).unit_ids(:))) || ...
                        ~isequal(ids,double(noise.unit_ids_by_group{g}(:)))
                    error('Variance/noise/category unit IDs or ordering disagree.');
                end
                if p == 1 && d == 1
                    info = validateAndExtractClassesLocal(gplGroups{g},ids, ...
                        cfg.group_display_names{g},gplFiles{g});
                    rec.group(g).class_info = info;
                    rec.group(g).gpl_file = gplFiles{g};
                    for c = 1:3
                        if ~any(info.(cfg.class_names{c}))
                            warning('%s / %s has no %s neurons; its class values will be NaN.', ...
                                rec.session_name,cfg.group_names{g},cfg.class_names{c});
                        end
                    end
                elseif ~isequal(ids,rec.group(g).class_info.unit_ids)
                    error('Neuron IDs/order change across conditions in group %d.',g);
                end
                masks = varianceCategoryMasksLocal(localDim,st.meta.xDim_across,st.classification);
                if strcmp(cfg.source_field,'all')
                    keep = true(1,localDim);
                else
                    keep = reshape(st.group(g).DSL_keep_mask,1,[]);
                    if numel(keep) ~= localDim || any(~ismember(double(keep),[0 1]))
                        error('Invalid saved DSL_keep_mask.');
                    end
                    keep = logical(keep);
                end
                % Compare with the already-saved whole-population result before
                % using this model's rows for P/C/U calculations.
                full = summarizeRowsLocal(X,R,true(numel(ids),1),keep,masks);
                baseline = rec.group(g).all_neurons;
                if numel(ids) ~= baseline.n_neurons(p,d)
                    error('Bestmodel and saved summary neuron counts differ.');
                end
                fields = {'raw_mean','raw_sum','percent_shared','percent_total', ...
                    'counts','percent_latents'};
                for f = 1:numel(fields)
                    expected = baseline.(fields{f})(p,:,d);
                    assertNearLocal(full.(fields{f}),expected, ...
                        ['bestmodel versus SummaryVariance: ' fields{f}]);
                end
                for c = 1:3
                    info = rec.group(g).class_info;
                    one = summarizeRowsLocal(X,R,info.(cfg.class_names{c}),keep,masks);
                    rec.group(g).population(c) = putSummaryRowLocal( ...
                        rec.group(g).population(c),one,p,d);
                end
            end
        end
    end
end

function B = emptyVarianceBlockLocal(name,label)
    B = struct('name',name,'label',label, ...
        'raw_mean',nan(8,6,2),'raw_sum',nan(8,6,2), ...
        'percent_shared',nan(8,5,2),'percent_total',nan(8,6,2), ...
        'percent_latents',nan(8,5,2),'counts',nan(8,5,2), ...
        'n_neurons',nan(8,2),'nLatents',nan(8,2), ...
        'shared_mean',nan(8,2),'shared_sum',nan(8,2), ...
        'total_mean',nan(8,2),'total_sum',nan(8,2));
end

function B = putSummaryRowLocal(B,A,p,d)
    vectors = {'raw_mean','raw_sum','percent_shared','percent_total','percent_latents','counts'};
    scalars = {'n_neurons','nLatents','shared_mean','shared_sum','total_mean','total_sum'};
    for k = 1:numel(vectors)
        B.(vectors{k})(p,:,d) = A.(vectors{k});
    end
    for k = 1:numel(scalars)
        B.(scalars{k})(p,d) = A.(scalars{k});
    end
end

function A = summarizeRowsLocal(X,R,rows,keep,masks)
% Sum over latents; average over selected neurons only. Percentages are
% ratios of aggregated variances, never averages of neuron percentages.
    rows = logical(rows(:));
    N = nnz(rows);
    counts = zeros(1,5);
    for k = 1:5
        counts(k) = nnz(keep & masks{k});
    end
    A = struct('raw_mean',nan(1,6),'raw_sum',nan(1,6), ...
        'percent_shared',nan(1,5),'percent_total',nan(1,6), ...
        'percent_latents',zeros(1,5),'counts',counts, ...
        'n_neurons',N,'nLatents',nnz(keep),'shared_mean',NaN, ...
        'shared_sum',NaN,'total_mean',NaN,'total_sum',NaN);
    if any(keep)
        A.percent_latents = 100*counts/nnz(keep);
    end
    if N == 0
        return; % an absent cell class is missing, not zero variance
    end
    byLatent = sum(X(rows,:),1);
    for k = 1:5
        A.raw_sum(k) = sum(byLatent(keep & masks{k}));
    end
    A.raw_sum(6) = sum(R(rows));
    A.shared_sum = sum(byLatent(keep));
    A.total_sum = A.shared_sum+A.raw_sum(6);
    A.raw_mean = A.raw_sum/N;
    A.shared_mean = A.shared_sum/N;
    A.total_mean = A.total_sum/N;
    if A.shared_sum > 0
        A.percent_shared = 100*A.raw_mean(1:5)/A.shared_mean;
        assertNearLocal(A.percent_shared,100*A.raw_sum(1:5)/A.shared_sum, ...
            'shared percentage: means versus sums');
    end
    if A.total_sum > 0
        A.percent_total = 100*A.raw_mean/A.total_mean;
        assertNearLocal(A.percent_total,100*A.raw_sum/A.total_sum, ...
            'total percentage: means versus sums');
    end
    assertNearLocal(A.raw_sum(1)+A.raw_sum(2),A.shared_sum,'Across + Within');
    assertNearLocal(sum(A.raw_sum(3:5)),A.raw_sum(1),'FF + FB + Ambiguous');
end

function masks = varianceCategoryMasksLocal(L,a,C)
    requireFieldsLocal(C,{'acrossIdx','feedforwardIdx','feedbackIdx','ambiguousIdx'}, ...
        'Stats.classification');
    if ~isscalar(a) || a<0 || a~=round(a) || L<a
        error('Invalid across/within latent dimensions.');
    end
    masks = repmat({false(1,L)},1,5);
    masks{1}(1:a) = true;
    masks{2}(a+1:L) = true;
    fields = {'feedforwardIdx','feedbackIdx','ambiguousIdx'};
    for k = 1:3
        idx = double(C.(fields{k})(:));
        if any(~isfinite(idx) | idx<1 | idx>a | idx~=round(idx)) || ...
                numel(unique(idx)) ~= numel(idx)
            error('Invalid %s in Stats.classification.',fields{k});
        end
        masks{k+2}(idx) = true;
    end
    if ~isequal(sort(double(C.acrossIdx(:))),reshape(1:a,[],1)) || ...
            any(double(masks{3})+double(masks{4})+double(masks{5}) ~= double(masks{1}))
        error('FF/FB/Ambiguous must partition the across latents exactly.');
    end
end

function validateSavedBlockLocal(B,d)
    n = B.n_neurons(:,d);
    if any(~isfinite(n) | n<1 | n~=round(n))
        error('Saved model neuron counts must be positive integers.');
    end
    x = B.raw_mean(:,:,d);
    sx = B.raw_sum(:,:,d);
    if any(~isfinite(x(:)) | x(:)<0) || any(~isfinite(sx(:)) | sx(:)<0)
        error('Saved raw variances must be finite and nonnegative.');
    end
    assertNearLocal(x,bsxfun(@rdivide,sx,n),'Saved mean versus sum / N');
    assertNearLocal(sum(x(:,1:2),2),B.shared_mean(:,d),'Saved shared denominator');
    assertNearLocal(sum(x(:,[1 2 6]),2),B.total_mean(:,d),'Saved total denominator');
    assertNearLocal(sum(x(:,3:5),2),x(:,1),'Saved FF/FB/Ambiguous partition');
    for p = 1:8
        expectedShared = nan(1,5);
        expectedTotal = nan(1,6);
        if B.shared_mean(p,d)>0
            expectedShared = 100*x(p,1:5)/B.shared_mean(p,d);
        end
        if B.total_mean(p,d)>0
            expectedTotal = 100*x(p,:)/B.total_mean(p,d);
        end
        assertNearLocal(B.percent_shared(p,:,d),expectedShared,'Saved shared percentages');
        assertNearLocal(B.percent_total(p,:,d),expectedTotal,'Saved total percentages');
        counts = B.counts(p,:,d);
        nLat = B.nLatents(p,d);
        if ~isfinite(nLat) || nLat<0 || nLat~=round(nLat) || ...
                any(~isfinite(counts) | counts<0 | counts~=round(counts)) || ...
                sum(counts(1:2))~=nLat || sum(counts(3:5))~=counts(1)
            error('Saved latent category counts do not partition correctly.');
        end
        expectedCounts = zeros(1,5);
        if nLat>0
            expectedCounts = 100*counts/nLat;
        end
        assertNearLocal(B.percent_latents(p,:,d),expectedCounts,'Saved latent percentages');
    end
end

function filename = resolveBestmodelLocal(sessionDir,cfg,id,entry)
    folder = fullfile(sessionDir,sprintf('FA_Dlag_%s_condition%d',cfg.data_content,id), ...
        'mat_results',sprintf('run%03d',cfg.runIdx));
    % Relocate the saved basename to this session, so moved sessions remain usable.
    if isfield(entry,'bestmodel_file') && ~isempty(entry.bestmodel_file)
        oldPath = strrep(char(entry.bestmodel_file),'\',filesep);
        [~,base,ext] = fileparts(oldPath);
        candidate = fullfile(folder,[base ext]);
        if isfile(candidate)
            filename = candidate;
            return;
        end
    end
    listing = dir(folder);
    listing = listing(~[listing.isdir]);
    keep = false(size(listing));
    for k = 1:numel(listing)
        [~,base,ext] = fileparts(listing(k).name);
        keep(k) = contains(lower(base),'bestmodel') && ...
            (strcmpi(ext,'.mat') || isempty(ext));
    end
    listing = listing(keep);
    if numel(listing) ~= 1
        error('Expected one bestmodel MAT in %s; found %d.',folder,numel(listing));
    end
    filename = fullfile(folder,listing(1).name);
end

function info = observationInfoLocal(records)
    info = struct('session_index',{},'direction_index',{},'direction_value',{}, ...
        'session_name',{},'session_dir',{},'summary_file',{});
    for s = 1:numel(records)
        for d = 1:2
            k = 2*(s-1)+d;
            info(k).session_index = s;
            info(k).direction_index = d;
            info(k).direction_value = records{s}.direction_values(d);
            info(k).session_name = records{s}.session_name;
            info(k).session_dir = records{s}.session_dir;
            info(k).summary_file = records{s}.summary_file;
        end
    end
end

function tag = filterTagLocal(cfg,records)
    if strcmp(cfg.source_field,'all')
        tag = 'all';
    else
        tag = ['dsl' strrep(sprintf('%.12g',records{1}.DSL_threshold),'.','p')];
    end
end

function ensureOutputDirLocal(folder)
    if ~isfolder(folder)
        [ok,msg] = mkdir(folder);
        if ~ok
            error('Cannot create output directory %s: %s',folder,msg);
        end
    end
end

function saveFigureLocal(fig,folder,base,cfg)
    if cfg.save_fig
        savefig(fig,fullfile(folder,[base '.fig']));
    end
    if cfg.save_png
        exportgraphics(fig,fullfile(folder,[base '.png']),'Resolution',cfg.png_dpi);
    end
    if cfg.save_svg
        % print -dsvg also supports MATLAB releases where exportgraphics
        % does not accept SVG. Short names avoid very long Windows paths.
        set(fig,'Renderer','painters','PaperPositionMode','auto');
        print(fig,fullfile(folder,[base '.svg']),'-dsvg','-painters');
    end
    if cfg.close_after_save && (cfg.save_fig || cfg.save_png || cfg.save_svg)
        close(fig);
    end
end

function drawDistributionLocal(ax,x,y,color,cfg,widthScale,seed)
    drawSummaryWithPoints(ax,x,y,cfg.plot_style, ...
        cfg.violin_width*widthScale,cfg.bar_width*widthScale,color, ...
        cfg.point_size,cfg.point_alpha,cfg.violin_alpha,cfg.bar_alpha, ...
        cfg.point_jitter_width*widthScale,cfg.show_mean,cfg.show_median, ...
        cfg.mean_marker_size,cfg.median_marker_size,cfg.median_line_width,seed);
end

function addConditionLegendLocal(ax,cfg)
    h = gobjects(1,8);
    for p = 1:8
        h(p) = plot(ax,nan,nan,'o','MarkerFaceColor',cfg.condition_colors(p,:), ...
            'MarkerEdgeColor','none','LineStyle','none','MarkerSize',7);
    end
    leg = legend(ax,h,cfg.condition_labels,'Location','southoutside', ...
        'Orientation','horizontal','Interpreter','none');
    leg.NumColumns = 4;
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

function assertNearLocal(a,b,context)
    if ~isequal(size(a),size(b))
        error('%s: inconsistent array dimensions.',context);
    end
    missing = isnan(a) & isnan(b);
    scale = max(1,max(abs(a),abs(b)));
    bad = ~missing & (~isfinite(a) | ~isfinite(b) | abs(a-b)>1e-7*scale);
    if any(bad(:))
        error('%s: numerical consistency check failed.',context);
    end
end

function tag = safeTagLocal(value)
    tag = regexprep(strtrim(char(value)),'[^A-Za-z0-9_-]+','_');
    if isempty(tag)
        tag = 'unnamed';
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


function drawSummaryWithPoints(ax, x0, y, plot_style, violin_width, ...
        bar_width, color, point_size, point_alpha, violin_alpha, ...
        bar_alpha, point_jitter_width, show_mean, show_median, ...
        mean_marker_size, median_marker_size, median_line_width, jitter_seed)

    y = double(y(:));
    y = y(isfinite(y));

    if isempty(y)
        return;
    end

    meanVal = mean(y);
    medianVal = median(y);

    switch plot_style
        case 'bar_points'
            if show_mean
                hb = bar(ax, x0, meanVal, bar_width, ...
                    'FaceColor', color, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');

                try
                    hb.FaceAlpha = bar_alpha;
                catch
                    % FaceAlpha is unavailable for bars in older releases.
                end
            end

            point_edge_color = 'k';

        case 'violin'
            if numel(y) >= 2 && range(y) > eps
                [dens, yi] = estimateDensity(y);

                if ~isempty(dens) && max(dens) > 0
                    dens = dens ./ max(dens) .* violin_width;

                    patch(ax, ...
                        [x0 - dens, fliplr(x0 + dens)], ...
                        [yi, fliplr(yi)], color, ...
                        'FaceAlpha', violin_alpha, ...
                        'EdgeColor', color, ...
                        'LineWidth', 0.9, ...
                        'HandleVisibility', 'off');
                end
            end

            point_edge_color = 'none';

        case 'points_median'
            % No bar or density object.
            point_edge_color = 'none';

        otherwise
            error('Unknown plot_style: %s', plot_style);
    end

    jitter = deterministicJitterLocal( ...
        numel(y), point_jitter_width, jitter_seed);

    scatter(ax, x0 + jitter, y, point_size, ...
        'MarkerFaceColor', color, ...
        'MarkerEdgeColor', point_edge_color, ...
        'MarkerFaceAlpha', point_alpha, ...
        'MarkerEdgeAlpha', point_alpha, ...
        'HandleVisibility', 'off');

    if show_mean && ~strcmp(plot_style, 'bar_points')
        plot(ax, x0, meanVal, 'kd', ...
            'MarkerSize', mean_marker_size, ...
            'MarkerFaceColor', 'k', ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end

    if show_median
        if strcmp(plot_style, 'bar_points')
            plot(ax, x0, medianVal, 'ks', ...
                'MarkerSize', median_marker_size, ...
                'MarkerFaceColor', 'k', ...
                'LineWidth', 0.8, ...
                'HandleVisibility', 'off');
        else
            median_half_width = violin_width .* 0.72;
            plot(ax, ...
                [x0 - median_half_width, x0 + median_half_width], ...
                [medianVal, medianVal], '-', ...
                'Color', color, ...
                'LineWidth', median_line_width, ...
                'HandleVisibility', 'off');
        end
    end
end

function jitter = deterministicJitterLocal(n, half_width, seed)

    if n <= 1 || half_width <= 0
        jitter = zeros(n, 1);
        return;
    end

    stream = RandStream('mt19937ar', 'Seed', seed);
    jitter = (2 .* rand(stream, n, 1) - 1) .* half_width;
end

function [dens, yi] = estimateDensity(y)
    y = y(:)';

    if numel(y) < 2 || range(y) <= eps
        dens = [];
        yi = [];
        return;
    end

    if exist('ksdensity', 'file') == 2
        try
            [dens, yi] = ksdensity(y, 'NumPoints', 80);
            dens = dens(:)';
            yi = yi(:)';
            return;
        catch
        end
    end

    % Fallback without Statistics Toolbox.
    nBins = min(20, max(6, round(sqrt(numel(y)) * 2)));
    edges = linspace(min(y), max(y), nBins + 1);
    counts = histcounts(y, edges);
    centers = (edges(1:end-1) + edges(2:end)) / 2;

    if numel(counts) >= 3
        kernel = [1 2 3 2 1];
        kernel = kernel / sum(kernel);
        counts = conv(counts, kernel, 'same');
    end

    yi = linspace(min(y), max(y), 80);
    dens = interp1(centers, counts, yi, 'linear', 0);
end

function yMax = computeFlexibleYMax(values)
    values = values(isfinite(values));

    if isempty(values)
        yMax = 1;
        return;
    end

    maxVal = max(values);

    if maxVal <= 0
        yMax = 1;
    elseif maxVal <= 0.5
        yMax = 0.6;
    elseif maxVal <= 1
        yMax = 1.2;
    elseif maxVal <= 2
        yMax = 2.4;
    elseif maxVal <= 5
        yMax = 6;
    elseif maxVal <= 10
        yMax = 12;
    elseif maxVal <= 20
        yMax = 24;
    elseif maxVal <= 40
        yMax = 45;
    elseif maxVal <= 60
        yMax = 66;
    elseif maxVal <= 80
        yMax = 88;
    elseif maxVal <= 100
        yMax = 105;
    else
        yMax = maxVal * 1.08;
    end
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



function cfg = normalizeVarianceSourceLocal(cfg)
    cfg.variance_source = lower(strtrim(char(cfg.variance_source)));
    if ~ismember(cfg.variance_source,{'model','posterior'})
        error('variance_source must be model or posterior.');
    end
    v = cfg.uncertainty_included;
    if ~(islogical(v) || isnumeric(v)) || ~isscalar(v) || ~ismember(double(v),[0 1])
        error('uncertainty_included must be 0 or 1.');
    end
    cfg.uncertainty_included = logical(v);
    cfg.uncertainty_included_effective = false;
    cfg.source_tag = 'model';
    cfg.variance_description = 'Model variance per neuron';
    cfg.delta_y_label = 'Difference in model variance per neuron';
    if strcmp(cfg.variance_source,'posterior')
        if ~strcmp(cfg.DSL_filter,'all_latents')
            error(['Posterior results use saved unfiltered reconstructions. ', ...
                'Set DSL_filter = ''all_latents'' for variance_source = ''posterior''.']);
        end
        cfg.uncertainty_included_effective = cfg.uncertainty_included;
        cfg.source_tag = sprintf('post_u%d',cfg.uncertainty_included);
        if cfg.uncertainty_included
            cfg.variance_description = 'Posterior expected trial variance per neuron';
        else
            cfg.variance_description = 'Posterior-mean trial variance per neuron';
        end
        cfg.delta_y_label = ['Difference in ' lower(cfg.variance_description)];
    end
end

function rec = readPosteriorSessionLocal(sessionDir,cfg,needClasses)
    summaryFile = fullfile(sessionDir,'each_condition_mode','posterior_rawvar', ...
        sprintf('postVar_%s_r%03d_u%d.mat',cfg.data_content,cfg.runIdx,cfg.uncertainty_included));
    if ~isfile(summaryFile)
        error(['Missing %s. Run posterior_rawvar_each_condition_mode.m in this ', ...
            'session with the matching uncertainty_included setting.'],summaryFile);
    end
    S = load(summaryFile,'PosteriorRawVar');
    requireFieldsLocal(S,{'PosteriorRawVar'},summaryFile);
    P = S.PosteriorRawVar;
    requireFieldsLocal(P,{'format_version','meta','labels','condition_ids','condition','group'},summaryFile);
    if ~strcmp(P.format_version,'posterior_rawvar_eachcond_v1')
        error('Unsupported PosteriorRawVar format in %s.',summaryFile);
    end
    requireFieldsLocal(P.meta,{'data_content','runIdx','uncertainty_included', ...
        'variance_source','DSL_filter','variance_method','variance_normalization', ...
        'conditionShortLabels','dirValues'},'PosteriorRawVar.meta');
    if ~strcmp(char(P.meta.data_content),cfg.data_content) || P.meta.runIdx ~= cfg.runIdx || ...
            ~isequal(double(P.meta.uncertainty_included),double(cfg.uncertainty_included)) || ...
            ~strcmp(P.meta.variance_source,'posterior') || ~strcmp(P.meta.DSL_filter,'all_latents')
        error('Posterior data_content/runIdx/source/uncertainty/DSL metadata mismatch.');
    end
    if ~strcmp(P.meta.variance_method,'across_trials_per_bin_mean_over_bins') || ...
            ~strcmp(P.meta.variance_normalization,'M-1')
        error('Posterior summary must use M-1 across trials per bin, then mean over bins.');
    end
    ng = numel(cfg.group_names);
    if numel(P.group) ~= ng
        error('Posterior model group count disagrees with group_names.');
    end
    if ~isequal(cellstr(string(P.labels(:)')),cfg.latent_labels) || ...
            ~isequal(cellstr(string(P.meta.conditionShortLabels(:)')),cfg.condition_labels)
        error('Posterior category/condition ordering disagrees with the required ordering.');
    end
    assertSizeLocal(P.condition_ids,[8 2],'posterior condition_ids');
    idsAll = double(P.condition_ids(:));
    if any(~isfinite(idsAll) | idsAll<1 | idsAll~=round(idsAll)) || numel(unique(idsAll)) ~= 16
        error('All eight conditions in both directions are required; no incomplete pooled averages.');
    end
    dirs = double(P.meta.dirValues(:)');
    if numel(dirs) ~= 2 || any(~isfinite(dirs)) || numel(unique(dirs)) ~= 2
        error('Expected two distinct posterior direction values.');
    end
    conditionIds = [P.condition.condition_id];
    if numel(conditionIds) ~= 16 || numel(unique(conditionIds)) ~= 16 || ...
            ~isequal(sort(conditionIds(:)),sort(idsAll))
        error('Posterior per-condition entries disagree with condition_ids.');
    end
    rec = struct();
    rec.session_dir = sessionDir;
    [parent,name] = fileparts(sessionDir); [~,parentName] = fileparts(parent);
    rec.session_name = [parentName '/' name];
    rec.summary_file = summaryFile; rec.direction_values = dirs;
    rec.condition_labels = cfg.condition_labels; rec.DSL_threshold = NaN;
    rec.variance_source = 'posterior'; rec.uncertainty_included = cfg.uncertainty_included;
    rec.variance_method = P.meta.variance_method;
    rec.variance_normalization = P.meta.variance_normalization;
    rec.condition_ids = P.condition_ids;
    rec.bestmodel_files = cell(8,2); rec.group = struct([]);
    if needClasses
        [gplGroups,gplFiles] = loadGplGroupsByModelIndexLocal(sessionDir,cfg.gpl_mat_name,ng);
        rec.population_names = cfg.class_names; rec.population_labels = cfg.class_labels;
    else
        rec.population_names = {'all_neurons'};
        rec.population_labels = {'All neurons (including invalid)'};
    end
    for g = 1:ng
        if ~isfield(P.group(g),'stim_dir') || numel(P.group(g).stim_dir) ~= 2
            error('Posterior group %d must contain two stim_dir summaries.',g);
        end
        baseline = emptyPosteriorBlockLocal('all_neurons','All neurons (including invalid)');
        for d = 1:2
            A = P.group(g).stim_dir(d);
            requireFieldsLocal(A,{'conditionIds','raw_mean','raw_sum','reconstruction_mean', ...
                'reconstruction_sum','uncertainty_mean','uncertainty_sum','counts', ...
                'percent_latents','available','n_neurons','nLatents','n_trials','n_bins'}, ...
                'PosteriorRawVar stim_dir');
            if ~isequal(double(A.conditionIds(:)),double(P.condition_ids(:,d)))
                error('Posterior direction summary condition IDs disagree.');
            end
            vectors = {'raw_mean','raw_sum','reconstruction_mean','reconstruction_sum', ...
                'uncertainty_mean','uncertainty_sum','counts','percent_latents','available'};
            for f = 1:numel(vectors)
                name = vectors{f}; assertSizeLocal(A.(name),[8 5],['posterior ' name]);
                baseline.(name)(:,:,d) = A.(name);
            end
            for f = {'n_neurons','nLatents','n_trials','n_bins'}
                name = f{1}; assertSizeLocal(A.(name),[8 1],['posterior ' name]);
                baseline.(name)(:,d) = A.(name);
            end
            validatePosteriorBlockLocal(baseline,d,cfg);
        end
        rec.group(g).all_neurons = baseline;
        if needClasses
            for c = 1:3
                rec.group(g).population(c) = emptyPosteriorBlockLocal(cfg.class_names{c},cfg.class_labels{c});
            end
        else
            rec.group(g).population = baseline;
        end
    end
    for d = 1:2
        for p = 1:8
            entry = P.condition(conditionIds == P.condition_ids(p,d));
            if entry.feature_index ~= p || entry.direction_index ~= d || ...
                    entry.direction_value ~= dirs(d) || numel(entry.group) ~= ng
                error('Posterior condition position/group metadata mismatch.');
            end
            rec.bestmodel_files{p,d} = entry.bestmodel_file; % provenance, no model reload
            for g = 1:ng
                A = entry.group(g);
                ids = double(A.unit_ids(:)); N = numel(ids);
                if N<1 || any(~isfinite(ids)) || numel(unique(ids)) ~= N || A.n_neurons ~= N
                    error('Invalid posterior unit IDs/count in group %d.',g);
                end
                if p == 1 && d == 1
                    rec.group(g).unit_ids = ids;
                    if needClasses
                        info = validateAndExtractClassesLocal(gplGroups{g},ids,cfg.group_display_names{g},gplFiles{g});
                        rec.group(g).class_info = info; rec.group(g).gpl_file = gplFiles{g};
                        for c = 1:3
                            if ~any(info.(cfg.class_names{c}))
                                warning('%s / %s has no %s neurons; class values are NaN.', ...
                                    rec.session_name,cfg.group_names{g},cfg.class_names{c});
                            end
                        end
                    end
                elseif ~isequal(ids,rec.group(g).unit_ids)
                    error('Posterior neuron IDs/order change across conditions in group %d.',g);
                end
                base = rec.group(g).all_neurons;
                if N ~= base.n_neurons(p,d) || entry.n_trials ~= base.n_trials(p,d) || ...
                        entry.n_bins ~= base.n_bins(p,d)
                    error('Posterior condition counts disagree with the saved session summary.');
                end
                assertNearLocal(double(A.counts),double(base.counts(p,:,d)),'posterior latent counts');
                assertNearLocal(double(A.available),double(base.available(p,:,d)),'posterior availability');
                if needClasses
                    for f = {'raw_var','reconstruction_var','uncertainty_var'}
                        assertSizeLocal(A.(f{1}),[N 5],['posterior ' f{1}]);
                    end
                    full = posteriorRowsLocal(A,true(N,1));
                    for f = {'raw_sum','raw_mean','reconstruction_sum','reconstruction_mean', ...
                            'uncertainty_sum','uncertainty_mean'}
                        name = f{1};
                        assertNearLocal(full.(name),base.(name)(p,:,d),['posterior neuron versus summary ' name]);
                    end
                    for c = 1:3
                        rows = rec.group(g).class_info.(cfg.class_names{c});
                        classResult = posteriorRowsLocal(A,rows);
                        classResult.n_trials = entry.n_trials; classResult.n_bins = entry.n_bins;
                        rec.group(g).population(c) = putPosteriorRowLocal( ...
                            rec.group(g).population(c),classResult,p,d);
                    end
                end
            end
        end
    end
    for g = 1:ng
        if any(~rec.group(g).all_neurons.available(:,5,:),'all')
            warning('posterior_rawvar:MissingAmbiguous', ...
                '%s / %s: some Ambiguous reconstructions are missing; their values remain NaN.', ...
                rec.session_name,cfg.group_names{g});
        end
    end
end

function B = emptyPosteriorBlockLocal(name,label)
    B = struct('name',name,'label',label,'raw_mean',nan(8,5,2),'raw_sum',nan(8,5,2), ...
        'reconstruction_mean',nan(8,5,2),'reconstruction_sum',nan(8,5,2), ...
        'uncertainty_mean',nan(8,5,2),'uncertainty_sum',nan(8,5,2), ...
        'percent_latents',nan(8,5,2),'counts',nan(8,5,2),'available',false(8,5,2), ...
        'n_neurons',nan(8,2),'nLatents',nan(8,2),'n_trials',nan(8,2),'n_bins',nan(8,2));
end

function A = posteriorRowsLocal(G,rows)
    N = nnz(rows);
    A = struct('n_neurons',N,'nLatents',G.nLatents,'counts',G.counts, ...
        'percent_latents',G.percent_latents,'available',G.available);
    for f = {'raw','reconstruction','uncertainty'}
        name = f{1};
        if N == 0
            A.([name '_sum']) = nan(1,5); A.([name '_mean']) = nan(1,5);
        else
            % Average neuron VARIANCES, never variance of an averaged trace.
            % NaN categories remain NaN; no omission or renormalization.
            A.([name '_sum']) = sum(G.([name '_var'])(rows,:),1);
            A.([name '_mean']) = A.([name '_sum'])/N;
        end
    end
end

function B = putPosteriorRowLocal(B,A,p,d)
    vectors = {'raw_mean','raw_sum','reconstruction_mean','reconstruction_sum', ...
        'uncertainty_mean','uncertainty_sum','counts','percent_latents','available'};
    for f = 1:numel(vectors), B.(vectors{f})(p,:,d) = A.(vectors{f}); end
    for f = {'n_neurons','nLatents','n_trials','n_bins'}
        B.(f{1})(p,d) = A.(f{1});
    end
end

function validatePosteriorBlockLocal(B,d,cfg)
    N = B.n_neurons(:,d); M = B.n_trials(:,d); T = B.n_bins(:,d);
    if any(~isfinite(N) | N<1 | N~=round(N)) || any(~isfinite(M) | M<2 | M~=round(M)) || ...
            any(~isfinite(T) | T<1 | T~=round(T))
        error('Posterior neuron/trial/bin counts are invalid.');
    end
    avail = B.available(:,:,d);
    if any(~ismember(double(avail(:)),[0 1])) || any(~avail(:,1:4),'all')
        error('The four required reconstruction categories must be available.');
    end
    for f = {'raw','reconstruction'}
        name = f{1}; X = B.([name '_mean'])(:,:,d);
        if any(~isfinite(X(avail)) | X(avail)<0) || any(~isnan(X(~avail)))
            error('Posterior %s variance values/availability are inconsistent.',name);
        end
        assertNearLocal(X,bsxfun(@rdivide,B.([name '_sum'])(:,:,d),N),['posterior ' name ' sum/N']);
    end
    U = B.uncertainty_mean(:,:,d);
    if cfg.uncertainty_included
        if any(~isfinite(U(:)) | U(:)<0)
            error('Posterior uncertainty must be finite and nonnegative when enabled.');
        end
        assertNearLocal(U,bsxfun(@rdivide,B.uncertainty_sum(:,:,d),N),'posterior uncertainty sum/N');
        expected = B.reconstruction_mean(:,:,d)+U;
    else
        if any(~isnan(U(:))) || any(~isnan(B.uncertainty_sum(:,:,d)),'all')
            error('Option 0 must mark uncomputed uncertainty as NaN.');
        end
        expected = B.reconstruction_mean(:,:,d);
    end
    assertNearLocal(B.raw_mean(:,:,d),expected,'posterior selected variance');
    counts = B.counts(:,:,d); nLat = B.nLatents(:,d);
    if any(~isfinite(counts(:)) | counts(:)<0 | counts(:)~=round(counts(:))) || ...
            any(~isfinite(nLat) | nLat<0 | nLat~=round(nLat)) || ...
            any(sum(counts(:,1:2),2) ~= nLat) || any(sum(counts(:,3:5),2) ~= counts(:,1))
        error('Posterior latent counts do not partition correctly.');
    end
    percentages = zeros(8,5);
    rows = nLat>0;
    percentages(rows,:) = 100*bsxfun(@rdivide,counts(rows,:),nLat(rows));
    assertNearLocal(B.percent_latents(:,:,d),percentages,'posterior count percentages');
    % Deliberately NO variance-additivity tests: posterior category traces
    % can be correlated, so FF+FB+Ambiguous variances need not equal Across.
end

