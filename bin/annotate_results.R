#!/usr/bin/env Rscript

# =====================================
# annotate_results.R (Safe Multi-file Version)
# Annotate one or more EdgeR result files with gene information.
# =====================================

suppressPackageStartupMessages({
    library(optparse)
    library(edgeR)
    library(dplyr)
})

# ---- Parse command line arguments ----
option_list <- list(
    make_option(c("--results"), type="character", action="append", default=NULL,
                help="One or more EdgeR results CSV files (use multiple --results flags).", metavar="FILE"),
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
cat("Annotate EdgeR Results\n")
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

    results <- tryCatch(read.csv(f), error = function(e) {
        cat("  ⚠️ Error reading file:", e$message, "\n\n")
        return(NULL)
    })
    if (is.null(results)) return(NULL)

    required_cols <- c("Chr", "Locus")
    missing <- setdiff(required_cols, colnames(results))
    if (length(missing) > 0) {
        cat("  ⚠️ Missing columns:", paste(missing, collapse = ", "), "→ skipping", "\n\n")
        return(NULL)
    }

    # Normalize chromosome names
    results$Chr <- ifelse(grepl("^chr", results$Chr), results$Chr, paste0("chr", results$Chr))

    # Perform annotation
    cat("  Finding nearest TSS...\n")
    TSS <- tryCatch({
        nearestTSS(results$Chr, results$Locus, species = "Hs")
    }, error = function(e) {
        cat("  ⚠️ Annotation failed for", f, ":", e$message, "\n\n")
        return(NULL)
    })
    if (is.null(TSS)) return(NULL)

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
