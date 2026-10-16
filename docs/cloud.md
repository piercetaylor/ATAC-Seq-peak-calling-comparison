# Running on AWS (Nextflow)

`nextflow/` is a portable version of the SLURM workflow. It runs the same tools, versions, parameters and Python helpers, and writes output in the same `results/` layout, so the dashboard reads it unchanged. The same pipeline also runs on a laptop, an HPC cluster or other clouds; only the executor profile changes.

**Status:** a real run succeeded on Hellbender (conda profile, 1M read pairs per library, 14 min). All nine tasks finished, and the dashboard loads the output without validation issues. A stub run also covers the reference-building step. The pipeline has not yet been run on AWS, and the Docker image has not been built.

## Stages

```
PREPARE_REFERENCE ─▶ PREPROCESS (per library) ─▶ CALL_PEAKS (library × caller) ─▶ SUMMARIZE
```

| Stage | Request | Observed on full data (Hellbender) |
|---|---|---|
| Reference index | 8 CPU, 48 GB | 41 min |
| Preprocess, per library | 8 CPU, 32 GB | 75–86 min |
| MACS3 / Genrich / HMMRATAC | 1 CPU; 8 / 16 / 8 GB | 7–8 / 2 / 40–50 min |
| Summarize | 1 CPU, 12 GB | 4 min |

A task killed for running out of memory or time is retried up to twice, each time with more resources.

## One-time AWS setup

1. **Container.**
   - Build the image from the project root: `docker build -f nextflow/Dockerfile -t atac-peak-callers:1.0 .`
   - Push it to Amazon ECR.
2. **S3 bucket.** Create one bucket for the Nextflow work directory and the results, for example `s3://my-atac`.
3. **AWS Batch.**
   - Create a compute environment and a job queue.
   - Instances need at least 8 vCPUs and 48 GB of memory, for example `r6i.2xlarge`. Spot instances work because failed tasks are retried.
   - The instance role needs read and write access to the bucket.
4. **AWS CLI on the instances.** Nextflow needs the AWS CLI on each Batch instance. Either:
   - use a custom AMI with the CLI installed at `/home/ec2-user/miniconda/bin/aws`; or
   - enable Fusion (`fusion.enabled = true`, `wave.enabled = true`) and skip the custom AMI.

## Run

```bash
nextflow run nextflow/main.nf -profile awsbatch \
  --aws_queue my-atac-queue --aws_region us-east-1 \
  --container <account>.dkr.ecr.us-east-1.amazonaws.com/atac-peak-callers:1.0 \
  -work-dir s3://my-atac/work --outdir s3://my-atac/results
```

- **Inputs.** FASTQs are read straight from the HTTPS URLs in `config/samples.tsv` and checked against their MD5s. To use your own data, point `--samples` at a sheet with the same columns; `s3://` or local paths both work.
- **Reference.** The Bowtie2 index is published to `<outdir>/reference/`. Pass `--reference_dir s3://my-atac/results/reference` to reuse it and skip the 40-minute build.
- **Resuming.** Add `-resume` to restart a run without redoing finished tasks.

Each run writes `pipeline_info/` with a report, a timeline and a per-task trace; these give actual cost drivers (CPU-hours and memory).

## Other executors

| Where | Profile |
|---|---|
| Laptop or workstation | `-profile conda` or `-profile docker`, with `--max_cpus` / `--max_memory` |
| SLURM, including Hellbender | `-profile slurm,conda` or `-profile slurm,apptainer` |
| Google Cloud / Azure | Add a `google-batch` or `azurebatch` profile; the processes need no changes |

To smoke-test on subsampled reads, add the `test` profile. It labels the output `subsample_smoke`, so the dashboard never shows it as a full run. Subsampled numbers are not meaningful: at 1M read pairs, Genrich at p < 0.01 calls nearly every cut site as a peak.

## Cost (rough)

The full two-library run needs about 3.5 instance-hours on 8-vCPU machines (reference plus preprocessing) and about 2 hours of single-CPU caller time. On on-demand `r6i.2xlarge` instances that comes to a few US dollars, plus S3 storage: the Hellbender run kept about 25 GB of BAMs and index, and the work directory also holds the FASTQs and intermediate files until it is cleaned. Spot instances cost less. Check current AWS prices before relying on these estimates.

## Differences from the SLURM workflow

- **Run tracking.** Nextflow tracks task success itself, so it does not write `.complete` markers or `jobs.tsv`. `pipeline_info/trace.tsv` takes their place.
- **Saved files.** The Nextflow run deletes the decompressed `genome.fa` (3 GB) after indexing; the Bowtie2 index is all that later stages need.
