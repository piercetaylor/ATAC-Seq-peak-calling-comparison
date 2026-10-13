#!/usr/bin/env python3
"""Produce measured dashboard tables from completed, normalized caller outputs.

Intervals are zero-based, half-open. FRiP counts each eligible paired fragment
once per caller, regardless of the number of peaks it overlaps. No truth labels
or synthetic replacement results are generated here.
"""
from __future__ import annotations

import argparse
import bisect
import csv
import gzip
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import statistics
import sys
from datetime import datetime, timezone
from collections import Counter, defaultdict

CALLERS = {"macs3": "MACS3", "genrich": "Genrich", "hmmratac": "HMMRATAC"}


def read_tsv(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path, columns, rows):
    with Path(path).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def iter_bed(path):
    path = Path(path)
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip() or line.startswith(("#", "track ", "browser ")):
                continue
            fields = line.rstrip("\r\n").split("\t")
            try:
                chrom, start, end = fields[0], int(fields[1]), int(fields[2])
            except (IndexError, ValueError) as error:
                raise ValueError(f"{path}:{number}: invalid BED coordinates") from error
            if not chrom or start < 0 or end <= start:
                raise ValueError(f"{path}:{number}: require 0 <= start < end")
            yield chrom, start, end, fields


def load_intervals(path):
    intervals = defaultdict(list)
    for chrom, start, end, _ in iter_bed(path):
        intervals[chrom].append((start, end))
    return dict(intervals)


def merge_intervals(intervals):
    merged = {}
    for chrom, records in intervals.items():
        union = []
        for start, end in sorted(records):
            if union and start <= union[-1][1]:
                union[-1] = (union[-1][0], max(end, union[-1][1]))
            else:
                union.append((start, end))
        if union:
            merged[chrom] = union
    return merged


def covered_bases(merged):
    return sum(end - start for records in merged.values() for start, end in records)


def overlap_bases(a, b):
    total = 0
    for chrom in a.keys() & b.keys():
        left, right = a[chrom], b[chrom]
        i = j = 0
        while i < len(left) and j < len(right):
            total += max(0, min(left[i][1], right[j][1]) - max(left[i][0], right[j][0]))
            if left[i][1] <= right[j][1]:
                i += 1
            else:
                j += 1
    return total


def interval_index(merged):
    return {chrom: ([start for start, _ in records], [end for _, end in records])
            for chrom, records in merged.items()}


def overlaps(index, chrom, start, end):
    if chrom not in index:
        return False
    starts, ends = index[chrom]
    pos = bisect.bisect_left(starts, end) - 1
    return pos >= 0 and ends[pos] > start


def safe_ratio(numerator, denominator):
    return numerator / denominator if denominator else None


def compare_intervals(raw_a, raw_b):
    a, b = merge_intervals(raw_a), merge_intervals(raw_b)
    intersection = overlap_bases(a, b)
    size_a, size_b = covered_bases(a), covered_bases(b)
    union = size_a + size_b - intersection
    index_a, index_b = interval_index(a), interval_index(b)
    count_a = sum(len(records) for records in raw_a.values())
    count_b = sum(len(records) for records in raw_b.values())
    hit_a = sum(overlaps(index_b, chrom, start, end) for chrom, records in raw_a.items() for start, end in records)
    hit_b = sum(overlaps(index_a, chrom, start, end) for chrom, records in raw_b.items() for start, end in records)
    return {"intersection_bp": intersection, "union_bp": union,
            "jaccard": safe_ratio(intersection, union),
            "a_only_bp": size_a - intersection, "b_only_bp": size_b - intersection,
            "a_peaks_overlapping_b": hit_a, "b_peaks_overlapping_a": hit_b,
            "fraction_a_overlapping_b": safe_ratio(hit_a, count_a),
            "fraction_b_overlapping_a": safe_ratio(hit_b, count_b),
            "overlap_rule": "at_least_1_bp"}


def quantile(values, probability):
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    low, high = math.floor(position), math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def fragment_metrics(path, unions):
    indexes = {caller: interval_index(intervals) for caller, intervals in unions.items()}
    counts = Counter({caller: 0 for caller in indexes})
    histogram = Counter()
    total = 0
    for chrom, start, end, _ in iter_bed(path):
        total += 1
        histogram[end - start] += 1
        for caller, index in indexes.items():
            counts[caller] += overlaps(index, chrom, start, end)
    return total, counts, histogram


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def atomic_json(path, value):
    temporary = Path(str(path) + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def summarize(project_root, results_dir, run_type="full"):
    project_root, results_dir = Path(project_root).resolve(), Path(results_dir).resolve()
    project = json.loads((project_root / "config/project.json").read_text(encoding="utf-8-sig"))
    samples = read_tsv(project_root / "config/samples.tsv")
    sample_ids = [row.get("sample") or row.get("sample_id") for row in samples]
    if not sample_ids or any(not sample for sample in sample_ids) or len(set(sample_ids)) != len(sample_ids):
        raise ValueError("samples.tsv must contain unique, nonempty sample or sample_id values")
    for sample in sample_ids:
        if not all(char.isalnum() or char in "_-" for char in sample):
            raise ValueError(f"Unsafe sample identifier: {sample!r}")
    output = results_dir / "dashboard"
    output.mkdir(parents=True, exist_ok=True)
    status = {"schema_version": 1, "dataset": project.get("dataset", "GM12878 Omni-ATAC"),
              "assembly": project.get("assembly", "hg38"), "mode": run_type,
              "status": "summarizing", "samples": sample_ids,
              "notes": "Descriptive comparison; no truth set. HMMRATAC uses MACS3. Replicate libraries are not independent human donors.",
              "generated_at": datetime.now(timezone.utc).isoformat()}
    atomic_json(output / "status.json", status)
    try:
        peak_rows, qc_rows, runtime_rows, length_rows, width_rows = [], [], [], [], []
        all_intervals = {}
        provenance = []
        for sample in sample_ids:
            pre = results_dir / "preprocessing" / sample
            if not (pre / ".complete").is_file() or (pre / ".failed").exists():
                raise ValueError(f"Preprocessing is not marked successfully complete: {sample}")
            qc = json.loads((pre / "qc.json").read_text(encoding="utf-8-sig"))
            raw = {}
            for slug, caller in CALLERS.items():
                caller_dir = results_dir / "peaks" / sample / slug
                if not (caller_dir / ".complete").is_file() or (caller_dir / ".failed").exists():
                    raise ValueError(f"Caller is not marked successfully complete: {sample} {caller}")
                bed = caller_dir / "peaks.bed"
                raw[caller] = load_intervals(bed)  # missing files must fail; empty files are valid
                provenance.append({"path": str(bed.relative_to(results_dir)).replace("\\", "/"), "sha256": sha256(bed)})
                runtime = read_tsv(caller_dir / "runtime.tsv")
                if len(runtime) != 1:
                    raise ValueError(f"{caller_dir}/runtime.tsv must contain one measurement")
                record = runtime[0]
                if record.get("exit_status", "0") != "0":
                    raise ValueError(f"Caller did not succeed: {sample} {caller}")
                for column in ("elapsed_seconds", "max_rss_kb"):
                    value = float(record[column])
                    if not math.isfinite(value) or value < 0:
                        raise ValueError(f"Invalid runtime {column}: {sample} {caller}")
                runtime_rows.append({**record, "sample": sample, "caller": caller})
            unions = {caller: merge_intervals(intervals) for caller, intervals in raw.items()}
            count, hits, histogram = fragment_metrics(pre / "fragments.bed", unions)
            if "filtered_pairs" not in qc or int(qc["filtered_pairs"]) != count:
                raise ValueError(f"Fragment/QC denominator mismatch for {sample}")
            if count == 0:
                raise ValueError(f"No eligible fragments remain for {sample}; cannot compare callers")
            qc_rows.append({**qc, "sample": sample})
            for width, frequency in sorted(histogram.items()):
                length_rows.append({"sample": sample, "length_bp": width, "fragments": frequency})
            for caller, intervals in raw.items():
                widths = [end - start for records in intervals.values() for start, end in records]
                for width, frequency in sorted(Counter(widths).items()):
                    width_rows.append({"sample": sample, "caller": caller, "width_bp": width, "peaks": frequency})
                peak_rows.append({"sample": sample, "caller": caller, "n_peaks": len(widths),
                                  "total_peak_bp": covered_bases(unions[caller]),
                                  "median_peak_width": statistics.median(widths) if widths else None,
                                  "q25_peak_width": quantile(widths, .25), "q75_peak_width": quantile(widths, .75),
                                  "frip": safe_ratio(hits[caller], count), "fragments": count,
                                  "fragments_in_peaks": hits[caller]})
            all_intervals[sample] = raw
        pair_rows = [{"sample": sample, "caller_a": a, "caller_b": b, **compare_intervals(intervals[a], intervals[b])}
                     for sample, intervals in all_intervals.items()
                     for a, b in itertools.combinations(CALLERS.values(), 2)]
        rep_rows = [{"caller": caller, "sample_a": a, "sample_b": b,
                     **compare_intervals(all_intervals[a][caller], all_intervals[b][caller])}
                    for caller in CALLERS.values() for a, b in itertools.combinations(sample_ids, 2)]
        comparison_cols = ["intersection_bp", "union_bp", "jaccard", "a_only_bp", "b_only_bp",
                           "a_peaks_overlapping_b", "b_peaks_overlapping_a", "fraction_a_overlapping_b",
                           "fraction_b_overlapping_a", "overlap_rule"]
        tables = {
            "peak_metrics.tsv": (["sample", "caller", "n_peaks", "total_peak_bp", "median_peak_width", "q25_peak_width", "q75_peak_width", "frip", "fragments", "fragments_in_peaks"], peak_rows),
            "qc.tsv": (["sample", "raw_pairs", "filtered_pairs", "duplicate_fraction", "mitochondrial_fraction"], qc_rows),
            "runtime.tsv": (["sample", "caller", "elapsed_seconds", "max_rss_kb"], runtime_rows),
            "pairwise_overlap.tsv": (["sample", "caller_a", "caller_b"] + comparison_cols, pair_rows),
            "replicate_overlap.tsv": (["caller", "sample_a", "sample_b"] + comparison_cols, rep_rows),
            "fragment_lengths.tsv": (["sample", "length_bp", "fragments"], length_rows),
            "peak_widths.tsv": (["sample", "caller", "width_bp", "peaks"], width_rows),
            "samples.tsv": (list(samples[0]), samples),
            "artifacts.tsv": (["path", "sha256"], provenance),
        }
        for filename, (columns, rows) in tables.items():
            temporary = output / (filename + ".tmp")
            write_tsv(temporary, columns, rows)
            os.replace(temporary, output / filename)
        with gzip.open(output / "peaks.tsv.gz", "wt", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
            writer.writerow(["sample", "caller", "chrom", "start", "end", "peak_id"])
            for sample, caller_intervals in all_intervals.items():
                for caller, intervals in caller_intervals.items():
                    number = 0
                    for chrom in sorted(intervals):
                        for start, end in sorted(intervals[chrom]):
                            number += 1
                            writer.writerow([sample, caller, chrom, start, end, f"{sample}_{caller}_{number}"])
        status.update(status="complete", config_sha256=sha256(project_root / "config/project.json"),
                      samples_sha256=sha256(project_root / "config/samples.tsv"),
                      generated_at=datetime.now(timezone.utc).isoformat())
        atomic_json(output / "status.json", status)
    except Exception as error:
        status.update(status="failed", error=str(error))
        atomic_json(output / "status.json", status)
        raise
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--results-dir", type=Path)
    parser.add_argument("--run-type", choices=["full", "subsample_smoke", "synthetic_fixture"], default="full")
    args = parser.parse_args()
    try:
        output = summarize(args.project_root, args.results_dir or args.project_root / "results", args.run_type)
    except (ValueError, OSError, KeyError) as error:
        print(f"Summary failed: {error}", file=sys.stderr)
        return 1
    print(f"Validated dashboard bundle: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
