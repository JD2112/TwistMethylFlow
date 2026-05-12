#!/bin/bash

#SBATCH --job-name=NF_repl
#SBATCH --output=logs/JD_nfcore_replicate_%j.out
#SBATCH --error=logs/JD_nfcore_replicate_%j.err
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=16
#SBATCH --get-user-env
#SBATCH --export=ALL
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --partition=compute

set -e
source $(conda info --base)/etc/profile.d/conda.sh
conda activate nf25
mkdir -p logs

export SINGULARITY_BINDPATH="/data"
export APPTAINER_FLAGS="--no-privs --pid"
export NXF_SINGULARITY_CACHEDIR=/data/Jyotirmoy/singularity_cache
export APPTAINER_CACHEDIR=/data/Jyotirmoy/singularity_cache
export APPTAINER_TMPDIR=/data/Jyotirmoy/tmp

nextflow run nf-core/methylseq \
    -c conf/nfcore_methylseq_replicate.config \
    -profile singularity \
    --outdir results_nfcore_replicate
