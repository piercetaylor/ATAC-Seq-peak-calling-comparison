#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
if [[ -f "$PROJECT_ROOT/config/local.sh" ]]; then
  source "$PROJECT_ROOT/config/local.sh"
fi
source "$PROJECT_ROOT/config/project.sh"
export PROJECT_ROOT DATA_DIR RESULTS_DIR ENV_PREFIX SAMPLES_TSV
REF_DIR="$DATA_DIR/reference"
THREADS="${SLURM_CPUS_PER_TASK:-4}"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing program: $1"; }
require_file() { [[ -f "$1" ]] || die "Missing file: $1"; }

load_conda() {
  if [[ -n "${CONDA_SH:-}" ]]; then
    source "$CONDA_SH"
    return
  fi
  if ! type module >/dev/null 2>&1 && [[ -f /etc/profile.d/modules.sh ]]; then
    source /etc/profile.d/modules.sh
  fi
  type module >/dev/null 2>&1 || die "Environment modules unavailable; set CONDA_SH in config/local.sh."
  module load "$CONDA_MODULE" || die "Could not load module $CONDA_MODULE; set CONDA_MODULE in config/local.sh."
  source "$(conda info --base)/etc/profile.d/conda.sh"
}

activate_env() {
  load_conda
  [[ -d "$ENV_PREFIX/conda-meta" ]] || die "Environment is not installed: $ENV_PREFIX"
  conda activate "$ENV_PREFIX"
  # Avoid nested numerical libraries using unallocated cores in caller comparisons.
  export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
}

sample_at() {
  local index="${1:?sample index required}"
  [[ "$index" =~ ^[1-9][0-9]*$ ]] || die "Sample index must be one-based."
  SAMPLE=$(awk -F '\t' -v n="$((index + 1))" 'NR==n {gsub(/\r/, ""); print $1}' "$SAMPLES_TSV")
  [[ "$SAMPLE" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || die "Invalid/missing sample at row $index"
}

stage_begin() {
  STAGE_DIR="$1"
  [[ ! -e "$STAGE_DIR" ]] || die "Stage output already exists: $STAGE_DIR. Choose a fresh RESULTS_DIR; inspect old outputs first."
  mkdir -p "$STAGE_DIR"
  date -u +'%Y-%m-%dT%H:%M:%SZ' > "$STAGE_DIR/.started"
  trap 'stage_exit $?' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

stage_exit() {
  local rc="$1"
  if (( rc != 0 )); then
    printf 'exit_code=%s\njob_id=%s\n' "$rc" "${SLURM_JOB_ID:-local}" > "$STAGE_DIR/.failed"
  fi
}

stage_complete() {
  date -u +'%Y-%m-%dT%H:%M:%SZ' > "$STAGE_DIR/.complete"
}

log_command() {
  printf '%q ' "$@" >> "$STAGE_DIR/commands.sh"
  printf '\n' >> "$STAGE_DIR/commands.sh"
  "$@"
}
