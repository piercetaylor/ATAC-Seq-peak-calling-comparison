# Copy to config/local.sh on Hellbender; use your allocated project storage.
# Avoid putting FASTQ, temporary BAMs, and indexes in the small home directory.
# Put the project under $HOME/data/ATAC_Seq_Project, or change these paths.
DATA_DIR="$HOME/data/ATAC_Seq_Project/data"
RESULTS_DIR="$HOME/data/ATAC_Seq_Project/results"
ENV_PREFIX="$HOME/data/ATAC_Seq_Project/env/runtime"
ACCOUNT="general"
PARTITION="general"
QOS="normal"
ARRAY_CONCURRENCY=2
# Optional: set if conda is not already available after loading a module.
# CONDA_SH="/path/to/miniconda/etc/profile.d/conda.sh"
