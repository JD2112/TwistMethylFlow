#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(optparse)
    library(dplyr)
    library(org.Hs.eg.db)
    library(jsonlite)
})

option_list <- list(
    make_option(c("--results"), type="character", default=NULL, help="Path to the annotated results file", metavar="FILE"),
    make_option(c("--output"), type="character", default=".", help="Output directory", metavar="DIR"),
    make_option(c("--method"), type="character", default="edger", help="Analysis method"),
    make_option(c("--promoter_dist"), type="integer", default=2000, help="Promoter distance"),
    make_option(c("--enhancer_dist"), type="integer", default=10000, help="Enhancer distance")
)

opt <- parse_args(OptionParser(option_list=option_list))
prefix <- tools::file_path_sans_ext(basename(opt$results))
outdir <- opt$output
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Load data with robust separator detection
raw_df <- read.csv(opt$results, sep=",", check.names=FALSE, stringsAsFactors=FALSE)
if (ncol(raw_df) <= 1) {
    raw_df <- read.csv(opt$results, sep="\t", check.names=FALSE, stringsAsFactors=FALSE)
}
df <- raw_df

# Clean empty/NA column names to prevent dplyr::mutate crashes
valid_names <- colnames(df)
valid_names[is.na(valid_names)] <- paste0("Unknown_", seq_along(valid_names)[is.na(valid_names)])
valid_names[valid_names == ""] <- paste0("Unnamed_", seq_along(valid_names)[valid_names == ""])
colnames(df) <- valid_names

# 1. Column Identification
all_cols <- colnames(df)
if (opt$method == "edger") {
    logfc_col <- all_cols[grep("logFC", all_cols, ignore.case=TRUE)][1]
    pval_col  <- all_cols[grep("PValue", all_cols, ignore.case=TRUE)][1]
    symbol_col <- all_cols[grep("Symbol", all_cols, ignore.case=TRUE)][1]
    dist_col   <- all_cols[grep("Distance|dist_to_feature", all_cols, ignore.case=TRUE)][1]
} else if (opt$method == "dss") {
    logfc_col <- all_cols[grep("^diff$|^mu", all_cols, ignore.case=TRUE)][1]
    pval_col  <- all_cols[grep("fdr|pvalue", all_cols, ignore.case=TRUE)][1]
    symbol_col <- all_cols[grep("Symbol", all_cols, ignore.case=TRUE)][1]
    dist_col   <- all_cols[grep("Distance|dist_to_feature", all_cols, ignore.case=TRUE)][1]
} else {
    logfc_col <- all_cols[grep("meth.diff|diff", all_cols, ignore.case=TRUE)][1]
    pval_col  <- all_cols[grep("qvalue", all_cols, ignore.case=TRUE)][1]
    symbol_col <- all_cols[grep("SYMBOL", all_cols, ignore.case=TRUE)][1]
    dist_col   <- all_cols[grep("Distance|dist.to.feature", all_cols, ignore.case=TRUE)][1]
}

# 2. Region Annotation
cat("Performing region annotation...\n")
if (!is.na(dist_col)) {
    df <- df %>% mutate(Region = case_when(
        abs(as.numeric(!!sym(dist_col))) <= opt$promoter_dist ~ "Promoter",
        abs(as.numeric(!!sym(dist_col))) <= opt$enhancer_dist ~ "Enhancer/Distal",
        TRUE ~ "Intergenic"
    ))
} else {
    df$Region <- "Unknown"
}

# 3. Coordinate Identification (Robust discovery for visualization)
cat("Identifying coordinate columns...\n")
chrom_col <- all_cols[grep("^chr$|^seqnames$|^chromosome$", all_cols, ignore.case=TRUE)][1]
start_col <- all_cols[grep("^start$|^pos$|^position$|^locus$|^location$|^bp$", all_cols, ignore.case=TRUE)][1]
end_col   <- all_cols[grep("^end$", all_cols, ignore.case=TRUE)][1]

if (is.na(chrom_col)) chrom_col <- all_cols[grep("chr", all_cols, ignore.case=TRUE)][1]
if (is.na(start_col)) start_col <- all_cols[grep("start|pos|locus|location", all_cols, ignore.case=TRUE)][1]
if (is.na(end_col))   end_col   <- all_cols[grep("end", all_cols, ignore.case=TRUE)][1]
if (is.na(end_col))   end_col   <- start_col

# 4. Gene Prioritization Score
cat("Calculating gene prioritization scores...\n")
df <- df %>% mutate(Rank_Score = as.numeric(abs(!!sym(logfc_col)) * -log10(!!sym(pval_col) + 1e-10)))

# 5. Global Metrics (Hyper/Hypo counts)
# Assuming logFC > 0 is Hyper compared to reference
hyper_count <- nrow(df %>% filter(!!sym(logfc_col) > 0, !!sym(pval_col) < 0.05))
hypo_count  <- nrow(df %>% filter(!!sym(logfc_col) < 0, !!sym(pval_col) < 0.05))

metrics_list <- list(
    total_significant = nrow(df %>% filter(!!sym(pval_col) < 0.05)),
    hypermethylated = hyper_count,
    hypomethylated = hypo_count,
    method = opt$method
)
write(toJSON(metrics_list, auto_unbox=TRUE), file.path(outdir, "epigenetic_metrics.json"))

# 6. Handle duplicates (multiple regions per gene) - keep most significant per gene
prioritized <- df %>%
    group_by(!!sym(symbol_col)) %>%
    arrange(desc(Rank_Score)) %>%
    dplyr::slice(1) %>%
    ungroup() %>%
    arrange(desc(Rank_Score))

# 7. Clinical Annotation (OMIM & gnomAD)
cat("Adding Clinical Annotations (OMIM & gnomAD)...\n")
symbols <- unique(as.character(prioritized[[symbol_col]]))
symbols <- symbols[!is.na(symbols) & symbols != ""]

if (length(symbols) > 0) {
    mapping <- tryCatch({
        select(org.Hs.eg.db, keys=symbols, columns=c("ENTREZID", "OMIM", "MAP"), keytype="SYMBOL")
    }, error = function(e) {
        cat("Warning: OMIM mapping failed -", e$message, "\n")
        data.frame(SYMBOL=character(), ENTREZID=character(), OMIM=character(), MAP=character())
    })
} else {
    mapping <- data.frame(SYMBOL=character(), ENTREZID=character(), OMIM=character(), MAP=character())
}

# Explicitly cast to character to prevent left_join crashing if the input CSV was empty (read as logical)
prioritized[[symbol_col]] <- as.character(prioritized[[symbol_col]])

prioritized <- prioritized %>%
    left_join(mapping %>% group_by(SYMBOL) %>% 
                summarize(ENTREZID = paste(unique(na.omit(ENTREZID)), collapse=", "),
                          OMIM_IDs = paste(unique(na.omit(OMIM)), collapse=", "),
                          Location = dplyr::first(na.omit(MAP))), 
              by=setNames("SYMBOL", symbol_col))

# Add interactive links and stabilize Coordinates
prioritized <- prioritized %>%
    mutate(
        chr = as.character(!!sym(chrom_col)),
        start = as.integer(!!sym(start_col)),
        end = as.integer(!!sym(end_col)),
        Coordinates = paste0(chr, ":", start, "-", end),
        OMIM = ifelse(OMIM_IDs != "", paste0("\\href{https://www.omim.org/search?search=", OMIM_IDs, "}{", OMIM_IDs, "}"), "N/A"),
        gnomAD = paste0("\\href{https://gnomad.broadinstitute.org/gene/", !!sym(symbol_col), "?dataset=gnomad_r4}{Link}")
    )

# 8. Export metadata for Top Gene
if (nrow(prioritized) > 0) {
    top_gene <- prioritized[1, ]
    meta_df <- data.frame(
        symbol = as.character(top_gene[[symbol_col]]),
        chr = as.character(top_gene$chr),
        dmr_start = as.integer(top_gene$start),
        dmr_end = as.integer(top_gene$end),
        rank_score = as.numeric(top_gene$Rank_Score)
    )
    write.table(meta_df, file.path(outdir, "top_gene_metadata.tsv"), sep="\t", row.names=FALSE, quote=FALSE)
    writeLines(as.character(top_gene[[symbol_col]]), file.path(outdir, "top_gene_symbol.txt"))
} else {
    # Write empty dummy files to satisfy Nextflow output expectations
    write.table(data.frame(symbol=character(), chr=character(), dmr_start=integer(), dmr_end=integer(), rank_score=numeric()), 
                file.path(outdir, "top_gene_metadata.tsv"), sep="\t", row.names=FALSE, quote=FALSE)
    writeLines("", file.path(outdir, "top_gene_symbol.txt"))
}

# 9. Final CSV Export
write.csv(df, file.path(outdir, paste0(prefix, "_region_annotated.csv")), row.names=F)
write.csv(prioritized, file.path(outdir, paste0(prefix, "_gene_prioritized.csv")), row.names=F)
