#!/usr/bin/env bash
# Offline scheduler test: a fake sbatch records arguments; no cluster is contacted.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
mkdir -p "$root/.tmp"
fixture=$(mktemp -d "$root/.tmp/submission-fixture.XXXXXX")
mkdir -p "$fixture/project/env" "$fixture/bin" "$fixture/data/provenance" "$fixture/runtime/provenance"
cp -R "$root/scripts" "$root/slurm" "$root/config" "$root/docs" "$fixture/project/"
cp "$root/env/environment.yml" "$root/env/bootstrap.sh" "$fixture/project/env/"
[[ ! -f "$fixture/project/config/local.sh" ]] || { printf 'Test requires no local override in copied config.\n' >&2; exit 1; }
cp "$root/config/samples.tsv" "$fixture/data/provenance/samples.tsv"
touch "$fixture/data/provenance/input_sha256.txt" "$fixture/runtime/provenance/conda-linux-64.explicit.txt" "$fixture/runtime/provenance/versions.txt"
cat > "$fixture/bin/sbatch" <<'FAKE'
#!/usr/bin/env bash
set -eu
number=$(cat "$TEST_JOB_COUNTER")
number=$((number + 1))
printf '%s' "$number" > "$TEST_JOB_COUNTER"
printf '%s\t' "$number" >> "$TEST_JOB_ARGUMENTS"
printf '%s ' "$@" >> "$TEST_JOB_ARGUMENTS"
printf '\n' >> "$TEST_JOB_ARGUMENTS"
printf '%s\n' "$number"
FAKE
chmod +x "$fixture/bin/sbatch"
export TEST_JOB_COUNTER="$fixture/counter" TEST_JOB_ARGUMENTS="$fixture/arguments.tsv"
printf 100 > "$TEST_JOB_COUNTER"
export PATH="$fixture/bin:$PATH" PROJECT_ROOT="$fixture/project" DATA_DIR="$fixture/data" RESULTS_DIR="$fixture/results" ENV_PREFIX="$fixture/runtime"
export SAMPLES_TSV="$fixture/project/config/samples.tsv"
bash "$fixture/project/slurm/submit_pipeline.sh" > "$fixture/stdout.txt"
[[ $(cat "$TEST_JOB_COUNTER") == 106 ]]
[[ $(wc -l < "$RESULTS_DIR/jobs.tsv") == 7 ]]
grep -q -- '--dependency=afterok:101 --array=1-2%2' "$TEST_JOB_ARGUMENTS"
grep -q -- '--dependency=afterok:103:104:105' "$TEST_JOB_ARGUMENTS"
if bash "$fixture/project/slurm/submit_pipeline.sh" > "$fixture/retry.txt" 2>&1; then
  printf 'Submission incorrectly reused existing results.\n' >&2; exit 1
fi
[[ $(cat "$TEST_JOB_COUNTER") == 106 ]]
printf 'Offline submission test passed: six dependent stages; stale-output refusal.\n'
