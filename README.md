![](docs/images/methylflow_logo.png)

[![DOI](https://zenodo.org/badge/490592846.svg)](https://doi.org/10.5281/zenodo.14204261)
[![GitBook Docs](https://img.shields.io/badge/docs-GitBook-blue?logo=gitbook)](https://jyotirmoys-organization.gitbook.io/MethylFlow)
[![MethylFlow CI](https://github.com/JD2112/MethylFlow/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/JD2112/MethylFlow/actions/workflows/ci.yml)
[![build-docs](https://github.com/JD2112/MethylFlow/actions/workflows/build-docs.yml/badge.svg?branch=main)](https://github.com/JD2112/MethylFlow/actions/workflows/build-docs.yml)
[![GitHub Invite Collaborators](https://img.shields.io/badge/Invite-Collaborators-blue?style=for-the-badge&logo=github)](https://github.com/JD2112/MethylFlow/settings/access)
[![wakatime](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1.svg)](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1)

## Overview

**MethylFlow** is a high-performance Nextflow pipeline designed for end-to-end DNA methylation profiling. It features a versatile architecture that seamlessly handles diverse conversion chemistries—including **Enzymatic Methyl-seq (EM-seq)** and traditional **Bisulfite sequencing**—while offering a unique dual-track processing mode for both GPU-accelerated (NVIDIA Parabricks) and CPU-based analysis.

### 🧪 Technology Compatibility
Although Bismark is traditionally associated with Bisulfite sequencing, MethylFlow fully supports **Enzymatic Methyl-seq (EM-seq)**. Since both methods result in a C→T conversion of unmethylated cytosines, the alignment and methylation extraction logic remains identical. MethylFlow leverages Bismark as a gold-standard, bisulfite-aware aligner to ensure high accuracy and full compatibility with legacy datasets.

> [!NOTE]
> For a deeper look at our design goals, competitive positioning, and scientific rationale, please see our [Project Philosophy](PHILOSOPHY.md) and our [Benchmarking Strategy](BENCHMARKING.md).

## Features

| Step | CPU (Bismark) | GPU (Parabricks) |
| :--- | :--- | :--- |
| Generate Genome Index | [Bismark](http://felixkrueger.github.io/Bismark/bismark/genome_preparation/) | [BWA-meth](https://github.com/brentp/bwa-meth) |
| Raw data QC | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) |
| Adapter trimming | [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) | [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) |
| Align Reads | [Bismark (bowtie2)](http://felixkrueger.github.io/Bismark/bismark/alignment/) (Split-Align support) | [Parabricks (fq2bam_meth)](https://www.nvidia.com/en-us/clara/genomics/) |
| Deduplicate Alignments | [Bismark](http://felixkrueger.github.io/Bismark/bismark/deduplication/) | Included in `fq2bam_meth` |
| Sort and indexing | [Samtools](http://www.htslib.org/) | [Samtools](http://www.htslib.org/) |
| Methylation Extraction | [Bismark](http://felixkrueger.github.io/Bismark/bismark/methylation_extraction/) | [MethylDackel](https://github.com/dpryan79/MethylDackel) |
| Alignment QC | [Qualimap](http://qualimap.conesalab.org/) | [Qualimap](http://qualimap.conesalab.org/) |
| QC Reporting | [MultiQC](https://seqera.io/multiqc/) | [MultiQC](https://seqera.io/multiqc/) |
| Diff Methylation | [EdgeR](https://bioconductor.org/packages/release/bioc/html/edgeR.html) / [MethylKit](https://www.bioconductor.org/packages/release/bioc/html/methylKit.html) | [EdgeR](https://bioconductor.org/packages/release/bioc/html/edgeR.html) / [MethylKit](https://www.bioconductor.org/packages/release/bioc/html/methylKit.html) |
| Post processing | [ggplot2](https://ggplot2.tidyverse.org/) | [ggplot2](https://ggplot2.tidyverse.org/) |
| Enrichment analysis | [GO](https://geneontology.org) / [KEGG](https://www.genome.jp/kegg/) | [GO](https://geneontology.org) / [KEGG](https://www.genome.jp/kegg/) |
| Unified Reporting | [Quarto](https://quarto.org/) (Clinical Mode) | [Quarto](https://quarto.org/) (Clinical Mode) |

## Pipeline Schema
![](docs/images/TMF.png)

## Requirements

- [Nextflow (>=21.10.3)](https://www.nextflow.io/docs/latest/install.html#install-nextflow)
- [Docker](https://docs.docker.com/engine/install/) or [Singularity](https://singularity-tutorial.github.io/01-installation/) (for containerized execution)
- Java (>=8)
- **NVIDIA GPU** (required for `gpu` profile): CUDA-enabled GPU with at least 16GB VRAM (e.g., A10, A30, A100) recommended for large genomes like Human (hg38) or Mouse (mm10). Tested with 3 L40S GPUs with 48GiB VRAM each.

## Usage

### 1. High-Speed GPU Run (NVIDIA Parabricks)
Recommended for large datasets. Requires NVIDIA GPUs and the `gpu` profile.

```bash
nextflow run JD2112/MethylFlow \
    -profile singularity,gpu \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --diff_meth_method dss,edger \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/MethylFlow_GPU
```

### 2. Traditional CPU Run (Bismark) [default: profile]
Standard workflow using Bismark for alignment and extraction on CPU-only systems.

```bash
nextflow run JD2112/MethylFlow \
    -profile singularity \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --diff_meth_method dss,edger \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/MethylFlow_CPU
```

### 3. Execution & Analysis Modes
Users can also choose to run the differential methylation analysis for specific methods:

1. when using the reference genome indexing, use `--genome_fasta` and `--diff_meth_method all` for comprehensive differential analysis.
2. if you already have the bisulfite genome index, `--bismark_index`, add `--bismark_index /data/reference_genome/hg38/` file PATH, the workflow will skip indexing and uses the provided index.
3. If you want to run only **DSS** for differential methylation analysis, use `--diff_meth_method dss`. It is the **default** method.
4. If you want to run only **EdgeR** for differential methylation analysis, use `--diff_meth_method edger`.
5. If you want to run only **MethylKit** for differential methylation analysis, use `--diff_meth_method methylkit`.
6. If you want to run the pipeline without differential methylation analysis, use `--skip_diff_meth`.
7. If you want to run the pipeline with aligned BAM files instead of FASTQ files, use `--aligned_bams`.
8. If you want to run the **Clinical Mode** with unified reporting and disease annotation, use `-profile clinical`.
9. If you want to trigger the automatic PDF report generation, use `--run_clinical_report`.

### 4. Applied Clinical Genomics (New in v1.1.0)
The pipeline now features a high-fidelity **Clinical Mode** (`--mode clinical`) used for diagnostic-ready reporting:
- **Unified Aggregation Layer**: Automatically synthesizes results from all differential methods into a standardized schema.
- **Disease Mapping**: Mapped gene-level results to clinical descriptors using the [DisGeNET](https://www.disgenet.org/) database.
- **Regional Context**: Automatic annotation of DMRs into **Promoter**, **Enhancer**, or **Intergenic** regions based on TSS distance.
- **Outlier Detection**: Detection of sample-level cohort deviations using multi-dimensional Z-score PCA on QC metrics.
- **Pathway Integration**: Combined GO and KEGG enrichment analysis with automated narrative generation.
- **CPU Parallelization**: Automated FastQ splitting and BAM merging for ultra-fast Bismark alignment on HPC clusters.


> [!TIP] "demo data check"
> Demo data runs with `hg19` reference genome. Rememeber to update the GTF/Refseq file accordingly

## Testing the Pipeline

You can easily test the pipeline's execution locally using the configured test data profiles. The configurations are powered by NVIDIA Parabricks for fast alignment analysis.

```bash
# Test the core mapping and QC steps (6 subset samples, runs fast)
nextflow run main.nf -profile test_local,singularity,gpu

# Test the core steps + all differential methylation methods (24 samples)
nextflow run main.nf -profile test_full,singularity,gpu
```

## Example usage
## ⚙️ Parameters Reference

| options | Description |
|--------|-----------------------------------------------------------|
| `--sample_sheet`       | Path to the sample sheet CSV file (**required**) |                                           
| `--bismark_index`      | Path to the Bismark index directory (required unless `--genome` or `--aligned_bams` is provided) |
| `--genome`             | Path to the reference genome FASTA file (required if `--bismark_index` not provided)| 
| `--aligned_bams`       | Path to aligned BAM files (use this to start from aligned BAM files instead of FASTQ files) |
| `--bismark_split_reads`| Number of reads per chunk for parallel Bismark alignment (default: 0 / disabled) |
| `--refseq_file`        | Path to RefSeq file for annotation (**reuired** to run `both` or `methylkit`)  |
| `--gtf_file`           | Path to GTF file for annotation (**reuired** to run `both` or `edger`)  |
| `--outdir`             | Output directory (default: ./results) |
| `--diff_meth_method`   | Differential methylation method to use: 'dss', 'edger', 'methylkit', or comma-separated list (default: dss) | 
| `--skip_diff_meth`     | Skip differential methylation analysis (default: false)   | 
| `--coverage_threshold` | Minimum read coverage to consider a CpG site (default: 3) |
| `--logfc_cutoff`       | Differential methylation cut-off for Volcano or MA plot (default: 1.5)    |  
| `--pvalue_cutoff`      | Differential methylation P-value cut-off for Volcano or MA plot (default: 0.05)      | 
| `--hyper_color`        | Hypermethylation color for Volcano or MA plot (default: red) |
| `--hypo_cutoff`        | Hypomethylation color for Volcano or MA plot (default: blue) |
| `--nonsig_color`       | Non-significant color for Volcano or MA plot (default: black) |
| `--compare_str`        | Comparison string for differential analysis (e.g. "Group1-Group2")  |
| `--top_n_genes`        | Number of top differentially methylated genes to report for GOplot (default: 100) |
| `--help`               | Show this help message and exit   | 

## Pipeline HELP

```bash
nextflow run JD2112/MethylFlow --help --outdir .
```
Find the details on the [manual](https://jd2112.github.io/MethylFlow/)

## Credits
- Main Author: 
    - Jyotirmoy Das ([@JD2112](https://github.com/JD2112))

- Collaborators:
    - Debojyoti Das ([@BioDebojyoti](https://github.com/BioDebojyoti))    

## Citation

Das, J. (2025). MethylFlow (v1.1.0). Zenodo. [https://doi.org/10.5281/zenodo.14204261](https://doi.org/10.5281/zenodo.14204261)

## FAQ/Troubleshooting

Please check the [manual](https://jd2112.github.io/MethylFlow/) for details.

Please create [issues](https://github.com/JD2112/MethylFlow/issues) on github.

## License(s)

[GNU-3 public license](https://github.com/JD2112/MethylFlow/blob/v1.0.3/LICENSE).

## Acknowledgement

We would like to acknowledge the **Core Facility, Faculty of Medicine and Health Sciences, Linköping University, Linköping, Sweden** and **Clinical Genomics Linköping, Science for Life Laboratory, Sweden** for their support. We are grateful to **PDC (KTH, Sweden)** support for computational support to test and validate the pipeline on the *Dardel* HPC.
