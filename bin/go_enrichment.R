#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(optparse)
    library(dplyr)
    library(ggplot2)
})

has_enrich_pkgs <- requireNamespace("org.Hs.eg.db", quietly = TRUE) && 
                   requireNamespace("clusterProfiler", quietly = TRUE)

if (has_enrich_pkgs) {
    suppressPackageStartupMessages({
        library(org.Hs.eg.db)
        library(clusterProfiler)
    })
} else {
    cat("Warning: clusterProfiler or org.Hs.eg.db not found. Skipping GO enrichment.\n")
}

# Enforce deterministic random sampling and clustering
set.seed(42)

option_list <- list(
    make_option(c("--results"), type="character", default=NULL, help="Path to the results file"),
    make_option(c("--output"), type="character", default=".", help="Output directory"),
    make_option(c("--top_n"), type="integer", default=100, help="Number of top genes"),
    make_option(c("--logfc_cutoff"), type="double", default=0.5, help="Log2 fold change cutoff"),
    make_option(c("--pvalue_cutoff"), type="double", default=0.05, help="P-value cutoff"),
    make_option(c("--method"), type="character", default="edger")
)

opt <- parse_args(OptionParser(option_list=option_list))
prefix <- tools::file_path_sans_ext(basename(opt$results))

# Load and Filter
df <- read.csv(opt$results)

# Check if there are no sites or if the result file contains the "Status" column indicating no sites found
is_empty_or_status <- FALSE
if (dim(df)[1] == 0) {
    is_empty_or_status <- TRUE
} else if ("Status" %in% colnames(df)) {
    is_empty_or_status <- TRUE
}

if (is_empty_or_status) {
    write.csv(data.frame(Message="No differentially methylated sites found with current criteria"), 
              file.path(opt$output, paste0(prefix, "_go_results.csv")), row.names=F)
    cat("No significant sites to process for GO. Exiting gracefully.\n")
    quit(save = "no", status = 0)
}
if (opt$method == "edger" || opt$method == "dss") {
    logfc_col <- ifelse("logFC" %in% colnames(df), "logFC", "diff")
    pval_col <- ifelse("PValue" %in% colnames(df), "PValue", "fdr")
    symbol_col <- "Symbol"
} else {
    logfc_col <- "meth.diff"; pval_col <- "qvalue"; symbol_col <- "SYMBOL"
}

effective_logfc_cutoff <- opt$logfc_cutoff
if ((opt$method == "dss" || opt$method == "methylkit") && opt$logfc_cutoff >= 0.5) {
    cat("Scaling logfc_cutoff from", opt$logfc_cutoff, "to 0.1 for methylation difference method.\n")
    effective_logfc_cutoff <- 0.1
}

filtered <- df %>% filter(abs(!!sym(logfc_col)) >= effective_logfc_cutoff, !!sym(pval_col) < opt$pvalue_cutoff) %>% arrange(!!sym(pval_col)) %>% head(opt$top_n)
genes <- unique(as.character(filtered[[symbol_col]]))
genes <- genes[genes != "" & !is.na(genes)]

if (has_enrich_pkgs) {
    cat("Mapping Symbols to Entrez IDs...\n")
    gene_mapping <- tryCatch({
        bitr(genes, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
    }, error = function(e) NULL)

    if (is.null(gene_mapping) || nrow(gene_mapping) == 0) {
        entrez_genes <- genes
        used_key <- "SYMBOL"
    } else {
        entrez_genes <- unique(gene_mapping$ENTREZID)
        used_key <- "ENTREZID"
    }

    # GO Enrichment with liberal cutoffs to avoid missing borderline results
    ego <- enrichGO(gene = entrez_genes, OrgDb = org.Hs.eg.db, keyType = used_key, ont = "BP", pvalueCutoff = 1, qvalueCutoff = 1)

    if (!is.null(ego)) {
        # Convert back to readable symbols if needed
        if (used_key == "ENTREZID") {
            ego <- tryCatch({ setReadable(ego, OrgDb = org.Hs.eg.db, keyType = "ENTREZID") }, error = function(e) ego)
        }
        
        results <- as.data.frame(ego)
        # Apply actual significance filter
        results <- results %>% filter(pvalue < opt$pvalue_cutoff)
        
        if (nrow(results) > 0) {
            write.csv(results, file.path(opt$output, paste0(prefix, "_go_results.csv")), row.names=F)
            # Re-create object for plotting if needed or just use results
            ggsave(file.path(opt$output, paste0(prefix, "_go_barplot.png")), barplot(ego, showCategory=15), width=10, height=8)
        } else {
            write.csv(data.frame(Message="No GO enrichment found below cutoff"), file.path(opt$output, paste0(prefix, "_go_results.csv")), row.names=F)
        }
    } else {
        write.csv(data.frame(Message="GO enrichment failed"), file.path(opt$output, paste0(prefix, "_go_results.csv")), row.names=F)
    }
} else {
    write.csv(data.frame(Message="Packages missing. Skipping GO enrichment."), file.path(opt$output, paste0(prefix, "_go_results.csv")), row.names=F)
}
