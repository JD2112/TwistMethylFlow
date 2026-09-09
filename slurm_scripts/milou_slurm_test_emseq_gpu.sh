#!/bin/bash

#SBATCH --job-name=milou_emseq_gpu
#SBATCH --output=logs/JD_milou_test_emseq_gpu_%j.out
#SBATCH --error=logs/JD_milou_test_emseq_gpu_%j.err
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=16
#SBATCH --get-user-env
#SBATCH --export=ALL
#SBATCH --ntasks=1
#SBATCH --mem=240G
#SBATCH --partition=compute
#SBATCH --gres=gpu:l40s:3

set -e
source $(conda info --base)/etc/profile.d/conda.sh
conda activate nf25
mkdir -p logs

export SINGULARITY_BINDPATH="/data"
export APPTAINER_FLAGS="--no-privs --pid"
export NXF_SINGULARITY_CACHEDIR=/data/${USER}/singularity_cache
export APPTAINER_CACHEDIR=/data/${USER}/singularity_cache
export APPTAINER_TMPDIR=/data/${USER}/tmp
export TMPDIR="/data/${USER}/tmp"
export TMP="/data/${USER}/tmp"
export TEMP="/data/${USER}/tmp"
export NXF_TEMP="/data/${USER}/tmp"
export APPTAINERENV_TMPDIR="/data/${USER}/tmp"
export APPTAINERENV_TMP="/data/${USER}/tmp"
export APPTAINERENV_TEMP="/data/${USER}/tmp"
export SINGULARITYENV_TMPDIR="/data/${USER}/tmp"
export SINGULARITYENV_TMP="/data/${USER}/tmp"
export SINGULARITYENV_TEMP="/data/${USER}/tmp"
mkdir -p /data/${USER}/tmp

nextflow run main.nf \
    -profile test_emseq_gpu,gpu,singularity \
    --outdir results_test_emseq_gpu -resume
