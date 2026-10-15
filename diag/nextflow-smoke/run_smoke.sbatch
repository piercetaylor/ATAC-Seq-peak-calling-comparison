#!/usr/bin/env bash
#SBATCH --job-name=nf-smoke
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=03:00:00
#SBATCH --output=diag/nextflow-smoke/smoke-%j.log
set -euo pipefail
P=/cluster/VAST/mendozacozatld-lab/PierceTaylor/ATAC_Seq_Project; T=$P/diag/nextflow-smoke
cd $T
printf 'sample\trun\treplicate\tfastq_1\tfastq_2\tmd5_1\tmd5_2\n' > samples_smoke.tsv
tail -n +2 $P/config/samples.tsv | while IFS=$'\t' read -r sample run rep f1 f2 m1 m2; do
  for m in 1 2; do { zcat $P/data/fastq/${sample}_R$m.fastq.gz || true; } | head -n 4000000 | gzip -1 > fastq/${sample}_R$m.fastq.gz; done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $sample $run $rep $T/fastq/${sample}_R1.fastq.gz $T/fastq/${sample}_R2.fastq.gz \
    $(md5sum < fastq/${sample}_R1.fastq.gz | cut -d' ' -f1) $(md5sum < fastq/${sample}_R2.fastq.gz | cut -d' ' -f1) >> samples_smoke.tsv
done
source /usr/share/lmod/lmod/init/bash
module load jdk/20_S nextflow/25.04.6.5954 "miniconda3/v26.7.1-1_py314"
export JAVA_CMD=$JAVA_HOME/bin/java NXF_ANSI_LOG=false NXF_HOME=$T/.nxf
nextflow run $P/nextflow/main.nf -profile conda,test --conda_env $P/env/runtime \
  --samples samples_smoke.tsv --reference_dir $P/results/reference --outdir $T/out \
  --max_cpus 8 --max_memory 44.GB
