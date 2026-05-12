#!/bin/bash

#SBATCH --job-name=MF_full_gpu
#SBATCH --output=logs/JD_mf_twist_full_gpu_%j.out
#SBATCH --error=logs/JD_mf_twist_full_gpu_%j.err
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=16
#SBATCH --get-user-env
#SBATCH --export=ALL
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --partition=compute
#SBATCH --gres=gpu:l40s:3

set -e
source $(conda info --base)/etc/profile.d/conda.sh
conda activate nf25
mkdir -p logs

export SINGULARITY_BINDPATH="/data"
export APPTAINER_FLAGS="--no-privs --pid"
export NXF_SINGULARITY_CACHEDIR=/data/Jyotirmoy/singularity_cache
export APPTAINER_CACHEDIR=/data/Jyotirmoy/singularity_cache
export APPTAINER_TMPDIR=/data/Jyotirmoy/tmp

nextflow run main.nf \
    -profile twist_full_gpu,gpu,singularity \
    --outdir results_twist_full_gpu
