# Output format (version 1)

All paths below are relative to `RESULTS_DIR`. A stage counts as done only if its directory contains `.complete` and does not contain `.failed`. The presence of output files alone is not enough.

## Stage outputs

| Path | Contents |
|---|---|
| `preprocessing/<sample>/filtered.bam` | Retained pairs, coordinate-sorted (plus a name-sorted copy) |
| `preprocessing/<sample>/fragments.bed` | One half-open interval per retained fragment; the FRiP denominator |
| `preprocessing/<sample>/qc.json` | Read counts, duplicate and chrM fractions, filter counters |
| `peaks/<sample>/<caller>/peaks.bed` | Normalized peaks (`macs3`, `genrich`, `hmmratac`); native output is kept in `native/` |
| `peaks/<sample>/<caller>/runtime.tsv` | Wall time and peak RSS of the caller command |

A caller that returns zero peaks fails its stage.

In `qc.json`, the duplicate and chrM fractions share one denominator: all primary read pairs after alignment and before filtering. A pair counts as a duplicate, or as mitochondrial, if either mate is flagged. The two fractions can overlap.

## Dashboard bundle (`dashboard/`)

`scripts/summarize.py` writes these files only after checking every sample and caller:

| File | Required columns |
|---|---|
| `peak_metrics.tsv` | sample, caller, n_peaks, total_peak_bp, median_peak_width, frip, fragments |
| `pairwise_overlap.tsv` | sample, caller_a, caller_b, intersection_bp, union_bp, jaccard |
| `replicate_overlap.tsv` | caller, sample_a, sample_b, intersection_bp, union_bp, jaccard |
| `qc.tsv` | sample, raw_pairs, filtered_pairs, duplicate_fraction, mitochondrial_fraction |
| `runtime.tsv` | sample, caller, elapsed_seconds, max_rss_kb |
| `fragment_lengths.tsv` | sample, length_bp, fragments |
| `peak_widths.tsv` | sample, caller, width_bp, peaks |
| `peaks.tsv.gz` | sample, caller, chrom, start, end, peak_id |
| `artifacts.tsv` | path, sha256 |

Some tables have extra columns: peak-width quartiles, overlapping peak counts, directional overlap fractions, and `overlap_rule=at_least_1_bp`.

**`status.json`** records the dataset, assembly, mode, status, samples, and config hashes.
- `mode` is `full`, `subsample_smoke`, or `synthetic_fixture`.
- `status` is `complete` only after every table is written and validated.

**Missing and undefined values** are written as blanks, never as zeros. Jaccard is undefined when both peak sets are empty.
