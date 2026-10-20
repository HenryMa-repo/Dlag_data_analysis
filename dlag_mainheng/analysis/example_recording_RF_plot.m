%% =========================================================================
% example_recording_RF_plot
%
% Put this script in the session's catgt_<run_g> folder and run it directly.
% It works from an empty workspace and exports exactly these three SVGs:
%   Probe 0 folder: all_site_rf_map_depth_desc.svg
%   Probe 1 folder: all_site_rf_map_depth_desc.svg
%   CatGT folder  : the original unit_sites, readable area-mean overlay
%                   basename, with extension changed to .svg.
%
% Existing inputs
% ---------------
% Each <run_g>_imec# folder:
%   site_rf_results.mat, variable site_rf (from Recording_site_RF.m).
%
% CatGT folder, for the requested target run:
%   model_*_cross_threshold_unit_sites_area_mean_RF_stimulus_overlay_...
%       readable_<target>.fig
% OR, if that FIG was not saved:
%   model_*_cross_threshold_RF_stimulus_summary_<target>.mat,
%       variable model_unit_rf_stimulus_summary
%       (from model_unit_RF_stimli_overlay.m).
%
% Plot behavior
% -------------
% - Reads the saved site RF maps, depths, region IDs, region names and colors.
% - Reuses the original all-site mosaic plotting code, including its depth
%   order, independent per-site parula scaling, flipped RF tiles, colored
%   borders, spacing, figure size, title and legend.
% - The overlay uses the existing FIG whenever available. Otherwise the
%   original plotting functions draw the saved unit_sites_group means and
%   target_stimulus_xy_size, including the original title and axis limits.
% - Uses the ordinary readable overlay. It retains the original selection
%   and saved means for this version.
% - RF estimation, RF fitting, area segmentation and averaging are not run.
% - Existing MAT/PNG/FIG files are read only. Only the three SVGs are written.
% - SVG resolution is set to 300 dpi by default. The mosaic and its colored
%   borders retain their original RGB-image representation; SVG text/lines
%   remain vector content where supported by MATLAB's exporter.
% - The plotting helpers are included below; neither source script needs
%   to be on the MATLAB path.
% =========================================================================

clc;
clear;

%% ----------------------- User parameters -----------------------

% Empty: use this script's folder (place the script in the CatGT folder).
% You can alternatively enter the absolute CatGT path here.
catgt_folder = '';

probes = [0, 1];

% Empty: select the unique matching unit_sites/readable overlay.
% If more than one target run is present, enter its EXACT saved stimTag,
% for example: '_2[Gpl2_2c_2sz_400_2_200isi]'.
target_stim_tag = '';

svg_dpi = 300;
figure_visibility = 'on';      % 'on' or 'off'
close_after_save = true;

%% ----------------------- Resolve the session -----------------------

if isempty(catgt_folder)
    this_script = mfilename('fullpath');
    if isempty(this_script)
        catgt_folder = pwd;
    else
        catgt_folder = fileparts(this_script);
    end
end
if ~isfolder(catgt_folder)
    error('CatGT folder does not exist: %s', catgt_folder);
end
[path_ok, folder_info] = fileattrib(catgt_folder);
if ~path_ok
    error('Cannot resolve CatGT folder: %s', catgt_folder);
end
catgt_folder = folder_info.Name;

if ~isnumeric(probes) || isempty(probes) || ~isvector(probes) || ...
        any(~isfinite(probes(:))) || any(probes(:) < 0) || ...
        any(probes(:) ~= round(probes(:))) || ...
        numel(unique(probes(:))) ~= numel(probes)
    error('probes must contain unique nonnegative integer probe IDs.');
end
if ~isscalar(svg_dpi) || ~isnumeric(svg_dpi) || ...
        ~isfinite(svg_dpi) || svg_dpi <= 0
    error('svg_dpi must be one finite positive number.');
end
if ~(strcmpi(figure_visibility, 'on') || strcmpi(figure_visibility, 'off'))
    error('figure_visibility must be ''on'' or ''off''.');
end
figure_visibility = lower(char(figure_visibility));
if ~isscalar(close_after_save) || ...
        ~(islogical(close_after_save) || isnumeric(close_after_save)) || ...
        ~ismember(close_after_save, [0 1])
    error('close_after_save must be true or false.');
end

fprintf('CatGT folder: %s\n', catgt_folder);
fprintf('SVG resolution: %g dpi\n', svg_dpi);

% Resolve and read every input before starting the exports.
nProbe = numel(probes);
site_results = cell(nProbe, 1);
site_mat_files = cell(nProbe, 1);
svg_files = cell(nProbe + 1, 1);
for p = 1:nProbe
    probe_folder = find_probe_folder(catgt_folder, probes(p));
    site_mat_files{p} = fullfile(probe_folder, 'site_rf_results.mat');
    site_results{p} = load_saved_site_rf(site_mat_files{p}, probes(p));
    svg_files{p} = fullfile(probe_folder, 'all_site_rf_map_depth_desc.svg');
end
overlay = resolve_saved_overlay(catgt_folder, target_stim_tag);
svg_files{end} = fullfile(catgt_folder, [overlay.stem '.svg']);

%% ----------------------- Export each probe's original mosaic -----------------------

for p = 1:nProbe
    fprintf('\nProbe %d: reading %s\n', probes(p), site_mat_files{p});
    fig = plot_rf_map_depth_desc(site_results{p}, figure_visibility);
    save_svg_figure(fig, svg_files{p}, svg_dpi, close_after_save);
    fprintf('Saved: %s\n', svg_files{p});
end

%% ----------------------- Export the original unit-sites overlay -----------------------

fprintf('\nOverlay source: %s\n', overlay.source_file);
if strcmp(overlay.source_kind, 'fig')
    % 'new' opens an independent in-memory copy of the saved figure.
    fig = openfig(overlay.source_file, 'new', 'invisible');
    set(fig, 'Visible', figure_visibility);
else
    fig = plot_independent_area_mean_overlay( ...
        overlay.group_summary, overlay.target_stimulus_xy_size, ...
        overlay.RF_R2_threshold, 'readable', overlay.stem, figure_visibility);
end
save_svg_figure(fig, svg_files{end}, svg_dpi, close_after_save);
fprintf('Saved: %s\n', svg_files{end});

fprintf('\nFinished: %d SVG files.\n', numel(svg_files));
for p = 1:numel(svg_files)
    fprintf('  %s\n', svg_files{p});
end

%% ======================= Input and export helpers =======================

function probe_folder = find_probe_folder(catgt_folder, probe_id)
d = dir(fullfile(catgt_folder, sprintf('*_imec%d', probe_id)));
d = d([d.isdir]);
if isempty(d)
    error('No *_imec%d probe folder found directly under:\n%s', ...
        probe_id, catgt_folder);
elseif numel(d) > 1
    error('Multiple *_imec%d probe folders found under %s:\n%s', ...
        probe_id, catgt_folder, strjoin({d.name}, sprintf('\n')));
end
probe_folder = fullfile(catgt_folder, d(1).name);
end


function site_rf = load_saved_site_rf(site_file, probe_id)
if ~isfile(site_file)
    error('Missing saved site RF result: %s', site_file);
end
S = load(site_file, 'site_rf');
if ~isfield(S, 'site_rf') || ~isstruct(S.site_rf) || ~isscalar(S.site_rf)
    error('Expected one site_rf structure in %s', site_file);
end
site_rf = S.site_rf;
required = {'probe_idx', 'site_ids', 'site_depth_um', 'rfs', ...
    'site_area_id', 'area_segmentation'};
for k = 1:numel(required)
    if ~isfield(site_rf, required{k})
        error('site_rf.%s is missing in %s', required{k}, site_file);
    end
end
if ~isnumeric(site_rf.probe_idx) || ~isscalar(site_rf.probe_idx) || ...
        site_rf.probe_idx ~= probe_id
    error('site_rf.probe_idx does not match probe %d in %s', ...
        probe_id, site_file);
end
if isempty(site_rf.site_ids) || ...
        numel(site_rf.site_depth_um) ~= numel(site_rf.site_ids) || ...
        ~isstruct(site_rf.rfs) || ~isfield(site_rf.rfs, 'map')
    error('Invalid saved site IDs, depths, or RF maps in %s', site_file);
end
end


function overlay = resolve_saved_overlay(catgt_folder, target_stim_tag)
if isstring(target_stim_tag) && isscalar(target_stim_tag)
    target_stim_tag = char(target_stim_tag);
end
if ~ischar(target_stim_tag) || ...
        (~isempty(target_stim_tag) && size(target_stim_tag, 1) ~= 1)
    error('target_stim_tag must be one text scalar or ''''.');
end
if isempty(target_stim_tag)
    target_token = '*';
else
    % Same sanitization and length limit as the original overlay script.
    target_token = make_filename_safe(target_stim_tag, 70);
end

fig_pattern = ['model_*_cross_threshold_unit_sites_area_mean_RF_' ...
    'stimulus_overlay_readable_' target_token '.fig'];
mat_pattern = ['model_*_cross_threshold_RF_stimulus_summary_' ...
    target_token '.mat'];
d = dir(fullfile(catgt_folder, fig_pattern));
d = d(~[d.isdir]);
% With an automatic wildcard, explicitly exclude the other readable view.
if ~isempty(d)
    remove_outlier = contains({d.name}, '_overlay_readable_remove_outlier_');
    d = d(~remove_outlier);
end
summary_files = dir(fullfile(catgt_folder, mat_pattern));
summary_files = summary_files(~[summary_files.isdir]);
fig_stems = regexprep({d.name}, '\.fig$', '');
mat_stems = regexprep({summary_files.name}, '\.mat$', '');
mat_stems = strrep(mat_stems, '_cross_threshold_RF_stimulus_summary_', ...
    '_cross_threshold_unit_sites_area_mean_RF_stimulus_overlay_readable_');
candidate_stems = unique([fig_stems(:); mat_stems(:)]);
% A FIG from one run must not hide another run that has only a summary MAT.
if numel(candidate_stems) > 1
    error(['Multiple saved unit_sites/readable overlays match:\n%s\n' ...
        'Set target_stim_tag at the top to the desired exact run tag.'], ...
        strjoin(candidate_stems, sprintf('\n')));
end
if numel(d) == 1
    overlay.source_kind = 'fig';
    overlay.source_file = fullfile(catgt_folder, d(1).name);
    [~, overlay.stem] = fileparts(d(1).name);
    return;
end

d = summary_files;
if isempty(d)
    error(['No saved unit_sites/readable overlay FIG or RF summary MAT ' ...
        'matches in:\n%s\nFIG pattern: %s\nMAT pattern: %s\n' ...
        'Check target_stim_tag or leave it empty for a unique match.'], ...
        catgt_folder, fig_pattern, mat_pattern);
elseif numel(d) > 1
    error(['Multiple RF summary MAT files match:\n%s\n' ...
        'Set target_stim_tag at the top to the desired exact run tag.'], ...
        strjoin({d.name}, sprintf('\n')));
end

summary_file = fullfile(catgt_folder, d(1).name);
S = load(summary_file, 'model_unit_rf_stimulus_summary');
if ~isfield(S, 'model_unit_rf_stimulus_summary') || ...
        ~isstruct(S.model_unit_rf_stimulus_summary) || ...
        ~isscalar(S.model_unit_rf_stimulus_summary)
    error('model_unit_rf_stimulus_summary is missing or invalid in %s', ...
        summary_file);
end
summary = S.model_unit_rf_stimulus_summary;
required = {'unit_sites_group', 'target_stimulus_xy_size', 'RF_R2_threshold'};
for k = 1:numel(required)
    if ~isfield(summary, required{k})
        error('Saved summary.%s is missing in %s', required{k}, summary_file);
    end
end
if ~isempty(target_stim_tag) && isfield(summary, 'target_stim_tag') && ...
        ~strcmp(char(summary.target_stim_tag), target_stim_tag)
    error('The saved target_stim_tag does not match the requested tag in %s', ...
        summary_file);
end

groups = summary.unit_sites_group;
group_fields = {'population_type', 'group_display_label', 'color_rgb', ...
    'mean_center', 'mean_size', 'n_cross_threshold_objects'};
if ~isstruct(groups) || isempty(groups)
    error('Saved summary.unit_sites_group is empty or invalid in %s', ...
        summary_file);
end
for k = 1:numel(group_fields)
    if ~isfield(groups, group_fields{k})
        error('unit_sites_group.%s is missing in %s', ...
            group_fields{k}, summary_file);
    end
end
for g = 1:numel(groups)
    if ~strcmp(groups(g).population_type, 'unit_sites') || ...
            numel(groups(g).mean_center) ~= 2 || ...
            numel(groups(g).mean_size) ~= 2
        error('Invalid saved unit_sites group %d in %s', g, summary_file);
    end
    validate_rgb_triplet(groups(g).color_rgb, 'Saved unit_sites group color');
end
stimuli = summary.target_stimulus_xy_size;
if ~isnumeric(stimuli) || (~isempty(stimuli) && size(stimuli, 2) ~= 3)
    error('Saved target_stimulus_xy_size must have columns [x y size] in %s', ...
        summary_file);
end

overlay.source_kind = 'summary';
overlay.source_file = summary_file;
overlay.stem = get_saved_overlay_stem(summary, d(1).name);
overlay.group_summary = groups;
overlay.target_stimulus_xy_size = stimuli;
overlay.RF_R2_threshold = summary.RF_R2_threshold;
end


function stem = get_saved_overlay_stem(summary, summary_filename)
% Keep the original output basename, even after moving a session folder.
stem = '';
if isfield(summary, 'output') && isstruct(summary.output) && ...
        isfield(summary.output, 'unit_sites') && ...
        isstruct(summary.output.unit_sites)
    saved_output = summary.output.unit_sites;
    fields = {'area_mean_overlay_readable_fig', 'area_mean_overlay_readable_png'};
    for k = 1:numel(fields)
        if isfield(saved_output, fields{k}) && ~isempty(saved_output.(fields{k}))
            saved_path = char(saved_output.(fields{k}));
            saved_path = strrep(saved_path, '\', '/');
            [~, stem] = fileparts(saved_path);
            break;
        end
    end
end
if isempty(stem)
    % The summary and overlay names share the same area and target tokens.
    [~, summary_stem] = fileparts(summary_filename);
    tokens = regexp(summary_stem, ...
        '^(model_.+)_cross_threshold_RF_stimulus_summary_(.+)$', ...
        'tokens', 'once');
    if isempty(tokens)
        error('Cannot recover the original overlay name from %s', summary_filename);
    end
    stem = [tokens{1} '_cross_threshold_unit_sites_area_mean_RF_' ...
        'stimulus_overlay_readable_' tokens{2}];
end
if ~contains(stem, '_cross_threshold_unit_sites_area_mean_RF_stimulus_overlay_readable_') || ...
        contains(stem, '_overlay_readable_remove_outlier_')
    error('The saved output name is not the requested unit_sites/readable overlay: %s', stem);
end
end


function save_svg_figure(fig, svg_file, dpi, close_after_save)
% A short temporary basename avoids older MATLAB print path-length limits.
% Rename in the original output folder only after a successful SVG export.
try
    [output_folder, output_stem, output_ext] = fileparts(svg_file);
    previous_folder = pwd;
    folder_guard = onCleanup(@() cd(previous_folder)); %#ok<NASGU>
    cd(output_folder);
    [~, temporary_stem] = fileparts(tempname(output_folder));
    temporary_name = [temporary_stem '.svg'];
    temporary_file = fullfile(output_folder, temporary_name);
    temp_guard = onCleanup(@() delete_if_present(temporary_file)); %#ok<NASGU>

    drawnow;
    set(fig, 'PaperPositionMode', 'auto');
    if exist('exportgraphics', 'file') == 2 && ~verLessThan('matlab', '25.1')
        % SVG exportgraphics support starts with MATLAB R2025a.
        try
            exportgraphics(fig, temporary_name, 'ContentType', 'vector', ...
                'Resolution', dpi, 'BackgroundColor', 'white');
        catch export_error
            warning('example_recording_RF_plot:SVGExportFallback', ...
                'exportgraphics SVG failed (%s). Using print -dsvg.', ...
                export_error.message);
            print(fig, temporary_name, '-dsvg', sprintf('-r%d', round(dpi)));
        end
    else
        % Compatible with MATLAB releases that reject SVG in exportgraphics.
        print(fig, temporary_name, '-dsvg', sprintf('-r%d', round(dpi)));
    end
    info = dir(temporary_name);
    if isempty(info) || info(1).bytes == 0
        error('SVG export did not produce a nonempty file for %s', svg_file);
    end
    [moved, move_message] = movefile(temporary_name, ...
        [output_stem output_ext], 'f');
    if ~moved
        error('Cannot save SVG %s: %s', svg_file, move_message);
    end
catch ME
    if close_after_save && isgraphics(fig, 'figure')
        close(fig);
    end
    rethrow(ME);
end
if close_after_save
    close(fig);
end
end


function delete_if_present(filename)
if isfile(filename)
    delete(filename);
end
end


% Original Recording_site_RF mosaic and display helpers.


function fig = plot_rf_map_depth_desc(site_rf, figure_visibility)
% Depth-sorted all-site RF mosaic. Every tile has the color of its assigned
% depth region; all sites are included regardless of RF R2.

RFmap = site_rf.rfs.map;
site_depth_um = site_rf.site_depth_um(:);
site_ids = site_rf.site_ids(:);
nSite = numel(site_rf.site_ids);

if size(RFmap, 1) ~= nSite
    error('size(site_rf.rfs.map,1) does not match numel(site_rf.site_ids).');
end
required = {'probe_idx', 'site_area_id', 'area_segmentation'};
for k = 1:numel(required)
    if ~isfield(site_rf, required{k})
        error('site_rf.%s is required for the colored all-site RF map.', ...
            required{k});
    end
end
if ~isstruct(site_rf.area_segmentation) || ...
        ~isfield(site_rf.area_segmentation, 'region_names') || ...
        ~isfield(site_rf.area_segmentation, 'region_colors_rgb')
    error(['site_rf.area_segmentation must contain region_names and ' ...
        'region_colors_rgb.']);
end

site_area_id = double(site_rf.site_area_id(:));
region_names = site_rf.area_segmentation.region_names(:);
region_colors_rgb = double( ...
    site_rf.area_segmentation.region_colors_rgb);
n_regions = numel(region_names);

if numel(site_area_id) ~= nSite || n_regions < 1 || ...
        any(~isfinite(site_area_id)) || ...
        any(site_area_id ~= round(site_area_id)) || ...
        any(site_area_id < 1) || any(site_area_id > n_regions)
    error('Every site must have one valid region ID before plotting.');
end
validate_region_colors(region_colors_rgb, n_regions, ...
    'site_rf.area_segmentation.region_colors_rgb');

% Larger depth is placed first. Within one depth, larger 0-based site ID is
% placed first so the smaller/start-side site ID appears later, toward tip 0.
order = get_depth_desc_order(site_depth_um, site_ids);

tile_scale = 5;
border_pix = 3;
gap_pix = 2;
margin_pix = 8;

nCols = ceil(sqrt(nSite * 1.25));
nRows = ceil(nSite / nCols);

[~, nY, nX] = size(RFmap);
inner_h = nY * tile_scale;
inner_w = nX * tile_scale;
tile_h = inner_h + 2 * border_pix;
tile_w = inner_w + 2 * border_pix;

img_h = 2 * margin_pix + nRows * tile_h + (nRows - 1) * gap_pix;
img_w = 2 * margin_pix + nCols * tile_w + (nCols - 1) * gap_pix;

mosaic_rgb = ones(img_h, img_w, 3);
cmap = parula(256);

for ii = 1:nSite
    s = order(ii);
    row = floor((ii - 1) / nCols) + 1;
    col = mod(ii - 1, nCols) + 1;

    y0 = margin_pix + (row - 1) * (tile_h + gap_pix) + 1;
    x0 = margin_pix + (col - 1) * (tile_w + gap_pix) + 1;

    y_outer = y0:(y0 + tile_h - 1);
    x_outer = x0:(x0 + tile_w - 1);

    region_id = site_area_id(s);
    border_color = reshape(region_colors_rgb(region_id,:), [1 1 3]);
    mosaic_rgb(y_outer, x_outer, :) = repmat( ...
        border_color, [numel(y_outer), numel(x_outer), 1]);

    y_inner = (y0 + border_pix):(y0 + border_pix + inner_h - 1);
    x_inner = (x0 + border_pix):(x0 + border_pix + inner_w - 1);

    Z = squeeze(RFmap(s, :, :));
    Z = flipud(Z);

    tile_rgb = rf_tile_to_rgb(Z, cmap, tile_scale);
    mosaic_rgb(y_inner, x_inner, :) = tile_rgb;
end

figure_title = sprintf('All sites | probe %d | n = %d', ...
    site_rf.probe_idx, nSite);
fig = figure('Visible', figure_visibility, 'Color', 'w', ...
    'Position', [80 80 1100 850], 'Name', figure_title, ...
    'NumberTitle', 'off');
ax = axes('Parent', fig, 'Position', [0.04 0.12 0.92 0.80]);
image(ax, mosaic_rgb);
axis(ax, 'image');
axis(ax, 'off');
title(ax, figure_title, 'Interpreter', 'none', 'FontWeight', 'bold');
hold(ax, 'on');

legend_handles = gobjects(n_regions, 1);
legend_labels = cell(n_regions, 1);
for k = 1:n_regions
    legend_handles(k) = plot(ax, NaN, NaN, 's', ...
        'MarkerSize', 10, 'LineStyle', 'none', ...
        'MarkerFaceColor', 'none', ...
        'MarkerEdgeColor', region_colors_rgb(k,:), ...
        'LineWidth', 2.5);
    n_region_sites = sum(site_area_id == k);
    legend_labels{k} = sprintf('%s = %d sites', ...
        region_names{k}, n_region_sites);
end
legend(ax, legend_handles, legend_labels, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'Interpreter', 'none', 'Box', 'off');
hold(ax, 'off');

end


function tile_rgb = rf_tile_to_rgb(Z, cmap, tile_scale)
% Copied from RF_analysis.m. Each site is scaled independently.

finite_mask = isfinite(Z);
tile_h = size(Z, 1) * tile_scale;
tile_w = size(Z, 2) * tile_scale;
tile_rgb = ones(tile_h, tile_w, 3);

if ~any(finite_mask(:))
    return;
end

zmin = min(Z(finite_mask));
zmax = max(Z(finite_mask));

if zmax > zmin
    Zn = (Z - zmin) ./ (zmax - zmin);
else
    if zmax == 0
        Zn = zeros(size(Z));
    else
        Zn = 0.5 * ones(size(Z));
    end
end

Zn(~finite_mask) = NaN;
idx = round(Zn * 255) + 1;
idx(idx < 1) = 1;
idx(idx > 256) = 256;

rgb_small = ones(size(Z,1), size(Z,2), 3);
for yy = 1:size(Z,1)
    for xx = 1:size(Z,2)
        if isfinite(idx(yy,xx))
            rgb_small(yy,xx,:) = reshape(cmap(idx(yy,xx), :), [1 1 3]);
        else
            rgb_small(yy,xx,:) = [1 1 1];
        end
    end
end

tile_rgb = repelem(rgb_small, tile_scale, tile_scale, 1);
end


function order = get_depth_desc_order(site_depth_um, site_ids)
% Sort recording sites for the 2-D RF mosaic.
%
% Primary key  : depth descending, so depth 0 (probe tip) is last.
% Secondary key: 0-based acquisition site ID descending. Thus, for sites
%                sharing one depth, the smaller/start-side site ID is later.
% NaN depth is placed after all finite depths with the same site-ID rule.

site_depth_um = site_depth_um(:);
site_ids = site_ids(:);
nSite = numel(site_ids);

if numel(site_depth_um) ~= nSite
    error('site_depth_um and site_ids must have the same length.');
end

site_index = (1:nSite)';
finite_depth = isfinite(site_depth_um);
site_id_sort = site_ids;
site_id_sort(~isfinite(site_id_sort)) = -Inf;

finite_idx = site_index(finite_depth);
finite_depth_val = site_depth_um(finite_depth);
finite_site_id = site_id_sort(finite_depth);

if isempty(finite_idx)
    [~, pos] = sortrows([-site_id_sort, site_index], [1 2]);
    order = site_index(pos);
    return;
end

sort_table = [-finite_depth_val, -finite_site_id, finite_idx];
[~, sort_pos] = sortrows(sort_table, [1 2 3]);
finite_order = finite_idx(sort_pos);
nan_order = site_index(~finite_depth);

if ~isempty(nan_order)
    [~, nan_pos] = sortrows( ...
        [-site_id_sort(~finite_depth), nan_order], [1 2]);
    nan_order = nan_order(nan_pos);
end

order = [finite_order; nan_order];
end


function validate_rgb_triplet(rgb, source_name)
if ~isnumeric(rgb) || numel(rgb) ~= 3 || ...
        any(~isfinite(double(rgb(:)))) || ...
        any(double(rgb(:)) < 0) || any(double(rgb(:)) > 1)
    error('%s must be a finite numeric [R G B] vector in [0,1].', ...
        source_name);
end
end


function validate_region_colors(colors_rgb, n_regions, source_name)
if ~isnumeric(colors_rgb) || ...
        ~isequal(size(colors_rgb), [n_regions, 3]) || ...
        any(~isfinite(double(colors_rgb(:)))) || ...
        any(double(colors_rgb(:)) < 0) || any(double(colors_rgb(:)) > 1)
    error('%s must be an n_regions-by-3 finite RGB matrix in [0,1].', ...
        source_name);
end
end


% Original model_unit_RF_stimli_overlay display helpers.


function fig = plot_independent_area_mean_overlay( ...
        group_summary, target_stimulus_xy_size, RF_R2_threshold, ...
        view_mode, figure_title, figure_visibility)

validate_mean_view_mode(view_mode);
nGroup = numel(group_summary);

if strcmpi(view_mode, 'readable_remove_outlier')
    all_centers = reshape([group_summary.mean_center_remove_outlier], 2, [])';
    all_sizes = reshape([group_summary.mean_size_remove_outlier], 2, [])';
    axis_view_mode = 'readable';
else
    all_centers = reshape([group_summary.mean_center], 2, [])';
    all_sizes = reshape([group_summary.mean_size], 2, [])';
    axis_view_mode = view_mode;
end

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

    if strcmpi(view_mode, 'readable_remove_outlier')
        center = group_summary(g).mean_center_remove_outlier;
        rf_size = group_summary(g).mean_size_remove_outlier;
        n_mean_objects = group_summary(g).n_readable_remove_outlier_objects;
    else
        center = group_summary(g).mean_center;
        rf_size = group_summary(g).mean_size;
        n_mean_objects = group_summary(g).n_cross_threshold_objects;
    end

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
        n_mean_objects, unit_label);
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

% readable_remove_outlier uses the same readable-axis presentation as the
% original readable figure, but the mean ellipses themselves are recomputed
% from area-specific outlier-filtered objects.
set_overlay_axis_limits(ax, target_stimulus_xy_size, ...
    all_centers, all_sizes, axis_view_mode, true);
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


function validate_mean_view_mode(view_mode)
if ~(ischar(view_mode) || (isstring(view_mode) && isscalar(view_mode))) || ...
        ~(strcmpi(view_mode, 'readable') || ...
          strcmpi(view_mode, 'readable_remove_outlier') || ...
          strcmpi(view_mode, 'full'))
    error(['Mean-overlay view_mode must be ''readable'', ' ...
        '''readable_remove_outlier'', or ''full''.']);
end
end


function validate_view_mode(view_mode)
if ~(ischar(view_mode) || (isstring(view_mode) && isscalar(view_mode))) || ...
        ~(strcmpi(view_mode, 'readable') || strcmpi(view_mode, 'full'))
    error('view_mode must be ''readable'' or ''full''.');
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
