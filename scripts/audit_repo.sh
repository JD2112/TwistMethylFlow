#!/usr/bin/env bash
#
# audit_repo.sh / audit_report.sh
# 
# Comprehensive pre-flight repository auditor for Git projects:
# - Scans for secrets, API tokens, passwords, and private keys
# - Detects leaked personal paths, home directories, and cluster usernames
# - Flags OS junk (.DS_Store), untracked caches, and oversized binary files
# - Validates standard OSS compliance files (README, LICENSE, CHANGELOG, etc.)
# - Generates color-coded terminal reports and optional Markdown summaries
#
# Usage:
#   ./scripts/audit_repo.sh [path/to/repo] [--report [report.md]]
#

set -eo pipefail

# ANSI color codes
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Counters
COUNT_CRITICAL=0
COUNT_WARNING=0
COUNT_PASS=0

# Arguments parsing
TARGET_DIR="."
REPORT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo -e "${BOLD}Usage:${NC} $0 [TARGET_DIR] [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -r, --report [FILE]  Save audit results as Markdown (default: audit_report.md)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                  # Audit current directory"
            echo "  $0 /path/to/my-repo                 # Audit specific repo"
            echo "  $0 . --report preflight_audit.md   # Generate markdown report"
            exit 0
            ;;
        -r|--report)
            if [[ -n "$2" && "$2" != -* ]]; then
                REPORT_FILE="$2"
                shift 2
            else
                REPORT_FILE="audit_report.md"
                shift 1
            fi
            ;;
        *)
            if [[ -d "$1" ]]; then
                TARGET_DIR="$1"
                shift 1
            else
                echo -e "${RED}Error: Directory '$1' not found.${NC}"
                exit 1
            fi
            ;;
    esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
cd "$TARGET_DIR"

echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}       🔍 REPOSITORY PRE-COMMIT & SECURITY AUDIT TOOL                 ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "${BOLD}Target Directory:${NC} $TARGET_DIR"
echo -e "${BOLD}Date / Time:${NC}      $(date)"
if [[ -n "$REPORT_FILE" ]]; then
    echo -e "${BOLD}Output Report:${NC}    $REPORT_FILE"
    cat <<EOF > "$REPORT_FILE"
# 🔍 Repository Pre-Commit & Security Audit Report

- **Target Directory:** \`$TARGET_DIR\`
- **Generated On:** $(date)
- **Git Branch:** $(git branch --show-current 2>/dev/null || echo "N/A")

---

EOF
fi
echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"

# Helper reporting functions
log_pass() {
    local msg="$1"
    echo -e "  ${GREEN}✔ [PASS]${NC} $msg"
    COUNT_PASS=$((COUNT_PASS + 1))
    if [[ -n "$REPORT_FILE" ]]; then
        echo -e "- ✅ **[PASS]** $msg" >> "$REPORT_FILE"
    fi
}

log_warn() {
    local msg="$1"
    local details="$2"
    echo -e "  ${YELLOW}⚠ [WARN]${NC} $msg"
    COUNT_WARNING=$((COUNT_WARNING + 1))
    if [[ -n "$REPORT_FILE" ]]; then
        echo -e "- ⚠️ **[WARN]** $msg" >> "$REPORT_FILE"
        if [[ -n "$details" ]]; then
            echo -e "  \`\`\`\n  $details\n  \`\`\`" >> "$REPORT_FILE"
        fi
    fi
}

log_crit() {
    local msg="$1"
    local details="$2"
    echo -e "  ${RED}✖ [CRITICAL]${NC} $msg"
    COUNT_CRITICAL=$((COUNT_CRITICAL + 1))
    if [[ -n "$REPORT_FILE" ]]; then
        echo -e "- ❌ **[CRITICAL]** $msg" >> "$REPORT_FILE"
        if [[ -n "$details" ]]; then
            echo -e "  \`\`\`\n  $details\n  \`\`\`" >> "$REPORT_FILE"
        fi
    fi
}

# Directories and files to exclude from regex content searching
EXCLUDE_ARGS=(
    --exclude-dir=".git"
    --exclude-dir=".hg"
    --exclude-dir=".svn"
    --exclude-dir="node_modules"
    --exclude-dir=".venv"
    --exclude-dir="venv"
    --exclude-dir=".quarto"
    --exclude-dir="backup"
    --exclude-dir="scratch"
    --exclude="*.png"
    --exclude="*.jpg"
    --exclude="*.jpeg"
    --exclude="*.gif"
    --exclude="*.svg"
    --exclude="*.pdf"
    --exclude="*.zip"
    --exclude="*.tar.gz"
    --exclude="*.gz"
    --exclude="*.bam"
    --exclude="*.bai"
    --exclude="*.bed"
    --exclude="*.fa"
    --exclude="*.fasta"
    --exclude="*.qmd"
    --exclude="*.html"
    --exclude="audit_repo.sh"
    --exclude="audit_report.sh"
    --exclude="$REPORT_FILE"
)

# -----------------------------------------------------------------------------
# CHECK 1: Secrets, Private Keys & Sensitive Files
# -----------------------------------------------------------------------------
echo -e "${BOLD}[1/5] Scanning for Credentials, Secrets & Sensitive Files...${NC}"
if [[ -n "$REPORT_FILE" ]]; then echo -e "\n### 1. Credentials, Secrets & Sensitive Files\n" >> "$REPORT_FILE"; fi

# 1.1 Private Keys & Certificates
FOUND_KEYS=$(find . -not -path '*/.*' -not -path '*/backup/*' \( -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.keystore" -o -name "id_rsa*" -o -name "id_ed25519*" \) 2>/dev/null || true)
if [[ -n "$FOUND_KEYS" ]]; then
    log_crit "Private key / certificate file(s) found on disk:" "$FOUND_KEYS"
    echo -e "    ${RED}Files:${NC}\n$FOUND_KEYS" | sed 's/^/      /'
else
    log_pass "No private key or certificate files detected on disk."
fi

# 1.2 Environment configuration files with secrets
FOUND_ENV=$(find . -not -path '*/.*' -not -path '*/backup/*' \( -name ".env" -o -name ".env.*" -o -name "*credentials*.json" \) 2>/dev/null || true)
if [[ -n "$FOUND_ENV" ]]; then
    log_crit "Active environment/credential file(s) found on disk:" "$FOUND_ENV"
    echo -e "    ${RED}Files:${NC}\n$FOUND_ENV" | sed 's/^/      /'
else
    log_pass "No unignored .env or credentials.json files found."
fi

# 1.3 Regex search for secrets inside text files
SECRET_REGEX="(ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9]{82}|AKIA[0-9A-Z]{16}|aws_secret_access_key|BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|bearer [a-zA-Z0-9_\-\.]{30,})"
LEAKED_SECRETS=$(grep -rnEi "${EXCLUDE_ARGS[@]}" "$SECRET_REGEX" . 2>/dev/null || true)

if [[ -n "$LEAKED_SECRETS" ]]; then
    log_crit "High-confidence secret tokens or private keys found in text files:" "$LEAKED_SECRETS"
    echo "$LEAKED_SECRETS" | head -n 10 | sed 's/^/      /'
else
    log_pass "No high-confidence API tokens or private key blocks found in text files."
fi

# -----------------------------------------------------------------------------
# CHECK 2: Local Paths, Home Directories & Cluster Usernames
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[2/5] Scanning for Leaked Local & Cluster Paths...${NC}"
if [[ -n "$REPORT_FILE" ]]; then echo -e "\n### 2. Local Machine & Cluster Paths\n" >> "$REPORT_FILE"; fi

# 2.1 Leaked macOS user paths (/Users/<user>)
MAC_LEAKS=$(grep -rnE "${EXCLUDE_ARGS[@]}" "/Users/[a-zA-Z0-9_-]+" . 2>/dev/null || true)
if [[ -n "$MAC_LEAKS" ]]; then
    log_crit "Personal macOS paths (/Users/...) found:" "$MAC_LEAKS"
    echo "$MAC_LEAKS" | head -n 8 | sed 's/^/      /'
else
    log_pass "No local macOS user paths (/Users/...) detected."
fi

# 2.2 Leaked Linux user paths (/home/<user> except /home/runner, /home/node)
LINUX_LEAKS=$(grep -rnE "${EXCLUDE_ARGS[@]}" "/home/[a-zA-Z0-9_-]+" . 2>/dev/null | grep -vE "(/home/runner|/home/node)" || true)
if [[ -n "$LINUX_LEAKS" ]]; then
    log_warn "Personal Linux paths (/home/<user>) found (verify if intentional):" "$LINUX_LEAKS"
    echo "$LINUX_LEAKS" | head -n 8 | sed 's/^/      /'
else
    log_pass "No non-standard Linux user home paths (/home/...) detected."
fi

# 2.3 Leaked cluster paths with hardcoded usernames (/data/<username> or /proj/<username>)
CLUSTER_LEAKS=$(grep -rnE "${EXCLUDE_ARGS[@]}" "(/(data|proj|scratch)/[A-Z][a-zA-Z0-9_]+)" . 2>/dev/null | grep -vE "(/(data|proj|scratch)/\$\{USER\}|/(data|proj|scratch)/test_data|Sample_sheet|Homo_sapiens|Twist_HMP|\.(csv|fa|fasta|gtf|bed|gz|zip))" || true)
if [[ -n "$CLUSTER_LEAKS" ]]; then
    log_warn "Potential hardcoded cluster user directories found (/data/<user>, /proj/<user>):" "$CLUSTER_LEAKS"
    echo "$CLUSTER_LEAKS" | head -n 8 | sed 's/^/      /'
else
    log_pass "No hardcoded cluster usernames found in storage paths (clean /data/\${USER}/ usage)."
fi

# 2.4 Leaked local URI links (file:///Users/ or file:///home/)
URI_LEAKS=$(grep -rnE "${EXCLUDE_ARGS[@]}" "file:///(Users|home)/" . 2>/dev/null || true)
if [[ -n "$URI_LEAKS" ]]; then
    log_crit "Clickable local URI path links (file:///...) found:" "$URI_LEAKS"
    echo "$URI_LEAKS" | head -n 8 | sed 's/^/      /'
else
    log_pass "No local file:// URI links found in documentation or scripts."
fi

# -----------------------------------------------------------------------------
# CHECK 3: Repository Hygiene, OS Junk & Large Files
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[3/5] Auditing Repository Hygiene, Junk Files & Large Blobs...${NC}"
if [[ -n "$REPORT_FILE" ]]; then echo -e "\n### 3. Repository Hygiene, Junk Files & Large Blobs\n" >> "$REPORT_FILE"; fi

# 3.1 OS Junk files (.DS_Store, Thumbs.db)
DS_STORE_FILES=$(find . -name ".DS_Store" -o -name "Thumbs.db" -o -name "desktop.ini" 2>/dev/null || true)
if [[ -n "$DS_STORE_FILES" ]]; then
    log_warn "OS artifact files found (.DS_Store / Thumbs.db):" "$DS_STORE_FILES"
    echo "$DS_STORE_FILES" | sed 's/^/      /'
    echo -e "      ${CYAN}Quick fix:${NC} find . -name '.DS_Store' -delete"
else
    log_pass "No OS junk files (.DS_Store / Thumbs.db) present."
fi

# 3.2 Python / R cache directories on disk
CACHE_FILES=$(find . -not -path '*/.git/*' -not -path '*/backup/*' \( -name "__pycache__" -o -name "*.pyc" -o -name ".Rhistory" -o -name ".RData" \) 2>/dev/null || true)
if [[ -n "$CACHE_FILES" ]]; then
    log_warn "Local development caches found (__pycache__, .Rhistory):" "$CACHE_FILES"
    echo "$CACHE_FILES" | head -n 5 | sed 's/^/      /'
else
    log_pass "No untracked Python or R environment caches found."
fi

# 3.3 Large files (> 10MB warning, > 50MB critical)
LARGE_FILES_50MB=$(find . -not -path '*/.git/*' -not -path '*/backup/*' -type f -size +50M 2>/dev/null || true)
LARGE_FILES_10MB=$(find . -not -path '*/.git/*' -not -path '*/backup/*' -type f -size +10M -size -50M 2>/dev/null || true)

if [[ -n "$LARGE_FILES_50MB" ]]; then
    log_crit "Large files (>50MB) detected (GitHub limit is 100MB; recommend Git LFS or Zenodo):" "$LARGE_FILES_50MB"
    for f in $LARGE_FILES_50MB; do
        ls -lh "$f" | awk '{print "      " $9 " (" $5 ")"}'
    done
else
    log_pass "No files exceeding 50 MB."
fi

if [[ -n "$LARGE_FILES_10MB" ]]; then
    log_warn "Medium-large files (>10MB) detected:" "$LARGE_FILES_10MB"
    for f in $LARGE_FILES_10MB; do
        ls -lh "$f" | awk '{print "      " $9 " (" $5 ")"}'
    done
else
    log_pass "No files between 10 MB and 50 MB."
fi

# -----------------------------------------------------------------------------
# CHECK 4: Git Status & .gitignore Coverage
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[4/5] Checking Git Status & .gitignore Protections...${NC}"
if [[ -n "$REPORT_FILE" ]]; then echo -e "\n### 4. Git Status & .gitignore Protections\n" >> "$REPORT_FILE"; fi

if [ -d ".git" ]; then
    # 4.1 Check .gitignore exists
    if [ -f ".gitignore" ]; then
        log_pass ".gitignore file is present."

        # Check recommended ignores
        RECOMMENDED_IGNORES=(".DS_Store" "work/" ".nextflow" "*.log" ".quarto/")
        MISSING_IGNORES=""
        for pat in "${RECOMMENDED_IGNORES[@]}"; do
            if ! grep -q "$pat" .gitignore 2>/dev/null; then
                MISSING_IGNORES+="$pat "
            fi
        done
        if [[ -n "$MISSING_IGNORES" ]]; then
            log_warn "Common patterns missing from .gitignore: $MISSING_IGNORES" ""
        else
            log_pass "Common critical ignore patterns (.DS_Store, work/, .nextflow, .quarto/) present in .gitignore."
        fi
    else
        log_warn ".gitignore file is MISSING at repository root." ""
    fi

    # 4.2 Untracked files audit
    UNTRACKED=$(git status --porcelain 2>/dev/null | grep "^??" || true)
    UNTRACKED_COUNT=$(echo "$UNTRACKED" | grep -v '^$' | wc -l | tr -d ' ')
    if [[ "$UNTRACKED_COUNT" -gt 0 ]]; then
        log_warn "$UNTRACKED_COUNT untracked file(s) or folder(s) present:" "$UNTRACKED"
        echo "$UNTRACKED" | head -n 8 | sed 's/^/      /'
        if [[ "$UNTRACKED_COUNT" -gt 8 ]]; then
            echo "      ... and $((UNTRACKED_COUNT - 8)) more (run 'git status -u' to view all)"
        fi
    else
        log_pass "No untracked files in working tree."
    fi

    # 4.3 Staged vs unstaged deletions/modifications
    DELETED_FILES=$(git status --porcelain 2>/dev/null | grep "^ D" || true)
    if [[ -n "$DELETED_FILES" ]]; then
        log_warn "Unstaged deleted files detected (use 'git add -u' to record removals):" "$DELETED_FILES"
        echo "$DELETED_FILES" | head -n 5 | sed 's/^/      /'
    else
        log_pass "No pending unstaged deletions in git tree."
    fi
else
    log_warn "Not a git repository (or .git not found)." ""
fi

# -----------------------------------------------------------------------------
# CHECK 5: Open Source Standard Files & Quality
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[5/5] Auditing Standard Open-Source Compliance Files...${NC}"
if [[ -n "$REPORT_FILE" ]]; then echo -e "\n### 5. Open-Source Compliance & Documentation\n" >> "$REPORT_FILE"; fi

for file in "README.md" "LICENSE" "CHANGELOG.md" "CONTRIBUTING.md" "SECURITY.md"; do
    if [ -f "$file" ]; then
        log_pass "Found standard repository file: $file"
    else
        log_warn "Missing standard recommended file: $file" ""
    fi
done

# Check for placeholder strings in markdown files
PLACEHOLDER_REGEX="(TODO:?|FIXME:?|INSERT_EMAIL_HERE|your\.email@example\.com|oss@jessesquires\.com)"
PLACEHOLDERS=$(grep -rnEi "${EXCLUDE_ARGS[@]}" "$PLACEHOLDER_REGEX" *.md .github/ 2>/dev/null || true)
if [[ -n "$PLACEHOLDERS" ]]; then
    log_warn "Template placeholders or boilerplate text found in documentation:" "$PLACEHOLDERS"
    echo "$PLACEHOLDERS" | head -n 6 | sed 's/^/      /'
else
    log_pass "No unresolved TODO, FIXME, or boilerplate placeholder emails found."
fi

# -----------------------------------------------------------------------------
# AUDIT SUMMARY
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}                          AUDIT SUMMARY                               ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "  ${GREEN}✔ Passed Checks:${NC}   $COUNT_PASS"
echo -e "  ${YELLOW}⚠ Warnings:${NC}        $COUNT_WARNING"
echo -e "  ${RED}✖ Critical Issues:${NC} $COUNT_CRITICAL"
echo -e "${CYAN}----------------------------------------------------------------------${NC}"

if [[ -n "$REPORT_FILE" ]]; then
    cat <<EOF >> "$REPORT_FILE"

---

## 📊 Summary Scorecard

| Status | Count |
|---|---|
| ✅ **Passed Checks** | $COUNT_PASS |
| ⚠️ **Warnings** | $COUNT_WARNING |
| ❌ **Critical Issues** | $COUNT_CRITICAL |

EOF
    echo -e "${GREEN}Report successfully saved to: ${BOLD}$REPORT_FILE${NC}\n"
fi

if [[ "$COUNT_CRITICAL" -gt 0 ]]; then
    echo -e "${RED}${BOLD}RESULT: FAILED.${NC} Please resolve the $COUNT_CRITICAL critical issue(s) before pushing to GitHub.\n"
    exit 1
elif [[ "$COUNT_WARNING" -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}RESULT: PASSED WITH WARNINGS.${NC} Please review the $COUNT_WARNING warning(s) above.\n"
    exit 0
else
    echo -e "${GREEN}${BOLD}RESULT: ALL CHECKS PASSED.${NC} The repository is clean and ready to commit/push!\n"
    exit 0
fi
