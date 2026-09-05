![](docs/images/milou_logo.png)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14204260.svg)](https://doi.org/10.5281/zenodo.14204260)
[![GitBook Docs](https://img.shields.io/badge/docs-GitBook-blue?logo=gitbook)](https://jyotirmoys-organization.gitbook.io/milou)
[![GitHub Invite Collaborators](https://img.shields.io/badge/Invite-Collaborators-blue?style=for-the-badge&logo=github)](https://github.com/JD2112/milou/settings/access)
[![wakatime](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1.svg)](https://wakatime.com/badge/user/fe95275f-909a-4147-a45d-624981173898/project/a44415f0-a274-4c3b-a59a-f8e1067c0fc1)


## 1. Overview

**milou** (**M**ethylation **I**ntegrated **L**ayer for **O**mics **U**nification) is a high-performance Nextflow DSL2 pipeline designed for end-to-end DNA methylation profiling. It features a versatile, dual-engine architecture that seamlessly handles diverse library preparations and conversion chemistries—including targeted hybrid capture (**Twist Human Methylome NGS panels**), **Enzymatic Methyl-seq (EM-seq)**, and traditional **Whole-Genome Bisulfite Sequencing (WGBS)**—while offering specialized dual-track processing modes for both GPU-accelerated (NVIDIA Clara Parabricks) and CPU-based (Bismark) execution.

A core scientific breakthrough of milou is its **Multi-Method Differential Methylation Consensus Framework**, which statistically reconciles calls across three complementary methodologies (**DSS**, **edgeR**, and **methylKit**) using a multi-method composite $\pi$-value score alongside an automated, publication-ready **Quarto Reporting Engine** (interactive HTML + vector PDF).

> [!NOTE]
> For a deeper look at our design goals, competitive positioning, and scientific rationale, please see our [Project Philosophy](PHILOSOPHY.md) and our [Benchmarking Strategy](BENCHMARKING.md).



## 2. Key Features

- **Dual-Engine Execution (GPU + CPU)**: Flexible support for ultra-fast GPU-accelerated processing via NVIDIA Clara Parabricks (`fq2bam_meth` + `MethylDackel`) and standard CPU-based workflows (Bismark with parallel FastQ chunking), achieving bitwise concordance across platforms.
- **Versatile Conversion Chemistry**: Native support for Enzymatic Methyl-seq (EM-seq), targeted hybrid capture (e.g., Twist Human Methylome), and standard WGBS bisulfite conversion.
- **Multi-Method Consensus Layer ($\pi$-Value)**: Directly addresses the notorious caller discordance between beta-binomial models (DSS), negative binomial generalized linear models (edgeR), and logistic regression (methylKit) by ranking candidate genes via:
  $$\pi_g = \overline{|\log_2(\text{FC})_g|} \times (-\log_{10}(P_{\min,g}))$$
- **Automated Clinical & Research Quarto Reports**: Interactive HTML dashboards (with searchable `DT::datatable`, TSV/Excel exports, and locus zoom plots) and publication-ready vector PDFs produced automatically via Quarto.
- **Genomic & Disease Annotation**: Direct integration with gnomAD population variant frequencies, OMIM morbid maps, and localized DisGeNET disease descriptors.
- **Biological Pathway Integration**: Automated functional profiling including Gene Ontology (GO) and KEGG pathway mapping with automated Pathview overlay diagrams.
- **Strict Clinical Governance & Determinism**: Cryptographic SHA256 input checksumming, HIPAA-compliant PHI sanitization, automated conversion efficiency QC (Lambda spike-in), and bitwise statistical determinism (`set.seed(42)`).
- **FAIR Open Science Archive (Zenodo)**: Complete execution reports, timelines, MultiQC dashboards, and benchmark assets are permanently deposited on Zenodo at **DOI: [10.5281/zenodo.22326688](https://doi.org/10.5281/zenodo.22326688)**.



## 3. Pipeline Architecture

| Step | CPU Track (Bismark) | GPU Track (NVIDIA Parabricks) |
| :--- | :--- | :--- |
| **Raw QC** | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) |
| **Adapter Trimming** | [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) | [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) |
| **Alignment & Dedup** | [Bismark](http://felixkrueger.github.io/Bismark/) (Multi-core split/merge) | [Parabricks](https://www.nvidia.com/en-us/clara/genomics/) (`fq2bam_meth`) |
| **Sorting & Indexing** | [Samtools](http://www.htslib.org/) | Included in Parabricks |
| **Methylation Extraction** | [Bismark Methylation Extractor](http://felixkrueger.github.io/Bismark/) | [MethylDackel](https://github.com/dpryan79/MethylDackel) |
| **Alignment & Target QC** | [Qualimap](http://qualimap.conesalab.org/) / [Picard HsMetrics](https://broadinstitute.github.io/picard/) | [Qualimap](http://qualimap.conesalab.org/) / [Picard HsMetrics](https://broadinstitute.github.io/picard/) |
| **Multi-Method DMC/DMR** | [DSS](https://bioconductor.org/packages/DSS/) / [edgeR](https://bioconductor.org/packages/edgeR/) / [methylKit](https://bioconductor.org/packages/methylKit/) | [DSS](https://bioconductor.org/packages/DSS/) / [edgeR](https://bioconductor.org/packages/edgeR/) / [methylKit](https://bioconductor.org/packages/methylKit/) |
| **Consensus Layer** | Multi-method $\pi$-value scoring + majority voting | Multi-method $\pi$-value scoring + majority voting |
| **Functional Enrichment** | [clusterProfiler](https://bioconductor.org/packages/clusterProfiler/) (GO, KEGG, Pathview, DisGeNET) | [clusterProfiler](https://bioconductor.org/packages/clusterProfiler/) (GO, KEGG, Pathview, DisGeNET) |
| **Clinical Quarto Report** | Integrated Quarto engine (HTML & vector PDF) | Integrated Quarto engine (HTML & vector PDF) |



## 4. Requirements & Installation

- **Nextflow**: Version `>= 21.10.3` (DSL2 compliant)
- **Container Engine**: [Docker](https://docs.docker.com/engine/install/) or [Singularity](https://singularity-tutorial.github.io/01-installation/) (all images pinned with immutable SHA256 digests)
- **Java**: JRE `>= 11` (or OpenJDK 17)
- **Hardware**:
  - **CPU Track**: Minimum 16 CPU cores and 64 GB RAM recommended for targeted panels; $\ge$ 128 GB RAM recommended for human whole-genome sequencing (WGBS / EM-seq).
  - **GPU Track**: NVIDIA CUDA-capable GPU with $\ge$ 16 GB VRAM (e.g., A10, A30, A100, L40S).



## 5. Quick Start

### A. Prepare Sample Sheet (`Sample_sheet.csv`)
```csv
sample_id,group,read1,read2
SRR36563094,asthmatic,data/sample1_R1.fastq.gz,data/sample1_R2.fastq.gz
SRR36563095,asthmatic,data/sample2_R1.fastq.gz,data/sample2_R2.fastq.gz
SRR36563098,healthy,data/sample3_R1.fastq.gz,data/sample3_R2.fastq.gz
SRR36563099,healthy,data/sample4_R1.fastq.gz,data/sample4_R2.fastq.gz
```

### B. High-Speed GPU Track (NVIDIA Parabricks)
```bash
nextflow run JD2112/milou \
    -profile singularity,gpu \
    --sample_sheet Sample_sheet.csv \
    --genome_fasta /data/genomes/GRCh38/Homo_sapiens.GRCh38.fa \
    --gtf_file /data/genomes/GRCh38/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/genomes/GRCh38/hg38_RefSeq.bed.gz \
    --diff_meth_method all \
    --mode clinical \
    --outdir results_gpu
```

### C. Standard CPU Track (Bismark)
```bash
nextflow run JD2112/milou \
    -profile singularity \
    --sample_sheet Sample_sheet.csv \
    --genome_fasta /data/genomes/GRCh38/Homo_sapiens.GRCh38.fa \
    --gtf_file /data/genomes/GRCh38/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/genomes/GRCh38/hg38_RefSeq.bed.gz \
    --diff_meth_method all \
    --mode clinical \
    --outdir results_cpu
```



## 6. Pre-Configured Benchmark Profiles

milou includes built-in test profiles for rapid execution, validation, and reproduction of published benchmarks:

```bash
# 1. Human EM-seq whole-genome benchmark (12 samples: asthmatic, atopic, healthy)
nextflow run JD2112/milou -profile em_seq_cpu,singularity
nextflow run JD2112/milou -profile em_seq_gpu,singularity,gpu

# 2. Human WGBS/Bisulfite benchmark (PRJNA476128)
nextflow run JD2112/milou -profile bs_seq_cpu,singularity
nextflow run JD2112/milou -profile bs_seq_gpu,singularity,gpu

# 3. Targeted Hybrid-Capture replication cohort (24 samples)
nextflow run JD2112/milou -profile twist_replicate_article_A_cpu,singularity
nextflow run JD2112/milou -profile twist_replicate_article_A_gpu,singularity,gpu

# 4. Minimal lightweight sanity test
nextflow run JD2112/milou -profile test_local,singularity
```



## 7. Key Parameter Reference

| Parameter | Description | Default |
| :--- | :--- | :---: |
| `--sample_sheet` | Path to sample sheet CSV (**required**) | `null` |
| `--genome_fasta` | Path to reference genome FASTA | `null` |
| `--bismark_index` | Pre-built Bismark bisulfite index directory | `null` |
| `--gtf_file` | Ensembl gene annotation GTF (for edgeR / feature overlap) | `null` |
| `--refseq_file` | RefSeq gene coordinates BED (for methylKit / promoter overlap) | `null` |
| `--diff_meth_method` | Differential callers to run: `all`, `dss`, `edger`, `methylkit` | `'dss'` |
| `--smoothing` | Spline smoothing in DSS (`TRUE` / `FALSE`; use `FALSE` for WGBS memory scaling) | `TRUE` |
| `--mode` | Operational mode: `research` (broad exploratory) or `clinical` (strict consensus voting) | `'research'` |
| `--run_clinical_report` | Render automated Quarto HTML & PDF diagnostic reports | `false` |
| `--coverage_threshold` | Minimum CpG read depth filter | `3` |
| `--logfc_cutoff` | Effect size threshold for significance filter | `0.5` |
| `--pvalue_cutoff` | P-value threshold for candidate significance filter | `0.05` |
| `--outdir` | Output publication directory | `'./results'` |

> For the exhaustive parameter specification, visit the [Online Documentation](https://jd2112.github.io/milou/parameters/).



## 8. Output Directory Structure

Each pipeline run organizes harmonized results into standard directories:
```
results/
├── multiqc/                   # MultiQC aggregated quality control report
├── pipeline_info/             # Nextflow execution report, timeline, trace, and DAG
├── clinical_reporting/        # Quarto HTML & PDF diagnostic summary reports
├── unified_layer/             # Cross-method consensus tables with calculated π-values
│   ├── Unified_Candidate_Genes_Ranked.csv
│   └── MultiMethod_Consensus_Voting_Matrix.csv
├── dss/                       # DSS differential methylation results (CpGs & DMRs)
├── edger/                     # edgeR dispersion-shrinkage differential results
├── methylkit/                 # methylKit logistic regression results & annotations
└── enrichment/                # clusterProfiler GO, KEGG Pathview, and DisGeNET outputs
```



## 9. Citation & Reproducibility

If you use milou in your research, please cite:

> **Das, J., et al. (2026).** *milou: An open-source, reproducible Nextflow framework for high-throughput DNA methylation profiling with multi-method consensus scoring and automated reporting.*   
> **Software Pipeline Archive:** [https://doi.org/10.5281/zenodo.14204260](https://doi.org/10.5281/zenodo.14204260)  
> **Benchmark Data Archive:** [https://doi.org/10.5281/zenodo.22326688](https://doi.org/10.5281/zenodo.22326688)



## 10. License & Acknowledgements

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

The authors would like to acknowledge Dr. Vesa Loitto, the Core Facility, Dept. of Biomedical and Clinical Sciences, Faculty of Medicine and Health Sciences at Linköping University, Sweden for his support on this application development. We would like to acknowledge the Core Facility, Faculty of Medicine and Health Sciences, Linköping University, Linköping, Sweden and Clinical Genomics Linköping, Science for Life Laboratory, Sweden for their support. We thank the PDC (Parallelldatorcentrum) Center for High-Performance Computing, KTH Royal Institute of Technology, Sweden, for providing access to the computing resources and storage used in this research. We thank ALF funding support from Region Östergötland (RÖ) and Genomic Medicine Sweden for the computational facility. Clinical Genomics Linköping receives funding from the Science for Life Laboratory.


