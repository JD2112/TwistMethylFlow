#!/bin/bash
# -----------------------------------------------------------------------------
# milou clinical-grade bioinformatics pipeline clean script
# -----------------------------------------------------------------------------
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PIPELINE_DIR}/backup"
LOCAL_BACKUPS_PARENT="$(cd "${PIPELINE_DIR}/.." && pwd)"
SAFE_BACKUP_DEST="${LOCAL_BACKUPS_PARENT}/milou_backups_local"

echo "========================================================================="
echo "        🧼 milou Workspace Hardening & Cleaning Utility"
echo "========================================================================="

# 1. Protect research and draft assets by moving them outside the repo
if [ -d "${BACKUP_DIR}" ]; then
    echo "📦 Moving large local backups & draft assets out of active repo..."
    echo "   Source: ${BACKUP_DIR}"
    echo "   Destination: ${SAFE_BACKUP_DEST}"
    mkdir -p "${SAFE_BACKUP_DEST}"
    rsync -a --remove-source-files "${BACKUP_DIR}/" "${SAFE_BACKUP_DEST}/"
    find "${BACKUP_DIR}" -type d -empty -delete 2>/dev/null || true
    echo "   ✅ Backup assets safely relocated."
else
    echo "   ℹ️ No 'backup/' folder found. Skipping relocation."
fi

# 2. Safely clean nextflow intermediate folders and caches
echo "🧹 Removing Nextflow runtime files and caches..."
declare -a JUNK_FOLDERS=(
    "${PIPELINE_DIR}/.nextflow"
    "${PIPELINE_DIR}/.nextflow_tmp"
    "${PIPELINE_DIR}/.quarto"
    "${PIPELINE_DIR}/.venv"
    "${PIPELINE_DIR}/work"
    "${PIPELINE_DIR}/bugs"
    "${PIPELINE_DIR}/results_260510"
    "${PIPELINE_DIR}/results_260518"
)

for folder in "${JUNK_FOLDERS[@]}"; do
    if [ -d "${folder}" ]; then
        echo "   - Deleting: $(basename "${folder}")"
        rm -rf "${folder}"
    fi
done

# Remove recurrent macOS metadata junk files
echo "🗑️ Removing recursively scattered .DS_Store files..."
find "${PIPELINE_DIR}" -name ".DS_Store" -delete 2>/dev/null || true

# 3. Compile clean distribution archive
echo "📦 Packaging milou pipeline source for Slurm transfer..."
DIST_ARCHIVE="${LOCAL_BACKUPS_PARENT}/milou_clean.tar.gz"

tar --exclude-vcs \
    --exclude='*tar.gz' \
    --exclude='*zip' \
    -czf "${DIST_ARCHIVE}" -C "${PIPELINE_DIR}" .

echo "========================================================================="
echo "        🎉 Clean-Up and Deployment Packaging Complete!"
echo "========================================================================="
echo "   🟢 Clean repository size: $(du -sh "${PIPELINE_DIR}" | awk '{print $1}')"
echo "   🎁 Distribution tarball: ${DIST_ARCHIVE}"
echo "   📦 Distribution size: $(du -sh "${DIST_ARCHIVE}" | awk '{print $1}')"
echo "========================================================================="
echo "   To copy to your Slurm server, run:"
echo "     scp ${DIST_ARCHIVE} user@your-server-ip:/path/to/destination/"
echo "========================================================================="
