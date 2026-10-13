# Dataset and method-comparison research

Sources checked on 2026-10-13. This document describes input selection and the proposed comparison, not completed analysis results. The user will submit the Hellbender jobs.

## Selected public dataset

Use the two human GM12878 Omni-ATAC libraries **SRR5427887 (RepA)** and **SRR5427886 (RepB)** from **PRJNA380283 / SRP103230**, associated with Corces et al., *An improved ATAC-seq protocol reduces background and enables interrogation of frozen tissues* (2017), DOI [10.1038/nmeth.4396](https://doi.org/10.1038/nmeth.4396). Both are paired-end Illumina HiSeq 4000 libraries. The source experiment titles explicitly identify Omni-ATAC, although the historical archive's `library_strategy` field is `OTHER`. [RepA experiment XML](https://www.ebi.ac.uk/ena/browser/api/xml/SRX2717912); [RepB experiment XML](https://www.ebi.ac.uk/ena/browser/api/xml/SRX2717911).

These libraries are a practical choice because they provide the same cell line and protocol, modest download size, and a published reuse precedent: *Extensive evaluation of ATAC-seq protocols for native or formaldehyde-fixed nuclei* explicitly identifies these runs as GM12878-OmniATAC-RepA and RepB. The archive assigns both to BioSample **SAMN06660167**. We therefore call them replicate libraries, without claiming independent donors or an independently established biological-replicate design. [Protocol evaluation paper](https://doi.org/10.1186/s12864-021-08266-x).

| Sample ID | Run | Experiment | Source label | Paired spots | Bases | Compressed FASTQs, bytes |
|---|---|---|---|---:|---:|---:|
| gm12878_omni_repA | SRR5427887 | SRX2717912 | GM12878-OmniATAC-RepA | 31,084,199 | 4,724,798,248 | 2,696,661,891 |
| gm12878_omni_repB | SRR5427886 | SRX2717911 | GM12878-OmniATAC-RepB | 37,596,063 | 5,714,601,576 | 3,259,653,689 |

Total compressed FASTQ input is **5,956,315,580 bytes**, approximately **5.96 GB / 5.55 GiB**, excluding references and intermediates. Base totals divided by paired spots give 152 bases per spot, consistent with **2 × 76 bp** sequencing. Counts and file metadata were retrieved directly from ENA; see [RepA file report](https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRR5427887&result=read_run&fields=run_accession,read_count,base_count,fastq_ftp,fastq_md5,fastq_bytes&format=tsv) and [RepB file report](https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRR5427886&result=read_run&fields=run_accession,read_count,base_count,fastq_ftp,fastq_md5,fastq_bytes&format=tsv). The observed source metadata are preserved in `docs/ena_metadata.tsv`; executable input URLs and MD5 values are in `config/samples.tsv`.

| File | HTTPS download | MD5 of compressed file | Bytes |
|---|---|---|---:|
| SRR5427887_1.fastq.gz | [RepA R1](https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR542/007/SRR5427887/SRR5427887_1.fastq.gz) | `242081544172a1ace666b216e5c25d09` | 1,235,221,454 |
| SRR5427887_2.fastq.gz | [RepA R2](https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR542/007/SRR5427887/SRR5427887_2.fastq.gz) | `6419aec9bc3456d39c13b61fe0827878` | 1,461,440,437 |
| SRR5427886_1.fastq.gz | [RepB R1](https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR542/006/SRR5427886/SRR5427886_1.fastq.gz) | `6f919e22e103b122c13a29a4ea1ea157` | 1,500,352,896 |
| SRR5427886_2.fastq.gz | [RepB R2](https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR542/006/SRR5427886/SRR5427886_2.fastq.gz) | `f71a0797ddd2e3a9cce6b0a82cdc6697` | 1,759,300,793 |

The RepA R1 HTTPS endpoint was checked with HEAD and returned HTTP 200 with the expected content length. Full FASTQs have not been downloaded or validated by this research step; the workflow must verify MD5 after transfer.

## Reference and exclusion regions

Use the fixed **UCSC hg38 no-alt analysis set**, [hg38.analysisSet.fa.gz](https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/analysisSet/hg38.analysisSet.fa.gz), with compressed-file MD5 **`6d3c82e1e12b127d526395294526b9c8`** from the [UCSC checksum manifest](https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/analysisSet/md5sum.txt). UCSC describes this as the sequence equivalent of `GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz`, with UCSC identifiers and soft masking. It is a fixed legacy analysis reference, not the latest GRCh38 patch release. [UCSC analysis-set description](https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/analysisSet/).

Align against the whole analysis reference, then report peaks on canonical nuclear chromosomes (`chr1`–`chr22`, `chrX`, `chrY`). Exclude `chrM` from nuclear analyses; quantify mitochondrial reads before that removal. Derive chromosome lengths from the exact FASTA rather than mixing a different assembly's sizes file. This is a project design decision to avoid alternate-locus ambiguity and keep annotations consistently named. UCSC explains that chromosome names differ across reference providers even where main chromosome sequences match. [UCSC assembly notes](https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/).

Use the [Boyle Lab hg38 blacklist v2](https://github.com/Boyle-Lab/Blacklist) at file revision **`d0527cdea356bf57d30535b48783804ca8d21031`**: [pinned compressed BED](https://raw.githubusercontent.com/Boyle-Lab/Blacklist/d0527cdea356bf57d30535b48783804ca8d21031/lists/hg38-blacklist.v2.bed.gz). The small file was retrieved and locally hashed on 2026-10-13: SHA256 **`c92e763af17271446194991e71917ac220593a5a3d40a06667be24178ef08cf2`**, MD5 **`83fe6bf8187a64dee8079b80f75ba289`**. Cite Amemiya, Kundaje and Boyle (2019), [*The ENCODE Blacklist: Identification of Problematic Regions of the Genome*](https://doi.org/10.1038/s41598-019-45839-z).

## Literature most relevant to this comparison

| Primary source | Why it matters here |
|---|---|
| Smith et al. (2021), [*PEPATAC: an optimized pipeline for ATAC-seq data analysis with serial alignments*](https://doi.org/10.1093/nargab/lqab101) | Direct precedent: compared Fseq, Genrich, HOMER, HMMRATAC and MACS2 peak variants on a common sample and consensus peaks, using interval Jaccard similarity. Also reports FRiP, fragment profiles, TSS enrichment and runtime. This is the closest model for this project's descriptive caller comparison. |
| Tarbell and Liu (2019), [*HMMRATAC: a Hidden Markov ModeleR for ATAC-seq*](https://doi.org/10.1093/nar/gkz533) | Original HMMRATAC method and comparison against MACS2/F-Seq. Uses fragment-length information and external annotations to evaluate accessible regions. Supports preserving nucleosomal fragments and distinguishing overlap from accuracy. |
| Cheng et al. (2024), [*Review and Evaluate the Bioinformatics Analysis Strategies of ATAC-seq and CUT&Tag Data*](https://doi.org/10.1093/gpbjnl/qzae054) | Reports a GM12878 Omni-ATAC benchmark using SRX2717911 with external DNase references; compares AIAP, F-Seq, HMMRATAC, HOMER and MACS2. Its Results identify SRX2717911 but Methods also give GSM1155957, an inconsistent archival label. Use verified ENA mappings above for this project's provenance. |
| Corces et al. (2017), [Omni-ATAC protocol paper](https://doi.org/10.1038/nmeth.4396) | Primary biological dataset/protocol citation. |
| Doherty et al. (2026), [*MACS3: A Peak-calling Platform for Bulk and Single-cell Regulatory Genomics*](https://doi.org/10.1093/gpbjnl/qzag097) | Current MACS3 software citation; the project is using a modern implementation rather than reproducing old MACS2 binaries. Published online 2026-09-16. |

Genrich's primary implementation source is its [official repository and manual](https://github.com/jsh58/Genrich); do not invent a peer-reviewed Genrich paper.

## Comparison design and interpretation

The proposed three methods are **MACS3 callpeak in paired-end fragment mode**, **Genrich in ATAC mode**, and **HMMRATAC implemented by MACS3**. The third label must include the implementation: the current Python/Cython port is not the original Java software used in the 2019 study. The [MACS3 HMMRATAC documentation](https://macs3-project.github.io/MACS/docs/hmmratac.html) describes its fragment-length model and output. [Original HMMRATAC requirements](https://github.com/LiuLabUB/HMMRATAC) explicitly require paired-end data and favor retention of the full fragment-length distribution.

Project recommendations:

1. Apply one common reference, trimming, alignment, duplicate and mapping-quality policy to both libraries. Preserve pairs and nucleosomal fragments. Keep an unshifted paired-end BAM for fragment-based methods. Feed Genrich query-name-sorted alignments and let its ATAC mode handle cut-site interpretation; do not shift an already shifted input again. Genrich requires query-name ordering. [Genrich manual](https://github.com/jsh58/Genrich).
2. Compare each caller within each library before pooling. Use library concordance as reproducibility evidence, not as independent donor replication. Keep per-library outputs available.
3. Report peak count, total genomic coverage, width distribution, base-pair Jaccard, directional peak-overlap fractions, fragment-based FRiP, wall time and maximum resident memory. Specify FRiP's denominator as the same eligible, deduplicated nuclear fragments for every caller; count a pair once.
4. Treat high overlap as agreement, not proof of truth. Peak count and FRiP increase with permissive thresholds and wider regions. HMMRATAC's fold-change/model settings do not share the same false-discovery interpretation as MACS3/Genrich q-values. Record exact commands and versions; retain default-threshold results as descriptive comparisons.
5. For stronger evaluation, add a separately accessioned, hg38-compatible GM12878 DNase or regulatory annotation set, report both reference recovery and fraction of predictions supported, and distinguish these proxies from sensitivity/specificity against a complete truth set. No independent truth set has yet been pinned in this project.
6. A small random, pair-preserving subset is useful for workflow testing. Label it as a pilot and keep it separate from full-depth conclusions. Avoid interpreting a tiny or chromosome-only pilot as a fair whole-genome HMMRATAC benchmark.

These are design recommendations informed by the sources, not claims that one caller has already performed best on these inputs. The dashboard must show unrun or missing values as unavailable, never as zero, and clearly label synthetic demonstration data if present.

## Hellbender constraints verified against the requested wiki

The [official Hellbender wiki](https://docs.itrss.umsystem.edu/pub/hpc/hellbender) is authoritative for cluster setup:

- SSH login: `hellbender-login.rnet.missouri.edu`; use the campus account. Off-campus access requires registered public-key authentication or VPN.
- CPU `general` jobs allow up to two days. `interactive` permits four hours. `requeue` can be preempted. Query live partition limits before submission.
- Compute and software installation belong in allocated jobs, not on login nodes.
- Move data through Globus or the data-transfer node, `hellbender-dtn-p1.rnet.missouri.edu`; the wiki explicitly prohibits data moves on the login node. It does not publish a general-purpose DTN partition name: do not invent one.
- Default storage: 50 GB home, 500 GB at `/home/$USER/data`; `/local/scratch` is node-local. Use data storage for inputs/environments and copy final outputs to persistent storage.
- Official Conda entry point: `module load miniconda3`. Create environments in a compute job and keep package caches outside the small home allocation.
- Open OnDemand includes RStudio Server; use an allocated session for Shiny.

User-specific account/QOS, project path and module availability must be checked in the actual account. Job submission remains with the user; this document does not assert that analysis jobs have run.
