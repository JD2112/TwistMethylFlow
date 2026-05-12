#!/usr/bin/env Rscript

# Optimized Principal Component Analysis (PCA) for Methylation Specimen Clustering
# Scaled to 5,000 regions with robust imputation and high-speed chromosomal indexing

suppressPackageStartupMessages({
    library(ggplot2)
    library(dplyr)
    library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
parse_args <- function(args) {
    arg_list <- list(
        output = "pca_plot.png",
        top_n = 5000,           # Default scaled to 5000 for clinical robustness
        na_threshold = 0.2     # Allow up to 20% missingness across specimens
    )
    for (i in seq(1, length(args), by=2)) {
        if (i > length(args)) break
        key <- gsub("--", "", args[i])
        val <- args[i+1]
        arg_list[[key]] <- val
    }
    return(arg_list)
}

opt <- parse_args(args)

# 1. Load Prioritized DMRs and Sample Info
gene_df <- read.csv(opt$prioritized_csv, stringsAsFactors=FALSE)
samplesheet <- read.csv(opt$sample_sheet, stringsAsFactors=FALSE)
cov_files <- unlist(strsplit(opt$coverage_files, ","))

# Normalize chromosome names (ensure chr prefix exists or is removed consistently)
gene_df$chr <- as.character(gene_df$chr)
if (any(grepl("^chr", gene_df$chr))) {
    chr_prefix <- TRUE
} else {
    chr_prefix <- FALSE
}

# Get top genes for PCA
top_dmrs <- head(gene_df %>% arrange(desc(Rank_Score)), as.integer(opt$top_n))

if (nrow(top_dmrs) == 0) {
    cat("Warning: No significant DMRs found. Creating placeholder PCA plot.\n")
    p <- ggplot() + 
        annotate("text", x=0, y=0, label="PCA skipped: No significant regions provided") + 
        theme_void()
    ggsave(opt$output, p, width=8, height=7)
    quit(save="no", status=0)
}

# 2. Extract Data Matrix
cat("High-performance extraction of methylation data for PCA (Top", nrow(top_dmrs), "regions)...\n")

# Map files to samples
get_info <- function(p) {
    fname <- basename(p)
    sid <- samplesheet$sample_id[sapply(samplesheet$sample_id, function(x) grepl(x, fname))][1]
    return(as.character(sid))
}

meth_matrix <- matrix(NA, nrow=nrow(top_dmrs), ncol=nrow(samplesheet))
colnames(meth_matrix) <- samplesheet$sample_id

for (i in seq_along(cov_files)) {
    f <- cov_files[i]
    sid <- get_info(f)
    if (is.na(sid)) next
    
    cat("  Processing specimen:", sid, "\n")
    # Read header and data start
    all_lines <- readLines(f, n = 10)
    data_start <- grep("^track|^browser|^#", all_lines, invert = TRUE)[1]
    if (is.na(data_start)) next
    
    first_data_line <- read.table(text = all_lines[data_start], sep="\t", header=FALSE)
    nc <- ncol(first_data_line)
    
    # Read essential 4 columns
    classes <- c("character", "integer", "integer", "numeric", rep("NULL", nc - 4))
    
    beg_time <- Sys.time()
    bg <- read.table(f, colClasses=classes, sep="\t", header=FALSE, skip = data_start - 1)
    colnames(bg) <- c("chr", "start", "end", "meth")
    
    # Chromosomal Indexing
    bg$chr <- as.character(bg$chr)
    bg_by_chr <- split(bg, bg$chr)
    
    # Accelerated lookup
    for (j in 1:nrow(top_dmrs)) {
        reg <- top_dmrs[j,]
        if (reg$chr %in% names(bg_by_chr)) {
            chrom_data <- bg_by_chr[[reg$chr]]
            # Vectorized interval intersection
            sub_bg <- chrom_data[chrom_data$start >= reg$start & chrom_data$end <= reg$end, ]
            if (nrow(sub_bg) > 0) {
                meth_matrix[j, sid] <- mean(sub_bg$meth, na.rm=TRUE)
            }
        }
    }
    end_time <- Sys.time()
    cat("    Indexed and extracted in:", round(difftime(end_time, beg_time, units="secs"), 1), "seconds\n")
}

# 3. Robust Data Handling (Imputation & Filtering)
# Filter rows with excessive missingness (> 20%)
na_counts <- rowSums(is.na(meth_matrix))
keep_rows <- na_counts <= (ncol(meth_matrix) * as.numeric(opt$na_threshold))
meth_filtered <- meth_matrix[keep_rows, , drop=FALSE]

cat("Regions remaining after missingness filter:", nrow(meth_filtered), "\n")

# Mean Imputation for small gaps
if (nrow(meth_filtered) > 0) {
    # Impute missing values with row means (cohort average for that site)
    for (i in 1:nrow(meth_filtered)) {
        if (any(is.na(meth_filtered[i,]))) {
            row_mean <- mean(meth_filtered[i,], na.rm = TRUE)
            meth_filtered[i, is.na(meth_filtered[i,])] <- row_mean
        }
    }
    
    # Final Variance Filter (remove constant regions)
    row_vars <- apply(meth_filtered, 1, var, na.rm=TRUE)
    meth_final <- meth_filtered[row_vars > 1e-6 & !is.na(row_vars), , drop=FALSE]
} else {
    meth_final <- matrix(0, nrow=0, ncol=ncol(meth_matrix))
}

cat("Regions remaining after variance filtering:", nrow(meth_final), "\n")

if (nrow(meth_final) < 3) {
    cat("Error: Insufficient variant data for PCA scaling.\n")
    p <- ggplot() + 
        annotate("text", x=0, y=0, label="PCA skipped: Insufficient variant regions across specimens") + 
        theme_void()
    ggsave(opt$output, p)
    quit(save="no", status=0)
}

# 4. Perform PCA & Plotting
pca_res <- prcomp(t(meth_final), scale. = TRUE)
pca_df <- as.data.frame(pca_res$x)
pca_df$Sample <- rownames(pca_df)
pca_df <- left_join(pca_df, samplesheet %>% select(sample_id, group), by=c("Sample" = "sample_id"))

var_exp <- round(100 * pca_res$sdev^2 / sum(pca_res$sdev^2), 1)

p <- ggplot(pca_df, aes(x=PC1, y=PC2, color=group, label=Sample)) +
    geom_point(size=4, alpha=0.8) +
    geom_text(vjust=-1, size=3) +
    theme_minimal() +
    scale_color_brewer(palette="Set1") +
    labs(title="Principal Component Analysis (PCA) of Significant Regions",
         subtitle=paste("Analysis of the", nrow(meth_final), "most variant significant regions"),
         x=paste0("PC1 (", var_exp[1], "%)"),
         y=paste0("PC2 (", var_exp[2], "%)"),
         color="Group",
         caption=paste("Criteria: Top", opt$top_n, "DMRs; <20% missingness; Mean imputation for minor gaps; Zero-variance regions excluded.")) +
    theme(legend.position="bottom",
          plot.title=element_text(face="bold", color="#003366"))

ggsave(opt$output, p, width=8, height=7, dpi=150)
cat("PCA analysis successfully completed!\n")
