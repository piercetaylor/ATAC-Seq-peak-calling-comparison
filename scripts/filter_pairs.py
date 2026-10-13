#!/usr/bin/env python3
"""Filter a query-name grouped SAM stream, retaining both mates or neither.

One fragment record represents one proper, primary, duplicate-free pair. No Tn5
shift or post-alignment length truncation is applied. Coordinates are BED0.
"""
from __future__ import annotations

import argparse
from bisect import bisect_left
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import sys

CANONICAL = tuple([f"chr{i}" for i in range(1, 23)] + ["chrX", "chrY"])
CIGAR = re.compile(r"(\d+)([MIDNSHP=X])")


class IntervalIndex:
    """Merged half-open intervals with logarithmic overlap queries."""

    def __init__(self, intervals=()):
        grouped = defaultdict(list)
        for chrom, start, end in intervals:
            if start < 0 or end <= start:
                raise ValueError(f"Invalid interval: {chrom}:{start}-{end}")
            grouped[chrom].append((start, end))
        self.data = {}
        for chrom, values in grouped.items():
            merged = []
            for start, end in sorted(values):
                if merged and start <= merged[-1][1]:
                    merged[-1] = (merged[-1][0], max(end, merged[-1][1]))
                else:
                    merged.append((start, end))
            self.data[chrom] = ([s for s, _ in merged], [e for _, e in merged])

    def overlaps(self, chrom, start, end):
        starts, ends = self.data.get(chrom, ([], []))
        pos = bisect_left(starts, end) - 1
        return pos >= 0 and ends[pos] > start


def read_bed(path):
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip() or line.startswith(("#", "track", "browser")):
                continue
            fields = line.split()
            if len(fields) < 3:
                raise ValueError(f"{path}:{number}: expected at least 3 BED columns")
            yield fields[0], int(fields[1]), int(fields[2])


def reference_length(cigar):
    parts = CIGAR.findall(cigar)
    if not parts or "".join(n + op for n, op in parts) != cigar:
        raise ValueError(f"Invalid CIGAR: {cigar}")
    return sum(int(n) for n, op in parts if op in "MDN=X")


def inspect_pair(records, blacklist, min_mapq=30, allowed=CANONICAL):
    """Return (reason, BED3 fragment or None) for primary SAM fields."""
    if len(records) != 2:
        return "not_two_primary_mates", None
    first, second = records
    flags = [int(row[1]) for row in records]
    if any((flag & 3) != 3 or (flag & (4 | 8 | 256 | 512 | 2048)) for flag in flags):
        return "not_proper_mapped_qc_pair", None
    if sorted(flag & (64 | 128) for flag in flags) != [64, 128]:
        return "invalid_mate_flags", None
    if any(flag & 1024 for flag in flags):
        return "duplicate", None
    if first[2] != second[2]:
        return "discordant_contigs", None
    chrom = first[2]
    if chrom not in allowed:
        return "excluded_contig", None
    if any(int(row[4]) < min_mapq for row in records):
        return "low_mapq", None
    if any(row[6] not in ("=", chrom) for row in records):
        return "invalid_mate_reference", None
    if int(first[7]) != int(second[3]) or int(second[7]) != int(first[3]):
        return "invalid_mate_position", None
    starts = [int(row[3]) - 1 for row in records]
    ends = [start + reference_length(row[5]) for start, row in zip(starts, records)]
    start, end = min(starts), max(ends)
    tlen1, tlen2 = int(first[8]), int(second[8])
    if start < 0 or end <= start or tlen1 != -tlen2 or abs(tlen1) != end - start:
        return "invalid_template_span", None
    if blacklist.overlaps(chrom, start, end):
        return "blacklist", None
    return "retained", (chrom, start, end)


def filter_stream(source, destination, fragments, blacklist, min_mapq=30):
    counts = Counter()
    lengths = Counter()
    name, records, lines = None, [], []
    saw_queryname_header = False

    def finish_group():
        if name is None or not records:
            return
        counts["primary_pairs"] += 1
        if any(int(row[1]) & 1024 for row in records):
            counts["duplicate_pairs"] += 1
        if any(row[2] in ("chrM", "MT", "M") for row in records):
            counts["mitochondrial_pairs"] += 1
        reason, fragment = inspect_pair(records, blacklist, min_mapq)
        counts[reason] += 1
        if fragment:
            destination.writelines(lines)
            chrom, start, end = fragment
            fragments.write(f"{chrom}\t{start}\t{end}\t{name}\n")
            lengths[end - start] += 1

    for line in source:
        if line.startswith("@"):
            if name is not None:
                raise ValueError("SAM header encountered inside alignment records")
            if line.startswith("@HD") and "SO:queryname" in line:
                saw_queryname_header = True
            destination.write(line)
            continue
        if not line.strip():
            continue
        if not saw_queryname_header:
            raise ValueError("Require SAM header SO:queryname (samtools sort -n).")
        fields = line.rstrip("\n").split("\t")
        if len(fields) < 11:
            raise ValueError("SAM record contains fewer than 11 fields")
        if fields[0] != name:
            finish_group()
            name, records, lines = fields[0], [], []
        if int(fields[1]) & (256 | 2048):
            counts["secondary_supplementary_records"] += 1
            continue
        records.append(fields)
        lines.append(line)
    finish_group()
    total = counts["primary_pairs"]
    qc = dict(counts)
    qc.update(filtered_pairs=counts["retained"],
              duplicate_fraction=counts["duplicate_pairs"] / total if total else None,
              mitochondrial_fraction=counts["mitochondrial_pairs"] / total if total else None,
              fraction_denominator="primary_pairs after fastp, before pair filtering")
    return qc, lengths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--blacklist", required=True)
    parser.add_argument("--fragments", required=True)
    parser.add_argument("--qc", required=True)
    parser.add_argument("--fastp-json", required=True)
    parser.add_argument("--sample", required=True)
    parser.add_argument("--mapq", type=int, default=30)
    args = parser.parse_args()
    index = IntervalIndex(read_bed(args.blacklist))
    with open(args.fragments, "w", encoding="utf-8", newline="\n") as fragments:
        qc, lengths = filter_stream(sys.stdin, sys.stdout, fragments, index, args.mapq)
    fastp = json.loads(Path(args.fastp_json).read_text())
    raw_reads = fastp["summary"]["before_filtering"]["total_reads"]
    if raw_reads % 2:
        raise ValueError("fastp reports an odd number of paired-end raw reads")
    qc.update(sample=args.sample, raw_pairs=raw_reads // 2, mapq=args.mapq)
    Path(args.qc).write_text(json.dumps(qc, indent=2) + "\n", encoding="utf-8")
    with Path(args.qc).with_name("fragment_length_histogram.tsv").open("w", newline="\n") as out:
        out.write("sample\tlength\tcount\n")
        for length, count in sorted(lengths.items()):
            out.write(f"{args.sample}\t{length}\t{count}\n")
    if not qc["filtered_pairs"]:
        raise ValueError("No usable pairs remain; refusing to pass an empty BAM to callers")


if __name__ == "__main__":
    main()
