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
    make_option(c("--method"), type="character", default="edger", help="Analysis method"),
    make_option(c("--disgenet_db"), type="character", default=NULL, help="Path to local DisGeNET TSV file")
)

opt <- parse_args(OptionParser(option_list=option_list))
prefix <- tools::file_path_sans_ext(basename(opt$results))
outdir <- opt$output
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Load data
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
              file.path(outdir, paste0(prefix, "_disease_enrichment.csv")), row.names=F)
    cat("No significant sites to process for disease enrichment. Exiting gracefully.\n")
    quit(save = "no", status = 0)
}
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
    gene_mapping <- tryCatch({
        bitr(genes, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
    }, error = function(e) {
        cat(sprintf("Warning in bitr: %s\n", e$message))
        NULL
    })

    if (!is.null(gene_mapping) && nrow(gene_mapping) > 0) {
        entrez_genes <- unique(gene_mapping$ENTREZID)
    } else {
        entrez_genes <- character(0)
    }

    do_enrich <- NULL
    
    # 3.2 Sovereign DisGeNET Mapping
    if (!is.null(opt$disgenet_db) && file.exists(opt$disgenet_db)) {
        cat("Using SOVEREIGN LOCAL DISGENET DB for disease enrichment...\n")
        tryCatch({
            dg_data <- read.csv(opt$disgenet_db, sep="\t")
            # Create TERM2GENE data frame (Disease -> GeneSymbol)
            if ("diseaseName" %in% names(dg_data) && "geneSymbol" %in% names(dg_data)) {
                term2gene <- dg_data[, c("diseaseName", "geneSymbol")]
                # Enricher works on symbols natively if term2gene uses symbols
                do_enrich <- enricher(gene = genes, TERM2GENE = term2gene, pvalueCutoff = opt$pvalue_cutoff)
            } else {
                cat("Warning: DisGeNET DB lacks 'diseaseName' or 'geneSymbol' columns. Falling back to DOSE.\n")
            }
        }, error = function(e) {
            cat("Error loading DisGeNET DB:", conditionMessage(e), "\nFalling back to DOSE.\n")
        })
    }
    
    # Fallback to DOSE API if DisGeNET is not available
    if (is.null(do_enrich)) {
        cat("Running standard DOSE disease ontology enrichment...\n")
        do_enrich <- tryCatch({
            enrichDO(gene = entrez_genes, ont = "DO", pvalueCutoff = opt$pvalue_cutoff)
        }, error = function(e) return(NULL))
        
        if (!is.null(do_enrich)) {
            do_enrich <- setReadable(do_enrich, OrgDb = org.Hs.eg.db, keyType = "ENTREZID")
        }
    }

    if (!is.null(do_enrich)) {
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
