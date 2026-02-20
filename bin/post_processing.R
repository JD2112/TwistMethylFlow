#!/usr/bin/env Rscript

# Load required libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(optparse)

# Parse command line arguments
option_list <- list(
    make_option(c("--results"), type="character", default=NULL, 
                help="Path to the results file", metavar="FILE"),
    make_option(c("--compare"), type="character", default=NULL, 
                help="Comparison string", metavar="STRING"),
    make_option(c("--output"), type="character", default=".", 
                help="Output directory [default= %default]", metavar="DIR"),
    make_option(c("--logfc_cutoff"), type="double", default=0.5, 
                help="Log2 fold change cutoff [default= %default]", metavar="NUMBER"),
    make_option(c("--pvalue_cutoff"), type="double", default=0.05, 
                help="P-value cutoff [default= %default]", metavar="NUMBER"),
    make_option(c("--hyper_color"), type="character", default="red", 
                help="Color for hypermethylated CpGs [default= %default]", metavar="COLOR"),
    make_option(c("--hypo_color"), type="character", default="blue", 
                help="Color for hypomethylated CpGs [default= %default]", metavar="COLOR"),
    make_option(c("--nonsig_color"), type="character", default="grey", 
                help="Color for non-significant CpGs [default= %default]", metavar="COLOR"),
    make_option(c("--method"), type="character", default="edger",
                help="Analysis method (edger or methylkit) [default= %default]", metavar="STRING")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

# Read results
results <- read.csv(opt$results)
print(paste("Dimensions of results:", dim(results)[1], "rows,", dim(results)[2], "columns"))
print(str(results))

# Add a column for significance based on user-defined cutoffs and the analysis method
if (opt$method == "edger") {
    results$significance <- case_when(
        results$logFC >= opt$logfc_cutoff & results$PValue < opt$pvalue_cutoff ~ "Hypermethylated",
        results$logFC <= -opt$logfc_cutoff & results$PValue < opt$pvalue_cutoff ~ "Hypomethylated",
        TRUE ~ "Not Significant"
    )
    x_axis <- "logFC"
    y_axis <- "-log10(PValue)"
} else if (opt$method == "methylkit") {
    results$significance <- case_when(
        results$meth.diff >= opt$logfc_cutoff & results$qvalue < opt$pvalue_cutoff ~ "Hypermethylated",
        results$meth.diff <= -opt$logfc_cutoff & results$qvalue < opt$pvalue_cutoff ~ "Hypomethylated",
        TRUE ~ "Not Significant"
    )
    x_axis <- "meth.diff"
    y_axis <- "-log10(qvalue)"
} else {
    stop("Unknown method. Use 'edger' or 'methylkit'.")
}

# Derive prefix from results filename
results_prefix <- tools::file_path_sans_ext(basename(opt$results))

print(table(results$significance))

# Generate summary statistics
summary_stats <- results %>%
    summarize(
        total_dmrs = n(),
        hypermethylated = sum(significance == "Hypermethylated"),
        hypomethylated = sum(significance == "Hypomethylated"),
        significant_dmrs = sum(significance != "Not Significant")
    )

write.csv(summary_stats, file.path(opt$output, paste0(results_prefix, "_summary_stats.csv")), row.names = FALSE)

# Color palette
color_palette <- c("Hypermethylated" = opt$hyper_color, 
                   "Hypomethylated" = opt$hypo_color, 
                   "Not Significant" = opt$nonsig_color)

# Create volcano plot
ggplot(results, aes_string(x = x_axis, y = y_axis, color = "significance")) +
    geom_point(alpha = 0.6) +
    scale_color_manual(values = color_palette) +
    geom_vline(xintercept = c(-opt$logfc_cutoff, opt$logfc_cutoff), linetype = "dashed", color = "black") +
    geom_hline(yintercept = -log10(opt$pvalue_cutoff), linetype = "dashed", color = "black") +
    labs(title = paste("Volcano Plot -", opt$compare, "(", opt$method, ")"), 
         x = ifelse(opt$method == "edger", "Log2 Fold Change", "Methylation Difference"),
         y = ifelse(opt$method == "edger", "-Log10 P-value", "-Log10 Q-value"),
         color = "Methylation Status") +
    theme_minimal() +
    theme(legend.position = "right")
ggsave(file.path(opt$output, paste0(results_prefix, "_volcano_plot.png")), width = 10, height = 8)

# Create MA plot (for EdgeR) or scatter plot (for MethylKit)
if (opt$method == "edger") {
    ggplot(results, aes(x = logCPM, y = logFC, color = significance)) +
        geom_point(alpha = 0.6) +
        scale_color_manual(values = color_palette) +
        geom_hline(yintercept = c(-opt$logfc_cutoff, opt$logfc_cutoff), linetype = "dashed", color = "black") +
        labs(title = paste("MA Plot -", opt$compare, "(", opt$method, ")"), 
             x = "Log2 CPM", y = "Log2 Fold Change",
             color = "Methylation Status") +
        theme_minimal() +
        theme(legend.position = "right")
} else {
    ggplot(results, aes(x = meth.diff, y = -log10(qvalue), color = significance)) +
        geom_point(alpha = 0.6) +
        scale_color_manual(values = color_palette) +
        geom_vline(xintercept = c(-opt$logfc_cutoff, opt$logfc_cutoff), linetype = "dashed", color = "black") +
        geom_hline(yintercept = -log10(opt$pvalue_cutoff), linetype = "dashed", color = "black") +
        labs(title = paste("Methylation Difference vs Q-value -", opt$compare, "(", opt$method, ")"), 
             x = "Methylation Difference", y = "-Log10 Q-value",
             color = "Methylation Status") +
        theme_minimal() +
        theme(legend.position = "right")
}
ggsave(file.path(opt$output, paste0(results_prefix, "_ma_or_scatter_plot.png")), width = 10, height = 8)
# Print the cutoffs and colors used
cat(sprintf("Analysis performed with:\nMethod: %s\nlogFC cutoff: %f\np-value cutoff: %f\n", 
            opt$method, opt$logfc_cutoff, opt$pvalue_cutoff))
cat(sprintf("Colors used:\nHypermethylated: %s\nHypomethylated: %s\nNot Significant: %s\n",
            opt$hyper_color, opt$hypo_color, opt$nonsig_color))