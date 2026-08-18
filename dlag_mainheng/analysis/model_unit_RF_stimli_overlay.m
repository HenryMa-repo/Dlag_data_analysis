%% =========================================================================
% model_unit_RF_stimli_overlay
%
% Purpose
% -------
% Plot RF results for three model-related populations without recomputing RF:
%   1. model-used units
%   2. all recording sites in the model-used areas
%   3. unique recording sites corresponding to the model-used units
%
% For the run selected by target_stim_tag, the program creates:
%
% 1. One all-object 2-D RF mosaic per probe and population.
%    - Contains every selected object, regardless of RF R^2.
%    - Units are sorted by descending depth; at the same depth, the smaller
%      original unit index is placed first.
%    - Sites are sorted exactly as in Recording_site_RF: descending depth;
%      at the same depth, the larger 0-based site ID is placed first.
%    - The RF tile uses the original independently scaled parula display.
%    - A colored border and legend identify each object's model area.
%
% 2. One individual-object 3-D RF/stimulus plot per probe and population.
%    - Contains only objects with finite RF fits and
%      fit.rsquare >= RF_R2_threshold.
%    - Each object's RF center and 95% RF ellipse are drawn at its depth.
%    - Each area uses its user-specified color.
%    - Target stimuli are drawn in neutral gray on a bottom plane.
%    - In the readable version, unusually large x/y RF diameters are omitted
%      by the user-adjustable median + SD rule below. Axes then include the
%      complete retained ellipses and complete target stimuli.
%    - The full version retains all finite cross-threshold ellipses.
%
% 3. One combined area-mean RF/stimulus plot in the CatGT folder.
%    - Every probe-area model group is averaged independently.
%    - There is no averaging across different areas/groups.
%    - All independently computed area means and target stimuli are drawn
%      together in one figure for direct comparison.
%    - Both readable and full versions are saved.
%    - The original RF_analysis readable/full method is retained unchanged
%      for this two-dimensional mean overlay.
%
% These three figure classes are produced for:
%   unit       : model-used units
%   all_sites  : all recording sites in every model-used area
%   unit_sites : unique recording sites carrying the model-used units
%
% 4. One summary MAT file in the CatGT folder.
%    It records all three populations, model group order, colors,
%    cross-threshold selections, readable-size omissions, independently
%    computed area means, stimulus layout, and output filenames.
%
% Required input
% --------------
% Common CatGT folder:
%   model_data_allruns.mat                 variable: model_data_allruns
%
% Every probe_ksDirs entry:
%   all_unit_rf_results.mat                variable: unit_rf
%
% Every probe folder containing the corresponding probe_ksDirs entry:
%   site_rf_results.mat                    variable: site_rf
%
% Important model-data behavior
% -----------------------------
% The program uses the generic fields retained by the original RF_analysis:
%   group_name, group_probe, groupd
%   probe0_usedunit_ids/depth_um/groupname, etc.
%
% Therefore, as in the previous RF_analysis Step 2, a nan_trial_strategy = 6
% run that contains only data-field-specific unit metadata is not guessed
% here; the program stops and reports the missing generic field.
%
% Output location
% ---------------
% Every probe's kilosort folder (unit figures):
%   all_model_<areas>_unit_RF_map_depth_desc_<target>.png/.fig
%   model_<areas>_cross_threshold_unit_RF_3D_readable_<target>.png/.fig
%   model_<areas>_cross_threshold_unit_RF_3D_full_<target>.png/.fig
%
% Every probe folder containing site_rf_results.mat (site figures):
%   all_model_<areas>_all_sites_RF_map_depth_desc_<target>.png/.fig
%   all_model_<areas>_unit_sites_RF_map_depth_desc_<target>.png/.fig
%   model_<areas>_cross_threshold_<all_sites|unit_sites>_RF_3D_...
%       <readable|full>_<target>.png/.fig
%
% Common CatGT folder (one independent mean per model group; no cross-area
% averaging):
%   model_<allareas>_cross_threshold_<unit|all_sites|unit_sites>_...
%       area_mean_RF_stimulus_overlay_...
%       readable_<target>.png/.fig
%       full_<target>.png/.fig
%   model_<allareas>_cross_threshold_RF_stimulus_summary_<target>.mat
% =========================================================================

clc;
clear;


%% ----------------------- User parameters -----------------------

% Keep the order identical to probe_ksDirs in
% model_data_prepar_with_trialshuffle.m. The model uses 0-based probe labels:
% probe_ksDirs{1} -> probe 0, probe_ksDirs{2} -> probe 1, etc.
probe_ksDirs = { ...
    'I:\np_data\RafiL001p0120_g1\catgt_RafiL001p0120_g1\RafiL001p0120_g1_imec0\kilosort4_10_dedup_phy', ...
    'I:\np_data\RafiL001p0120_g1\catgt_RafiL001p0120_g1\RafiL001p0120_g1_imec1\kilosort4_2_dedup_phy' ...
};

% The model run whose selected units and stimulus layout will be plotted.
target_stim_tag = '_2[Gpl2_2c_2sz_400_2_200isi]';

% This one threshold is shared by the unit, all-sites, and unit-sites 3-D
% plots and area-mean overlays. Every 2-D RF mosaic includes all selected
% objects and is never filtered by R^2.
RF_R2_threshold = 0.5;

% Used only by the individual-object 3-D readable figures. For the x and y
% RF diameters separately, the readable upper size limit is:
%   max(median(size) + multiplier * std(size), largest stimulus diameter)
% An ellipse exceeding either x or y limit is omitted from the readable 3-D
% figure. The full 3-D figure still contains every valid cross-threshold fit.
% The combined area-mean 2-D overlay does not use this filter.
readable_size_std_multiplier = 1.5;

% Colors are positional and must follow model group order exactly:
% all areas of probe_ksDirs{1}, followed by all areas of probe_ksDirs{2}, etc.
% Column 1 is checked against target_run.group_name; column 2 is RGB.
% Duplicate area names on different probes are allowed because rows are
% matched by position, not by unique area name.
%
% Suggested palette for up to four groups:
% blue   = [0.0000 0.4470 0.7410]   (original group/probe color 1)
% orange = [0.8500 0.3250 0.0980]   (original group/probe color 2)
% green  = [0.4660 0.6740 0.1880]
% purple = [0.4940 0.1840 0.5560]
area_color = { ...
    'V1', [0.0000 0.4470 0.7410]; ...
    'MT', [0.8500 0.3250 0.0980]  ...
};

% Target stimulus plane in the 3-D plot. Depth 0 is the probe tip and is the
% natural bottom plane for the current depth convention.
stimulus_plane_depth_um = 0;

% If target conditions have no size/stimsize field, use this value.
% Keep [] to stop with an error when target stimulus size is unavailable.
target_default_stimsize = [];

% Input filenames.
model_data_filename = 'model_data_allruns.mat';
all_unit_rf_filename = 'all_unit_rf_results.mat';
site_rf_filename = 'site_rf_results.mat';

% Figure behavior. FIG files are saved with Visible='on', so double-clicking
% a saved FIG opens a visible figure even if generation was hidden.
figure_visibility = 'on';       % 'on' or 'off'
close_figures_after_save = true;
save_fig_files = true;
png_dpi = 300;


%% ----------------------- Validate basic parameters -----------------------

probe_ksDirs = normalize_probe_ksdirs(probe_ksDirs);
nProbe = numel(probe_ksDirs);

if ~(ischar(target_stim_tag) || (isstring(target_stim_tag) && isscalar(target_stim_tag)))
    error('target_stim_tag must be one text scalar.');
end
target_stim_tag = char(target_stim_tag);
if isempty(target_stim_tag)
    error('target_stim_tag cannot be empty.');
end

if ~isscalar(RF_R2_threshold) || ~isnumeric(RF_R2_threshold) || ...
        ~isfinite(RF_R2_threshold)
    error('RF_R2_threshold must be one finite numeric scalar.');
end

if ~isscalar(readable_size_std_multiplier) || ...
        ~isnumeric(readable_size_std_multiplier) || ...
        ~isfinite(readable_size_std_multiplier) || ...
        readable_size_std_multiplier < 0
    error('readable_size_std_multiplier must be one finite nonnegative scalar.');
end

if ~isscalar(stimulus_plane_depth_um) || ...
        ~isnumeric(stimulus_plane_depth_um) || ...
        ~isfinite(stimulus_plane_depth_um)
    error('stimulus_plane_depth_um must be one finite numeric scalar.');
end

if ~isempty(target_default_stimsize) && ...
        (~isscalar(target_default_stimsize) || ...
         ~isnumeric(target_default_stimsize) || ...
         ~isfinite(target_default_stimsize) || ...
         target_default_stimsize <= 0)
    error('target_default_stimsize must be [] or one finite positive scalar.');
end

if ~(strcmpi(figure_visibility, 'on') || strcmpi(figure_visibility, 'off'))
    error('figure_visibility must be ''on'' or ''off''.');
end
figure_visibility = lower(char(figure_visibility));

close_figures_after_save = validate_logical_scalar( ...
    close_figures_after_save, 'close_figures_after_save');
save_fig_files = validate_logical_scalar(save_fig_files, 'save_fig_files');

if ~isscalar(png_dpi) || ~isnumeric(png_dpi) || ...
        ~isfinite(png_dpi) || png_dpi <= 0
    error('png_dpi must be one finite positive numeric scalar.');
end

model_data_filename = validate_filename_text( ...
    model_data_filename, 'model_data_filename');
all_unit_rf_filename = validate_filename_text( ...
    all_unit_rf_filename, 'all_unit_rf_filename');
site_rf_filename = validate_filename_text( ...
    site_rf_filename, 'site_rf_filename');


%% ----------------------- Load the selected model run -----------------------

catgt_folder = get_common_catgt_folder(probe_ksDirs);
model_data_file = fullfile(catgt_folder, model_data_filename);

fprintf('Common catgt_folder : %s\n', catgt_folder);
fprintf('Model data file     : %s\n', model_data_file);
fprintf('Target stim tag     : %s\n', target_stim_tag);
fprintf('RF R2 threshold     : %.6g\n', RF_R2_threshold);
fprintf('Readable size SD x  : %.6g\n', readable_size_std_multiplier);

if ~isfile(model_data_file)
    error('Missing model data file: %s', model_data_file);
end

M = load(model_data_file, 'model_data_allruns');
if ~isfield(M, 'model_data_allruns')
    error('model_data_allruns not found in %s', model_data_file);
end
model_data_allruns = M.model_data_allruns;

target_run_idx = find_model_run_by_stim_tag( ...
    model_data_allruns, target_stim_tag);
if isempty(target_run_idx)
    error('target_stim_tag not found in model_data_allruns: %s', ...
        target_stim_tag);
end
if numel(target_run_idx) > 1
    error('Duplicate target_stim_tag in model_data_allruns: %s', ...
        target_stim_tag);
end

target_run = model_data_allruns{target_run_idx};
[group_name, group_probe, groupd] = get_model_group_metadata( ...
    target_run, nProbe, target_run_idx);
nGroup = numel(groupd);

[area_color_name, area_color_rgb] = validate_area_color( ...
    area_color, group_name, group_probe);
group_display_label = make_group_display_labels(group_name, group_probe);

target_stimulus_xy_size = extract_target_stimulus_xy_size( ...
    target_run, target_default_stimsize);
target_safe_name = make_filename_safe(target_stim_tag, 70);
all_group_safe_name = make_group_bundle_safe(group_name);

fprintf('Model group order:\n');
for g = 1:nGroup
    fprintf('  group %d: probe %d / %-20s / %d units / color [%g %g %g]\n', ...
        g, group_probe(g), group_name{g}, groupd(g), ...
        area_color_rgb(g,1), area_color_rgb(g,2), area_color_rgb(g,3));
end


%% ----------------------- Initialize summary -----------------------

model_unit_rf_stimulus_summary = struct();
model_unit_rf_stimulus_summary.program = mfilename;
model_unit_rf_stimulus_summary.model_data_file = model_data_file;
model_unit_rf_stimulus_summary.model_data_filename = model_data_filename;
model_unit_rf_stimulus_summary.target_stim_tag = target_stim_tag;
model_unit_rf_stimulus_summary.target_run_idx = target_run_idx;
model_unit_rf_stimulus_summary.RF_R2_threshold = RF_R2_threshold;
model_unit_rf_stimulus_summary.threshold_rule = 'fit.rsquare >= RF_R2_threshold';
model_unit_rf_stimulus_summary.readable_size_std_multiplier = ...
    readable_size_std_multiplier;
model_unit_rf_stimulus_summary.readable_3d_rule = [ ...
    'For x and y RF diameters separately: limit = max(median(size) + ' ...
    'multiplier*std(size), largest stimulus diameter); omit an ellipse ' ...
    'when either diameter exceeds its limit.'];
model_unit_rf_stimulus_summary.population_definitions = struct( ...
    'unit', 'model-used units', ...
    'all_sites', 'all sites in model-used areas', ...
    'unit_sites', 'sites corresponding to model-used units');
model_unit_rf_stimulus_summary.target_stimulus_xy_size = ...
    target_stimulus_xy_size;
model_unit_rf_stimulus_summary.stimulus_plane_depth_um = ...
    stimulus_plane_depth_um;
model_unit_rf_stimulus_summary.group_name = group_name;
model_unit_rf_stimulus_summary.group_probe = group_probe;
model_unit_rf_stimulus_summary.groupd = groupd;
model_unit_rf_stimulus_summary.group_display_label = group_display_label;
model_unit_rf_stimulus_summary.area_color_name = area_color_name;
model_unit_rf_stimulus_summary.area_color_rgb = area_color_rgb;
model_unit_rf_stimulus_summary.probe_ksDirs = probe_ksDirs;

unit_probe_summaries = cell(nProbe, 1);
all_sites_probe_summaries = cell(nProbe, 1);
unit_sites_probe_summaries = cell(nProbe, 1);


%% ----------------------- Plot each probe separately -----------------------

for p = 1:nProbe
    probe_id = p - 1;
    model_group_indices = find(group_probe == probe_id);

    if isempty(model_group_indices)
        error('No model group is assigned to probe %d.', probe_id);
    end

    fprintf('\n============================================================\n');
    fprintf('Processing probe %d\n', probe_id);
    fprintf('ksDir: %s\n', probe_ksDirs{p});
    fprintf('============================================================\n');

    [model_unit_ids, model_unit_depth_um, model_unit_groupname] = ...
        get_model_probe_unit_metadata(target_run, probe_id, target_run_idx);

    rf_file = fullfile(probe_ksDirs{p}, all_unit_rf_filename);
    if ~isfile(rf_file)
        error('Missing RF result file: %s', rf_file);
    end

    Srf = load(rf_file, 'unit_rf');
    if ~isfield(Srf, 'unit_rf')
        error('unit_rf not found in %s', rf_file);
    end

    unit_result = build_probe_result( ...
        Srf.unit_rf, rf_file, probe_id, probe_ksDirs{p}, ...
        model_unit_ids, model_unit_depth_um, model_unit_groupname, ...
        model_group_indices, group_name, group_probe, groupd, ...
        RF_R2_threshold);

    probe_area_safe_name = make_group_bundle_safe( ...
        group_name(model_group_indices));

    %% ---- Load recording-site RFs and build both site populations ----

    probe_folder = fileparts(probe_ksDirs{p});
    site_rf_file = fullfile(probe_folder, site_rf_filename);
    if ~isfile(site_rf_file)
        error('Missing recording-site RF result file: %s', site_rf_file);
    end

    Ssite = load(site_rf_file, 'site_rf');
    if ~isfield(Ssite, 'site_rf')
        error('site_rf not found in %s', site_rf_file);
    end

    [all_sites_result, unit_sites_result] = ...
        build_site_population_results( ...
        Ssite.site_rf, site_rf_file, probe_id, probe_folder, ...
        unit_result, model_group_indices, group_name, group_probe, ...
        RF_R2_threshold);

    %% ---- Create the three figure classes for all three populations ----

    unit_result = create_population_outputs( ...
        unit_result, probe_ksDirs{p}, 'unit', 'model units', ...
        probe_area_safe_name, target_safe_name, target_stim_tag, ...
        target_stimulus_xy_size, stimulus_plane_depth_um, ...
        group_display_label, area_color_rgb, RF_R2_threshold, ...
        readable_size_std_multiplier, figure_visibility, ...
        close_figures_after_save, save_fig_files, png_dpi);

    all_sites_result = create_population_outputs( ...
        all_sites_result, probe_folder, 'all_sites', ...
        'sites in model-used areas', ...
        probe_area_safe_name, target_safe_name, target_stim_tag, ...
        target_stimulus_xy_size, stimulus_plane_depth_um, ...
        group_display_label, area_color_rgb, RF_R2_threshold, ...
        readable_size_std_multiplier, figure_visibility, ...
        close_figures_after_save, save_fig_files, png_dpi);

    unit_sites_result = create_population_outputs( ...
        unit_sites_result, probe_folder, 'unit_sites', ...
        'sites corresponding to model units', ...
        probe_area_safe_name, target_safe_name, target_stim_tag, ...
        target_stimulus_xy_size, stimulus_plane_depth_um, ...
        group_display_label, area_color_rgb, RF_R2_threshold, ...
        readable_size_std_multiplier, figure_visibility, ...
        close_figures_after_save, save_fig_files, png_dpi);

    % RF maps are needed for plotting but would duplicate source RF files
    % inside the CatGT summary MAT.
    unit_probe_summaries{p} = remove_population_rf_map(unit_result);
    all_sites_probe_summaries{p} = ...
        remove_population_rf_map(all_sites_result);
    unit_sites_probe_summaries{p} = ...
        remove_population_rf_map(unit_sites_result);
end


%% ----------------------- Compute each area mean independently -----------------------

unit_group_summary = compute_population_group_summaries( ...
    unit_probe_summaries, group_name, group_probe, groupd, ...
    group_display_label, area_color_rgb, RF_R2_threshold, 'unit');
all_sites_group_summary = compute_population_group_summaries( ...
    all_sites_probe_summaries, group_name, group_probe, [], ...
    group_display_label, area_color_rgb, RF_R2_threshold, 'all_sites');
unit_sites_group_summary = compute_population_group_summaries( ...
    unit_sites_probe_summaries, group_name, group_probe, [], ...
    group_display_label, area_color_rgb, RF_R2_threshold, 'unit_sites');

% Keep .probe and .group as the unit-analysis fields for compatibility with
% the previous version, and add explicit fields for both site populations.
model_unit_rf_stimulus_summary.probe = vertcat(unit_probe_summaries{:});
model_unit_rf_stimulus_summary.group = unit_group_summary;
model_unit_rf_stimulus_summary.all_sites_probe = ...
    vertcat(all_sites_probe_summaries{:});
model_unit_rf_stimulus_summary.all_sites_group = all_sites_group_summary;
model_unit_rf_stimulus_summary.unit_sites_probe = ...
    vertcat(unit_sites_probe_summaries{:});
model_unit_rf_stimulus_summary.unit_sites_group = unit_sites_group_summary;


%% ----------------------- Plot all independent area means together -----------------------

unit_mean_output = create_population_mean_outputs( ...
    unit_group_summary, catgt_folder, 'unit', 'model units', ...
    all_group_safe_name, target_safe_name, target_stim_tag, ...
    target_stimulus_xy_size, RF_R2_threshold, figure_visibility, ...
    close_figures_after_save, save_fig_files, png_dpi);
all_sites_mean_output = create_population_mean_outputs( ...
    all_sites_group_summary, catgt_folder, 'all_sites', ...
    'sites in model-used areas', all_group_safe_name, ...
    target_safe_name, target_stim_tag, target_stimulus_xy_size, ...
    RF_R2_threshold, figure_visibility, close_figures_after_save, ...
    save_fig_files, png_dpi);
unit_sites_mean_output = create_population_mean_outputs( ...
    unit_sites_group_summary, catgt_folder, 'unit_sites', ...
    'sites corresponding to model units', all_group_safe_name, ...
    target_safe_name, target_stim_tag, target_stimulus_xy_size, ...
    RF_R2_threshold, figure_visibility, close_figures_after_save, ...
    save_fig_files, png_dpi);

model_unit_rf_stimulus_summary.output = struct();
model_unit_rf_stimulus_summary.output.area_mean_overlay_readable_png = ...
    unit_mean_output.area_mean_overlay_readable_png;
model_unit_rf_stimulus_summary.output.area_mean_overlay_readable_fig = ...
    unit_mean_output.area_mean_overlay_readable_fig;
model_unit_rf_stimulus_summary.output.area_mean_overlay_full_png = ...
    unit_mean_output.area_mean_overlay_full_png;
model_unit_rf_stimulus_summary.output.area_mean_overlay_full_fig = ...
    unit_mean_output.area_mean_overlay_full_fig;
model_unit_rf_stimulus_summary.output.unit = unit_mean_output;
model_unit_rf_stimulus_summary.output.all_sites = all_sites_mean_output;
model_unit_rf_stimulus_summary.output.unit_sites = unit_sites_mean_output;

summary_stem = sprintf( ...
    'model_%s_cross_threshold_RF_stimulus_summary_%s', ...
    all_group_safe_name, target_safe_name);
summary_mat_file = fullfile(catgt_folder, [summary_stem '.mat']);
model_unit_rf_stimulus_summary.output.summary_mat = summary_mat_file;

save(summary_mat_file, 'model_unit_rf_stimulus_summary');

fprintf('\nSaved combined independent-area mean overlays and summary:\n');
fprintf('  %s\n', unit_mean_output.area_mean_overlay_readable_png);
fprintf('  %s\n', all_sites_mean_output.area_mean_overlay_readable_png);
fprintf('  %s\n', unit_sites_mean_output.area_mean_overlay_readable_png);
fprintf('  %s\n', summary_mat_file);
fprintf('\nDone.\n');


%% ======================= Local functions =======================

function probe_ksDirs = normalize_probe_ksdirs(probe_ksDirs)
if ~iscell(probe_ksDirs) || isempty(probe_ksDirs)
    error('probe_ksDirs must be one nonempty cell array.');
end

probe_ksDirs = probe_ksDirs(:);
for p = 1:numel(probe_ksDirs)
    value = probe_ksDirs{p};
    if isstring(value) && isscalar(value)
        value = char(value);
    end
    if ~ischar(value) || isempty(strtrim(value))
        error('probe_ksDirs{%d} must be one nonempty path.', p);
    end
    value = strtrim(value);
    if ~isfolder(value)
        error('probe_ksDirs{%d} does not exist: %s', p, value);
    end
    probe_ksDirs{p} = value;
end
end


function value = validate_logical_scalar(value, parameter_name)
if ~(islogical(value) || isnumeric(value)) || ...
        ~isscalar(value) || ~isfinite(double(value)) || ...
        ~ismember(double(value), [0 1])
    error('%s must be one logical scalar.', parameter_name);
end
value = logical(value);
end


function catgt_folder = get_common_catgt_folder(probe_ksDirs)
catgt_list = cell(numel(probe_ksDirs), 1);
for p = 1:numel(probe_ksDirs)
    probe_folder = fileparts(probe_ksDirs{p});
    catgt_list{p} = fileparts(probe_folder);
end

catgt_folder = catgt_list{1};
for p = 2:numel(catgt_list)
    if ~strcmp(catgt_folder, catgt_list{p})
        error(['All probe_ksDirs must belong to the same CatGT folder.\n' ...
            'Got:\n%s\n%s'], catgt_folder, catgt_list{p});
    end
end
end


function run_idx = find_model_run_by_stim_tag(model_data_allruns, target_stim_tag)
if ~iscell(model_data_allruns)
    error('model_data_allruns must be a cell array.');
end

run_idx = [];
for r = 1:numel(model_data_allruns)
    entry = model_data_allruns{r};
    if isempty(entry) || ~isstruct(entry) || ~isfield(entry, 'stim_tag')
        continue;
    end
    if strcmp(entry.stim_tag, target_stim_tag)
        run_idx(end+1) = r; %#ok<AGROW>
    end
end
end


function [group_name, group_probe, groupd] = get_model_group_metadata( ...
        target_run, nProbe, target_run_idx)
required = {'group_name', 'group_probe', 'groupd'};
for k = 1:numel(required)
    if ~isfield(target_run, required{k})
        if isfield(target_run, 'nan_trial_strategy') && ...
                isequal(target_run.nan_trial_strategy, 6)
            error([ ...
                'model_data_allruns{%d} uses nan_trial_strategy = 6 and ' ...
                'does not contain generic %s metadata. As in the previous ' ...
                'RF_analysis Step 2, this program does not guess which ' ...
                'data-field-specific unit set was used.'], ...
                target_run_idx, required{k});
        else
            error('model_data_allruns{%d}.%s is missing.', ...
                target_run_idx, required{k});
        end
    end
end

group_name = normalize_text_list( ...
    target_run.group_name, 'target_run.group_name');
group_name = group_name(:)';
group_probe = double(target_run.group_probe(:)');
groupd = double(target_run.groupd(:)');

nGroup = numel(groupd);
if nGroup == 0 || numel(group_name) ~= nGroup || ...
        numel(group_probe) ~= nGroup
    error('group_name, group_probe, and groupd must have the same nonzero length.');
end
if any(~isfinite(group_probe)) || any(group_probe ~= round(group_probe)) || ...
        any(group_probe < 0) || any(group_probe >= nProbe)
    error('target_run.group_probe contains an invalid 0-based probe index.');
end
if any(~isfinite(groupd)) || any(groupd ~= round(groupd)) || any(groupd <= 0)
    error('Every target_run.groupd entry must be one positive integer.');
end

% The model-preparation program stacks all groups of one probe together.
% Therefore group_probe must be nondecreasing in flattened model order.
if any(diff(group_probe) < 0)
    error(['target_run.group_probe is not ordered by probe. Expected all ' ...
        'areas of probe 0, then all areas of probe 1, etc.']);
end

for p = 0:(nProbe-1)
    if ~any(group_probe == p)
        error('No target_run group belongs to probe %d.', p);
    end
end
end


function [color_names, color_rgb] = validate_area_color( ...
        area_color, group_name, group_probe)
nGroup = numel(group_name);

if ~iscell(area_color) || size(area_color, 2) ~= 2 || ...
        size(area_color, 1) ~= nGroup
    error(['area_color must be an Ngroup x 2 cell array. Ngroup = %d for ' ...
        'the selected model run.'], nGroup);
end

color_names = cell(1, nGroup);
color_rgb = nan(nGroup, 3);

for g = 1:nGroup
    name_value = area_color{g,1};
    if isstring(name_value) && isscalar(name_value)
        name_value = char(name_value);
    end
    if ~ischar(name_value) || isempty(strtrim(name_value))
        error('area_color{%d,1} must contain one nonempty area name.', g);
    end
    name_value = strtrim(name_value);

    if ~strcmp(name_value, group_name{g})
        error([ ...
            'area_color row %d does not match model group order. ' ...
            'Expected probe %d / %s, but got %s.'], ...
            g, group_probe(g), group_name{g}, name_value);
    end

    rgb = area_color{g,2};
    if ~isnumeric(rgb) || numel(rgb) ~= 3 || ...
            any(~isfinite(double(rgb(:)))) || ...
            any(double(rgb(:)) < 0) || any(double(rgb(:)) > 1)
        error(['area_color{%d,2} must be one finite numeric RGB vector ' ...
            'with three values in [0,1].'], g);
    end

    color_names{g} = name_value;
    color_rgb(g,:) = double(rgb(:)');
end
end


function labels = make_group_display_labels(group_name, group_probe)
nGroup = numel(group_name);
labels = cell(1, nGroup);

for g = 1:nGroup
    if sum(strcmp(group_name, group_name{g})) > 1
        labels{g} = sprintf('probe %d / %s', ...
            group_probe(g), group_name{g});
    else
        labels{g} = group_name{g};
    end
end
end


function [unit_ids, unit_depth_um, unit_groupname] = ...
        get_model_probe_unit_metadata(target_run, probe_id, target_run_idx)
base = sprintf('probe%d_usedunit', probe_id);
ids_field = [base '_ids'];
depth_field = [base '_depth_um'];
group_field = [base '_groupname'];
required = {ids_field, depth_field, group_field};

for k = 1:numel(required)
    if ~isfield(target_run, required{k})
        if isfield(target_run, 'nan_trial_strategy') && ...
                isequal(target_run.nan_trial_strategy, 6)
            error([ ...
                'model_data_allruns{%d} uses nan_trial_strategy = 6 and ' ...
                'does not contain generic field %s. As in the previous ' ...
                'RF_analysis Step 2, no data field is guessed.'], ...
                target_run_idx, required{k});
        else
            error('model_data_allruns{%d}.%s is missing.', ...
                target_run_idx, required{k});
        end
    end
end

unit_ids = target_run.(ids_field);
unit_ids = unit_ids(:);
unit_depth_um = double(target_run.(depth_field));
unit_depth_um = unit_depth_um(:);
unit_groupname = normalize_text_list( ...
    target_run.(group_field), ['target_run.' group_field]);
unit_groupname = unit_groupname(:);

nUnit = numel(unit_ids);
if numel(unit_depth_um) ~= nUnit || numel(unit_groupname) ~= nUnit
    error(['Model probe %d unit IDs, depth, and groupname do not have ' ...
        'the same length.'], probe_id);
end
if nUnit == 0
    error('Model probe %d contains no selected units.', probe_id);
end
if ~isnumeric(unit_ids) || any(~isfinite(double(unit_ids))) || ...
        numel(unique(unit_ids)) ~= nUnit
    error('Model probe %d unit_ids must be finite and unique.', probe_id);
end
if any(~isfinite(unit_depth_um))
    bad = find(~isfinite(unit_depth_um));
    show_bad = bad(1:min(20,numel(bad)));
    error(['NaN/Inf model unit depth found for probe %d. Affected unit IDs ' ...
        '(up to 20): %s'], probe_id, ...
        mat2str(double(unit_ids(show_bad))'));
end
end


function probe_result = build_probe_result( ...
        unit_rf, rf_file, probe_id, ksDir, ...
        model_unit_ids, model_unit_depth_um, model_unit_groupname, ...
        model_group_indices, group_name, group_probe, groupd, ...
        RF_R2_threshold)

required = {'probe_idx', 'unit_ids', 'unit_depth_um', 'unit_channel', ...
    'area_name', 'rfs', 'fit'};
for k = 1:numel(required)
    if ~isfield(unit_rf, required{k})
        error('unit_rf.%s is missing in %s', required{k}, rf_file);
    end
end
if ~isnumeric(unit_rf.probe_idx) || ~isscalar(unit_rf.probe_idx) || ...
        ~isfinite(double(unit_rf.probe_idx)) || ...
        double(unit_rf.probe_idx) ~= probe_id
    error('unit_rf.probe_idx in %s does not match probe %d.', ...
        rf_file, probe_id);
end
if ~isstruct(unit_rf.rfs) || ~isfield(unit_rf.rfs, 'map')
    error('unit_rf.rfs.map is missing in %s', rf_file);
end
fit_required = {'center', 'size', 'rsquare'};
for k = 1:numel(fit_required)
    if ~isstruct(unit_rf.fit) || ~isfield(unit_rf.fit, fit_required{k})
        error('unit_rf.fit.%s is missing in %s', fit_required{k}, rf_file);
    end
end

if ~isnumeric(unit_rf.unit_ids) || ...
        ~isnumeric(unit_rf.unit_depth_um) || ...
        ~isnumeric(unit_rf.unit_channel)
    error('unit_rf unit IDs, depths, and channels must be numeric in %s.', ...
        rf_file);
end

rf_unit_ids = unit_rf.unit_ids(:);
rf_depth = double(unit_rf.unit_depth_um(:));
rf_channel = double(unit_rf.unit_channel(:));
rf_area_name = normalize_text_list(unit_rf.area_name, 'unit_rf.area_name');
rf_area_name = rf_area_name(:);
rf_center = double(unit_rf.fit.center);
rf_size = double(unit_rf.fit.size);
rf_r2 = double(unit_rf.fit.rsquare(:));
rf_map = unit_rf.rfs.map;

nRF = numel(rf_unit_ids);
if ~isnumeric(rf_unit_ids) || any(~isfinite(double(rf_unit_ids))) || ...
        numel(unique(rf_unit_ids)) ~= nRF
    error('unit_rf.unit_ids must be finite and unique in %s', rf_file);
end
if numel(rf_depth) ~= nRF || numel(rf_channel) ~= nRF || ...
        numel(rf_area_name) ~= nRF || ...
        size(rf_center,1) ~= nRF || size(rf_center,2) ~= 2 || ...
        size(rf_size,1) ~= nRF || size(rf_size,2) ~= 2 || ...
        numel(rf_r2) ~= nRF || size(rf_map,1) ~= nRF
    error('unit_rf result dimensions are inconsistent in %s', rf_file);
end
if any(~isfinite(rf_depth))
    bad = find(~isfinite(rf_depth));
    show_bad = bad(1:min(20,numel(bad)));
    error(['NaN/Inf unit_rf.unit_depth_um found in %s. Affected unit IDs ' ...
        '(up to 20): %s'], rf_file, ...
        mat2str(double(rf_unit_ids(show_bad))'));
end

[found, rf_index] = ismember(model_unit_ids, rf_unit_ids);
if ~all(found)
    missing = model_unit_ids(~found);
    error(['Model-selected unit IDs are missing from %s for probe %d: %s'], ...
        rf_file, probe_id, mat2str(double(missing(:)')));
end

matched_depth = rf_depth(rf_index);
depth_tol = 1e-9 * max(1, max(abs([matched_depth; model_unit_depth_um])));
if any(abs(matched_depth - model_unit_depth_um) > depth_tol)
    bad = find(abs(matched_depth - model_unit_depth_um) > depth_tol, 1);
    error([ ...
        'Depth mismatch for probe %d unit %g: model %.12g um versus ' ...
        'all_unit_rf_results %.12g um.'], ...
        probe_id, double(model_unit_ids(bad)), ...
        model_unit_depth_um(bad), matched_depth(bad));
end

matched_area = rf_area_name(rf_index);
if ~all(strcmp(matched_area, model_unit_groupname))
    bad = find(~strcmp(matched_area, model_unit_groupname), 1);
    error([ ...
        'Area mismatch for probe %d unit %g: model %s versus ' ...
        'all_unit_rf_results %s.'], ...
        probe_id, double(model_unit_ids(bad)), ...
        model_unit_groupname{bad}, matched_area{bad});
end

model_group_index = nan(numel(model_unit_ids), 1);
for u = 1:numel(model_unit_ids)
    candidates = model_group_indices( ...
        strcmp(group_name(model_group_indices), model_unit_groupname{u}));
    if numel(candidates) ~= 1
        error([ ...
            'Cannot map probe %d unit %g with area %s to exactly one ' ...
            'model group.'], ...
            probe_id, double(model_unit_ids(u)), model_unit_groupname{u});
    end
    model_group_index(u) = candidates;
end

for ii = 1:numel(model_group_indices)
    g = model_group_indices(ii);
    if group_probe(g) ~= probe_id
        error('Internal probe/group mismatch for model group %d.', g);
    end
    observed = sum(model_group_index == g);
    if observed ~= groupd(g)
        error([ ...
            'Model group count mismatch for probe %d / area %s: ' ...
            'groupd=%d, metadata contains %d units.'], ...
            probe_id, group_name{g}, groupd(g), observed);
    end
end

center = rf_center(rf_index,:);
rf_size = rf_size(rf_index,:);
r2 = rf_r2(rf_index);
model_unit_channel = rf_channel(rf_index);

cross_threshold = isfinite(r2) & (r2 >= RF_R2_threshold) & ...
    all(isfinite(center), 2) & all(isfinite(rf_size), 2) & ...
    all(rf_size > 0, 2) & isfinite(model_unit_depth_um);

depth_desc_order = get_depth_desc_order( ...
    model_unit_depth_um, rf_index);

probe_result = struct();
probe_result.population_type = 'unit';
probe_result.probe_id = probe_id;
probe_result.ksDir = ksDir;
probe_result.all_unit_rf_file = rf_file;
probe_result.model_group_indices = model_group_indices(:)';
probe_result.model_unit_ids = model_unit_ids(:);
probe_result.model_unit_depth_um = model_unit_depth_um(:);
probe_result.model_unit_channel = model_unit_channel(:);
probe_result.model_unit_groupname = model_unit_groupname(:);
probe_result.model_group_index_per_unit = model_group_index(:);
probe_result.original_unit_index = rf_index(:);
probe_result.rf_center = center;
probe_result.rf_size = rf_size;
probe_result.rf_rsquare = r2;
probe_result.cross_threshold_mask = cross_threshold;
probe_result.cross_threshold_unit_ids = model_unit_ids(cross_threshold);
probe_result.depth_desc_order = depth_desc_order;
probe_result.rf_map = rf_map(rf_index,:,:);

% Common population fields used by plotting and group-mean functions.
probe_result.object_ids = model_unit_ids(:);
probe_result.object_depth_um = model_unit_depth_um(:);
probe_result.object_groupname = model_unit_groupname(:);
probe_result.object_group_index = model_group_index(:);
probe_result.source_index = rf_index(:);
probe_result.cross_threshold_object_ids = model_unit_ids(cross_threshold);
probe_result.n_objects = numel(model_unit_ids);
probe_result.n_cross_threshold_objects = sum(cross_threshold);
end


function order = get_depth_desc_order(depth_um, original_unit_index)
depth_um = double(depth_um(:));
original_unit_index = double(original_unit_index(:));

if numel(depth_um) ~= numel(original_unit_index)
    error('Depth and original unit index lengths do not match.');
end

local_index = (1:numel(depth_um))';
sort_table = [-depth_um, original_unit_index, local_index];
[~, pos] = sortrows(sort_table, [1 2 3]);
order = local_index(pos);
end


function [all_sites_result, unit_sites_result] = ...
        build_site_population_results( ...
        site_rf, site_rf_file, probe_id, probe_folder, unit_result, ...
        model_group_indices, group_name, group_probe, RF_R2_threshold)

required = {'probe_idx', 'site_ids', 'site_depth_um', ...
    'site_area_name', 'rfs', 'fit'};
for k = 1:numel(required)
    if ~isfield(site_rf, required{k})
        error('site_rf.%s is missing in %s', required{k}, site_rf_file);
    end
end
if ~isnumeric(site_rf.probe_idx) || ~isscalar(site_rf.probe_idx) || ...
        ~isfinite(double(site_rf.probe_idx)) || ...
        double(site_rf.probe_idx) ~= probe_id
    error('site_rf.probe_idx in %s does not match probe %d.', ...
        site_rf_file, probe_id);
end
if ~isstruct(site_rf.rfs) || ~isfield(site_rf.rfs, 'map')
    error('site_rf.rfs.map is missing in %s', site_rf_file);
end
fit_required = {'center', 'size', 'rsquare'};
for k = 1:numel(fit_required)
    if ~isstruct(site_rf.fit) || ~isfield(site_rf.fit, fit_required{k})
        error('site_rf.fit.%s is missing in %s', ...
            fit_required{k}, site_rf_file);
    end
end

if ~isnumeric(site_rf.site_ids) || ...
        ~isnumeric(site_rf.site_depth_um)
    error('site_rf site IDs and depths must be numeric in %s.', site_rf_file);
end

site_ids = double(site_rf.site_ids(:));
site_depth_um = double(site_rf.site_depth_um(:));
site_area_name = normalize_text_list( ...
    site_rf.site_area_name, 'site_rf.site_area_name');
site_area_name = site_area_name(:);
site_center = double(site_rf.fit.center);
site_size = double(site_rf.fit.size);
site_r2 = double(site_rf.fit.rsquare(:));
site_map = site_rf.rfs.map;
nSite = numel(site_ids);

if nSite == 0 || any(~isfinite(site_ids)) || any(site_ids < 0) || ...
        any(site_ids ~= round(site_ids)) || ...
        numel(unique(site_ids)) ~= nSite
    error(['site_rf.site_ids must be nonempty, finite, nonnegative, integer, ' ...
        'and unique in %s.'], ...
        site_rf_file);
end
if numel(site_depth_um) ~= nSite || numel(site_area_name) ~= nSite || ...
        size(site_center,1) ~= nSite || size(site_center,2) ~= 2 || ...
        size(site_size,1) ~= nSite || size(site_size,2) ~= 2 || ...
        numel(site_r2) ~= nSite || size(site_map,1) ~= nSite
    error('site_rf result dimensions are inconsistent in %s', site_rf_file);
end
if any(~isfinite(site_depth_um))
    bad = find(~isfinite(site_depth_um));
    show_bad = bad(1:min(20,numel(bad)));
    error(['NaN/Inf site_rf.site_depth_um found in %s. Affected site IDs ' ...
        '(up to 20): %s'], site_rf_file, mat2str(site_ids(show_bad)'));
end

site_group_index = nan(nSite,1);
for ii = 1:numel(model_group_indices)
    g = model_group_indices(ii);
    if group_probe(g) ~= probe_id
        error('Internal probe/group mismatch for model group %d.', g);
    end
    take = strcmp(site_area_name, group_name{g});
    if ~any(take)
        error(['No recording site in %s belongs to requested model area ' ...
            'probe %d / %s.'], site_rf_file, probe_id, group_name{g});
    end
    if any(isfinite(site_group_index(take)))
        error('A recording site maps to multiple model groups in %s.', ...
            site_rf_file);
    end
    site_group_index(take) = g;
end

all_site_indices = find(isfinite(site_group_index));
all_sites_result = make_site_population_result( ...
    'all_sites', site_rf_file, probe_folder, probe_id, ...
    model_group_indices, site_ids, site_depth_um, site_area_name, ...
    site_group_index, site_center, site_size, site_r2, site_map, ...
    all_site_indices, cell(numel(all_site_indices),1), RF_R2_threshold);

% Map every model-used unit's Phy channel directly to the 0-based
% acquisition-channel site ID, as requested. No conversion or nearest-site
% fallback is permitted.
unit_channels = double(unit_result.model_unit_channel(:));
if any(~isfinite(unit_channels)) || any(unit_channels ~= round(unit_channels)) || ...
        any(unit_channels < 0)
    bad = find(~isfinite(unit_channels) | ...
        unit_channels ~= round(unit_channels) | unit_channels < 0);
    show_bad = bad(1:min(20,numel(bad)));
    error(['NaN/Inf/negative/noninteger unit_channel prevents exact ' ...
        'unit-to-site ' ...
        'matching for probe %d. Affected unit IDs (up to 20): %s'], ...
        probe_id, mat2str(double(unit_result.model_unit_ids(show_bad))'));
end

[found_site, site_index_per_unit] = ismember(unit_channels, site_ids);
if ~all(found_site)
    missing_units = unit_result.model_unit_ids(~found_site);
    missing_channels = unit_channels(~found_site);
    error([ ...
        'Exact unit_channel to site_rf.site_ids matching failed for probe %d. ' ...
        'Unit IDs: %s; channels: %s'], ...
        probe_id, mat2str(double(missing_units(:)')), ...
        mat2str(missing_channels(:)'));
end

mapped_site_group = site_group_index(site_index_per_unit);
if any(~isfinite(mapped_site_group))
    bad = find(~isfinite(mapped_site_group), 1);
    error([ ...
        'Probe %d unit %g maps to site %g, whose area %s is not one of ' ...
        'the model-used areas.'], ...
        probe_id, double(unit_result.model_unit_ids(bad)), ...
        site_ids(site_index_per_unit(bad)), ...
        site_area_name{site_index_per_unit(bad)});
end
if any(mapped_site_group ~= unit_result.model_group_index_per_unit)
    bad = find(mapped_site_group ~= ...
        unit_result.model_group_index_per_unit, 1);
    error([ ...
        'Area mismatch while mapping probe %d unit %g to site %g: ' ...
        'unit group %s, site area %s.'], ...
        probe_id, double(unit_result.model_unit_ids(bad)), ...
        site_ids(site_index_per_unit(bad)), ...
        unit_result.model_unit_groupname{bad}, ...
        site_area_name{site_index_per_unit(bad)});
end

unit_site_indices = stable_unique_numeric(site_index_per_unit);
source_unit_ids_by_site = cell(numel(unit_site_indices),1);
for s = 1:numel(unit_site_indices)
    take_unit = site_index_per_unit == unit_site_indices(s);
    groups_here = unique(unit_result.model_group_index_per_unit(take_unit));
    if numel(groups_here) ~= 1
        error('One recording site maps to model units from multiple groups.');
    end
    source_unit_ids_by_site{s} = ...
        unit_result.model_unit_ids(take_unit);
end

unit_sites_result = make_site_population_result( ...
    'unit_sites', site_rf_file, probe_folder, probe_id, ...
    model_group_indices, site_ids, site_depth_um, site_area_name, ...
    site_group_index, site_center, site_size, site_r2, site_map, ...
    unit_site_indices, source_unit_ids_by_site, RF_R2_threshold);

for ii = 1:numel(model_group_indices)
    g = model_group_indices(ii);
    if ~any(unit_sites_result.object_group_index == g)
        error(['No unit-corresponding recording site remains for probe %d / ' ...
            'area %s.'], probe_id, group_name{g});
    end
end
end


function result = make_site_population_result( ...
        population_type, site_rf_file, probe_folder, probe_id, ...
        model_group_indices, all_site_ids, all_site_depth_um, ...
        all_site_area_name, all_site_group_index, all_center, all_size, ...
        all_r2, all_map, selected_indices, source_unit_ids_by_site, ...
        RF_R2_threshold)

selected_indices = selected_indices(:);
if isempty(selected_indices) || ...
        any(~isfinite(double(selected_indices))) || ...
        any(selected_indices ~= round(selected_indices)) || ...
        any(selected_indices < 1) || ...
        any(selected_indices > numel(all_site_ids)) || ...
        numel(unique(selected_indices)) ~= numel(selected_indices)
    error('Selected site indices for population %s are invalid.', ...
        population_type);
end
if ~iscell(source_unit_ids_by_site) || ...
        numel(source_unit_ids_by_site) ~= numel(selected_indices)
    error(['source_unit_ids_by_site does not match selected site count for ' ...
        'population %s.'], population_type);
end

site_ids = all_site_ids(selected_indices);
site_depth_um = all_site_depth_um(selected_indices);
site_area_name = all_site_area_name(selected_indices);
site_group_index = all_site_group_index(selected_indices);
center = all_center(selected_indices,:);
rf_size = all_size(selected_indices,:);
r2 = all_r2(selected_indices);

if any(~isfinite(site_group_index))
    error('Population %s contains a site outside the model-used groups.', ...
        population_type);
end

cross_threshold = isfinite(r2) & (r2 >= RF_R2_threshold) & ...
    all(isfinite(center),2) & all(isfinite(rf_size),2) & ...
    all(rf_size > 0,2) & isfinite(site_depth_um);

result = struct();
result.population_type = population_type;
result.probe_id = probe_id;
result.probe_folder = probe_folder;
result.site_rf_file = site_rf_file;
result.model_group_indices = model_group_indices(:)';
result.site_ids = site_ids(:);
result.site_depth_um = site_depth_um(:);
result.site_area_name = site_area_name(:);
result.site_group_index = site_group_index(:);
result.original_site_index = selected_indices(:);
result.source_model_unit_ids_by_site = source_unit_ids_by_site(:);
result.n_source_model_units_by_site = cellfun( ...
    @numel, source_unit_ids_by_site(:));
result.rf_center = center;
result.rf_size = rf_size;
result.rf_rsquare = r2;
result.cross_threshold_mask = cross_threshold;
result.cross_threshold_site_ids = site_ids(cross_threshold);
result.depth_desc_order = get_site_depth_desc_order( ...
    site_depth_um, site_ids);
result.rf_map = all_map(selected_indices,:,:);

% Common population fields used by plotting and group-mean functions.
result.object_ids = site_ids(:);
result.object_depth_um = site_depth_um(:);
result.object_groupname = site_area_name(:);
result.object_group_index = site_group_index(:);
result.source_index = selected_indices(:);
result.cross_threshold_object_ids = site_ids(cross_threshold);
result.n_objects = numel(site_ids);
result.n_cross_threshold_objects = sum(cross_threshold);
end


function values = stable_unique_numeric(values_in)
values_in = values_in(:);
values = zeros(0,1,'like',values_in);
for i = 1:numel(values_in)
    if ~any(values == values_in(i))
        values(end+1,1) = values_in(i); %#ok<AGROW>
    end
end
end


function order = get_site_depth_desc_order(site_depth_um, site_ids)
site_depth_um = double(site_depth_um(:));
site_ids = double(site_ids(:));
if numel(site_depth_um) ~= numel(site_ids)
    error('Site depth and site ID lengths do not match.');
end

% Match Recording_site_RF: depth descending, then larger 0-based site ID
% first, so the smaller/start-side site ID is placed later at equal depth.
local_index = (1:numel(site_ids))';
sort_table = [-site_depth_um, -site_ids, local_index];
[~, pos] = sortrows(sort_table, [1 2 3]);
order = local_index(pos);
end


function result = create_population_outputs( ...
        result, output_folder, file_token, display_name, ...
        probe_area_safe_name, target_safe_name, target_stim_tag, ...
        target_stimulus_xy_size, stimulus_plane_depth_um, ...
        group_display_label, area_color_rgb, RF_R2_threshold, ...
        readable_size_std_multiplier, figure_visibility, ...
        close_figures_after_save, save_fig_files, png_dpi)

model_group_indices = result.model_group_indices;
probe_id = result.probe_id;

map_stem = sprintf( ...
    'all_model_%s_%s_RF_map_depth_desc_%s', ...
    probe_area_safe_name, file_token, target_safe_name);
map_png_file = fullfile(output_folder, [map_stem '.png']);
map_fig_file = make_optional_fig_path( ...
    output_folder, map_stem, save_fig_files);
map_title = sprintf('All %s | probe %d | %s | n = %d', ...
    display_name, probe_id, ...
    strjoin(group_display_label(model_group_indices), ', '), ...
    numel(result.object_ids));

fig = plot_model_rf_map_2d( ...
    result, model_group_indices, group_display_label, ...
    area_color_rgb, map_title, figure_visibility);
save_figure_outputs(fig, map_png_file, map_fig_file, png_dpi, ...
    figure_visibility, close_figures_after_save);

view_modes = {'readable', 'full'};
rf3d_png_files = cell(1,2);
rf3d_fig_files = cell(1,2);
view_info = cell(1,2);

for v = 1:2
    view_mode = view_modes{v};
    rf3d_stem = sprintf( ...
        'model_%s_cross_threshold_%s_RF_3D_%s_%s', ...
        probe_area_safe_name, file_token, view_mode, target_safe_name);
    rf3d_png_files{v} = fullfile(output_folder, [rf3d_stem '.png']);
    rf3d_fig_files{v} = make_optional_fig_path( ...
        output_folder, rf3d_stem, save_fig_files);
    % Use the output basename for both the in-figure title and the FIG
    % window name. PNG and FIG share this same basename.
    rf3d_title = rf3d_stem;

    [fig, view_info{v}] = plot_population_rf_3d( ...
        result, target_stimulus_xy_size, stimulus_plane_depth_um, ...
        model_group_indices, group_display_label, area_color_rgb, ...
        RF_R2_threshold, readable_size_std_multiplier, view_mode, ...
        rf3d_title, figure_visibility);
    save_figure_outputs(fig, rf3d_png_files{v}, rf3d_fig_files{v}, ...
        png_dpi, figure_visibility, close_figures_after_save);
end

result.readable_3d = view_info{1};
result.full_3d = view_info{2};
result.output = struct();
result.output.all_rf_map_png = map_png_file;
result.output.all_rf_map_fig = map_fig_file;
result.output.cross_threshold_rf_3d_readable_png = rf3d_png_files{1};
result.output.cross_threshold_rf_3d_readable_fig = rf3d_fig_files{1};
result.output.cross_threshold_rf_3d_full_png = rf3d_png_files{2};
result.output.cross_threshold_rf_3d_full_fig = rf3d_fig_files{2};

fprintf('Saved probe %d %s figures:\n', probe_id, display_name);
fprintf('  %s\n', map_png_file);
fprintf('  %s\n', rf3d_png_files{1});
fprintf('  %s\n', rf3d_png_files{2});
end


function result = remove_population_rf_map(result)
if isfield(result, 'rf_map')
    result = rmfield(result, 'rf_map');
end
end


function unit_label = get_population_unit_label(population_type)
if strcmp(population_type, 'unit')
    unit_label = 'units';
elseif strcmp(population_type, 'all_sites') || ...
        strcmp(population_type, 'unit_sites')
    unit_label = 'sites';
else
    error('Unsupported RF population type: %s', population_type);
end
end


function fig = plot_model_rf_map_2d( ...
        probe_result, model_group_indices, group_display_label, ...
        area_color_rgb, figure_title, figure_visibility)

RFmap = probe_result.rf_map;
nObject = numel(probe_result.object_ids);
if size(RFmap,1) ~= nObject || nObject == 0
    error('RF map object dimension does not match the selected population.');
end

order = probe_result.depth_desc_order;
tile_scale = 5;
border_pix = 3;
gap_pix = 2;
margin_pix = 8;

nCols = ceil(sqrt(nObject * 1.25));
nRows = ceil(nObject / nCols);

[~, nY, nX] = size(RFmap);
inner_h = nY * tile_scale;
inner_w = nX * tile_scale;
tile_h = inner_h + 2 * border_pix;
tile_w = inner_w + 2 * border_pix;

img_h = 2 * margin_pix + nRows * tile_h + (nRows - 1) * gap_pix;
img_w = 2 * margin_pix + nCols * tile_w + (nCols - 1) * gap_pix;
mosaic_rgb = ones(img_h, img_w, 3);
cmap = parula(256);

for ii = 1:nObject
    u = order(ii);
    row = floor((ii - 1) / nCols) + 1;
    col = mod(ii - 1, nCols) + 1;

    y0 = margin_pix + (row - 1) * (tile_h + gap_pix) + 1;
    x0 = margin_pix + (col - 1) * (tile_w + gap_pix) + 1;
    y_outer = y0:(y0 + tile_h - 1);
    x_outer = x0:(x0 + tile_w - 1);

    g = probe_result.object_group_index(u);
    border_color = reshape(area_color_rgb(g,:), [1 1 3]);
    mosaic_rgb(y_outer, x_outer, :) = repmat( ...
        border_color, [numel(y_outer), numel(x_outer), 1]);

    y_inner = (y0 + border_pix):(y0 + border_pix + inner_h - 1);
    x_inner = (x0 + border_pix):(x0 + border_pix + inner_w - 1);

    Z = squeeze(RFmap(u,:,:));
    Z = flipud(Z);
    mosaic_rgb(y_inner, x_inner, :) = ...
        rf_tile_to_rgb(Z, cmap, tile_scale);
end

fig = figure('Visible', figure_visibility, 'Color', 'w', ...
    'Position', [80 80 1100 850], 'Name', figure_title, ...
    'NumberTitle', 'off');
ax = axes('Parent', fig, 'Position', [0.04 0.11 0.92 0.82]);
image(ax, mosaic_rgb);
axis(ax, 'image');
axis(ax, 'off');
title(ax, figure_title, 'Interpreter', 'none', 'FontWeight', 'bold');
hold(ax, 'on');

legend_handles = gobjects(numel(model_group_indices), 1);
legend_labels = cell(numel(model_group_indices), 1);
unit_label = get_population_unit_label(probe_result.population_type);
for ii = 1:numel(model_group_indices)
    g = model_group_indices(ii);
    legend_handles(ii) = plot(ax, NaN, NaN, 's', ...
        'MarkerSize', 10, 'LineStyle', 'none', ...
        'MarkerFaceColor', 'none', ...
        'MarkerEdgeColor', area_color_rgb(g,:), ...
        'LineWidth', 2.5);
    n_group_objects = sum(probe_result.object_group_index == g);
    legend_labels{ii} = sprintf('%s = %d %s', ...
        group_display_label{g}, n_group_objects, unit_label);
end
legend(ax, legend_handles, legend_labels, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'Interpreter', 'none', 'Box', 'off');
hold(ax, 'off');
end


function tile_rgb = rf_tile_to_rgb(Z, cmap, tile_scale)
finite_mask = isfinite(Z);
tile_h = size(Z,1) * tile_scale;
tile_w = size(Z,2) * tile_scale;
tile_rgb = ones(tile_h, tile_w, 3);

if ~any(finite_mask(:))
    return;
end

zmin = min(Z(finite_mask));
zmax = max(Z(finite_mask));
if zmax > zmin
    Zn = (Z - zmin) ./ (zmax - zmin);
elseif zmax == 0
    Zn = zeros(size(Z));
else
    Zn = 0.5 * ones(size(Z));
end
Zn(~finite_mask) = NaN;

idx = round(Zn * 255) + 1;
idx(idx < 1) = 1;
idx(idx > 256) = 256;

rgb_small = ones(size(Z,1), size(Z,2), 3);
for y = 1:size(Z,1)
    for x = 1:size(Z,2)
        if isfinite(idx(y,x))
            rgb_small(y,x,:) = reshape(cmap(idx(y,x),:), [1 1 3]);
        end
    end
end
tile_rgb = repelem(rgb_small, tile_scale, tile_scale, 1);
end


function [fig, view_info] = plot_population_rf_3d( ...
        probe_result, target_stimulus_xy_size, stimulus_plane_depth_um, ...
        model_group_indices, group_display_label, area_color_rgb, ...
        RF_R2_threshold, readable_size_std_multiplier, view_mode, ...
        figure_title, figure_visibility)

validate_view_mode(view_mode);
candidate_mask = probe_result.cross_threshold_mask(:);

if strcmpi(view_mode, 'readable')
    [plot_mask, view_info] = get_readable_3d_plot_mask( ...
        probe_result, target_stimulus_xy_size, ...
        readable_size_std_multiplier);
else
    plot_mask = candidate_mask;
    view_info = make_full_3d_view_info(probe_result, candidate_mask);
end

centers = probe_result.rf_center(plot_mask,:);
sizes = probe_result.rf_size(plot_mask,:);

[xl, yl] = get_overlay_axis_limits( ...
    target_stimulus_xy_size, centers, sizes, view_mode, true);

fig = figure('Visible', figure_visibility, 'Color', 'w', ...
    'Position', [80 60 1050 850], 'Name', figure_title, ...
    'NumberTitle', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');
xlim(ax, xl);
ylim(ax, yl);

good_depth = probe_result.object_depth_um(plot_mask);
z_values = [stimulus_plane_depth_um; good_depth(:)];
z_min = min(z_values);
z_max = max(z_values);
if z_max > z_min
    z_span = z_max - z_min;
    if stimulus_plane_depth_um <= min(z_values)
        zl = [stimulus_plane_depth_um, z_max + 0.04 * z_span];
    else
        zl = [z_min - 0.04 * z_span, z_max + 0.04 * z_span];
    end
else
    z_span = 1;
    zl = [z_min - 0.5, z_max + 0.5];
end
zlim(ax, zl);
view_info.x_limits = xl;
view_info.y_limits = yl;
view_info.z_limits = zl;
view_info.stimulus_plane_depth_um = stimulus_plane_depth_um;

draw_stimulus_floor_3d(ax, xl, yl, stimulus_plane_depth_um);
target_z_offset = max(0.01, 1e-5 * max(z_span, 1));
draw_target_stimulus_circles_3d( ...
    ax, target_stimulus_xy_size, ...
    stimulus_plane_depth_um + target_z_offset);

% Draw the visual-field meridians on the stimulus plane.
meridian_z = stimulus_plane_depth_um + 1.5 * target_z_offset;
line(ax, xl, [0 0], [meridian_z meridian_z], ...
    'Color', [0.1 0.1 0.1], 'LineWidth', 1.8);
line(ax, [0 0], yl, [meridian_z meridian_z], ...
    'Color', [0.1 0.1 0.1], 'LineWidth', 1.8);

plot_local_index = probe_result.depth_desc_order(:);
plot_local_index = plot_local_index(plot_mask(plot_local_index));
if ~isempty(plot_local_index)

    theta = linspace(0, 2*pi, 161);
    for ii = 1:numel(plot_local_index)
        u = plot_local_index(ii);
        g = probe_result.object_group_index(u);
        color_value = area_color_rgb(g,:);
        center = probe_result.rf_center(u,:);
        rf_size = probe_result.rf_size(u,:);
        depth = probe_result.object_depth_um(u);

        xe = center(1) + rf_size(1)/2 * cos(theta);
        ye = center(2) + rf_size(2)/2 * sin(theta);
        ze = depth * ones(size(theta));
        plot3(ax, xe, ye, ze, '-', ...
            'Color', color_value, 'LineWidth', 1.25);
        plot3(ax, center(1), center(2), depth, 'o', ...
            'MarkerFaceColor', color_value, ...
            'MarkerEdgeColor', [0.15 0.15 0.15], ...
            'MarkerSize', 4.5, 'LineStyle', 'none');
    end
end

xlim(ax, xl);
ylim(ax, yl);
zlim(ax, zl);
xlabel(ax, 'RF x (deg)');
ylabel(ax, 'RF y (deg)');
zlabel(ax, 'Depth from probe tip (um)');
% Keep both the in-figure title and FIG window name identical to the output
% basename. Counts and population units are reported by the legend.
title(ax, figure_title, 'Interpreter', 'none', 'FontWeight', 'bold');
grid(ax, 'on');
box(ax, 'on');
view(ax, 42, 25);
set_rf_depth_aspect(ax);

legend_handles = gobjects(numel(model_group_indices) + 1, 1);
legend_labels = cell(numel(model_group_indices) + 1, 1);
unit_label = get_population_unit_label(probe_result.population_type);
for ii = 1:numel(model_group_indices)
    g = model_group_indices(ii);
    n_good_group = sum(plot_mask & probe_result.object_group_index == g);
    legend_handles(ii) = plot3(ax, NaN, NaN, NaN, 'o-', ...
        'Color', area_color_rgb(g,:), ...
        'MarkerFaceColor', area_color_rgb(g,:), ...
        'MarkerEdgeColor', area_color_rgb(g,:), ...
        'LineWidth', 1.5, 'MarkerSize', 5);
    legend_labels{ii} = sprintf('%s = %d %s', ...
        group_display_label{g}, n_good_group, unit_label);
end
legend_handles(end) = plot3(ax, NaN, NaN, NaN, 'o', ...
    'MarkerFaceColor', [0.45 0.45 0.45], ...
    'MarkerEdgeColor', 'none', 'MarkerSize', 8, ...
    'LineStyle', 'none');
legend_labels{end} = 'Target stimuli';
legend(ax, legend_handles, legend_labels, ...
    'Location', 'best', 'Interpreter', 'none', 'Box', 'off');
hold(ax, 'off');
end


function [plot_mask, info] = get_readable_3d_plot_mask( ...
        result, target_stimulus_xy_size, multiplier)

candidate_mask = result.cross_threshold_mask(:);
candidate_size = result.rf_size(candidate_mask,:);

if isempty(target_stimulus_xy_size)
    largest_stimulus_diameter = 0;
else
    largest_stimulus_diameter = ...
        max(target_stimulus_xy_size(:,3), [], 'omitnan');
end

if isempty(candidate_size)
    size_median_xy = [NaN NaN];
    size_std_xy = [NaN NaN];
    statistical_limit_xy = [NaN NaN];
    final_limit_xy = [largest_stimulus_diameter, ...
        largest_stimulus_diameter];
    plot_mask = false(size(candidate_mask));
else
    size_median_xy = median(candidate_size, 1, 'omitnan');
    size_std_xy = std(candidate_size, 0, 1, 'omitnan');
    statistical_limit_xy = ...
        size_median_xy + multiplier .* size_std_xy;
    final_limit_xy = max(statistical_limit_xy, ...
        largest_stimulus_diameter * ones(1,2));

    keep_candidate = candidate_size(:,1) <= final_limit_xy(1) & ...
        candidate_size(:,2) <= final_limit_xy(2);
    plot_mask = false(size(candidate_mask));
    candidate_index = find(candidate_mask);
    plot_mask(candidate_index(keep_candidate)) = true;
end

outlier_mask = candidate_mask & ~plot_mask;
info = struct();
info.view_mode = 'readable';
info.readable_size_std_multiplier = multiplier;
info.largest_stimulus_diameter = largest_stimulus_diameter;
info.size_median_xy = size_median_xy;
info.size_std_xy = size_std_xy;
info.statistical_size_limit_xy = statistical_limit_xy;
info.final_size_limit_xy = final_limit_xy;
info.n_cross_threshold_candidates = sum(candidate_mask);
info.n_plotted = sum(plot_mask);
info.n_size_outliers_omitted = sum(outlier_mask);
info.cross_threshold_candidate_object_ids = ...
    result.object_ids(candidate_mask);
info.plotted_object_ids = result.object_ids(plot_mask);
info.size_outlier_object_ids = result.object_ids(outlier_mask);
end


function info = make_full_3d_view_info(result, candidate_mask)
info = struct();
info.view_mode = 'full';
info.readable_size_std_multiplier = NaN;
info.largest_stimulus_diameter = NaN;
info.size_median_xy = [NaN NaN];
info.size_std_xy = [NaN NaN];
info.statistical_size_limit_xy = [NaN NaN];
info.final_size_limit_xy = [NaN NaN];
info.n_cross_threshold_candidates = sum(candidate_mask);
info.n_plotted = sum(candidate_mask);
info.n_size_outliers_omitted = 0;
info.cross_threshold_candidate_object_ids = ...
    result.object_ids(candidate_mask);
info.plotted_object_ids = result.object_ids(candidate_mask);
info.size_outlier_object_ids = result.object_ids(false(size(candidate_mask)));
end


function draw_stimulus_floor_3d(ax, xl, yl, z_plane)
X = [xl(1) xl(2); xl(1) xl(2)];
Y = [yl(1) yl(1); yl(2) yl(2)];
Z = z_plane * ones(2,2);
surf(ax, X, Y, Z, ...
    'FaceColor', [0.92 0.92 0.92], ...
    'FaceAlpha', 0.20, ...
    'EdgeColor', [0.72 0.72 0.72], ...
    'LineStyle', '-');
end


function draw_target_stimulus_circles_3d(ax, target_stimulus_xy_size, z)
if isempty(target_stimulus_xy_size)
    return;
end

s = target_stimulus_xy_size(:,3);
[~, order] = sort(s, 'descend');
s_min = min(s);
s_max = max(s);
theta = linspace(0, 2*pi, 100);

for ii = 1:numel(order)
    k = order(ii);
    cx = target_stimulus_xy_size(k,1);
    cy = target_stimulus_xy_size(k,2);
    radius = s(k)/2;
    if s_max > s_min
        gray = 0.15 + 0.60 * (s(k)-s_min)/(s_max-s_min);
    else
        gray = 0.45;
    end
    xx = cx + radius * cos(theta);
    yy = cy + radius * sin(theta);
    zz = z * ones(size(theta));
    patch(ax, xx, yy, zz, gray * [1 1 1], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.78);
end
end


function group_summary = compute_population_group_summaries( ...
        probe_summaries, group_name, group_probe, expected_groupd, ...
        group_display_label, area_color_rgb, RF_R2_threshold, ...
        population_type)

nGroup = numel(group_name);
template = struct( ...
    'population_type', population_type, ...
    'group_index', [], ...
    'group_name', '', ...
    'group_display_label', '', ...
    'probe_id', [], ...
    'color_rgb', [], ...
    'n_objects', 0, ...
    'object_ids', [], ...
    'n_cross_threshold_objects', 0, ...
    'cross_threshold_object_ids', [], ...
    'cross_threshold_object_depth_um', [], ...
    'n_model_units', 0, ...
    'model_unit_ids', [], ...
    'n_cross_threshold_units', 0, ...
    'cross_threshold_unit_ids', [], ...
    'cross_threshold_unit_depth_um', [], ...
    'cross_threshold_center', [], ...
    'cross_threshold_size', [], ...
    'cross_threshold_rsquare', [], ...
    'n_sites', 0, ...
    'site_ids', [], ...
    'n_cross_threshold_sites', 0, ...
    'cross_threshold_site_ids', [], ...
    'cross_threshold_site_depth_um', [], ...
    'mean_center', [NaN NaN], ...
    'mean_size', [NaN NaN]);
group_summary = repmat(template, nGroup, 1);

for g = 1:nGroup
    p = group_probe(g) + 1;
    if p < 1 || p > numel(probe_summaries)
        error('Invalid probe index for group %d.', g);
    end
    probe_result = probe_summaries{p};
    take_object = probe_result.object_group_index == g;
    n_object = sum(take_object);
    if n_object == 0
        error('Population %s contains no object for model group %d.', ...
            population_type, g);
    end
    if ~isempty(expected_groupd) && n_object ~= expected_groupd(g)
        error(['Population %s object count changed unexpectedly for group ' ...
            '%d: expected %d, found %d.'], ...
            population_type, g, expected_groupd(g), n_object);
    end

    take_good = take_object & probe_result.cross_threshold_mask;
    good_center = probe_result.rf_center(take_good,:);
    good_size = probe_result.rf_size(take_good,:);

    group_summary(g).group_index = g;
    group_summary(g).group_name = group_name{g};
    group_summary(g).group_display_label = group_display_label{g};
    group_summary(g).probe_id = group_probe(g);
    group_summary(g).color_rgb = area_color_rgb(g,:);
    group_summary(g).n_objects = n_object;
    group_summary(g).object_ids = probe_result.object_ids(take_object);
    group_summary(g).n_cross_threshold_objects = sum(take_good);
    group_summary(g).cross_threshold_object_ids = ...
        probe_result.object_ids(take_good);
    group_summary(g).cross_threshold_object_depth_um = ...
        probe_result.object_depth_um(take_good);
    group_summary(g).cross_threshold_center = good_center;
    group_summary(g).cross_threshold_size = good_size;
    group_summary(g).cross_threshold_rsquare = ...
        probe_result.rf_rsquare(take_good);

    if strcmp(population_type, 'unit')
        group_summary(g).n_model_units = n_object;
        group_summary(g).model_unit_ids = ...
            probe_result.object_ids(take_object);
        group_summary(g).n_cross_threshold_units = sum(take_good);
        group_summary(g).cross_threshold_unit_ids = ...
            probe_result.object_ids(take_good);
        group_summary(g).cross_threshold_unit_depth_um = ...
            probe_result.object_depth_um(take_good);
    else
        group_summary(g).n_sites = n_object;
        group_summary(g).site_ids = probe_result.object_ids(take_object);
        group_summary(g).n_cross_threshold_sites = sum(take_good);
        group_summary(g).cross_threshold_site_ids = ...
            probe_result.object_ids(take_good);
        group_summary(g).cross_threshold_site_depth_um = ...
            probe_result.object_depth_um(take_good);
    end

    if any(take_good)
        % This is an independent within-group arithmetic mean. No value from
        % another area/group enters this mean.
        group_summary(g).mean_center = mean(good_center, 1, 'omitnan');
        group_summary(g).mean_size = mean(good_size, 1, 'omitnan');
    else
        warning([ ...
            'No %s object in probe %d / area %s has a finite positive-size ' ...
            'RF fit with R^2 >= %.6g. Its mean ellipse will be omitted.'], ...
            population_type, group_probe(g), group_name{g}, RF_R2_threshold);
    end
end
end


function output = create_population_mean_outputs( ...
        group_summary, catgt_folder, file_token, display_name, ...
        all_group_safe_name, target_safe_name, target_stim_tag, ...
        target_stimulus_xy_size, RF_R2_threshold, figure_visibility, ...
        close_figures_after_save, save_fig_files, png_dpi)

view_modes = {'readable', 'full'};
png_files = cell(1,2);
fig_files = cell(1,2);

for v = 1:2
    view_mode = view_modes{v};
    mean_stem = sprintf( ...
        ['model_%s_cross_threshold_%s_area_mean_RF_stimulus_' ...
         'overlay_%s_%s'], ...
        all_group_safe_name, file_token, view_mode, target_safe_name);
    png_files{v} = fullfile(catgt_folder, [mean_stem '.png']);
    fig_files{v} = make_optional_fig_path( ...
        catgt_folder, mean_stem, save_fig_files);
    % Use the output basename for both the in-figure title and the FIG
    % window name. PNG and FIG share this same basename.
    mean_title = mean_stem;

    % This function intentionally retains the original two-dimensional
    % combined-mean readable/full axis method. The individual-object 3-D
    % readable size filter is not applied here.
    fig = plot_independent_area_mean_overlay( ...
        group_summary, target_stimulus_xy_size, RF_R2_threshold, ...
        view_mode, mean_title, figure_visibility);
    save_figure_outputs(fig, png_files{v}, fig_files{v}, png_dpi, ...
        figure_visibility, close_figures_after_save);
end

output = struct();
output.population_type = file_token;
output.area_mean_overlay_readable_png = png_files{1};
output.area_mean_overlay_readable_fig = fig_files{1};
output.area_mean_overlay_full_png = png_files{2};
output.area_mean_overlay_full_fig = fig_files{2};

fprintf('Saved combined %s area-mean overlays:\n', display_name);
fprintf('  %s\n', png_files{1});
fprintf('  %s\n', png_files{2});
end


function fig = plot_independent_area_mean_overlay( ...
        group_summary, target_stimulus_xy_size, RF_R2_threshold, ...
        view_mode, figure_title, figure_visibility)

validate_view_mode(view_mode);
nGroup = numel(group_summary);
all_centers = reshape([group_summary.mean_center], 2, [])';
all_sizes = reshape([group_summary.mean_size], 2, [])';

fig = figure('Visible', figure_visibility, 'Color', 'w', ...
    'Position', [100 80 900 820], 'Name', figure_title, ...
    'NumberTitle', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');

draw_target_stimulus_circles_2d(ax, target_stimulus_xy_size);

legend_handles = gobjects(nGroup + 1, 1);
legend_labels = cell(nGroup + 1, 1);
unit_label = get_population_unit_label(group_summary(1).population_type);
for g = 1:nGroup
    color_value = group_summary(g).color_rgb;
    center = group_summary(g).mean_center;
    rf_size = group_summary(g).mean_size;

    if all(isfinite(center)) && all(isfinite(rf_size)) && all(rf_size > 0)
        legend_handles(g) = draw_rf_ellipse_2d( ...
            ax, center, rf_size, color_value, 2.3);
        plot(ax, center(1), center(2), 'o', ...
            'MarkerFaceColor', color_value, ...
            'MarkerEdgeColor', color_value, ...
            'MarkerSize', 6, 'LineStyle', 'none');
    else
        legend_handles(g) = plot(ax, NaN, NaN, '-', ...
            'Color', color_value, 'LineWidth', 2.3);
    end

    legend_labels{g} = sprintf('%s mean = %d %s', ...
        group_summary(g).group_display_label, ...
        group_summary(g).n_cross_threshold_objects, unit_label);
end

legend_handles(end) = plot(ax, NaN, NaN, 'o', ...
    'MarkerFaceColor', [0.45 0.45 0.45], ...
    'MarkerEdgeColor', 'none', 'MarkerSize', 8, ...
    'LineStyle', 'none');
legend_labels{end} = 'Target stimuli';

axis(ax, 'equal');
box(ax, 'off');
grid(ax, 'off');
title(ax, figure_title, 'Interpreter', 'none', 'FontWeight', 'bold');

% Match the old combined-mean RF_analysis behavior: readable and full
% views both include the complete independently computed mean ellipses.
set_overlay_axis_limits(ax, target_stimulus_xy_size, ...
    all_centers, all_sizes, view_mode, true);
format_rf_overlay_axis(ax);
legend(ax, legend_handles, legend_labels, ...
    'Location', 'eastoutside', 'Interpreter', 'none', 'Box', 'off');
hold(ax, 'off');
end


function draw_target_stimulus_circles_2d(ax, target_stimulus_xy_size)
if isempty(target_stimulus_xy_size)
    return;
end

s = target_stimulus_xy_size(:,3);
[~, order] = sort(s, 'descend');
s_min = min(s);
s_max = max(s);
theta = linspace(0, 2*pi, 100);

for ii = 1:numel(order)
    k = order(ii);
    cx = target_stimulus_xy_size(k,1);
    cy = target_stimulus_xy_size(k,2);
    radius = s(k)/2;
    if s_max > s_min
        gray = 0.15 + 0.60 * (s(k)-s_min)/(s_max-s_min);
    else
        gray = 0.45;
    end
    xx = cx + radius * cos(theta);
    yy = cy + radius * sin(theta);
    patch(ax, xx, yy, gray * [1 1 1], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.75);
end
end


function h = draw_rf_ellipse_2d(ax, center, rf_size, color_value, line_width)
theta = linspace(0, 2*pi, 180);
xx = center(1) + rf_size(1)/2 * cos(theta);
yy = center(2) + rf_size(2)/2 * sin(theta);
h = line(ax, xx, yy, ...
    'Color', color_value, 'LineWidth', line_width);
end


function set_overlay_axis_limits( ...
        ax, target_stimulus_xy_size, centers, sizes, ...
        view_mode, include_size_in_readable)
[xl, yl] = get_overlay_axis_limits( ...
    target_stimulus_xy_size, centers, sizes, ...
    view_mode, include_size_in_readable);
xlim(ax, xl);
ylim(ax, yl);
end


function [xl, yl] = get_overlay_axis_limits( ...
        target_stimulus_xy_size, centers, sizes, ...
        view_mode, include_size_in_readable)

if nargin < 5 || isempty(include_size_in_readable)
    include_size_in_readable = false;
end
validate_view_mode(view_mode);

xs = [];
ys = [];

if ~isempty(target_stimulus_xy_size)
    x = target_stimulus_xy_size(:,1);
    y = target_stimulus_xy_size(:,2);
    s = target_stimulus_xy_size(:,3);
    xs = [xs; x-s/2; x+s/2]; %#ok<AGROW>
    ys = [ys; y-s/2; y+s/2]; %#ok<AGROW>
end

if ~isempty(centers)
    good_center = all(isfinite(centers), 2);
    include_size = strcmpi(view_mode, 'full') || ...
        (strcmpi(view_mode, 'readable') && include_size_in_readable);

    if include_size
        good = good_center & all(isfinite(sizes), 2);
        if any(good)
            c = centers(good,:);
            sz = sizes(good,:);
            xs = [xs; c(:,1)-sz(:,1)/2; c(:,1)+sz(:,1)/2]; %#ok<AGROW>
            ys = [ys; c(:,2)-sz(:,2)/2; c(:,2)+sz(:,2)/2]; %#ok<AGROW>
        end
    elseif any(good_center)
        c = centers(good_center,:);
        xs = [xs; c(:,1)]; %#ok<AGROW>
        ys = [ys; c(:,2)]; %#ok<AGROW>
    end
end

% Keep vertical and horizontal meridians inside both views.
xs = [xs; 0]; %#ok<AGROW>
ys = [ys; 0]; %#ok<AGROW>
xs = xs(isfinite(xs));
ys = ys(isfinite(ys));

if isempty(xs) || isempty(ys)
    xl = [-1 1];
    yl = [-1 1];
    return;
end

xmin = min(xs);
xmax = max(xs);
ymin = min(ys);
ymax = max(ys);
xrange = xmax-xmin;
yrange = ymax-ymin;
if xrange == 0
    xrange = 1;
end
if yrange == 0
    yrange = 1;
end

if strcmpi(view_mode, 'readable')
    pad = 0.25 * max(xrange, yrange);
    min_half_width = 8;
else
    pad = 0.08 * max(xrange, yrange);
    min_half_width = 0;
end

xl = [xmin-pad, xmax+pad];
yl = [ymin-pad, ymax+pad];

if min_half_width > 0
    cx = mean([xmin xmax]);
    cy = mean([ymin ymax]);
    if diff(xl) < 2*min_half_width
        xl = [cx-min_half_width, cx+min_half_width];
    end
    if diff(yl) < 2*min_half_width
        yl = [cy-min_half_width, cy+min_half_width];
    end
end
end


function validate_view_mode(view_mode)
if ~(ischar(view_mode) || (isstring(view_mode) && isscalar(view_mode))) || ...
        ~(strcmpi(view_mode, 'readable') || strcmpi(view_mode, 'full'))
    error('view_mode must be ''readable'' or ''full''.');
end
end


function set_rf_depth_aspect(ax)
xl = xlim(ax);
yl = ylim(ax);
zl = zlim(ax);
xy_span = max([diff(xl), diff(yl)]);

if isfinite(xy_span) && xy_span > 0 && ...
        all(isfinite([diff(xl), diff(yl), diff(zl)]))
    pbaspect(ax, [max(diff(xl),eps), max(diff(yl),eps), 1.25*xy_span]);
else
    pbaspect(ax, [1 1 1]);
end
end


function target_stimulus_xy_size = extract_target_stimulus_xy_size( ...
        target_run, target_default_stimsize)
conditions = get_target_conditions(target_run);

x_field = find_field_case_insensitive(conditions, ...
    {'centerX', 'center_x', 'xPos', 'xpos', 'x_pos', 'x'});
y_field = find_field_case_insensitive(conditions, ...
    {'centerY', 'center_y', 'yPos', 'ypos', 'y_pos', 'y'});
size_field = find_field_case_insensitive(conditions, ...
    {'size', 'stimsize', 'stim_size', 'stimSize'});

if isempty(x_field)
    error('No x-position field found in target run conditions.');
end
if isempty(y_field)
    error('No y-position field found in target run conditions.');
end
if isempty(size_field) && isempty(target_default_stimsize)
    error([ ...
        'No size/stimsize field found in target run conditions, and ' ...
        'target_default_stimsize is empty.']);
end

nCond = numel(conditions);
xyzs = nan(nCond,3);
for c = 1:nCond
    xyzs(c,1) = get_numeric_scalar_from_struct(conditions(c), x_field);
    xyzs(c,2) = get_numeric_scalar_from_struct(conditions(c), y_field);
    if isempty(size_field)
        xyzs(c,3) = target_default_stimsize;
    else
        xyzs(c,3) = get_numeric_scalar_from_struct(conditions(c), size_field);
    end
end

good = all(isfinite(xyzs), 2) & xyzs(:,3) > 0;
if ~any(good)
    error('No finite positive-size target stimulus [x,y,size] combination found.');
end
target_stimulus_xy_size = unique(xyzs(good,:), 'rows');
end


function conditions = get_target_conditions(target_run)
if isfield(target_run, 'conditions_full')
    conditions = target_run.conditions_full;
elseif isfield(target_run, 'conditions')
    conditions = target_run.conditions;
else
    error('Target run contains neither conditions_full nor conditions.');
end
if ~isstruct(conditions) || isempty(conditions)
    error('Target run conditions must be one nonempty struct array.');
end
end


function field_name = find_field_case_insensitive(struct_array, candidates)
field_name = '';
all_fields = fieldnames(struct_array);
for c = 1:numel(candidates)
    idx = find(strcmpi(all_fields, candidates{c}), 1);
    if ~isempty(idx)
        field_name = all_fields{idx};
        return;
    end
end
end


function value = get_numeric_scalar_from_struct(S, field_name)
if ~isfield(S, field_name)
    error('Condition field %s is missing.', field_name);
end
raw = S.(field_name);
if iscell(raw) && isscalar(raw)
    raw = raw{1};
end
if isstring(raw) && isscalar(raw)
    raw = str2double(raw);
elseif ischar(raw)
    raw = str2double(raw);
end
if ~isnumeric(raw) || ~isscalar(raw) || ~isfinite(double(raw))
    error('Condition field %s must contain one finite numeric scalar.', ...
        field_name);
end
value = double(raw);
end


function names = normalize_text_list(raw_names, source_name)
if isstring(raw_names)
    raw_names = cellstr(raw_names(:));
elseif ischar(raw_names)
    raw_names = cellstr(raw_names);
elseif iscell(raw_names)
    raw_names = raw_names(:);
else
    error('%s has an unsupported text-list type.', source_name);
end

names = cell(numel(raw_names),1);
for i = 1:numel(raw_names)
    value = raw_names{i};
    if isstring(value) && isscalar(value)
        value = char(value);
    end
    if ~ischar(value) || isempty(strtrim(value))
        error('%s{%d} must contain one nonempty text value.', source_name, i);
    end
    names{i} = strtrim(value);
end
end


function value = validate_filename_text(value, parameter_name)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || isempty(strtrim(value))
    error('%s must be one nonempty filename.', parameter_name);
end
value = strtrim(value);
end


function fig_file = make_optional_fig_path(folder, stem, save_fig_files)
if save_fig_files
    fig_file = fullfile(folder, [stem '.fig']);
else
    fig_file = '';
end
end


function save_figure_outputs( ...
        fig, png_file, fig_file, dpi, figure_visibility, close_after_save)
drawnow;

save_figure_png(fig, png_file, dpi);

if ~isempty(fig_file)
    % Store Visible='on' in the FIG so opening it later displays it normally.
    set(fig, 'Visible', 'on');
    savefig(fig, fig_file);
    set(fig, 'Visible', figure_visibility);
end

if close_after_save
    close(fig);
end
end


function save_figure_png(fig, png_file, dpi)
try
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, png_file, ...
            'Resolution', dpi, 'BackgroundColor', 'white');
    else
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, png_file, '-dpng', sprintf('-r%d', dpi));
    end
catch
    saveas(fig, png_file);
end
end


function safe_name = make_group_bundle_safe(group_names)
group_names = normalize_text_list(group_names, 'group_names');
safe_parts = cell(size(group_names));
for i = 1:numel(group_names)
    safe_parts{i} = make_filename_safe(group_names{i}, 30);
end
safe_name = strjoin(safe_parts(:)', '_');
if numel(safe_name) > 100
    safe_name = safe_name(1:100);
end
end


function safe_name = make_filename_safe(value, max_len)
value = char(value);
safe_name = regexprep(value, '[^A-Za-z0-9_-]', '_');
safe_name = regexprep(safe_name, '_+', '_');
safe_name = regexprep(safe_name, '^_+', '');
safe_name = regexprep(safe_name, '_+$', '');
if isempty(safe_name)
    safe_name = 'unnamed';
end
if numel(safe_name) > max_len
    safe_name = safe_name(1:max_len);
end
end


function format_rf_overlay_axis(ax)
hold(ax, 'on');

xl = xlim(ax);
yl = ylim(ax);
xrange = xl(2)-xl(1);
yrange = yl(2)-yl(1);

box(ax, 'off');
grid(ax, 'off');
set(ax, 'XColor', 'none', 'YColor', 'none', ...
    'FontSize', 11, 'LineWidth', 1);
xlabel(ax, '');
ylabel(ax, '');

axis_color = [0 0 0];
axis_lw = 2.4;
tick_lw = 1.4;
tick_len_frac = 0.018;
label_font = 9;

has_HM = yl(1) <= 0 && yl(2) >= 0;
has_VM = xl(1) <= 0 && xl(2) >= 0;

if has_HM
    line(ax, xl, [0 0], 'Color', axis_color, ...
        'LineStyle', '-', 'LineWidth', axis_lw);
end
if has_VM
    line(ax, [0 0], yl, 'Color', axis_color, ...
        'LineStyle', '-', 'LineWidth', axis_lw);
end
xlim(ax, xl);
ylim(ax, yl);

tick_step = choose_nice_tick_step(max(xrange,yrange)/8);
if has_HM
    xt = ceil(xl(1)/tick_step)*tick_step : tick_step : ...
        floor(xl(2)/tick_step)*tick_step;
    xt = xt(abs(xt) > 1e-9);
    tick_len_y = tick_len_frac * yrange;
    for i = 1:numel(xt)
        line(ax, [xt(i) xt(i)], [-tick_len_y tick_len_y], ...
            'Color', axis_color, 'LineWidth', tick_lw);
        text(ax, xt(i), -2.3*tick_len_y, sprintf('%g',xt(i)), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', ...
            'FontSize', label_font, 'Color', axis_color);
    end
end

if has_VM
    yt = ceil(yl(1)/tick_step)*tick_step : tick_step : ...
        floor(yl(2)/tick_step)*tick_step;
    yt = yt(abs(yt) > 1e-9);
    tick_len_x = tick_len_frac * xrange;
    for i = 1:numel(yt)
        line(ax, [-tick_len_x tick_len_x], [yt(i) yt(i)], ...
            'Color', axis_color, 'LineWidth', tick_lw);
        text(ax, -2*tick_len_x, yt(i), sprintf('%g',yt(i)), ...
            'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', label_font, 'Color', axis_color);
    end
end

if has_HM
    text(ax, xl(2)-0.02*xrange, 0+0.04*yrange, 'HM', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', ...
        'FontSize', 13, 'FontWeight', 'bold', 'Color', axis_color);
end
if has_VM
    text(ax, 0+0.035*xrange, yl(2)-0.02*yrange, 'VM', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 13, 'FontWeight', 'bold', 'Color', axis_color);
end
if has_HM && has_VM
    text(ax, 0+0.02*xrange, 0-0.035*yrange, '0', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'FontSize', label_font, 'Color', axis_color);
end

draw_scale_bar_deg(ax, 2);
end


function step = choose_nice_tick_step(raw_step)
if ~isfinite(raw_step) || raw_step <= 0
    step = 2;
    return;
end
base = 10^floor(log10(raw_step));
candidates = base * [1 2 5 10];
idx = find(candidates >= raw_step, 1, 'first');
if isempty(idx)
    step = candidates(end);
else
    step = candidates(idx);
end
end


function draw_scale_bar_deg(ax, scale_len)
xl = xlim(ax);
yl = ylim(ax);
xrange = xl(2)-xl(1);
yrange = yl(2)-yl(1);
if xrange <= 0 || yrange <= 0
    return;
end

y0 = yl(1) + 0.075*yrange;
if xl(1) < 0 && xl(2) > 0
    x0 = xl(1) + 0.025*xrange;
    right_margin_from_VM = 0.08*xrange;
    if x0 + scale_len > -right_margin_from_VM
        x0 = -right_margin_from_VM - scale_len;
    end
    if x0 < xl(1) + 0.01*xrange
        x0 = xl(1) + 0.025*xrange;
    end
else
    x0 = xl(1) + 0.025*xrange;
end

if x0 + scale_len > xl(2) - 0.04*xrange
    x0 = xl(2) - scale_len - 0.08*xrange;
end
if x0 < xl(1) || x0 + scale_len > xl(2)
    return;
end

line(ax, [x0 x0+scale_len], [y0 y0], ...
    'Color', 'k', 'LineWidth', 2.2);
text(ax, x0+scale_len/2, y0-0.035*yrange, ...
    sprintf('%g deg',scale_len), ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 11, 'Color', 'k');
end
