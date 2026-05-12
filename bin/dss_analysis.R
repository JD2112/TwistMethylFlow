#!/usr/bin/env Rscript

# Load required libraries
# Using Base R for everything except DSS/bsseq to ensure compatibility with 
# the dedicated Biocontainer which might not have tidyverse/readr/dplyr
suppressPackageStartupMessages({
    library(DSS)
    library(bsseq)
})

# Enforce deterministic random sampling and clustering
set.seed(42)

# Define command line arguments manually using commandArgs to avoid optparse dependency
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 5) {
    cat("Usage: dss_analysis.R --design <design.csv> --compare <compare> --output <dir> --coverage_threshold <int> <file1.bedGraph> <file2.bedGraph> ...\n")
    quit(status=1)
}

# Simple argument parser
parse_args <- function(args) {
    params <- list(coverage_files = c(), p_threshold = 1.0, diff_threshold = 0.0)
    i <- 1
    while(i <= length(args)) {
        if(args[i] == "--design") {
            params$design <- args[i+1]; i <- i + 2
        } else if(args[i] == "--compare") {
            params$compare <- args[i+1]; i <- i + 2
        } else if(args[i] == "--output") {
            params$output <- args[i+1]; i <- i + 2
        } else if(args[i] == "--coverage_threshold") {
            params$threshold <- as.integer(args[i+1]); i <- i + 2
        } else if(args[i] == "--p_threshold") {
            params$p_threshold <- as.numeric(args[i+1]); i <- i + 2
        } else if(args[i] == "--diff_threshold") {
            params$diff_threshold <- as.numeric(args[i+1]); i <- i + 2
        } else {
            if (startsWith(args[i], "--")) {
                i <- i + 2 # Skip unknown flags
            } else {
                params$coverage_files <- c(params$coverage_files, args[i]); i <- i + 1
            }
        }
    }
    return(params)
}

opt <- parse_args(args)

# Read design file using Base R
targets <- read.csv(opt$design, stringsAsFactors = FALSE)

# Check if 'group' column exists
if(!"group" %in% colnames(targets)) {
    stop("Error: 'group' column not found in the design file. Please check your design file.")
}

unique_groups <- unique(targets$group)
if(length(unique_groups) < 2) {
    stop(paste("Error: Found only", length(unique_groups), "group(s). At least two groups are required for comparison."))
}

# Determine comparisons
if(opt$compare == "all") {
    comparisons <- combn(as.character(unique_groups), 2, simplify = FALSE)
} else if(opt$compare == "two_groups") {
    comparisons <- list(as.character(unique_groups)[1:2])
} else {
    group_ids <- unlist(strsplit(as.character(opt$compare), "_vs_"))
    comparisons <- list(group_ids)
}

# Map sample IDs to files
id_col <- if("sample_id" %in% colnames(targets)) "sample_id" else "sample"
available_ids <- as.character(targets[[id_col]])

sample_ids_from_files <- unname(sapply(basename(opt$coverage_files), function(f) {
    match_idx <- which(sapply(available_ids, function(id) startsWith(f, id)))
    if (length(match_idx) > 0) {
        matches <- available_ids[match_idx]
        return(matches[which.max(nchar(matches))])
    }
    return(NA)
}))

# Handle mismatch
if (any(is.na(sample_ids_from_files))) {
    cat("Error: Could not map some files to sample IDs.\n")
    print(basename(opt$coverage_files))
    stop("Sample mismatch")
}

# Reorder targets
targets <- targets[match(sample_ids_from_files, targets[[id_col]]), ]

# Function to read Bismark/MethylDackel coverage files
read_bismark_cov <- function(file) {
    if (file.exists(file)) {
        # Check for track line
        con <- file(file, "r")
        first_line <- readLines(con, n=1)
        close(con)
        
        skip_n <- if (grepl("^track", first_line)) 1 else 0
        df <- read.table(file, header=FALSE, sep="\t", skip=skip_n, stringsAsFactors=FALSE)
        
        # DSS requires: chr, pos, N (total), X (methylated)
        cov_data <- data.frame(
            chr = df$V1,
            pos = df$V2,
            N = df$V5 + df$V6, # total = methylated + unmethylated
            X = df$V5          # methylated
        )
        return(cov_data)
    }
    return(NULL)
}

cat("Reading coverage files...\n")
dat_list <- list()
for(i in seq_along(opt$coverage_files)) {
    cat("  Loading", opt$coverage_files[i], "\n")
    dat_list[[i]] <- read_bismark_cov(opt$coverage_files[i])
}

cat("Creating BSseq object...\n")
BSobj <- makeBSseqData(dat_list, as.character(targets[[id_col]]))

for(comp in comparisons) {
    group1 <- comp[1]
    group2 <- comp[2]
    
    cat(paste("\n--- Processing Comparison:", group1, "vs", group2, "---\n"))
    
    tryCatch({
        # Run DML test
        # smoothing=TRUE is recommended for WGBS/EM-seq
        dmlTest.obj <- DMLtest(BSobj, 
                               group1 = as.character(targets[[id_col]][targets$group == group1]), 
                               group2 = as.character(targets[[id_col]][targets$group == group2]), 
                               smoothing = TRUE)
        
        # 1. Site-level analysis (DML)
        # DSS output columns: chr, pos, mu1, mu2, diff, diff.se, stat, phi1, phi2, pval, fdr
        results_all <- dmlTest.obj
        
        # Filter for significance
        cat("Applying filters: p-value <", opt$p_threshold, "and |diff| >", opt$diff_threshold, "\n")
        results <- results_all[results_all$fdr < opt$p_threshold & abs(results_all$diff) > opt$diff_threshold, ]
        
        cat("Number of sites before filtering:", nrow(results_all), "\n")
        cat("Number of sites after filtering:", nrow(results), "\n")
        
        if (nrow(results) == 0) {
            cat("Warning: No significant sites found. Saving empty file with header.\n")
            # Create a 1-row placeholder or just the header
            results <- results_all[0, ]
        }

        # Rename columns to match annotate_results.R expectations (Chr, Locus)
        colnames(results)[colnames(results) == "chr"] <- "Chr"
        colnames(results)[colnames(results) == "pos"] <- "Locus"
        
        output_name <- paste0("DSS_group_", trimws(group1), "_vs_", trimws(group2), "_sig")
        output_file <- file.path(opt$output, paste0(output_name, ".csv"))
        
        write.csv(results, file = output_file, quote = FALSE, row.names = FALSE)
        cat("Site-level results (DML) written to:", output_file, "\n")

        # 2. Region-level analysis (DMR)
        cat("Calling Differentially Methylated Regions (DMRs)...\n")
        # delta: minimum mean methylation difference (defaults to 0.1)
        # p.threshold: p-value threshold for sites to be considered (defaults to 1e-5)
        # minlen: minimum length of DMR (defaults to 50bp)
        # minCG: minimum number of CpG sites in DMR (defaults to 3)
        # dis.merge: maximum distance between DMRs to be merged (defaults to 100bp)
        # pct.sig: minimum percentage of significant sites in DMR (defaults to 0.5)
        
        # We use a slightly more lenient p.threshold for DMR calling as recommended for smaller datasets
        dmrs <- callDMR(dmlTest.obj, delta = opt$diff_threshold, p.threshold = opt$p_threshold)
        
        if (!is.null(dmrs) && nrow(dmrs) > 0) {
            cat("Number of DMRs found:", nrow(dmrs), "\n")
            
            # Standardize column names for Unified Layer
            # DSS DMR columns: chr, start, end, length, nCG, areaStat, diff.Methy
            colnames(dmrs)[colnames(dmrs) == "chr"] <- "Chr"
            colnames(dmrs)[colnames(dmrs) == "diff.Methy"] <- "logFC"
            
            dmr_output_name <- paste0("DSS_group_", trimws(group1), "_vs_", trimws(group2), "_dmr")
            dmr_output_file <- file.path(opt$output, paste0(dmr_output_name, ".csv"))
            write.csv(dmrs, file = dmr_output_file, quote = FALSE, row.names = FALSE)
            cat("Region-level results (DMR) written to:", dmr_output_file, "\n")
        } else {
            cat("No DMRs found for this comparison.\n")
        }
    }, error = function(e) {
        cat("Error in DMLtest for", group1, "vs", group2, ":", e$message, "\n")
    })
}

cat("DSS analysis complete.\n")
