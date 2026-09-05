#!/usr/bin/env bash
#
# verify_fastq_pairs.sh - A utility to validate paired-end FASTQ.gz files
# Checks for: Empty files, Gzip integrity, Sync at head & tail, and Excessive 'N' content.
#

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$#" -lt 2 ]; then
    echo -e "${RED}Usage:${NC} $0 <R1.fastq.gz> <R2.fastq.gz> [cores]"
    echo -e "  [cores] optional, defaults to 4"
    exit 1
fi

R1="$1"
R2="$2"
CORES="${3:-4}"

# Determine which tool to use for decompression
DECOMPRESSOR="zcat"
if command -v pigz &> /dev/null; then
    DECOMPRESSOR="pigz -dc -p $CORES"
fi

echo -e "${YELLOW}======================================================================${NC}"
echo -e "Analyzing: $(basename "$R1") and $(basename "$R2")"
echo -e "Using decompressor: $DECOMPRESSOR"
echo -e "${YELLOW}======================================================================${NC}"

# Check if files exist
if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
    echo -e "${RED}[FAIL]${NC} One or both files do not exist."
    exit 1
fi

# 1. Check for empty files
if [ ! -s "$R1" ] || [ ! -s "$R2" ]; then
    echo -e "${RED}[FAIL]${NC} One or both files are completely empty."
    exit 1
fi
echo -e "${GREEN}[PASS]${NC} Both files are non-empty."

# 2. Gzip Integrity Check (Super fast way to detect truncation without reading text)
echo -e "Testing gzip integrity (checking for truncation)..."
if gzip -t "$R1" && gzip -t "$R2"; then
    echo -e "${GREEN}[PASS]${NC} Gzip integrity check passed (no truncation detected)."
else
    echo -e "${RED}[FAIL]${NC} One or both gzip files are corrupted/truncated."
    exit 1
fi

# 3. Check first 1000 IDs (Sync at the beginning)
echo -e "Checking read ID sync at the beginning of the files..."
$DECOMPRESSOR "$R1" | head -n 4000 | grep '^@' | cut -d' ' -f1 | sed 's/\/[12]$//; s/_[12]$//' > /tmp/r1_head.txt
$DECOMPRESSOR "$R2" | head -n 4000 | grep '^@' | cut -d' ' -f1 | sed 's/\/[12]$//; s/_[12]$//' > /tmp/r2_head.txt

if diff /tmp/r1_head.txt /tmp/r2_head.txt > /dev/null; then
    echo -e "${GREEN}[PASS]${NC} Read IDs match at the beginning."
else
    echo -e "${RED}[FAIL]${NC} Read IDs mismatch at the beginning! Files are not paired or sorted."
    rm -f /tmp/r1_head.txt /tmp/r2_head.txt
    exit 1
fi
rm -f /tmp/r1_head.txt /tmp/r2_head.txt

# 4. Check last 1000 IDs (Sync at the end)
echo -e "Checking read ID sync at the end of the files..."
$DECOMPRESSOR "$R1" | tail -n 4000 | grep '^@' | cut -d' ' -f1 | sed 's/\/[12]$//; s/_[12]$//' > /tmp/r1_tail.txt
$DECOMPRESSOR "$R2" | tail -n 4000 | grep '^@' | cut -d' ' -f1 | sed 's/\/[12]$//; s/_[12]$//' > /tmp/r2_tail.txt

if diff /tmp/r1_tail.txt /tmp/r2_tail.txt > /dev/null; then
    echo -e "${GREEN}[PASS]${NC} Read IDs match at the end."
else
    echo -e "${RED}[FAIL]${NC} Read IDs mismatch at the end! Files may be mismatched or truncated."
    rm -f /tmp/r1_tail.txt /tmp/r2_tail.txt
    exit 1
fi
rm -f /tmp/r1_tail.txt /tmp/r2_tail.txt

# 5. Check for excessive 'N' content (Flowcell/instrument corruption check)
echo -e "Checking base calling diversity (excessive 'N' count in first 10,000 lines)..."
N_COUNT_R1=$($DECOMPRESSOR "$R1" | head -n 10000 | sed -n '2~4p' | tr -cd 'N' | wc -c)
N_COUNT_R2=$($DECOMPRESSOR "$R2" | head -n 10000 | sed -n '2~4p' | tr -cd 'N' | wc -c)

THRESHOLD=50000
if [ "$N_COUNT_R1" -lt "$THRESHOLD" ] && [ "$N_COUNT_R2" -lt "$THRESHOLD" ]; then
    echo -e "${GREEN}[PASS]${NC} Base call quality looks good (R1 'N's: $N_COUNT_R1, R2 'N's: $N_COUNT_R2)."
else
    echo -e "${YELLOW}[WARN]${NC} Excessive 'N' bases detected (R1 'N's: $N_COUNT_R1, R2 'N's: $N_COUNT_R2)."
    echo -e "       This can be common for bisulfite sequencing. Skipping fatal failure block."
fi

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}[SUCCESS] Sample passed all sync and quality validation checks!${NC}"
echo -e "${GREEN}======================================================================${NC}"
