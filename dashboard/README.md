# Dashboard

An R Shiny app for exploring the results of the peak-caller comparison. It shows only measured values; it contains no demo data.

```sh
Rscript scripts/install_dashboard.R   # installs pinned packages into .R-library/
Rscript scripts/run_dashboard.R       # http://127.0.0.1:3838
```

## Configuration

- **Data.** The app reads `results/dashboard/`. Set `ATAC_RESULTS_DIR` to use another folder.
- **Port.** Set `ATAC_DASHBOARD_PORT` to change it.
- **Updates.** The app checks for new results every 30 seconds, or on **Refresh results**.

## Tabs

- **Overview.** Key findings, computed from the loaded tables, and a note on the differing caller cutoffs.
- **Read quality.** Read depth, duplicate and chrM fractions, and fragment lengths.
- **Peak profiles.** Peak counts, widths, covered bases, and FRiP.
- **Agreement.** Jaccard between callers and between replicates.
- **Resource use.** Caller wall time and memory.
- **Methods & evidence.** Method notes, literature, and table downloads that respect the current filters.

## Data handling

Tables that fail validation are withheld, and the reason is shown on screen. Validation checks:
- column names and unique keys;
- numeric values and value ranges;
- that Jaccard equals intersection / union.

Missing values appear as "Not reported", never as zero. The expected file format is in [../docs/data_contract.md](../docs/data_contract.md).

## Tests

```sh
Rscript tests/test_dashboard.R
```
