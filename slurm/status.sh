#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
require_file "$RESULTS_DIR/jobs.tsv"
ids=$(awk -F '\t' 'NR>1 {print $2}' "$RESULTS_DIR/jobs.tsv" | paste -sd, -)
[[ -n "$ids" ]] || die "No jobs recorded."
squeue -j "$ids" -o '%.18i %.20j %.12T %.40R'
sacct -j "$ids" --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS,AllocCPUS --parsable2 | tee "$RESULTS_DIR/provenance/slurm_accounting.tsv"
