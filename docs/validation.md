# Preparation validation

Date: 2026-10-13. This record distinguishes software preparation from a completed biological analysis.

| Check | Observed outcome |
|---|---|
| Public metadata and provenance | ENA run/experiment metadata, four FASTQ URLs and MD5 values, reference MD5, and pinned blacklist digest recorded |
| Configuration preflight | Passed for the selected manifest |
| Python unit tests | 19 passed: paired-read filtering, long fragments, blacklist/body overlap, coordinate boundaries, peak normalization, union/Jaccard, one-count-per-fragment FRiP, missing/partial outputs, and denominator consistency |
| Shell syntax | All project Bash and SLURM files passed `bash -n` |
| Offline scheduler test | Passed using a fake local scheduler: six stages, correct dependency links and two-library arrays, refusal to overwrite an existing run; no cluster jobs submitted |
| Linux text format | Shell/Python/sample-manifest files have LF line endings and no UTF-8 BOM |
| Caller option review | Pinned MACS3 3.0.3 CLI/source inspected; HMMRATAC uses `--randomSeed`, preserves duplicates by default, and emits accessible-region narrowPeak output |
| Dashboard assertions | 23 parser/reactive/plot assertions passed, including explicit fixture labeling, missing data, empty selections, and partial-bundle handling |
| Browser check | Final Shiny app opened successfully at 127.0.0.1:3838 outside the Windows sandbox; overview/awaiting-results state and Methods & evidence navigation verified |
| Full biological workflow | **Not executed.** The user will submit the Hellbender jobs |
| Linux environment resolution | **Not executed.** The version-constrained specification is not yet a solved Linux lock |

## Local R limitation

The installed Windows R 4.4.3 process exits abnormally after the dashboard tests print all passing assertions. A minimal process loading the existing rlang package also reproduces a shutdown failure. Pinning the project's dependencies to a 2025-06-01 CRAN snapshot and testing with a clean R session did not remove it. The interactive dashboard runs and was verified in the browser, but the R test command does not return a clean exit code on this host. No global R installation or global package library was changed.

The dependency set is project-local and listed in [dashboard-package-versions.tsv](dashboard-package-versions.tsv). Investigate the host R shutdown separately if it affects ordinary R sessions; do not suppress failing process exit codes in automated testing.

## What remains for scientific completion

Transfer and checksum-verify the complete inputs, successfully resolve the Linux environment on a compute node, execute all selected libraries/callers, inspect read QC and HMM training diagnostics, export validated real metrics, and review those outputs in Shiny. Recorded runtime/memory and peak counts remain unavailable until that run finishes. No synthetic test fixture is included as project analysis results.
