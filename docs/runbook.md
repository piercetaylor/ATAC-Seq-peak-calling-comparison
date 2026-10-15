# Hellbender runbook

Run every step from `/cluster/VAST/mendozacozatld-lab/PierceTaylor/ATAC_Seq_Project`. Use the login node only to submit and monitor jobs.

## 1. Configure

The defaults in `config/project.sh` work as-is:
- `data/`, `results/`, and `env/runtime/` are created inside the project;
- jobs use the `general` account and partition with the `normal` QoS.

To change paths or the allocation, copy `config/local.example.sh` to `config/local.sh` and edit it. A run needs roughly 150–250 GB of disk, mostly for the reference index and BAMs.

## 2. Fetch inputs and build the environment

Submit both jobs; they can run at the same time:

```bash
sbatch slurm/fetch_inputs.sbatch   # FASTQs, reference, blacklist
sbatch slurm/setup_env.sbatch      # conda environment
```

- **Inputs.** Every file is checked against its MD5 or pinned SHA256. Interrupted downloads resume when the job is resubmitted. A checksum mismatch stops the job.
- **Environment.** Built from `env/environment.yml` using conda-forge and bioconda only. Resolved versions are recorded in `env/runtime/provenance/`.

Confirm both jobs succeeded with `sacct -j <id>` before going on.

## 3. Run the analysis

```bash
bash slurm/submit_pipeline.sh
bash slurm/status.sh
```

Each stage starts only after the stage before it succeeds:

| Stage | Jobs | CPUs | Memory | Limit | Observed (per job) |
|---|---:|---:|---:|---:|---:|
| Reference index | 1 | 8 | 48 GB | 8 h | 41 min |
| Preprocessing | 2 | 8 | 48 GB | 18 h | 75–86 min |
| MACS3 | 2 | 1 | 32 GB | 12 h | 7–8 min |
| Genrich | 2 | 1 | 32 GB | 12 h | 2 min |
| HMMRATAC | 2 | 1 | 64 GB | 24 h | 40–50 min |
| Summarize | 1 | 1 | 12 GB | 8 h | 4 min |

The full graph took about 3 hours.

- **Job records.** Job IDs go to `results/jobs.tsv` and logs to `results/logs/`. Each finished stage writes a `.complete` marker; a failed stage writes `.failed`.
- **Failures.** A failed stage cancels everything downstream. A caller that returns zero peaks counts as a failure.
- **Don't edit mid-run.** The pipeline checksums its scripts and config at submission, so do not change them while a run is active.
- **Reruns.** Point `RESULTS_DIR` at a new directory; existing results are never overwritten.

## 4. View results

Once `results/dashboard/status.json` reports `"status": "complete"`, launch the dashboard from an Open OnDemand RStudio session:

```bash
Rscript scripts/run_dashboard.R
```

To view it on your own machine, copy `results/dashboard/` back to your computer through the data-transfer node and run the same commands there.

Keep the full `results/` directory on the cluster. It holds the native peak files, commands, logs, and provenance.
