# Optional: copy to config/local.sh to override config/project.sh.
# The defaults keep data, results, and the conda environment inside the project
# directory, which on Hellbender is lab VAST storage:
#   /cluster/VAST/mendozacozatld-lab/PierceTaylor/ATAC_Seq_Project
# Avoid the small home directory for FASTQ, BAMs, and indexes.
# RESULTS_DIR must be a fresh path for every pipeline run, e.g.:
# RESULTS_DIR="$PROJECT_ROOT/results_run2"
ACCOUNT="general"
PARTITION="general"
QOS="normal"
ARRAY_CONCURRENCY=2
# Hellbender's default miniconda3 module is 4.10.3; this newer one uses libmamba.
# CONDA_MODULE="miniconda3/v26.7.1-1_py314"
# Or bypass modules entirely with a conda activation script:
# CONDA_SH="/path/to/miniconda/etc/profile.d/conda.sh"
