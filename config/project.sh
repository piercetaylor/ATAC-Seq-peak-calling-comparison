# Source from scripts/common.sh. Override paths/resources in config/local.sh.
DATA_DIR="${DATA_DIR:-$PROJECT_ROOT/data}"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
ENV_PREFIX="${ENV_PREFIX:-$PROJECT_ROOT/env/runtime}"
SAMPLES_TSV="${SAMPLES_TSV:-$PROJECT_ROOT/config/samples.tsv}"
ACCOUNT="${ACCOUNT:-general}"
PARTITION="${PARTITION:-general}"
QOS="${QOS:-normal}"
ARRAY_CONCURRENCY="${ARRAY_CONCURRENCY:-2}"
# Hellbender default miniconda3 (4.10.3) predates libmamba; pin the current module.
CONDA_MODULE="${CONDA_MODULE:-miniconda3/v26.7.1-1_py314}"
MAPQ="${MAPQ:-30}"
MAX_INSERT="${MAX_INSERT:-2000}"
QVALUE="${QVALUE:-0.01}"
SEED="${SEED:-42}"
# MACS3 'hs' shortcut is 2,913,022,398 effective bases (documented by MACS3).
EFFECTIVE_GENOME_SIZE="${EFFECTIVE_GENOME_SIZE:-2913022398}"
REFERENCE_URL='https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/analysisSet/hg38.analysisSet.fa.gz'
REFERENCE_MD5='6d3c82e1e12b127d526395294526b9c8'
BLACKLIST_URL='https://raw.githubusercontent.com/Boyle-Lab/Blacklist/d0527cdea356bf57d30535b48783804ca8d21031/lists/hg38-blacklist.v2.bed.gz'
BLACKLIST_SHA256='c92e763af17271446194991e71917ac220593a5a3d40a06667be24178ef08cf2'
