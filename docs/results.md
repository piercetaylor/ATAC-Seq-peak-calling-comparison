# Results

Run completed 2026-10-14; Genrich re-run 2026-10-15. Source tables are in `results/dashboard/`. There is no truth set, so agreement between callers says nothing about accuracy.

## Library quality

| Library | Raw pairs | Retained pairs | Duplicates | chrM |
|---|---:|---:|---:|---:|
| RepA | 31.1 M | 22.7 M | 12.8% | 2.1% |
| RepB | 37.6 M | 27.6 M | 12.3% | 1.8% |

Both libraries are clean: duplication and mitochondrial content are low, and FRiP was at least 0.41 for every caller.

## Peak calls

| Caller (cutoff) | Peaks, A / B | Covered, A / B | Median width | FRiP, A / B |
|---|---:|---:|---:|---:|
| MACS3 (q < 0.01) | 68,936 / 73,193 | 44.9 / 50.3 Mb | ~560 bp | 0.47 / 0.47 |
| Genrich (p < 0.01) | 74,714 / 73,975 | 61.6 / 60.4 Mb | ~580 bp | 0.53 / 0.52 |
| HMMRATAC | 147,871 / 191,649 | 31.2 / 46.0 Mb | ~120 bp | 0.41 / 0.52 |

MACS3 and Genrich called similar numbers of peaks. Genrich covered more sequence because its widths have a longer upper tail (Q3 about 1,040 bp versus 860 bp for MACS3). HMMRATAC split accessible chromatin into twice as many short regions. It was also the most sensitive to depth: the deeper library, RepB, had 30% more HMMRATAC peaks than RepA.

## Agreement (base-pair Jaccard)

| Caller | RepA vs RepB | | Caller pair | RepA | RepB |
|---|---:|---|---|---:|---:|
| Genrich | 0.80 | | MACS3–Genrich | 0.54 | 0.55 |
| MACS3 | 0.68 | | Genrich–HMMRATAC | 0.40 | 0.57 |
| HMMRATAC | 0.47 | | MACS3–HMMRATAC | 0.37 | 0.49 |

Genrich gave the most consistent calls between libraries and HMMRATAC the least. Among callers, MACS3 and Genrich agreed most closely: about 80% of Genrich peaks overlapped a MACS3 peak.

## Compute cost

Each caller ran on one CPU per library.

| Caller | Wall time | Peak memory |
|---|---:|---:|
| Genrich | ~1.5 min | ~10 GB |
| MACS3 | ~7.5 min | ~1 GB |
| HMMRATAC | ~45 min | ~2.8 GB |

## Caveats

- **The cutoffs differ.** At q < 0.01, Genrich returned no peaks. Genrich corrects for multiple testing across every base of the genome, and even its strongest peaks (p ≈ 1e-10) cannot survive that correction on hg38. We therefore used its default cutoff, p < 0.01. Some of Genrich's lead in peak count, FRiP, and replicate agreement probably comes from this looser cutoff. The cutoff also depends strongly on depth: on a 1M-pair subsample, Genrich at p < 0.01 called about 585,000 peaks, essentially one per cut site. The diagnostics are in `diag/genrich/`.
- HMMRATAC has no comparable significance cutoff. We ran the MACS3 port, not the original Java release.
- The two libraries share one BioSample, so their agreement overstates biological reproducibility.

## Conclusion

MACS3 and Genrich produced broadly similar peak sets. Genrich was faster and more consistent between libraries, but it ran at a more permissive cutoff. HMMRATAC gave finer, less reproducible segmentation at about six times the runtime of MACS3. On these data, the right choice depends on the downstream analysis rather than on any measured difference in accuracy.
