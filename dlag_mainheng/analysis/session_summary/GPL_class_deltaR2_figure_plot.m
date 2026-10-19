%% GPL_class_deltaR2_figure_plot.m
% Poster figures: raw delta R2 and delta of session-area z-scored R2.
% Only eight three-feature stimulus conditions are read. All distributions
% contain ONE value per neuron: the mean of its finite condition/match values.
% The MAT retains original per-condition data, unit IDs, and session IDs.
%
% Latent-source differences Across - Within and FF - FB are plotted
% separately for V1 and MT, with Pattern/Component/Unclassified cells shown
% as separate x-axis categories. Feature effects Grating - Plaid,
% Small - Large, Low - High use the neuron_population selected below.
% 'all_neurons': all model neurons, including GPL-invalid neurons.
% 'pcu_neurons': Pattern/Component/Unclassified only (original analysis).
% Each feature-effect
% plot shows both areas side by side for each reconstruction source; the area
% is encoded solely by blue/orange and a two-entry legend. An optional full
% range inset uses exactly the same source -> area grouping as the main plot.
%
% The colored violin has centered density-dependent points. The black
% vertical bar is Q1-Q3, thin whiskers end at observed Tukey inliers, and
% the horizontal bar marks the median. A central-range axis keeps extreme
% values visible in an unlabelled full-range inset (when needed).
% Significance is calculated from individual neurons: one-sample signed-
% rank tests against zero, plus a three-class Kruskal-Wallis test and
% Holm-corrected rank-sum comparisons for the latent-source balances.
% One-sample violin P values are nominal; only class pairs receive Holm.
% The SAME neuron_population option selects the z-score reference pool:
% finite R2 values from the selected neurons, all five reconstruction fields
% and all eight conditions within EACH session-area.
% Feature and balance analyses share that mean and sample SD. V1 and MT
% are never normalized together. Legends report unique used neurons per
% area in that figure (a neuron used by both sources is counted once).
% Balance figures always show P/C/U separately, with the selected shared
% z-score baseline. Output bases carry allN or pcuN to keep modes separate.

clc;
clear;

%% ========================== USER SETTINGS ==============================

root_dir = 'I:\np_data';
data_content = 'demean_count_within_t_and_condition';
runIdx = 1; % 1: original data; 2: independently shuffled units
model_mode = 'all_condition_model';
% 'all_condition_model' or 'condition_specific_models'
reconstruction_suffix = 'all_across_within_ff_fb';
group_names = {'V1', 'MT'}; % follows model group order in input MAT
gpl_mat_name = 'unit_gpl_results_sponsub.mat';

neuron_population = 'all_neurons'; % 'all_neurons' or 'pcu_neurons'
% Controls BOTH stimulus-feature neurons and the shared z-score pool.
% all_neurons: current all-model-neuron analysis, including GPL-invalid.
% pcu_neurons: original P/C/U analysis and original P/C/U z-score baseline.
% Both modes retain the same figures and legends with actual neuron counts.

save_mat = false;
save_fig = false;
save_svg = true;
save_png = false;
close_after_save = true;
figure_visible = 'on'; % 'on' or 'off'
png_dpi = 300;
print_full_error_report = false;

% Categorical color means area ONLY; marks, boundaries and text are gray.
poster_area_colors = [0.0000, 0.4470, 0.7410; ... % V1
                      0.8500, 0.3250, 0.0980];   % MT
poster_outlier_mode = 'zoom_inset'; % 'zoom_inset' or 'full_range'
poster_central_percentile = 95;   % central percentile of |delta|
poster_point_size = 9;
poster_point_alpha = 0.45;
poster_point_jitter_width = 0.12;
poster_violin_width = 0.25;
poster_violin_alpha = 0.18;
poster_violin_point_spread_gain = 1.3;
% Larger gain spreads dots at every density; raise violin_width if the
% dots reach the outline. Dots always stay inside the violin contour.
poster_violin_point_edge_fraction = 0.90;
poster_significance_alpha = 0.05;
% Each pre-specified one-sample violin test reports its nominal P value.
% Only the three post hoc cell-class pairs are Holm-corrected.
% Labels use bold P; the Kruskal-Wallis omnibus P is unadjusted.

font_name = 'Arial';
axis_font_size = 11;
figure_width = 1900;
figure_height = 780;

%% ==================== FIXED ANALYSIS DEFINITIONS ======================

% These are fixed poster choices; no other split/display/plot branches.
r2_split_mode = 'by_three_features';
split_file_tag = 'stszct';
mean_differnet_conditions = 1; % mean finite values within each neuron
plot_value_modes = {'raw', 'zscore'};

stim_types = {'G_S_L', 'G_S_H', 'G_L_L', 'G_L_H', ...
    'P_S_L', 'P_S_H', 'P_L_L', 'P_L_H'};
category_labels = {'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
    'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};
class_names = {'pattern', 'component', 'unclassified'};
class_labels = {'Pattern cell', 'Component cell', 'Unclassified cell'};
class_markers = {'o', 's', '^'};
class_short_names = {'P', 'C', 'U'};

% 'use_all' contributes to session-area normalization, but is not plotted.
r2_field_names = {'use_all', 'use_across', 'use_within', ...
    'use_feedforward', 'use_feedback'};
r2_field_labels = {'all', 'across', 'within', 'FF', 'FB'};
source_r2_field_names = {'use_across', 'use_within', ...
    'use_feedforward', 'use_feedback'};
source_r2_field_labels = {'across', 'within', 'FF', 'FB'};
feature_source_labels = {'Across', 'Within', 'Feedforward', 'Feedback'};
delta_names = {'acr_vs_wit', 'ff_vs_fb'};
delta_labels = {'acr vs. wit', 'ff vs. fb'};
delta_positive_fields = {'use_across', 'use_feedforward'};
delta_negative_fields = {'use_within', 'use_feedback'};
feature_delta_definitions = buildFeatureDeltaDefinitionsLocal();

%% ======================= VALIDATE SETTINGS =============================

neuron_population = lower(strtrim(char(neuron_population)));
[population_description, population_tag] = ...
    neuronPopulationDefinitionLocal(neuron_population);
group_names = normalizeGroupNamesLocal(group_names);
[group_display_names, group_file_tags] = ...
    buildGroupLabelsLocal(group_names);
mapping_file_tag = strjoin(group_file_tags, '_');
validatePosterInputLocal(root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, gpl_mat_name, group_names, ...
    class_names, class_labels, class_short_names, class_markers, ...
    r2_field_names, r2_field_labels, ...
    source_r2_field_names, source_r2_field_labels, ...
    feature_source_labels, delta_names, delta_labels, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, feature_delta_definitions, ...
    save_mat, save_fig, save_svg, save_png, close_after_save, ...
    figure_visible, png_dpi, figure_width, figure_height);

poster_outlier_mode = lower(strtrim(char(poster_outlier_mode)));
validateattributes(poster_significance_alpha, {'numeric'}, ...
    {'scalar', '>', 0, '<=', 0.05, 'finite'}, ...
    mfilename, 'poster_significance_alpha');
for test_function = {'signrank', 'kruskalwallis', 'ranksum'}
    if exist(test_function{1}, 'file') == 0
        error(['Cell-level poster statistics require MATLAB Statistics ', ...
            'and Machine Learning Toolbox (%s is unavailable).'], ...
            test_function{1});
    end
end
validatePosterOptionsLocal(poster_area_colors, group_names, ...
    poster_outlier_mode, poster_central_percentile, ...
    poster_point_size, poster_point_alpha, poster_point_jitter_width, ...
    poster_violin_width, poster_violin_alpha, ...
    poster_violin_point_spread_gain, ...
    poster_violin_point_edge_fraction);
poster_group_colors = resolvePosterAreaColorsLocal( ...
    group_names, poster_area_colors);
poster_config = struct( ...
    'plot_style', 'violin', 'condition_display_mode', 'pooled', ...
    'neuron_population', neuron_population, ...
    'feature_delta_plot_mode', 'pooled', ...
    'mean_differnet_conditions', logical(mean_differnet_conditions), ...
    'outlier_mode', poster_outlier_mode, ...
    'central_percentile', poster_central_percentile, ...
    'point_size', poster_point_size, ...
    'point_alpha', poster_point_alpha, ...
    'point_jitter_width', poster_point_jitter_width, ...
    'violin_width', poster_violin_width, ...
    'violin_alpha', poster_violin_alpha, ...
    'violin_point_spread_gain', poster_violin_point_spread_gain, ...
    'violin_point_edge_fraction', poster_violin_point_edge_fraction, ...
    'significance_alpha', poster_significance_alpha, ...
    'test_unit', 'neuron', 'one_sample_test', 'signrank', ...
    'class_omnibus_test', 'kruskalwallis', ...
    'class_pairwise_test', 'ranksum', ...
    'multiple_comparisons', 'Holm for three post hoc class pairs only', ...
    'area_colors', poster_group_colors, ...
    'font_name', font_name, 'axis_font_size', axis_font_size, ...
    'figure_width', figure_width, 'figure_height', figure_height, ...
    'figure_visible', figure_visible);

model_tag = makeModelTagLocal(model_mode);
output_prefix = sprintf('GPLdR2fig_%s_%s_%s_r%03d', ...
    data_content, model_tag, split_file_tag, runIdx);
output_base = sprintf('%s_%s_pooled_mean1_violin_cellstats_%s_p%g_vw%g_jw%g_vg%g', ...
    output_prefix, mapping_file_tag, poster_outlier_mode, ...
    poster_central_percentile, poster_violin_width, ...
    poster_point_jitter_width, poster_violin_point_spread_gain);
output_base = [output_base, '_', population_tag];

fprintf('\nAcross-session delta R2 poster figures (pooled neuron means)\n');
fprintf('Root: %s | model: %s | run: %d\n', root_dir, model_mode, runIdx);
fprintf('Z-score: R2 first, differences second; separate for each session-area.\n');
fprintf('Feature and z-score neuron population: %s\n', neuron_population);
fprintf('Figures: raw and z-scored latent/feature deltas; violin only.\n');
fprintf('Feature effects: source, then V1/MT; colors represent area.\n');
fprintf('Output base: %s\n', output_base);

%% ======================= FIND SESSION FOLDERS ==========================

session_dirs = findCatgtSessionDirsLocal(root_dir);

if isempty(session_dirs)
    error('No catgt_* folders found one level below root_dir: %s', root_dir);
end

fprintf('\nFound %d candidate catgt_* session folders.\n', ...
    numel(session_dirs));

%% ======================= READ ALL SESSIONS =============================

records = {};
skipped = struct('session_dir', {}, 'reason', {});
reference = struct();

for si = 1:numel(session_dirs)
    session_dir = session_dirs{si};

    fprintf('\n[%d/%d] Reading %s\n', ...
        si, numel(session_dirs), session_dir);

    try
        [rec, reference] = readOneSessionLocal( ...
            session_dir, data_content, model_mode, r2_split_mode, ...
            split_file_tag, runIdx, ...
            reconstruction_suffix, group_names, group_display_names, ...
            group_file_tags, gpl_mat_name, ...
            r2_field_names, source_r2_field_names, delta_names, ...
            delta_positive_fields, delta_negative_fields, ...
            stim_types, category_labels, ...
            feature_delta_definitions, reference, neuron_population);

        records{end + 1} = rec; %#ok<SAGROW>

    catch ME
        skipped(end + 1).session_dir = session_dir; %#ok<SAGROW>
        skipped(end).reason = ME.message;

        warning('Skipping session: %s\nReason: %s', ...
            session_dir, ME.message);

        if print_full_error_report
            fprintf('\nFull error report for skipped session:\n');
            fprintf('%s\n', getReport(ME, 'extended', ...
                'hyperlinks', 'off'));
        end
    end
end

if isempty(records)
    fprintf('\nSkipped sessions:\n');

    for k = 1:numel(skipped)
        fprintf('  %s\n    %s\n', ...
            skipped(k).session_dir, skipped(k).reason);
    end

    error('No valid sessions were loaded.');
end

num_sessions = numel(records);

for s = 1:num_sessions
    records{s}.session_index = s;
    records{s}.session_label = sprintf('S%d', s);
end

fprintf('\nLoaded %d valid sessions.\n', num_sessions);
fprintf('Skipped %d sessions.\n', numel(skipped));

fprintf('\nSession mapping retained in the MAT file:\n');

for s = 1:num_sessions
    fprintf('  %-4s -> %s/%s\n', ...
        records{s}.session_label, ...
        records{s}.session_parent_name, ...
        records{s}.catgt_name);
end

%% ======================= BUILD AND SAVE SUMMARY ========================

MultiSessionGPLClassDeltaR2 = buildMultiSessionDeltaSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, ...
    r2_split_mode, split_file_tag, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, class_short_names, ...
    r2_field_names, r2_field_labels, ...
    source_r2_field_names, source_r2_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, category_labels, ...
    output_prefix, output_base, feature_delta_definitions, neuron_population);

MultiSessionGPLClassDeltaR2.meta.created_by = ...
    'GPL_class_deltaR2_figure_plot.m';
MultiSessionGPLClassDeltaR2.meta.poster_plot_settings = poster_config;
MultiSessionGPLClassDeltaR2.notes.condition_plotting = [ ...
    'Latent-source plots are pooled separately for each GPL cell class. ', ...
    'Finite values from eight conditions are averaged per neuron; each ', ...
    'neuron supplies at most one point per contrast.'];
MultiSessionGPLClassDeltaR2.notes.feature_delta_plotting = [ ...
    'Selected population: ', population_description, '. Within each ', ...
    'source and effect, four matched values are averaged per neuron. ', ...
    'Both areas appear next to one another within each source category ', ...
    'in the main axes and full-range inset; color and legend identify area. ', ...
    'Original match arrays, unit IDs and session IDs are retained.'];
MultiSessionGPLClassDeltaR2.notes.poster_violin_summary = [ ...
    'Black vertical bar: Q1-Q3. Thin whiskers: observed values within ', ...
    'Q1 - 1.5*IQR and Q3 + 1.5*IQR. Median: horizontal bar. ', ...
    'Dots: neuron means with centered density-dependent jitter inside ', ...
    'the violin. A small unlabelled inset shows the full data range. ', ...
    'These are descriptive statistics, not standard errors.'];
MultiSessionGPLClassDeltaR2.notes.poster_statistics = [ ...
    'One neuron supplies at most one finite value to each violin. ', ...
    'One-sample signrank tail: feature Within/Across right, ', ...
    'feature FF/FB both, latent Across-Within left, latent FF-FB both. ', ...
    'Each violin shows its own nominal one-sample p-value with no ', ...
    'across-violin or across-figure multiple-testing adjustment. ', ...
    'Three latent neuron classes are compared separately by area and ', ...
    'contrast using Kruskal-Wallis; significant omnibus tests are ', ...
    'followed by three two-sided ranksum tests with Holm correction. ', ...
    'Figure labels use bold P: only post hoc pairwise values are ', ...
    'Holm-adjusted; violin and omnibus values are unadjusted. ', ...
    'All tests treat neurons as the sampling units.'];
poster_tests = struct( ...
    'figure_base', {}, 'family', {}, 'area_names', {}, ...
    'value_mode', {}, 'effect', {}, 'x_category_labels', {}, ...
    'neuron_counts', {}, 'statistics', {});

%% ========== SEPARATE LATENT-SOURCE DIFFERENCE FIGURES ==================

for g = 1:numel(group_names)
    for vm = 1:numel(plot_value_modes)
        value_mode = plot_value_modes{vm};
        for d = 1:numel(delta_names)
            P = buildPosterLatentDeltaDataLocal( ...
                MultiSessionGPLClassDeltaR2.pooled(g), ...
                stim_types, class_names, class_labels, ...
                d, delta_names{d}, value_mode);
            if d == 1
                test_tail = 'left';
            else
                test_tail = 'both';
            end
            P = posterComputeTestsLocal(P, test_tail, true, ...
                poster_significance_alpha);
            fig = plotPosterDeltaLocal(P, poster_config, ...
                poster_group_colors(g,:), group_names{g});
            figure_base = sprintf('%s_%s_ld%d_%s', ...
                output_base, group_file_tags{g}, d, value_mode);
            poster_tests(end + 1) = posterTestRecordLocal( ...
                figure_base, 'latent_balance', group_names(g), ...
                value_mode, P); %#ok<SAGROW>
            savePosterOutputLocal(fig, root_dir, figure_base, ...
                save_fig, save_svg, save_png, png_dpi, close_after_save);
        end
    end
end

%% ====== COMBINED-AREA FEATURE EFFECTS: SELECTED NEURON POPULATION ======

source_families = {[2, 1], [3, 4]}; % Within/Across; FF/FB
source_file_tags = {'witAcr', 'ffFb'};
for e = 1:numel(feature_delta_definitions)
    D = feature_delta_definitions(e);
    for sf = 1:numel(source_families)
        source_idx = source_families{sf};
        for vm = 1:numel(plot_value_modes)
            value_mode = plot_value_modes{vm};
            for g = 1:numel(group_names)
                pooled_effect = ...
                    MultiSessionGPLClassDeltaR2.feature_delta_pooled(g).effect.(D.name);
                Q = buildPosterFeatureDeltaDataLocal( ...
                    pooled_effect, D, class_names, source_idx, ...
                    feature_source_labels(source_idx), value_mode, neuron_population);
                if g == 1
                    P = Q;
                    P.groups = cell(numel(source_idx), numel(group_names));
                    P.neuron_counts = zeros(numel(source_idx), ...
                        numel(group_names));
                    P.legend_neuron_counts = zeros(1, numel(group_names));
                    P.area_names = group_names;
                end
                P.groups(:, g) = Q.groups(:, 1);
                P.neuron_counts(:, g) = Q.neuron_counts(:);
                P.legend_neuron_counts(g) = Q.legend_neuron_counts;
            end
            if sf == 1
                test_tail = 'right';
            else
                test_tail = 'both';
            end
            P = posterComputeTestsLocal(P, test_tail, false, ...
                poster_significance_alpha);
            fig = plotPosterDeltaLocal(P, poster_config, [], ...
                strjoin(group_names, ' / '));
            figure_base = sprintf('%s_fd%s_%s_%s', ...
                output_base, D.file_tag, source_file_tags{sf}, value_mode);
            poster_tests(end + 1) = posterTestRecordLocal( ...
                figure_base, 'stimulus_feature', group_names, ...
                value_mode, P); %#ok<SAGROW>
            savePosterOutputLocal(fig, root_dir, figure_base, ...
                save_fig, save_svg, save_png, png_dpi, close_after_save);
        end
    end
end

MultiSessionGPLClassDeltaR2.poster_statistics = poster_tests;
if save_mat
    mat_file = fullfile(root_dir, [output_base, '.mat']);
    save(mat_file, 'MultiSessionGPLClassDeltaR2', '-v7.3');
    fprintf('\nSaved MAT:\n  %s\n', mat_file);
end

fprintf('\nDone.\n');

%% =======================================================================
% Local functions
% ========================================================================

function [description, tag] = neuronPopulationDefinitionLocal(mode)
    switch mode
        case 'all_neurons'
            description = 'all model neurons (including GPL-invalid neurons)';
            tag = 'allN';
        case 'pcu_neurons'
            description = 'P/C/U neurons (excluding GPL-invalid neurons)';
            tag = 'pcuN';
        otherwise
            error('neuron_population must be ''all_neurons'' or ''pcu_neurons''.');
    end
end

function validatePosterOptionsLocal( ...
    area_colors, group_names, outlier_mode, central_percentile, ...
    point_size, point_alpha, point_jitter_width, violin_width, ...
    violin_alpha, violin_point_spread_gain, violin_point_edge_fraction)

    assertStringOptionLocal(outlier_mode, ...
        {'zoom_inset', 'full_range'}, 'poster_outlier_mode');
    if ~isnumeric(area_colors) || size(area_colors, 2) ~= 3 || ...
            size(area_colors, 1) < numel(unique(group_names)) || ...
            any(~isfinite(area_colors(:))) || ...
            any(area_colors(:) < 0 | area_colors(:) > 1)
        error('poster_area_colors needs one valid RGB row per area.');
    end
    validateattributes(central_percentile, {'numeric'}, ...
        {'scalar', '>=', 50, '<', 100, 'finite'}, ...
        mfilename, 'poster_central_percentile');
    values = [point_size, point_alpha, point_jitter_width, ...
        violin_width, violin_alpha, violin_point_spread_gain, ...
        violin_point_edge_fraction];
    if ~isnumeric(values) || any(~isfinite(values)) || ...
            point_size <= 0 || point_alpha <= 0 || point_alpha > 1 || ...
            point_jitter_width < 0 || violin_width <= 0 || ...
            violin_alpha <= 0 || violin_alpha > 1 || ...
            violin_point_spread_gain < 0 || ...
            violin_point_edge_fraction <= 0 || ...
            violin_point_edge_fraction >= 1
        error('Invalid poster point or violin settings.');
    end
end

function colors = resolvePosterAreaColorsLocal(group_names, area_colors)
    seen_areas = {};
    colors = zeros(numel(group_names), 3);
    for g = 1:numel(group_names)
        idx = find(strcmp(seen_areas, group_names{g}), 1);
        if isempty(idx)
            seen_areas{end + 1} = group_names{g}; %#ok<AGROW>
            idx = numel(seen_areas);
        end
        colors(g, :) = area_colors(idx, :);
    end
end

function y = posterFiniteRowMeanLocal(x)
% Each row is one neuron; an all-missing row remains NaN.
    is_valid = isfinite(x);
    x(~is_valid) = 0;
    counts = sum(is_valid, 2);
    y = sum(x, 2) ./ counts;
    y(counts == 0) = NaN;
end

function P = buildPosterLatentDeltaDataLocal( ...
    pooled_group, stim_types, class_names, class_labels, ...
    delta_idx, delta_name, value_mode)

    if strcmp(value_mode, 'raw')
        matrix_field = 'raw_delta_matrix';
        prefix = '\Delta R^2';
    else
        matrix_field = 'z_delta_matrix';
        prefix = '\Delta Z(R^2)';
    end
    if strcmp(delta_name, 'acr_vs_wit')
        comparison = 'Across - Within';
    elseif strcmp(delta_name, 'ff_vs_fb')
        comparison = 'Feedforward - Feedback';
    else
        error('Unknown latent difference: %s.', delta_name);
    end

    P.outer_labels = class_labels;
    P.effect_label = comparison;
    P.ylabel = [prefix, ' (', comparison, ')'];
    P.neuron_counts = zeros(numel(class_names), 1);
    P.groups = cell(numel(class_names), 1);

    for c = 1:numel(class_names)
        condition_matrix = [];
        reference_ids = [];
        reference_session = [];
        for st = 1:numel(stim_types)
            stim = stim_types{st};
            if ~isfield(pooled_group.stim, stim) || ...
                    ~isfield(pooled_group.stim.(stim).class, class_names{c})
                error('Missing pooled %s / %s.', stim, class_names{c});
            end
            C = pooled_group.stim.(stim).class.(class_names{c});
            A = C.(matrix_field);
            if ~isnumeric(A) || size(A, 2) < delta_idx
                error('Invalid %s in %s / %s.', ...
                    matrix_field, stim, class_names{c});
            end
            if st == 1
                reference_ids = C.unit_ids;
                reference_session = C.session_index;
                condition_matrix = nan(size(A, 1), numel(stim_types));
            elseif ~isequal(reference_ids, C.unit_ids) || ...
                    ~isequal(reference_session, C.session_index)
                error(['Cannot average conditions: neuron or session ', ...
                    'alignment differs for class %s.'], class_names{c});
            end
            condition_matrix(:, st) = double(A(:, delta_idx));
        end
        P.groups{c, 1} = posterFiniteRowMeanLocal(condition_matrix);
        P.neuron_counts(c) = sum(isfinite(P.groups{c, 1}));
    end
    % P/C/U are mutually exclusive; each finite class value is one neuron.
    P.legend_neuron_counts = sum(P.neuron_counts);
end

function P = buildPosterFeatureDeltaDataLocal( ...
    pooled_effect, D, class_names, source_idx, source_labels, value_mode, neuron_population)

    if strcmp(value_mode, 'raw')
        matrix_field = 'raw_delta_array';
        prefix = '\Delta R^2';
    else
        matrix_field = 'z_delta_array';
        prefix = '\Delta Z(R^2)';
    end
    colon_pos = find(D.title == ':', 1, 'last');
    if isempty(colon_pos)
        effect_description = char(D.title);
    else
        effect_description = strtrim(D.title(colon_pos + 1:end));
    end

    P.outer_labels = source_labels;
    P.effect_label = D.title;
    P.ylabel = [prefix, ' (', effect_description, ')'];
    P.neuron_counts = zeros(numel(source_idx), 1);
    P.groups = cell(numel(source_idx), 1);

    if strcmp(neuron_population, 'all_neurons')
        if ~isfield(pooled_effect, 'all_neurons')
            error('Missing all-model-neuron feature data for %s.', D.name);
        end
        C = pooled_effect.all_neurons;
        A = C.(matrix_field);
    else
        % Preserve the original class -> session -> unit row order so the
        % PCU mode reproduces the original numerical and plotted values.
        A = [];
        for c = 1:numel(class_names)
            if ~isfield(pooled_effect.class, class_names{c})
                error('Missing pooled feature class %s.', class_names{c});
            end
            C = pooled_effect.class.(class_names{c});
            this_array = C.(matrix_field);
            if ~isnumeric(this_array) || size(this_array, 2) < max(source_idx) || ...
                    size(this_array, 3) ~= numel(D.fixed_labels)
                error('Invalid %s for class %s.', matrix_field, class_names{c});
            end
            if c == 1
                A = this_array;
            else
                A = cat(1, A, this_array);
            end
        end
    end
    if ~isnumeric(A) || size(A, 2) < max(source_idx) || ...
            size(A, 3) ~= numel(D.fixed_labels)
        error('Invalid %s for %s (%s).', matrix_field, D.name, neuron_population);
    end
    used_neurons = false(size(A, 1), 1);
    for i = 1:numel(source_idx)
        source_matrix = reshape(double(A(:, source_idx(i), :)), ...
            size(A, 1), numel(D.fixed_labels));
        P.groups{i, 1} = posterFiniteRowMeanLocal(source_matrix);
        P.neuron_counts(i) = sum(isfinite(P.groups{i, 1}));
        used_neurons = used_neurons | isfinite(P.groups{i, 1});
    end
    % Rows retain session + unit identity and are shared by both sources.
    % Count the union of finite plotted values, not the sum of source counts.
    P.legend_neuron_counts = sum(used_neurons);
end

function P = posterComputeTestsLocal(P, tail, compare_classes, alpha)
% Test precisely the finite one-value-per-neuron vectors shown as dots.
% One-sample P values are nominal; Holm adjusts only post hoc class pairs.
    n_outer = size(P.groups, 1);
    n_inner = size(P.groups, 2);
    S = struct();
    S.unit = 'neuron';
    S.one_sample_method = 'Wilcoxon signed-rank';
    S.one_sample_tail = tail;
    S.alpha = alpha;
    S.one_sample_p_raw = nan(n_outer, n_inner);
    S.one_sample_n = zeros(n_outer, n_inner);
    S.one_sample_median = nan(n_outer, n_inner);
    S.one_sample_direction = cell(n_outer, n_inner);
    S.omnibus_method = 'Kruskal-Wallis';
    S.omnibus_p = NaN;
    S.pairwise_method = 'two-sided Wilcoxon rank-sum';
    S.pairwise_groups = [1, 2; 2, 3; 1, 3];
    S.pairwise_p_raw = nan(3, 1);
    S.pairwise_p_holm = nan(3, 1);
    S.adjustment = 'Nominal one-sample P; Holm for post hoc class pairs only';

    for k = 1:numel(P.groups)
        vals = double(P.groups{k}(:));
        vals = vals(isfinite(vals));
        S.one_sample_n(k) = numel(vals);
        if isempty(vals)
            continue;
        end
        S.one_sample_median(k) = median(vals);
        if all(vals == 0)
            S.one_sample_p_raw(k) = 1;
        else
            S.one_sample_p_raw(k) = signrank(vals, 0, ...
                'tail', tail);
            if strcmp(tail, 'both')
                % The signed-rank direction remains defined when the
                % observed sample median happens to equal zero.
                right_p = signrank(vals, 0, 'tail', 'right');
                if right_p < 0.5
                    S.one_sample_direction{k} = '+';
                elseif right_p > 0.5
                    S.one_sample_direction{k} = '-';
                end
            end
        end
    end
    if compare_classes
        if ~isequal(size(P.groups), [3, 1])
            error('Three-class comparison requires exactly three violins.');
        end
        class_values = cell(3, 1);
        for c = 1:3
            vals = double(P.groups{c}(:));
            class_values{c} = vals(isfinite(vals));
        end
        if all(cellfun(@numel, class_values) >= 2)
            all_values = vertcat(class_values{:});
            if max(all_values) == min(all_values)
                S.omnibus_p = 1;
            else
                class_index = vertcat( ...
                    ones(numel(class_values{1}), 1), ...
                    2 * ones(numel(class_values{2}), 1), ...
                    3 * ones(numel(class_values{3}), 1));
                S.omnibus_p = kruskalwallis( ...
                    all_values, class_index, 'off');
            end
            if isfinite(S.omnibus_p) && S.omnibus_p < alpha
                for pair_idx = 1:3
                    c1 = S.pairwise_groups(pair_idx, 1);
                    c2 = S.pairwise_groups(pair_idx, 2);
                    S.pairwise_p_raw(pair_idx) = ranksum( ...
                        class_values{c1}, class_values{c2}, ...
                        'tail', 'both');
                end
                S.pairwise_p_holm = posterHolmPValuesLocal( ...
                    S.pairwise_p_raw);
            end
        end
    end
    P.stats = S;
end

function adjusted = posterHolmPValuesLocal(p)
% Holm step-down adjusted p-values; retain NaN for absent tests.
    adjusted = nan(size(p));
    indices = find(isfinite(p));
    if isempty(indices)
        return;
    end
    [ordered_p, order] = sort(p(indices));
    previous = 0;
    m = numel(indices);
    for rank = 1:m
        previous = max(previous, min(1, (m - rank + 1) * ...
            ordered_p(rank)));
        adjusted(indices(order(rank))) = previous;
    end
end

function record = posterTestRecordLocal( ...
    figure_base, family, area_names, value_mode, P)
    record = struct();
    record.figure_base = figure_base;
    record.family = family;
    record.area_names = area_names;
    record.value_mode = value_mode;
    record.effect = P.effect_label;
    record.x_category_labels = P.outer_labels;
    record.neuron_counts = P.neuron_counts;
    record.statistics = P.stats;
end

function fig = plotPosterDeltaLocal(P, config, area_color, area_name)
% Rows are cell classes (latent) or reconstruction sources (features).
% For feature effects, columns are areas in legend order, so the x-axis
% hierarchy is source first, adjacent V1/MT second. The inset reuses x.
    n_outer = size(P.groups, 1);
    n_inner = size(P.groups, 2);
    combined_areas = isfield(P, 'area_names');
    if combined_areas
        if n_inner ~= numel(P.area_names) || ...
                n_inner ~= size(config.area_colors, 1)
            error('Area labels, data columns and colors do not match.');
        end
        colors = config.area_colors;
        legend_names = P.area_names;
    else
        colors = area_color;
        legend_names = {area_name};
    end

    x = nan(n_outer, n_inner);
    centers = nan(1, n_outer);
    separators = nan(1, max(n_outer - 1, 0));
    for i = 1:n_outer
        x(i, :) = (i - 1) * (n_inner + 1.3) + (1:n_inner);
        centers(i) = mean(x(i, :));
        if i > 1
            separators(i - 1) = ...
                (x(i - 1, end) + x(i, 1)) / 2;
        end
    end
    xlimits = [x(1, 1) - 0.65, x(end, end) + 0.65];

    % One shared main y range for both areas within this figure.
    y_all = vertcat(P.groups{:});
    y_all = double(y_all(isfinite(y_all)));
    is_zoom = false;
    if isempty(y_all)
        ylimit = 0.1;
        full_limit = ylimit;
    else
        full_limit = 1.08 * max(abs(y_all));
        if strcmp(config.outlier_mode, 'zoom_inset')
            ylimit = 1.12 * posterEmpiricalPercentileLocal( ...
                abs(y_all), config.central_percentile);
            for k = 1:numel(P.groups)
                vals = P.groups{k};
                vals = vals(isfinite(vals));
                if isempty(vals)
                    continue;
                end
                [q1, q3, whisker_low, whisker_high] = ...
                    posterTukeySummaryLocal(vals);
                ylimit = max(ylimit, 1.1 * max( ...
                    abs([median(vals), q1, q3])));
                ylimit = max(ylimit, 1.08 * max( ...
                    abs([whisker_low, whisker_high])));
            end
            ylimit = max(ylimit, min(full_limit, 0.002));
            is_zoom = any(abs(y_all) > ylimit);
        else
            ylimit = full_limit;
        end
        if ~isfinite(ylimit) || ylimit <= 0
            ylimit = 0.1;
        end
        if ~isfinite(full_limit) || full_limit <= 0
            full_limit = ylimit;
        end
        if ~is_zoom
            ylimit = max(ylimit, full_limit);
        end
    end

    fig = figure('Name', [area_name, ' | ', P.effect_label], ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Visible', config.figure_visible, ...
        'Position', [100, 100, config.figure_width, config.figure_height], ...
        'Renderer', 'painters');
    ax = axes('Parent', fig);
    if is_zoom
        main_width = 0.69;
    else
        main_width = 0.85;
    end
    if combined_areas
        main_height = 0.57;
    else
        % Three possible class-pair brackets have room above the axis.
        main_height = 0.50;
    end
    main_pos = [0.09, 0.27, main_width, main_height];
    set(ax, 'Position', main_pos);
    hold(ax, 'on');
    plot(ax, xlimits, [0, 0], '--', 'Color', [0.6, 0.6, 0.6], ...
        'LineWidth', 0.8, 'HandleVisibility', 'off');
    for i = 1:numel(separators)
        plot(ax, [separators(i), separators(i)], ...
            [-ylimit, ylimit], '-', 'Color', [0.86, 0.86, 0.86], ...
            'LineWidth', 0.7, 'HandleVisibility', 'off');
    end

    inset = [];
    if is_zoom
        inset = axes('Parent', fig, 'Position', ...
            [0.82, 0.52, 0.15, 0.35]);
        hold(inset, 'on');
        plot(inset, xlimits, [0, 0], '--', ...
            'Color', [0.6, 0.6, 0.6], 'LineWidth', 0.6, ...
            'HandleVisibility', 'off');
        for i = 1:numel(separators)
            plot(inset, [separators(i), separators(i)], ...
                [-full_limit, full_limit], '-', ...
                'Color', [0.86, 0.86, 0.86], 'LineWidth', 0.5, ...
                'HandleVisibility', 'off');
        end
        set(inset, 'Color', [0.98, 0.98, 0.98]);
    end

    clipped_count = 0;
    for i = 1:n_outer
        for j = 1:n_inner
            vals = double(P.groups{i, j}(:));
            vals = vals(isfinite(vals));
            if isempty(vals)
                continue;
            end
            color = colors(min(j, size(colors, 1)), :);
            x0 = x(i, j);
            profile = posterDrawSummaryLocal( ...
                ax, x0, vals, config, color, ylimit);
            jitter = posterViolinJitterLocal( ...
                vals, profile, config.point_jitter_width, ...
                config.violin_width, ...
                config.violin_point_spread_gain, ...
                config.violin_point_edge_fraction, ...
                10000 * i + 100 * j);
            visible = abs(vals) <= ylimit;
            posterScatterLocal(ax, x0 + jitter(visible), ...
                vals(visible), color, config.point_size, ...
                config.point_alpha);
            posterDrawInnerMarksLocal(ax, x0, vals);

            if is_zoom
                num_high = sum(vals > ylimit);
                num_low = sum(vals < -ylimit);
                clipped_count = clipped_count + num_high + num_low;
                posterScatterLocal(inset, x0 + jitter, vals, ...
                    color, max(2, config.point_size * 0.65), 0.35);
            end
        end
    end

    xlim(ax, xlimits);
    ylim(ax, [-ylimit, ylimit]);
    set(ax, 'XColor', [0.3, 0.3, 0.3], ...
        'YColor', [0.25, 0.25, 0.25], 'TickDir', 'out', ...
        'LineWidth', 1, 'FontName', config.font_name, ...
        'FontSize', config.axis_font_size, ...
        'XTick', centers, 'XTickLabel', P.outer_labels, ...
        'TickLabelInterpreter', 'none');
    box(ax, 'off');
    ylabel(ax, P.ylabel, 'Interpreter', 'tex', ...
        'FontName', config.font_name, 'FontSize', ...
        config.axis_font_size + 2, 'Color', [0.25, 0.25, 0.25]);

    if is_zoom
        xlim(inset, xlimits);
        ylim(inset, [-full_limit, full_limit]);
        if combined_areas
            inset_labels = P.outer_labels;
        else
            inset_labels = repmat({''}, 1, n_outer);
        end
        set(inset, 'XTick', centers, 'XTickLabel', inset_labels, ...
            'TickLabelInterpreter', 'none', ...
            'FontName', config.font_name, ...
            'FontSize', max(7, config.axis_font_size - 3), ...
            'TickDir', 'out', 'YColor', [0.4, 0.4, 0.4], ...
            'LineWidth', 0.8);
        box(inset, 'off');
    end

    annotation(fig, 'textbox', [0.09, 0.952, 0.66, 0.038], ...
        'String', P.effect_label, 'Interpreter', 'none', ...
        'EdgeColor', 'none', 'FontName', config.font_name, ...
        'FontSize', config.axis_font_size + 2, ...
        'Color', [0.3, 0.3, 0.3]);
    legend_markers = gobjects(1, numel(legend_names));
    legend_labels = cell(size(legend_names));
    for j = 1:numel(legend_names)
        legend_markers(j) = plot(ax, nan, nan, 'o', ...
            'LineStyle', 'none', 'MarkerFaceColor', colors(j,:), ...
            'MarkerEdgeColor', colors(j,:), 'MarkerSize', 7);
        legend_labels{j} = sprintf('%s: n=%d', ...
            legend_names{j}, P.legend_neuron_counts(j));
    end
    lgd = legend(ax, legend_markers, legend_labels, 'Box', 'off', ...
        'Interpreter', 'none', 'Location', 'none', ...
        'Orientation', 'horizontal', 'FontName', config.font_name, ...
        'FontSize', config.axis_font_size);
    set(lgd, 'Position', [0.79, 0.94, 0.18, 0.04]);
    set(ax, 'Position', main_pos); % Legend must not resize the data axis.
    posterAnnotateSignificanceLocal( ...
        fig, P, config, x, xlimits, main_pos, combined_areas);
    fig.UserData = struct('area', {legend_names}, ...
        'effect', P.effect_label, 'neuron_counts', P.neuron_counts, ...
        'legend_neuron_counts', P.legend_neuron_counts, ...
        'is_neuron_average', true, ...
        'main_abs_limit', ylimit, 'full_abs_limit', full_limit, ...
        'points_outside_main_axis', clipped_count, ...
        'x_positions', x, 'x_source_centers', centers, ...
        'statistics', P.stats);
end

function posterAnnotateSignificanceLocal( ...
    fig, P, config, x, xlimits, main_pos, combined_areas)
% Figure-coordinate annotations reserve space ABOVE the original y axis.
% Consequently significance labels cannot change the delta-R2 tick range.
    xfig = main_pos(1) + ...
        (x - xlimits(1)) ./ diff(xlimits) .* main_pos(3);
    top = main_pos(2) + main_pos(4);
    xpos = sort(xfig(:));
    if numel(xpos) > 1
        box_width = min(0.15, 0.90 * min(diff(xpos)));
    else
        box_width = 0.15;
    end
    ink = [0.23, 0.23, 0.23];

    for i = 1:size(P.groups, 1)
        for j = 1:size(P.groups, 2)
            p = P.stats.one_sample_p_raw(i, j);
            if ~isfinite(p)
                continue;
            end
            direction = '';
            if strcmp(P.stats.one_sample_tail, 'both') && ...
                    p < config.significance_alpha
                direction = P.stats.one_sample_direction{i, j};
            end
            label = sprintf('%s %s%s', ...
                posterPValueTextLocal(p), direction, ...
                posterStarsLocal(p, config.significance_alpha));
            annotation(fig, 'textbox', ...
                [xfig(i, j) - box_width / 2, top + 0.008, ...
                 box_width, 0.028], ...
                'String', label, 'Interpreter', 'tex', ...
                'EdgeColor', 'none', 'Color', ink, ...
                'FontName', config.font_name, 'FontSize', 9, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle');
        end
    end

    if combined_areas
        return;
    end
    if isfinite(P.stats.omnibus_p)
        kw_label = ['Kruskal-Wallis: ', ...
            posterPValueTextLocal(P.stats.omnibus_p)];
        annotation(fig, 'textbox', [0.09, 0.16, 0.65, 0.04], ...
            'String', kw_label, 'Interpreter', 'tex', ...
            'EdgeColor', 'none', 'Color', ink, ...
            'FontName', config.font_name, ...
            'FontSize', config.axis_font_size, ...
            'HorizontalAlignment', 'left');
    end

    significant_pairs = find(isfinite(P.stats.pairwise_p_holm) & ...
        P.stats.pairwise_p_holm < config.significance_alpha);
    for level = 1:numel(significant_pairs)
        pair_idx = significant_pairs(level);
        groups = P.stats.pairwise_groups(pair_idx, :);
        left = xfig(groups(1), 1);
        right = xfig(groups(2), 1);
        y = top + 0.073 + 0.036 * (level - 1);
        annotation(fig, 'line', [left, right], [y, y], ...
            'Color', ink, 'LineWidth', 1);
        annotation(fig, 'line', [left, left], [y - 0.010, y], ...
            'Color', ink, 'LineWidth', 1);
        annotation(fig, 'line', [right, right], [y - 0.010, y], ...
            'Color', ink, 'LineWidth', 1);
        p = P.stats.pairwise_p_holm(pair_idx);
        label = sprintf('%s %s', ...
            posterPValueTextLocal(p), ...
            posterStarsLocal(p, config.significance_alpha));
        annotation(fig, 'textbox', ...
            [(left + right) / 2 - 0.075, y + 0.003, 0.15, 0.026], ...
            'String', label, 'Interpreter', 'tex', ...
            'EdgeColor', 'none', 'Color', ink, ...
            'FontName', config.font_name, 'FontSize', 9, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle');
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

function posterDrawInnerMarksLocal(ax, x0, vals)
% Black Q1-Q3 bar, thin observed Tukey whiskers, horizontal median mark.
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
        [median(vals), median(vals)], '-', ...
        'Color', [1, 1, 1], 'LineWidth', 4.5, ...
        'HandleVisibility', 'off');
    plot(ax, [x0 - 0.2, x0 + 0.2], ...
        [median(vals), median(vals)], '-', ...
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

function savePosterOutputLocal(fig, root_dir, figure_base, ...
    save_fig, save_svg, save_png, dpi, close_after_save)
    if save_fig
        saveFigLocal(fig, fullfile(root_dir, [figure_base, '.fig']));
    end
    if save_svg
        saveSvgLocal(fig, fullfile(root_dir, [figure_base, '.svg']));
    end
    if save_png
        savePngLocal(fig, fullfile(root_dir, [figure_base, '.png']), dpi);
    end
    if save_fig || save_svg || save_png
        fprintf('Saved figure: %s\n', figure_base);
    end
    if close_after_save
        close(fig);
    end
end

function definitions = buildFeatureDeltaDefinitionsLocal()
% Each row replaces exactly one position in the canonical
% stimulus-type / size / contrast label with a matched subtraction.

    template = struct( ...
        'name', '', ...
        'file_tag', '', ...
        'title', '', ...
        'subscript', '', ...
        'fixed_labels', {{}}, ...
        'positive_stim', {{}}, ...
        'negative_stim', {{}});

    definitions = repmat(template, 1, 3);

    definitions(1).name = 'stimtype_G_minus_P';
    definitions(1).file_tag = 'GP';
    definitions(1).title = 'Stimulus type effect: Grating - Plaid';
    definitions(1).subscript = 'GP';
    definitions(1).fixed_labels = { ...
        '\Delta-S-L', '\Delta-S-H', ...
        '\Delta-L-L', '\Delta-L-H'};
    definitions(1).positive_stim = { ...
        'G_S_L', 'G_S_H', 'G_L_L', 'G_L_H'};
    definitions(1).negative_stim = { ...
        'P_S_L', 'P_S_H', 'P_L_L', 'P_L_H'};

    definitions(2).name = 'size_S_minus_L';
    definitions(2).file_tag = 'SL';
    definitions(2).title = 'Size effect: Small - Large';
    definitions(2).subscript = 'SL';
    definitions(2).fixed_labels = { ...
        'G-\Delta-L', 'G-\Delta-H', ...
        'P-\Delta-L', 'P-\Delta-H'};
    definitions(2).positive_stim = { ...
        'G_S_L', 'G_S_H', 'P_S_L', 'P_S_H'};
    definitions(2).negative_stim = { ...
        'G_L_L', 'G_L_H', 'P_L_L', 'P_L_H'};

    definitions(3).name = 'contrast_Low_minus_High';
    definitions(3).file_tag = 'LH';
    definitions(3).title = 'Contrast effect: Low - High';
    definitions(3).subscript = 'LH';
    definitions(3).fixed_labels = { ...
        'G-S-\Delta', 'G-L-\Delta', ...
        'P-S-\Delta', 'P-L-\Delta'};
    definitions(3).positive_stim = { ...
        'G_S_L', 'G_L_L', 'P_S_L', 'P_L_L'};
    definitions(3).negative_stim = { ...
        'G_S_H', 'G_L_H', 'P_S_H', 'P_L_H'};
end

function validatePosterInputLocal( ...
    root_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, gpl_mat_name, group_names, ...
    class_names, class_labels, class_short_names, class_markers, ...
    r2_field_names, r2_field_labels, ...
    source_field_names, source_field_labels, ...
    feature_source_labels, delta_names, delta_labels, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, feature_delta_definitions, ...
    save_mat, save_fig, save_svg, save_png, close_after_save, ...
    figure_visible, png_dpi, figure_width, figure_height)

    requireNonemptyTextLocal(root_dir, 'root_dir');
    if ~isfolder(char(root_dir))
        error('root_dir does not exist: %s', char(root_dir));
    end
    requireNonemptyTextLocal(data_content, 'data_content');
    requireNonemptyTextLocal(reconstruction_suffix, 'reconstruction_suffix');
    requireNonemptyTextLocal(gpl_mat_name, 'gpl_mat_name');
    assertStringOptionLocal(model_mode, ...
        {'all_condition_model', 'condition_specific_models'}, ...
        'model_mode');
    assertStringOptionLocal(figure_visible, {'on', 'off'}, ...
        'figure_visible');
    validateattributes(runIdx, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'runIdx');
    if ~isequal(group_names, {'V1', 'MT'})
        error('This poster layout expects V1 and MT in that group order.');
    end
    validateParallelLabelListsLocal(class_names, class_labels, ...
        'class_names', 'class_labels');
    validateParallelLabelListsLocal(class_names, class_short_names, ...
        'class_names', 'class_short_names');
    validateParallelLabelListsLocal(class_names, class_markers, ...
        'class_names', 'class_markers');
    validateParallelLabelListsLocal(r2_field_names, r2_field_labels, ...
        'r2_field_names', 'r2_field_labels');
    if ~isequal(r2_field_names, {'use_all', 'use_across', ...
            'use_within', 'use_feedforward', 'use_feedback'})
        error('The R2 fields must keep the expected input-file order.');
    end
    validateParallelLabelListsLocal(source_field_names, ...
        source_field_labels, 'source fields', 'source labels');
    validateParallelLabelListsLocal(source_field_names, ...
        feature_source_labels, 'source fields', 'feature labels');
    validateParallelLabelListsLocal(delta_names, delta_labels, ...
        'delta_names', 'delta_labels');
    validateParallelLabelListsLocal(delta_names, delta_positive_fields, ...
        'delta_names', 'delta_positive_fields');
    validateParallelLabelListsLocal(delta_names, delta_negative_fields, ...
        'delta_names', 'delta_negative_fields');
    validateParallelLabelListsLocal(stim_types, category_labels, ...
        'stim_types', 'category_labels');
    for k = 1:numel(source_field_names)
        if ~any(strcmp(source_field_names{k}, r2_field_names))
            error('Unknown source R2 field: %s.', source_field_names{k});
        end
    end
    for d = 1:numel(delta_names)
        if ~any(strcmp(delta_positive_fields{d}, source_field_names)) || ...
                ~any(strcmp(delta_negative_fields{d}, source_field_names))
            error('Invalid source field in delta %s.', delta_names{d});
        end
    end
    validateFeatureDeltaDefinitionsLocal(feature_delta_definitions, ...
        stim_types);
    validateLogicalScalarLocal(save_mat, 'save_mat');
    validateLogicalScalarLocal(save_fig, 'save_fig');
    validateLogicalScalarLocal(save_svg, 'save_svg');
    validateLogicalScalarLocal(save_png, 'save_png');
    validateLogicalScalarLocal(close_after_save, 'close_after_save');
    validateattributes(png_dpi, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'png_dpi');
    validateattributes(figure_width, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'figure_width');
    validateattributes(figure_height, {'numeric'}, ...
        {'scalar', 'positive', 'finite'}, mfilename, 'figure_height');
end

function validateFeatureDeltaDefinitionsLocal(definitions, stim_types)

    required_fields = { ...
        'name', 'file_tag', 'title', 'subscript', ...
        'fixed_labels', 'positive_stim', 'negative_stim'};

    if ~isstruct(definitions) || numel(definitions) ~= 3
        error('feature_delta_definitions must contain exactly 3 entries.');
    end

    definition_names = cell(1, numel(definitions));
    file_tags = cell(1, numel(definitions));

    for e = 1:numel(definitions)
        D = definitions(e);

        for f = 1:numel(required_fields)
            if ~isfield(D, required_fields{f})
                error(['Feature-delta definition %d is missing ', ...
                    'field %s.'], e, required_fields{f});
            end
        end

        requireNonemptyTextLocal(D.name, ...
            sprintf('feature_delta_definitions(%d).name', e));
        requireNonemptyTextLocal(D.file_tag, ...
            sprintf('feature_delta_definitions(%d).file_tag', e));
        requireNonemptyTextLocal(D.title, ...
            sprintf('feature_delta_definitions(%d).title', e));
        requireNonemptyTextLocal(D.subscript, ...
            sprintf('feature_delta_definitions(%d).subscript', e));

        if ~isvarname(char(D.name))
            error('Feature-delta name %s is not a valid field name.', ...
                char(D.name));
        end

        if ~iscell(D.fixed_labels) || ...
                ~iscell(D.positive_stim) || ...
                ~iscell(D.negative_stim) || ...
                numel(D.fixed_labels) ~= 4 || ...
                numel(D.positive_stim) ~= 4 || ...
                numel(D.negative_stim) ~= 4
            error(['Feature-delta definition %s must contain exactly ', ...
                'four labels and four matched stimulus pairs.'], D.name);
        end

        for k = 1:4
            requireNonemptyTextLocal(D.fixed_labels{k}, ...
                sprintf('%s.fixed_labels{%d}', D.name, k));
            requireNonemptyTextLocal(D.positive_stim{k}, ...
                sprintf('%s.positive_stim{%d}', D.name, k));
            requireNonemptyTextLocal(D.negative_stim{k}, ...
                sprintf('%s.negative_stim{%d}', D.name, k));

            if ~any(strcmp(D.positive_stim{k}, stim_types)) || ...
                    ~any(strcmp(D.negative_stim{k}, stim_types))
                error(['Feature-delta definition %s pair %d refers to ', ...
                    'a stimulus field unavailable in r2_split_mode.'], ...
                    D.name, k);
            end

            if strcmp(D.positive_stim{k}, D.negative_stim{k})
                error(['Feature-delta definition %s pair %d subtracts ', ...
                    'a stimulus field from itself.'], D.name, k);
            end
        end

        definition_names{e} = char(D.name);
        file_tags{e} = char(D.file_tag);
    end

    if numel(unique(definition_names)) ~= numel(definition_names) || ...
            numel(unique(file_tags)) ~= numel(file_tags)
        error('Feature-delta names and file tags must be unique.');
    end
end

function validateLogicalScalarLocal(value, var_name)
    if ~(islogical(value) || isnumeric(value)) || ...
            ~isscalar(value) || ~isfinite(double(value)) || ...
            ~ismember(double(value), [0, 1])
        error('%s must be one logical scalar.', var_name);
    end
end

function validateParallelLabelListsLocal( ...
    names, labels, names_var, labels_var)

    if ~iscell(names) || ~iscell(labels) || isempty(names) || ...
            numel(names) ~= numel(labels)
        error('%s and %s must be nonempty equal-length cell arrays.', ...
            names_var, labels_var);
    end

    for i = 1:numel(names)
        requireNonemptyTextLocal(names{i}, ...
            sprintf('%s{%d}', names_var, i));
        requireNonemptyTextLocal(labels{i}, ...
            sprintf('%s{%d}', labels_var, i));
    end

    names_char = cellfun(@char, names, 'UniformOutput', false);

    if numel(unique(names_char, 'stable')) ~= numel(names_char)
        error('%s contains duplicate entries.', names_var);
    end
end

function requireNonemptyTextLocal(value, var_name)
    if ~(ischar(value) || (isstring(value) && isscalar(value))) || ...
            isempty(char(value))
        error('%s must be nonempty text.', var_name);
    end
end

function values = normalizeTextCellLocal(values, var_name)
    if isstring(values)
        values = cellstr(values);
    elseif ischar(values)
        values = {values};
    elseif iscell(values)
        for i = 1:numel(values)
            requireNonemptyTextLocal(values{i}, ...
                sprintf('%s{%d}', var_name, i));
            values{i} = char(values{i});
        end
    else
        error('%s must be text or a cell array of text.', var_name);
    end

    values = reshape(values, 1, []);
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

function [group_display_names, group_file_tags] = ...
        buildGroupLabelsLocal(group_names)
    num_groups = numel(group_names);
    group_display_names = cell(1, num_groups);
    group_file_tags = cell(1, num_groups);

    for g = 1:num_groups
        group_display_names{g} = sprintf( ...
            'Group %d: %s', g, group_names{g});
        group_file_tags{g} = sprintf( ...
            'G%02d_%s', g, makeSafeGroupNameTagLocal(group_names{g}));
    end
end

function tag = makeSafeGroupNameTagLocal(group_name)
    tag = strtrim(char(string(group_name)));
    tag = regexprep(tag, '[^A-Za-z0-9_-]+', '_');
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_+|_+$', '');

    if isempty(tag)
        tag = 'area';
    end
end

function assertStringOptionLocal(value, valid_options, var_name)
    if ~ischar(value) && ~(isstring(value) && isscalar(value))
        error('%s must be a char or scalar string.', var_name);
    end

    value = char(value);

    if ~any(strcmp(value, valid_options))
        error('%s = ''%s'' is invalid. Valid options are: %s', ...
            var_name, value, strjoin(valid_options, ', '));
    end
end

function tag = makeModelTagLocal(model_mode)
    switch char(model_mode)
        case 'all_condition_model'
            tag = 'all_condition_M';

        case 'condition_specific_models'
            tag = 'condition_specific_M';

        otherwise
            error('Unknown model_mode: %s', model_mode);
    end
end

function session_dirs = findCatgtSessionDirsLocal(root_dir)
    listing = dir(fullfile(root_dir, '*', 'catgt_*'));
    listing = listing([listing.isdir]);

    if isempty(listing)
        session_dirs = {};
        return;
    end

    n = numel(listing);
    session_dirs = cell(n, 1);
    session_numbers = nan(n, 1);
    parent_names = cell(n, 1);
    catgt_names = cell(n, 1);

    for k = 1:n
        session_dirs{k} = fullfile(listing(k).folder, listing(k).name);
        catgt_names{k} = listing(k).name;

        [parent_dir, ~] = fileparts(session_dirs{k});
        [~, parent_names{k}] = fileparts(parent_dir);
        session_numbers(k) = ...
            extractSessionNumberFromNameLocal(parent_names{k});
    end

    T = table(session_numbers, parent_names, catgt_names, session_dirs, ...
        'VariableNames', { ...
        'session_number', 'session_name', 'catgt_name', 'session_dir'});

    T = sortrows(T, { ...
        'session_number', 'session_name', 'catgt_name'});

    session_dirs = T.session_dir(:)';
end

function session_number = extractSessionNumberFromNameLocal(session_name)
    tokens = regexp(session_name, 'p(\d+)', 'tokens', 'once');

    if isempty(tokens)
        session_number = inf;
        return;
    end

    session_number = str2double(tokens{1});

    if ~isfinite(session_number)
        session_number = inf;
    end
end

function [rec, reference] = readOneSessionLocal( ...
    session_dir, data_content, model_mode, r2_split_mode, ...
    split_file_tag, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, gpl_mat_name, r2_field_names, ...
    source_field_names, delta_names, ...
    delta_positive_fields, delta_negative_fields, ...
    stim_types, category_labels, feature_delta_definitions, reference, neuron_population)

    [parent_dir, catgt_name] = fileparts(session_dir);
    [~, session_parent_name] = fileparts(parent_dir);

    prefix = 'catgt_';

    if ~startsWith(catgt_name, prefix) || ...
            numel(catgt_name) <= numel(prefix)
        error('Unrecognized CatGT folder name: %s', catgt_name);
    end

    run_g = catgt_name(numel(prefix) + 1:end);
    run_tokens = regexp(run_g, '^(.+)_g(\d+)$', 'tokens', 'once');

    if isempty(run_tokens)
        error(['CatGT folder name must end in _g<number>: %s'], ...
            catgt_name);
    end

    run_name = run_tokens{1};
    run_ind = str2double(run_tokens{2});

    r2_file = resolveR2FileLocal( ...
        session_dir, data_content, model_mode, runIdx, ...
        reconstruction_suffix, split_file_tag);

    if ~isfile(r2_file)
        error('Required reconstruction R2 file not found: %s', r2_file);
    end

    S = load(r2_file, 'stimtype_recon_R2');

    if ~isfield(S, 'stimtype_recon_R2')
        error('%s does not contain stimtype_recon_R2.', r2_file);
    end

    R = S.stimtype_recon_R2;
    num_groups = numel(group_names);

    validateStimtypeR2Local( ...
        R, data_content, model_mode, num_groups, r2_field_names, ...
        r2_split_mode, split_file_tag, stim_types, ...
        category_labels, r2_file);

    reference = validateOrInitializeReferenceLocal( ...
        reference, R, group_names, group_display_names, ...
        group_file_tags, r2_field_names, source_field_names, delta_names, ...
        r2_split_mode, stim_types, category_labels, session_dir);

    empty_group = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'unit_ids', [], ...
        'gpl_file', '', ...
        'class_info', struct(), ...
        'zscore', struct(), ...
        'r2_zscore', struct(), ...
        'feature_delta', struct(), ...
        'feature_delta_zscore', struct(), ...
        'stim', struct());

    groups = repmat(empty_group, 1, num_groups);

    fprintf('  R2 file: %s\n', r2_file);

    [gpl_group_by_index, gpl_file_by_index] = ...
        loadGplGroupsByModelIndexLocal( ...
        session_dir, gpl_mat_name, num_groups);

    source_r2_indices = nan(1, numel(source_field_names));

    for f = 1:numel(source_field_names)
        source_r2_indices(f) = find(strcmp( ...
            r2_field_names, source_field_names{f}), 1, 'first');
    end

    delta_positive_indices = nan(1, numel(delta_names));
    delta_negative_indices = nan(1, numel(delta_names));

    for d = 1:numel(delta_names)
        delta_positive_indices(d) = find(strcmp( ...
            source_field_names, delta_positive_fields{d}), ...
            1, 'first');
        delta_negative_indices(d) = find(strcmp( ...
            source_field_names, delta_negative_fields{d}), ...
            1, 'first');
    end

    for g = 1:num_groups
        model_ids = double(R.unit_ids_by_group{g}(:));
        gpl_results = gpl_group_by_index{g};
        gpl_file = gpl_file_by_index{g};

        class_info = validateAndExtractClassesLocal( ...
            gpl_results, model_ids, ...
            group_display_names{g}, gpl_file);

        groups(g).group_index = g;
        groups(g).group_name = group_names{g};
        groups(g).group_display_name = group_display_names{g};
        groups(g).group_file_tag = group_file_tags{g};
        groups(g).unit_ids = model_ids;
        groups(g).gpl_file = gpl_file;
        groups(g).class_info = class_info;

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            raw_r2_matrix = nan( ...
                numel(model_ids), numel(r2_field_names));

            for f = 1:numel(r2_field_names)
                raw_r2_matrix(:, f) = getGroupR2VectorLocal( ...
                    R.(stim_name), r2_field_names{f}, g);
            end

            source_r2_matrix = raw_r2_matrix(:, source_r2_indices);

            raw_delta_matrix = nan( ...
                numel(model_ids), numel(delta_names));

            for d = 1:numel(delta_names)
                raw_delta_matrix(:, d) = ...
                    source_r2_matrix(:, delta_positive_indices(d)) - ...
                    source_r2_matrix(:, delta_negative_indices(d));
            end

            groups(g).stim.(stim_name).raw_r2_matrix = ...
                raw_r2_matrix;
            groups(g).stim.(stim_name).z_r2_matrix = ...
                nan(size(raw_r2_matrix));
            groups(g).stim.(stim_name).source_r2_matrix = ...
                source_r2_matrix;
            groups(g).stim.(stim_name).z_source_r2_matrix = ...
                nan(size(source_r2_matrix));
            groups(g).stim.(stim_name).raw_delta_matrix = ...
                raw_delta_matrix;
            groups(g).stim.(stim_name).z_delta_matrix = ...
                nan(size(raw_delta_matrix));
            groups(g).stim.(stim_name).raw_delta = struct();
            groups(g).stim.(stim_name).z_delta = struct();

            for d = 1:numel(delta_names)
                groups(g).stim.(stim_name).raw_delta.( ...
                    delta_names{d}) = raw_delta_matrix(:, d);
                groups(g).stim.(stim_name).z_delta.( ...
                    delta_names{d}) = nan(numel(model_ids), 1);
            end
        end

        % The selected population supplies ONE common reference mean/SD
        % for every feature and balance within this session and area.
        normalization_mask = true(numel(model_ids), 1);
        if strcmp(neuron_population, 'pcu_neurons')
            normalization_mask = class_info.pattern | ...
                class_info.component | class_info.unclassified;
            if ~any(normalization_mask)
                error('%s contains no pattern/component/unclassified neurons.', ...
                    group_display_names{g});
            end
        end
        r2_zscore_pool = [];

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            this_r2 = groups(g).stim.(stim_name).raw_r2_matrix;
            this_r2 = this_r2(normalization_mask, :);
            r2_zscore_pool = [ ...
                r2_zscore_pool; this_r2(:)]; %#ok<AGROW>
        end

        num_possible = numel(r2_zscore_pool);
        r2_zscore_pool = r2_zscore_pool(isfinite(r2_zscore_pool));

        if numel(r2_zscore_pool) < 2
            error(['%s has fewer than two finite R2 values in the ', ...
                'session-area R2 z-score pool.'], ...
                group_display_names{g});
        end

        pool_mean = mean(r2_zscore_pool);
        pool_sd = std(r2_zscore_pool, 0);

        if ~isfinite(pool_mean) || ~isfinite(pool_sd) || pool_sd <= 0
            error(['%s has an invalid or zero sample SD in the ', ...
                'session-area R2 z-score pool.'], ...
                group_display_names{g});
        end

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            raw_r2_matrix = ...
                groups(g).stim.(stim_name).raw_r2_matrix;
            z_r2_matrix = (raw_r2_matrix - pool_mean) ./ pool_sd;
            z_source_r2_matrix = ...
                z_r2_matrix(:, source_r2_indices);
            z_delta_matrix = nan( ...
                numel(model_ids), numel(delta_names));

            for d = 1:numel(delta_names)
                z_delta_matrix(:, d) = ...
                    z_source_r2_matrix(:, delta_positive_indices(d)) - ...
                    z_source_r2_matrix(:, delta_negative_indices(d));
            end

            groups(g).stim.(stim_name).z_r2_matrix = z_r2_matrix;
            groups(g).stim.(stim_name).z_source_r2_matrix = ...
                z_source_r2_matrix;
            groups(g).stim.(stim_name).z_delta_matrix = z_delta_matrix;

            for d = 1:numel(delta_names)
                groups(g).stim.(stim_name).z_delta.( ...
                    delta_names{d}) = ...
                    z_delta_matrix(:, d);
            end
        end

        normalization = struct();
        normalization.neuron_population = neuron_population;
        normalization.pool_mean = pool_mean;
        normalization.pool_sd = pool_sd;
        normalization.std_normalization = 0;
        normalization.n_finite = numel(r2_zscore_pool);
        normalization.n_possible = num_possible;
        normalization.n_nonfinite = ...
            num_possible - numel(r2_zscore_pool);
        population_description = neuronPopulationDefinitionLocal(neuron_population);
        normalization.pooling_scope = [ ...
            'all finite raw R2 values from ', population_description, ' pooled across ', ...
            num2str(numel(r2_field_names)), ...
            ' reconstruction fields (all, across, within, FF, FB) ', ...
            'and all ', num2str(numel(stim_types)), ...
            ' stimulus groups within this session and model group/area'];
        normalization.operation_order = [ ...
            'Apply the common R2 mean and sample SD first; then ', ...
            'calculate every latent-source or stimulus-feature difference'];

        groups(g).zscore = normalization;
        groups(g).r2_zscore = normalization;

        groups(g).feature_delta = computeFeatureDeltasForGroupLocal( ...
            groups(g).stim, numel(source_field_names), ...
            feature_delta_definitions, group_display_names{g});
        groups(g).feature_delta_zscore = normalization;

        fprintf(['  %s: pattern=%d, component=%d, ', ...
            'unclassified=%d, invalid=%d, ', ...
            'R2 z-mean=%.6g, R2 z-SD=%.6g, z-N=%d/%d\n'], ...
            group_display_names{g}, ...
            sum(class_info.pattern), ...
            sum(class_info.component), ...
            sum(class_info.unclassified), ...
            sum(class_info.invalid), ...
            pool_mean, pool_sd, ...
            numel(r2_zscore_pool), num_possible);
    end

    rec = struct();
    rec.session_index = [];
    rec.session_label = '';
    rec.session_name = sprintf('%s/%s', ...
        session_parent_name, catgt_name);
    rec.session_parent_name = session_parent_name;
    rec.session_number = ...
        extractSessionNumberFromNameLocal(session_parent_name);
    rec.session_dir = session_dir;
    rec.catgt_name = catgt_name;
    rec.run_name = run_name;
    rec.run_ind = run_ind;
    rec.run_g = run_g;
    rec.r2_file = r2_file;
    rec.group = groups;
end

function feature_delta = computeFeatureDeltasForGroupLocal( ...
        stim_data, num_source_fields, definitions, group_display_name)

    feature_delta = struct();

    for e = 1:numel(definitions)
        D = definitions(e);
        num_matches = numel(D.fixed_labels);
        raw_delta_array = [];
        z_delta_array = [];

        for k = 1:num_matches
            positive_raw = ...
                stim_data.(D.positive_stim{k}).source_r2_matrix;
            negative_raw = ...
                stim_data.(D.negative_stim{k}).source_r2_matrix;
            positive_z = ...
                stim_data.(D.positive_stim{k}).z_source_r2_matrix;
            negative_z = ...
                stim_data.(D.negative_stim{k}).z_source_r2_matrix;

            if k == 1
                num_neurons = size(positive_raw, 1);
                raw_delta_array = nan( ...
                    num_neurons, num_source_fields, num_matches);
                z_delta_array = nan( ...
                    num_neurons, num_source_fields, num_matches);
            end

            if ~isnumeric(positive_raw) || ...
                    ~isnumeric(negative_raw) || ...
                    ~isnumeric(positive_z) || ...
                    ~isnumeric(negative_z) || ...
                    ~isequal(size(positive_raw), ...
                    [num_neurons, num_source_fields]) || ...
                    ~isequal(size(negative_raw), ...
                    [num_neurons, num_source_fields]) || ...
                    ~isequal(size(positive_z), ...
                    [num_neurons, num_source_fields]) || ...
                    ~isequal(size(negative_z), ...
                    [num_neurons, num_source_fields])
                error(['%s has incompatible source R2 matrices for ', ...
                    'feature delta %s, match %d.'], ...
                    group_display_name, D.name, k);
            end

            raw_delta_array(:, :, k) = ...
                positive_raw - negative_raw;
            z_delta_array(:, :, k) = positive_z - negative_z;
        end

        E = struct();
        E.name = D.name;
        E.file_tag = D.file_tag;
        E.title = D.title;
        E.subscript = D.subscript;
        E.fixed_labels = reshape(D.fixed_labels, 1, []);
        E.positive_stim = reshape(D.positive_stim, 1, []);
        E.negative_stim = reshape(D.negative_stim, 1, []);
        E.raw_delta_array = raw_delta_array;
        E.z_delta_array = z_delta_array;
        E.zscore_order = 'R2 first, matched stimulus subtraction second';

        feature_delta.(D.name) = E;
    end
end

function r2_file = resolveR2FileLocal( ...
    session_dir, data_content, model_mode, runIdx, ...
    reconstruction_suffix, split_file_tag)

    file_name = sprintf('%s_%s_%s_R2_%s.mat', ...
        data_content, model_mode, split_file_tag, ...
        reconstruction_suffix);

    switch char(model_mode)
        case 'all_condition_model'
            r2_file = fullfile( ...
                session_dir, ...
                sprintf('FA_Dlag_%s', data_content), ...
                'mat_results', ...
                sprintf('run%03d', runIdx), ...
                file_name);

        case 'condition_specific_models'
            r2_file = fullfile(session_dir, file_name);

        otherwise
            error('Unknown model_mode: %s', model_mode);
    end
end

function validateStimtypeR2Local( ...
    R, expected_content, expected_mode, expected_num_groups, field_names, ...
    expected_split_mode, expected_split_file_tag, ...
    stim_types, category_labels, source_file)

    required_top = { ...
        'data_content', ...
        'model_mode', ...
        'yDims', ...
        'unit_ids_by_group'};

    for i = 1:numel(required_top)
        if ~isfield(R, required_top{i})
            error('%s: stimtype_recon_R2 is missing %s.', ...
                source_file, required_top{i});
        end
    end

    if ~strcmp(char(R.data_content), char(expected_content))
        error('%s: data_content is %s; expected %s.', ...
            source_file, char(R.data_content), char(expected_content));
    end

    if ~strcmp(char(R.model_mode), char(expected_mode))
        error('%s: model_mode is %s; expected %s.', ...
            source_file, char(R.model_mode), char(expected_mode));
    end

    if isfield(R, 'r2_split_mode')
        stored_split_mode = lower(strtrim(char(R.r2_split_mode)));

        if ~strcmp(stored_split_mode, expected_split_mode)
            error('%s: r2_split_mode is %s; expected %s.', ...
                source_file, stored_split_mode, expected_split_mode);
        end
    else
        error(['%s: by_three_features requires an R2 MAT produced by ', ...
            'calculate_reconstruction_R2_dfferent_ways.m.'], source_file);
    end

    if isfield(R, 'split_file_tag') && ...
            ~strcmp(char(R.split_file_tag), expected_split_file_tag)
        error('%s: split_file_tag is %s; expected %s.', ...
            source_file, char(R.split_file_tag), ...
            expected_split_file_tag);
    end

    if isfield(R, 'category_fields')
        stored_category_fields = normalizeTextCellLocal( ...
            R.category_fields, 'R.category_fields');

        if ~isequal(reshape(stored_category_fields, 1, []), ...
                reshape(stim_types, 1, []))
            error(['%s: category_fields do not match ', ...
                'r2_split_mode = %s.'], ...
                source_file, expected_split_mode);
        end
    end

    if isfield(R, 'category_labels')
        stored_category_labels = normalizeTextCellLocal( ...
            R.category_labels, 'R.category_labels');

        if ~isequal(reshape(stored_category_labels, 1, []), ...
                reshape(category_labels, 1, []))
            error(['%s: category_labels do not match ', ...
                'r2_split_mode = %s.'], ...
                source_file, expected_split_mode);
        end
    end

    y_dims = double(R.yDims(:)');
    num_groups = expected_num_groups;

    if numel(y_dims) ~= num_groups || ...
            any(~isfinite(y_dims)) || ...
            any(y_dims ~= round(y_dims)) || ...
            any(y_dims < 1)
        error(['%s: yDims is invalid or contains %d groups instead ', ...
            'of the %d entries supplied in group_names.'], ...
            source_file, numel(y_dims), num_groups);
    end

    if ~iscell(R.unit_ids_by_group) || ...
            numel(R.unit_ids_by_group) ~= num_groups
        error('%s: unit_ids_by_group has the wrong group count.', ...
            source_file);
    end

    for g = 1:num_groups
        ids = R.unit_ids_by_group{g};

        if ~isnumeric(ids) || numel(ids) ~= y_dims(g)
            error(['%s: unit_ids_by_group{%d} length does not ', ...
                'match yDims(%d).'], source_file, g, g);
        end
    end

    for st = 1:numel(stim_types)
        stim_name = stim_types{st};

        if ~isfield(R, stim_name) || ~isstruct(R.(stim_name))
            error('%s: missing stimulus field %s.', ...
                source_file, stim_name);
        end

        for f = 1:numel(field_names)
            field_name = field_names{f};

            if ~isfield(R.(stim_name), field_name) || ...
                    ~isstruct(R.(stim_name).(field_name)) || ...
                    ~isfield(R.(stim_name).(field_name), ...
                    'neuron_by_group')
                error('%s: %s.%s is missing neuron_by_group.', ...
                    source_file, stim_name, field_name);
            end

            by_group = ...
                R.(stim_name).(field_name).neuron_by_group;

            if ~iscell(by_group) || numel(by_group) ~= num_groups
                error('%s: %s.%s.neuron_by_group has wrong group count.', ...
                    source_file, stim_name, field_name);
            end

            for g = 1:num_groups
                if ~isnumeric(by_group{g}) || ...
                        numel(by_group{g}) ~= y_dims(g)
                    error(['%s: %s.%s group %d has the wrong ', ...
                        'neuron count.'], ...
                        source_file, stim_name, field_name, g);
                end
            end
        end
    end
end

function reference = validateOrInitializeReferenceLocal( ...
    reference, R, group_names, group_display_names, group_file_tags, ...
    r2_field_names, source_field_names, delta_names, r2_split_mode, ...
    stim_types, category_labels, session_dir)

    if isempty(fieldnames(reference))
        reference.num_groups = numel(R.yDims);
        reference.group_names = reshape(group_names, 1, []);
        reference.group_display_names = ...
            reshape(group_display_names, 1, []);
        reference.group_file_tags = reshape(group_file_tags, 1, []);
        reference.r2_field_names = ...
            reshape(r2_field_names, 1, []);
        reference.source_field_names = ...
            reshape(source_field_names, 1, []);
        reference.delta_names = reshape(delta_names, 1, []);
        reference.r2_split_mode = r2_split_mode;
        reference.stim_types = reshape(stim_types, 1, []);
        reference.category_labels = reshape(category_labels, 1, []);
        return;
    end

    if numel(R.yDims) ~= reference.num_groups
        error('%s: number of groups differs across sessions.', ...
            session_dir);
    end

    if ~isequal(reshape(group_names, 1, []), ...
            reference.group_names) || ...
            ~isequal(reshape(group_display_names, 1, []), ...
            reference.group_display_names) || ...
            ~isequal(reshape(group_file_tags, 1, []), ...
            reference.group_file_tags) || ...
            ~isequal(reshape(r2_field_names, 1, []), ...
            reference.r2_field_names) || ...
            ~isequal(reshape(source_field_names, 1, []), ...
            reference.source_field_names) || ...
            ~isequal(reshape(delta_names, 1, []), ...
            reference.delta_names) || ...
            ~strcmp(r2_split_mode, reference.r2_split_mode) || ...
            ~isequal(reshape(stim_types, 1, []), ...
            reference.stim_types) || ...
            ~isequal(reshape(category_labels, 1, []), ...
            reference.category_labels)
        error('%s: plotting labels or field order differ across sessions.', ...
            session_dir);
    end
end

function vec = getGroupR2VectorLocal(stim_result, field_name, group_idx)
    by_group = stim_result.(field_name).neuron_by_group;
    vec = double(by_group{group_idx}(:));
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

function M = buildMultiSessionDeltaSummaryLocal( ...
    records, skipped, root_dir, data_content, model_mode, ...
    r2_split_mode, split_file_tag, runIdx, ...
    reconstruction_suffix, group_names, group_display_names, ...
    group_file_tags, mapping_file_tag, gpl_mat_name, ...
    class_names, class_labels, class_markers, class_short_names, ...
    r2_field_names, r2_field_labels, ...
    source_field_names, source_field_labels, ...
    feature_source_labels, ...
    delta_names, delta_labels, delta_positive_fields, ...
    delta_negative_fields, stim_types, category_labels, ...
    output_prefix, output_base, feature_delta_definitions, neuron_population)

    num_sessions = numel(records);
    num_groups = numel(group_names);
    population_description = neuronPopulationDefinitionLocal(neuron_population);

    session_info = struct( ...
        'session_index', {}, ...
        'session_label', {}, ...
        'session_name', {}, ...
        'session_parent_name', {}, ...
        'session_number', {}, ...
        'session_dir', {}, ...
        'catgt_name', {}, ...
        'run_name', {}, ...
        'run_ind', {}, ...
        'run_g', {}, ...
        'r2_file', {}, ...
        'gpl_file_by_group', {});

    for s = 1:num_sessions
        session_info(s).session_index = s;
        session_info(s).session_label = records{s}.session_label;
        session_info(s).session_name = records{s}.session_name;
        session_info(s).session_parent_name = ...
            records{s}.session_parent_name;
        session_info(s).session_number = records{s}.session_number;
        session_info(s).session_dir = records{s}.session_dir;
        session_info(s).catgt_name = records{s}.catgt_name;
        session_info(s).run_name = records{s}.run_name;
        session_info(s).run_ind = records{s}.run_ind;
        session_info(s).run_g = records{s}.run_g;
        session_info(s).r2_file = records{s}.r2_file;
        session_info(s).gpl_file_by_group = ...
            {records{s}.group.gpl_file};
    end

    zscore_template = struct( ...
        'session_index', [], ...
        'session_label', '', ...
        'session_name', '', ...
        'group_index', [], ...
        'group_name', '', ...
        'group_file_tag', '', ...
        'pool_mean', NaN, ...
        'pool_sd', NaN, ...
        'std_normalization', 0, ...
        'n_finite', 0, ...
        'n_possible', 0, ...
        'n_nonfinite', 0, ...
        'pooling_scope', '', ...
        'operation_order', '');

    zscore_by_session_area = repmat( ...
        zscore_template, num_sessions, num_groups);

    for s = 1:num_sessions
        for g = 1:num_groups
            Z = records{s}.group(g).zscore;
            zscore_by_session_area(s, g).session_index = s;
            zscore_by_session_area(s, g).session_label = ...
                records{s}.session_label;
            zscore_by_session_area(s, g).session_name = ...
                records{s}.session_name;
            zscore_by_session_area(s, g).group_index = g;
            zscore_by_session_area(s, g).group_name = group_names{g};
            zscore_by_session_area(s, g).group_file_tag = ...
                group_file_tags{g};
            zscore_by_session_area(s, g).pool_mean = Z.pool_mean;
            zscore_by_session_area(s, g).pool_sd = Z.pool_sd;
            zscore_by_session_area(s, g).std_normalization = ...
                Z.std_normalization;
            zscore_by_session_area(s, g).n_finite = Z.n_finite;
            zscore_by_session_area(s, g).n_possible = Z.n_possible;
            zscore_by_session_area(s, g).n_nonfinite = Z.n_nonfinite;
            zscore_by_session_area(s, g).pooling_scope = ...
                Z.pooling_scope;
            zscore_by_session_area(s, g).operation_order = ...
                Z.operation_order;
        end
    end

    feature_zscore_by_session_area = repmat( ...
        zscore_template, num_sessions, num_groups);

    for s = 1:num_sessions
        for g = 1:num_groups
            Z = records{s}.group(g).feature_delta_zscore;
            feature_zscore_by_session_area(s, g).session_index = s;
            feature_zscore_by_session_area(s, g).session_label = ...
                records{s}.session_label;
            feature_zscore_by_session_area(s, g).session_name = ...
                records{s}.session_name;
            feature_zscore_by_session_area(s, g).group_index = g;
            feature_zscore_by_session_area(s, g).group_name = ...
                group_names{g};
            feature_zscore_by_session_area(s, g).group_file_tag = ...
                group_file_tags{g};
            feature_zscore_by_session_area(s, g).pool_mean = ...
                Z.pool_mean;
            feature_zscore_by_session_area(s, g).pool_sd = ...
                Z.pool_sd;
            feature_zscore_by_session_area(s, g).std_normalization = ...
                Z.std_normalization;
            feature_zscore_by_session_area(s, g).n_finite = ...
                Z.n_finite;
            feature_zscore_by_session_area(s, g).n_possible = ...
                Z.n_possible;
            feature_zscore_by_session_area(s, g).n_nonfinite = ...
                Z.n_nonfinite;
            feature_zscore_by_session_area(s, g).pooling_scope = ...
                Z.pooling_scope;
            feature_zscore_by_session_area(s, g).operation_order = ...
                Z.operation_order;
        end
    end

    pooled_template = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'stim', struct());

    pooled = repmat(pooled_template, 1, num_groups);

    for g = 1:num_groups
        pooled(g).group_index = g;
        pooled(g).group_name = group_names{g};
        pooled(g).group_display_name = group_display_names{g};
        pooled(g).group_file_tag = group_file_tags{g};

        for st = 1:numel(stim_types)
            stim_name = stim_types{st};
            pooled(g).stim.(stim_name) = struct();
            pooled(g).stim.(stim_name).class = struct();

            for c = 1:numel(class_names)
                class_name = class_names{c};
                raw_r2_matrix = zeros(0, numel(r2_field_names));
                z_r2_matrix = zeros(0, numel(r2_field_names));
                raw_delta_matrix = zeros(0, numel(delta_names));
                z_delta_matrix = zeros(0, numel(delta_names));
                unit_ids = [];
                session_index = [];
                session_label = {};
                session_name = {};

                for s = 1:num_sessions
                    G = records{s}.group(g);
                    class_mask = G.class_info.(class_name);
                    n_this = sum(class_mask);

                    if n_this == 0
                        continue;
                    end

                    raw_r2_matrix = [ ...
                        raw_r2_matrix; ...
                        G.stim.(stim_name).raw_r2_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    z_r2_matrix = [ ...
                        z_r2_matrix; ...
                        G.stim.(stim_name).z_r2_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    raw_delta_matrix = [ ...
                        raw_delta_matrix; ...
                        G.stim.(stim_name).raw_delta_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    z_delta_matrix = [ ...
                        z_delta_matrix; ...
                        G.stim.(stim_name).z_delta_matrix( ...
                        class_mask, :)]; %#ok<AGROW>

                    unit_ids = [unit_ids; G.unit_ids(class_mask)]; %#ok<AGROW>
                    session_index = [ ...
                        session_index; repmat(s, n_this, 1)]; %#ok<AGROW>
                    session_label = [ ...
                        session_label; ...
                        repmat({records{s}.session_label}, n_this, 1)]; %#ok<AGROW>
                    session_name = [ ...
                        session_name; ...
                        repmat({records{s}.session_name}, n_this, 1)]; %#ok<AGROW>
                end

                C = struct();
                C.class_name = class_name;
                C.class_label = class_labels{c};
                C.class_marker = class_markers{c};
                C.class_short_name = class_short_names{c};
                C.raw_r2_matrix = raw_r2_matrix;
                C.z_r2_matrix = z_r2_matrix;
                C.raw_delta_matrix = raw_delta_matrix;
                C.z_delta_matrix = z_delta_matrix;
                C.raw_delta = struct();
                C.z_delta = struct();

                for d = 1:numel(delta_names)
                    C.raw_delta.(delta_names{d}) = ...
                        raw_delta_matrix(:, d);
                    C.z_delta.(delta_names{d}) = ...
                        z_delta_matrix(:, d);
                end

                C.unit_ids = unit_ids;
                C.session_index = session_index;
                C.session_label = session_label;
                C.session_name = session_name;
                C.n_neurons = size(raw_delta_matrix, 1);
                C.finite_count_raw_by_r2_field = ...
                    sum(isfinite(raw_r2_matrix), 1);
                C.finite_count_z_by_r2_field = ...
                    sum(isfinite(z_r2_matrix), 1);
                C.finite_count_raw_by_delta = ...
                    sum(isfinite(raw_delta_matrix), 1);
                C.finite_count_z_by_delta = ...
                    sum(isfinite(z_delta_matrix), 1);

                pooled(g).stim.(stim_name).class.(class_name) = C;
            end
        end
    end

    feature_pooled_template = struct( ...
        'group_index', [], ...
        'group_name', '', ...
        'group_display_name', '', ...
        'group_file_tag', '', ...
        'effect', struct());

    feature_delta_pooled = repmat( ...
        feature_pooled_template, 1, num_groups);

    for g = 1:num_groups
        feature_delta_pooled(g).group_index = g;
        feature_delta_pooled(g).group_name = group_names{g};
        feature_delta_pooled(g).group_display_name = ...
            group_display_names{g};
        feature_delta_pooled(g).group_file_tag = ...
            group_file_tags{g};

        for e = 1:numel(feature_delta_definitions)
            D = feature_delta_definitions(e);
            num_matches = numel(D.fixed_labels);
            E = struct();
            E.name = D.name;
            E.file_tag = D.file_tag;
            E.title = D.title;
            E.subscript = D.subscript;
            E.fixed_labels = reshape(D.fixed_labels, 1, []);
            E.positive_stim = reshape(D.positive_stim, 1, []);
            E.negative_stim = reshape(D.negative_stim, 1, []);
            E.class = struct();

            for c = 1:numel(class_names)
                class_name = class_names{c};
                raw_delta_array = zeros( ...
                    0, numel(source_field_names), num_matches);
                z_delta_array = zeros( ...
                    0, numel(source_field_names), num_matches);
                unit_ids = [];
                session_index = [];
                session_label = {};
                session_name = {};

                for s = 1:num_sessions
                    G = records{s}.group(g);
                    class_mask = G.class_info.(class_name);
                    n_this = sum(class_mask);

                    if n_this == 0
                        continue;
                    end

                    session_effect = G.feature_delta.(D.name);
                    raw_delta_array = cat(1, raw_delta_array, ...
                        session_effect.raw_delta_array( ...
                        class_mask, :, :));
                    z_delta_array = cat(1, z_delta_array, ...
                        session_effect.z_delta_array( ...
                        class_mask, :, :));

                    unit_ids = [ ...
                        unit_ids; G.unit_ids(class_mask)]; %#ok<AGROW>
                    session_index = [ ...
                        session_index; repmat(s, n_this, 1)]; %#ok<AGROW>
                    session_label = [ ...
                        session_label; ...
                        repmat({records{s}.session_label}, ...
                        n_this, 1)]; %#ok<AGROW>
                    session_name = [ ...
                        session_name; ...
                        repmat({records{s}.session_name}, ...
                        n_this, 1)]; %#ok<AGROW>
                end

                C = struct();
                C.class_name = class_name;
                C.class_label = class_labels{c};
                C.class_marker = class_markers{c};
                C.raw_delta_array = raw_delta_array;
                C.z_delta_array = z_delta_array;
                C.unit_ids = unit_ids;
                C.session_index = session_index;
                C.session_label = session_label;
                C.session_name = session_name;
                C.n_neurons = size(raw_delta_array, 1);
                C.finite_count_raw_by_source_match = reshape( ...
                    sum(isfinite(raw_delta_array), 1), ...
                    numel(source_field_names), num_matches);
                C.finite_count_z_by_source_match = reshape( ...
                    sum(isfinite(z_delta_array), 1), ...
                    numel(source_field_names), num_matches);

                E.class.(class_name) = C;
            end

            % Preserve the existing P/C/U fields for downstream readers.
            % all_neurons mode uses this additional, unscreened neuron pool;
            % pcu_neurons mode uses the original class fields above.
            E.all_neurons = poolAllModelFeatureDeltasLocal( ...
                records, g, D, numel(source_field_names));
            feature_delta_pooled(g).effect.(D.name) = E;
        end
    end

    M = struct();

    M.meta.format_version = 'GPL_class_deltaR2_poster_v6';
    M.meta.root_dir = root_dir;
    M.meta.data_content = data_content;
    M.meta.model_mode = model_mode;
    M.meta.neuron_population = neuron_population;
    M.meta.r2_split_mode = r2_split_mode;
    M.meta.split_file_tag = split_file_tag;
    M.meta.condition_display_mode = 'pooled';
    M.meta.feature_delta_plot_mode = 'pooled';
    M.meta.feature_delta_enabled = true;
    M.meta.zscore_operation_order = 'R2 first, differences second';
    M.meta.runIdx = runIdx;
    M.meta.reconstruction_suffix = reconstruction_suffix;
    M.meta.gpl_mat_name = gpl_mat_name;
    M.meta.output_prefix = output_prefix;
    M.meta.output_base = output_base;
    M.meta.mapping_file_tag = mapping_file_tag;
    M.meta.num_sessions = num_sessions;
    M.meta.num_groups = num_groups;
    M.meta.num_stim_types = numel(stim_types);
    M.meta.num_categories = numel(stim_types);
    M.meta.num_delta_types = numel(delta_names);
    M.meta.num_r2_fields = numel(r2_field_names);
    M.meta.num_feature_delta_types = ...
        numel(feature_delta_definitions);

    M.settings.plot_value_modes = {'raw', 'zscore'};
    M.settings.neuron_population = neuron_population;
    M.settings.zscore_std_normalization = 0;
    M.settings.mean_differnet_conditions = 1;
    M.settings.plot_style = 'violin';

    M.labels.group = reshape(group_display_names, 1, []);
    M.labels.group_name = reshape(group_names, 1, []);
    M.labels.group_display_name = reshape(group_display_names, 1, []);
    M.labels.group_file_tag = reshape(group_file_tags, 1, []);
    M.labels.session = {session_info.session_label};
    M.labels.class_name = reshape(class_names, 1, []);
    M.labels.class = reshape(class_labels, 1, []);
    M.labels.class_marker = reshape(class_markers, 1, []);
    M.labels.class_short_name = reshape(class_short_names, 1, []);
    M.labels.r2_field_name = reshape(r2_field_names, 1, []);
    M.labels.r2_field = reshape(r2_field_labels, 1, []);
    M.labels.source_r2_field_name = ...
        reshape(source_field_names, 1, []);
    M.labels.source_r2_field = ...
        reshape(source_field_labels, 1, []);
    M.labels.feature_source = ...
        reshape(feature_source_labels, 1, []);
    M.labels.delta_name = reshape(delta_names, 1, []);
    M.labels.delta = reshape(delta_labels, 1, []);
    M.labels.delta_positive_field = ...
        reshape(delta_positive_fields, 1, []);
    M.labels.delta_negative_field = ...
        reshape(delta_negative_fields, 1, []);
    M.labels.stimulus = reshape(stim_types, 1, []);
    M.labels.category_field = reshape(stim_types, 1, []);
    M.labels.category = reshape(category_labels, 1, []);
    M.labels.feature_delta_name = ...
        reshape({feature_delta_definitions.name}, 1, []);
    M.labels.feature_delta_file_tag = ...
        reshape({feature_delta_definitions.file_tag}, 1, []);
    M.labels.feature_delta_title = ...
        reshape({feature_delta_definitions.title}, 1, []);
    M.labels.feature_delta_subscript = ...
        reshape({feature_delta_definitions.subscript}, 1, []);

    M.sessions.included = session_info;
    M.sessions.skipped = skipped;

    M.session_data = [records{:}];
    M.zscore_by_session_area = zscore_by_session_area;
    M.r2_zscore_by_session_area = zscore_by_session_area;
    M.pooled = pooled;
    M.feature_delta_definitions = feature_delta_definitions;
    M.feature_delta_zscore_by_session_area = ...
        feature_zscore_by_session_area;
    M.feature_delta_pooled = feature_delta_pooled;

    M.dimension_names.source_r2_matrix = { ...
        'neuron', 'source_r2_field'};
    M.dimension_names.raw_r2_matrix = {'neuron', 'r2_field'};
    M.dimension_names.z_r2_matrix = {'neuron', 'r2_field'};
    M.dimension_names.raw_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.z_delta_matrix = {'neuron', 'delta_type'};
    M.dimension_names.feature_raw_delta_array = { ...
        'neuron', 'source_r2_field', 'fixed_dimension_match'};
    M.dimension_names.feature_z_delta_array = { ...
        'neuron', 'source_r2_field', 'fixed_dimension_match'};

    M.notes.delta_definition = [ ...
        'acr_vs_wit = use_across R2 - use_within R2; ', ...
        'ff_vs_fb = use_feedforward R2 - use_feedback R2'];
    M.notes.zscore_definition = [ ...
        'For every session and area/model group separately, one mean and ', ...
        'one sample SD are calculated from all finite raw R2 values after ', ...
        'pooling ', population_description, ', all five ', ...
        'reconstruction fields (all, across, within, FF, FB), and all ', ...
        num2str(numel(stim_types)), ...
        ' stimulus groups selected by r2_split_mode. The same mean and ', ...
        'SD are applied to every R2 value in that session-area before ', ...
        'any latent-source or stimulus-feature difference is calculated.'];
    M.notes.zscore_zero_interpretation = [ ...
        'Because both terms in every difference use the same session-area ', ...
        'R2 mean and SD, their shared mean cancels. A zero difference of ', ...
        'z-scored R2 means the two original R2 values are equal.'];
    if strcmp(neuron_population, 'all_neurons')
        M.notes.invalid_neurons = [ ...
            'Invalid neurons remain in alignment checks and session_data, ', ...
            'and their finite R2 values contribute to the common z-score pool. ', ...
            'They are included in stimulus-feature figures but not in the ', ...
            'P/C/U class-specific latent-balance figures.'];
    else
        M.notes.invalid_neurons = [ ...
            'Invalid neurons remain in alignment checks and session_data, ', ...
            'but are excluded from the z-score pool and summary figures.'];
    end
    M.notes.classification_source = [ ...
        'Spontaneous-subtracted GPL plaid classification selected from ', ...
        'nested GPL group entries by model_group_index.'];
    M.notes.session_plot_encoding = [ ...
        'Session identity is retained in the MAT but is not encoded by ', ...
        'color, shade, legend, or connecting lines in the figures.'];
    M.notes.condition_plotting = [ ...
        'One finite-mean point per neuron from eight three-feature ', ...
        'stimulus conditions. GPL cell classes remain distinct.'];
    M.notes.value_figures = [ ...
        'Raw delta R2 and delta of z-scored R2 are separate figures.'];
    M.notes.feature_delta_definition = [ ...
        'For each reconstruction source separately: GP = Grating minus ', ...
        'Plaid, SL = Small minus Large, and LH = Low minus High, while ', ...
        'holding the other two stimulus dimensions fixed.'];
    M.notes.feature_delta_zscore_definition = [ ...
        'Use the same session-area R2 mean and sample SD as the latent ', ...
        'differences; standardize R2 before each matched subtraction.'];
    M.notes.feature_delta_plotting = [ ...
        'One finite-mean point per neuron over four matched differences. ', ...
        'Selected population: ', population_description, ...
        '; areas are paired for each source.'];
end

function C = poolAllModelFeatureDeltasLocal(records, group_idx, D, num_sources)
% Keep each model neuron once per session, independently of GPL validity.
% The existing E.class fields retain their original P/C/U-only structure.
    num_matches = numel(D.fixed_labels);
    C = struct();
    C.raw_delta_array = zeros(0, num_sources, num_matches);
    C.z_delta_array = zeros(0, num_sources, num_matches);
    C.unit_ids = [];
    C.session_index = [];
    C.session_label = {};
    C.session_name = {};
    for s = 1:numel(records)
        G = records{s}.group(group_idx);
        E = G.feature_delta.(D.name);
        n_this = numel(G.unit_ids);
        C.raw_delta_array = cat(1, C.raw_delta_array, E.raw_delta_array);
        C.z_delta_array = cat(1, C.z_delta_array, E.z_delta_array);
        C.unit_ids = [C.unit_ids; G.unit_ids(:)]; %#ok<AGROW>
        C.session_index = [C.session_index; repmat(s, n_this, 1)]; %#ok<AGROW>
        C.session_label = [C.session_label; ...
            repmat({records{s}.session_label}, n_this, 1)]; %#ok<AGROW>
        C.session_name = [C.session_name; ...
            repmat({records{s}.session_name}, n_this, 1)]; %#ok<AGROW>
    end
    C.n_neurons = size(C.raw_delta_array, 1);
    C.finite_count_raw_by_source_match = reshape( ...
        sum(isfinite(C.raw_delta_array), 1), num_sources, num_matches);
    C.finite_count_z_by_source_match = reshape( ...
        sum(isfinite(C.z_delta_array), 1), num_sources, num_matches);
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

function saveFigLocal(fig, fig_file)
    if exist('savefig', 'file') == 2
        savefig(fig, fig_file);
    else
        saveas(fig, fig_file);
    end
end

function saveSvgLocal(fig, svg_file)
    drawnow;

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, svg_file, ...
                'ContentType', 'vector', ...
                'BackgroundColor', 'white');
        else
            print(fig, svg_file, '-dsvg');
        end
    catch
        warning('SVG export failed. Falling back to saveas.');
        saveas(fig, svg_file);
    end
end

function savePngLocal(fig, png_file, dpi)
    drawnow;

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, png_file, ...
                'Resolution', dpi, ...
                'BackgroundColor', 'white');
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, png_file, '-dpng', sprintf('-r%d', dpi));
        end
    catch
        warning('PNG export failed. Falling back to saveas.');
        saveas(fig, png_file);
    end
end
