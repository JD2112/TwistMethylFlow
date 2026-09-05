#!/bin/bash

#SBATCH --job-name=milou_bisulfite_cpu
#SBATCH --output=logs/JD_milou_test_bisulfite_cpu_%j.out
#SBATCH --error=logs/JD_milou_test_bisulfite_cpu_%j.err
#SBATCH --time=120:00:00
#SBATCH --cpus-per-task=192
#SBATCH --get-user-env
#SBATCH --export=ALL
#SBATCH --ntasks=1
#SBATCH --mem=800G
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
    -profile test_bisulfite_cpu,singularity \
    --outdir results_test_bisulfite_cpu
