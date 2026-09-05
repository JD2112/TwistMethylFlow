#!/bin/bash

#SBATCH --job-name=JD_mf260504
#SBATCH --output=logs/JD_mf_twist_minimal_gpu_%j.out
#SBATCH --error=logs/JD_mf_twist_minimal_gpu_%j.err
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=16
#SBATCH --get-user-env
#SBATCH --export=ALL
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --partition=compute
#SBATCH --gres=gpu:l40s:3  # Use 1, 2, or 3 available GPUs


set -e

# 1. Load Conda (ensure the path to your conda.sh is correct)
# Usually found at ~/miniconda3/etc/profile.d/conda.sh or /opt/anaconda/etc/profile.d/conda.sh
source $(conda info --base)/etc/profile.d/conda.sh
conda activate nf25

# 3. Create a logs directory if it doesn't exist
mkdir -p logs

# 2. Force Apptainer to work in "unprivileged" mode (Fixes 'Operation not permitted')
export APPTAINER_BINDPATH="/data"
export SINGULARITY_BINDPATH="/data"
# This flag is the most important for single-node Slurm setups:
export APPTAINER_FLAGS="--no-privs --pid"

# 3. Define Cache Directories
export NXF_SINGULARITY_CACHEDIR=/data/${USER}/singularity_cache
export APPTAINER_CACHEDIR=/data/${USER}/singularity_cache
export APPTAINER_TMPDIR=/data/${USER}/tmp
mkdir -p $NXF_SINGULARITY_CACHEDIR $APPTAINER_TMPDIR

nextflow run main.nf \
    -profile twist_minimal_gpu,gpu,singularity \
    --outdir results_twist_minimal_gpu