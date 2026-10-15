#!/usr/bin/env python3
"""Validate manifests and prerequisite files without submitting work."""
import argparse
import csv
import json
import re
from pathlib import Path


def validate(root, data_dir=None, reference_dir=None, reference_only=False):
    if not reference_only:
        json.loads((root / "config/project.json").read_text(encoding="utf-8-sig"))
        with (root / "config/samples.tsv").open(encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
        if not rows:
            raise ValueError("No samples configured")
        names = set()
        for row in rows:
            sample = row["sample"]
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", sample) or sample in names:
                raise ValueError("Invalid or repeated sample: " + sample)
            names.add(sample)
            for mate in ("1", "2"):
                if not row["fastq_" + mate].startswith("https://") or not re.fullmatch(r"[a-f0-9]{32}", row["md5_" + mate]):
                    raise ValueError("Require HTTPS URL and MD5 for " + sample)
                if data_dir and not (data_dir / "fastq" / f"{sample}_R{mate}.fastq.gz").is_file():
                    raise ValueError("FASTQ missing: " + sample + " mate " + mate)
        if data_dir:
            receipt = data_dir / "provenance/samples.tsv"
            if not receipt.is_file() or receipt.read_bytes() != (root / "config/samples.tsv").read_bytes():
                raise ValueError("Input receipt differs from current sample manifest; rerun slurm/fetch_inputs.sbatch")
            if not (data_dir / "provenance/input_sha256.txt").is_file():
                raise ValueError("Input checksum receipt is missing")
    if reference_dir:
        from filter_pairs import CANONICAL, read_bed
        sizes = dict((row.split()[0], int(row.split()[1])) for row in (reference_dir / "chrom.sizes").read_text().splitlines())
        if not all(chrom in sizes for chrom in CANONICAL):
            raise ValueError("Reference is missing canonical hg38 chromosomes")
        for chrom, start, end in read_bed(reference_dir / "blacklist.bed"):
            if chrom not in sizes or start < 0 or end <= start or end > sizes[chrom]:
                raise ValueError(f"Blacklist/reference mismatch: {chrom}:{start}-{end}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--data-dir", type=Path)
    parser.add_argument("--reference-dir", type=Path)
    parser.add_argument("--reference-only", action="store_true")
    args = parser.parse_args()
    validate(args.project_root, args.data_dir, args.reference_dir, args.reference_only)
    print("Preflight passed.")
