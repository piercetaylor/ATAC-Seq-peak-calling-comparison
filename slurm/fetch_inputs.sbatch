#!/usr/bin/env bash
#SBATCH --job-name=atac-fetch
#SBATCH --account=general
#SBATCH --partition=general
#SBATCH --qos=normal
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=08:00:00
#SBATCH --output=atac-fetch-%j.log
set -Eeuo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/fetch_inputs.sh
