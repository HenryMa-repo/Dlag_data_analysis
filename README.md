# DLAG Data Analysis

MATLAB scripts for preparing multi-probe electrophysiology recordings, fitting delayed-latent models, and analyzing neural population activity across brain areas and visual stimulus conditions.

This repository is a research codebase built around [DLAG (Delayed Latents Across Groups)](https://github.com/egokcen/DLAG). It connects SpikeGLX/CatGT and Kilosort/Phy outputs with trial-wise Expo stimulus information, produces inputs for DLAG, and provides session-level and cross-session analyses. V1 and MT are used as example groups throughout many scripts; group names, probe assignments, and analysis settings should be checked for each dataset.

One application is to examine how within-area and across-area population activity varies with grating versus plaid stimuli, stimulus size, contrast, and direction.

The repository is organized as a collection of **scripts**, not an installed MATLAB toolbox. Most scripts are configured by editing the parameters near the top, then running the script in the appropriate session or analysis directory.

## What the workflow covers

- Aligning spike times and recording event markers with stimulus trials.
- Extracting trial-by-trial stimulus information from Expo XML files.
- Computing unit quality and response statistics, and generating binned spike-count and firing-rate data.
- Selecting units, assigning model groups by probe and brain area, and preparing original and trial-shuffled model inputs.
- Fitting all-condition or condition-specific DLAG models and analyzing the inferred latent structure.
- Comparing reconstructions, variance, latent timescales, neural subspaces, tuning classes, and spike-count correlations across conditions and sessions.

## Repository layout

```text
Dlag_data_analysis/
├── data_seg/                        # Spike/LFP segmentation and binned responses
│   └── sorting_check/               # Spike alignment and unit statistics
├── readstim_info/                   # Trial-wise Expo stimulus information
└── dlag_mainheng/
    ├── prepar_data/                 # Model input and shuffle controls
    ├── train/                       # DLAG model fitting
    └── analysis/                    # Per-session analysis and visualization
        └── session_summary/         # Across-session summaries and figures
```

Some older versions of analysis scripts are retained under `dlag_mainheng/analysis/old script already insert in new/`. Use the current script outside that folder unless a historical version is specifically needed. Some script names also appear in more than one active directory, so check the full path of the version being run.

## Requirements and inputs

The required files and MATLAB toolboxes depend on the chosen analysis. The complete workflow uses:

1. **MATLAB**, with Statistics and Machine Learning Toolbox functions used by several analyses. Training scripts can use parallel workers and require Parallel Computing Toolbox when parallel execution is enabled.
2. The original [DLAG repository](https://github.com/egokcen/DLAG) and its dependencies on the MATLAB path. This repository calls DLAG functions such as `fit_fa` and `fit_dlag`; it does not contain the DLAG implementation itself. Follow the original repository's setup instructions, including `startup.m`; DLAG also notes that Bioinformatics Toolbox may be needed.
3. SpikeGLX/CatGT recordings and event information, Kilosort/Phy sorting outputs, and Expo XML files for the session being analyzed.
4. The `npy-matlab` reader (`readNPY`) for Kilosort `.npy` files, Expo-reading helpers such as `ReadExpoXML` and `getExpo_pulses_fix`, and recording/event helpers such as `get_eventst_GLX`. The paths to these helpers are environment-specific.
5. For area-based unit selection, receptive-field/area-label results such as `all_unit_rf_results.mat` in each selected Kilosort folder. The related [Area-seg repository](https://github.com/HenryMa-repo/Area-seg) contains the associated area-segmentation workflow.

The scripts include example local paths, stimulus tags, selected probes, and analysis parameters. Update these for your environment. Some scripts add `./expo_tools` and `./utils` relative to the current directory; ensure the required functions are actually on the MATLAB path. There is no single installation or configuration command for the entire pipeline.

To check whether key dependencies can be found, for example:

```matlab
which fit_dlag -all
which readNPY -all
which ReadExpoXML -all
which get_eventst_GLX -all
```

### Expected session organization

The preprocessing scripts use a session and CatGT folder layout similar to:

```text
<data_root>/
└── <run>_g<index>/
    ├── <run>_g<index>_t0.nidq.bin
    └── catgt_<run>_g<index>/
        ├── stiminfo.mat
        ├── model_data_allruns.mat
        ├── <run>_g<index>_imec0/
        │   └── kilosort*/
        └── <run>_g<index>_imec1/
            └── kilosort*/
```

This is an example, not a complete file list. NIDQ metadata, sorted-unit files, `cluster_info.tsv`, Expo files, and intermediate outputs must also be available where the relevant scripts expect them. Paths and filenames are constructed from each script's settings.

## Typical workflow

The steps below describe the main dependencies between scripts. Depending on the question, only a subset of the analyses in the next section is needed.

### 1. Align spikes and extract trial information

| Script | Purpose | Main outputs |
| --- | --- | --- |
| [get_spikt_evt_mrkidx_seg.m](data_seg/sorting_check/get_spikt_evt_mrkidx_seg.m) | Align sorted spike times with NIDQ events and segment them into stimulus blocks and trials. | `eventunit_time.mat`, `spike_unit_time_trial.mat`, run-level unit metrics |
| [stiminfo_pertrial.m](readstim_info/stiminfo_pertrial.m) | Read the experiment's Expo XML files and extract stimulus information for each trial. | `stiminfo.mat` |
| [unit_statistic_by_condition.m](data_seg/sorting_check/unit_statistic_by_condition.m) | Compute condition-level firing-rate, d-prime, and Fano-factor statistics for each unit. | `unit_condition_metrics.mat` and summary figures |
| [processing_to_count_and_fr.m](data_seg/processing_to_count_and_fr.m) | Bin trial responses and create count, rate, z-scored, and demeaned data versions. | `bined_data_allruns.mat` in each Kilosort folder |

Check the stimulus tags, session/run identifiers, probe numbers, analysis windows, and bin sizes before running. In particular, `stiminfo_pertrial.m` obtains its session folder from the active editor file's location; inspect its path setup before use. The optional [baseline processing script](data_seg/processing_to_count_and_fr_baseline.m) prepares baseline data used by analyses that request it.

### 2. Prepare DLAG inputs

Run [model_data_prepar_with_trialshuffle.m](dlag_mainheng/prepar_data/model_data_prepar_with_trialshuffle.m) after the required per-probe data and area-label files are available. It selects units using the configured response/quality and area criteria, combines the chosen probe-area populations, handles missing data according to the selected strategy, and saves `model_data_allruns.mat` in the shared CatGT folder.

Each selected **probe–area pair** is a model group. The order in `group_name`, `group_probe`, and `groupd` determines the group order used downstream. One probe can contribute more than one area. Check this order whenever setting `group_names`, `group_probes`, or other group-dependent options in an analysis script.

The script also saves two controls within each stimulus condition:

- `model_data_allruns_trialshuffled_withincondition.mat`: independently permutes trial identities for each group, preserving each group's population time course while changing trial pairing across groups.
- `model_data_allruns_trialshuffled_unit_independently_withincondition.mat`: starts from the group-shuffled data and additionally permutes trials independently for each unit, retaining each unit's time course within a trial.

The control files contain the same main variable name, `model_data_allruns`, plus shuffle bookkeeping. Choose the intended input file explicitly in training and analysis; a run index alone does not load the corresponding control automatically. Set a numeric shuffle seed if a reproducible shuffle is needed.

### 3. Fit DLAG models

| Script | Model mode |
| --- | --- |
| [train_dlag.m](dlag_mainheng/train/train_dlag.m) | One model fitted to the selected run's pooled trials across conditions. |
| [train_dlag_by_condition.m](dlag_mainheng/train/train_dlag_by_condition.m) | Separate models fitted to selected stimulus conditions. |

Edit at least `dat_file`, `stim_tag`, `data_content`, `runIdx`, and the model/parallelization settings before training. The condition-specific script also uses `data_condtion` (the spelling used in the code) to select condition IDs. Training uses FA to help select dimensionality, followed by DLAG cross-validation and fitting. The example training settings assume two groups, so review group-dependent settings for the data being analyzed.

For the current grating/plaid design, a run commonly contains two directions and eight type × size × contrast combinations per direction. Thus, 16 separately fitted conditions are often used, but the actual condition list must be read from the session's data rather than assumed for every dataset.

Results are organized under paths such as:

```text
FA_Dlag_<data_content>/mat_results/runXXX/                 # all-condition model
FA_Dlag_<data_content>_condition<id>/mat_results/runXXX/  # condition-specific model
```

These paths are relative to the configured working directory. `runIdx` identifies a results subdirectory; use settings consistent with the input file and all downstream analyses. The example training scripts set `overwriteExisting = true`, so check that setting before reusing an existing output directory.

### 4. Analyze fitted models

Begin with [plot_dlag_results.m](dlag_mainheng/analysis/plot_dlag_results.m) for the matching model mode and input data. It produces post-fit results, including a `bestmodel*.mat` file used by downstream analyses. For the additional model-variance fields used by the condition-specific variance workflow, see [plot_dlag_results_for_each_condtion_mode_var.m](dlag_mainheng/analysis/plot_dlag_results_for_each_condtion_mode_var.m).

| Analysis | Starting scripts | What they examine |
| --- | --- | --- |
| Latent categories | [Latents_compare.m](dlag_mainheng/analysis/Latents_compare.m), [latent_compare_for_each_condtion_mode.m](dlag_mainheng/analysis/latent_compare_for_each_condtion_mode.m) | Within-area, across-area, feedforward, feedback, and ambiguous latent categories, with options for latent selection and variance summaries. |
| Reconstruction | [data_reconstruction.m](dlag_mainheng/analysis/data_reconstruction.m), [calculate_reconstruction_R2_dfferent_ways.m](dlag_mainheng/analysis/calculate_reconstruction_R2_dfferent_ways.m) | Reconstructed responses and neuron-wise R², including grating/plaid or type × size × contrast groupings. |
| Posterior and latent variability | [posterior_rawvar.m](dlag_mainheng/analysis/posterior_rawvar.m), [plot_latent_xsm_var.m](dlag_mainheng/analysis/plot_latent_xsm_var.m) | Trial-to-trial variance of reconstructed responses or inferred latent posterior means, respectively. |
| Timescales | [plot_timescale_compare.m](dlag_mainheng/analysis/plot_timescale_compare.m), [compute_psd_timescale.m](dlag_mainheng/analysis/compute_psd_timescale.m) | Latent timescales by category, including model- and PSD-based measures. |
| Neural subspaces | [subspace_similarity_dlag.m](dlag_mainheng/analysis/subspace_similarity_dlag.m), [subspace_overlap_sigtest.m](dlag_mainheng/analysis/subspace_overlap_sigtest.m) | Principal angles and directional similarity between selected loading subspaces, with matched null controls. |
| Grating/plaid tuning | [GPL_analysis_by_area.m](dlag_mainheng/analysis/GPL_analysis_by_area.m), [GPL_tuning_case_neuron.m](dlag_mainheng/analysis/GPL_tuning_case_neuron.m) | Tuning, orientation/direction selectivity, and pattern/component classification for selected model neurons. |
| Spike-count correlation | [calculate_rsc_by_condition.m](dlag_mainheng/analysis/calculate_rsc_by_condition.m) | Within- and across-group trial-to-trial spike-count correlations for each condition. |

For reconstruction, `data_reconstruction.m` adds requested fields to the saved `bestmodel*.mat`; it does not refit the model. It can overwrite the model file with the updated `seqEst`, so review its settings and keep a copy when needed. Run it before analyses that explicitly require its reconstruction fields.

### 5. Summarize across sessions

Scripts in [session_summary/](dlag_mainheng/analysis/session_summary/) load previously saved per-session outputs. Examples include:

- [sum_sessions_latent_compare.m](dlag_mainheng/analysis/session_summary/sum_sessions_latent_compare.m) and [sum_sessions_latent_compare_var.m](dlag_mainheng/analysis/session_summary/sum_sessions_latent_compare_var.m) for latent-category and variance summaries.
- [sum_GPL_index_by_area.m](dlag_mainheng/analysis/session_summary/sum_GPL_index_by_area.m) and [sum_GPL_class_deltaR2_by_area.m](dlag_mainheng/analysis/session_summary/sum_GPL_class_deltaR2_by_area.m) for tuning and reconstruction comparisons by neuron class.
- [sum_session_rsc.m](dlag_mainheng/analysis/session_summary/sum_session_rsc.m) for condition-wise spike-count correlations.
- [sum_sessions_timescale_compare.m](dlag_mainheng/analysis/session_summary/sum_sessions_timescale_compare.m) and the `sum_sessions_subspace_*` scripts for timescales and subspace analyses.
- [Varline_figure_plot.m](dlag_mainheng/analysis/session_summary/Varline_figure_plot.m) and the `GPL_class_deltaVar_*` scripts for selected variance comparisons.
- [compare_deltaR2_with_deltaVar.m](dlag_mainheng/analysis/session_summary/compare_deltaR2_with_deltaVar.m) for neuron-matched correlations between saved stimulus-dependent ΔR² and saved variance-change measures. This script reads existing all-condition posterior summaries and reports nominal, uncorrected correlations across pooled neurons; consult its header for matching and population requirements.

Set the root directory, model mode, stimulus/data settings, group order, and input-selection options to match the saved session results. Individual scripts document their required files and whether a plotted observation represents a neuron, a latent, a session, or a session–direction combination.

## Interpreting the outputs

- `raw_count`, `raw_fr`, z-scored fields, and demeaned fields are different inputs. For example, `demean_count_within_t_and_condition` subtracts the across-trial mean separately for each time bin and condition; it should be distinguished from demeaning across time within each trial.
- Across and Within partition the selected shared latent categories, while Feedforward, Feedback, and Ambiguous are subdivisions of Across. These five labels therefore overlap and should not be summed as five independent categories.
- Variance derived from model parameters, trial variance of inferred latent posterior means, and variance of reconstructed neural responses are different measures. Posterior uncertainty and normalization options depend on the script and settings. Similarly, spike-count correlation measures pairwise association; it is not the same quantity as reconstructed-response variance.
- Some posterior-variance summaries offer raw variance, normalization by mean response, or percentages using joint All-latent reconstructed variance or observed variance as the denominator. The All-latent variance is a joint quantity and need not equal the sum of Across and Within variances.
- Reconstruction R² is calculated relative to the grouping and denominator specified in the analysis script; it can be negative. Reconstructed contributions or their variances are not generally additive across latent categories when covariance terms are present.
- Feedforward and feedback labels use the selected group order and inferred delay conventions. Verify those settings when interpreting directionality; a delay-based label by itself does not establish causality.

Always check each script's header and saved metadata for its precise selection, normalization, trial pooling, and uncertainty conventions.
