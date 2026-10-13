#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
[[ -n "${SLURM_JOB_ID:-}" ]] || die "Run peak calling through SLURM."
activate_env
caller="${1:?caller required}"; sample_at "${2:-${SLURM_ARRAY_TASK_ID:-}}"
require_file "$RESULTS_DIR/preprocessing/$SAMPLE/.complete"
stage_begin "$RESULTS_DIR/peaks/$SAMPLE/$caller"
mkdir -p "$STAGE_DIR/native"
hostname > "$STAGE_DIR/host.txt"
lscpu > "$STAGE_DIR/cpu.txt"
pre="$RESULTS_DIR/preprocessing/$SAMPLE"; ref="$RESULTS_DIR/reference"
case "$caller" in
  macs3)
    label=MACS3
    command=(macs3 callpeak -t "$pre/filtered.bam" -f BAMPE -g "$EFFECTIVE_GENOME_SIZE" -q "$QVALUE" --keep-dup all -n "$SAMPLE" --outdir "$STAGE_DIR/native")
    native="$STAGE_DIR/native/${SAMPLE}_peaks.narrowPeak" ;;
  genrich)
    label=Genrich
    command=(Genrich -t "$pre/filtered.namesort.bam" -o "$STAGE_DIR/native/${SAMPLE}.narrowPeak" -j -q "$QVALUE" -e "$(cat "$ref/excluded_contigs.txt")" -v)
    native="$STAGE_DIR/native/${SAMPLE}.narrowPeak" ;;
  hmmratac)
    label=HMMRATAC
    # v3.0.3 preserves duplicates by default; already deduplicated upstream.
    command=(macs3 hmmratac -i "$pre/filtered.bam" -f BAMPE -n "$SAMPLE" --outdir "$STAGE_DIR/native" --randomSeed "$SEED")
    native="$STAGE_DIR/native/${SAMPLE}_accessible_regions.narrowPeak" ;;
  *) die "Unknown caller: $caller" ;;
esac
printf '%q ' "${command[@]}" > "$STAGE_DIR/commands.sh"; printf '\n' >> "$STAGE_DIR/commands.sh"
set +e
"$ENV_PREFIX/bin/time" -q -f '%e\t%M\t%x' -o "$STAGE_DIR/time.raw.tsv" "${command[@]}" > "$STAGE_DIR/caller.log" 2>&1
rc=$?
set -e
printf 'sample\tcaller\telapsed_seconds\tmax_rss_kb\texit_status\n' > "$STAGE_DIR/runtime.tsv"
printf '%s\t%s\t' "$SAMPLE" "$label" >> "$STAGE_DIR/runtime.tsv"
cat "$STAGE_DIR/time.raw.tsv" >> "$STAGE_DIR/runtime.tsv"
(( rc == 0 )) || exit "$rc"
require_file "$native"
log_command python "$PROJECT_ROOT/scripts/normalize_peaks.py" --input "$native" --output "$STAGE_DIR/peaks.bed" \
  --sizes "$ref/chrom.sizes" --blacklist "$ref/blacklist.bed"
stage_complete
