# Validation

Last checked 2026-10-16 on Hellbender.

## Software tests

| Check | Result |
|---|---|
| Python unit tests | 19/19 pass with the project environment's Python 3.11 (pair filtering, blacklist overlap, interval boundaries, Jaccard, FRiP, missing outputs) |
| SLURM submission test | Passes with a mock scheduler (six dependent stages; refuses to overwrite an existing run) |
| Dashboard tests (R 4.4.0) | 15/15 pass. The Shiny reactive tests are skipped until `scripts/install_dashboard.R` creates `.R-library/` |
| Nextflow pipeline | A stub run covers all stages. A real run on 1M read pairs per library (conda, job 18966192) completed all 9 tasks, and its output passes dashboard validation. Not yet run on AWS |
| Dashboard on real results | The server loads all six caller/sample rows and the overview renders. The published copy in `published_results/dashboard/` loads all seven tables with no validation issues. Plots could not be rendered on the login node, which lacks `libtiff.so.6` |

## Full run

| Step | Result |
|---|---|
| Input download | All FASTQs, the reference, and the blacklist matched their checksums |
| Environment | Solved and installed. MACS3 3.0.3, Genrich 0.6.1, samtools 1.21, fastp 0.24.0, bedtools 2.31.1 |
| Pipeline | All stages exited 0 (jobs 18935775–18935780). `status.json` reports `complete` in `full` mode |
| Genrich | The first run returned zero peaks at q < 0.01. The cause was diagnosed, and Genrich was re-run at p < 0.01 (jobs 18953716–18953717). See [PATCH_NOTES.txt](../published_results/provenance/PATCH_NOTES.txt) |

## Not yet checked

- HMMRATAC training and cutoff diagnostics have not been reviewed.
- No external reference set, such as DNase, has been compared.
