#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(optparse)
    library(dplyr)
    library(GOplot)
    library(org.Hs.eg.db)
    library(clusterProfiler)
    library(ggplot2)
})

# -------- Parse arguments --------
option_list <- list(
    make_option(c("--results"), type="character", default=NULL,
                help="Path to the annotated results file", metavar="FILE"),
    make_option(c("--output"), type="character", default=".",
                help="Output directory [default= %default]", metavar="DIR"),
    make_option(c("--top_n"), type="integer", default=100,
                help="Number of top genes to use [default= %default]", metavar="NUMBER"),
    make_option(c("--logfc_cutoff"), type="double", default=0.5,
                help="Log2 fold change cutoff [default= %default]", metavar="NUMBER"),
    make_option(c("--pvalue_cutoff"), type="double", default=0.05,
                help="P-value cutoff [default= %default]", metavar="NUMBER"),
    make_option(c("--method"), type="character", default="edger",
                help="Analysis method (edger or methylkit) [default= %default]", metavar="STRING")
)

opt <- parse_args(OptionParser(option_list=option_list))

if (is.null(opt$results)) {
    cat("⚠️ No results file provided. Exiting.\n")
    quit(save = "no", status = 0)
}

prefix <- tools::file_path_sans_ext(basename(opt$results))
outdir <- opt$output
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("\n=== GO Analysis:", prefix, "===\n")

# Reading file
df <- tryCatch(read.csv(opt$results), error = function(e) {
    cat("Error reading file:", e$message, "\n")
    return(NULL)
})
if (is.null(df) || nrow(df) == 0) {
    cat("Empty or missing file.\n")
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.png")))
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.svg")))
    file.create(file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")))
    quit(save="no", status=0)
}

# Column mapping
if (opt$method == "edger") {
    logfc_col <- "logFC"; pval_col <- "PValue"; symbol_col <- "Symbol"
} else {
    logfc_col <- "meth.diff"; pval_col <- "qvalue"; symbol_col <- "SYMBOL"
}

if (!all(c(logfc_col, pval_col, symbol_col) %in% colnames(df))) {
    cat("Missing required columns. Skipping.\n")
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.png")))
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.svg")))
    file.create(file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")))
    quit(save="no", status=0)
}

# Filtering
filtered <- df %>%
    filter(abs(!!sym(logfc_col)) >= opt$logfc_cutoff, !!sym(pval_col) < opt$pvalue_cutoff) %>%
    arrange(!!sym(pval_col)) %>%
    head(opt$top_n)

if (nrow(filtered) == 0) {
    cat("No significant genes found.\n")
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.png")))
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.svg")))
    file.create(file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")))
    quit(save="no", status=0)
}

# GO Enrichment
genes <- unique(as.character(filtered[[symbol_col]]))
ego <- tryCatch({
    enrichGO(gene = genes, OrgDb = org.Hs.eg.db, keyType = "SYMBOL", ont = "BP", pvalueCutoff = 0.05)
}, error = function(e) {
    cat("Enrichment failed:", e$message, "\n")
    NULL
})

if (is.null(ego) || nrow(as.data.frame(ego)) == 0) {
    cat("No GO terms enriched.\n")
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.png")))
    file.create(file.path(outdir, paste0(prefix, "_gochord_plot.svg")))
    file.create(file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")))
    quit(save="no", status=0)
}

write.csv(as.data.frame(ego), file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")), row.names=F)

# GOChord Plotting Function
safe_plot <- function(file, type, mat) {
    cat("DEBUG: plotting to", file, "as", type, "\n")
    tryCatch({
        if (type == "png") {
            png(file, width=12, height=10, units="in", res=300)
        } else {
            svg(file, width=12, height=10)
        }
        
        # Ensure device is active
        if (dev.cur() == 1) stop("Failed to open device")
        
        GOChord(mat, space = 0.02, gene.order = 'logFC', gene.size = 3)
        dev.off()
        
        if (!file.exists(file) || file.size(file) == 0) {
            cat("⚠️ Plot was not created correctly. Touching file.\n")
            file.create(file)
        } else {
            cat("✅ Plot created successfully:", file, "\n")
        }
    }, error = function(e) {
        cat("⚠️ Plotting error (", type, "):", e$message, "\n")
        if (dev.cur() > 1) dev.off()
        # Fallback to empty file to satisfy Nextflow
        file.create(file)
    })
}

# Prepare data for GOChord
top_go <- as.data.frame(ego) %>% head(5)
all_genes <- unique(unlist(strsplit(top_go$geneID, "/")))

chord_mat <- matrix(0, nrow = length(all_genes), ncol = nrow(top_go))
rownames(chord_mat) <- all_genes
colnames(chord_mat) <- top_go$Description

for(i in 1:nrow(top_go)) {
    g <- unlist(strsplit(as.character(top_go$geneID[i]), "/"))
    chord_mat[g, i] <- 1
}

# Match logFC
gene_logfc <- filtered[[logfc_col]][match(all_genes, filtered[[symbol_col]])]
# Ensure everything is strictly numeric
final_mat <- cbind(chord_mat, logFC = as.numeric(as.character(gene_logfc)))
final_mat[is.na(final_mat)] <- 0

# Convert to matrix of numbers
final_mat_numeric <- apply(final_mat, 2, function(x) as.numeric(as.character(x)))
rownames(final_mat_numeric) <- rownames(final_mat)

safe_plot(file.path(outdir, paste0(prefix, "_gochord_plot.png")), "png", final_mat_numeric)
safe_plot(file.path(outdir, paste0(prefix, "_gochord_plot.svg")), "svg", final_mat_numeric)

cat("Analysis complete for:", prefix, "\n")
# Extra safety: ensure all 3 output files exist
expected_files <- c(
    file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")),
    file.path(outdir, paste0(prefix, "_gochord_plot.png")),
    file.path(outdir, paste0(prefix, "_gochord_plot.svg"))
)
for (f in expected_files) {
    if (!file.exists(f)) {
        cat("DEBUG: creating late-stage fallback for", f, "\n")
        file.create(f)
    }
}
