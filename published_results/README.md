# Published results (v1.0.0)

The compact outputs of the full Hellbender run (completed 2026-10-14; Genrich re-run 2026-10-15). You can inspect them, or open them in the dashboard, without rerunning the sequencing analysis:

```bash
Rscript scripts/install_dashboard.R
ATAC_RESULTS_DIR=published_results/dashboard Rscript scripts/run_dashboard.R
```

| Path | Contents |
|---|---|
| `dashboard/` | The dashboard bundle described in [docs/data_contract.md](../docs/data_contract.md): metrics, overlaps, QC, runtimes, distributions, and every final peak (`peaks.tsv.gz`) |
| `jobs.tsv` | SLURM job IDs for each stage |
| `provenance/config/` | The configuration the run used |
| `provenance/inputs/` | Input URLs and the checksums they were verified against |
| `provenance/software/` | The resolved conda environment and tool versions |
| `provenance/PATCH_NOTES.txt` | The Genrich re-run, and a correction to the dataset label in this copy |

The BAMs, native caller output, and logs (about 25 GB) remain on Hellbender. `dashboard/artifacts.tsv` lists the SHA256 of each final `peaks.bed`; this directory is kept separate from `results/` because the pipeline refuses to write into an existing results directory.
