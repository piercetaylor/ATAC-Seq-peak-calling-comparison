# Results contract, version 1

All relative paths here are beneath the selected results directory. There are no actual analysis results until the cluster workflow completes. Test fixtures exist only in temporary test directories.

Preprocessing and caller directories must each have a `.complete` marker and no `.failed` marker before summarization. Presence of output files alone does not establish successful execution.

## Stage products

- `preprocessing/<sample>/filtered.bam`: eligible coordinate-sorted paired alignments; its queryname-sorted counterpart contains the same records.
- `preprocessing/<sample>/fragments.bed`: exactly one zero-based, half-open interval per retained fragment, with read-pair name in column 4. This file defines the FRiP denominator.
- `preprocessing/<sample>/qc.json`: includes `filtered_pairs`; it must equal the fragment count. `raw_pairs`, `duplicate_fraction`, and `mitochondrial_fraction` are propagated into the dashboard. Exact filtering counters remain in this JSON.
- `peaks/<sample>/<caller>/peaks.bed`: normalized final intervals. Caller path names are `macs3`, `genrich`, and `hmmratac`. An empty file is a valid zero-peak result only after successful calling; a missing file is an error.
- `peaks/<sample>/<caller>/runtime.tsv`: one data row containing `elapsed_seconds`, `max_rss_kb`, and optionally `exit_status`, which must be zero. Measurements apply to the caller command rather than preprocessing.

`raw_pairs` is half of fastp's raw input read count. The duplicate and mitochondrial fractions use primary read-name groups after trimming/alignment but before pair filtering as their denominator, including unmapped groups. A group is duplicate-positive if either primary mate is marked duplicate, and mitochondrial-positive if either primary mate maps to chrM. These categories can overlap; they are not sequential loss fractions. Detailed counters and the denominator description are saved in `qc.json`.

## Dashboard bundle

`scripts/summarize.py` writes `dashboard/` after checking all selected samples and callers. Table caller labels are `MACS3`, `Genrich`, and `HMMRATAC`. Numeric missing values are blank, not zero.

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

`samples.tsv` copies configured provenance. Additional peak columns contain `q25_peak_width`, `q75_peak_width`, and `fragments_in_peaks`. Pairwise tables also contain unique coverage, overlapping peak counts, directional fractions, and `overlap_rule=at_least_1_bp`. Native caller scores are intentionally not compared across methods; original output files retain those scores.

`status.json` contains `schema_version`, `dataset`, `assembly`, `mode`, `status`, `samples`, `notes`, and generation timestamp. A complete bundle additionally records project and sample-configuration SHA256 digests. `mode` is `full`, `subsample_smoke`, or `synthetic_fixture`; the latter two never represent a completed full dataset run. Summary status is `summarizing`, `complete`, or `failed`. The summary writes `complete` only after validating and publishing every required table. A failure records its error explicitly.

Jaccard is undefined if both interval sets are empty. Median widths of empty peak sets are missing. FRiP is zero for empty peaks when retained fragments exist; a library with zero retained fragments fails the comparison rather than presenting a usable result. Fragment overlap counts an eligible fragment once per caller even if it overlaps multiple peaks.

Shiny reads this bundle only; it never submits compute jobs or downloads reads. The selected results path is controlled by `ATAC_RESULTS_DIR`.
