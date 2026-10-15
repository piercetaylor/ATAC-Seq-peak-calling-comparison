#!/usr/bin/env nextflow
// Portable version of the SLURM workflow in slurm/. Same tools, versions,
// parameters, and Python helpers; runs locally, on SLURM, or on AWS Batch.
nextflow.enable.dsl = 2

process PREPARE_REFERENCE {
    label 'reference'
    publishDir "${params.outdir}", mode: 'copy'

    input:
    path fasta_gz
    path blacklist_gz
    path scripts

    output:
    path 'reference', emit: dir

    script:
    """
    echo "${params.genome_md5}  ${fasta_gz}" | md5sum -c -
    echo "${params.blacklist_sha256}  ${blacklist_gz}" | sha256sum -c -
    mkdir reference
    gzip -dc ${fasta_gz} > reference/genome.fa
    gzip -dc ${blacklist_gz} > reference/blacklist.bed
    samtools faidx reference/genome.fa
    cut -f1,2 reference/genome.fa.fai > reference/chrom.sizes
    awk '\$1 ~ /^chr([1-9]|1[0-9]|2[0-2]|X|Y)\$/ {print \$1 "\\t" \$2}' reference/chrom.sizes > reference/canonical.sizes
    [[ \$(wc -l < reference/canonical.sizes) -eq 24 ]] || { echo "Reference must contain chr1-22, chrX, chrY" >&2; exit 1; }
    awk '\$1 !~ /^chr([1-9]|1[0-9]|2[0-2]|X|Y)\$/ {print \$1}' reference/chrom.sizes | paste -sd, - > reference/excluded_contigs.txt
    PYTHONPATH=${scripts} python ${scripts}/preflight.py --reference-dir reference --reference-only
    bowtie2-build --threads ${task.cpus} reference/genome.fa reference/genome
    rm reference/genome.fa
    sha256sum ${fasta_gz} reference/blacklist.bed reference/chrom.sizes > reference/reference_sha256.txt
    """

    stub:
    """
    mkdir reference
    touch reference/genome.1.bt2 reference/blacklist.bed reference/chrom.sizes reference/excluded_contigs.txt
    """
}

process PREPROCESS {
    tag "${sample}"
    label 'preprocess'
    publishDir "${params.outdir}/preprocessing/${sample}", mode: 'copy',
        saveAs: { it.startsWith("${sample}.") ? it.substring(sample.size() + 1) : it }

    input:
    tuple val(sample), path(r1), path(r2), val(md5_1), val(md5_2)
    path reference
    path scripts

    output:
    tuple val(sample), path('filtered.bam'), path('filtered.bam.bai'), path('filtered.namesort.bam'), emit: bams
    tuple val(sample), path("${sample}.qc.json"), path("${sample}.fragments.bed"), emit: qc
    path '*.{json,html,log,txt}'

    script:
    def sort_threads = Math.max(task.cpus - 1, 1)
    """
    printf '%s  %s\\n%s  %s\\n' "${md5_1}" "${r1}" "${md5_2}" "${r2}" | md5sum -c -
    fastp --in1 ${r1} --in2 ${r2} --out1 trimmed_R1.fastq.gz --out2 trimmed_R2.fastq.gz \\
      --detect_adapter_for_pe --thread ${task.cpus} --length_required 25 --json fastp.json --html fastp.html > fastp.log 2>&1
    bowtie2 --very-sensitive --no-mixed --no-discordant -X ${params.max_insert} --seed ${params.seed} -p ${sort_threads} \\
      -x ${reference}/genome -1 trimmed_R1.fastq.gz -2 trimmed_R2.fastq.gz 2> bowtie2.log \\
      | samtools sort -n -m 2G -o name.bam -
    samtools fixmate -m name.bam fixmate.bam
    samtools sort -@ ${sort_threads} -m 2G -o coordinate.bam fixmate.bam
    samtools markdup -s coordinate.bam marked.bam 2> markdup.log
    samtools sort -n -@ ${sort_threads} -m 2G -o marked.namesort.bam marked.bam
    samtools view -h marked.namesort.bam \\
      | PYTHONPATH=${scripts} python ${scripts}/filter_pairs.py --blacklist ${reference}/blacklist.bed --mapq ${params.mapq} \\
          --sample ${sample} --fragments ${sample}.fragments.bed --qc ${sample}.qc.json --fastp-json fastp.json \\
      | samtools view -b -o filtered.namesort.bam -
    samtools sort -@ ${sort_threads} -m 2G -o filtered.bam filtered.namesort.bam
    samtools index filtered.bam
    samtools quickcheck -v filtered.bam filtered.namesort.bam
    samtools flagstat filtered.bam > filtered.flagstat.txt
    rm name.bam fixmate.bam coordinate.bam marked.bam marked.namesort.bam trimmed_R1.fastq.gz trimmed_R2.fastq.gz
    """

    stub:
    """
    touch filtered.bam filtered.bam.bai filtered.namesort.bam ${sample}.fragments.bed fastp.json
    echo '{}' > ${sample}.qc.json
    """
}

process CALL_PEAKS {
    tag "${sample} ${caller}"
    label 'caller'
    // Observed peaks: MACS3 ~1 GB / 8 min, Genrich ~10 GB / 2 min, HMMRATAC ~3 GB / 50 min per library.
    memory { [macs3: 8.GB, genrich: 16.GB, hmmratac: 8.GB][caller] * task.attempt }
    time { [macs3: 2.h, genrich: 1.h, hmmratac: 6.h][caller] * task.attempt }
    publishDir "${params.outdir}/peaks/${sample}", mode: 'copy', saveAs: { it.substring(sample.size() + 1) }

    input:
    tuple val(sample), path(bam), path(bai), path(namesort_bam), val(caller)
    path reference
    path scripts

    output:
    tuple val(sample), val(caller), path("${sample}.${caller}"), emit: calls

    script:
    def caller_label = [macs3: 'MACS3', genrich: 'Genrich', hmmratac: 'HMMRATAC'][caller]
    def command = [
        macs3:    "macs3 callpeak -t ${bam} -f BAMPE -g ${params.effective_genome_size} -q ${params.qvalue} --keep-dup all -n ${sample} --outdir native",
        genrich:  "Genrich -t ${namesort_bam} -o native/${sample}.narrowPeak -j -p ${params.genrich_pvalue} -e \"\$(cat ${reference}/excluded_contigs.txt)\" -v",
        hmmratac: "macs3 hmmratac -i ${bam} -f BAMPE -n ${sample} --outdir native --randomSeed ${params.seed}"
    ][caller]
    def native_peaks = [macs3: "native/${sample}_peaks.narrowPeak", genrich: "native/${sample}.narrowPeak",
                  hmmratac: "native/${sample}_accessible_regions.narrowPeak"][caller]
    """
    out=${sample}.${caller}
    mkdir -p native "\$out"
    lscpu > "\$out/cpu.txt"
    cat > "\$out/commands.sh" <<'CMD'
${command}
CMD
    # Single-threaded numerics keep caller timings comparable.
    export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
    env time -q -f '%e\\t%M\\t%x' -o time.raw.tsv bash "\$out/commands.sh" > "\$out/caller.log" 2>&1
    printf 'sample\\tcaller\\telapsed_seconds\\tmax_rss_kb\\texit_status\\n${sample}\\t${caller_label}\\t' > "\$out/runtime.tsv"
    cat time.raw.tsv >> "\$out/runtime.tsv"
    PYTHONPATH=${scripts} python ${scripts}/normalize_peaks.py --input ${native_peaks} --output "\$out/peaks.bed" \\
      --sizes ${reference}/chrom.sizes --blacklist ${reference}/blacklist.bed
    [[ -s "\$out/peaks.bed" ]] || { echo "${caller_label} produced zero peaks for ${sample}; see \$out/caller.log" >&2; exit 1; }
    mv native "\$out/native"
    """

    stub:
    """
    mkdir -p ${sample}.${caller}
    printf 'chr1\\t100\\t200\\n' > ${sample}.${caller}/peaks.bed
    printf 'sample\\tcaller\\telapsed_seconds\\tmax_rss_kb\\texit_status\\n${sample}\\t${caller}\\t1\\t1\\t0\\n' > ${sample}.${caller}/runtime.tsv
    """
}

process SUMMARIZE {
    label 'summarize'
    publishDir "${params.outdir}", mode: 'copy'

    input:
    path qc_files, stageAs: 'qc/*'
    path call_dirs, stageAs: 'calls/*'
    path project_json
    path samples_tsv
    path scripts

    output:
    path 'dashboard'

    script:
    """
    # Rebuild the results layout that summarize.py validates; Nextflow has already
    # guaranteed that every upstream task succeeded.
    mkdir -p project/config results
    cp ${project_json} project/config/project.json
    cp ${samples_tsv} project/config/samples.tsv
    for qc in qc/*.qc.json; do
      sample=\$(basename "\$qc" .qc.json)
      mkdir -p "results/preprocessing/\$sample"
      ln -s "\$PWD/\$qc" "results/preprocessing/\$sample/qc.json"
      ln -s "\$PWD/qc/\$sample.fragments.bed" "results/preprocessing/\$sample/fragments.bed"
      touch "results/preprocessing/\$sample/.complete"
    done
    for call in calls/*; do
      name=\$(basename "\$call"); sample=\${name%.*}; caller=\${name##*.}
      mkdir -p "results/peaks/\$sample/\$caller"
      ln -s "\$PWD/\$call/peaks.bed" "\$PWD/\$call/runtime.tsv" "results/peaks/\$sample/\$caller/"
      touch "results/peaks/\$sample/\$caller/.complete"
    done
    python ${scripts}/summarize.py --project-root project --results-dir results --run-type ${params.run_type}
    mv results/dashboard dashboard
    """

    stub:
    """
    mkdir dashboard && echo '{"status": "complete"}' > dashboard/status.json
    """
}

workflow {
    def scripts = file("${projectDir}/../scripts", checkIfExists: true)
    def samples_tsv = file(params.samples, checkIfExists: true)

    samples = Channel.fromPath(samples_tsv)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            if (!(row.sample ==~ /[A-Za-z0-9][A-Za-z0-9_-]*/)) error "Invalid sample name: ${row.sample}"
            tuple(row.sample, file(row.fastq_1), file(row.fastq_2), row.md5_1, row.md5_2)
        }

    if (params.reference_dir) {
        reference = Channel.value(file(params.reference_dir, checkIfExists: true))
    } else {
        PREPARE_REFERENCE(file(params.genome_fasta), file(params.blacklist), scripts)
        reference = PREPARE_REFERENCE.out.dir
    }

    PREPROCESS(samples, reference, scripts)
    CALL_PEAKS(PREPROCESS.out.bams.combine(Channel.of('macs3', 'genrich', 'hmmratac')), reference, scripts)

    qc_files = PREPROCESS.out.qc.flatMap { sample, qc, fragments -> [qc, fragments] }.collect()
    call_dirs = CALL_PEAKS.out.calls.map { sample, caller, dir -> dir }.collect()
    SUMMARIZE(qc_files, call_dirs, file("${projectDir}/../config/project.json"), samples_tsv, scripts)
}
