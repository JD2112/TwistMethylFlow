#!/usr/bin/env Rscript

# Load required libraries
suppressPackageStartupMessages({
    library(edgeR)
    library(readr)
    library(optparse)
    library(dplyr)
    library(stringr)
    library(org.Hs.eg.db)
})

# Define command line arguments
option_list <- list(
    make_option(c("--design"), type="character", default=NULL, 
                help="Design file path (CSV format)", metavar="FILE"),
    make_option(c("--compare"), type="character", default="all", 
                help="Comparison string (e.g., 'GroupA_vs_GroupB') or 'all' for all pairwise comparisons [default= %default]", metavar="STRING"),
    make_option(c("--output"), type="character", default=".", 
                help="Output directory [default= %default]", metavar="DIR"),
    make_option(c("--coverage_threshold"), type="integer", default=3, 
                help="Coverage threshold for filtering [default= %default]", metavar="INTEGER")
)

# Parse command line arguments
opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser, positional_arguments = TRUE)

# Extract coverage files from positional arguments
coverage_files <- opt$args

# Print out the received arguments for debugging
cat("Received arguments:\n")
cat("coverage_files:", paste(coverage_files, collapse=" "), "\n")
cat("design:", opt$options$design, "\n")
cat("compare:", opt$options$compare, "\n")
cat("output:", opt$options$output, "\n")
cat("coverage_threshold:", opt$options$coverage_threshold, "\n")

# Read design file
targets <- read_csv(opt$options$design)
print("Design file contents:")
print(targets)

# Check if 'group' column exists
if(!"group" %in% colnames(targets)) {
    stop("Error: 'group' column not found in the design file. Please check your design file.")
}

# Check number of unique groups
unique_groups <- unique(targets$group)
if(length(unique_groups) < 2) {
    stop(paste("Error: Found only", length(unique_groups), "group(s). At least two groups are required for comparison."))
}

compare_str <- opt$options$compare

# Determine comparisons
if(compare_str == "all") {
    comparisons <- combn(unique_groups, 2, simplify = FALSE)
} else if(compare_str == "two_groups") {
    comparisons <- list(unique_groups[1:2])
} else {
    group_ids <- strsplit(as.character(compare_str), "_vs_")[[1]]
    if(length(group_ids) != 2) {
        stop("Error: Invalid comparison string. It should be in the format 'GroupA_vs_GroupB'.")
    }
    if(!all(group_ids %in% unique_groups)) {
        stop("Error: One or both groups specified in the comparison string are not present in the design file.")
    }
    comparisons <- list(group_ids)
}

# Read bismark data to DGEList
# Check if files have a track line (common in MethylDackel output) and create temp files without it if necessary
cleaned_coverage_files <- character(length(coverage_files))
for (i in seq_along(coverage_files)) {
    f <- coverage_files[i]
    if (file.exists(f)) {
        first_line <- readLines(f, n=1)
        if (grepl("^track", first_line)) {
            cat(paste("Detected track line in", f, "- creating temporary cleaned file.\n"))
            tmp_f <- tempfile(pattern = basename(f))
            # Use tail to skip the first line (efficiently)
            system(paste("tail -n +2", shQuote(f), ">", shQuote(tmp_f)))
            cleaned_coverage_files[i] <- tmp_f
        } else {
            cleaned_coverage_files[i] <- f
        }
    } else {
        warning(paste("File not found:", f))
        cleaned_coverage_files[i] <- f # Let readBismark2DGE fail or handle it
    }
}

# Extract IDs from filenames to ensure alignment with design file
cat("Extracting sample IDs from coverage files...\n")
available_ids <- as.character(targets$sample_id)
sample_ids_from_files <- unname(sapply(basename(coverage_files), function(f) {
    # Match the ID from design file that is a prefix of the filename
    match_idx <- which(sapply(available_ids, function(id) startsWith(f, id)))
    if (length(match_idx) > 0) {
        # Return the longest match if multiple exist
        matches <- available_ids[match_idx]
        return(matches[which.max(nchar(matches))])
    }
    return(NA)
}))
cat("Sample IDs extracted from files:\n")
print(sample_ids_from_files)

# Reorder targets to match file order
cat("Reordering design to match coverage files...\n")
targets <- targets[match(sample_ids_from_files, targets$sample_id), ]

if (any(is.na(sample_ids_from_files)) || any(is.na(targets$sample_id))) {
    cat("Error: Mapping between coverage files and design file failed.\n")
    cat("Filenames:\n")
    print(basename(coverage_files))
    cat("Extracted sample names:\n")
    print(sample_ids_from_files)
    cat("Available IDs in design file:\n")
    print(available_ids)
    stop("Sample mismatch between files and design")
}

# Use the cleaned files list
tt <- readBismark2DGE(cleaned_coverage_files, sample.names = targets$sample_id, readr = FALSE, verbose = TRUE)

# Print sample names for debugging
cat("Sample names in DGEList:\n")
print(colnames(tt))

# Cleaning of unwanted chromosomes
keep <- rep(TRUE, nrow(tt))
Chr <- as.character(tt$genes$Chr)
keep[grep("random", Chr)] <- FALSE
keep[grep("chrUn", Chr)] <- FALSE
keep[Chr == "chrM"] <- FALSE
tt1 <- tt[keep, , keep.lib.sizes = FALSE]

# Assign chromosome names
ChrNames <- paste0("chr", c(1:22, "X", "Y"))
tt1$genes$Chr <- factor(tt1$genes$Chr, levels = ChrNames)
o <- order(tt1$genes$Chr, tt1$genes$Locus)
tt1 <- tt1[o,]

# Filtering and normalizing
Methylation <- gl(2, 1, ncol(tt1), labels = c("Me", "Un"))
Me <- tt1$counts[, Methylation == "Me"]
Un <- tt1$counts[, Methylation == "Un"]
Coverage <- Me + Un

# Keeping CpGs with at least the specified coverage threshold per sample
keep <- rowSums(Coverage >= opt$options$coverage_threshold) == nrow(targets)
HasBoth <- rowSums(Me) > 0 & rowSums(Un) > 0

y <- tt1[keep & HasBoth, , keep.lib.sizes = FALSE]
TotalLibSize <- 0.5 * y$samples$lib.size[Methylation == "Me"] + 0.5 * y$samples$lib.size[Methylation == "Un"]
y$samples$lib.size <- rep(TotalLibSize, each = 2)

# Perform comparisons
for(comp in comparisons) {
    group1 <- comp[1]
    group2 <- comp[2]
    
    cat("Performing comparison:", group1, "vs", group2, "\n")
    
    # Subset the data for the current comparison
    current_samples <- targets$group %in% c(group1, group2)
    y_subset <- y[, rep(current_samples, each = 2)]
    
    # Design matrix
    design_matrix <- model.matrix(~0 + group, data = data.frame(group = factor(rep(targets$group[current_samples], each = 2))))
    colnames(design_matrix) <- levels(factor(targets$group[current_samples]))
    
    # Print dimensions for debugging
    cat("Dimensions of y_subset:", dim(y_subset), "\n")
    cat("Dimensions of design_matrix:", dim(design_matrix), "\n")
    
    # Estimate dispersion
    y_subset <- estimateDisp(y_subset, design_matrix)
    
    # Fit model
    fit <- glmQLFit(y_subset, design_matrix)
    
    # Define contrast
    contrast <- makeContrasts(contrasts = paste0(group2, "-", group1), levels = design_matrix)
    
    # Perform test
    qlf <- glmQLFTest(fit, contrast = contrast)
    
    # Get results
    results <- topTags(qlf, n = Inf)
    
    # Prepare output
    output_name <- paste0("EdgeR_group_", trimws(group1), "_vs_", trimws(group2), "_coverage", opt$options$coverage_threshold)
    output_file <- file.path(opt$options$output, paste0(output_name, ".csv"))
    
    # Write results
    write.csv(results$table, file = output_file, quote = FALSE, row.names = TRUE)
    
    cat("Results written to:", output_file, "\n")
}

cat("All analyses complete.\n")
cat("Coverage threshold used:", opt$options$coverage_threshold, "\n")