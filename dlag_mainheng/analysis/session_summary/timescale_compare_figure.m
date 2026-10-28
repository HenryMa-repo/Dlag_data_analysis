%% timescale_compare_figure.m
% Poster version of sum_sessions_timescale_compare.m.
% Poster typography: Arial 30 pt for axes, session/category labels, condition
% labels and legends. Canvas and panel margins accommodate the larger text.
%
% Run sum_sessions_timescale_compare.m with save_mat = true first. This
% standalone SCRIPT reads its MultiSessionTimescale MAT, not the individual
% session MATs. The saved timescales and latent membership are not changed.
% Plot order: Within, Across, Feedforward (FF), Feedback (FB), Ambiguous.
%
% Within has a separate distribution for each area. Across, FF, FB and
% Ambiguous are shared latents: each appears ONCE, using Group 1's saved
% distribution as in the source program (a warning reports disagreements
% with other groups). Area determines color only for Within; all shared
% latents, stimulus labels, session labels and reference lines are gray.
%
% all_condition_model: one figure; condition_specific_models: one figure
% with one labeled panel per condition. pool_sessions pools individual
% latent timescales without averaging; separate_sessions gives each session
% its own x position. Values > 400 ms appear at 430 ms, with a >400 tick;
% the original values in the source MAT remain unchanged.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';

% Leave empty to construct the exact MAT name used by the source script
% from the settings below; alternatively supply a full MAT file path.
summary_mat_file = '';

data_content = 'demean_count_within_t_and_condition';
runIdx = 1;
model_mode = 'all_condition_model';
% 'all_condition_model' or 'condition_specific_models'
timescale_source = 'model-timescale';
% 'model-timescale' or 'posterior-timescale'
use_dsl_filter = false;
dsl_field = 'logical';
plot_session_mode = 'pool_sessions';
% 'pool_sessions' or 'separate_sessions'

% For automatic filename lookup, follow the group order used by
% sum_sessions_timescale_compare.m. The MAT itself supplies the plot labels.
group_names = {'V1', 'MT'};

figure_visible = 'on';
save_fig = true;
save_svg = true;
save_png = false;
save_meta_mat = false;
png_dpi = 300;
close_after_save = false;

% The ONLY saturated colors in the figure represent areas.
area_colors = [0.0000, 0.4470, 0.7410; ...
               0.8500, 0.3250, 0.0980];
shared_gray =  [0 0 0];
axis_gray = [0 0 0];
guide_gray =[0.3 0.3 0.3];
division_gray = [0.3 0.3 0.3];

point_size = 50;
point_alpha = 1;
point_jitter_width_pool = 0.38;
point_jitter_width_separate = 0.12;

timescale_y_min = 0;
timescale_y_regular_max = 400;
timescale_y_tick_step = 50;
timescale_overflow_y = 430;
timescale_y_top_padding = 15;
timescale_division_lines = []; % [] disables the lines
timescale_division_line_width = 1.0;

font_name = 'Arial';
axis_font_size = 30; % points; axes, labels and legend
panel_font_size = 30; % points; condition labels

%% ============================ READ SUMMARY =============================

if exist(root_dir, 'dir') ~= 7
    error('root_dir does not exist: %s', root_dir);
end
if ~any(strcmp(char(figure_visible), {'on','off'}))
    error('figure_visible must be ''on'' or ''off''.');
end
if ~any(strcmp(char(model_mode), ...
        {'all_condition_model','condition_specific_models'}))
    error('Unknown model_mode: %s', model_mode);
end
if ~any(strcmp(char(plot_session_mode), ...
        {'pool_sessions','separate_sessions'}))
    error('Unknown plot_session_mode: %s', plot_session_mode);
end
if timescale_y_min >= timescale_y_regular_max || ...
        timescale_y_regular_max >= timescale_overflow_y || ...
        timescale_y_tick_step <= 0 || ...
        timescale_y_top_padding < 0
    error('The timescale axis settings must satisfy min < 400 < overflow.');
end
if abs((timescale_y_regular_max-timescale_y_min) / ...
        timescale_y_tick_step - ...
        round((timescale_y_regular_max-timescale_y_min) / ...
        timescale_y_tick_step)) > 1e-10
    error('timescale_y_tick_step must divide the regular axis exactly.');
end
if size(area_colors,2) ~= 3 || any(~isfinite(area_colors(:))) || ...
        any(area_colors(:)<0) || any(area_colors(:)>1)
    error('area_colors must have one valid RGB row per area.');
end

auto_mat_lookup = isempty(summary_mat_file);
if auto_mat_lookup
    summary_mat_file = autoSummaryFileLocal(root_dir, data_content, ...
        model_mode, timescale_source, use_dsl_filter, dsl_field, ...
        plot_session_mode, group_names);
else
    summary_mat_file = char(summary_mat_file);
    if isempty(fileparts(summary_mat_file))
        summary_mat_file = fullfile(root_dir, summary_mat_file);
    end
end
if exist(summary_mat_file, 'file') ~= 2
    error(['Timescale summary MAT not found: %s\nRun ', ...
        'sum_sessions_timescale_compare.m with save_mat = true, or ', ...
        'set summary_mat_file to the saved MAT path.'], summary_mat_file);
end
loaded = load(summary_mat_file, 'MultiSessionTimescale');
if ~isfield(loaded, 'MultiSessionTimescale') || ...
        ~isscalar(loaded.MultiSessionTimescale)
    error('The MAT must contain a scalar MultiSessionTimescale struct.');
end
M = loaded.MultiSessionTimescale;
if ~isfield(M, 'values') || ~iscell(M.values) || ...
        ~isfield(M, 'labels') || ...
        ~isfield(M.labels, 'categories') || ...
        ~isfield(M.labels, 'conditions') || ...
        ~isfield(M.labels, 'sessions') || ...
        ~isfield(M, 'meta') || ...
        ~isfield(M.meta, 'model_mode') || ...
        ~isfield(M.meta, 'plot_session_mode') || ...
        ~isfield(M.meta, 'group_names') || ...
        ~isfield(M.meta, 'output_base')
    error('The MAT is not a complete sum_sessions_timescale_compare output.');
end

category_indices = categoryOrderLocal(M.labels.categories);
category_labels = {'Within','Across','FF','FB','Ambiguous'};
area_names = cellstr(string(M.meta.group_names(:)'));
num_sessions = size(M.values, 1);
num_groups = size(M.values, 2);
if num_sessions < 1 || num_groups ~= 2 || numel(area_names) ~= 2
    error('Expected timescale values for at least one session and two areas.');
end
if auto_mat_lookup && isfield(M.meta,'runIdx') && M.meta.runIdx ~= runIdx
    error(['Saved MAT is from runIdx=%d, but the script specifies %d. ', ...
        'The source output filename does not encode runIdx; rerun the ', ...
        'source summary for the selected run or choose its MAT path.'], ...
        M.meta.runIdx,runIdx);
end
resolved_area_colors = resolveAreaColorsLocal(area_names,area_colors);
if size(M.values, ndims(M.values)) ~= 5
    error('Expected exactly five latent categories in the last value dimension.');
end
if ~any(strcmp(char(M.meta.plot_session_mode), ...
        {'pool_sessions','separate_sessions'}))
    error('Unrecognized plot session mode in summary MAT.');
end
source_model_mode = char(M.meta.model_mode);
switch source_model_mode
    case 'all_condition_model'
        if ndims(M.values) ~= 3 || size(M.values,3) ~= 5
            error('Expected session x group x latent category values.');
        end
        num_conditions = 0;
    case 'condition_specific_models'
        if ndims(M.values) ~= 4 || size(M.values,4) ~= 5
            error('Expected session x group x condition x category values.');
        end
        num_conditions = size(M.values,3);
    otherwise
        error('Unknown model mode in summary MAT: %s', source_model_mode);
end
condition_labels = cellstr(string(M.labels.conditions(:)'));
if num_conditions ~= numel(condition_labels)
    error('Condition labels and saved values do not align.');
end
session_labels = cellstr(string(M.labels.sessions(:)'));
if numel(session_labels) ~= num_sessions
    error('Session labels and saved values do not align.');
end

% Shared latent arrays are duplicates across group positions in the
% unfiltered case. Keep the source script's Group 1 rule even if a
% group-specific DSL filter makes the two saved arrays differ.
shared_mismatch_count = countSharedMismatchLocal(M, category_indices);
if shared_mismatch_count > 0
    warning(['%d shared-latent session/condition/category slices differ ', ...
        'between areas. As in the source plot, only Group 1 is displayed ', ...
        'for shared categories; both raw arrays remain in the source MAT.'], ...
        shared_mismatch_count);
end

cfg = struct();
cfg.area_colors = resolved_area_colors;
cfg.area_names = area_names;
cfg.session_labels = session_labels;
cfg.category_indices = category_indices;
cfg.category_labels = category_labels;
cfg.shared_gray = shared_gray;
cfg.axis_gray = axis_gray;
cfg.guide_gray = guide_gray;
cfg.division_gray = division_gray;
cfg.point_size = point_size;
cfg.point_alpha = point_alpha;
cfg.jitter_pool = point_jitter_width_pool;
cfg.jitter_separate = point_jitter_width_separate;
cfg.y_min = timescale_y_min;
cfg.regular_max = timescale_y_regular_max;
cfg.tick_step = timescale_y_tick_step;
cfg.overflow_y = timescale_overflow_y;
cfg.top_padding = timescale_y_top_padding;
cfg.division_lines = timescale_division_lines;
cfg.division_line_width = timescale_division_line_width;
cfg.font_name = font_name;
cfg.axis_font_size = axis_font_size;
cfg.panel_font_size = panel_font_size;
cfg.pool_sessions = strcmp(char(M.meta.plot_session_mode), 'pool_sessions');
cfg.condition_specific = strcmp(source_model_mode, 'condition_specific_models');

%% ============================= POSTER FIGURE ===========================

if cfg.condition_specific
    num_columns = min(2, num_conditions);
    num_rows = ceil(num_conditions/num_columns);
    if cfg.pool_sessions
        panel_width_inches = 14.0;
    else
        panel_width_inches = max(18.0, 1.8*num_sessions+8);
    end
    fig_width_inches = num_columns*panel_width_inches;
    fig_height_inches = max(10.5, num_rows*10.5 + 0.9);
else
    num_columns = 1;
    num_rows = 1;
    if cfg.pool_sessions
        fig_width_inches = 18.0;
        fig_height_inches = 9.5;
    else
        fig_width_inches = max(22.0, 1.8*num_sessions + 12);
        fig_height_inches = 12.0;
    end
end
fig = figure('Visible', figure_visible, 'Color', 'w', ...
    'Units', 'inches', 'Position', ...
    [0.7, 0.7, fig_width_inches, fig_height_inches], ...
    'PaperPositionMode', 'auto', 'InvertHardcopy', 'off', ...
    'Renderer', 'painters', ...
    'Name', 'Timescale comparison (poster)');
first_ax = [];

if cfg.condition_specific
    for p = 1:num_conditions
        row = ceil(p/num_columns);
        col = mod(p-1,num_columns)+1;
        panel_band = 0.84/num_rows;
        left = (col-1)/num_columns + 0.14/num_columns;
        width = 0.78/num_columns;
        bottom = 0.082 + (num_rows-row)*panel_band + ...
            0.26*panel_band;
        height = 0.63*panel_band;
        ax = axes('Parent',fig, 'Units','normalized', ...
            'Position',[left, bottom, width, height]);
        plotOnePanelLocal(ax, M, p, cfg);
        if col == 1
            ylabel(ax,'Timescale (ms)', ...
                'FontName', font_name, 'FontSize', axis_font_size);
        else
            set(ax, 'YTickLabel', []);
        end
        text(ax, 0.015, 1.04, condition_labels{p}, ...
            'Units','normalized','FontName',font_name, ...
            'FontSize',panel_font_size, 'FontWeight','bold', ...
            'Color',axis_gray, 'VerticalAlignment','bottom', ...
            'Interpreter','none', 'Clipping','off');
        if p == 1
            first_ax = ax;
        end
    end
else
    if cfg.pool_sessions
        main_pos = [0.11, 0.19, 0.855, 0.69];
    else
        % Session ticks and the category labels below them need two rows.
        main_pos = [0.11, 0.32, 0.855, 0.56];
    end
    ax = axes('Parent',fig,'Units','normalized', 'Position',main_pos);
    plotOnePanelLocal(ax, M, 0, cfg);
    ylabel(ax,'Timescale (ms)', ...
        'FontName',font_name,'FontSize',axis_font_size);
    first_ax = ax;
end
addAreaLegendLocal(first_ax, cfg.area_names, cfg.area_colors, ...
    font_name, axis_font_size, cfg.condition_specific);

%% ============================= SAVE FIGURE =============================

source_base = char(M.meta.output_base);
if isempty(strfind(source_base,'_sum_timescale_')) %#ok<STREMP>
    output_base = [source_base, '_timescale_compare_figure'];
else
    output_base = strrep(source_base, ...
        '_sum_timescale_', '_timescale_compare_figure_');
end
output_path = fullfile(root_dir, output_base);

TimescaleFigureMeta = struct();
TimescaleFigureMeta.created_by = mfilename;
TimescaleFigureMeta.summary_mat_file = summary_mat_file;
TimescaleFigureMeta.source_output_base = source_base;
TimescaleFigureMeta.output_base = output_base;
TimescaleFigureMeta.model_mode = source_model_mode;
TimescaleFigureMeta.plot_session_mode = M.meta.plot_session_mode;
TimescaleFigureMeta.num_sessions = num_sessions;
TimescaleFigureMeta.area_names = area_names;
TimescaleFigureMeta.area_colors = cfg.area_colors;
if isfield(M.meta,'runIdx')
    TimescaleFigureMeta.source_runIdx = M.meta.runIdx;
end
TimescaleFigureMeta.shared_latent_color = shared_gray;
TimescaleFigureMeta.source_category_labels = ...
    cellstr(string(M.labels.categories(:)'));
TimescaleFigureMeta.plot_category_indices = category_indices;
TimescaleFigureMeta.plot_category_labels = category_labels;
TimescaleFigureMeta.shared_latent_policy = ...
    'Group 1 values shown exactly once; no duplicate across-area points';
TimescaleFigureMeta.shared_group_mismatch_slices = ...
    shared_mismatch_count;
TimescaleFigureMeta.timescale_overflow_policy = ...
    'Values above 400 ms shown at 430 ms; source MAT unchanged';
TimescaleFigureMeta.division_lines_ms = timescale_division_lines;
TimescaleFigureMeta.color_policy = ...
    'Only area-specific Within distributions use area colors; other marks gray';
fig.UserData = TimescaleFigureMeta;

if save_meta_mat
    save([output_path, '_meta.mat'], 'TimescaleFigureMeta');
    fprintf('Saved plot metadata: %s_meta.mat\n', output_path);
end
drawnow;
if save_fig
    savefig(fig, [output_path, '.fig']);
    fprintf('Saved FIG: %s.fig\n', output_path);
end
if save_svg
    % saveas supports SVG on MATLAB releases where exportgraphics does not.
    try
        saveas(fig, [output_path, '.svg']);
    catch ME
        warning('timescale_compare_figure:SVGSaveasFailed', ...
            'SVG saveas failed (%s); trying print -dsvg.', ME.message);
        print(fig, [output_path, '.svg'], '-dsvg');
    end
    fprintf('Saved SVG: %s.svg\n', output_path);
end
if save_png
    try
        exportgraphics(fig, [output_path, '.png'], ...
            'Resolution', png_dpi, 'BackgroundColor','white');
    catch ME
        warning('timescale_compare_figure:PNGExportFallback', ...
            'PNG exportgraphics failed (%s); trying print -dpng.', ...
            ME.message);
        print(fig,[output_path,'.png'],'-dpng',sprintf('-r%d',png_dpi));
    end
    fprintf('Saved PNG: %s.png\n', output_path);
end
if close_after_save
    close(fig);
end
fprintf('Done: %s\n', output_base);

%% ============================= LOCAL FUNCTIONS =========================

function file = autoSummaryFileLocal(rootDir, content, model, source, ...
        useFilter, filterField, sessionMode, groupNames)
    if isstring(groupNames)
        groupNames = cellstr(groupNames(:)');
    end
    if ~iscell(groupNames) || isempty(groupNames)
        error('group_names must list the areas in saved group order.');
    end
    parts = cell(1,numel(groupNames));
    for g = 1:numel(groupNames)
        tag = regexprep(strtrim(char(groupNames{g})), ...
            '[^A-Za-z0-9_-]+','_');
        tag = regexprep(tag,'_+','_');
        tag = regexprep(tag,'^_+|_+$','');
        if isempty(tag), tag = 'area'; end
        parts{g} = sprintf('G%02d_%s', g, tag);
    end
    if useFilter
        selectionTag = safeTagLocal(filterField);
    else
        selectionTag = 'all';
    end
    if strcmp(char(sessionMode),'pool_sessions')
        sessionTag = 'pool_s';
    else
        sessionTag = 'separ_s';
    end
    base = sprintf('%s_sum_timescale_%s_%s_%s_%s_%s', ...
        content, safeTagLocal(model), safeTagLocal(source), ...
        selectionTag, sessionTag, strjoin(parts,'_'));
    file = fullfile(rootDir, [base,'.mat']);
end

function tag = safeTagLocal(s)
    tag = regexprep(lower(char(string(s))), '[^a-z0-9]+','_');
    tag = regexprep(tag,'^_+|_+$','');
end

function indices = categoryOrderLocal(labels)
    labels = cellstr(string(labels(:)'));
    if numel(labels) ~= 5
        error('Expected exactly five latent categories.');
    end
    cleaned = cellfun(@(s) regexprep(lower(strtrim(s)), ...
        '[^a-z]',''),labels,'UniformOutput',false);
    names = {{'within'}, {'across'}, {'feedforward','ff'}, ...
        {'feedback','fb'}, {'ambiguous'}};
    indices = zeros(1,5);
    for c = 1:5
        hit = find(ismember(cleaned, names{c}));
        if numel(hit) ~= 1
            error('Cannot identify category %d uniquely among: %s', ...
                c, strjoin(labels,', '));
        end
        indices(c) = hit;
    end
end

function colors = resolveAreaColorsLocal(groupNames,palette)
    % A repeated area name always uses the same color in the poster figure.
    seen = {};
    colors = zeros(numel(groupNames),3);
    for g = 1:numel(groupNames)
        index = find(strcmp(seen,groupNames{g}),1);
        if isempty(index)
            seen{end+1} = groupNames{g}; %#ok<AGROW>
            index = numel(seen);
        end
        if index > size(palette,1)
            error('Specify one RGB color per unique area in area_colors.');
        end
        colors(g,:) = palette(index,:);
    end
end

function n = countSharedMismatchLocal(M, order)
    n = 0;
    for c = 2:5
        originalIndex = order(c);
        for s = 1:size(M.values,1)
            if strcmp(char(M.meta.model_mode),'all_condition_model')
                a = sortedFiniteLocal(M.values{s,1,originalIndex});
                b = sortedFiniteLocal(M.values{s,2,originalIndex});
                n = n + ~isequaln(a,b);
            else
                for p = 1:size(M.values,3)
                    a = sortedFiniteLocal(M.values{s,1,p,originalIndex});
                    b = sortedFiniteLocal(M.values{s,2,p,originalIndex});
                    n = n + ~isequaln(a,b);
                end
            end
        end
    end
end

function vals = sortedFiniteLocal(vals)
    vals = vals(:);
    vals = sort(vals(isfinite(vals)));
end

function vals = getTimescaleLocal(M,s,g,p,c)
    if strcmp(char(M.meta.model_mode),'all_condition_model')
        raw = M.values{s,g,c};
    else
        raw = M.values{s,g,p,c};
    end
    if ~isnumeric(raw) || ~isreal(raw)
        error('Expected numeric real latent timescales in the source MAT.');
    end
    vals = double(raw(:));
    vals = vals(isfinite(vals));
end

function positions = buildPositionsLocal(numSessions,pool,jitterSeparate)
    % Each category holds two area positions only for Within. The other
    % categories each hold one canonical shared distribution.
    positions = repmat(struct('x',[],'center',NaN, ...
        'left',NaN,'right',NaN),1,5);
    if pool
        centers = 1 + (0:4)*1.65;
        positions(1).x = [centers(1)-0.31; centers(1)+0.31];
        for c = 2:5
            positions(c).x = centers(c);
        end
    else
        step = max(0.28, jitterSeparate+0.12);
        groupGap = 0.52;
        categoryGap = 0.82;
        cursor = 0.5;
        for c = 1:5
            if c == 1
                firstArea = cursor+(0:numSessions-1)*step;
                secondArea = firstArea(end)+groupGap+ ...
                    (1:numSessions)*step;
                positions(c).x = [firstArea;secondArea];
            else
                positions(c).x = cursor+(0:numSessions-1)*step;
            end
            cursor = max(positions(c).x(:))+categoryGap;
        end
    end
    for c = 1:5
        positions(c).center = mean(positions(c).x(:));
        positions(c).left = min(positions(c).x(:));
        positions(c).right = max(positions(c).x(:));
    end
end

function plotOnePanelLocal(ax,M,conditionIndex,cfg)
    hold(ax,'on');
    numSessions = size(M.values,1);
    positions = buildPositionsLocal(numSessions,cfg.pool_sessions, ...
        cfg.jitter_separate);
    xlim(ax,[positions(1).left-0.65,positions(5).right+0.65]);
    ylim(ax,[cfg.y_min,cfg.overflow_y+cfg.top_padding]);
    yt = cfg.y_min:cfg.tick_step:cfg.regular_max;
    ylabels = arrayfun(@(v) sprintf('%g',v),yt,'UniformOutput',false);
    ylabels{end+1} = sprintf('>%g',cfg.regular_max);
    set(ax,'YTick',[yt,cfg.overflow_y],'YTickLabel',ylabels, ...
        'FontName',cfg.font_name,'FontUnits','points', ...
        'FontSize',cfg.axis_font_size, ...
        'XColor',cfg.axis_gray,'YColor',cfg.axis_gray, ...
        'TickDir','out','LineWidth',0.9,'Box','off', ...
        'XGrid','off','YGrid','off');

    % Background reference lines and category separators never use area
    % colors. Draw them before the observations.
    xl = xlim(ax);
    for y = cfg.division_lines(:)'
        if isfinite(y) && y >= cfg.y_min && ...
                y <= cfg.overflow_y+cfg.top_padding
            line(ax,xl,[y,y],'LineStyle','--', ...
                'Color',cfg.division_gray, ...
                'LineWidth',cfg.division_line_width, ...
                'HandleVisibility','off');
        end
    end
    for c = 1:4
        boundary = (positions(c).right+positions(c+1).left)/2;
        line(ax,[boundary,boundary],ylim(ax), ...
            'Color',cfg.guide_gray,'LineWidth',0.8, ...
            'HandleVisibility','off');
    end

    for c = 1:5
        originalIndex = cfg.category_indices(c);
        if c == 1
            groups = 1:2;
        else
            groups = 1; % A shared across-area latent is drawn once.
        end
        for g = groups
            if c == 1
                thisColor = cfg.area_colors(g,:);
            else
                thisColor = cfg.shared_gray;
            end
            if cfg.pool_sessions
                values = [];
                for s = 1:numSessions
                    values = [values;getTimescaleLocal( ...
                        M,s,g,conditionIndex,originalIndex)]; %#ok<AGROW>
                end
                values(values > cfg.regular_max) = cfg.overflow_y;
                drawCloudLocal(ax,positions(c).x(g),values, ...
                    thisColor,cfg.point_size,cfg.point_alpha, ...
                    cfg.jitter_pool,1000*c+10*g+conditionIndex);
            else
                for s = 1:numSessions
                    values = getTimescaleLocal( ...
                        M,s,g,conditionIndex,originalIndex);
                    values(values > cfg.regular_max) = cfg.overflow_y;
                    drawCloudLocal(ax,positions(c).x(g,s),values, ...
                        thisColor,cfg.point_size,cfg.point_alpha, ...
                        cfg.jitter_separate,1000*c+100*g+10*s+conditionIndex);
                end
            end
        end
    end

    if cfg.pool_sessions
        set(ax,'XTick',[positions.center], ...
            'XTickLabel',cfg.category_labels, ...
            'TickLabelInterpreter','none');
    else
        ticks = [];
        tickLabels = {};
        for c = 1:5
            if c == 1
                groups = 1:2;
            else
                groups = 1;
            end
            for g = groups
                ticks = [ticks,positions(c).x(g,:)]; %#ok<AGROW>
                tickLabels = [tickLabels,cfg.session_labels]; %#ok<AGROW>
            end
        end
        set(ax,'XTick',ticks,'XTickLabel',tickLabels, ...
            'XTickLabelRotation',57, ...
            'TickLabelInterpreter','none', ...
            'FontSize',cfg.axis_font_size);
        xBounds = xlim(ax);
        for c = 1:5
            xFraction = (positions(c).center-xBounds(1))/diff(xBounds);
            text(ax,xFraction,-0.30,cfg.category_labels{c}, ...
                'Units','normalized','HorizontalAlignment','center', ...
                'FontName',cfg.font_name,'FontSize',cfg.axis_font_size, ...
                'FontWeight','bold','Color',cfg.axis_gray, ...
                'Interpreter','none','Clipping','off');
        end
    end
end

function drawCloudLocal(ax,x0,vals,color,sz,alpha,jitterWidth,seed)
    if isempty(vals)
        return;
    end
    n = numel(vals);
    if n == 1
        offset = 0;
    else
        % Stable, evenly distributed horizontal jitter. No global RNG.
        offset = jitterWidth*(mod((1:n)'*0.61803398875 + ...
            seed*0.137508,1)-0.5);
    end
    dots = scatter(ax,x0+offset,vals,sz,'o','filled', ...
        'MarkerFaceColor',color,'MarkerEdgeColor',[0.6 0.6 0.6], ...
        'HandleVisibility','off');
    try
        dots.MarkerFaceAlpha = alpha;
    catch
        % Older MATLAB versions do not expose scatter transparency.
    end
end

function addAreaLegendLocal(ax,labels,colors,fontName,fontSize,manyPanels)
    uniqueLabels = {};
    firstIndex = [];
    for g = 1:numel(labels)
        if ~any(strcmp(uniqueLabels,labels{g}))
            uniqueLabels{end+1} = labels{g}; %#ok<AGROW>
            firstIndex(end+1) = g; %#ok<AGROW>
        end
    end
    handles = gobjects(1,numel(firstIndex));
    for k = 1:numel(firstIndex)
        g = firstIndex(k);
        handles(k) = plot(ax,nan,nan,'o','MarkerSize',7, ...
            'MarkerFaceColor',colors(g,:), ...
            'MarkerEdgeColor','none', ...
            'LineStyle','none');
    end
    oldPosition = get(ax,'Position');
    lgd = legend(ax,handles,uniqueLabels, ...
        'Orientation','horizontal', 'Box','off', ...
        'FontName',fontName,'FontSize',fontSize, ...
        'Interpreter','none','AutoUpdate','off');
    lgd.Units = 'normalized';
    figure_position = get(ancestor(ax,'figure'),'Position'); % inches
    text_height = 1.5*fontSize/(72*figure_position(4));
    if manyPanels
        legend_height = max(0.025,text_height);
        lgd.Position = [0.75, 0.99-legend_height, 0.23, legend_height];
    else
        legend_height = max(0.04,text_height);
        lgd.Position = [0.71, 0.98-legend_height, 0.26, legend_height];
    end
    set(ax,'Position',oldPosition);
end
