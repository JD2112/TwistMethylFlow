This Nextflow pipeline performs comprehensive analysis of Twist NGS DNA Methylation sequencing data, including quality control, alignment, methylation calling, and differential methylation analysis.

Usage:
------
nextflow run main.nf [options]

Options:
--------
--sample_sheet         Path to the sample sheet CSV file (required)
--bismark_index        Path to the Bismark index directory (required unless --genome or --aligned_bams is provided)
--genome               Path to the reference genome FASTA file (required if --bismark_index not provided)
--aligned_bams         Path to aligned BAM files (use this to start from aligned BAM files instead of FASTQ files)
--refseq_file          Path to RefSeq file for annotation (**mandatory if both/MethylKit method is chosen**).
--gtf_file             Path to GTF file for annotation (**mandatory if both/EdgeR method is chosen**) 
--outdir               Output directory (default: ./results)
--diff_meth_method     Differential methylation method to use: 'edger' or 'methylkit' (default: edger)
--run_both_methods     Run both edgeR and methylkit for differential methylation analysis (default: false)
--skip_diff_meth	     Skip differential methylation analysis (default: false)
--coverage_threshold   Minimum read coverage to consider a CpG site (default: 10)
--methylkit.assembly   genome assembly is required for methylkit analysis (should match with reference genome). Need to change in the `conf/params.config` or can be used directly on terminal (default: hg38).
--methylkit.mc_cores   number of cores to be used for methylkit analysis. Need to change in the `conf/params.config` or can be used directly on terminal (default: 1).
--methylkit.diff       methylation difference cut-off is required for methylkit analysis. Need to change in the `conf/params.config` or can be used directly on terminal (default: 0.2).
--methylkit.qvalue     qvalue is required for methylkit analysis to get significant results. Need to change in the `conf/params.config` or can be used directly on terminal (default: 0.05).
--logfc_cutoff         Differential methylation cut-off for Volcano or MA plot (default: 1.5)
--pvalue_cutoff        Differential methylation P-value cut-off for Volcano or MA plot (default: 0.05)
--hyper_color          Hypermethylation color for Volcano or MA plot (default: red)
--hypo_cutoff          Hypomethylation color for Volcano or MA plot (default: blue)
--nonsig_color         Non-significant color for Volcano or MA plot (default: black)
--compare_str          Comparison string for differential analysis (e.g., "Group1-Group2")
--top_n_genes          Number of top differentially methylated genes to report for GOplot (default: 100)   
--help                 Show this help message and exit

Input:
------
The sample sheet should be a CSV file with the following columns:
sample_id,read1,read2,group
Where:
- sample_id: Unique identifier for the sample
- read1: Path to R1 FASTQ file
- read2: Path to R2 FASTQ file (leave empty for single-end data)
- group: Group identifier for differential methylation analysis

Aligned BAM Files
If using `--aligned_bams`, provide the path to the directory containing aligned BAM files or a glob pattern to match the BAM files. In this case, the 'read1' column in the sample sheet should contain the paths to the aligned BAM files, and the 'read2' column should be left empty.

Output:
-------
The pipeline will create several subdirectories in the specified output directory:
- fastqc: FastQC reports for raw reads
- trimmed: Trimmed reads and trimming reports
- bismark_align: Bismark alignment results
- bismark_deduplicate: Deduplicated BAM files
- bismark_methylation_extraction: Methylation call files
- qualimap: Qualimap reports for aligned reads
- multiqc: MultiQC report summarizing QC metrics
- differential_methylation: Differential methylation analysis results
- post_processing: Summary statistics and plots of differential methylation results
- go_analysis: gene ontology annotation from top n (100) genes identified by differential_methylation process.

Profiles:
---------
The pipeline comes with several pre-configured profiles:
- standard: Local execution with default parameters
- singularity: Executes pipeline using Singularity containers
- docker: Executes pipeline using Docker containers
- conda: Executes pipeline using Conda environments
- gpu: Executes pipeline using NVIDIA Parabricks for GPU acceleration

Example commands:
-----------------
1. Run with singularity profile:
   nextflow run main.nf -profile singularity --sample_sheet samples.csv --bismark_index /path/to/bismark_index --outdir /path/to/results

2. Run with GPU acceleration (Parabricks):
   nextflow run main.nf -profile gpu,singularity --sample_sheet samples.csv --genome /path/to/genome.fa --outdir /path/to/results

3. Run with conda profile and methylkit for differential analysis:
   nextflow run main.nf -profile conda --sample_sheet samples.csv --bismark_index /path/to/bismark_index --diff_meth_method methylkit

4. Run with genome FASTA instead of pre-built Bismark index:
   nextflow run main.nf -profile singularity --sample_sheet samples.csv --genome /path/to/genome.fa --outdir /path/to/results

5. Start from aligned BAM files:
   nextflow run main.nf -profile singularity --aligned_bams '/path/to/aligned/*.bam' --outdir /path/to/results

6. Run both edgeR and methylkit for differential methylation analysis:
   nextflow run main.nf -profile singularity --sample_sheet samples.csv --bismark_index /path/to/bismark_index --run_both_methods --refseq_file data/hg38_RefSeq.bed.gz  --gtf_file data/Homo_sapiens.GRCh38.104.gtf --outdir /path/to/results

7. Skip differential methylation analysis:
   nextflow run main.nf -profile singularity --sample_sheet samples.csv --bismark_index /path/to/bismark_index --skip_diff_meth --outdir /path/to/results

For more information and detailed documentation, please refer to the README.md file.