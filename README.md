![](artworks/twistmethylflow_logo.png)

[![DOI](https://zenodo.org/badge/490592846.svg)](https://doi.org/10.5281/zenodo.14204261)
[![GitBook Docs](https://img.shields.io/badge/docs-GitBook-blue?logo=gitbook)](https://jyotirmoys-organization.gitbook.io/TwistMethylFlow)
[![build-docs](https://github.com/JD2112/TwistMethylFlow/actions/workflows/build-docs.yml/badge.svg?branch=main)](https://github.com/JD2112/TwistMethylFlow/actions/workflows/build-docs.yml)
[![GitHub Invite Collaborators](https://img.shields.io/badge/Invite-Collaborators-blue?style=for-the-badge&logo=github)](https://github.com/JD2112/TwistMethylFlow/settings/access)
[![wakatime](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1.svg)](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1)

## Overview

**TwistMethylFlow** is a robust, end-to-end Nextflow pipeline tailored for the analysis of Twist NGS DNA Methylation data. It streamlines the entire process from raw FASTQ files to multi-method differential methylation reports. The pipeline is uniquely designed with a dual-track architecture, allowing users to choose between a high-efficiency **GPU-accelerated path** (powered by NVIDIA Parabricks) for rapid processing of large cohorts, or a **traditional CPU-based path** (using Bismark) for standard compatibility. With integrated quality control, modular analysis stages, and automated result visualization, TwistMethylFlow ensures reproducible and scalable methylation profiling.

## Features

| Step | CPU (Bismark) | GPU (Parabricks) |
| :--- | :--- | :--- |
| Generate Genome Index | [Bismark](http://felixkrueger.github.io/Bismark/bismark/genome_preparation/) | [BWA-meth](https://github.com/brentp/bwa-meth) |
| Raw data QC | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) |
| Adapter trimming | [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) | [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) |
| Align Reads | [Bismark (bowtie2)](http://felixkrueger.github.io/Bismark/bismark/alignment/) | [Parabricks (fq2bam_meth)](https://www.nvidia.com/en-us/clara/genomics/) |
| Deduplicate Alignments | [Bismark](http://felixkrueger.github.io/Bismark/bismark/deduplication/) | Included in `fq2bam_meth` |
| Sort and indexing | [Samtools](http://www.htslib.org/) | [Samtools](http://www.htslib.org/) |
| Methylation Extraction | [Bismark](http://felixkrueger.github.io/Bismark/bismark/methylation_extraction/) | [MethylDackel](https://github.com/dpryan79/MethylDackel) |
| Alignment QC | [Qualimap](http://qualimap.conesalab.org/) | [Qualimap](http://qualimap.conesalab.org/) |
| QC Reporting | [MultiQC](https://seqera.io/multiqc/) | [MultiQC](https://seqera.io/multiqc/) |
| Diff Methylation | [EdgeR](https://bioconductor.org/packages/release/bioc/html/edgeR.html) / [MethylKit](https://www.bioconductor.org/packages/release/bioc/html/methylKit.html) | [EdgeR](https://bioconductor.org/packages/release/bioc/html/edgeR.html) / [MethylKit](https://www.bioconductor.org/packages/release/bioc/html/methylKit.html) |
| Post processing | [ggplot2](https://ggplot2.tidyverse.org/) | [ggplot2](https://ggplot2.tidyverse.org/) |
| GO analysis | [Gene Ontology](https://geneontology.org) | [Gene Ontology](https://geneontology.org) |

## Pipeline Schema
![](artworks/TMF.png)

## Requirements

- [Nextflow (>=21.10.3)](https://www.nextflow.io/docs/latest/install.html#install-nextflow)
- [Docker](https://docs.docker.com/engine/install/) or [Singularity](https://singularity-tutorial.github.io/01-installation/) (for containerized execution)
- Java (>=8)
- **NVIDIA GPU** (required for `gpu` profile): CUDA-enabled GPU with at least 16GB VRAM (e.g., A10, A30, A100) recommended for large genomes like Human (hg38) or Mouse (mm10). Tested with 3 L40S GPUs with 48GiB VRAM each.

## Usage

### 1. High-Speed GPU Run (NVIDIA Parabricks)
Recommended for large datasets. Requires NVIDIA GPUs and the `gpu` profile.

```bash
nextflow run JD2112/TwistMethylFlow \
    -profile singularity,gpu \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --run_both_methods \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/TwistMethylFlow_GPU
```

### 2. Traditional CPU Run (Bismark) [default: profile]
Standard workflow using Bismark for alignment and extraction on CPU-only systems.

```bash
nextflow run JD2112/TwistMethylFlow \
    -profile singularity \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --run_both_methods \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/TwistMethylFlow_CPU
```

### 3. Execution & Analysis Modes
Users can also choose to run the differential methylation analysis for specific methods:

1. when using the reference genome indexing, use `--genome_fasta` and `--run_both_methods` for both MethylKit and EdgeR differential analysis.
2. if you already have the bisulfite genome index, `--bismark_index`, add `--bismark_index /data/reference_genome/hg38/` file PATH, the workflow will skip indexing and uses the provided index.
3. If you want to run only **EdgeR** for differential methylation analysis, use `--diff_meth_method edger`. It is the **default** method.
4. If you want to run only **MethylKit** for differential methylation analysis, use `--diff_meth_method methylkit`.
5. If you want to run the pipeline without differential methylation analysis, use `--skip_diff_meth`.
6. If you want to run the pipeline with aligned BAM files instead of FASTQ files, use `--aligned_bams`.
7. If you want to run both **MethylKit** and **EdgeR** for differential methylation analysis, use `--run_both_methods`.

> [!TIP] "demo data check"
> Demo data runs with `hg19` reference genome. Rememeber to update the GTF/Refseq file accordingly

## ⚙️ Parameters Reference

| options | Description |
|--------|-----------------------------------------------------------|
| `--sample_sheet`       | Path to the sample sheet CSV file (**required**) |                                           
| `--bismark_index`      | Path to the Bismark index directory (required unless `--genome` or `--aligned_bams` is provided) |
| `--genome`             | Path to the reference genome FASTA file (required if `--bismark_index` not provided)| 
| `--aligned_bams`       | Path to aligned BAM files (use this to start from aligned BAM files instead of FASTQ files) |
| `--refseq_file`        | Path to RefSeq file for annotation (**reuired** to run `both` or `methylkit`)  |
| `--gtf_file`           | Path to GTF file for annotation (**reuired** to run `both` or `edger`)  |
| `--outdir`             | Output directory (default: ./results) |
| `--diff_meth_method`   | Differential methylation method to use: 'edger' or 'methylkit' (default: edger) | 
| `--run_both_methods`   | Run both edgeR and methylkit for differential methylation analysis (default: false) | 
| `--skip_diff_meth`     | Skip differential methylation analysis (default: false)   | 
| `--coverage_threshold` | Minimum read coverage to consider a CpG site (default: 10) |
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
nextflow run JD2112/TwistMethylFlow --help --outdir .
```
Find the details on the [manual](https://jd2112.github.io/TwistMethylFlow/)

## Credits
- Main Author: 
    - Jyotirmoy Das ([@JD2112](https://github.com/JD2112))

- Collaborators:
    - Debojyoti Das ([@BioDebojyoti](https://github.com/BioDebojyoti))    

## Citation

Das, J. (2024). TwistMethylFlow (v1.0.0). Zenodo. [https://doi.org/10.5281/zenodo.14204261](https://doi.org/10.5281/zenodo.14204261)

## FAQ/Troubleshooting

Please check the [manual](https://jd2112.github.io/TwistMethylFlow/) for details.

Please create [issues](https://github.com/JD2112/TwistMethylFlow/issues) on github.

## License(s)

[GNU-3 public license](https://github.com/JD2112/TwistMethylFlow/blob/v1.0.3/LICENSE).

## Acknowledgement

We would like to acknowledge the **Core Facility, Faculty of Medicine and Health Sciences, Linköping University, Linköping, Sweden** and **Clinical Genomics Linköping, Science for Life Laboratory, Sweden** for their support. We are grateful to **PDC (KTH, Sweden)** support for computational support to test and validate the pipeline on the *Dardel* HPC.
