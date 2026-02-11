#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(optparse)
    library(dplyr)
    library(GOplot)
    library(org.Hs.eg.db)
    library(clusterProfiler)
})

# -------- Parse arguments --------
option_list <- list(
    make_option(c("--results"), type="character", action="store",
                help="Path(s) to one or more results files", metavar="FILE"),
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

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser, positional_arguments = TRUE)

# -------- Handle multiple input files --------
input_files <- unlist(strsplit(paste(c(opt$options$results, opt$args), collapse=","), ","))
input_files <- input_files[file.exists(input_files)]

if (length(input_files) == 0) {
    cat("⚠️ No valid input files provided. Exiting.\n")
    quit(save = "no", status = 0)
}

cat("Processing", length(input_files), "result file(s):\n")
print(input_files)

# -------- Helper: Safe GO analysis --------
run_go_analysis <- function(file_path, method, outdir, logfc_cutoff, pvalue_cutoff, top_n) {
    prefix <- tools::file_path_sans_ext(basename(file_path))
    cat("\n=== Processing:", prefix, "===\n")

    results <- tryCatch(read.csv(file_path), error = function(e) {
        cat("  ⚠️ Error reading file:", e$message, "\n")
        return(NULL)
    })
    if (is.null(results)) return(NULL)

    # Column setup
    colmap <- list(
        edger = list(logfc = "logFC", pval = "PValue", symbol = "Symbol"),
        methylkit = list(logfc = "meth.diff", pval = "qvalue", symbol = "SYMBOL")
    )[[method]]

    if (is.null(colmap) || !all(unlist(colmap) %in% colnames(results))) {
        cat("  ⚠️ Missing required columns in", file_path, "\n")
        return(NULL)
    }

    filtered <- results %>%
        filter(abs(.data[[colmap$logfc]]) >= logfc_cutoff, .data[[colmap$pval]] < pvalue_cutoff) %>%
        arrange(.data[[colmap$pval]]) %>%
        head(top_n)

    if (nrow(filtered) == 0) {
        msg <- paste0("No significant genes found in ", prefix, ". Skipping GO analysis.\n")
        cat("  ⚠️ ", msg, "\n")
        writeLines(msg, file.path(outdir, paste0(prefix, "_no_significant_genes.txt")))
        # Create empty placeholder plot to satisfy Nextflow
        png(file.path(outdir, paste0(prefix, "_gochord_plot.png"))); plot.new(); text(0.5,0.5,"No significant genes"); dev.off()
        return(NULL)
    }

    cat("  → Significant genes:", nrow(filtered), "\n")

    genes <- unique(filtered[[colmap$symbol]])
    go_enrichment <- tryCatch({
        enrichGO(
            gene = genes,
            OrgDb = org.Hs.eg.db,
            keyType = "SYMBOL",
            ont = "BP",
            pAdjustMethod = "BH",
            pvalueCutoff = 0.05,
            qvalueCutoff = 0.2
        )
    }, error = function(e) {
        cat("  ⚠️ enrichGO failed:", e$message, "\n")
        return(NULL)
    })

    if (is.null(go_enrichment) || nrow(go_enrichment@result) == 0) {
        msg <- paste0("No enriched GO terms found for ", prefix, ".\n")
        cat("  ⚠️ ", msg, "\n")
        writeLines(msg, file.path(outdir, paste0(prefix, "_no_enriched_terms.txt")))
        # Create placeholder plot
        png(file.path(outdir, paste0(prefix, "_gochord_plot.png"))); plot.new(); text(0.5,0.5,"No enriched GO terms"); dev.off()
        return(NULL)
    }

    # Save results
    write.csv(go_enrichment@result,
              file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")),
              row.names = FALSE)
    cat("  ✅ Saved GO enrichment results for", prefix, "\n")

    # ---- GOChord Plot ----
    tryCatch({
        png(file.path(outdir, paste0(prefix, "_gochord_plot.png")), width = 16.5, height = 14, units = "in", res = 300)
        GOChord(go_enrichment@result, space = 0.02)
        dev.off()
    }, error = function(e) {
        cat("  ⚠️ GOChord plotting failed:", e$message, "\n")
        # Generate fallback plot
        png(file.path(outdir, paste0(prefix, "_gochord_plot.png"))); plot.new(); text(0.5,0.5,"Plot failed"); dev.off()
    })
}

# -------- Run all --------
for (f in input_files) {
    run_go_analysis(
        f,
        method = opt$options$method,
        outdir = opt$options$output,
        logfc_cutoff = opt$options$logfc_cutoff,
        pvalue_cutoff = opt$options$pvalue_cutoff,
        top_n = opt$options$top_n
    )
}

cat("\n✅ All GO analyses completed (including skipped cases).\n")
quit(save = "no", status = 0)
fault= %default]", metavar="NUMBER"),
    make_option(c("--logfc_cutoff"), type="double", default=0.5,
                help="Log2 fold change cutoff [default= %default]", metavar="NUMBER"),
    make_option(c("--pvalue_cutoff"), type="double", default=0.05,
                help="P-value cutoff [default= %default]", metavar="NUMBER"),
    make_option(c("--method"), type="character", default="edger",
                help="Analysis method (edger or methylkit) [default= %default]", metavar="STRING")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser, positional_arguments = TRUE)

# -------- Handle multiple input files --------
if (is.null(opt$options$results) && length(opt$args) == 0) {
    stop("Error: No input files provided to --results")
}

# Accept either --results file1 file2 ... OR --results='file1,file2'
input_files <- unlist(strsplit(paste(c(opt$options$results, opt$args), collapse=","), ","))

cat("Processing", length(input_files), "result file(s):\n")
print(input_files)

# -------- Helper: safe GO analysis --------
run_go_analysis <- function(file_path, method, outdir, logfc_cutoff, pvalue_cutoff, top_n) {
    prefix <- tools::file_path_sans_ext(basename(file_path))
    cat("\n=== Processing:", prefix, "===\n")

    if (!file.exists(file_path)) {
        cat("File not found:", file_path, "\n")
        return(NULL)
    }

    results <- tryCatch(read.csv(file_path), error = function(e) {
        cat("Error reading file:", e$message, "\n")
        return(NULL)
    })
    if (is.null(results)) return(NULL)

    # Select correct columns
    if (method == "edger") {
        logfc_col <- "logFC"
        pvalue_col <- "PValue"
        symbol_col <- "Symbol"
    } else if (method == "methylkit") {
        logfc_col <- "meth.diff"
        pvalue_col <- "qvalue"
        symbol_col <- "SYMBOL"
    } else {
        cat("Unknown method:", method, "\n")
        return(NULL)
    }

    if (!all(c(logfc_col, pvalue_col, symbol_col) %in% colnames(results))) {
        cat("Missing required columns in", file_path, "\n")
        return(NULL)
    }

    filtered_results <- results %>%
        filter(abs(!!sym(logfc_col)) >= logfc_cutoff, !!sym(pvalue_col) < pvalue_cutoff) %>%
        arrange(!!sym(pvalue_col)) %>%
        head(top_n)

    if (nrow(filtered_results) == 0) {
        msg <- paste0("No significant genes found in ", prefix, ". Skipping GO analysis.\n")
        cat(msg)
        writeLines(msg, file.path(outdir, paste0(prefix, "_no_significant_genes.txt")))
        return(NULL)
    }

    genes <- filtered_results[[symbol_col]]
    cat("Number of significant genes:", length(genes), "\n")

    go_enrichment <- tryCatch({
        enrichGO(
            gene = genes,
            OrgDb = org.Hs.eg.db,
            keyType = "SYMBOL",
            ont = "BP",
            pAdjustMethod = "BH",
            pvalueCutoff = 0.05,
            qvalueCutoff = 0.2
        )
    }, error = function(e) {
        cat("Error in enrichGO:", e$message, "\n")
        return(NULL)
    })

    if (is.null(go_enrichment) || nrow(go_enrichment@result) == 0) {
        msg <- paste0("No enriched GO terms found for ", prefix, ".\n")
        cat(msg)
        writeLines(msg, file.path(outdir, paste0(prefix, "_no_enriched_terms.txt")))
        return(NULL)
    }

    write.csv(go_enrichment@result,
              file.path(outdir, paste0(prefix, "_go_enrichment_results.csv")),
              row.names = FALSE)

    cat("Saved enrichment results for", prefix, "\n")

    # Prepare GOChord data
    chord_data <- data.frame(
        Category = go_enrichment@result$Description[1:min(10, nrow(go_enrichment@result))],
        Genes = sapply(go_enrichment@result$geneID[1:min(10, nrow(go_enrichment@result))],
                       function(x) paste(strsplit(x, "/")[[1]], collapse = ","))
    )

    chord_data$logFC <- sapply(strsplit(chord_data$Genes, ","), function(x) {
        mean(filtered_results[[logfc_col]][match(x, filtered_results[[symbol_col]])], na.rm = TRUE)
    })

    genes_unique <- unique(unlist(strsplit(chord_data$Genes, ",")))
    mat <- matrix(0, nrow = length(genes_unique), ncol = nrow(chord_data))
    rownames(mat) <- genes_unique
    colnames(mat) <- chord_data$Category
    for (i in seq_len(nrow(chord_data))) {
        mat[strsplit(chord_data$Genes[i], ",")[[1]], i] <- 1
    }
    mat <- cbind(mat, logFC = filtered_results[[logfc_col]][match(rownames(mat), filtered_results[[symbol_col]])])

    # Plot GOChord safely
    safe_plot <- function(file, type) {
        tryCatch({
            if (type == "png")
                png(file, width = 16.5, height = 14, units = "in", res = 300)
            else
                svg(file, width = 36, height = 36)
            par(mar = c(5, 5, 5, 5))
            GOChord(mat, space = 0.02, gene.order = 'logFC', gene.space = 0.25, gene.size = 5, process.label = 10)
            dev.off()
        }, error = function(e) {
            cat("Error in GOChord plot for", prefix, ":", e$message, "\n")
        })
    }

    safe_plot(file.path(outdir, paste0(prefix, "_gochord_plot.png")), "png")
    safe_plot(file.path(outdir, paste0(prefix, "_gochord_plot.svg")), "svg")
    cat("Plots saved for", prefix, "\n")
}

# -------- Run for all files --------
for (f in input_files) {
    run_go_analysis(
        f,
        method = opt$options$method,
        outdir = opt$options$output,
        logfc_cutoff = opt$options$logfc_cutoff,
        pvalue_cutoff = opt$options$pvalue_cutoff,
        top_n = opt$options$top_n
    )
}

cat("\nAll GO analyses completed successfully.\n")
