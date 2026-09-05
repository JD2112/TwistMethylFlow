#!/bin/bash

# Validation function - checks size and gzip integrity
validate_file() {
    local file=$1
    local file_name=$(basename "$file")
    
    # 1. Check existence and non-zero
    if [ ! -f "$file" ]; then return 1; fi
    if [ ! -s "$file" ]; then return 1; fi
    
    # 2. Size check - Reference/FastQ files are never < 1MB
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || wc -c < "$file")
    if [ "$size" -lt 1000000 ]; then 
        echo "  !! ERROR: $file_name is too small ($size bytes). Likely an HTML error page."
        return 1
    fi
    
    # 3. Content check - catch HTML error pages
    if [[ "$file" == *.gz ]]; then
        local header=$(head -c 2 "$file")
        if [[ ! "$header" == $'\x1f\x8b'* ]]; then
            echo "  !! ERROR: $file_name is not a valid gzip file (bad magic number)."
            return 1
        fi
        
        # 4. Gzip integrity check
        if ! gzip -t "$file" 2>/dev/null; then 
            echo "  !! ERROR: $file_name failed gzip integrity check."
            return 1
        fi
    fi
    
    return 0
}

# Subroutine for downloading a single file
if [ "$1" = "download_single" ]; then
    PROJECT_DIR="$2"
    URL="$3"
    DATA_DIR="${PROJECT_DIR}/data/test_data"
    
    if [[ "$URL" == *"hg38_RefSeq"* ]]; then FILE_NAME="hg38_RefSeq.bed.gz"
    elif [[ "$URL" == *"hg19_RefSeq"* ]]; then FILE_NAME="hg19_RefSeq.bed.gz"
    else FILE_NAME=$(basename "$URL"); fi

    TARGET_FILE="$DATA_DIR/$FILE_NAME"
    UNCOMPRESSED_FILE="${TARGET_FILE%.gz}"
    
    # If uncompressed exists, skip
    if [ -f "$UNCOMPRESSED_FILE" ] && [ -s "$UNCOMPRESSED_FILE" ]; then
        echo "OK: $FILE_NAME (already ready)"
        exit 0
    fi

    # Download loop
    ATTEMPT=1
    SUCCESS=0
    while [ $ATTEMPT -le 3 ]; do
        if [ -f "$TARGET_FILE" ]; then
            if validate_file "$TARGET_FILE"; then
                echo "OK: $FILE_NAME"
                SUCCESS=1
                break
            else
                echo "!! Removing invalid file: $FILE_NAME (Attempt $ATTEMPT)"
                rm -f "$TARGET_FILE"
            fi
        fi

        echo "Downloading $FILE_NAME (Attempt $ATTEMPT)..."
        if command -v wget >/dev/null 2>&1; then
            # Quiet mode -q is preferred when running in parallel to prevent output interleaving
            wget -q -c --timeout=60 --tries=5 -w 5 -O "$TARGET_FILE" "$URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -s -L -C - --connect-timeout 60 --retry 5 --retry-delay 5 -o "$TARGET_FILE" "$URL"
        else
            echo "!! ERROR: Neither wget nor curl found. Cannot download $FILE_NAME."
            exit 1
        fi
        
        if validate_file "$TARGET_FILE"; then
            echo "OK: $FILE_NAME"
            SUCCESS=1
            break
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
        [ $ATTEMPT -le 3 ] && sleep 5
    done

    if [ $SUCCESS -eq 0 ]; then
        echo "!! CRITICAL ERROR: Failed to download valid copy of $FILE_NAME after 3 attempts."
        exit 1
    else
        # Decompress FASTA and GTF
        if [[ "$FILE_NAME" == *.fa.gz ]] || [[ "$FILE_NAME" == *.gtf.gz ]] || [[ "$FILE_NAME" == curated_gene_disease_associations.tsv.gz ]]; then
            if [ -f "$TARGET_FILE" ] && [ ! -f "$UNCOMPRESSED_FILE" ]; then
                echo "Decompressing $FILE_NAME..."
                gunzip -k "$TARGET_FILE" || gunzip "$TARGET_FILE"
            fi
        fi
    fi
    exit 0
fi

# Main script execution
PROJECT_DIR=${1:-"."}
SAMPLE_SHEET=${2}
DATA_DIR="${PROJECT_DIR}/data/test_data"

mkdir -p "$DATA_DIR"

echo "===================================================="
echo "milou: Reference & Test Data Staging"
echo "Target Directory: $DATA_DIR"
echo "Current Time: $(date)"
echo "===================================================="

# Base reference files (hg38 and hg19/GRCh37)
FILES=(
    # hg38 (Ensembl 104)
    "https://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz"
    "https://ftp.ensembl.org/pub/release-104/gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz"
    "https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg38_RefSeq.bed.gz/download"
    
    # hg19 (Ensembl 87 / GRCh37)
    "https://ftp.ensembl.org/pub/grch37/release-87/fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz"
    "https://ftp.ensembl.org/pub/grch37/release-87/gtf/homo_sapiens/Homo_sapiens.GRCh37.87.gtf.gz"
    "https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg19_RefSeq.bed.gz/download"

    # Metadata
    "https://raw.githubusercontent.com/isglobal-brge/brgeUtils/master/annots/curated_gene_disease_associations.tsv.gz"
)

# Parse CSV for FastQ links
if [ -n "$SAMPLE_SHEET" ] && [ -f "$SAMPLE_SHEET" ]; then
    echo "Parsing Sample Sheet: $SAMPLE_SHEET"
    LINKS=$(awk -F',' 'NR > 1 { for(i=1; i<=NF; i++) { if($i ~ /^(http|ftp)/) { gsub(/\r/, "", $i); gsub(/"/, "", $i); print $i } } }' "$SAMPLE_SHEET")
    while read -r link; do [ -n "$link" ] && FILES+=("$link"); done <<< "$LINKS"
fi

# De-duplicate
FILES=($(for f in "${FILES[@]}"; do echo $f; done | sort -u))

echo "Checking ${#FILES[@]} unique files..."
echo "Downloading files in parallel (16 concurrent threads)..."

# Run parallel downloads using xargs
printf "%s\n" "${FILES[@]}" | xargs -n 1 -P 16 "$0" "download_single" "$PROJECT_DIR"
XARGS_STATUS=$?

if [ $XARGS_STATUS -ne 0 ]; then
    echo "===================================================="
    echo "STAGING FAILED: One or more parallel downloads failed."
    echo "===================================================="
    exit 1
fi

echo ""
echo "===================================================="
echo "Staging complete in $DATA_DIR"
echo "===================================================="
