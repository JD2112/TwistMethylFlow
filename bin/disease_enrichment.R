#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(optparse)
    library(dplyr)
    library(ggplot2)
})

# Safely check for Bioconductor packages
has_enrichment_pkgs <- requireNamespace("org.Hs.eg.db", quietly = TRUE) && 
                       requireNamespace("clusterProfiler", quietly = TRUE) &&
                       requireNamespace("DOSE", quietly = TRUE) &&
                       requireNamespace("ReactomePA", quietly = TRUE)

if (has_enrichment_pkgs) {
    suppressPackageStartupMessages({
        library(org.Hs.eg.db)
        library(clusterProfiler)
        library(DOSE)
        library(ReactomePA)
    })
} else {
    cat("Warning: clusterProfiler, DOSE, ReactomePA, or org.Hs.eg.db not found. Skipping disease enrichment.\n")
}

# Enforce deterministic random sampling and clustering
set.seed(42)

option_list <- list(
    make_option(c("--results"), type="character", default=NULL, help="Path to the annotated results file", metavar="FILE"),
    make_option(c("--output"), type="character", default=".", help="Output directory", metavar="DIR"),
    make_option(c("--logfc_cutoff"), type="double", default=0.5, help="Log2 fold change cutoff"),
    make_option(c("--pvalue_cutoff"), type="double", default=0.05, help="P-value cutoff"),
    make_option(c("--method"), type="character", default="edger", help="Analysis method")
)

opt <- parse_args(OptionParser(option_list=option_list))
prefix <- tools::file_path_sans_ext(basename(opt$results))
outdir <- opt$output
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Load data
df <- read.csv(opt$results)
if (opt$method == "edger") {
    logfc_col <- "logFC"; pval_col <- "PValue"; symbol_col <- "Symbol"
} else if (opt$method == "dss") {
    logfc_col <- "diff"; pval_col <- "fdr"; symbol_col <- "Symbol"
} else {
    logfc_col <- "meth.diff"; pval_col <- "qvalue"; symbol_col <- "SYMBOL"
}

# Logic for logfc threshold adjustment:
effective_logfc_cutoff <- opt$logfc_cutoff
if ((opt$method == "dss" || opt$method == "methylkit") && opt$logfc_cutoff >= 0.5) {
    cat("Scaling logfc_cutoff from", opt$logfc_cutoff, "to 0.1 for methylation difference method.\n")
    effective_logfc_cutoff <- 0.1
}

# Filter significant genes
filtered <- df %>% filter(abs(!!sym(logfc_col)) >= effective_logfc_cutoff, !!sym(pval_col) < opt$pvalue_cutoff)
genes <- unique(as.character(filtered[[symbol_col]]))
genes <- genes[genes != "" & !is.na(genes)]

if (has_enrichment_pkgs) {
    # Map to Entrez
    gene_mapping <- bitr(genes, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
    entrez_genes <- unique(gene_mapping$ENTREZID)

    # Disease Ontology Enrichment
    do_enrich <- tryCatch({
        enrichDO(gene = entrez_genes, ont = "DO", pvalueCutoff = opt$pvalue_cutoff)
    }, error = function(e) return(NULL))

    if (!is.null(do_enrich)) {
        do_enrich <- setReadable(do_enrich, OrgDb = org.Hs.eg.db, keyType = "ENTREZID")
        write.csv(as.data.frame(do_enrich), file.path(outdir, paste0(prefix, "_disease_enrichment.csv")), row.names=F)
        
        # Plotting
        if (nrow(as.data.frame(do_enrich)) > 0) {
            ggsave(file.path(outdir, paste0(prefix, "_disease_barplot.png")), barplot(do_enrich, showCategory=15), width=10, height=8)
            ggsave(file.path(outdir, paste0(prefix, "_disease_dotplot.png")), dotplot(do_enrich, showCategory=15), width=10, height=8)
        }
    } else {
        write.csv(data.frame(Message="No disease enrichment found"), file.path(outdir, paste0(prefix, "_disease_enrichment.csv")), row.names=F)
    }

    # Reactome Pathway Analysis (often used for clinical relevance)
    reactome <- tryCatch({
        enrichPathway(gene = entrez_genes, pvalueCutoff = opt$pvalue_cutoff, readable = TRUE)
    }, error = function(e) return(NULL))

    if (!is.null(reactome)) {
        write.csv(as.data.frame(reactome), file.path(outdir, paste0(prefix, "_reactome_enrichment.csv")), row.names=F)
    }
} else {
    # Packages are missing, write safe dummy files
    write.csv(data.frame(Message="Packages missing. Skipping disease enrichment."), file.path(outdir, paste0(prefix, "_disease_enrichment.csv")), row.names=F)
}
