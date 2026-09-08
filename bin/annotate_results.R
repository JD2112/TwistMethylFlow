#!/usr/bin/env Rscript

# =====================================
# annotate_results.R (Safe Multi-file Version)
# Annotate one or more EdgeR/DSS result files with gene information.
# =====================================

suppressPackageStartupMessages({
    library(optparse)
    library(edgeR)
    library(dplyr)
    library(org.Hs.eg.db)
})

# Enforce deterministic random sampling and clustering
set.seed(42)

# ---- Parse command line arguments ----
option_list <- list(
    make_option(c("--results"), type="character", action="append", default=NULL,
                help="One or more EdgeR/DSS results CSV files (use multiple --results flags).", metavar="FILE"),
    make_option(c("--gtf"), type="character", default=NULL,
                help="Optional: GTF annotation file (not yet used directly, for metadata)", metavar="FILE")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# ---- Check inputs ----
if (is.null(opt$results)) {
    stop("Error: --results argument is required. Use --help for more information.")
}

cat("====================================\n")
cat("Annotate Differential Results\n")
cat("====================================\n\n")

cat("Input files:\n")
cat(paste(" -", opt$results), sep = "\n")
cat("\n")

if (!is.null(opt$gtf)) {
    cat("Using GTF file:", opt$gtf, "\n\n")
}

# ---- Helper to safely annotate ----
safe_annotate <- function(f) {
    cat("Processing file:", f, "\n")

    if (!file.exists(f)) {
        cat("  ⚠️ File not found, skipping:", f, "\n\n")
        return(NULL)
    }

    results <- tryCatch({
        read.csv(f)
    }, error = function(e) {
        stop(paste("Error reading file:", f, "-", e$message))
    })

    # Handle different coordinate systems (Site-level vs Region-level)
    # 1. Site-level (EdgeR/DSS DML): Chr, Locus
    # 2. Region-level (DSS DMR): Chr, start, end
    
    if (!("Locus" %in% colnames(results))) {
        if ("start" %in% colnames(results) && "end" %in% colnames(results)) {
            cat("  Detection: Region-level data (DMR) found. Using midpoint for annotation.\n")
            results$Locus <- as.integer((results$start + results$end) / 2)
        } else if ("pos" %in% colnames(results)) {
            cat("  Detection: 'pos' column found. Mapping to 'Locus'.\n")
            results$Locus <- results$pos
        }
    }

    required_cols <- c("Chr", "Locus")
    cat("  Columns found:", paste(colnames(results), collapse = ", "), "\n")
    cat("  Preview of data (first 5 rows):\n")
    print(head(results, 5))
    missing <- setdiff(required_cols, colnames(results))
    if (length(missing) > 0) {
        stop(paste("File", f, "is missing required columns:", paste(missing, collapse = ", "), ". It must have (Chr, Locus) or (Chr, start, end)."))
    }

    # Normalize chromosome names and handle NAs
    results <- results[!is.na(results$Chr) & !is.na(results$Locus), ]
    results$Chr <- as.character(results$Chr)
    results$Chr <- ifelse(grepl("^chr", results$Chr), results$Chr, paste0("chr", results$Chr))
    # Remove any that became "chrNA"
    results <- results[results$Chr != "chrNA", ]
    
    # Ensure Locus is integer
    results$Locus <- as.integer(as.character(results$Locus))
    
    # Filter for standard human chromosomes to avoid nearestTSS internal errors
    valid_chrs <- c(paste0("chr", c(1:22, "X", "Y", "M", "MT")), c(1:22, "X", "Y", "M", "MT"))
    results <- results[results$Chr %in% valid_chrs, ]
    results <- results[!is.na(results$Chr) & !is.na(results$Locus), ]

    cat("  Rows after chromosome filtering:", nrow(results), "\n")
    if (nrow(results) == 0) {
        cat("  ⚠️ No valid rows to annotate. Writing empty file with headers.\n")
        # Ensure the columns for annotation exist even if empty
        results$EntrezID <- character(0)
        results$Symbol   <- character(0)
        results$Strand   <- character(0)
        results$Distance <- numeric(0)
        results$Width    <- numeric(0)
        
        base <- tools::file_path_sans_ext(basename(f))
        out_file <- paste0(base, "_annotated.csv")
        write.csv(results, file = out_file, row.names = FALSE)
        cat("  ✅ Written empty file:", out_file, "\n\n")
        return(NULL)
    }

    cat("  Sample of data to be annotated:\n")
    print(head(results[, c("Chr", "Locus")], 5))

    # Perform annotation
    cat("  Finding nearest TSS...\n")
    # Use unname() and as.vector() to prevent 'invalid row.names length' errors in nearestTSS
    TSS <- tryCatch({
        nearestTSS(as.vector(unname(results$Chr)), 
                   as.vector(unname(results$Locus)), 
                   species = "Hs")
    }, error = function(e) {
        stop(paste("Annotation failed for", f, ":", e$message))
    })

    results$EntrezID <- TSS$gene_id
    results$Symbol   <- TSS$symbol
    results$Strand   <- TSS$strand
    results$Distance <- TSS$distance
    results$Width    <- TSS$width

    annotated_rows <- sum(!is.na(results$EntrezID))
    cat("  Annotated rows:", annotated_rows, "/", nrow(results), "\n")

    # Save annotated file
    base <- tools::file_path_sans_ext(basename(f))
    out_file <- paste0(base, "_annotated.csv")

    write.csv(results, file = out_file, row.names = FALSE)
    cat("  ✅ Written:", out_file, "\n\n")
}

# ---- Annotate all result files ----
for (f in opt$results) {
    safe_annotate(f)
}

cat("====================================\n")
cat("All annotation attempts completed.\n")
cat("====================================\n")
