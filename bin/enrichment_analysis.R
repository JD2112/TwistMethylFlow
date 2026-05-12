#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(optparse)
    library(dplyr)
    library(ggplot2)
})

has_enrich_pkgs <- requireNamespace("org.Hs.eg.db", quietly = TRUE) && 
                   requireNamespace("clusterProfiler", quietly = TRUE) &&
                   requireNamespace("GOplot", quietly = TRUE)

if (has_enrich_pkgs) {
    suppressPackageStartupMessages({
        library(org.Hs.eg.db)
        library(clusterProfiler)
        library(GOplot)
    })
}

# -------- Helper to create dummy outputs --------
create_dummy_outputs <- function(outdir, prefix, message) {
    # Dummy CSV
    write.csv(data.frame(Message = message), file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")), row.names = FALSE)
    
    # Dummy PNG plots
    for (plot_type in c("_gochord_plot.png", "_dotplot.png", "_barplot.png")) {
        png(file.path(outdir, paste0(prefix, plot_type)), width = 800, height = 600)
        plot(1, type = "n", axes = FALSE, xlab = "", ylab = "")
        text(1, 1, message, cex = 1.5)
        dev.off()
    }
    
    # Dummy SVG
    svg(file.path(outdir, paste0(prefix, "_gochord_plot.svg")), width = 8, height = 6)
    plot(1, type = "n", axes = FALSE, xlab = "", ylab = "")
    text(1, 1, message, cex = 1.5)
    dev.off()
    
    # Dummy KEGG CSV
    write.csv(data.frame(Message = message), file.path(outdir, paste0(prefix, "_kegg_enrichment_results.csv")), row.names = FALSE)
    
    # Dummy KEGG Plots
    for (plot_type in c("_kegg_dotplot.png", "_kegg_barplot.png")) {
        png(file.path(outdir, paste0(prefix, plot_type)), width = 800, height = 600)
        plot(1, type = "n", axes = FALSE, xlab = "", ylab = "")
        text(1, 1, message, cex = 1.5)
        dev.off()
    }
}

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

if (!has_enrich_pkgs) {
    cat("⚠️ Warning: Bioconductor packages missing (clusterProfiler, org.Hs.eg.db, GOplot). Skipping enrichment.\n")
    create_dummy_outputs(outdir, prefix, "Packages missing. Skipping enrichment.")
    quit(save="no", status=0)
}

cat("\n=== GO Analysis:", prefix, "===\n")

# Reading file
cat("Loading results file:", opt$results, "\n")
df <- tryCatch(read.csv(opt$results), error = function(e) {
    cat("Error reading file:", e$message, "\n")
    return(NULL)
})
if (is.null(df) || nrow(df) == 0) {
    cat("⚠️ ERROR: Empty or missing file.\n")
    create_dummy_outputs(outdir, prefix, "Empty or missing file")
    quit(save="no", status=0)
}
cat("Loaded file with", nrow(df), "rows and columns:", paste(colnames(df), collapse=", "), "\n")

# Column mapping
if (opt$method == "edger") {
    logfc_col <- "logFC"; pval_col <- "PValue"; symbol_col <- "Symbol"
} else if (opt$method == "dss") {
    logfc_col <- "diff"; pval_col <- "fdr"; symbol_col <- "Symbol"
} else {
    logfc_col <- "meth.diff"; pval_col <- "qvalue"; symbol_col <- "SYMBOL"
}

cat("Using column mapping - LogFC:", logfc_col, "| P-val:", pval_col, "| Symbol:", symbol_col, "\n")

if (!all(c(logfc_col, pval_col, symbol_col) %in% colnames(df))) {
    missing <- c(logfc_col, pval_col, symbol_col)[!c(logfc_col, pval_col, symbol_col) %in% colnames(df)]
    cat("⚠️ ERROR: Missing required columns:", paste(missing, collapse=", "), "\n")
    cat("Available columns are:", paste(colnames(df), collapse=", "), "\n")
    create_dummy_outputs(outdir, prefix, paste("Missing required columns:", paste(missing, collapse=", ")))
    quit(save="no", status=0)
}

# Logic for logfc threshold adjustment:
# If method is dss or methylkit, 'logfc_cutoff' refers to proportion difference.
# if cutoff is 0.5, it's 50% which is very high. Normalize to 0.1 (10%).
effective_logfc_cutoff <- opt$logfc_cutoff
if ((opt$method == "dss" || opt$method == "methylkit") && opt$logfc_cutoff >= 0.5) {
    cat("Scaling logfc_cutoff from", opt$logfc_cutoff, "to 0.1 for methylation difference method.\n")
    effective_logfc_cutoff <- 0.1
}

# Filtering
cat("Applying filters: abs(", logfc_col, ") >=", effective_logfc_cutoff, "and", pval_col, "<", opt$pvalue_cutoff, "\n")
filtered <- df %>%
    filter(abs(!!sym(logfc_col)) >= effective_logfc_cutoff, !!sym(pval_col) < opt$pvalue_cutoff)

cat("Number of genes passing filters:", nrow(filtered), "\n")

if (nrow(filtered) > 0) {
    filtered <- filtered %>%
        arrange(!!sym(pval_col)) %>%
        head(opt$top_n)
    cat("Selecting top", nrow(filtered), "genes for GO enrichment.\n")
} else {
    cat("⚠️ No significant genes found.\n")
    create_dummy_outputs(outdir, prefix, paste("No significant genes found for cutoffs logFC >=", opt$logfc_cutoff, "and P-val <", opt$pvalue_cutoff))
    quit(save="no", status=0)
}

# GO Enrichment
genes <- unique(as.character(filtered[[symbol_col]]))
# Remove NA or empty symbols
genes <- genes[genes != "" & !is.na(genes)]

cat("Starting GO enrichment for", length(genes), "input genes.\n")

# Map Symbols to Entrez IDs for more robust GO analysis
cat("Mapping Symbols to Entrez IDs using bitr...\n")
gene_mapping <- tryCatch({
    bitr(genes, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
}, error = function(e) {
    cat("⚠️ ERROR: Symbol to Entrez mapping failed:", e$message, "\n")
    NULL
})

if (is.null(gene_mapping) || nrow(gene_mapping) == 0) {
    cat("⚠️ No mapping found for gene symbols. Attempting enrichment with symbols anyway.\n")
    entrez_genes <- genes
    used_key_type <- "SYMBOL"
} else {
    entrez_genes <- unique(gene_mapping$ENTREZID)
    used_key_type <- "ENTREZID"
    cat("Successfully mapped", nrow(gene_mapping), "symbols to", length(entrez_genes), "unique Entrez IDs.\n")
}

# Main GO enrichment step
ego <- tryCatch({
    enrichGO(gene = entrez_genes, 
             OrgDb = org.Hs.eg.db, 
             keyType = used_key_type, 
             ont = "BP", 
             pvalueCutoff = 1, # Set internally to 1 to see RAW results
             qvalueCutoff = 1) # Set internally to 1 to see RAW results
}, error = function(e) {
    cat("⚠️ ERROR: enrichment failed:", e$message, "\n")
    NULL
})

if (!is.null(ego)) {
    # Convert Entrez IDs back to Symbols for easier matching and plotting
    if (used_key_type == "ENTREZID") {
        cat("Converting Entrez IDs back to Symbols for plotting...\n")
        ego <- tryCatch({
            setReadable(ego, OrgDb = org.Hs.eg.db, keyType = "ENTREZID")
        }, error = function(e) {
            cat("⚠️ Warning: setReadable failed:", e$message, "\n")
            ego
        })
    }
    
    raw_results <- as.data.frame(ego)
    cat("Enrichment run finished. Found", nrow(raw_results), "raw GO terms before filtering.\n")
    
    if (nrow(raw_results) > 0) {
        cat("Top 5 raw results (ranked by p-value):\n")
        print(head(raw_results[, c("ID", "Description", "pvalue", "p.adjust")], 5))
        
        # Apply the ACTUAL user cutoff now
        cat("Filtering results by pvalue <", opt$pvalue_cutoff, "...\n")
        ego_filtered <- raw_results[raw_results$pvalue < opt$pvalue_cutoff, ]
        
        if (nrow(ego_filtered) == 0) {
            cat("⚠️ No GO terms survived the significance filter (p <", opt$pvalue_cutoff, ").\n")
            create_dummy_outputs(outdir, prefix, paste("No GO terms enriched for", length(entrez_genes), "genes at P <", opt$pvalue_cutoff))
            quit(save="no", status=0)
        }
        
        # If we have results, update the ego object or write the filtered table
        cat("Successfully enriched", nrow(ego_filtered), "GO terms.\n")
        write.csv(ego_filtered, file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")), row.names=F)
    } else {
        cat("⚠️ No GO terms found at all for these genes.\n")
        create_dummy_outputs(outdir, prefix, "No GO terms enriched (empty set)")
    }
} else {
    create_dummy_outputs(outdir, prefix, "No GO terms enriched")
}

# ---------------- KEGG Enrichment ----------------
cat("\nStarting KEGG enrichment...\n")
kegg <- tryCatch({
    enrichKEGG(gene = entrez_genes, 
               organism = 'hsa', 
               pvalueCutoff = opt$pvalue_cutoff)
}, error = function(e) {
    cat("⚠️ ERROR: KEGG enrichment failed:", e$message, "\n")
    NULL
})

if (!is.null(kegg)) {
    # Convert Entrez IDs back to Symbols for readable KEGG
    kegg <- tryCatch({
        setReadable(kegg, OrgDb = org.Hs.eg.db, keyType = "ENTREZID")
    }, error = function(e) { kegg })
    
    kegg_results <- as.data.frame(kegg)
    if (nrow(kegg_results) > 0) {
        cat("Successfully enriched", nrow(kegg_results), "KEGG pathways.\n")
        write.csv(kegg_results, file.path(outdir, paste0(prefix, "_kegg_enrichment_results.csv")), row.names=F)
    } else {
        cat("⚠️ No KEGG pathways passed the filter.\n")
        write.csv(data.frame(Message="No KEGG pathways enriched"), file.path(outdir, paste0(prefix, "_kegg_enrichment_results.csv")), row.names=F)
    }
} else {
    write.csv(data.frame(Message="KEGG Error"), file.path(outdir, paste0(prefix, "_kegg_enrichment_results.csv")), row.names=F)
}


# -------- Helper for robust plotting --------
safe_plot_base <- function(file, plot_obj, width=10, height=8) {
    pdf(NULL) # Avoid creating Rplots.pdf
    tryCatch({
        ggsave(file, plot = plot_obj, width = width, height = height, bg = "white")
        if (!file.exists(file) || file.size(file) == 0) {
            # Provide dummy output instead
            png(file, width=800, height=600)
            plot(1, type="n", axes=FALSE, xlab="", ylab="")
            text(1, 1, "Plot could not be saved", cex=1.5)
            dev.off()
        }
    }, error = function(e) {
        cat("⚠️ Plotting failed for", file, ":", e$message, "\n")
        png(file, width=800, height=600)
        plot(1, type="n", axes=FALSE, xlab="", ylab="")
        text(1, 1, paste("Plotting failed:", substring(e$message, 1, 50)), cex=1.5)
        dev.off()
    })
}

# 1. Barplot
cat("Generating barplot...\n")
p_bar <- tryCatch({
    barplot(ego, showCategory=20)
}, error = function(e) {
    cat("Barplot failed:", e$message, "\n")
    NULL
})
if (!is.null(p_bar)) safe_plot_base(file.path(outdir, paste0(prefix, "_barplot.png")), p_bar) else {
    png(file.path(outdir, paste0(prefix, "_barplot.png")), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "Barplot failed to generate", cex=1.5)
    dev.off()
}

# 2. Dotplot
cat("Generating dotplot...\n")
p_dot <- tryCatch({
    dotplot(ego, showCategory=20)
}, error = function(e) {
    cat("Dotplot failed:", e$message, "\n")
    NULL
})
if (!is.null(p_dot)) safe_plot_base(file.path(outdir, paste0(prefix, "_dotplot.png")), p_dot) else {
    png(file.path(outdir, paste0(prefix, "_dotplot.png")), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "Dotplot failed to generate", cex=1.5)
    dev.off()
}

# KEGG Barplot
if (!is.null(kegg) && nrow(as.data.frame(kegg)) > 0) {
    cat("Generating KEGG barplot...\n")
    k_bar <- tryCatch({ barplot(kegg, showCategory=15) }, error = function(e) NULL)
    if (!is.null(k_bar)) safe_plot_base(file.path(outdir, paste0(prefix, "_kegg_barplot.png")), k_bar) else {
        png(file.path(outdir, paste0(prefix, "_kegg_barplot.png")), width=800, height=600); plot(1, type="n", axes=FALSE, xlab="", ylab=""); dev.off()
    }
    
    cat("Generating KEGG dotplot...\n")
    k_dot <- tryCatch({ dotplot(kegg, showCategory=15) }, error = function(e) NULL)
    if (!is.null(k_dot)) safe_plot_base(file.path(outdir, paste0(prefix, "_kegg_dotplot.png")), k_dot) else {
        png(file.path(outdir, paste0(prefix, "_kegg_dotplot.png")), width=800, height=600); plot(1, type="n", axes=FALSE, xlab="", ylab=""); dev.off()
    }
} else {
    png(file.path(outdir, paste0(prefix, "_kegg_barplot.png")), width=800, height=600); plot(1, type="n", axes=FALSE, xlab="", ylab=""); text(1, 1, "No KEGG Terms", cex=1.5); dev.off()
    png(file.path(outdir, paste0(prefix, "_kegg_dotplot.png")), width=800, height=600); plot(1, type="n", axes=FALSE, xlab="", ylab=""); text(1, 1, "No KEGG Terms", cex=1.5); dev.off()
}

# 3. GOChord (Keep it as it's fancy but wrap in more safety)
# GOChord Plotting Function
safe_plot_chord <- function(file, mat) {
    cat("DEBUG: plotting chord to", file, "\n")
    tryCatch({
        p <- GOChord(mat, space = 0.02, gene.order = 'logFC', gene.size = 3)
        
        # Use ggsave for better compatibility with fonts and devices
        # Try cairo first if available, then fallback
        device_type <- "png"
        if (grepl("\\.svg$", file)) device_type <- "svg"
        
        ggsave(file, plot = p, width = 12, height = 10, bg = "white")
        
        if (!file.exists(file) || file.size(file) == 0) {
            stop("File creation failed or result was empty")
        }
        cat("✅ GOChord created successfully:", file, "\n")
        
    }, error = function(e) {
        cat("⚠️ GOChord plotting error:", e$message, "\n")
        
        # Fallback dummy file
        if (grepl("\\.png$", file)) {
            png(file, width=800, height=600)
        } else {
            svg(file, width=8, height=6)
        }
        plot(1, type="n", axes=FALSE, xlab="", ylab="")
        text(1, 1, paste("GOChord plotting failed:", substring(e$message, 1, 50)), cex=1.5)
        dev.off()
    })
}

# Prepare data for GOChord
top_go <- as.data.frame(ego) %>% head(5)
if (nrow(top_go) > 0) {
    all_genes <- unique(unlist(strsplit(top_go$geneID, "/")))
    
    chord_mat <- matrix(0, nrow = length(all_genes), ncol = nrow(top_go))
    rownames(chord_mat) <- all_genes
    colnames(chord_mat) <- top_go$Description
    
    for(i in 1:nrow(top_go)) {
        g <- unlist(strsplit(as.character(top_go$geneID[i]), "/"))
        chord_mat[g, i] <- 1
    }
    
    # Match logFC (using Symbols now that ego has been converted)
    gene_logfc <- filtered[[logfc_col]][match(all_genes, filtered[[symbol_col]])]
    
    # Ensure everything is strictly numeric and handle NAs
    final_mat <- cbind(chord_mat, logFC = as.numeric(as.character(gene_logfc)))
    final_mat[is.na(final_mat)] <- 0
    
    # Convert to matrix of numbers
    final_mat_numeric <- apply(final_mat, 2, function(x) as.numeric(as.character(x)))
    rownames(final_mat_numeric) <- rownames(final_mat)
    
    safe_plot_chord(file.path(outdir, paste0(prefix, "_gochord_plot.png")), final_mat_numeric)
    safe_plot_chord(file.path(outdir, paste0(prefix, "_gochord_plot.svg")), final_mat_numeric)
} else {
    cat("No terms available for GOChord.\n")
    png(file.path(outdir, paste0(prefix, "_gochord_plot.png")), width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No terms available for GOChord", cex=1.5)
    dev.off()
    
    svg(file.path(outdir, paste0(prefix, "_gochord_plot.svg")), width=8, height=6)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No terms available for GOChord", cex=1.5)
    dev.off()
}

cat("Analysis complete for:", prefix, "\n")

# Ensure all expected files exist to satisfy Nextflow
expected_files <- c(
    file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")),
    file.path(outdir, paste0(prefix, "_gochord_plot.png")),
    file.path(outdir, paste0(prefix, "_gochord_plot.svg")),
    file.path(outdir, paste0(prefix, "_dotplot.png")),
    file.path(outdir, paste0(prefix, "_barplot.png")),
    file.path(outdir, paste0(prefix, "_kegg_enrichment_results.csv")),
    file.path(outdir, paste0(prefix, "_kegg_dotplot.png")),
    file.path(outdir, paste0(prefix, "_kegg_barplot.png"))
)
for (f in expected_files) {
    if (!file.exists(f) || file.size(f) == 0) {
        cat("DEBUG: ensuring fallback for missing/empty file", f, "\n")
        
        # Determine file type
        if (grepl("\\.png$", f)) {
            png(f, width=800, height=600)
            plot(1, type="n", axes=FALSE, xlab="", ylab="")
            text(1, 1, "Result file could not be generated", cex=1.5)
            dev.off()
        } else if (grepl("\\.svg$", f)) {
            svg(f, width=8, height=6)
            plot(1, type="n", axes=FALSE, xlab="", ylab="")
            text(1, 1, "Result file could not be generated", cex=1.5)
            dev.off()
        } else if (grepl("\\.csv$", f)) {
            write.csv(data.frame(Message="Result file could not be generated"), f, row.names=FALSE)
        } else {
            file.create(f)
        }
    }
}
