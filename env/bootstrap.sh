#!/usr/bin/env bash
# Run inside a compute allocation: sbatch slurm/setup_env.sbatch.
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
[[ -n "${SLURM_JOB_ID:-}" ]] || die "Use sbatch slurm/setup_env.sbatch; install software on an allocated compute node."
load_conda
need conda
[[ ! -e "$ENV_PREFIX" ]] || die "Environment path exists; choose a fresh ENV_PREFIX to avoid changing a recorded environment."
mkdir -p "$(dirname -- "$ENV_PREFIX")"
export CONDA_PKGS_DIRS="$PROJECT_ROOT/env/package-cache"
export CONDA_CHANNEL_PRIORITY=strict
mkdir -p "$CONDA_PKGS_DIRS"
# Install the environment.yml specs with --override-channels so channels from
# ~/.condarc or the site condarc (e.g. Anaconda 'defaults', which requires a ToS
# acceptance) never enter the solve.
mapfile -t specs < <(awk '/^dependencies:/ {deps=1; next} deps && /^  - / {print $2} deps && /^[^ ]/ {deps=0}' "$PROJECT_ROOT/env/environment.yml")
(( ${#specs[@]} > 0 )) || die "No dependencies parsed from env/environment.yml"
conda create --yes --prefix "$ENV_PREFIX" --override-channels -c conda-forge -c bioconda --strict-channel-priority "${specs[@]}"
activate_env
mkdir -p "$ENV_PREFIX/provenance"
conda list --explicit > "$ENV_PREFIX/provenance/conda-linux-64.explicit.txt"
conda env export --prefix "$ENV_PREFIX" > "$ENV_PREFIX/provenance/environment.resolved.yml"
python --version > "$ENV_PREFIX/provenance/versions.txt" 2>&1
bowtie2 --version >> "$ENV_PREFIX/provenance/versions.txt" 2>&1
samtools --version >> "$ENV_PREFIX/provenance/versions.txt" 2>&1
fastp --version >> "$ENV_PREFIX/provenance/versions.txt" 2>&1
bedtools --version >> "$ENV_PREFIX/provenance/versions.txt" 2>&1
macs3 --version >> "$ENV_PREFIX/provenance/versions.txt" 2>&1
conda list --prefix "$ENV_PREFIX" '^genrich$' >> "$ENV_PREFIX/provenance/versions.txt"
macs3 hmmratac --help > "$ENV_PREFIX/provenance/hmmratac-help.txt"
grep -q -- '--randomSeed' "$ENV_PREFIX/provenance/hmmratac-help.txt" || die "Installed HMMRATAC lacks expected --randomSeed option."
grep -q -- '--remove-dup' "$ENV_PREFIX/provenance/hmmratac-help.txt" || die "Expected MACS3 3.0.3 duplicate handling was not found."
printf 'Environment ready: %s\n' "$ENV_PREFIX"
