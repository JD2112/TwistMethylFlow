#!/usr/bin/env Rscript

# Clinical DMR Detail Plotting (High-Fidelity NanoMethViz Style)
# Optimized for Grouped Trends, Smoothing, and Aggregate Heatmaps

suppressPackageStartupMessages({
    library(Gviz)
    library(GenomicRanges)
    library(rtracklayer)
    library(dplyr)
})

# Disable strict UCSC chromosome name enforcement to allow custom GTF contigs (e.g., KI270728.1)
options(ucscChromosomeNames=FALSE)

# 1. Base R Argument Parsing
args <- commandArgs(trailingOnly = TRUE)
parse_args <- function(args) {
    arg_list <- list(
        padding = 10000,
        genome = "hg38",
        output = "top_dmr_detail_plot.png"
    )
    for (i in seq(1, length(args), by=2)) {
        if (i > length(args)) break
        key <- gsub("--", "", args[i])
        val <- args[i+1]
        if (key == "padding") val <- as.integer(val)
        arg_list[[key]] <- val
    }
    return(arg_list)
}

opt <- parse_args(args)

if (is.null(opt$top_gene_tsv) || is.null(opt$coverage_files) || is.null(opt$sample_sheet)) {
    cat("Usage: generate_dmr_plots.R --top_gene_tsv <tsv> --coverage_files <files> --sample_sheet <csv> --gtf <gtf> --genome <genome>\n")
    quit(save="no", status=1)
}

# 2. Load Metadata and Sample Sheet
meta_df <- read.table(opt$top_gene_tsv, sep="\t", header=TRUE, stringsAsFactors=FALSE)

if (nrow(meta_df) == 0) {
    cat("Warning: No metadata found (empty result set). Creating placeholder plot and exiting.\n")
    png(opt$output, width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No significant DMRs to plot", cex=1.5)
    dev.off()
    quit(save="no", status=0)
}

gene_meta <- as.list(meta_df[1,])

# Load Group Info
samplesheet <- read.csv(opt$sample_sheet, stringsAsFactors=FALSE)
# Some cleanup for ID matching
samplesheet$sample_id <- as.character(samplesheet$sample_id)

target_chr <- as.character(gene_meta$chr)
dmr_start <- as.integer(gene_meta$dmr_start)
dmr_end <- as.integer(gene_meta$dmr_end)
gene_symbol <- as.character(gene_meta$symbol)

# Padding-adjusted viewport
view_start <- max(1, dmr_start - opt$padding)
view_end <- dmr_end + opt$padding

# 3. Load Methylation Coverage Files (BedGraphs) and Map to Groups
cov_files <- unlist(strsplit(opt$coverage_files, ","))

# Get group info from samplesheet
# Map file basenames to sample_ids to get groups
get_sample_info <- function(path) {
    fname <- basename(path)
    sid <- samplesheet$sample_id[sapply(samplesheet$sample_id, function(x) grepl(x, fname))][1]
    group <- samplesheet$group[samplesheet$sample_id == sid][1]
    return(list(id = sid, group = group))
}

cat("Loading sample methylation data...\n")
# 1. Read all files and extract scores
all_gr_list <- lapply(cov_files, function(f) {
    info <- get_sample_info(f)
    # Use strict awk column matching to avoid grep accidentally matching coordinates/scores from other chromosomes
    cmd <- sprintf("awk -F'\\t' '$1 == \"%s\" && $2 >= %d && $3 <= %d' %s", target_chr, view_start - 500, view_end + 500, f)
    data <- tryCatch({ read.table(pipe(cmd), sep="\t", stringsAsFactors=FALSE) }, error = function(e) return(NULL))
    if (is.null(data) || nrow(data) == 0) return(NULL)
    colnames(data) <- c("chr", "start", "end", "score")
    gr <- GRanges(data$chr, IRanges(data$start, data$end), score = data$score)
    mcols(gr)[[info$id]] <- data$score # Assign score to sample-named column
    gr$score <- NULL # Remove generic score column
    return(list(gr = gr, info = info))
})
all_gr_list <- all_gr_list[!sapply(all_gr_list, is.null)]

if (length(all_gr_list) == 0) {
    cat("Warning: No coverage data found in the specified region. Creating placeholder plot.\n")
    png(opt$output, width=800, height=600)
    plot(1, type="n", axes=FALSE, xlab="", ylab="")
    text(1, 1, "No coverage data available for this DMR", cex=1.5)
    dev.off()
    quit(save="no", status=0)
}

# 2. Align all samples to a common set of CpG sites (Wide Format)
# Use unique sites across all samples
all_sites <- unique(do.call(c, lapply(all_gr_list, function(x) granges(x$gr))))
# Build the data matrix column by column
for (i in seq_along(all_gr_list)) {
    samp_gr <- all_gr_list[[i]]$gr
    sid <- all_gr_list[[i]]$info$id
    hits <- findOverlaps(all_sites, samp_gr)
    mcols(all_sites)[[sid]] <- NA
    mcols(all_sites)[[sid]][queryHits(hits)] <- mcols(samp_gr)[[sid]][subjectHits(hits)]
}

# 3. Prepare Grouping Vector
sample_ids <- sapply(all_gr_list, function(x) x$info$id)
sample_groups <- sapply(all_gr_list, function(x) x$info$group)
names(sample_groups) <- sample_ids

# Filter out samples that are completely NA in this genomic window to avoid Gviz groups length mismatch
data_matrix <- as.matrix(mcols(all_sites))
non_na_samples <- colnames(data_matrix)[colSums(!is.na(data_matrix)) > 0]
if (length(non_na_samples) < length(sample_ids)) {
    dropped <- setdiff(sample_ids, non_na_samples)
    cat(paste("Warning: Dropping samples with no coverage in this window:", paste(dropped, collapse=", "), "\n"))
    mcols(all_sites) <- mcols(all_sites)[, non_na_samples, drop=FALSE]
    sample_groups <- sample_groups[non_na_samples]
    sample_ids <- non_na_samples
}

# 4. Gviz Tracks Initialization
axis_track <- GenomeAxisTrack()
ideo_track <- tryCatch({
    IdeogramTrack(genome = opt$genome, chromosome = target_chr)
}, error = function(e) NULL)

# 5. Gene Track with RefSeq Accession IDs
gene_track <- NULL
if (!is.null(opt$gtf) && file.exists(opt$gtf)) {
    cat("Loading gene models from GTF...\n")
    gtf_gr <- import(opt$gtf, format="gtf", genome=opt$genome, 
                     which=GRanges(target_chr, IRanges(view_start, view_end)))
    
    if (length(gtf_gr) > 0) {
        # Filter for exons only to avoid plotting overlapping CDS/UTR/transcript features separately
        if ("type" %in% colnames(mcols(gtf_gr))) {
            gtf_gr <- gtf_gr[gtf_gr$type == "exon"]
        }
        
        # Map standard GTF columns to Gviz-expected names
        if ("gene_id" %in% colnames(mcols(gtf_gr))) {
            gtf_gr$gene <- gtf_gr$gene_id
        }
        if ("transcript_id" %in% colnames(mcols(gtf_gr))) {
            gtf_gr$transcript <- gtf_gr$transcript_id
        }
        if ("exon_id" %in% colnames(mcols(gtf_gr))) {
            gtf_gr$exon <- gtf_gr$exon_id
        }
        if ("gene_name" %in% colnames(mcols(gtf_gr))) {
            gtf_gr$symbol <- gtf_gr$gene_name
        }

        # Select NM_ ids for labels
        if ("transcript_id" %in% colnames(mcols(gtf_gr))) {
            gtf_gr$id <- gtf_gr$transcript_id
        }
        gene_track <- GeneRegionTrack(gtf_gr, genome = opt$genome, chromosome = target_chr, 
                                     name = "RefSeq Models",
                                     showId = TRUE, geneSymbol = TRUE,
                                     collapseTranscripts = "meta",
                                     shape = "arrow", fill = "#EAEAEA", col = "#444444",
                                     fontsize.group = 8)
    }
}

# 6. CpG Site Annotation Track
cpg_sites <- all_sites
mcols(cpg_sites) <- NULL # Clear data for annotation track
cpg_track <- AnnotationTrack(cpg_sites, name = "CpG Sites", 
                             col = "black", fill = "black", 
                             shape = "box", stacking = "dense")

# 7. Aggregate Trend Track (Grouped Lines)
# Red/Blue Color Scheme
groups_present <- unique(sample_groups)
group_colors <- c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00")
names(group_colors) <- groups_present[1:min(length(groups_present), 5)]

# Plot individual points + smoothed trend line per group
trend_track <- DataTrack(all_sites, 
                         groups = sample_groups,
                         name = "Methylation %",
                         type = c("smooth", "p"),
                         legend = TRUE,
                         ylim = c(0, 100),
                         col = group_colors,
                         alpha = 0.5,
                         cex = 0.5)

# 8. Aggregated Heatmaps (Bead tracks, one per group)
heatmap_tracks <- lapply(groups_present, function(g) {
    # Get columns belonging to this group
    g_samples <- names(sample_groups)[sample_groups == g]
    # Subset columns for this group
    g_data <- all_sites
    mcols(g_data) <- mcols(all_sites)[, g_samples, drop=FALSE]
    
    dt <- DataTrack(g_data, 
              name = g,
              type = "heatmap",
              ylim = c(0, 100),
              showSampleNames = FALSE,
              col = c("white", group_colors[g]))
    displayPars(dt)$size <- 1.0 # Thicker beads
    return(dt)
})

# 9. Highlight Track (Green shading for DMR)
# Set relative sizes on components
displayPars(axis_track)$size <- 0.5
displayPars(trend_track)$size <- 2.5
if (!is.null(cpg_track)) displayPars(cpg_track)$size <- 0.3
if (!is.null(gene_track)) displayPars(gene_track)$size <- 1.2

inner_tracks <- c(list(axis_track, trend_track, cpg_track), heatmap_tracks, list(gene_track))
inner_tracks <- inner_tracks[!sapply(inner_tracks, is.null)]

highlight_track <- HighlightTrack(trackList = inner_tracks,
                                 start = dmr_start, end = dmr_end,
                                 chromosome = target_chr,
                                 fill = "#EAFFEA", col = "#2E8B57", alpha = 0.3)

final_tracks <- c(list(ideo_track), list(highlight_track))
final_tracks <- final_tracks[!sapply(final_tracks, is.null)]

if (!is.null(ideo_track)) displayPars(ideo_track)$size <- 0.6

# 10. Plotting
png(opt$output, width = 1400, height = 1200 + 150 * length(groups_present), res = 150)

plotTracks(final_tracks, 
           from = view_start, to = view_end, 
           main = paste("Clinical DMR Detail Analysis:", gene_symbol),
           cex.main = 1.3,
           background.title = "#003366",
           col.title = "white")

dev.off()
cat("NanoMethViz-style plotting complete!\n")
