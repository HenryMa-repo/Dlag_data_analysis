%% plot_inferred_latents.m
% Plot single-trial inferred DLAG latent time courses by stimulus condition.
%
% This script is intended for the pooled, all-condition DLAG model used by
% Anova_latents_for_all_conds_used_dlag.m. It creates one figure for every
% latent dimension. Each figure contains 17 axes:
%   1) one overview axis containing all 16 direction-condition groups;
%   2) sixteen axes, one for each direction-condition group.
%
% Important behavior
% ------------------
% 1. Every line is one inferred single-trial latent trajectory. No trial
%    average and no error/SEM shading are drawn.
% 2. At most num_trials_to_plot_per_condition trials are drawn from each
%    direction-condition group. Trials are sampled randomly with a fixed
%    random seed. If fewer trials exist, all available trials are used.
% 3. Trial sampling is performed only once. Therefore, all latent figures,
%    the overview axis, and the separate condition axes use the same trials.
% 4. Across-group latents are plotted only from across_reference_group,
%    because the other groups contain time-shifted versions of the same
%    across-group latent process.
% 5. Within-group latents are plotted separately for every DLAG group.
%
% Expected condition order within each direction
% ------------------------------------------------
%   G-S-L, G-S-H, G-L-L, G-L-H,
%   P-S-L, P-S-H, P-L-L, P-L-H
%
% The script uses the DLAG local latent ordering
%   [across latents, within-group latents]
% within each group block of seqEst(n).xsm.

clearvars;
clc;
close all;

%% ========================================================================
% USER SETTINGS
% =========================================================================

% Run this script from the session/CatGT folder that contains
% model_data_allruns.mat and the FA_Dlag_* result folders, or replace
% session_dir with that folder's full path.
session_dir = pwd;
model_data_file = fullfile(session_dir, 'model_data_allruns.mat');

% Must match the data content used to fit the pooled DLAG model.
% This default follows Anova_latents_for_all_conds_used_dlag.m.
data_content = 'demean_count_within_t_and_condition';

% DLAG result-folder index, matching the original ANOVA program:
%   FA_Dlag_<data_content>/mat_results/run%03d
% This is intentionally separate from run_idx below. run_idx is obtained
% by matching stim_tag in model_data_allruns; runIdx chooses the fitted
% DLAG result folder.
runIdx = 1;

% Exact run tag stored in model_data_allruns. If this is empty and there is
% only one run, that run is selected automatically. If several runs exist,
% an exact stim_tag is required.
stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';

% These names are labels only. Data and latent rows always follow the DLAG
% group order in res.estParams / seqEst; no probe-name remapping is done.
group_names = {'V1', 'MT'};

% Number of randomly selected single-trial trajectories per one of the 16
% direction-condition groups. If this exceeds the number available, the
% available number is used. Set to Inf to draw every available trial.
num_trials_to_plot_per_condition = 20;

% Fixed seed makes the random trial selection reproducible.
random_seed = 1;

% Plot each across-group latent using this group's time-shifted copy only.
across_reference_group = 1;

% Plot formatting.
condition_colors = [];           % [] -> lines(16)
single_trial_line_width = 0.65;
show_zero_line = true;
show_grid = false;
use_common_ylim_within_figure = true;
figure_visible = 'on';           % 'on' or 'off'
figure_position = [50 50 1900 1200];

% Output. Figures are saved below the selected best-model run folder.
output_folder_name = fullfile( ...
    'latent_condition_analysis_split_by_dir', ...
    'plot_inferred_latents');
save_fig = false;
save_png = true;
png_dpi = 300;
close_figures_after_saving = true;

%% ========================================================================
% VALIDATE SETTINGS
% =========================================================================

if ~isfolder(session_dir)
    error('plot_inferred_latents:SessionFolderNotFound', ...
        'session_dir does not exist:\n%s', session_dir);
end

if ~isfile(model_data_file)
    error('plot_inferred_latents:ModelDataNotFound', ...
        'Cannot find model_data_allruns.mat:\n%s', model_data_file);
end

if ~(isnumeric(num_trials_to_plot_per_condition) && ...
        isscalar(num_trials_to_plot_per_condition) && ...
        (isinf(num_trials_to_plot_per_condition) || ...
         (isfinite(num_trials_to_plot_per_condition) && ...
          num_trials_to_plot_per_condition >= 1 && ...
          num_trials_to_plot_per_condition == floor(num_trials_to_plot_per_condition))))
    error('plot_inferred_latents:BadTrialNumber', ...
        ['num_trials_to_plot_per_condition must be a positive integer ', ...
         'or Inf.']);
end

if ~(isnumeric(random_seed) && isscalar(random_seed) && ...
        isfinite(random_seed) && random_seed >= 0 && ...
        random_seed == floor(random_seed))
    error('plot_inferred_latents:BadRandomSeed', ...
        'random_seed must be one nonnegative integer.');
end

if ~(isnumeric(runIdx) && isscalar(runIdx) && isfinite(runIdx) && ...
        runIdx >= 1 && runIdx == floor(runIdx))
    error('plot_inferred_latents:BadResultRunIndex', ...
        'runIdx must be one positive integer.');
end

if ~(ischar(figure_visible) || (isstring(figure_visible) && isscalar(figure_visible)))
    error('plot_inferred_latents:BadFigureVisibility', ...
        'figure_visible must be ''on'' or ''off''.');
end
figure_visible = char(string(figure_visible));
if ~ismember(lower(figure_visible), {'on', 'off'})
    error('plot_inferred_latents:BadFigureVisibility', ...
        'figure_visible must be ''on'' or ''off''.');
end

if close_figures_after_saving && ~save_fig && ~save_png
    error('plot_inferred_latents:NoVisibleOutput', ...
        ['Both save_fig and save_png are false while ', ...
         'close_figures_after_saving is true.']);
end

if ~(isnumeric(png_dpi) && isscalar(png_dpi) && ...
        isfinite(png_dpi) && png_dpi > 0)
    error('plot_inferred_latents:BadDPI', ...
        'png_dpi must be one positive finite number.');
end

%% ========================================================================
% LOAD MODEL DATA AND SELECT THE RUN
% =========================================================================

fprintf('\n=== plot_inferred_latents ===\n');
fprintf('Session folder : %s\n', session_dir);
fprintf('Data content   : %s\n', data_content);

Sdata = load(model_data_file, 'model_data_allruns');
if ~isfield(Sdata, 'model_data_allruns') || ~iscell(Sdata.model_data_allruns)
    error('plot_inferred_latents:MissingModelData', ...
        '%s does not contain a cell array named model_data_allruns.', ...
        model_data_file);
end
model_data_allruns = Sdata.model_data_allruns;

[run_idx, all_run_tags] = find_run_index_local(model_data_allruns, stim_tag);
this_run = model_data_allruns{run_idx};

fprintf('Metadata run_idx : %d\n', run_idx);
fprintf('Run tag          : %s\n', all_run_tags{run_idx});
fprintf('Result runIdx    : %d\n', runIdx);

if ~isstruct(this_run) || ~isfield(this_run, 'conditions_full')
    error('plot_inferred_latents:MissingConditions', ...
        'model_data_allruns{%d} does not contain conditions_full.', run_idx);
end

conditions_full = this_run.conditions_full;
if iscell(conditions_full)
    try
        conditions_full = [conditions_full{:}];
    catch ME
        error('plot_inferred_latents:BadConditions', ...
            'conditions_full could not be converted from a cell array: %s', ...
            ME.message);
    end
end
if ~isstruct(conditions_full) || isempty(conditions_full)
    error('plot_inferred_latents:BadConditions', ...
        'conditions_full must be a nonempty struct array.');
end

%% ========================================================================
% LOAD THE POOLED ALL-CONDITION BEST MODEL
% =========================================================================

base_dir = fullfile(session_dir, ['FA_Dlag_' data_content]);
tempfname = fullfile(base_dir, 'mat_results', sprintf('run%03d', runIdx));

if ~isfolder(tempfname)
    error('plot_inferred_latents:ResultFolderNotFound', ...
        ['Cannot find the pooled all-condition DLAG result folder:\n%s\n', ...
         'Check session_dir, data_content, and runIdx.'], tempfname);
end

best_model_file = find_first_file_local(tempfname, 'bestmodel*');
fprintf('Best-model file: %s\n', best_model_file);

Sbest = load(best_model_file, 'seqEst', 'res', 'bestModel');
if ~isfield(Sbest, 'seqEst') || ~isstruct(Sbest.seqEst) || isempty(Sbest.seqEst)
    error('plot_inferred_latents:MissingSeqEst', ...
        'The best-model file does not contain a nonempty struct array seqEst.');
end
seqEst = Sbest.seqEst;

if ~isfield(seqEst, 'xsm')
    error('plot_inferred_latents:MissingXsm', ...
        'seqEst does not contain inferred latent trajectories in field xsm.');
end

% The ANOVA program reads the selected dimensions from this file. Use the
% same source first, while retaining a bestmodel fallback for portability.
stats_file = fullfile(tempfname, 'DSL_and_latent_category_stats.mat');
if isfile(stats_file)
    Sstats = load(stats_file, 'bestModel');
else
    Sstats = struct();
end

params = resolve_dlag_params_local(Sstats, Sbest);
xDim_across = double(params.xDim_across);
xDim_within = reshape(double(params.xDim_within), 1, []);
num_groups = numel(xDim_within);

if ~(isscalar(xDim_across) && isfinite(xDim_across) && ...
        xDim_across >= 0 && xDim_across == floor(xDim_across))
    error('plot_inferred_latents:BadAcrossDimension', ...
        'xDim_across must be a nonnegative integer.');
end
if any(~isfinite(xDim_within)) || any(xDim_within < 0) || ...
        any(xDim_within ~= floor(xDim_within))
    error('plot_inferred_latents:BadWithinDimension', ...
        'Every xDim_within entry must be a nonnegative integer.');
end

if numel(group_names) ~= num_groups
    error('plot_inferred_latents:GroupNameCountMismatch', ...
        ['group_names contains %d names, but the fitted DLAG model has ', ...
         '%d groups.'], numel(group_names), num_groups);
end
group_names = cellfun(@(x) char(string(x)), group_names, ...
    'UniformOutput', false);

if ~(isnumeric(across_reference_group) && ...
        isscalar(across_reference_group) && ...
        across_reference_group >= 1 && ...
        across_reference_group <= num_groups && ...
        across_reference_group == floor(across_reference_group))
    error('plot_inferred_latents:BadAcrossReferenceGroup', ...
        'across_reference_group must be an integer from 1 to %d.', num_groups);
end

% Local latent row layout in xsm:
%   group 1: [across, within-1]
%   group 2: [across, within-2]
%   ...
local_dims = xDim_across + xDim_within;
block_start = cumsum([1, local_dims(1:end-1)]);
expected_x_rows = sum(local_dims);

for n = 1:numel(seqEst)
    if ~isnumeric(seqEst(n).xsm) || ndims(seqEst(n).xsm) ~= 2
        error('plot_inferred_latents:BadXsm', ...
            'seqEst(%d).xsm must be a numeric latent-by-time matrix.', n);
    end
    if size(seqEst(n).xsm, 1) < expected_x_rows
        error('plot_inferred_latents:XsmRowMismatch', ...
            ['seqEst(%d).xsm has %d rows, but the fitted dimensions ', ...
             'require at least %d rows.'], ...
            n, size(seqEst(n).xsm, 1), expected_x_rows);
    end
end

% Preserve the ANOVA program's time axis exactly: columns of xsm are
% plotted as time bins 1:T (not converted to milliseconds).
trial_lengths = arrayfun(@(s) size(s.xsm, 2), seqEst);
if any(trial_lengths ~= trial_lengths(1))
    error('plot_inferred_latents:UnequalTrialLengths', ...
        'All seqEst trials must have the same number of time bins.');
end
t_axis = 1:trial_lengths(1);

fprintf('Across dims    : %d\n', xDim_across);
fprintf('Within dims    : %s\n', mat2str(xDim_within));

%% ========================================================================
% MAP seqEst TRIALS TO THE 16 DIRECTION-CONDITION GROUPS
% =========================================================================

[trial_condition_ids, ~] = map_trials_to_conditions_local( ...
    conditions_full, seqEst);

[condition_to_plot_group, plot_group_labels, plot_group_short_labels] = ...
    build_condition_groups_local(conditions_full);

trial_plot_groups = nan(size(trial_condition_ids));
valid_condition = isfinite(trial_condition_ids) & ...
    trial_condition_ids >= 1 & ...
    trial_condition_ids <= numel(condition_to_plot_group) & ...
    trial_condition_ids == floor(trial_condition_ids);
trial_plot_groups(valid_condition) = ...
    condition_to_plot_group(trial_condition_ids(valid_condition));

num_unmapped = sum(~isfinite(trial_plot_groups));
if num_unmapped > 0
    warning('plot_inferred_latents:UnmappedTrials', ...
        ['%d of %d seqEst trials could not be assigned to one of the ', ...
         '16 direction-condition groups and will not be plotted.'], ...
        num_unmapped, numel(seqEst));
end

if isempty(condition_colors)
    condition_colors = lines(16);
else
    if ~(isnumeric(condition_colors) && isequal(size(condition_colors), [16 3]) && ...
            all(isfinite(condition_colors(:))) && ...
            all(condition_colors(:) >= 0) && all(condition_colors(:) <= 1))
        error('plot_inferred_latents:BadConditionColors', ...
            'condition_colors must be [] or a finite 16-by-3 RGB matrix in [0,1].');
    end
end

%% ========================================================================
% RANDOMLY SELECT TRIALS ONCE; REUSE THEM FOR EVERY LATENT
% =========================================================================

old_rng_state = rng;
rng(random_seed, 'twister');

selected_seq_indices = cell(1, 16);
available_trial_counts = zeros(1, 16);
selected_trial_counts = zeros(1, 16);

for plot_group_idx = 1:16
    candidates = find(trial_plot_groups == plot_group_idx);
    available_trial_counts(plot_group_idx) = numel(candidates);

    if isinf(num_trials_to_plot_per_condition)
        n_take = numel(candidates);
    else
        n_take = min(num_trials_to_plot_per_condition, numel(candidates));
    end

    if n_take > 0
        order = randperm(numel(candidates), n_take);
        selected_seq_indices{plot_group_idx} = candidates(order);
    else
        selected_seq_indices{plot_group_idx} = zeros(1, 0);
    end
    selected_trial_counts(plot_group_idx) = n_take;
end

% Do not alter the caller's random-number stream beyond this script's
% reproducible selection operation.
rng(old_rng_state);

fprintf('\nRandom trial selection (seed = %d)\n', random_seed);
fprintf('%-24s %10s %10s\n', 'Direction-condition', 'Available', 'Selected');
for plot_group_idx = 1:16
    fprintf('%-24s %10d %10d\n', plot_group_short_labels{plot_group_idx}, ...
        available_trial_counts(plot_group_idx), ...
        selected_trial_counts(plot_group_idx));
end

if sum(selected_trial_counts) == 0
    error('plot_inferred_latents:NoTrialsSelected', ...
        'No inferred trials were available in any of the 16 groups.');
end

%% ========================================================================
% BUILD THE LIST OF LATENTS TO PLOT
% =========================================================================

latent_specs = struct( ...
    'type', {}, ...
    'group_idx', {}, ...
    'latent_idx', {}, ...
    'row_idx', {}, ...
    'title_text', {}, ...
    'file_stem', {});

% Across-group latents: plot only the selected reference group's copy.
for latent_idx = 1:xDim_across
    group_idx = across_reference_group;
    row_idx = block_start(group_idx) + latent_idx - 1;

    group_tag = sprintf('G%02d_%s', group_idx, ...
        sanitize_filename_local(group_names{group_idx}));
    title_text = sprintf('Across latent A%03d | Group %d: %s copy', ...
        latent_idx, group_idx, group_names{group_idx});
    file_stem = sprintf('%s_A%03d_across_inferred_latents', ...
        group_tag, latent_idx);

    latent_specs(end+1) = make_latent_spec_local( ...
        'across', group_idx, latent_idx, row_idx, ...
        title_text, file_stem); %#ok<SAGROW>
end

% Within-group latents: plot every dimension separately for every group.
for group_idx = 1:num_groups
    for latent_idx = 1:xDim_within(group_idx)
        row_idx = block_start(group_idx) + xDim_across + latent_idx - 1;

        group_tag = sprintf('G%02d_%s', group_idx, ...
            sanitize_filename_local(group_names{group_idx}));
        title_text = sprintf('Within latent W%03d | Group %d: %s', ...
            latent_idx, group_idx, group_names{group_idx});
        file_stem = sprintf('%s_W%03d_within_inferred_latents', ...
            group_tag, latent_idx);

        latent_specs(end+1) = make_latent_spec_local( ...
            'within', group_idx, latent_idx, row_idx, ...
            title_text, file_stem); %#ok<SAGROW>
    end
end

if isempty(latent_specs)
    error('plot_inferred_latents:ZeroTotalDimension', ...
        'The fitted model has no across- or within-group latent dimensions.');
end

%% ========================================================================
% PLOT AND SAVE
% =========================================================================

output_dir = fullfile(tempfname, output_folder_name);
if ~isfolder(output_dir)
    mkdir(output_dir);
end

fprintf('\nOutput folder  : %s\n', output_dir);
fprintf('Figures to make: %d\n\n', numel(latent_specs));

for spec_idx = 1:numel(latent_specs)
    spec = latent_specs(spec_idx);
    fprintf('[%d/%d] %s\n', spec_idx, numel(latent_specs), spec.title_text);

    fig = plot_one_latent_local( ...
        seqEst, ...
        spec.row_idx, ...
        selected_seq_indices, ...
        plot_group_labels, ...
        plot_group_short_labels, ...
        condition_colors, ...
        t_axis, ...
        single_trial_line_width, ...
        show_zero_line, ...
        show_grid, ...
        use_common_ylim_within_figure, ...
        figure_visible, ...
        figure_position, ...
        spec.title_text);

    if save_fig
        fig_file = fullfile(output_dir, [spec.file_stem '.fig']);
        savefig(fig, fig_file);
    end

    if save_png
        png_file = fullfile(output_dir, [spec.file_stem '.png']);
        save_png_local(fig, png_file, png_dpi);
    end

    if close_figures_after_saving
        close(fig);
    end
end

fprintf('\nFinished: created %d latent figures.\n', numel(latent_specs));

%% ========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function [run_idx, run_tags] = find_run_index_local(model_data_allruns, stim_tag)
% Find one run by exact stim_tag.

num_runs = numel(model_data_allruns);
run_tags = {};

% Use the same project helper as Anova_latents_for_all_conds_used_dlag.m
% whenever it is on the MATLAB path. The field-based branch below keeps
% this plotting script self-contained when that helper is unavailable.
if exist('get_all_run_tags', 'file') == 2
    try
        helper_tags = get_all_run_tags(model_data_allruns);
        if isstring(helper_tags)
            helper_tags = cellstr(helper_tags(:));
        elseif ischar(helper_tags)
            helper_tags = cellstr(helper_tags);
        end
        if iscell(helper_tags) && numel(helper_tags) == num_runs
            run_tags = cell(1, num_runs);
            for run_idx0 = 1:num_runs
                run_tags{run_idx0} = scalar_text_local(helper_tags{run_idx0}, ...
                    sprintf('run tag returned for run %d', run_idx0));
            end
        end
    catch ME
        warning('plot_inferred_latents:RunTagHelperFailed', ...
            ['get_all_run_tags failed (%s). Trying run-tag fields ', ...
             'inside model_data_allruns instead.'], ME.message);
        run_tags = {};
    end
end

if isempty(run_tags)
    run_tags = cell(1, num_runs);
    for run_idx0 = 1:num_runs
        this_run0 = model_data_allruns{run_idx0};
        if ~isstruct(this_run0)
            error('plot_inferred_latents:BadRunEntry', ...
                'model_data_allruns{%d} is not a struct.', run_idx0);
        end

        [value, found] = get_first_field_local(this_run0, ...
            {'stim_tag', 'stimTag', 'run_tag', 'runTag'});
        if found
            run_tags{run_idx0} = scalar_text_local(value, ...
                sprintf('run tag in model_data_allruns{%d}', run_idx0));
        else
            run_tags{run_idx0} = sprintf('<run %d: tag field missing>', run_idx0);
        end
    end
end

stim_tag = char(string(stim_tag));
if isempty(stim_tag)
    if num_runs == 1
        run_idx = 1;
        return;
    end
    error('plot_inferred_latents:StimTagRequired', ...
        ['stim_tag is empty, but model_data_allruns contains %d runs. ', ...
         'Set stim_tag to one exact run tag. Available tags:\n  %s'], ...
        num_runs, strjoin(run_tags, '\n  '));
end

matches = find(strcmp(run_tags, stim_tag));
if isempty(matches)
    error('plot_inferred_latents:StimTagNotFound', ...
        ['Exact stim_tag was not found:\n  %s\nAvailable tags:\n  %s'], ...
        stim_tag, strjoin(run_tags, '\n  '));
end
if numel(matches) > 1
    error('plot_inferred_latents:DuplicateStimTag', ...
        'stim_tag matched multiple run entries: %s', mat2str(matches));
end
run_idx = matches;
end

function best_file = find_first_file_local(folder_name, pattern)
% Follow the reference program: use the first file in name order.

files = dir(fullfile(folder_name, pattern));
files = files(~[files.isdir]);
if isempty(files)
    error('plot_inferred_latents:BestModelNotFound', ...
        'No file matching %s was found in:\n%s', pattern, folder_name);
end

[~, order] = sort({files.name});
files = files(order);
best_file = fullfile(files(1).folder, files(1).name);

if numel(files) > 1
    warning('plot_inferred_latents:MultipleBestModels', ...
        ['Found %d files matching %s. The first file in name order ', ...
         'was selected:\n%s'], ...
        numel(files), pattern, best_file);
end
end

function params = resolve_dlag_params_local(Sstats, Sbest)
% Prefer bestModel from DSL_and_latent_category_stats.mat, matching ANOVA.

if isfield(Sstats, 'bestModel') && isstruct(Sstats.bestModel)
    params = Sstats.bestModel;
elseif isfield(Sbest, 'res') && isstruct(Sbest.res) && ...
        isfield(Sbest.res, 'estParams') && isstruct(Sbest.res.estParams)
    params = Sbest.res.estParams;
elseif isfield(Sbest, 'bestModel') && isstruct(Sbest.bestModel)
    params = Sbest.bestModel;
else
    error('plot_inferred_latents:MissingParameters', ...
        ['Could not find xDim parameters in ', ...
         'DSL_and_latent_category_stats.mat or the bestmodel file.']);
end

required = {'xDim_across', 'xDim_within'};
for k = 1:numel(required)
    if ~isfield(params, required{k})
        error('plot_inferred_latents:MissingParameterField', ...
            'The fitted parameter struct has no field %s.', required{k});
    end
end
end

function [trial_condition_ids, seq_trial_ids] = ...
        map_trials_to_conditions_local(conditions_full, seqEst)
% Map seqEst.trialId through conditions_full(k).trial_indices, as in ANOVA.

num_seq = numel(seqEst);
if isfield(seqEst, 'trialId')
    try
        seq_trial_ids = double([seqEst.trialId]);
    catch
        error('plot_inferred_latents:BadTrialId', ...
            'Every seqEst(n).trialId must be one numeric scalar.');
    end
else
    seq_trial_ids = 1:num_seq;
end

if numel(seq_trial_ids) ~= num_seq || any(~isfinite(seq_trial_ids)) || ...
        any(seq_trial_ids < 1) || any(seq_trial_ids ~= floor(seq_trial_ids))
    error('plot_inferred_latents:BadTrialId', ...
        'seqEst trial IDs must be positive finite integers.');
end

num_conditions = numel(conditions_full);
all_trial_indices = cell(1, num_conditions);
max_trial_index = max(seq_trial_ids);
for condition_idx = 1:num_conditions
    [indices, found] = get_first_field_local(conditions_full(condition_idx), ...
        {'trial_indices', 'trial_idx', 'trial_ids'});
    if ~found
        error('plot_inferred_latents:MissingTrialIndices', ...
            'conditions_full(%d) has no trial_indices field.', ...
            condition_idx);
    end
    if ~isnumeric(indices)
        error('plot_inferred_latents:BadTrialIndices', ...
            'conditions_full(%d).trial_indices must be numeric.', ...
            condition_idx);
    end
    indices = reshape(double(indices), 1, []);
    if any(~isfinite(indices)) || any(indices < 1) || ...
            any(indices ~= floor(indices))
        error('plot_inferred_latents:BadTrialIndices', ...
            ['conditions_full(%d).trial_indices must contain ', ...
             'positive finite integers.'], condition_idx);
    end
    all_trial_indices{condition_idx} = indices;
    if ~isempty(indices)
        max_trial_index = max(max_trial_index, max(indices));
    end
end

trial_to_condition = nan(1, max_trial_index);
for condition_idx = 1:num_conditions
    indices = all_trial_indices{condition_idx};
    already_assigned = isfinite(trial_to_condition(indices));
    conflicting = already_assigned & ...
        trial_to_condition(indices) ~= condition_idx;
    if any(conflicting)
        error('plot_inferred_latents:OverlappingTrialIndices', ...
            ['At least one trial index belongs to more than one ', ...
             'conditions_full element.']);
    end
    trial_to_condition(indices) = condition_idx;
end
trial_condition_ids = trial_to_condition(seq_trial_ids);

bad_condition_id = isfinite(trial_condition_ids) & ...
    (trial_condition_ids < 1 | ...
     trial_condition_ids > num_conditions | ...
     trial_condition_ids ~= floor(trial_condition_ids));
if any(bad_condition_id)
    bad_positions = find(bad_condition_id);
    error('plot_inferred_latents:BadMappedCondition', ...
        ['Mapped condition IDs must be integers from 1 to %d. ', ...
         'First invalid seqEst position: %d (trialId %d).'], ...
        num_conditions, bad_positions(1), ...
        seq_trial_ids(bad_positions(1)));
end
end

function [condition_to_group, display_labels, short_labels] = ...
        build_condition_groups_local(conditions_full)
% Convert conditions_full metadata to 2 directions x 8 stimulus groups.

num_conditions = numel(conditions_full);
stim_code = nan(1, num_conditions);       % 1 grating, 2 plaid
size_values = cell(1, num_conditions);
contrast_values = cell(1, num_conditions);
direction_values = cell(1, num_conditions);

for condition_idx = 1:num_conditions
    condition_struct = conditions_full(condition_idx);

    [stim_value, found] = get_first_field_local(condition_struct, ...
        {'stim_name', 'stimName', 'stimulus_name', 'stimulus'});
    if ~found
        error('plot_inferred_latents:MissingStimName', ...
            'conditions_full(%d) has no stim_name field.', condition_idx);
    end
    stim_code(condition_idx) = classify_stimulus_local(stim_value, condition_idx);

    [size_values{condition_idx}, found] = get_first_field_local( ...
        condition_struct, {'size', 'stim_size', 'stimsize', 'stimSize'});
    if ~found
        error('plot_inferred_latents:MissingSize', ...
            'conditions_full(%d) has no size field.', condition_idx);
    end

    [contrast_values{condition_idx}, found] = get_first_field_local( ...
        condition_struct, {'contrast', 'stim_contrast', 'stimContrast'});
    if ~found
        error('plot_inferred_latents:MissingContrast', ...
            'conditions_full(%d) has no contrast field.', condition_idx);
    end

    if stim_code(condition_idx) == 1
        direction_candidates = {'grating_dir', 'grating_direction', ...
            'direction', 'dir'};
    else
        direction_candidates = {'plaid_dir', 'plaid_direction', ...
            'direction', 'dir'};
    end
    [direction_values{condition_idx}, found] = get_first_field_local( ...
        condition_struct, direction_candidates);
    if ~found
        error('plot_inferred_latents:MissingDirection', ...
            ['conditions_full(%d) has no stimulus-appropriate ', ...
             'direction field.'], condition_idx);
    end
end

size_code = classify_two_levels_local(size_values, 'size');

% Match the ANOVA program: low/high contrast is defined separately inside
% grating and plaid, because the two stimulus types may use different raw
% numeric contrast values.
contrast_code = nan(1, num_conditions);
for stim_idx = 1:2
    stim_mask = (stim_code == stim_idx);
    contrast_code(stim_mask) = classify_two_levels_local( ...
        contrast_values(stim_mask), 'contrast');
end

% Match its after-the-fact angle correction (360 == 0, -10 == 350).
for condition_idx = 1:num_conditions
    value = direction_values{condition_idx};
    if isnumeric(value) && isscalar(value) && isfinite(value)
        value = mod(double(value), 360);
        if abs(value - round(value)) < 1e-10
            value = round(value);
        end
        if abs(value) < 1e-10 || abs(value - 360) < 1e-10
            value = 0;
        end
        direction_values{condition_idx} = value;
    end
end
[direction_code, direction_labels] = classify_directions_local(direction_values);

base_condition_idx = (stim_code - 1) * 4 + ...
    (size_code - 1) * 2 + contrast_code;
condition_to_group = (direction_code - 1) * 8 + base_condition_idx;

base_labels = {'G-S-L', 'G-S-H', 'G-L-L', 'G-L-H', ...
               'P-S-L', 'P-S-H', 'P-L-L', 'P-L-H'};
display_labels = cell(1, 16);
short_labels = cell(1, 16);

for direction_idx = 1:2
    for base_idx = 1:8
        plot_group_idx = (direction_idx - 1) * 8 + base_idx;
        display_labels{plot_group_idx} = sprintf('Dir %d (%s) | %s', ...
            direction_idx, direction_labels{direction_idx}, ...
            base_labels{base_idx});
        short_labels{plot_group_idx} = sprintf('D%d_%s', ...
            direction_idx, base_labels{base_idx});
    end
end

metadata_counts = accumarray(condition_to_group(:), 1, [16 1]);
missing_groups = find(metadata_counts == 0);
if ~isempty(missing_groups)
    error('plot_inferred_latents:IncompleteConditionSet', ...
        ['conditions_full does not contain all expected 16 ', ...
         'direction-condition groups. Missing: %s'], ...
        strjoin(short_labels(missing_groups), ', '));
end

duplicate_groups = find(metadata_counts > 1);
if ~isempty(duplicate_groups)
    warning('plot_inferred_latents:DuplicateConditionMetadata', ...
        ['Multiple conditions_full entries map to the same plot group. ', ...
         'Their trials will be combined for: %s'], ...
        strjoin(short_labels(duplicate_groups), ', '));
end
end

function stim_code = classify_stimulus_local(value, condition_idx)
% Return 1 for grating and 2 for plaid.

if isnumeric(value) && isscalar(value) && isfinite(value)
    if value == 1
        stim_code = 1;
        return;
    elseif value == 2
        stim_code = 2;
        return;
    end
end

text_value = lower(strtrim(scalar_text_local(value, ...
    sprintf('conditions_full(%d).stim_name', condition_idx))));
if contains(text_value, 'grat') || strcmp(text_value, 'g')
    stim_code = 1;
elseif contains(text_value, 'plaid') || strcmp(text_value, 'p')
    stim_code = 2;
else
    error('plot_inferred_latents:UnknownStimulus', ...
        ['Cannot classify conditions_full(%d).stim_name as grating ', ...
         'or plaid: %s'], condition_idx, text_value);
end
end

function codes = classify_two_levels_local(values, level_type)
% Classify size as small/large or contrast as low/high.

num_values = numel(values);
codes = nan(1, num_values);
numeric_values = nan(1, num_values);
all_numeric = true;

for idx = 1:num_values
    value = values{idx};
    if isnumeric(value) && isscalar(value) && isfinite(value)
        numeric_values(idx) = double(value);
    else
        all_numeric = false;
    end

    text_value = lower(strtrim(scalar_text_local(value, ...
        sprintf('%s value %d', level_type, idx))));

    switch lower(level_type)
        case 'size'
            if strcmp(text_value, 's') || contains(text_value, 'small')
                codes(idx) = 1;
            elseif strcmp(text_value, 'l') || contains(text_value, 'large')
                codes(idx) = 2;
            end
        case 'contrast'
            if strcmp(text_value, 'l') || contains(text_value, 'low')
                codes(idx) = 1;
            elseif strcmp(text_value, 'h') || contains(text_value, 'high')
                codes(idx) = 2;
            end
        otherwise
            error('plot_inferred_latents:InternalLevelType', ...
                'Unknown two-level type: %s', level_type);
    end
end

if all_numeric
    levels = unique(numeric_values);
    levels = sort(levels);
    if numel(levels) ~= 2
        error('plot_inferred_latents:WrongLevelCount', ...
            'Expected exactly two %s levels; found %d.', ...
            level_type, numel(levels));
    end
    codes(numeric_values == levels(1)) = 1;
    codes(numeric_values == levels(2)) = 2;
end

if any(~isfinite(codes))
    unresolved = find(~isfinite(codes));
    error('plot_inferred_latents:UnclassifiedLevel', ...
        ['Could not classify all %s values as low/high or small/large. ', ...
         'First unresolved conditions_full index: %d.'], ...
        level_type, unresolved(1));
end

if ~isequal(unique(codes), [1 2]) && ~isequal(unique(codes), [1; 2])
    error('plot_inferred_latents:WrongLevelCount', ...
        'Expected both levels of %s in conditions_full.', level_type);
end
end

function [codes, direction_labels] = classify_directions_local(values)
% Classify exactly two directions, using numeric ascending order when possible.

num_values = numel(values);
numeric_values = nan(1, num_values);
all_numeric = true;
keys = cell(1, num_values);

for idx = 1:num_values
    value = values{idx};
    if isnumeric(value) && isscalar(value) && isfinite(value)
        numeric_values(idx) = double(value);
        keys{idx} = sprintf('%.15g', double(value));
    else
        all_numeric = false;
        keys{idx} = lower(strtrim(scalar_text_local(value, ...
            sprintf('direction value %d', idx))));
    end
end

codes = nan(1, num_values);
direction_labels = cell(1, 2);

if all_numeric
    levels = sort(unique(numeric_values));
    if numel(levels) ~= 2
        error('plot_inferred_latents:WrongDirectionCount', ...
            'Expected exactly two stimulus directions; found %d.', numel(levels));
    end
    for direction_idx = 1:2
        codes(numeric_values == levels(direction_idx)) = direction_idx;
        direction_labels{direction_idx} = sprintf('%.6g deg', levels(direction_idx));
    end
else
    [unique_keys, ~, key_codes] = unique(keys, 'stable');
    if numel(unique_keys) ~= 2
        error('plot_inferred_latents:WrongDirectionCount', ...
            'Expected exactly two stimulus directions; found %d.', ...
            numel(unique_keys));
    end
    codes = reshape(key_codes, 1, []);
    direction_labels = unique_keys;
end
end

function spec = make_latent_spec_local(type, group_idx, latent_idx, ...
        row_idx, title_text, file_stem)
spec = struct( ...
    'type', type, ...
    'group_idx', group_idx, ...
    'latent_idx', latent_idx, ...
    'row_idx', row_idx, ...
    'title_text', title_text, ...
    'file_stem', file_stem);
end

function fig = plot_one_latent_local(seqEst, row_idx, selected_seq_indices, ...
        display_labels, short_labels, colors, t_axis, ...
        line_width, show_zero_line, show_grid, ...
        use_common_ylim, figure_visible, figure_position, figure_title)
% Draw one 17-axis figure for one latent row.

if numel(t_axis) == 1
    global_xlim = [t_axis(1) - 0.5, t_axis(1) + 0.5];
else
    global_xlim = [t_axis(1), t_axis(end)];
end
global_ylim = determine_ylim_local( ...
    seqEst, row_idx, selected_seq_indices);

fig = figure( ...
    'Color', 'w', ...
    'Visible', figure_visible, ...
    'Position', figure_position, ...
    'Name', figure_title, ...
    'NumberTitle', 'off', ...
    'InvertHardcopy', 'off');

layout = tiledlayout(fig, 5, 4, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

% Overview occupies the full first row.
ax_all = nexttile(layout, [1 4]);
hold(ax_all, 'on');
legend_handles = gobjects(1, 16);

for plot_group_idx = 1:16
    plot_trials_on_axis_local(ax_all, seqEst, row_idx, ...
        selected_seq_indices{plot_group_idx}, ...
        colors(plot_group_idx, :), line_width, ...
        t_axis);

    legend_handles(plot_group_idx) = plot(ax_all, NaN, NaN, ...
        'Color', colors(plot_group_idx, :), ...
        'LineWidth', max(1.2, line_width), ...
        'DisplayName', display_labels{plot_group_idx});
end

format_axis_local(ax_all, global_xlim, global_ylim, ...
    show_zero_line, show_grid);
xlabel(ax_all, 'Time bin');
ylabel(ax_all, 'Inferred latent value');
title(ax_all, sprintf('All 16 groups | %d selected trial curves total', ...
    sum(cellfun(@numel, selected_seq_indices))), ...
    'Interpreter', 'none');
lgd = legend(ax_all, legend_handles, display_labels, ...
    'Location', 'southoutside', ...
    'Interpreter', 'none', ...
    'FontSize', 7);
lgd.NumColumns = 4;
lgd.Layout.Tile = 'south';

% Sixteen separate direction-condition axes.
individual_axes = gobjects(1, 16);
for plot_group_idx = 1:16
    ax = nexttile(layout);
    individual_axes(plot_group_idx) = ax;
    hold(ax, 'on');

    plot_trials_on_axis_local(ax, seqEst, row_idx, ...
        selected_seq_indices{plot_group_idx}, ...
        colors(plot_group_idx, :), line_width, ...
        t_axis);

    if isempty(selected_seq_indices{plot_group_idx})
        text(ax, 0.5, 0.5, 'No inferred trials', ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Color', [0.35 0.35 0.35], ...
            'FontSize', 8);
    end

    if use_common_ylim
        this_ylim = global_ylim;
    else
        this_ylim = determine_ylim_local( ...
            seqEst, row_idx, {selected_seq_indices{plot_group_idx}});
    end

    format_axis_local(ax, global_xlim, this_ylim, ...
        show_zero_line, show_grid);
    title(ax, sprintf('%s | n = %d', ...
        short_labels{plot_group_idx}, ...
        numel(selected_seq_indices{plot_group_idx})), ...
        'Interpreter', 'none', ...
        'Color', colors(plot_group_idx, :));

    % The 16 axes occupy a 4 x 4 block below the overview.
    local_row = ceil(plot_group_idx / 4);
    local_col = mod(plot_group_idx - 1, 4) + 1;
    if local_row == 4
        xlabel(ax, 'Time bin');
    end
    if local_col == 1
        ylabel(ax, 'Latent value');
    end
end

% Keep zoom/pan synchronized across all axes in the figure.
all_axes = [ax_all, individual_axes];
linkaxes(all_axes, 'x');
if use_common_ylim
    linkaxes(all_axes, 'y');
end

sgtitle(layout, figure_title, ...
    'Interpreter', 'none', ...
    'FontWeight', 'bold', ...
    'FontSize', 13);
end

function plot_trials_on_axis_local(ax, seqEst, row_idx, seq_indices, ...
        color_value, line_width, t_axis)
% Plot selected single-trial trajectories on one axis.

for idx = reshape(seq_indices, 1, [])
    latent_curve = double(seqEst(idx).xsm(row_idx, :));
    plot(ax, t_axis, latent_curve, ...
        'Color', color_value, ...
        'LineWidth', line_width, ...
        'HandleVisibility', 'off');
end
end

function y_limits = determine_ylim_local(seqEst, row_idx, ...
        selected_seq_indices)
% Determine y limits from all selected finite single-trial values.

min_y = Inf;
max_y = -Inf;

for plot_group_idx = 1:numel(selected_seq_indices)
    for idx = reshape(selected_seq_indices{plot_group_idx}, 1, [])
        latent_curve = double(seqEst(idx).xsm(row_idx, :));
        finite_values = latent_curve(isfinite(latent_curve));
        if ~isempty(finite_values)
            min_y = min(min_y, min(finite_values));
            max_y = max(max_y, max(finite_values));
        end
    end
end

if ~isfinite(min_y) || ~isfinite(max_y)
    y_limits = [-1 1];
elseif min_y == max_y
    pad = max(0.5, 0.1 * max(1, abs(min_y)));
    y_limits = [min_y - pad, max_y + pad];
else
    pad = 0.05 * (max_y - min_y);
    y_limits = [min_y - pad, max_y + pad];
end
end

function format_axis_local(ax, x_limits, y_limits, show_zero_line, show_grid)
% Apply shared formatting and an optional zero reference line.

xlim(ax, x_limits);
ylim(ax, y_limits);
set(ax, ...
    'Box', 'off', ...
    'TickDir', 'out', ...
    'LineWidth', 0.75, ...
    'FontSize', 8, ...
    'Layer', 'top');

if show_grid
    grid(ax, 'on');
else
    grid(ax, 'off');
end

if show_zero_line && y_limits(1) < 0 && y_limits(2) > 0
    line(ax, x_limits, [0 0], ...
        'Color', [0.55 0.55 0.55], ...
        'LineStyle', ':', ...
        'LineWidth', 0.65, ...
        'HandleVisibility', 'off');
end

end

function save_png_local(fig, png_file, png_dpi)
% Use exportgraphics when available, with print as a compatibility fallback.

try
    exportgraphics(fig, png_file, 'Resolution', png_dpi);
catch ME
    warning('plot_inferred_latents:ExportGraphicsFallback', ...
        ['exportgraphics failed (%s). Falling back to print for:\n%s'], ...
        ME.message, png_file);
    print(fig, png_file, '-dpng', sprintf('-r%d', round(png_dpi)));
end
end

function [value, found] = get_first_field_local(struct_value, candidates)
% Get the first matching field, allowing case-insensitive field matching.

value = [];
found = false;
field_names = fieldnames(struct_value);

for idx = 1:numel(candidates)
    exact_idx = find(strcmp(field_names, candidates{idx}), 1, 'first');
    if isempty(exact_idx)
        exact_idx = find(strcmpi(field_names, candidates{idx}), 1, 'first');
    end
    if ~isempty(exact_idx)
        value = struct_value.(field_names{exact_idx});
        found = true;
        return;
    end
end
end

function text_value = scalar_text_local(value, description)
% Convert one scalar metadata value to character text.

if ischar(value)
    if size(value, 1) ~= 1
        error('plot_inferred_latents:NonScalarText', ...
            '%s must be scalar text.', description);
    end
    text_value = value;
elseif isstring(value) && isscalar(value)
    text_value = char(value);
elseif isnumeric(value) && isscalar(value) && isfinite(value)
    text_value = sprintf('%.15g', double(value));
elseif islogical(value) && isscalar(value)
    text_value = char(string(value));
elseif iscell(value) && isscalar(value)
    text_value = scalar_text_local(value{1}, description);
else
    error('plot_inferred_latents:NonScalarMetadata', ...
        '%s must be one scalar numeric or text value.', description);
end
end

function safe_name = sanitize_filename_local(name_value)
% Make a short metadata label safe for use in a filename.

safe_name = char(string(name_value));
safe_name = strtrim(safe_name);
safe_name = regexprep(safe_name, '[^A-Za-z0-9_-]+', '_');
safe_name = regexprep(safe_name, '_+', '_');
safe_name = regexprep(safe_name, '^_+|_+$', '');
if isempty(safe_name)
    safe_name = 'unnamed';
end
end
