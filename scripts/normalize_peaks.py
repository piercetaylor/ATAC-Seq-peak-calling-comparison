#!/usr/bin/env python3
"""Validate caller intervals; apply common canonical/blacklist filtering to BED3.

Native files remain untouched. Existing empty native files are valid; missing
files and malformed coordinates fail. Peaks are not merged for peak counts.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
from filter_pairs import CANONICAL, IntervalIndex, read_bed


def normalize(intervals, sizes, blacklist):
    retained, counts = [], Counter()
    rank = {chrom: i for i, chrom in enumerate(CANONICAL)}
    for chrom, start, end in intervals:
        counts["native_peaks"] += 1
        if chrom not in sizes:
            raise ValueError(f"Unknown reference contig: {chrom}")
        if start < 0 or end <= start or end > sizes[chrom]:
            raise ValueError(f"Out-of-bounds/invalid peak: {chrom}:{start}-{end}")
        if chrom not in rank:
            counts["excluded_contig"] += 1
        elif blacklist.overlaps(chrom, start, end):
            counts["blacklist"] += 1
        else:
            retained.append((chrom, start, end))
    retained.sort(key=lambda row: (rank[row[0]], row[1], row[2]))
    counts["retained_peaks"] = len(retained)
    counts.setdefault("native_peaks", 0)
    return retained, dict(counts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--sizes", required=True)
    parser.add_argument("--blacklist", required=True)
    args = parser.parse_args()
    sizes = {}
    for line in Path(args.sizes).read_text().splitlines():
        chrom, size = line.split()[:2]
        sizes[chrom] = int(size)
    peaks, counts = normalize(read_bed(args.input), sizes, IntervalIndex(read_bed(args.blacklist)))
    with open(args.output, "w", encoding="utf-8", newline="\n") as out:
        for chrom, start, end in peaks:
            out.write(f"{chrom}\t{start}\t{end}\n")
    Path(args.output).with_suffix(".normalization.json").write_text(json.dumps(counts, indent=2) + "\n")


if __name__ == "__main__":
    main()
