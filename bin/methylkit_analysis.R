#!/usr/bin/env Rscript

cat("Starting methylkit_analysis.R script\n")

suppressPackageStartupMessages({
  library(methylKit)
  library(readr)
  library(stringr)
  library(org.Hs.eg.db)
  library(genomation)
  library(optparse)
})

option_list <- list(
    make_option(c("-f", "--coverage_files"), type="character", default=NULL, 
                help="Comma-separated list of Bismark coverage files", metavar="FILES"),
    make_option(c("-d", "--design"), type="character", default=NULL, 
                help="Design file path (CSV format)", metavar="FILE"),
    make_option(c("-c", "--compare"), type="character", default="all", 
                help="Comparison string (e.g., 'GroupA_vs_GroupB') or 'all' for all pairwise comparisons [default= %default]", metavar="STRING"),
    make_option(c("-o", "--output"), type="character", default=".", 
                help="Output directory [default= %default]", metavar="DIR"),
    make_option(c("-t", "--threshold"), type="integer", default=3, 
                help="Coverage threshold for filtering [default= %default]", metavar="INTEGER"),
    make_option(c("--refseq"), type="character", default=NULL, 
                help="Path to RefSeq file", metavar="FILE"),
    make_option(c("--assembly"), type="character", default="hg19", 
                help="Genome assembly (hg19 or hg38) [default= %default]", metavar="STRING"),
    make_option(c("--mc_cores"), type="integer", default=1, 
                help="Number of cores to use for parallel processing [default= %default]", metavar="INTEGER"),
    make_option(c("--diff"), type="numeric", default=0.05, 
                help="Difference in methylation for getMethylDiff [default= %default]", metavar="NUMERIC"),
    make_option(c("--qvalue"), type="numeric", default=0.1, 
                help="Q-value threshold for getMethylDiff [default= %default]", metavar="NUMERIC")
)

opt <- parse_args(OptionParser(option_list=option_list))

cat("Script arguments:\n")
print(opt)

if (is.null(opt$coverage_files) || is.null(opt$design)) {
  stop("Both coverage_files and design file must be provided")
}

if (!file.exists(opt$design)) {
  stop(paste("Design file does not exist:", opt$design))
}

coverage_files <- unlist(strsplit(opt$coverage_files, ","))
for (file in coverage_files) {
  if (!file.exists(file)) {
    stop(paste("Coverage file does not exist:", file))
  }
}

# Read design file
cat("Reading design file...\n")
design <- tryCatch({
  read_csv(opt$design)
}, error = function(e) {
  cat(paste("Error reading design file:", e$message, "\n"))
  stop("Failed to read design file")
})
cat("Design file contents:\n")
print(design)

# Process coverage files
cat("Extracting sample IDs from coverage files...\n")
id_col <- if("sample_id" %in% colnames(design)) "sample_id" else "sample"
available_ids <- as.character(design[[id_col]])

sample_names <- unname(sapply(basename(coverage_files), function(f) {
    # Match the ID from design file that is a prefix of the filename
    match_idx <- which(sapply(available_ids, function(id) startsWith(f, id)))
    if (length(match_idx) > 0) {
        # Return the longest match if multiple exist (e.g. "WT" and "WT-1")
        matches <- available_ids[match_idx]
        return(matches[which.max(nchar(matches))])
    }
    return(NA)
}))

# Reorder design to match coverage_files order
cat("Reordering design to match coverage files...\n")
design <- design[match(sample_names, design[[id_col]]), ]

if (any(is.na(sample_names)) || any(is.na(design[[id_col]]))) {
    cat("Error: Mapping between coverage files and design file failed.\n")
    cat("Filenames:\n")
    print(basename(coverage_files))
    cat("Extracted sample names:\n")
    print(sample_names)
    cat("Available IDs in design file:\n")
    print(available_ids)
    stop("Sample mismatch between files and design")
}

cat("Coverage files:\n")
print(coverage_files)
cat("Sample names:\n")
print(sample_names)
cat("Reordered design:\n")
print(design)

# Create methylKit object
cat("Creating methylKit object...\n")
myObj <- tryCatch({
    methRead(
        location = as.list(coverage_files),
        sample.id = as.list(sample_names),
        assembly = opt$assembly,
        treatment = as.numeric(factor(design$group)) - 1,
        context = "CpG",
        pipeline = "bismarkCoverage",
        mincov = opt$threshold
    )
}, error = function(e) {
    cat(paste("Error in methRead:", e$message, "\n"))
    cat("Trying to read the first few lines of each coverage file:\n")
    for (file in coverage_files) {
        cat(paste("File:", file, "\n"))
        tryCatch({
            print(head(read.table(gzfile(file), header=FALSE, nrows=5)))
        }, error = function(e) {
            cat(paste("Error reading file:", e$message, "\n"))
        })
    }
    stop("Error in methRead. See above for details.")
})

cat("MethylKit object created successfully\n")
print(summary(myObj))

# Filtering and normalization
cat("Starting filtering process...\n")
filtered.myObj <- filterByCoverage(myObj, 
                                   lo.count = opt$threshold, 
                                   lo.perc = NULL, 
                                   hi.count = NULL, 
                                   hi.perc = 99.9)

cat("Filtered object summary:\n")
print(summary(filtered.myObj))
cat("Number of sites after filtering:", nrow(filtered.myObj[[1]]), "\n")

cat("Starting normalization process...\n")
myobj.filt.norm <- normalizeCoverage(filtered.myObj, method = "median")

cat("Normalized object summary:\n")
print(summary(myobj.filt.norm))
cat("Number of sites after normalization:", nrow(myobj.filt.norm[[1]]), "\n")

# Merge data
cat("Starting data merging process...\n")
meth1 <- unite(myobj.filt.norm, destrand=FALSE)

cat("United object summary:\n")
print(summary(meth1))
print(head(meth1))
cat("Number of sites in meth1:", nrow(meth1), "\n")

if (nrow(meth1) < 100) {
    cat("Warning: Very few sites (", nrow(meth1), ") remain after filtering and merging.\n")
    cat("This may cause issues in downstream analysis.\n")
    cat("Consider adjusting your filtering criteria.\n")
}

if (length(unique(design$group)) < 2) {
    stop("Error: At least two distinct groups are required for differential methylation analysis.")
}

# Calculate differential methylation
cat("Starting differential methylation calculation...\n")
if (opt$compare == "all") {
    groups <- unique(design$group)
    comparisons <- combn(groups, 2, simplify = FALSE)
} else {
    comparisons <- list(unlist(strsplit(opt$compare, "_vs_")))
}

for (comp in comparisons) {
    group1 <- comp[1]
    group2 <- comp[2]
    
    cat(paste("\n--- Processing Comparison:", group1, "vs", group2, "---\n"))
    
    # Subset samples for pairwise comparison
    subset_indices <- which(design$group %in% c(group1, group2))
    subset_samples <- sample_names[subset_indices]
    subset_treatment <- as.numeric(design$group[subset_indices] == group2)
    
    cat("Selected samples:", paste(subset_samples, collapse=", "), "\n")
    cat("Calculated treatment vector (0 for ref, 1 for treated):", paste(subset_treatment, collapse=", "), "\n")
    
    # Reorganize object to include only selected samples
    meth_subset <- reorganize(meth1, sample.ids = subset_samples, treatment = subset_treatment)
    
    cat(paste("Calculating differential methylation for", group1, "vs", group2, "\n"))
    
    myDiff <- tryCatch({
        calculateDiffMeth(meth_subset,
                          overdispersion = "MN",
                          adjust = "BH",
                          mc.cores = opt$mc_cores)
    }, error = function(e) {
        cat("Error in calculateDiffMeth:", e$message, "\n")
        print(str(meth1))
        print(table(design$group))
        stop("Failed to calculate differential methylation")
    })

    cat("Differential methylation calculation successful\n")
    print(summary(myDiff))
    print(table(myDiff$qvalue < opt$qvalue))
    print(table(abs(myDiff$meth.diff) > opt$diff))

    # Get differentially methylated bases
    myDiff5p <- getMethylDiff(myDiff, difference=opt$diff, qvalue=opt$qvalue)
    cat("Number of differentially methylated sites:", nrow(myDiff5p), "\n")
    if(nrow(myDiff5p) == 0) {
        cat("Warning: No differentially methylated sites found with current criteria.\n")
        cat("Consider adjusting the 'diff' and 'qvalue' parameters.\n")
        next  # Skip to the next comparison or end the script
    }
    print(head(myDiff5p))

    # Annotation
    cat("Starting annotation process...\n")
    tryCatch({
        if (!is.null(opt$refseq)) {
            cat(paste("Using provided RefSeq file:", opt$refseq, "\n"))
            gene.obj <- readTranscriptFeatures(opt$refseq)
        } else {
            cat("Downloading default RefSeq file...\n")
            url <- "https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg38_RefSeq.bed.gz/download"
            destfile <- "hg38_RefSeq.bed.gz"
            download.file(url, destfile)
            gene.obj <- readTranscriptFeatures(destfile)
        }

        cat("Gene object summary:\n")
        print(summary(gene.obj))

        myDiff5p.annot <- suppressWarnings(annotateWithGeneParts(as(myDiff5p, "GRanges"), gene.obj))
        dist_to_tss <- myDiff5p.annot@dist.to.TSS

        dist_to_tss_df <- data.frame(
            dist_to_feature = dist_to_tss$dist.to.feature,
            feature_name = dist_to_tss$feature.name,
            feature_strand = dist_to_tss$feature.strand,
            target_row = dist_to_tss$target.row
        )

        myDiff5p_df <- as.data.frame(myDiff5p)
        myDiff5p_annotated <- myDiff5p_df
        myDiff5p_annotated$target_row <- 1:nrow(myDiff5p_annotated)
        myDiff5p_data <- getData(myDiff5p_annotated)
        myDiff5p_data_annotated <- merge(myDiff5p_data, dist_to_tss_df, by = "target_row", all.x = TRUE)

        # Get the annotation
        cat("Getting annotation from org.Hs.eg.db\n")
        key <- gsub("\\..*", "", myDiff5p_data_annotated$feature_name) 
        anno <- AnnotationDbi::select(org.Hs.eg.db, 
                                      keys=key,
                                      columns=c("SYMBOL","GENENAME"),
                                      keytype="REFSEQ")

        cat("Annotation result summary:\n")
        print(summary(anno))

        # Combine all information
        DMC.final.annot <- cbind(as.data.frame(myDiff5p_data_annotated), anno)

        cat("Final annotation summary:\n")
        print(summary(DMC.final.annot))

        # Write results
        output_name <- file.path(opt$output, paste0("MethylKit_", group1, "_vs_", group2, ".csv"))
        write.csv(DMC.final.annot, file = output_name, quote = FALSE)
        cat(paste("Results written to:", output_name, "\n"))
    }, error = function(e) {
        cat(paste("Error in annotation process:", e$message, "\n"))
        cat("myDiff5p summary:\n")
        print(summary(myDiff5p))
        cat("myDiff5p.annot summary (if available):\n")
        if(exists("myDiff5p.annot")) print(summary(myDiff5p.annot))
        cat("Gene object summary (if available):\n")
        if(exists("gene.obj")) print(summary(gene.obj))
        cat("Annotation process failed. See above for details.\n")
    })
}

# Write version information
version_file <- file.path(opt$output, "versions.txt")
cat(paste0("methylKit version: ", packageVersion("methylKit"), "\n"),
    file = version_file)
cat(paste("Version information written to:", version_file, "\n"))

cat("methylkit_analysis.R script completed successfully\n")