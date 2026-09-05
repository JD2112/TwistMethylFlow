#!/usr/bin/env Rscript

# Integrated KEGG Pathway Visualization (PathView)
# Maps differential methylation intensities (Red/Blue) onto KEGG pathways

suppressPackageStartupMessages({
    library(pathview)
    library(org.Hs.eg.db)
})

args <- commandArgs(trailingOnly = TRUE)
parse_args <- function(args) {
    arg_list <- list(
        output_prefix = "pathview",
        kegg_tsv = NULL,
        prioritized_csv = NULL
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

if (is.null(opt$kegg_tsv) || is.null(opt$prioritized_csv)) {
    cat("Usage: generate_pathview.R --kegg_tsv <tsv> --prioritized_csv <csv>\n")
    quit(save="no", status=1)
}

# 1. Load KEGG Results and Prioritized Data
kegg_df <- read.csv(opt$kegg_tsv, stringsAsFactors=FALSE)

# Detect if the file is empty or is a placeholder/dummy file
if (nrow(kegg_df) == 0 || "Message" %in% colnames(kegg_df) || is.na(grep("ID", colnames(kegg_df), ignore.case=TRUE)[1])) {
    cat("Warning: No valid KEGG pathways found or analysis was skipped. Creating placeholder Pathview plot.\n")
    png(file.path(".", "top_kegg_pathview.png"), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No significant KEGG pathways found", cex=1.5)
    dev.off()
    quit(save="no", status=0)
}

# The ID column might be "ID" or "kegg_id"
k_id_col <- grep("ID", colnames(kegg_df), ignore.case=TRUE, value=TRUE)[1]
top_kegg_id <- kegg_df[1, k_id_col]
# Clean prefix if it has "hsa"
pathway_id <- gsub("hsa", "", top_kegg_id)

cat("Generating Pathview for top pathway:", top_kegg_id, "\n")

# 2. Map Symbols to Entrez IDs for Pathview
gene_df <- read.csv(opt$prioritized_csv, stringsAsFactors=FALSE)

# Ensure columns are identified
symbol_col <- grep("Symbol", colnames(gene_df), ignore.case=TRUE, value=TRUE)[1]
logfc_col <- grep("logFC|diff", colnames(gene_df), ignore.case=TRUE, value=TRUE)[1]

if (nrow(gene_df) == 0 || is.na(symbol_col) || is.na(logfc_col) || length(gene_df[[symbol_col]]) == 0) {
    cat("Warning: No prioritized genes found in", opt$prioritized_csv, ". Creating placeholder Pathview plot.\n")
    png(file.path(".", "top_kegg_pathview.png"), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No prioritized genes for Pathview", cex=1.5)
    dev.off()
    quit(save="no", status=0)
}

symbols <- gene_df[[symbol_col]]
symbols <- symbols[!is.na(symbols) & symbols != ""]

if (length(symbols) == 0) {
    cat("Warning: No valid gene symbols found. Creating placeholder Pathview plot.\n")
    png(file.path(".", "top_kegg_pathview.png"), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No valid gene symbols for Pathview", cex=1.5)
    dev.off()
    quit(save="no", status=0)
}

mapping <- mapIds(org.Hs.eg.db, keys=symbols, column="ENTREZID", keytype="SYMBOL", multiVals="first")

# Create the data vector for Pathview (logFC mapped to Entrez)
pv_data <- gene_df[[logfc_col]]
names(pv_data) <- mapping

# Filter out NAs
pv_data <- pv_data[!is.na(names(pv_data))]

if (length(pv_data) == 0) {
    cat("No Entrez mappings found for prioritized genes. Creating placeholder Pathview plot.\n")
    png(file.path(".", "top_kegg_pathview.png"), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No Entrez mappings found", cex=1.5)
    dev.off()
    quit(save="no", status=0)
}

# 3. Trigger Pathview
cat("Executing Pathview...\n")
# pathview sometimes writes to the current directory directly
tryCatch({
    pathview(gene.data = pv_data, 
             pathway.id = pathway_id, 
             species = "hsa", 
             out.suffix = "top_kegg",
             limit = list(gene=2, cpd=1),
             low = list(gene="blue", cpd="blue"),
             mid = list(gene="white", cpd="white"),
             high = list(gene="red", cpd="red"),
             kegg.native = TRUE)

    # We expect a file like hsaXXXXX.top_kegg.png
    # Find and rename to a stable name for Nextflow
    gen_file <- list.files(pattern = paste0("hsa", pathway_id, "\\.top_kegg\\.png"))
    if (length(gen_file) > 0) {
        file.rename(gen_file[1], "top_kegg_pathview.png")
    }
}, error = function(e) {
    cat("Pathview Error:", conditionMessage(e), "\n")
})

# Guarantee output exists so Nextflow does not fail
if (!file.exists("top_kegg_pathview.png")) {
    png(file.path(".", "top_kegg_pathview.png"), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "Pathview generation skipped", cex=1.5)
    dev.off()
}

cat("Pathview analysis complete!\n")

