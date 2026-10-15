# Methods

## Data

We analyzed two paired-end (2 × 76 bp) GM12878 Omni-ATAC libraries, SRR5427887 (RepA) and SRR5427886 (RepB), from PRJNA380283 (Corces et al., 2017). They share one BioSample and are treated as technical replicates. Accessions and checksums are listed in [research.md](research.md).

## Preprocessing

- **Trimming.** fastp 0.24.0 trimmed adapters, keeping reads of at least 25 bp.
- **Alignment.** Bowtie2 2.5.4 aligned reads to the UCSC hg38 no-alt analysis set (`--very-sensitive --no-mixed --no-discordant -X 2000`, seed 42).
- **Duplicates.** samtools 1.21 marked duplicates (`fixmate -m`, then `markdup`).
- **Pair filtering.** A pair was kept only if both primary mates:
  - mapped as a proper pair to the same chromosome among chr1–22, X, and Y;
  - each had MAPQ of at least 30;
  - were not flagged as duplicate or QC-fail.

  The fragment also had to lie outside the ENCODE hg38 blacklist v2.
- **What was kept.** Nucleosome-length fragments were retained. No Tn5 shift was applied to the shared BAM.

## Peak calling

All three callers received the same filtered pairs.

- **MACS3 3.0.3** `callpeak`: BAMPE mode, q < 0.01, genome size 2,913,022,398, `--keep-dup all`.
- **Genrich 0.6.1**: queryname-sorted BAM, ATAC mode (`-j`), p < 0.01, with non-canonical contigs excluded. Genrich's q-values are adjusted across every base in the genome, and no position reached q < 0.05, so q cutoffs produced zero peaks. We used Genrich's default p-value cutoff instead.
- **HMMRATAC** (`macs3 hmmratac`, 3.0.3): BAMPE mode, seed 42, default model settings. This is the maintained Python port, not the original Java tool.

These cutoffs are not equivalent statistical operating points.

## Metrics

Final peaks were restricted to canonical nuclear chromosomes outside the blacklist.

- **Counts and widths** use individual peaks.
- **Covered bases and Jaccard** use the merged union of each peak set.
- **Peak overlap** requires at least 1 bp in common.
- **FRiP** is the fraction of retained fragments whose span overlaps any peak. Each fragment is counted once.
- **Replicate agreement** compares RepA and RepB within each caller.
- **Runtime and memory** were measured with GNU time, one SLURM job per caller and library, single-threaded.

We did not run IDR, TSS enrichment, motif analysis, or comparisons to an external reference. The results describe how the callers behave; they do not measure accuracy.

## References

[MACS3 callpeak](https://macs3-project.github.io/MACS/docs/callpeak.html) · [MACS3 HMMRATAC](https://macs3-project.github.io/MACS/docs/hmmratac.html) · [Genrich](https://github.com/jsh58/Genrich)
