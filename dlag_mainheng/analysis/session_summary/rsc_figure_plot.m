%% rsc_figure_plot.m
% Poster figure based on the MAT file saved by sum_session_rsc.m.
%
% Run sum_session_rsc.m first, then run this SCRIPT with an empty workspace.
% The input variable is MultiSessionRSC. Only its mean-z-scored-Fisher-r_sc
% observations are plotted here; the original session summary is unchanged.
%
% Within each of the three neuron-pair-type blocks, the eight conditions
% have the fixed order G-S-L, G-S-H, G-L-L, G-L-H, P-S-L, P-S-H,
% P-L-L, P-L-H. Three nested brackets and three P values test:
%   all eight bars : G - P, averaged across four matched comparisons;
%   first four bars: Small - Large within G, averaged across contrasts;
%   first two bars : Low - High within G and Small.
% The second and third tests are conditional comparisons, not the
% Small-Large and Low-High marginal effects across all eight conditions.
%
% One session x stimulus-direction observation supplies one paired
% difference per test. With six sessions and two directions each, each
% test has at most 12 differences; the four G-P matches are NOT treated as
% 48 independent samples. Each right-tailed Wilcoxon signed-rank P is
% nominal (not corrected across tests). Exact zeros are omitted by signrank.
% The two directions from a session are deliberately treated as separate
% observations here, following the source figure's mean and SEM rule;
% this does not establish statistical independence across directions.
%
% Gray bars show the arithmetic mean of the 12 finite plotted points;
% gray dots show individual session-direction observations; dark-gray
% error bars are sample SD(points) / sqrt(number of finite points).
% All plotted marks and text are grayscale. The result and its testing
% policy are also saved in a small, separate statistics MAT file.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';
input_mat_name = ...
    'sum_session_rsc_16conditions_G01_V1_G02_MT_barmean.mat';

save_fig = false;
save_svg = true;
save_png = false;
save_stats_mat = false;
close_after_save = true;
figure_visible = 'on'; % 'on' or 'off'
png_dpi = 300;

font_name = 'Arial';
axis_font_size = 11;
figure_width = 2000;
figure_height = 900;
condition_group_width = 0.86;
bar_width_fraction = 0.72;
point_jitter_fraction = 0.55;
point_size = 20;
point_alpha = 0.80;
bar_alpha = 0.55;
poster_alpha = 0.05;

%% ======================= READ SAVED SUMMARY ============================

if exist(root_dir, 'dir') ~= 7
    error('Root directory does not exist: %s', root_dir);
end
if ~ischar(input_mat_name) && ...
        ~(isstring(input_mat_name) && isscalar(input_mat_name))
    error('input_mat_name must be a file name or a full path.');
end
input_mat_name = char(input_mat_name);
if isempty(fileparts(input_mat_name))
    input_mat_file = fullfile(root_dir, input_mat_name);
else
    input_mat_file = input_mat_name;
end
if exist(input_mat_file, 'file') ~= 2
    error(['Summary MAT is missing: %s\nRun sum_session_rsc.m first ', ...
        'or update input_mat_name.'], input_mat_file);
end
if exist('signrank', 'file') == 0
    error('Wilcoxon signed-rank tests require Statistics and Machine Learning Toolbox.');
end
if ~ismember(lower(char(figure_visible)), {'on', 'off'})
    error('figure_visible must be ''on'' or ''off''.');
end
if ~isscalar(poster_alpha) || ~isfinite(poster_alpha) || ...
        poster_alpha <= 0 || poster_alpha > 0.05
    error('poster_alpha must be a finite number in (0, 0.05].');
end
if ~(isnumeric(condition_group_width) && ...
        isscalar(condition_group_width) && ...
        condition_group_width > 0 && condition_group_width < 1 && ...
        isfinite(condition_group_width))
    error('condition_group_width must be in (0, 1).');
end

input_data = load(input_mat_file, 'MultiSessionRSC');
if ~isfield(input_data, 'MultiSessionRSC') || ...
        ~isscalar(input_data.MultiSessionRSC)
    error('Input MAT must contain one MultiSessionRSC struct.');
end
M = input_data.MultiSessionRSC;
if ~isfield(M, 'observations') || ...
        ~isfield(M.observations, 'mean_zscored_fisher') || ...
        ~isfield(M.observations, 'info') || ...
        ~isfield(M, 'labels') || ...
        ~isfield(M.labels, 'conditions') || ...
        ~isfield(M.labels, 'pair_types') || ...
        ~isfield(M, 'meta') || ...
        ~isfield(M.meta, 'area_mapping_tag')
    error('The MAT is not a complete sum_session_rsc.m output.');
end

observations = double(M.observations.mean_zscored_fisher);
if ~isnumeric(M.observations.mean_zscored_fisher) || ...
        ndims(observations) ~= 3 || ...
        size(observations, 2) ~= 8 || size(observations, 3) ~= 3
    error('Expected an observations x 8 conditions x 3 pair types array.');
end
num_observations = size(observations, 1);
if num_observations < 1 || ...
        numel(M.observations.info) ~= num_observations
    error('Observation data and observation_info do not align.');
end

condition_labels = cellstr(string(M.labels.conditions(:)'));
pair_type_labels = cellstr(string(M.labels.pair_types(:)'));
expected_conditions = {'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
    'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};
if ~isequal(upper(string(condition_labels)), ...
        upper(string(expected_conditions))) || ...
        numel(pair_type_labels) ~= 3
    error('The input must have the standard eight condition labels and three pair types.');
end
if ~isfield(M.meta, 'num_sessions') || ...
        ~isfield(M.meta, 'num_directions_per_session') || ...
        ~isfield(M.meta, 'bar_summary_stat') || ...
        ~strcmpi(char(M.meta.bar_summary_stat), 'mean') || ...
        M.meta.num_directions_per_session ~= 2 || ...
        num_observations ~= 2 * M.meta.num_sessions
    error('Expected a barmean summary with exactly two directions per session.');
end

%% ==================== DESCRIPTIVE BAR STATISTICS =======================

bar_means = nan(8, 3);
bar_sems = nan(8, 3);
bar_counts = zeros(8, 3);
for pair_type = 1:3
    for condition = 1:8
        values = observations(:, condition, pair_type);
        values = values(isfinite(values));
        bar_counts(condition, pair_type) = numel(values);
        if isempty(values)
            continue;
        end
        bar_means(condition, pair_type) = mean(values);
        if numel(values) >= 2
            bar_sems(condition, pair_type) = ...
                std(values, 0) / sqrt(numel(values));
        end
    end
end

%% ============ THREE RIGHT-TAILED P VALUES PER PAIR TYPE ===============

% The indices below also determine the bracket spans in each eight-bar
% block: 1:8 for G-P, 1:4 for S-L within G, 1:2 for L-H within G/S.
contrast_names = {'G - P', 'Small - Large (G)', ...
    'Low - High (G, Small)'};
matched_indices = { ...
    [1, 5; 2, 6; 3, 7; 4, 8], ...
    [1, 3; 2, 4], ...
    [1, 2]};
bracket_spans = [1, 8; 1, 4; 1, 2];
contrast_template = struct( ...
    'pair_type', '', 'name', '', 'matched_condition_indices', [], ...
    'matched_condition_labels', {{}}, 'bracket_span', [], ...
    'per_observation_difference', [], 'matched_pairs_per_observation', [], ...
    'n_finite_observations', 0, 'n_nonzero_differences', 0, ...
    'mean_difference', NaN, 'median_difference', NaN, ...
    'test', 'right-tailed Wilcoxon signed-rank against zero', ...
    'p_value', NaN);
contrast_stats = repmat(contrast_template, 3, 3);

for pair_type = 1:3
    for effect = 1:3
        indices = matched_indices{effect};
        n_pairs = size(indices, 1);
        positive = reshape(observations(:, indices(:,1), pair_type), ...
            num_observations, n_pairs);
        negative = reshape(observations(:, indices(:,2), pair_type), ...
            num_observations, n_pairs);
        matched_differences = positive - negative;
        matched_differences(~isfinite(positive) | ...
            ~isfinite(negative)) = NaN;

        % One mean of finite MATCHED differences per session x direction.
        n_matched = sum(isfinite(matched_differences), 2);
        matched_differences(~isfinite(matched_differences)) = 0;
        delta = sum(matched_differences, 2) ./ n_matched;
        delta(n_matched == 0) = NaN;
        finite_delta = delta(isfinite(delta));

        this_test = contrast_template;
        this_test.pair_type = pair_type_labels{pair_type};
        this_test.name = contrast_names{effect};
        this_test.matched_condition_indices = indices;
        this_test.matched_condition_labels = [ ...
            reshape(expected_conditions(indices(:,1)), [], 1), ...
            reshape(expected_conditions(indices(:,2)), [], 1)];
        this_test.bracket_span = bracket_spans(effect,:);
        this_test.per_observation_difference = delta;
        this_test.matched_pairs_per_observation = n_matched;
        this_test.n_finite_observations = numel(finite_delta);
        this_test.n_nonzero_differences = nnz(finite_delta ~= 0);
        if ~isempty(finite_delta)
            this_test.mean_difference = mean(finite_delta);
            this_test.median_difference = median(finite_delta);
            if all(finite_delta == 0)
                this_test.p_value = 1;
            else
                this_test.p_value = signrank( ...
                    finite_delta, 0, 'tail', 'right');
            end
        end
        contrast_stats(pair_type, effect) = this_test;
    end
end

%% ==================== STATISTICS AND PROVENANCE ========================

RSCFigureStats = struct();
RSCFigureStats.meta.created_by = mfilename;
RSCFigureStats.meta.input_mat_file = input_mat_file;
RSCFigureStats.meta.source_area_mapping_tag = M.meta.area_mapping_tag;
RSCFigureStats.meta.num_sessions = M.meta.num_sessions;
RSCFigureStats.meta.num_direction_observations = num_observations;
RSCFigureStats.meta.test_unit = 'session x stimulus direction';
RSCFigureStats.meta.direction_dependence = [ ...
    'Two directions from the same session are treated as separate ', ...
    'observations following the requested 2N-point summary; ', ...
    'within-session statistical independence is an analysis assumption.'];
RSCFigureStats.meta.test_alternative = 'paired contrast greater than zero';
RSCFigureStats.meta.multiple_testing = [ ...
    'Nominal one-sided P for each of the three pre-specified ', ...
    'contrasts per pair type; no multiple-testing adjustment.'];
RSCFigureStats.meta.bar_definition = [ ...
    'Mean of finite session-direction observations in each condition.'];
RSCFigureStats.meta.errorbar_definition = [ ...
    'Sample SD of finite session-direction values divided by sqrt(N).'];
RSCFigureStats.meta.condition_effect_definition = [ ...
    'G-P averages four matched differences across all eight bars; ', ...
    'Small-Large averages two matched differences in the first four ', ...
    'G bars; Low-High uses the first two G/Small bars only.'];
RSCFigureStats.meta.p_text = 'Bold P; * <0.05, ** <0.01, *** <0.001, **** <0.0001';
RSCFigureStats.labels.condition = condition_labels;
RSCFigureStats.labels.pair_type = pair_type_labels;
RSCFigureStats.observations.info = M.observations.info;
RSCFigureStats.observations.mean_zscored_fisher = observations;
RSCFigureStats.bars.mean = bar_means;
RSCFigureStats.bars.sem = bar_sems;
RSCFigureStats.bars.n = bar_counts;
RSCFigureStats.contrasts = contrast_stats;

%% ============================ POSTER FIGURE ============================

fig = figure('Name', 'Noise correlation: stimulus effects', ...
    'NumberTitle', 'off', 'Color', 'w', ...
    'Visible', figure_visible, ...
    'Position', [100, 100, figure_width, figure_height], ...
    'Renderer', 'painters');
ax = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.087, 0.215, 0.885, 0.575]);
hold(ax, 'on');

condition_spacing = condition_group_width / 8;
offsets = ((1:8) - 4.5) * condition_spacing;
bar_width = condition_spacing * bar_width_fraction;
point_width = bar_width * point_jitter_fraction;
x_positions = (1:3) + offsets';
x_limits = [0.45, 3.55];

finite_y = observations(isfinite(observations));
visible_summaries = [bar_means(:) + bar_sems(:); ...
    bar_means(:) - bar_sems(:)];
finite_y = [finite_y(:); visible_summaries(isfinite(visible_summaries))];
if isempty(finite_y)
    y_limits = [-0.1, 0.1];
else
    y_min = min([0; finite_y]);
    y_max = max([0; finite_y]);
    y_span = max(y_max - y_min, 0.1);
    y_limits = [y_min - 0.07*y_span, y_max + 0.08*y_span];
end

gray_bar = [0.72, 0.72, 0.72];
gray_point = [0.36, 0.36, 0.36];
gray_ink = [0.20, 0.20, 0.20];

plot(ax, x_limits, [0, 0], ':', ...
    'Color', [0.57, 0.57, 0.57], 'LineWidth', 0.9, ...
    'HandleVisibility', 'off');
for sep = [1.5, 2.5]
    plot(ax, [sep, sep], y_limits, '-', ...
        'Color', [0.87, 0.87, 0.87], 'LineWidth', 0.9, ...
        'HandleVisibility', 'off');
end

for pair_type = 1:3
    for condition = 1:8
        x0 = x_positions(condition, pair_type);
        center = bar_means(condition, pair_type);
        error_length = bar_sems(condition, pair_type);
        if isfinite(center)
            patch(ax, x0 + bar_width * [-0.5, 0.5, 0.5, -0.5], ...
                [0, 0, center, center], gray_bar, ...
                'EdgeColor', [0.48, 0.48, 0.48], ...
                'LineWidth', 0.7, 'FaceAlpha', bar_alpha, ...
                'HandleVisibility', 'off');
            if isfinite(error_length)
                errorbar(ax, x0, center, error_length, error_length, ...
                    'Color', gray_ink, 'LineStyle', 'none', ...
                    'LineWidth', 1.2, 'CapSize', 7, ...
                    'HandleVisibility', 'off');
            end
        end
        values = observations(:, condition, pair_type);
        values = values(isfinite(values));
        n = numel(values);
        if n > 0
            if n == 1
                jitter = 0;
            else
                jitter = linspace(-point_width/2, point_width/2, n)';
            end
            dots = scatter(ax, x0 + jitter, values, point_size, ...
                'filled', 'MarkerFaceColor', gray_point, ...
                'MarkerEdgeColor', gray_point, ...
                'HandleVisibility', 'off');
            try
                dots.MarkerFaceAlpha = point_alpha;
                dots.MarkerEdgeAlpha = point_alpha;
            catch
                % Older MATLAB versions do not expose scatter alpha.
            end
        end
    end
end

xlim(ax, x_limits);
ylim(ax, y_limits);
set(ax, 'XTick', x_positions(:)', ...
    'XTickLabel', repmat(condition_labels, 1, 3), ...
    'XTickLabelRotation', 58, 'TickLabelInterpreter', 'none', ...
    'XColor', gray_ink, 'YColor', gray_ink, ...
    'FontName', font_name, 'FontSize', axis_font_size, ...
    'TickDir', 'out', 'Box', 'off', 'LineWidth', 1);
ylabel(ax, 'Mean z-scored Fisher r_{sc}', 'Interpreter', 'tex', ...
    'FontName', font_name, 'FontSize', axis_font_size + 2, ...
    'Color', gray_ink);

title_box = [0.087, 0.960, 0.81, 0.034];
annotation(fig, 'textbox', title_box, ...
    'String', 'Noise correlation across stimulus conditions', ...
    'Interpreter', 'none', 'EdgeColor', 'none', ...
    'Color', gray_ink, 'FontName', font_name, ...
    'FontSize', axis_font_size + 3, 'FontWeight', 'bold');

% The bracket height is measured in figure coordinates, outside the data
% axis, so its nine P labels cannot change the r_sc y-axis range.
ax_pos = [0.087, 0.215, 0.885, 0.575];
set(ax, 'Position', ax_pos);
x_in_figure = ax_pos(1) + ...
    (x_positions - x_limits(1)) / diff(x_limits) * ax_pos(3);

for pair_type = 1:3
    annotation(fig, 'textbox', ...
        [mean(x_in_figure(:, pair_type)) - 0.10, ...
         0.038, 0.20, 0.034], ...
        'String', pair_type_labels{pair_type}, ...
        'Interpreter', 'none', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', ...
        'Color', gray_ink, 'FontName', font_name, ...
        'FontSize', axis_font_size + 2, 'FontWeight', 'bold');

    for effect = 1:3
        span = bracket_spans(effect,:);
        left = x_in_figure(span(1), pair_type) - ...
            0.40 * bar_width / diff(x_limits) * ax_pos(3);
        right = x_in_figure(span(2), pair_type) + ...
            0.40 * bar_width / diff(x_limits) * ax_pos(3);
        height = 0.919 - 0.049 * (effect - 1);
        annotation(fig, 'line', [left, right], [height, height], ...
            'Color', gray_ink, 'LineWidth', 1.0);
        annotation(fig, 'line', [left, left], ...
            [height - 0.009, height], 'Color', gray_ink, ...
            'LineWidth', 1.0);
        annotation(fig, 'line', [right, right], ...
            [height - 0.009, height], 'Color', gray_ink, ...
            'LineWidth', 1.0);

        p = contrast_stats(pair_type, effect).p_value;
        if isfinite(p)
            label = sprintf('%s %s', rscPTextLocal(p), ...
                rscStarsLocal(p, poster_alpha));
        else
            label = '\bfP\rm=NA';
        end
        annotation(fig, 'textbox', ...
            [(left + right)/2 - 0.082, height + 0.002, ...
             0.164, 0.027], ...
            'String', label, 'Interpreter', 'tex', ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Color', gray_ink, 'FontName', font_name, ...
            'FontSize', axis_font_size - 1);
    end
end

%% ============================ SAVE RESULTS =============================

output_base = sprintf('rsc_figure_plot_16conditions_%s_mean', ...
    char(M.meta.area_mapping_tag));
output_path = fullfile(root_dir, output_base);
RSCFigureStats.meta.output_base = output_base;
fig.UserData = RSCFigureStats;
if save_stats_mat
    save([output_path, '_stats.mat'], 'RSCFigureStats', '-v7.3');
    fprintf('Saved statistics: %s_stats.mat\n', output_path);
end
drawnow;
if save_fig
    savefig(fig, [output_path, '.fig']);
    fprintf('Saved FIG: %s.fig\n', output_path);
end
if save_svg
    savePosterSvgLocal(fig, [output_path, '.svg']);
    fprintf('Saved SVG: %s.svg\n', output_path);
end
if save_png
    savePosterPngLocal(fig, [output_path, '.png'], png_dpi);
    fprintf('Saved PNG: %s.png\n', output_path);
end
if close_after_save
    close(fig);
end
fprintf('Done. Three nominal one-sided P values per pair type.\n');

%% ============================ LOCAL FUNCTIONS ==========================

function label = rscPTextLocal(p)
% MATLAB's TeX interpreter bolds only the P and resets the digits to roman.
    if p < 0.001
        label = '\bfP\rm<0.001';
    else
        label = sprintf('\\bfP\\rm=%.3g', p);
    end
end

function stars = rscStarsLocal(p, alpha)
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

function savePosterSvgLocal(fig, file_name)
    try
        % exportgraphics gained SVG output only in R2025a; saveas also
        % supports the older MATLAB versions used by the source program.
        saveas(fig, file_name);
    catch ME
        warning('SVG saveas failed (%s); trying print -dsvg.', ME.message);
        print(fig, file_name, '-dsvg');
    end
end

function savePosterPngLocal(fig, file_name, dpi)
    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, file_name, 'Resolution', dpi, ...
                'BackgroundColor', 'white');
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, file_name, '-dpng', sprintf('-r%d', dpi));
        end
    catch ME
        warning('PNG export failed (%s); trying saveas.', ME.message);
        saveas(fig, file_name);
    end
end
