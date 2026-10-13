# Hellbender runbook

The user submits all cluster work. These steps follow the [Hellbender wiki](https://docs.itrss.umsystem.edu/pub/hpc/hellbender). Large transfers use the DTN; installation and analysis use allocated compute nodes. The login node is for submission and monitoring.

## 1. Transfer and configure

If you cloned the source from GitHub, create the transfer archive from the project directory first:

```text
python scripts/package_project.py
```

Use Globus or `scp` to transfer `dist/ATAC_Seq_Project.tar.gz` to your account on `hellbender-dtn-p1.rnet.missouri.edu`. In PowerShell, replacing `YOUR_USERNAME` with your cluster username:

```powershell
scp .\dist\ATAC_Seq_Project.tar.gz YOUR_USERNAME@hellbender-dtn-p1.rnet.missouri.edu:~/data/
ssh YOUR_USERNAME@hellbender-dtn-p1.rnet.missouri.edu
```

On the DTN:

```bash
cd "$HOME/data"
tar -tzf ATAC_Seq_Project.tar.gz | head
# Extract only if ATAC_Seq_Project is a new destination.
test ! -e ATAC_Seq_Project && tar -xzf ATAC_Seq_Project.tar.gz
cd ATAC_Seq_Project
```

Defaults work when the whole project lives on allocated data storage. To override paths or resources, copy `config/local.example.sh` to `config/local.sh` and edit it. `general` account, `general` partition, and `normal` QoS were observed for this account during a read-only check; confirm they still apply at submission. Environment setup has matching directives in `slurm/setup_env.sbatch`; override those with `sbatch --account=... --partition=... --qos=...` if needed.

Allow substantially more storage than the 5.96 GB FASTQ download: the reference, indexes, BAMs, environment, and intermediate files also occupy space. A conservative planning allowance is 150–250 GB for this two-library run; it is an estimate, not a measured requirement. Check quota and available project storage first. Avoid the smaller home allocation.

## 2. Fetch public inputs on the DTN

```bash
bash scripts/fetch_inputs.sh
```

This downloads the full two-library dataset, reference, and blacklist. It verifies provider MD5 or pinned SHA256 values and records a local SHA256 receipt. Interrupted transfers retain `.part` files for resumable downloads. A checksum mismatch fails rather than accepting the file. Do not edit the sample manifest after fetching without fetching/verifying again.

## 3. Install the Linux environment in a compute job

Connect to `hellbender-login.rnet.missouri.edu` and change to the same project directory:

```bash
cd "$HOME/data/ATAC_Seq_Project"
sbatch slurm/setup_env.sbatch
```

Save the returned job ID. Inspect `atac-env-JOBID.log` and `sacct -j JOBID --format=JobID,State,ExitCode` for completion. Do not start the analysis until this setup job succeeds.

Setup loads `miniconda3`, resolves `env/environment.yml` in project storage, and writes the exact package list and tool versions under `env/runtime/provenance`. A `CONDA_SH` override is available if the site's module arrangement changes. The environment specification pins MACS3 3.0.3, Genrich 0.6.1, Bowtie2 2.5.4, samtools 1.21, fastp 0.24.0, bedtools 2.31.1, Python 3.11, and GNU time 1.9. It has not been solved on Hellbender during preparation. A solver or network failure is a setup failure and must be resolved before analysis; do not silently substitute caller versions.

## 4. Submit analysis and monitor

```bash
bash slurm/submit_pipeline.sh
bash slurm/status.sh
```

The dependency graph processes all input reads. It does not use a hidden subsample.

| Stage | Parallel units | CPUs/unit | Memory/unit | Time limit |
|---|---:|---:|---:|---:|
| Reference/checksums/index | 1 | 8 | 48 GB | 8 h |
| Paired-end preprocessing | 2 libraries | 8 | 48 GB | 18 h |
| MACS3 | 2 libraries | 1 | 32 GB | 12 h |
| Genrich | 2 libraries | 1 | 32 GB | 12 h |
| HMMRATAC | 2 libraries | 1 | 64 GB | 24 h |
| Metrics export | 1 | 1 | 12 GB | 8 h |

These are conservative requests, not measured runtime forecasts. Every job fits within the wiki's two-day general limit. Caller jobs use one CPU and constrained numerical-library threading; measured wall time, peak memory, and CPU details are retained for interpretation. The array concurrency cap defaults to two.

`results/jobs.tsv` lists submitted IDs. `results/logs` contains stage logs. `.complete` marks validated stage products; `.failed` records shell-detected failures. A scheduler kill may prevent a trap from writing a marker, so SLURM accounting remains authoritative. Failed dependencies cancel downstream jobs rather than creating success-looking summaries. If submission itself stops midway, inspect recorded IDs before retrying; already-submitted jobs may still exist.

The source checksum snapshot detects changes to analysis scripts/configuration between submission and execution. Do not modify them during an active run. To rerun, set a fresh `RESULTS_DIR`; old analysis outputs are intentionally never overwritten. Reference indexing is repeated for each fresh run. Preserve the shared input and environment directories for reuse.

## 5. Retrieve and view measured results

After all jobs succeed, `results/dashboard/status.json` should report `status: complete` and `mode: full`. Preserve full `results` on the cluster; the small dashboard bundle is enough for viewing locally.

From the local project directory in PowerShell:

```powershell
New-Item -ItemType Directory -Force results | Out-Null
scp -r YOUR_USERNAME@hellbender-dtn-p1.rnet.missouri.edu:~/data/ATAC_Seq_Project/results/dashboard .\results\
& 'C:\Program Files\R\R-4.4.3\bin\Rscript.exe' scripts/install_dashboard.R
& 'C:\Program Files\R\R-4.4.3\bin\Rscript.exe' scripts/run_dashboard.R
```

Open [127.0.0.1:3838](http://127.0.0.1:3838). For a differently named run, change the remote path and set `$env:ATAC_RESULTS_DIR` to the absolute local dashboard directory before launching. The dashboard uses localhost only. It can also run within an allocated Open OnDemand RStudio session; it should not be launched on the login node.

Review QC and HMMRATAC model/cutoff logs before writing conclusions. Save the final software lock, commands, job accounting, normalized and native peaks, and comparison tables with any report. This first project deliberately does not claim a best caller or validate peaks against an independent truth set.
