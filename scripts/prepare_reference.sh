#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
[[ -n "${SLURM_JOB_ID:-}" ]] || die "Run reference preparation through SLURM."
activate_env
stage_begin "$RESULTS_DIR/reference"
require_file "$REF_DIR/hg38.analysisSet.fa.gz"
require_file "$REF_DIR/hg38-blacklist.v2.bed.gz"
# Per-run derived reference prevents index reuse across different assemblies/configs.
gzip -dc "$REF_DIR/hg38.analysisSet.fa.gz" > "$STAGE_DIR/genome.fa"
gzip -dc "$REF_DIR/hg38-blacklist.v2.bed.gz" > "$STAGE_DIR/blacklist.bed"
log_command samtools faidx "$STAGE_DIR/genome.fa"
cut -f1,2 "$STAGE_DIR/genome.fa.fai" > "$STAGE_DIR/chrom.sizes"
awk '$1 ~ /^chr([1-9]|1[0-9]|2[0-2]|X|Y)$/ {print $1 "\t" $2}' "$STAGE_DIR/chrom.sizes" > "$STAGE_DIR/canonical.sizes"
[[ $(wc -l < "$STAGE_DIR/canonical.sizes") -eq 24 ]] || die "Reference must contain chr1-22, chrX, and chrY."
awk '$1 !~ /^chr([1-9]|1[0-9]|2[0-2]|X|Y)$/ {print $1}' "$STAGE_DIR/chrom.sizes" | paste -sd, - > "$STAGE_DIR/excluded_contigs.txt"
python "$PROJECT_ROOT/scripts/preflight.py" --project-root "$PROJECT_ROOT" --reference-dir "$STAGE_DIR" --reference-only
log_command bowtie2-build --threads "$THREADS" "$STAGE_DIR/genome.fa" "$STAGE_DIR/genome"
sha256sum "$STAGE_DIR/genome.fa" "$STAGE_DIR/blacklist.bed" "$STAGE_DIR/chrom.sizes" > "$STAGE_DIR/reference_sha256.txt"
stage_complete
