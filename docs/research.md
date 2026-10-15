# Data sources and background

Sources checked on 2026-10-13.

## Dataset

The data are two GM12878 Omni-ATAC libraries from PRJNA380283 / SRP103230 (Corces et al., 2017, [doi:10.1038/nmeth.4396](https://doi.org/10.1038/nmeth.4396)). Both were sequenced paired-end, 2 × 76 bp, on a HiSeq 4000. They share BioSample SAMN06660167, so we treat them as technical replicates. Zhang et al. (2022, [doi:10.1186/s12864-021-08266-x](https://doi.org/10.1186/s12864-021-08266-x)) reused the same two runs.

| Sample | Run | Experiment | Read pairs | Compressed FASTQ |
|---|---|---|---:|---:|
| gm12878_omni_repA | SRR5427887 | SRX2717912 | 31,084,199 | 2.70 GB |
| gm12878_omni_repB | SRR5427886 | SRX2717911 | 37,596,063 | 3.26 GB |

FASTQ URLs and ENA MD5s are in `config/samples.tsv`, and the full ENA metadata is in `ena_metadata.tsv`.

## Reference

- **Genome:** UCSC hg38 no-alt analysis set ([hg38.analysisSet.fa.gz](https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/analysisSet/hg38.analysisSet.fa.gz), MD5 `6d3c82e1e12b127d526395294526b9c8`). Reads were aligned to the full set. Peaks were reported only on chr1–22, X, and Y.
- **Blacklist:** ENCODE hg38 blacklist v2 (Amemiya et al., 2019, [doi:10.1038/s41598-019-45839-z](https://doi.org/10.1038/s41598-019-45839-z)), pinned to commit `d0527cd` of [Boyle-Lab/Blacklist](https://github.com/Boyle-Lab/Blacklist). SHA256 `c92e763a…08cf2`.

## Related work

| Source | Relevance |
|---|---|
| Smith et al. (2021), [PEPATAC](https://doi.org/10.1093/nargab/lqab101) | Closest precedent. Compared Genrich, HMMRATAC, MACS2, and others on one sample using interval Jaccard, FRiP, and runtime |
| Tarbell & Liu (2019), [HMMRATAC](https://doi.org/10.1093/nar/gkz533) | Original HMMRATAC method and comparison with MACS2 |
| Cheng et al. (2024), [ATAC-seq strategies review](https://doi.org/10.1093/gpbjnl/qzae054) | Benchmarked callers on SRX2717911 against DNase references. Its Methods section mislabels the sample as GSM1155957 |
| Doherty et al. (2026), [MACS3](https://doi.org/10.1093/gpbjnl/qzag097) | Current MACS3 citation |

Genrich has no peer-reviewed paper; cite its [repository](https://github.com/jsh58/Genrich).

## Hellbender notes

These notes follow the [Hellbender wiki](https://docs.itrss.umsystem.edu/pub/hpc/hellbender).

- Run compute and software installs in SLURM jobs, never on the login node.
- The `general` partition allows jobs of up to two days.
- Large transfers go through Globus or the data-transfer node `hellbender-dtn-p1.rnet.missouri.edu`.
- Conda is provided through `module load miniconda3`.
- Open OnDemand provides RStudio for running the Shiny app.
