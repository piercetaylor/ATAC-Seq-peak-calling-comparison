# Human ATAC-seq peak caller comparison

This project compares **MACS3**, **Genrich**, and **HMMRATAC through MACS3** on two complete human GM12878 Omni-ATAC replicate libraries. It contains a Hellbender SLURM workflow, a literature-backed study design, tested summary calculations, and an R Shiny dashboard.

**Status:** prepared for user submission. The full public-data analysis has not been run. No benchmark results are included or fabricated.

| Library | Public run | Paired spots | Compressed reads |
|---|---|---:|---:|
| RepA | [SRR5427887](https://www.ebi.ac.uk/ena/browser/view/SRR5427887) | 31,084,199 | 2.70 GB |
| RepB | [SRR5427886](https://www.ebi.ac.uk/ena/browser/view/SRR5427886) | 37,596,063 | 3.26 GB |

The study is PRJNA380283 / SRP103230. Both libraries share the same cell-line BioSample; they are not independent human donors. All four download URLs and MD5 checksums are in `config/samples.tsv`. The reference is the UCSC hg38 no-alt analysis set with hg38 blacklist v2.

Start with the [Hellbender runbook](docs/runbook.md). Read the [study plan](docs/study_plan.md), [research and citations](docs/research.md), and [results contract](docs/data_contract.md) for the scientific choices. [PEPATAC](https://doi.org/10.1093/nargab/lqab101) is the closest published precedent for the caller/Jaccard comparison; the [original HMMRATAC paper](https://doi.org/10.1093/nar/gkz533) provides another method-comparison example.

## Cluster workflow

Follow the [official Hellbender wiki](https://docs.itrss.umsystem.edu/pub/hpc/hellbender). Transfer the project into `$HOME/data/ATAC_Seq_Project` through the data-transfer node. From that project directory:

```bash
# Data-transfer node: download complete inputs and verify checksums.
bash scripts/fetch_inputs.sh

# Login node: submit software setup on a compute node.
sbatch slurm/setup_env.sbatch

# After setup succeeds: submit the analysis dependency graph.
bash slurm/submit_pipeline.sh
bash slurm/status.sh
```

The wrapper submits reference indexing, preprocessing of both libraries, one array for each caller, and summary export. Each run requires a fresh `RESULTS_DIR`. Customize paths and allocation with `config/local.sh`, copied from `config/local.example.sh`. Inspect the runbook before the first submission; setup and transfer run on different cluster hosts.

## Open the dashboard locally

```text
Rscript scripts/install_dashboard.R
Rscript scripts/run_dashboard.R
```

Open [the local dashboard](http://127.0.0.1:3838). It starts in an explicit awaiting-results state. After the cluster run, copy its `results/dashboard` directory into this project's `results/dashboard`, or set `ATAC_RESULTS_DIR` to the downloaded bundle. Use **Refresh results** to reload it.

Views cover study status, QC, caller counts/widths/FRiP, overlap, replicate agreement, runtime/memory, and downloadable evidence. Peak agreement is not accuracy, and a higher FRiP does not by itself establish better calls.

## Validation and reproducibility

```bash
python -m unittest discover -s tests -p 'test_*.py' -v
bash tests/test_submission.sh
Rscript tests/test_dashboard.R
```

Input checksums, resolved Linux packages, caller commands, CPU information, logs, and SLURM job IDs are retained with each run. The environment YAML constrains package versions; the setup job produces the actual resolved platform lock. Linux caller execution remains to be verified by the user's cluster run. See [validation.md](docs/validation.md) for checks performed during preparation.
