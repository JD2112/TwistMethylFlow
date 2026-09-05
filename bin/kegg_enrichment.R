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
    cat("Warning: clusterProfiler or org.Hs.eg.db not found. Skipping KEGG enrichment.\n")
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
              file.path(opt$output, paste0(prefix, "_kegg_results.csv")), row.names=F)
    cat("No significant sites to process for KEGG. Exiting gracefully.\n")
    quit(save = "no", status = 0)
}
if (opt$method == "edger" || opt$method == "dss") {
    logfc_col <- ifelse("logFC" %in% colnames(df), "logFC", "diff")
    pval_col <- ifelse("PValue" %in% colnames(df), "PValue", "fdr")
    symbol_col <- "Symbol"
} else {
    logfc_col <- "meth.diff"; pval_col <- "qvalue"; symbol_col <- "SYMBOL"
}

# Logic for logfc threshold adjustment:
effective_logfc_cutoff <- opt$logfc_cutoff
if ((opt$method == "dss" || opt$method == "methylkit") && opt$logfc_cutoff >= 0.5) {
    cat("Scaling logfc_cutoff from", opt$logfc_cutoff, "to 0.1 for methylation difference method.\n")
    effective_logfc_cutoff <- 0.1
}

filtered <- df %>% filter(abs(!!sym(logfc_col)) >= effective_logfc_cutoff, !!sym(pval_col) < opt$pvalue_cutoff) %>% arrange(!!sym(pval_col)) %>% head(opt$top_n)
genes <- unique(as.character(filtered[[symbol_col]]))
genes <- genes[genes != "" & !is.na(genes)]

if (has_enrich_pkgs) {
    # Map to Entrez for KEGG
    gene_mapping <- tryCatch({
        bitr(genes, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
    }, error = function(e) {
        cat(sprintf("Warning in bitr: %s\n", e$message))
        NULL
    })

    if (!is.null(gene_mapping) && nrow(gene_mapping) > 0) {
        entrez_genes <- unique(gene_mapping$ENTREZID)

        # KEGG Enrichment with liberal cutoffs
        kegg <- tryCatch({
            enrichKEGG(gene = entrez_genes, organism = 'hsa', pvalueCutoff = 1, qvalueCutoff = 1)
        }, error = function(e) NULL)

        if (!is.null(kegg)) {
            # Convert Entrez IDs back to Symbols for readable KEGG
            kegg <- tryCatch({ setReadable(kegg, OrgDb = org.Hs.eg.db, keyType = "ENTREZID") }, error = function(e) kegg)
            
            results <- as.data.frame(kegg)
            # Apply actual significance filter
            results <- results %>% filter(pvalue < opt$pvalue_cutoff)
            
            if (nrow(results) > 0) {
                write.csv(results, file.path(opt$output, paste0(prefix, "_kegg_results.csv")), row.names=F)
                ggsave(file.path(opt$output, paste0(prefix, "_kegg_barplot.png")), barplot(kegg, showCategory=15), width=10, height=8)
                ggsave(file.path(opt$output, paste0(prefix, "_kegg_dotplot.png")), dotplot(kegg, showCategory=15), width=10, height=8)
            } else {
                write.csv(data.frame(Message="No KEGG pathways found below cutoff"), file.path(opt$output, paste0(prefix, "_kegg_results.csv")), row.names=F)
            }
        } else {
            write.csv(data.frame(Message="KEGG enrichment failed"), file.path(opt$output, paste0(prefix, "_kegg_results.csv")), row.names=F)
        }
    } else {
        write.csv(data.frame(Message="No valid SYMBOL keys for KEGG enrichment"), file.path(opt$output, paste0(prefix, "_kegg_results.csv")), row.names=F)
    }
} else {
    write.csv(data.frame(Message="Packages missing. Skipping KEGG enrichment."), file.path(opt$output, paste0(prefix, "_kegg_results.csv")), row.names=F)
}
