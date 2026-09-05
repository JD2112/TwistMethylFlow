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

# Enforce deterministic random sampling and clustering
set.seed(42)

option_list <- list(
    make_option(c("-f", "--coverage_files"), type="character", default=NULL, 
                help="Comma-separated list of Bismark coverage files", metavar="FILES"),
    make_option(c("-d", "--design"), type="character", default=NULL, 
                help="Design file path (CSV format)", metavar="FILE"),
    make_option(c("-c", "--compare"), type="character", default="all", 
                help="Comparison string (e.g., 'GroupA_vs_GroupB') or 'all' for all pairwise comparisons [default= %default]", metavar="STRING"),
    make_option(c("-o", "--output"), type="character", default=".", 
                help="Output directory [default= %default]", metavar="DIR"),
    make_option(c("-t", "--threshold"), type="integer", default=10, 
                help="Coverage threshold for filtering (Article default=10) [default= %default]", metavar="INTEGER"),
    make_option(c("-b", "--bed"), type="character", default=NULL, 
                help="Optional BED file for targeted methylation analysis (Twist Bioscience target regions)", metavar="FILE"),
    make_option(c("--refseq"), type="character", default=NULL, 
                help="Path to RefSeq file", metavar="FILE"),
    make_option(c("--assembly"), type="character", default="hg19", 
                help="Genome assembly (hg19 or hg38) [default= %default]", metavar="STRING"),
    make_option(c("--mc_cores"), type="integer", default=1, 
                help="Number of cores to use for parallel processing [default= %default]", metavar="INTEGER"),
    make_option(c("--diff"), type="numeric", default=0.25, 
                help="Difference in methylation (Article default=0.25) [default= %default]", metavar="NUMERIC"),
    make_option(c("--qvalue"), type="numeric", default=0.01, 
                help="Q-value threshold (Article default=0.01) [default= %default]", metavar="NUMERIC"),
    make_option(c("--min_per_group"), type="integer", default=1, 
                help="Minimum number of samples per group to cover a site during unite [default= %default]", metavar="INTEGER")
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

# Process coverage files - align them with the design file order
cat("Aligning coverage files with the design file order...\n")
id_col <- if("sample_id" %in% colnames(design)) "sample_id" else "sample"
available_ids <- as.character(design[[id_col]])

# Create a mapping of sample_id to file path
file_map <- list()
for (f in coverage_files) {
    # Match the ID from design file that is a prefix of the filename
    match_idx <- which(sapply(available_ids, function(id) startsWith(basename(f), id)))
    if (length(match_idx) > 0) {
        # Return the longest match if multiple exist (e.g. "WT" and "WT-1")
        matches <- available_ids[match_idx]
        id <- matches[which.max(nchar(matches))]
        file_map[[id]] <- f
    }
}

# Re-order the coverage files and sample names to match the design file exactly
cat("Reordering files and names to match design file order...\n")
aligned_coverage_files <- c()
aligned_sample_names <- c()
for (id in available_ids) {
    if (is.null(file_map[[id]])) {
        stop(paste("Error: No coverage file found for sample ID:", id))
    }
    aligned_coverage_files <- c(aligned_coverage_files, file_map[[id]])
    aligned_sample_names <- c(aligned_sample_names, id)
}

coverage_files <- aligned_coverage_files
sample_names <- aligned_sample_names

# Preprocess coverage files: check for track line (common in MethylDackel output) and create temp files without it if necessary
cleaned_coverage_files <- character(length(coverage_files))
for (i in seq_along(coverage_files)) {
    f <- coverage_files[i]
    if (file.exists(f)) {
        is_gz <- grepl("\\.gz$", f)
        if (is_gz) {
            con <- gzfile(f, "r")
        } else {
            con <- file(f, "r")
        }
        first_line <- readLines(con, n=1)
        close(con)
        
        if (grepl("^track", first_line)) {
            cat(paste("Detected track line in", f, "- creating temporary cleaned file.\n"))
            tmp_f <- tempfile(pattern = basename(f))
            if (is_gz) {
                lines <- readLines(gzfile(f))
                writeLines(lines[-1], tmp_f)
            } else {
                system(paste("tail -n +2", shQuote(f), ">", shQuote(tmp_f)))
            }
            cleaned_coverage_files[i] <- tmp_f
        } else {
            cleaned_coverage_files[i] <- f
        }
    } else {
        cleaned_coverage_files[i] <- f
    }
}
coverage_files <- cleaned_coverage_files

cat("Coverage files (aligned & cleaned):\n")
print(coverage_files)
cat("Sample names (aligned):\n")
print(sample_names)
cat("Design file (order kept):\n")
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
            is_gz <- grepl("\\.gz$", file)
            con <- if(is_gz) gzfile(file) else file(file)
            print(head(read.table(con, header=FALSE, nrows=5)))
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
cat("Starting data merging process (uniting)...\n")
# Use min.per.group to allow some missing data across replicates
# This is crucial for maintaining enough sites for statistical significance
meth1 <- unite(myobj.filt.norm, destrand=FALSE, min.per.group=opt$min_per_group)

cat("United object summary:\n")
print(summary(meth1))
cat("Number of sites in meth1 (before BED filtering):", nrow(meth1), "\n")

# Targeted filtering using BED file
if (!is.null(opt$bed)) {
    cat(paste("Applying target region filtering with BED file:", opt$bed, "\n"))
    
    # Check if bed is zipped
    bed_file <- opt$bed
    if (grepl("\\.zip$", bed_file)) {
        cat("Unzipping BED file...\n")
        temp_dir <- tempdir()
        unzip(bed_file, exdir = temp_dir)
        # Find the .bed file in the unzipped content, excluding hidden macOS files
        bed_extracted <- list.files(temp_dir, pattern = "\\.bed$", full.names = TRUE)
        # Exclude hidden files starting with ._ or .
        bed_extracted <- bed_extracted[!grepl("/\\._", bed_extracted) & !grepl("/\\.", basename(bed_extracted))]
        if (length(bed_extracted) > 0) {
            bed_file <- bed_extracted[1]
        }
    }
    
    cat(paste("Reading target regions from:", bed_file, "\n"))
    # Use read.table for better robustness over genomation::readBed
    bed_data <- tryCatch({
        read.table(bed_file, header=FALSE, sep="\t", stringsAsFactors=FALSE)
    }, error = function(e) {
        cat("Error reading BED file with read.table (tab-separated). Trying with default separator.\n")
        read.table(bed_file, header=FALSE, stringsAsFactors=FALSE)
    })
    
    cat(paste("BED file read successfully. Found", nrow(bed_data), "rows and", ncol(bed_data), "columns.\n"))
    
    # Check for chromosome naming mismatch ('chr1' vs '1')
    data_chrs <- unique(meth1$chr)
    bed_chrs <- unique(bed_data[,1])
    
    cat("Sample chromosomes (first few):", paste(head(data_chrs, 3), collapse=", "), "\n")
    cat("BED chromosomes (first few):", paste(head(bed_chrs, 3), collapse=", "), "\n")
    
    has_chr_prefix_data <- any(grepl("^chr", data_chrs))
    has_chr_prefix_bed <- any(grepl("^chr", bed_chrs))
    
    if (has_chr_prefix_data != has_chr_prefix_bed) {
        cat("Detected chromosome naming mismatch. Adjusting BED file to match data...\n")
        if (has_chr_prefix_data) {
            # Add 'chr' prefix to BED
            cat("Adding 'chr' prefix to BED file chromosomes.\n")
            bed_data[,1] <- paste0("chr", bed_data[,1])
            # Handle 'chrMT' -> 'chrM' mapping common in UCSC
            bed_data[,1] <- gsub("chrMT", "chrM", bed_data[,1])
        } else {
            # Remove 'chr' prefix from BED
            cat("Removing 'chr' prefix from BED file chromosomes.\n")
            bed_data[,1] <- gsub("^chr", "", bed_data[,1])
        }
    }

    # Convert to GRanges
    targets <- GRanges(
        seqnames = bed_data[,1],
        ranges = IRanges(start = bed_data[,2], end = bed_data[,3]),
        strand = if(ncol(bed_data) >= 6) bed_data[,6] else "*"
    )
    cat("Target regions converted to GRanges successfully. Number of regions:", length(targets), "\n")
    
    # Convert to GRanges for overlap
    cat("Filtering CpG sites to keep only those within target regions...\n")
    # Manual overlap to ensure it works correctly across all methylKit versions
    meth1_gr <- as(meth1, "GRanges")
    overlaps <- findOverlaps(meth1_gr, targets)
    meth1 <- meth1[unique(queryHits(overlaps)), ]
    
    cat("Number of sites in meth1 (after BED filtering):", nrow(meth1), "\n")
}

if (nrow(meth1) < 100) {
    cat("Warning: Very few sites (", nrow(meth1), ") remain after filtering and merging.\n")
    cat("This may cause issues in downstream analysis.\n")
    cat("Consider adjusting your filtering criteria or check your BED file.\n")
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
    
    cat("Filtering meth_subset to ensure at least 2 samples per group to prevent variance calculation crash...\n")
    meth_data <- getData(meth_subset)
    
    # In methylBase, coverage columns are at 5, 8, 11, ... (3 * i + 2)
    cov_cols <- 3 * (1:length(subset_samples)) + 2
    
    group1_cols <- cov_cols[subset_treatment == 0]
    group2_cols <- cov_cols[subset_treatment == 1]
    
    if (length(group1_cols) >= 2 && length(group2_cols) >= 2) {
        group1_non_na <- rowSums(!is.na(meth_data[, group1_cols, drop=FALSE]))
        group2_non_na <- rowSums(!is.na(meth_data[, group2_cols, drop=FALSE]))
        
        valid_rows <- (group1_non_na >= 2) & (group2_non_na >= 2)
        
        if (!all(valid_rows)) {
            cat(paste("Removing", sum(!valid_rows), "CpGs that have fewer than 2 valid samples in either group...\n"))
            meth_subset <- meth_subset[valid_rows, ]
        }
    }
    
    if (nrow(meth_subset) < 100) {
        cat("Warning: Too few sites (", nrow(meth_subset), ") left for differential methylation analysis.\n")
        output_name <- file.path(opt$output, paste0("MethylKit_", group1, "_vs_", group2, ".csv"))
        write.csv(data.frame(Status="Not enough valid sites (>=2 samples/group) for statistical testing"), file = output_name, quote = FALSE, row.names=FALSE)
        next
    }
    
    cat(paste("Calculating differential methylation for", group1, "vs", group2, "\n"))
    
    myDiff <- tryCatch({
        calculateDiffMeth(meth_subset,
                          overdispersion = "MN",
                          adjust = "BH",
                          mc.cores = opt$mc_cores)
    }, error = function(e) {
        cat("Error in calculateDiffMeth with multi-cores:", e$message, "\n")
        if (opt$mc_cores > 1) {
            cat("Retrying calculateDiffMeth with mc.cores = 1 for stability...\n")
            myDiff <- tryCatch({
                calculateDiffMeth(meth_subset,
                                  overdispersion = "MN",
                                  adjust = "BH",
                                  mc.cores = 1)
            }, error = function(e_fallback) {
                cat("Error in fallback calculateDiffMeth:", e_fallback$message, "\n")
                print(str(meth1))
                print(table(design$group))
                stop("Failed to calculate differential methylation in both multi-core and fallback modes.")
            })
        } else {
            print(str(meth1))
            print(table(design$group))
            stop("Failed to calculate differential methylation")
        }
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
        output_name <- file.path(opt$output, paste0("MethylKit_", group1, "_vs_", group2, ".csv"))
        write.csv(data.frame(Status="No differentially methylated sites found with current criteria"), file = output_name, quote = FALSE, row.names=FALSE)
        next  # Skip to the next comparison or end the script
    }
    print(head(myDiff5p))

    # Annotation
    cat("Starting annotation process...\n")
    tryCatch({
        if (!is.null(opt$refseq) && file.exists(opt$refseq) && file.size(opt$refseq) > 0) {
            cat(paste("Using provided RefSeq file:", opt$refseq, "\n"))
            gene.obj <- readTranscriptFeatures(opt$refseq)
        } else {
            cat("RefSeq file not provided or not found. Attempting to download default for:", opt$assembly, "\n")
            
            # Use specific URL based on assembly
            if (opt$assembly == "hg19") {
                url <- "https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg19_RefSeq.bed.gz/download"
                destfile <- "hg19_RefSeq.bed.gz"
            } else {
                url <- "https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg38_RefSeq.bed.gz/download"
                destfile <- "hg38_RefSeq.bed.gz"
            }
            
            download_success <- tryCatch({
                # Set a timeout for the download
                options(timeout = 300)
                download.file(url, destfile, mode = "wb")
                TRUE
            }, error = function(e) {
                cat("⚠️ Download failed:", e$message, "\n")
                FALSE
            })
            
            if (download_success && file.exists(destfile) && file.size(destfile) > 100) {
                cat("Download successful. Reading transcript features...\n")
                gene.obj <- readTranscriptFeatures(destfile)
            } else {
                cat("⚠️ RefSeq acquisition failed. Annotation will be skipped.\n")
                gene.obj <- NULL
            }
        }

        if (is.null(gene.obj)) {
            # Skip the rest of the annotation but write the unannotated results
            cat("Writing results without annotation (SYMBOL column will be missing)...\n")
            output_name <- file.path(opt$output, paste0("MethylKit_", group1, "_vs_", group2, ".csv"))
            write.csv(getData(myDiff5p), file = output_name, row.names = FALSE)
            next 
        }

        cat("Gene object summary:\n")
        print(summary(gene.obj))

        # Convert Ensembl chromosome names ('1') to UCSC ('chr1') to match RefSeq BED
        myDiff5p_gr <- as(myDiff5p, "GRanges")
        seqlevs <- seqlevels(myDiff5p_gr)
        new_seqlevs <- ifelse(grepl("^chr", seqlevs), seqlevs, paste0("chr", seqlevs))
        new_seqlevs <- gsub("chrMT", "chrM", new_seqlevs)
        seqlevels(myDiff5p_gr) <- new_seqlevs

        myDiff5p.annot <- suppressWarnings(annotateWithGeneParts(myDiff5p_gr, gene.obj))
        dist_to_tss <- myDiff5p.annot@dist.to.TSS

        dist_to_tss_df <- data.frame(
            dist_to_feature = dist_to_tss$dist.to.feature,
            feature_name = dist_to_tss$feature.name,
            feature_strand = dist_to_tss$feature.strand,
            target_row = dist_to_tss$target.row
        )

        myDiff5p_data <- getData(myDiff5p)
        myDiff5p_data$target_row <- 1:nrow(myDiff5p_data)
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
        write.csv(DMC.final.annot, file = output_name, row.names = FALSE)
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