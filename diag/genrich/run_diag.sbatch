#!/usr/bin/env bash
#SBATCH --job-name=genrich-diag
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=diag/genrich/diag-%j.log
set -uo pipefail
cd /cluster/VAST/mendozacozatld-lab/PierceTaylor/ATAC_Seq_Project
G=env/runtime/bin/Genrich
BAM=results/preprocessing/gm12878_omni_repA/filtered.namesort.bam
EX=$(cat results/reference/excluded_contigs.txt)
O=diag/genrich
run() { local name=$1; shift; echo "=== $name: $*"; $G -t "$BAM" -o "$O/$name.narrowPeak" -j "$@" -v > "$O/$name.log" 2>&1; echo "rc=$?"; grep -E 'Peaks identified|Significance|Min. AUC' "$O/$name.log"; }
run p01      -p 0.01 -e "$EX"
run q05      -q 0.05 -e "$EX"
run q01_noex -q 0.01
run q01_a0   -q 0.01 -a 0 -e "$EX"
