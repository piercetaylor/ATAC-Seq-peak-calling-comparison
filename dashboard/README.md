# ATAC-seq comparison dashboard

The dashboard reads measured workflow exports. It shows an actionable empty state until results arrive; no demonstration measurements are included.

From the project directory:

```sh
Rscript scripts/install_dashboard.R
Rscript scripts/run_dashboard.R
```

Open `http://127.0.0.1:3838`. The server binds to the local computer. `ATAC_DASHBOARD_PORT` changes the port; `ATAC_RESULTS_DIR` points to another exported results folder. Otherwise the dashboard uses `results/dashboard/` in this project. Dependencies are installed in `.R-library/` from a frozen Posit CRAN snapshot (2025-06-01), with installed versions recorded in `.R-library/dashboard-package-versions.tsv`. `ATAC_R_REPOSITORY` can override that repository.

On Windows PowerShell with the installed R version:

```powershell
& 'C:\Program Files\R\R-4.4.3\bin\Rscript.exe' scripts/install_dashboard.R
& 'C:\Program Files\R\R-4.4.3\bin\Rscript.exe' scripts/run_dashboard.R
```

For cluster results, copy the small `results/dashboard/` export to the same location in this project. Alternatively set `ATAC_RESULTS_DIR` before launching. Refresh results manually or leave automatic checks enabled. No live cluster connection is needed.

## Evidence contract

The dashboard accepts tab-separated tables with a header. Empty strings and `NA` are missing measurements; numeric fractions are 0–1. Additional columns are retained in table views and downloads.

| File | Required columns |
|---|---|
| `peak_metrics.tsv` | `sample`, `caller`, `n_peaks`, `total_peak_bp`, `median_peak_width`, `frip`, `fragments` |
| `pairwise_overlap.tsv` | `sample`, `caller_a`, `caller_b`, `intersection_bp`, `union_bp`, `jaccard` |
| `replicate_overlap.tsv` | `caller`, `sample_a`, `sample_b`, `intersection_bp`, `union_bp`, `jaccard` |
| `qc.tsv` | `sample`, `raw_pairs`, `filtered_pairs`, `duplicate_fraction`, `mitochondrial_fraction` |
| `runtime.tsv` | `sample`, `caller`, `elapsed_seconds`, `max_rss_kb` |
| `fragment_lengths.tsv` | `sample`, `length_bp`, `fragments` |
| `peak_widths.tsv` | `sample`, `caller`, `width_bp`, `peaks` |

`status.json` supplies `dataset`, `mode`, `status`, `assembly`, and `notes`. Modes `synthetic_fixture` and `subsample_smoke` receive explicit provenance labels. A results table without run metadata is shown with a warning; completion is never inferred from the presence of rows.

Missing tables remain empty. Invalid tables are withheld and their validation errors are displayed. Validation checks include column names, unique row keys, numeric values, nonnegative integer counts, fraction bounds, retained read counts, and Jaccard arithmetic. The caller names are inferred from the files. The named colors for this project's three methods are consistent across charts.

Tables exported from the app respect the current sample and caller selection. Downloads retain their original numeric precision and units. The compressed peak-coordinate file remains a pipeline artifact; the dashboard does not read millions of peak coordinates into memory.

## Interpretation

The views cover read quality, peak counts and widths, fragment length distributions, caller-specific fragment FRiP, base-pair Jaccard agreement, and measured caller time/memory. No independent truth set is present, so none of these measures establishes accuracy. FRiP depends on the peak set; broader or more numerous peaks can raise it. Replicate overlap is descriptive and is not IDR. Duplicate and mitochondrial fractions use primary read-name groups after trimming and alignment, before common pair filtering, including unmapped groups. Either mate can flag a pair, so these two counts may overlap.

The Methods & evidence view links the official caller documentation and the related GM12878 protocol/QC study. HMMRATAC runs through `macs3 hmmratac`.

## Validation

```sh
Rscript tests/test_dashboard.R
```

Checks use temporary synthetic fixtures outside `results/`. They exercise invalid data handling, selection, overlap arithmetic, distribution loading, Shiny reactive state, plots, and the no-results screen.

On the current Windows R 4.4.3 host, all 23 assertions finish successfully, followed by an abnormal R process exit. Loading the pre-existing `rlang` package alone reproduces a process-exit failure. The dashboard runs and was verified in a browser outside the Windows sandbox, but this shutdown issue means the automated check process does not currently return a clean exit code. No system-wide R installation or package library was changed.
