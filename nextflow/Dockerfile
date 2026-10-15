# Pipeline image: the same pinned tools as env/environment.yml.
# Build from the project root:  docker build -f nextflow/Dockerfile -t atac-peak-callers:1.0 .
FROM mambaorg/micromamba:1.5.10
USER root
# Nextflow needs ps for task metrics.
RUN apt-get update && apt-get install -y --no-install-recommends procps && rm -rf /var/lib/apt/lists/*
USER $MAMBA_USER
COPY --chown=$MAMBA_USER:$MAMBA_USER env/environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml && micromamba clean --all --yes
ENV PATH=/opt/conda/bin:$PATH
