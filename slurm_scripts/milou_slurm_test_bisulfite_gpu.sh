#!/bin/bash

#SBATCH --job-name=milou_bisulfite_gpu
#SBATCH --output=logs/JD_milou_test_bisulfite_gpu_%j.out
#SBATCH --error=logs/JD_milou_test_bisulfite_gpu_%j.err
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=16
#SBATCH --get-user-env
#SBATCH --export=ALL
#SBATCH --ntasks=1
#SBATCH --mem=200G
#SBATCH --partition=compute
#SBATCH --gres=gpu:l40s:3

set -e
# Unload broken Apptainer 1.5.3 module to ensure native Singularity-CE 4.1.1 is used
module unload apptainer/1.5.3 2>/dev/null || true
module unload apptainer 2>/dev/null || true

source $(conda info --base)/etc/profile.d/conda.sh
conda activate nf25
mkdir -p logs

echo "Container runtime in use: $(singularity --version)"

export SINGULARITY_BINDPATH="/data"
export NXF_SINGULARITY_CACHEDIR=/data/${USER}/singularity_cache
export TMPDIR="/data/${USER}/tmp"
export TMP="/data/${USER}/tmp"
export TEMP="/data/${USER}/tmp"
export NXF_TEMP="/data/${USER}/tmp"
export SINGULARITYENV_TMPDIR="/data/${USER}/tmp"
export SINGULARITYENV_TMP="/data/${USER}/tmp"
export SINGULARITYENV_TEMP="/data/${USER}/tmp"
mkdir -p /data/${USER}/tmp

nextflow run main.nf \
    -profile test_bisulfite_gpu,gpu,singularity \
    --outdir results_test_bisulfite_gpu \
    --max_memory 200.GB \
    -c <(echo "process { withName: '.*DSS_ANALYSIS.*' { ext.args = '--smoothing FALSE'; memory = '150 GB'; cpus = 2 } }") \
    -resume
