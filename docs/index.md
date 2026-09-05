---
hide:
  - navigation
  - toc
---

# Introduction

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14204260.svg)](https://doi.org/10.5281/zenodo.14204260)
[![GitBook Docs](https://img.shields.io/badge/docs-GitBook-blue?logo=gitbook)](https://jyotirmoys-organization.gitbook.io/milou)
[![GitHub Invite Collaborators](https://img.shields.io/badge/Invite-Collaborators-blue?style=for-the-badge&logo=github)](https://github.com/JD2112/milou/settings/access)
[![wakatime](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1.svg)](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1)

<div class="grid-container" markdown="1">

<div class="main-content" markdown="1">

**milou** is a robust, end-to-end Nextflow pipeline for comprehensive analysis of DNA methylation data, streamlining the workflow from raw FASTQ files to harmonized analytical outputs and automated, publication-ready reports.

The pipeline features a dual-mode operational design supporting both rapid exploratory research and structured, interpretation-oriented clinical reporting. To accommodate diverse institutional and high-performance computing infrastructures, milou provides GPU-accelerated alignment and deduplication via NVIDIA Parabricks alongside CPU-based execution with Bismark for reproducible, cross-platform analysis. A unified results layer aggregates differential methylation calls across three complementary statistical frameworks (DSS, edgeR, methylKit), functional enrichment (Gene Ontology and KEGG Pathview diagrams), and clinical annotations (gnomAD, OMIM) into harmonized, deterministic outputs.

???+ danger "Research Use Only (RUO)"

    This pipeline is intended for **Research Use Only (RUO)**. It has not been clinically validated and is not approved for diagnostic use. The generated reports are designed to support data interpretation and hypothesis generation, and must not be used for medical decision-making.

![milou overview](images/milou.png)

## 1. Key Features

- **End-to-End Methylation Analysis**: Complete workflow from raw FASTQ files to differential methylation, functional enrichment (GO/KEGG), and integrated downstream interpretation.
- **Dual Execution Engine (GPU + CPU)**: Flexible support for high-speed GPU-accelerated processing (NVIDIA Parabricks) and standard CPU-based workflows (Bismark), enabling both rapid turnaround and reproducible analysis.
- **Dual-Mode Reporting (Research vs Clinical-Style)**: Supports both research mode for fast, exploratory analysis and clinical-style mode for structured, interpretation-oriented outputs with prioritized results and summaries.
- **Unified Analysis Layer**: Harmonizes outputs across modules into standardized result tables, integrating differentially methylated regions (DMRs), gene-level summaries, functional enrichment (GO/KEGG), and disease association layers.
- **Integrated Biological Interpretation**: Built-in annotation modules connect methylation changes to biological pathways and disease-relevant genes, facilitating downstream interpretation without manual integration.
- **Automated, Publication-Ready Reports**: Generates clean, structured reports (PDF/HTML) via Quarto, combining statistical results with narrative summaries for easy interpretation and sharing.
- **Security & Container Auditing ([quindecagon](https://github.com/JD2112/quindecagon))**: All containers within milou undergo strict continuous security verification using quindecagon, incorporating automated static analysis, OCI image vulnerability scanning (Trivy, Grype), Software Bill of Materials (SBOM) generation (Syft), and cryptographic image signing (Cosign).
- **FAIR Open Science Archive (Zenodo)**: Complete execution reports, timelines, MultiQC dashboards, and Python evaluation scripts are permanently archived on Zenodo at **DOI: [10.5281/zenodo.22326688](https://doi.org/10.5281/zenodo.22326688)**.
- **Reproducible & Scalable Architecture**: Built with Nextflow DSL2 and containerized environments, ensuring portability across HPC, cloud, and local systems with bitwise determinism (`set.seed(42)`).

## 2. Pipeline Capabilities

| Category            | Feature                                                       | Status |
| :------------------ | :------------------------------------------------------------ | :----: |
| **Core Processing** | Dual-track Processing (GPU-Accelerated / CPU-Standard)        |   ✅   |
|                     | Multi-method Differential Methylation (DSS, edgeR, methylKit) |   ✅   |
| **Enrichment**      | Functional Annotation (GO / KEGG Pathway)                     |   ✅   |
|                     | Disease Association Layer (DisGeNET)                          |   ✅   |
| **Analysis**        | Unified Analysis Layer (Integrated Structured Outputs)        |   ✅   |
|                     | Gene Prioritization (Significance + Effect Size Scoring)      |   ✅   |
| **Reporting**       | Automated PDF/HTML Integrated Research Reports                |   ✅   |
|                     | Technical MultiQC Reporting                                   |   ✅   |
| **Review Layer**    | Integrated Region Annotation (Promoter/Enhancer/Distal)       |   ✅   |
|                     | Clinical-Style Review Mode (`--mode clinical`)                |   ✅   |
| **Clinical Rigor**  | Data Integrity (Input SHA256 Checksumming)                    |   ✅   |
|                     | Bitwise Determinism (Enforced Random Seeds)                   |   ✅   |
|                     | Automated Output Sanity Validation (Pass/Fail Checks)          |   ✅   |
|                     | HIPAA-Compliant Schema Enforcement                            |   ✅   |
| **Infrastructure**  | Containerized (Singularity, Docker, Conda)                    |   ✅   |
|                     | Reproducible DSL2 Modular Architecture                        |   ✅   |

## 3. Quick Start & Execution Syntax

Sample sheet (CSV format) with sample information `Sample_sheet.csv`:

```bash
sample_id,group,read1,read2
SN09,Healthy,SN09_R1_001.fastq.gz,SN09_R2_001.fastq.gz
SN10,Disease,SN10_R1_001.fastq.gz,SN10_R2_001.fastq.gz
```

Each row represents a pair of fastq files (paired end).

???+ tip "Sample Information"
     **PLEASE NOTE:** minimum 3 samples per group are required to run the differential methylation analysis.

Now run the pipeline using:

```bash
nextflow run JD2112/milou \
    -profile singularity,gpu \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --diff_meth_method dss,edger \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/milou_GPU
```

???+ warning "pipeline run" 
    1. Running on NVIDIA GPUs with CUDA will reduce the time significantly, but if not available, runs on cpu using bismark -

    ```bash
    nextflow run JD2112/milou \
    -profile singularity \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --diff_meth_method dss,edger \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/milou_CPU
    ```
    2. Consider to check the pipeline parameters before running. You can change it via `conf/params.config`

For more details and further functionality, please refer to the [usage documentation](usage.md) and the [parameter documentation](parameters.md).

## 4. Pipeline Output Directory Structure

milou generates a comprehensive `results/` folder including:

- **MultiQC Report**: Combined stats for all QC and alignment steps.
- **Clinical Research Report**: Automated PDF/HTML report (Quarto) containing physician-ready summaries of DMRs and pathways.
- **Unified Analysis Layer**: Integrated tables combining DMR statistics with GO, KEGG, and disease associations.
- **Visualizations**: Volcano plots, MA plots, dot plots, and GO/KEGG chord diagrams.


<div class="grid cards" markdown>

<div>
        <h4>GPU output</h4>
        ```
        results_test_bisulfite_gpu/
        ├── clinical_reporting
        ├── conversion_qc
        ├── differential_methylation
        ├── multiqc
        ├── parabricks_analysis
        ├── pipeline_info
        ├── prepare_genome
        ├── read_processing
        ├── report
        ├── result_analysis
        └── unified_layer
        ```
</div>

<div>
        <h4>CPU output</h4>
        ```
        results_test_bisulfite_cpu/
        ├── bismark_analysis
        ├── clinical_reporting
        ├── conversion_qc
        ├── differential_methylation
        ├── multiqc
        ├── pipeline_info
        ├── prepare_genome
        ├── read_processing
        ├── report
        ├── result_analysis
        └── unified_layer

        ```
    </div>
</div>

For more details about the output files and reports, please refer to the [output documentation](output.md).

## 5. Hardware Benchmarking

Benchmarked on **hg38** (Human Genome) using 24 paired-end samples on the Dardel HPC and Fraka HPC.

| Feature             | CPU Track (Standard) | GPU Track (Parabricks)  |
| :------------------ | :------------------- | :---------------------- |
| **Indexing**        | Bismark Index        | BWA-meth Index          |
| **Alignment Speed** | 1.0x (Baseline)      | **~28x Faster**         |
| **Data Extraction** | Bismark Extractor    | MethylDackel            |
| **Hardware**        | 12+ CPU Cores        | NVIDIA GPU (16GB+ VRAM) |

## 6. Development & Authorship

### Core Developers & Contributors

**milou** was originally conceptualized and written by **Jyotirmoy Das** ([@JD2112](https://github.com/JD2112)) at the Bioinformatics Core Facility and Clinical Genomics Linköping, Linköping University to reduce the gap between the identification of methylation sites per sample and then perform the differential analysis separately.

Main developer & maintainer:

- [Jyotirmoy Das](https://github.com/JD2112)

Contributors:

- [Debojyoti Das](https://github.com/biodebojyoti)

### Acknowledgements

The authors would like to acknowledge Dr. Vesa Loitto, the Core Facility, Dept. of Biomedical and Clinical Sciences, Faculty of Medicine and Health Sciences at Linköping University, Sweden for his support on this application development. We would like to acknowledge the Core Facility, Faculty of Medicine and Health Sciences, Linköping University, Linköping, Sweden and Clinical Genomics Linköping, Science for Life Laboratory, Sweden for their support. We thank the PDC (Parallelldatorcentrum) Center for High-Performance Computing, KTH Royal Institute of Technology, Sweden, for providing access to the computing resources and storage used in this research. We thank ALF funding support from Region Östergötland (RÖ) and Genomic Medicine Sweden for the computational facility. Clinical Genomics Linköping receives funding from the Science for Life Laboratory.

### Citation

> Das, J., et al. (2026). *milou: An End-to-End Nextflow Pipeline for Translational DNA Methylation Profiling with Multi-Method Consensus Scoring*.  
> **Software Pipeline Archive:** [https://doi.org/10.5281/zenodo.14204260](https://doi.org/10.5281/zenodo.14204260)  
> **Benchmark Data Archive:** [https://doi.org/10.5281/zenodo.22326688](https://doi.org/10.5281/zenodo.22326688)

</div>

<div class="side-panel" markdown="1">

![](images/milou_logo.png)

## Run with

[![](https://img.shields.io/badge/Nextflow-%E2%89%A521.10.3-brightgreen)](https://www.nextflow.io/)
[![](https://img.shields.io/badge/Docker-supported-blue?logo=docker)](https://www.docker.com/)
[![](https://img.shields.io/badge/Singularity-supported-white?logo=singularity)](https://apptainer.org/)
[![](https://img.shields.io/badge/Conda-supported-lightgrey?logo=anaconda)](https://docs.conda.io/)

## Stats

<div class="stats-grid">
  <div class="stats-item"><span id="gh-stars" class="stats-value">--</span><span class="stats-label">stars</span></div>
  <div class="stats-item"><span id="gh-issues" class="stats-value">--</span><span class="stats-label">open issues</span></div>
  <div class="stats-item"><span id="gh-last-release" class="stats-value">--</span><span class="stats-label">last release</span></div>
  <div class="stats-item"><span id="gh-last-update" class="stats-value">--</span><span class="stats-label">last update</span></div>
</div>

## Included Tools

<div class="tag-section">
  <a href="https://www.bioinformatics.babraham.ac.uk/projects/fastqc/" target="_blank"><span>FastQC</span></a>
  <a href="https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/" target="_blank"><span>Trim Galore!</span></a>
  <a href="https://www.bioinformatics.babraham.ac.uk/projects/bismark/" target="_blank"><span>Bismark</span></a>
  <a href="https://www.nvidia.com/en-us/clara/genomics/" target="_blank"><span>Parabricks</span></a>
  <a href="http://www.htslib.org/" target="_blank"><span>Samtools</span></a>
  <a href="http://qualimap.conesalab.org/" target="_blank"><span>Qualimap</span></a>
  <a href="https://github.com/dpryan79/MethylDackel" target="_blank"><span>MethylDackel</span></a>
  <a href="https://bioconductor.org/packages/release/bioc/html/edgeR.html" target="_blank"><span>EdgeR</span></a>
  <a href="https://bioconductor.org/packages/release/bioc/html/methylKit.html" target="_blank"><span>MethylKit</span></a>
  <a href="https://bioconductor.org/packages/release/bioc/html/clusterProfiler.html" target="_blank"><span>clusterProfiler</span></a>
  <a href="https://multiqc.info/" target="_blank"><span>MultiQC</span></a>
  <a href="https://ggplot2.tidyverse.org/" target="_blank"><span>ggplot2</span></a>
  <a href="https://quarto.org/" target="_blank"><span>Quarto</span></a>
</div>

## Contributors

<div id="gh-contributors" class="contrib-grid">
  <!-- Dynamically populated from GitHub API -->
</div>

## Get Help

- [Slack Community](https://nfcore.slack.com/channels/twistmethylflow)
- [GitHub Issues](https://github.com/JD2112/milou/issues)

</div>

</div>
