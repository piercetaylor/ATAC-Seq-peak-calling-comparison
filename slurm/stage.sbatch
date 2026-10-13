#!/usr/bin/env bash
# Resource requests are supplied by submit_pipeline.sh.
set -Eeuo pipefail
source "${PROJECT_ROOT:?}/scripts/common.sh"
cd "$PROJECT_ROOT"
sha256sum --quiet -c "$RESULTS_DIR/provenance/source_sha256.txt"
case "${1:?stage required}" in
  reference)
    sha256sum --quiet -c "$DATA_DIR/provenance/input_sha256.txt"
    bash scripts/prepare_reference.sh ;;
  preprocess) bash scripts/preprocess.sh "$SLURM_ARRAY_TASK_ID" ;;
  call) bash scripts/call_peaks.sh "${2:?caller}" "$SLURM_ARRAY_TASK_ID" ;;
  summarize)
    activate_env
    python scripts/summarize.py --project-root "$PROJECT_ROOT" --results-dir "$RESULTS_DIR" --run-type full ;;
  *) die "Unknown stage" ;;
esac
