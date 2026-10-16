# ATAC-seq peak caller comparison

Three peak callers (MACS3, Genrich, and HMMRATAC as implemented in MACS3) were compared on two full-depth GM12878 Omni-ATAC libraries. The workflow runs on Hellbender under SLURM, and an R Shiny dashboard presents the results.

**Status:** complete. Findings are in [docs/results.md](docs/results.md).

| Library | Run | Read pairs |
|---|---|---:|
| RepA | [SRR5427887](https://www.ebi.ac.uk/ena/browser/view/SRR5427887) | 31,084,199 |
| RepB | [SRR5427886](https://www.ebi.ac.uk/ena/browser/view/SRR5427886) | 37,596,063 |

Both libraries come from one GM12878 BioSample (PRJNA380283; Corces et al., 2017), so they are technical rather than donor replicates. Reads were aligned to the UCSC hg38 no-alt analysis set, with the ENCODE blacklist v2 excluded.

**Docs:** [methods](docs/methods.md) · [data sources](docs/research.md) · [runbook](docs/runbook.md) · [cloud](docs/cloud.md)

## Run it

On the Hellbender login node, from the project directory:

```bash
sbatch slurm/fetch_inputs.sbatch   # download and checksum inputs
sbatch slurm/setup_env.sbatch      # build the conda environment (in parallel)
bash slurm/submit_pipeline.sh      # once both jobs succeed
bash slurm/status.sh
```

Each run writes to a new `RESULTS_DIR`. Paths and SLURM settings can be overridden in `config/local.sh`.

## Cloud

The same analysis is also packaged as a Nextflow pipeline (`nextflow/`). It can run on AWS Batch, other clouds, a laptop, or SLURM, and it writes the same `results/` layout. See [docs/cloud.md](docs/cloud.md) for setup and cost.

## Dashboard

```bash
Rscript scripts/install_dashboard.R
Rscript scripts/run_dashboard.R    # http://127.0.0.1:3838
```

The app reads `results/dashboard/`, or the folder named by `ATAC_RESULTS_DIR`.

## Tests

```bash
env/runtime/bin/python -m unittest discover -s tests -p 'test_*.py'   # needs Python >= 3.7
bash tests/test_submission.sh
Rscript tests/test_dashboard.R
```

## License

MIT. See [LICENSE](LICENSE). The sequencing data, reference genome, and blacklist are third-party public resources under their own terms.
