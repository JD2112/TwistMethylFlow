#!/bin/bash

#SBATCH --job-name=MF_repl_cpu
#SBATCH --output=logs/JD_mf_twist_replicate_article_cpu_%j.out
#SBATCH --error=logs/JD_mf_twist_replicate_article_cpu_%j.err
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
export NXF_SINGULARITY_CACHEDIR=/data/${USER}/singularity_cache
export APPTAINER_CACHEDIR=/data/${USER}/singularity_cache
export APPTAINER_TMPDIR=/data/${USER}/tmp

nextflow run main.nf \
    -profile twist_replicate_article_cpu,singularity \
    --outdir results_twist_replicate_article_cpu
