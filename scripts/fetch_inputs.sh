#!/usr/bin/env bash
# Run on the designated Hellbender DTN, not the login or compute nodes.
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/scripts/common.sh"
[[ -z "${SLURM_JOB_ID:-}" ]] || die "Transfer inputs on the DTN before submitting jobs."
[[ "$(hostname -s)" != *login* ]] || die "Transfer inputs on hellbender-dtn-p1, not the login node."
need curl; need md5sum; need sha256sum; need gzip
mkdir -p "$DATA_DIR/fastq" "$REF_DIR" "$DATA_DIR/provenance"

fetch_checked() {
  local url="$1" target="$2" algorithm="$3" expected="$4" observed
  if [[ -f "$target" ]]; then
    observed=$("${algorithm}sum" "$target"); observed="${observed%% *}"
    [[ "$observed" == "$expected" ]] || die "Existing file has wrong $algorithm: $target; inspect and move it before retrying."
  else
    curl --fail --location --retry 5 --retry-delay 5 --continue-at - --output "$target.part" "$url"
    observed=$("${algorithm}sum" "$target.part"); observed="${observed%% *}"
    [[ "$observed" == "$expected" ]] || die "Checksum mismatch: $target.part; inspect/remove only the failed partial download before retrying."
    gzip -t "$target.part"
    mv -- "$target.part" "$target"
  fi
  printf '%s\t%s\t%s\t%s\n' "$target" "$url" "$algorithm" "$expected" >> "$DATA_DIR/provenance/downloads.tsv.part"
}

printf 'path\turl\talgorithm\texpected_digest\n' > "$DATA_DIR/provenance/downloads.tsv.part"
while IFS=$'\t' read -r sample run replicate fq1 fq2 md51 md52; do
  [[ "$sample" == sample ]] && continue
  md52="${md52%$'\r'}"
  [[ "$sample" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || die "Invalid sample name in manifest."
  [[ "$md51" =~ ^[a-f0-9]{32}$ && "$md52" =~ ^[a-f0-9]{32}$ ]] || die "Missing ENA checksums for $sample"
  fetch_checked "$fq1" "$DATA_DIR/fastq/${sample}_R1.fastq.gz" md5 "$md51"
  fetch_checked "$fq2" "$DATA_DIR/fastq/${sample}_R2.fastq.gz" md5 "$md52"
done < "$SAMPLES_TSV"
fetch_checked "$REFERENCE_URL" "$REF_DIR/hg38.analysisSet.fa.gz" md5 "$REFERENCE_MD5"
fetch_checked "$BLACKLIST_URL" "$REF_DIR/hg38-blacklist.v2.bed.gz" sha256 "$BLACKLIST_SHA256"
mv -- "$DATA_DIR/provenance/downloads.tsv.part" "$DATA_DIR/provenance/downloads.tsv"
# Receipt freezes the exact manifest and local SHA256 of all downloaded bytes.
cp -- "$SAMPLES_TSV" "$DATA_DIR/provenance/samples.tsv"
sha256sum "$DATA_DIR/fastq/"*.fastq.gz "$REF_DIR/"*.gz > "$DATA_DIR/provenance/input_sha256.txt.part"
mv -- "$DATA_DIR/provenance/input_sha256.txt.part" "$DATA_DIR/provenance/input_sha256.txt"
printf 'All inputs downloaded and verified. Submit from the login node with bash slurm/submit_pipeline.sh.\n'
