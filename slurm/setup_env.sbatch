#!/usr/bin/env bash
#SBATCH --job-name=atac-env
#SBATCH --account=general
#SBATCH --partition=general
#SBATCH --qos=normal
#SBATCH --cpus-per-task=2
#SBATCH --mem=12G
#SBATCH --time=02:00:00
#SBATCH --output=atac-env-%j.log
set -Eeuo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash env/bootstrap.sh
