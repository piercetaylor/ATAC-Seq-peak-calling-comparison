#!/usr/bin/env bash
# Run this lightweight submission wrapper on the login node after successful
# fetch_inputs.sbatch and setup_env.sbatch completion. It is the only analysis submitter.
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
need sbatch
require_file "$ENV_PREFIX/provenance/conda-linux-64.explicit.txt"
require_file "$ENV_PREFIX/provenance/versions.txt"
require_file "$DATA_DIR/provenance/input_sha256.txt"
cmp -s "$SAMPLES_TSV" "$DATA_DIR/provenance/samples.tsv" || die "Sample manifest changed since download."
[[ "$SAMPLES_TSV" == "$PROJECT_ROOT/config/samples.tsv" ]] || die "Edit config/samples.tsv directly; alternate sample manifests are not supported by summarization."
[[ ! -e "$RESULTS_DIR" ]] || die "RESULTS_DIR exists. Use a new path in config/local.sh for each run."
[[ "$ARRAY_CONCURRENCY" =~ ^[1-9][0-9]*$ ]] || die "Invalid ARRAY_CONCURRENCY."
samples=$(awk 'END {print NR-1}' "$SAMPLES_TSV")
(( samples > 0 )) || die "No samples."
mkdir -p "$RESULTS_DIR/logs" "$RESULTS_DIR/provenance"
cp -a "$PROJECT_ROOT/config" "$RESULTS_DIR/provenance/config"
cp -a "$ENV_PREFIX/provenance" "$RESULTS_DIR/provenance/software"
cp -a "$DATA_DIR/provenance" "$RESULTS_DIR/provenance/inputs"
cd "$PROJECT_ROOT"
find scripts slurm env -maxdepth 1 -type f \( -name '*.py' -o -name '*.sh' -o -name '*.sbatch' -o -name '*.yml' \) -print0 | sort -z | xargs -0 sha256sum > "$RESULTS_DIR/provenance/source_sha256.txt"
find config -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum >> "$RESULTS_DIR/provenance/source_sha256.txt"
tar -czf "$RESULTS_DIR/provenance/source.tar.gz" config scripts slurm docs env/environment.yml env/bootstrap.sh
printf 'stage\tjob_id\n' > "$RESULTS_DIR/jobs.tsv"
export PROJECT_ROOT DATA_DIR RESULTS_DIR ENV_PREFIX SAMPLES_TSV
options=(--parsable --account="$ACCOUNT" --partition="$PARTITION" --qos="$QOS" --export=ALL --chdir="$PROJECT_ROOT" --kill-on-invalid-dep=yes)
submit() {
  local stage="$1"; shift
  local id
  id=$(sbatch "${options[@]}" --job-name="atac-$stage" --output="$RESULTS_DIR/logs/${stage}-%A_%a.log" "$@")
  id="${id%%;*}"
  [[ "$id" =~ ^[0-9]+$ ]] || die "Unexpected sbatch response."
  printf '%s\t%s\n' "$stage" "$id" >> "$RESULTS_DIR/jobs.tsv"
  printf '%s' "$id"
}
ref=$(submit reference --cpus-per-task=8 --mem=48G --time=08:00:00 slurm/stage.sbatch reference)
pre=$(submit preprocess --dependency="afterok:$ref" --array="1-${samples}%${ARRAY_CONCURRENCY}" --cpus-per-task=8 --mem=48G --time=18:00:00 slurm/stage.sbatch preprocess)
mac=$(submit macs3 --dependency="afterok:$pre" --array="1-${samples}%${ARRAY_CONCURRENCY}" --cpus-per-task=1 --mem=32G --time=12:00:00 slurm/stage.sbatch call macs3)
gen=$(submit genrich --dependency="afterok:$pre" --array="1-${samples}%${ARRAY_CONCURRENCY}" --cpus-per-task=1 --mem=32G --time=12:00:00 slurm/stage.sbatch call genrich)
hmm=$(submit hmmratac --dependency="afterok:$pre" --array="1-${samples}%${ARRAY_CONCURRENCY}" --cpus-per-task=1 --mem=64G --time=24:00:00 slurm/stage.sbatch call hmmratac)
summary=$(submit summarize --dependency="afterok:$mac:$gen:$hmm" --cpus-per-task=1 --mem=12G --time=08:00:00 slurm/stage.sbatch summarize)
printf '\nSubmitted dependency graph; final summary job %s.\n' "$summary"
cat "$RESULTS_DIR/jobs.tsv"
printf 'Monitor with bash slurm/status.sh. If submission stopped midway, inspect jobs.tsv before resubmitting.\n'
