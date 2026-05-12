# FAQs

# MethylFlow FAQs

## Pipeline Steps

### Generate Reference Genome
??? question "What is the purpose of Generate Reference Genome?"
    This step creates reference genome index files for **Bismark**, which are required for bisulfite read alignment.

### Raw Data QC
??? question "How is raw sequencing data quality assessed?"
    Raw Data QC uses **FastQC** to evaluate per-base quality, GC content, adapter contamination, and other metrics.

### Adapter Trimming
??? question "How should adapters and low-quality bases be handled?"
    **Trim Galore** removes adapters and low-quality bases from reads, ensuring high-quality data for alignment.

### Align Reads
??? question "How are reads aligned to the reference genome?"
    **Bismark (Bowtie2)** aligns bisulfite-treated reads to the reference genome.  
    Accurate alignment is crucial for downstream methylation analysis.

### Deduplicate Removal
??? question "What is deduplicate removal?"
    **Bismark** removes PCR duplicates from aligned reads to prevent bias in methylation calling.

### Sort and Indexing
??? question "How are BAM files prepared after alignment?"
    **Samtools** sorts and indexes deduplicated BAM files for efficient access in downstream analyses.

### Extract Methylation Calls
??? question "How are methylation calls extracted?"
    **Bismark** extracts cytosine methylation calls from aligned reads, generating the input for differential methylation analysis.

### Summary Report
??? question "How is the summary report generated?"
    **Bismark** summarizes alignment statistics and methylation extraction results, including conversion efficiency.

### Alignment QC
??? question "How is alignment quality assessed?"
    **Qualimap** generates metrics such as coverage, mapping quality, and duplication rate for aligned reads.

### QC Reporting
??? question "How are QC reports aggregated?"
    **MultiQC** compiles QC reports from FastQC, Bismark, and Qualimap into a single comprehensive report.

### Differential Methylation
??? question "How is differential methylation analysis performed?"
    **DSS**, **EdgeR**, and **MethylKit** identify differentially methylated positions or regions, considering replicates and experimental design.

### Post Processing
??? question "How are results visualized?"
    **ggplot2** creates summary plots like heatmaps, volcano plots, and coverage plots for differential methylation results.

### GO Analysis
??? question "How is Gene Ontology analysis performed?"
    Functional enrichment analysis identifies pathways associated with differentially methylated genes, providing biological interpretation.

---

## Nextflow Workflow Concepts

### General Nextflow
??? question "What is Nextflow?"
    Nextflow is a workflow management system for reproducible and scalable scientific pipelines.  
    It allows users to define tasks and data flow using **processes** and **channels**.

### Processes
??? question "What are processes in Nextflow?"
    Processes encapsulate a task with defined inputs, outputs, and commands.  
    They run independently and can scale across computing resources.

### Channels
??? question "What are channels in Nextflow?"
    Channels are asynchronous data streams that connect processes, passing input and output data between them.

### Outputs
??? question "How do I define outputs in Nextflow?"
    Outputs are declared using the `output` block in processes or workflows.  
    This defines what data is saved for downstream steps or exported from the workflow.

### Parallel Execution
??? question "How does Nextflow handle parallel execution?"
    Nextflow automatically runs independent processes in parallel based on available compute resources, enabling scalable execution.

### Reproducibility
??? question "How does Nextflow ensure reproducibility?"
    Nextflow supports containerization (Docker/Singularity) and environment specification, ensuring the same pipeline produces identical results across systems.

### Workflow Profiles
??? question "What are Nextflow profiles?"
    Profiles allow users to define environment-specific configurations, such as compute clusters, Docker images, and resource limits, for flexible pipeline execution.

### Learning Resources
??? question "Where can I learn more about Nextflow?"
    - [Nextflow Documentation](https://www.nextflow.io/docs/latest/index.html)  
    - [Nextflow Tutorials](https://nf-co.re/docs/usage/tutorials/nextflow)  
    - [Hello Nextflow Training](https://training.nextflow.io/2.0/hello_nextflow/)


---
## Performance
### Runtime, Memory, and Storage
??? question "What are the typical runtime, memory, and storage requirements?"
    - **Runtime**: Varies based on dataset size and computational resources. For 24 paired-end samples, it can take several hours to days.
    - **Memory**: Ranges from 6 GB to 200 GB depending on the step. Alignment and differential methylation analysis are more memory-intensive.
    - **Storage**: Approximately 2 TB for 24 paired-end samples, including intermediate files and results.
    
    | Process                       | Average Process Time | Average Wall Clock Time | Max Peak Memory | Total I/O (Read + Written) |
    |-------------------------------|----------------------|-------------------------|-----------------|----------------------------|
    | FastQC                        | 7m 3s                | 7m 2s                   | 628.4 MB        | 5.3 GB                     |
    | trim galore                   | 22m 1s               | 22m 0s                  | 348.2 MB        | 165.2 GB                   |
    | Bismark Genome Preparation    | 2h 24m 38s           | 2h 24m 37s              | 12.8 GB         | 47.8 GB                    |
    | Bismark Alignment             | 14h 27m 57s          | 14h 27m 56s             | 10.2 GB         | 229.8 GB                   |
    | Bismark Deduplication         | 29m 3s               | 29m 1s                  | 9.8 GB          | 95.8 GB                    |
    | Samtools sort                 | 8m 32s               | 8m 31s                  | 3.3 GB          | 14.8 GB                    |
    | Samtools index                | 1m 2s                | 1m 1s                   | 21.1 MB         | 4.8 GB                     |
    | Bismark Methylation extractor | 2h 56m 23s           | 2h 56m 22s              | 2 GB            | 258.4 GB                   |
    | Qualimap                      | 6m 29s               | 6m 29s                  | 12.1 GB         | 4.7 GB                     |
    | Bismark report                | 2.9s                 | 2.5s                    | 161.1 MB        | 7.1 MB                     |
    | Multiqc                       | 14.1s                | 13.3s                   | 80.5 MB         | 3.0 GB                     |
    | EdgeR analysis                | 46m 37s              | 46m 36s                 | 44.9 GB         | 8.9 GB                     |
    | Annotate results              | 5m 23s               | 5m 23s                  | 6.8 GB          | 1.8 GB                     |
    | GO analysis EdgeR             | 4m 15s               | 4m 15s                  | 6.4 GB          | 1.8 GB                     |
    | Post processing EdgeR         | 18m 40s              | 18m 40s                 | 9.3 GB          | 7.3 GB                     |
    | MethylKit analysis            | 2h 59m 19s           | 2h 59m 19s              | 37.6 GB         | 9.0 GB                     |
    | GO analysis methylKit         | 1m 44s               | 1m 44s                  | 3.9 GB          | 1.3 GB                     |
    | Post processing methylKit     | 8m 4s                | 8m 3s                   | 4.4 GB          | 3.5 GB                     |

