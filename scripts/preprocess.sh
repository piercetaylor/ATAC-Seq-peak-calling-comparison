#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
[[ -n "${SLURM_JOB_ID:-}" ]] || die "Run preprocessing through SLURM."
activate_env
sample_at "${1:-${SLURM_ARRAY_TASK_ID:-}}"
require_file "$RESULTS_DIR/reference/.complete"
stage_begin "$RESULTS_DIR/preprocessing/$SAMPLE"
ref="$RESULTS_DIR/reference"
r1="$DATA_DIR/fastq/${SAMPLE}_R1.fastq.gz"
r2="$DATA_DIR/fastq/${SAMPLE}_R2.fastq.gz"
require_file "$r1"; require_file "$r2"
log_command fastp --in1 "$r1" --in2 "$r2" --out1 "$STAGE_DIR/trimmed_R1.fastq.gz" --out2 "$STAGE_DIR/trimmed_R2.fastq.gz" \
  --detect_adapter_for_pe --thread "$THREADS" --length_required 25 --json "$STAGE_DIR/fastp.json" --html "$STAGE_DIR/fastp.html" \
  > "$STAGE_DIR/fastp.log" 2>&1
# Reserve one allocated CPU for the simultaneously running SAM/BAM sorter.
align_threads=$((THREADS > 1 ? THREADS - 1 : 1))
log_command bowtie2 --very-sensitive --no-mixed --no-discordant -X "$MAX_INSERT" --seed "$SEED" -p "$align_threads" \
  -x "$ref/genome" -1 "$STAGE_DIR/trimmed_R1.fastq.gz" -2 "$STAGE_DIR/trimmed_R2.fastq.gz" \
  2> "$STAGE_DIR/bowtie2.log" | samtools sort -n -m 2G -o "$STAGE_DIR/name.bam" -
log_command samtools fixmate -m "$STAGE_DIR/name.bam" "$STAGE_DIR/fixmate.bam"
log_command samtools sort -@ "$((THREADS - 1))" -m 2G -o "$STAGE_DIR/coordinate.bam" "$STAGE_DIR/fixmate.bam"
log_command samtools markdup -s "$STAGE_DIR/coordinate.bam" "$STAGE_DIR/marked.bam" 2> "$STAGE_DIR/markdup.log"
log_command samtools sort -n -@ "$((THREADS - 1))" -m 2G -o "$STAGE_DIR/marked.namesort.bam" "$STAGE_DIR/marked.bam"
samtools view -h "$STAGE_DIR/marked.namesort.bam" | \
  python "$PROJECT_ROOT/scripts/filter_pairs.py" --blacklist "$ref/blacklist.bed" --mapq "$MAPQ" --sample "$SAMPLE" \
    --fragments "$STAGE_DIR/fragments.bed" --qc "$STAGE_DIR/qc.json" --fastp-json "$STAGE_DIR/fastp.json" | \
  samtools view -b -o "$STAGE_DIR/filtered.namesort.bam" -
log_command samtools sort -@ "$((THREADS - 1))" -m 2G -o "$STAGE_DIR/filtered.bam" "$STAGE_DIR/filtered.namesort.bam"
log_command samtools index "$STAGE_DIR/filtered.bam"
samtools quickcheck -v "$STAGE_DIR/filtered.bam" "$STAGE_DIR/filtered.namesort.bam"
samtools flagstat "$STAGE_DIR/filtered.bam" > "$STAGE_DIR/filtered.flagstat.txt"
# Delete only named, reproducible intermediates after validating final BAMs.
rm -- "$STAGE_DIR/name.bam" "$STAGE_DIR/fixmate.bam" "$STAGE_DIR/coordinate.bam" "$STAGE_DIR/marked.namesort.bam" \
  "$STAGE_DIR/trimmed_R1.fastq.gz" "$STAGE_DIR/trimmed_R2.fastq.gz"
stage_complete
