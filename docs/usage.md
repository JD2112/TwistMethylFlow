---
hide:
  - navigation
---

# Prerequisites

1. Install NextFlow (>=25.10.2)
2. Install Singularity (>=4.2.1) or Docker (>=28.5.2) or Conda (>=23.10.1).
3. Install NVIDIA CUDA Toolkit (>=12.8.0) _for GPU runs_

???+ danger "Important Information"
    Almost all tools in MethylFlow runs with Conda but for GPU runs, it is recommended to use Singularity or Docker. **Conda implementation for GPU runs is not recommended.**

## Getting Started

> NOTE: check if test data can be available for testing the pipeline.

The easiest way to run the pipeline is by using the following base command:

```bash
nextflow run JD2112/MethylFlow \
    -r 1.1.0 \
    -profile singularity,clinical \
    --sample_sheet Sample_sheet_twist.csv \
    --genome_fasta path/to/genome.fa \
    --diff_meth_method dss,edger \
    --gtf_file /data/Homo_sapiens.GRCh38.104.gtf \
    --refseq_file /data/hg38_RefSeq.bed.gz \
    --outdir Results/MethylFlow_Clinical
```

???+ note "Run Information"

    **Key Arguments:**

    - **`-r`**: Specifies the version or branch of the pipeline (e.g., `-r main` or `-r 1.1.0`).

    - **`-profile`**: Defines the execution environment and mode. You can combine multiple profiles using commas (e.g., `singularity,gpu,clinical`).
        - `singularity`: Recommended for HPC environments.
        - `docker`: Executes pipeline using Docker containers.
        - `conda`: Executes pipeline using Conda environments (requires `environment_main.yml`).
        - `clinical`: Enables clinical-style reporting mode.
        - `research`: Enables research mode (default).
        - `test_local`: Executes pipeline with a minimal test dataset (6 samples).
        - `test_full`: Executes pipeline with a test dataset mapping full differential methylation steps.
        - `gpu`: Enables NVIDIA Parabricks acceleration.

???+ info "Test the Pipeline"

    It is highly recommended to run the test profile on your system to ensure everything is configured properly before processing your own full datasets. The test runs require a GPU (from Parabricks) for maximum throughput and test real human genome data over varying sub-samples:

    **Local Test** (runs quickly, uses small subset of data):**

    ```
    nextflow run main.nf -profile test_local,singularity,gpu,clinical
    ```

    For a **full pipeline test** including calculating varying groups over 24 samples via all available statistical frameworks:

    ```
    nextflow run main.nf -profile test_full,singularity,gpu
    ```

    - `--sample_sheet`: Path to the CSV file describing your input data.
    - `--outdir`: The directory where all results, reports, and logs will be saved.

    Running the command will create the follwoing files in the working directory:

    ```
    work/                               # Nextflow's work directory for intermediate files
    .nextflow.log                       # Nextflow's log file
    Results/MethylFlow_GPU/        # Output directory
    # Other Nextflow hidden files, like pipeline history logs
    ```

## Running JD2112/MethylFlow with your data

Running the pipeline with your own data is as simple as running the base command with your:

1. Prepare a samplesheet,
2. Prepare reference files (Genome FASTA file, RefSeq BED file, and GTF file for annotation). If you are using **Twist Target Region BED file**, download it [here](https://www.twistbioscience.com/resources/data-files/twist-human-methylome-panel-target-bed-file).
3. Select workflows to run (select one or more methods).
4. Select a profile to run the pipeline (singularity, docker, conda, gpu, clinical, research).
5. Run the pipeline with the base command.

## 1. Samplesheet

To run the pipeline with your own data, you need to create a samplesheet that maps your raw sequencing data to specific groups for comparison. Use this parameter to specify the path to your samplesheet:

```bash
--sample_sheet path/to/samplesheet.csv
```

The pipeline requires a CSV samplesheet with a header row. This file maps your raw sequencing data to specific groups for comparison.

| Column Name | Description                                                                      |
| :---------- | :------------------------------------------------------------------------------- |
| `sample_id` | Unique name for the sample (Alphanumeric only: `A-Z`, `a-z`, `0-9`, `-`, `_`).   |
| `group`     | Experimental group (e.g., `Control`, `Disease`). Used for differential analysis. |
| `read1`     | Full path to the forward FASTQ file (`*_R1.fastq.gz`).                           |
| `read2`     | Full path to the reverse FASTQ file (`*_R2.fastq.gz`).                           |

???+ danger "HIPAA Compliance & PII"
    The `sample_id` field is strictly validated via JSON schema to prevent the accidental inclusion of Patient Identifiable Information (PII). **Spaces and special characters are forbidden.** This ensures that patient names or medical record numbers are not leaked into filenames, logs, or clinical reports.

### Example `samplesheet.csv`:

**Minimal Example Samplesheet (DONOT RUN)**

```bash
sample_id,group,read1,read2
SN09,Healthy,SN09_R1_001.fastq.gz,SN09_R2_001.fastq.gz
SN10,Disease,SN10_R1_001.fastq.gz,SN10_R2_001.fastq.gz
```

**Full Example Samplesheet**

??? info "Sample sheet Information"

    The following data was downloaded from [ENA webserver](https://www.ebi.ac.uk/ena/browser/view/ERP146869) and the original data was published in [Krumpolec et al (2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10835804)

    ```bash
    sample_id,group,read1,read2
    ERR11284501,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR112/001/ERR11284501/ERR11284501_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR112/001/ERR11284501/ERR11284501_2.fastq.gz
    ERR11435646,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/046/ERR11435646/ERR11435646_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/046/ERR11435646/ERR11435646_2.fastq.gz
    ERR11435647,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/047/ERR11435647/ERR11435647_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/047/ERR11435647/ERR11435647_2.fastq.gz
    ERR11435651,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/051/ERR11435651/ERR11435651_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/051/ERR11435651/ERR11435651_2.fastq.gz
    ERR11435652,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/052/ERR11435652/ERR11435652_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/052/ERR11435652/ERR11435652_2.fastq.gz
    ERR11435654,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/054/ERR11435654/ERR11435654_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/054/ERR11435654/ERR11435654_2.fastq.gz
    ERR11435659,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/059/ERR11435659/ERR11435659_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/059/ERR11435659/ERR11435659_2.fastq.gz
    ERR11435661,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/061/ERR11435661/ERR11435661_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/061/ERR11435661/ERR11435661_2.fastq.gz
    ERR11435663,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/063/ERR11435663/ERR11435663_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/063/ERR11435663/ERR11435663_2.fastq.gz
    ERR11435640,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/040/ERR11435640/ERR11435640_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/040/ERR11435640/ERR11435640_2.fastq.gz
    ERR11435643,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/043/ERR11435643/ERR11435643_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/043/ERR11435643/ERR11435643_2.fastq.gz
    ERR11435644,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/044/ERR11435644/ERR11435644_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/044/ERR11435644/ERR11435644_2.fastq.gz
    ERR11435645,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/045/ERR11435645/ERR11435645_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/045/ERR11435645/ERR11435645_2.fastq.gz
    ERR11435649,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/049/ERR11435649/ERR11435649_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/049/ERR11435649/ERR11435649_2.fastq.gz
    ERR11435650,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/050/ERR11435650/ERR11435650_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/050/ERR11435650/ERR11435650_2.fastq.gz
    ERR11435653,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/053/ERR11435653/ERR11435653_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/053/ERR11435653/ERR11435653_2.fastq.gz
    ERR11435655,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/055/ERR11435655/ERR11435655_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/055/ERR11435655/ERR11435655_2.fastq.gz
    ERR11435657,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/057/ERR11435657/ERR11435657_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/057/ERR11435657/ERR11435657_2.fastq.gz
    ERR11435641,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/041/ERR11435641/ERR11435641_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/041/ERR11435641/ERR11435641_2.fastq.gz
    ERR11435642,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/042/ERR11435642/ERR11435642_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/042/ERR11435642/ERR11435642_2.fastq.gz
    ERR11435648,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/048/ERR11435648/ERR11435648_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/048/ERR11435648/ERR11435648_2.fastq.gz
    ERR11435656,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/056/ERR11435656/ERR11435656_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/056/ERR11435656/ERR11435656_2.fastq.gz
    ERR11435658,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/058/ERR11435658/ERR11435658_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/058/ERR11435658/ERR11435658_2.fastq.gz
    ERR11435660,VD,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/060/ERR11435660/ERR11435660_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/060/ERR11435660/ERR11435660_2.fastq.gz
    ERR11435662,CS,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/062/ERR11435662/ERR11435662_1.fastq.gz,https://ftp.sra.ebi.ac.uk/vol1/fastq/ERR114/062/ERR11435662/ERR11435662_2.fastq.gz
    ```

???+ warning "Differential Methylation Analysis Requirements"

    You must have **minimum 3 samples per group** to perform a statistically valid differential methylation analysis.

???+ note "Replicating the analysis in the publication (Krumpolec et al 2024)"

    1. Download the fastq.gz files from [https://www.ebi.ac.uk/ena/browser/view/ERP146869](https://www.ebi.ac.uk/ena/browser/view/ERP146869)
    2. Download TSV file with "sample_alias" (`examples/filereport_read_run_ERP146869.tsv`)
    3. Run `bin/map_era_samples.py` to get the final csv file (`examples/Sample_sheet_replicate.csv`). Note- provide exact file path.
    4. Run nextflow `nextflow run main.nf -profile replicate_article,singularity,gpu`

        a. provide `hg19.fasta` file. [https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.13/](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.13/)

        b. provide `covered_targets_Twist_Methylome_hg19_annotated_collapsed_final.bed.zip` file [https://www.twistbioscience.com/resources/data-files/twist-human-methylome-panel-target-bed-file](https://www.twistbioscience.com/resources/data-files/twist-human-methylome-panel-target-bed-file)

## 2. Reference files

MethylFlow requires the following reference files:

1. Genome FASTA file
2. RefSeq BED file
3. GTF file
4. Twist Target Region BED file (optional)

??? warning "Reference Files"

    The reference files should matched with the parameters configuration file in the pipeline. Check the [parameters configuration file](parameters.md) for more information.

    **Example: For human genome assembly GRCh38**

    1. Download the [Genome Fasta file](https://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.toplevel.fa.gz).

    2. Download the [RefSeq bed file](https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg38_RefSeq.bed.gz/download).

    3. Download the [GTF file](https://ftp.ensembl.org/pub/release-104/gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz).

    4. Download the [Twist Target Region BED file](https://www.twistbioscience.com/resources/data-files/twist-human-methylome-panel-target-bed-file).

## 3. Subworkflows

As mentioned above, MethylFlow has several subworkflows, each with its own set of parameters and outputs.

1. Running the pipeline with default CPU track (`bismark`) or GPU track (`parabricks`). To run with the GPU track, the user need to set the `--profile gpu`. By default, the pipeline will run with the CPU track.
2. User can choose to run the pipeline with directly with reference genome fasta file `--genome_fasta [path/to/fasta]` or bismark indexed file `--bismark_index [path/to/index]`. Default is `--genome_fasta [path/to/fasta]`.
3. User also has the option to run the pipeline with aligned BAM files `--aligned_bams [path/to/bams]`. Default is `false`.
4. For the differential methylation analysis, the user can choose to run the pipeline with one or more methods: `--diff_meth_method dss`, `--diff_meth_method edger` or `--diff_meth_method methylkit`. Default is `dss`. If the user wants to run multiple methods, the user can provide a comma-separated list, e.g. `--diff_meth_method dss,edger`. They can also choose to skip the differential methylation analysis by setting the `--skip_diff_meth true`.

## 3.1. Quality Control & Trimming

Before alignment, the pipeline ensures your data is clean and high-quality. The pipeline uses `fastqc` to assess the raw sequencing quality and `trim_galore` to remove adapter sequences and clip low-quality base calls from the ends of reads. These are default parameters and user can adjust the `--fastqc` and `--trim_galore` arguments using `--args` to change the default parameters.

The pipelines also generates a post-alignments quality control report using `qualimap` and a multiqc report using `multiqc`. User can adjust the `multiqc_config` and `multiqc_title` arguments to change the default parameters. For qualimap extra arguments, check the [Qualimap arguments](https://qualimap.bioinfo.cipf.es/doc/qualimap.html). For multiqc extra arguments, check the [MultiQC arguments](https://multiqc.info/docs/).

???+ note "FastQC arguments"
    Check this page for more information: [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/). For fastqc extra arguments, check the [FastQC arguments](https://home.cc.umanitoba.ca/~psgendb/doc/fastqc.help).

???+ note "Trim Galore! arguments"
    Check this page for more information: [Trim Galore!](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/). For trim_galore extra arguments, check the [Trim Galore! arguments](https://github.com/FelixKrueger/TrimGalore/blob/master/Docs/Trim_Galore_User_Guide.md).

| Parameters         | Description                                                                                             |
| :----------------- | :------------------------------------------------------------------------------------------------------ |
| `--multiqc_config` | multiqc config file. Default is `null`. `--multiqc_config [path/to/config]` to use multiqc config file. |
| `--multiqc_title`  | multiqc title. Default is `null`. `--multiqc_title [title]` to use multiqc title.                       |
| `--qualimap_args`  | qualimap arguments. Default is `null`. `--qualimap_args [args]` to use qualimap arguments.              |

## 3.2. Alignment & Processing

Aligment is the default track used in the pipeline if not the `--aligned_bams true` is specified. The standard CPU track uses the Bismark suite for comprehensive bisulfite analysis.

### Bismark (CPU Track)

Prepares the reference genome for bisulfite alignment by converting it _in silico_ (**C->T** and **G->A**). The default parameter is `--genome_fasta [path/to/fasta]`. User can also use `--bismark_index [path/to/index]` to skip this step if they already have a pre-built index. Maps trimmed reads to the converted reference using Bowtie2. The default parameter is `--aligner bismark`. Removes PCR duplicates based on mapping position. The default process is `BISMARK_DEDUPLICATE`. It is essential for accurate methylation estimation, as duplicates can bias the counts. `samtools` is used to convert the Bismark output into sorted/indexed BAM files for downstream compatibility.

### BWA-meth (GPU Track)

Since `bismark` is quite slow and runs only on CPU, we recommend using the GPU track for larger datasets. User can modify the GPU runs by changing the `conf/gpu.config` file.

When the GPU profile is active, the pipeline automatically builds a **BWA-meth index**, which is required by NVIDIA Parabricks. Use `--aligner bwameth` to use the GPU track. A highly optimized, GPU-accelerated version of the alignment and deduplication process. The default parameter is `--use_parabricks true` and `-profile gpu`. User can also use `--aligner bwameth` to use the GPU track.

## 3.3. Methylation calls

This stage converts aligned BAM files into site-specific methylation counts.

### Bismark Methylation Extractor (CPU)

The pipeline extracts CpG, CHG, and CHH methylation calls using the `BISMARK_METHYLATION_EXTRACTOR` process and generates `.cov.gz` files containing methylation percentages and coverage.

### MethylDackel (GPU)

Used in the GPU track for rapid extraction of methylation metrics directly from Parabricks BAMs. The pipeline extracts CpG, CHG, and CHH methylation calls using the `METHYLDACKEL_EXTRACT` process and generates `.cov.gz` files containing methylation percentages and coverage.

| Parameters         | Description                                                                                          |
| :----------------- | :--------------------------------------------------------------------------------------------------- |
| `--profile`        | use cpu or gpu track. Default is `cpu`. `--profile gpu` to use GPU track.                            |
| `--aligner`        | aligner to use. Default is `bismark`. Change to `bwameth` to use BWA-meth.                           |
| `--use_parabricks` | use NVIDIA Parabricks. Default is `false`. `--use_parabricks true` to use NVIDIA Parabricks.         |
| `--genome_fasta`   | genome fasta file. Default is `false`. `--genome_fasta [path/to/fasta]` to use genome fasta file.    |
| `--bismark_index`  | bismark index file. Default is `false`. `--bismark_index [path/to/index]` to use bismark index file. |
| `--aligned_bams`   | aligned bams file. Default is `false`. `--aligned_bams [path/to/bams]` to use aligned bams file.     |

## 4. Downstream Processing

Once methylation calls are extracted, the pipeline performs statistical analysis to identify differentially methylated regions and genes, if not skipped by the user using `--skip_diff_meth true`. By default, the pipeline will run the differential methylation analysis using `diff_meth_method` parameter. The default parameter is `--diff_meth_method dss`. User can also use `--diff_meth_method edger` or `--diff_meth_method methylkit` to run the differential methylation analysis using EdgeR or MethylKit. If the user wants to run all methods, the user can set the `--diff_meth_method all`.

### Coverage Filtering and differential methylation analysis

Before the differential methylation analysis, CpG sites with low read depth are filtered out to ensure statistical power using `--coverage_threshold` (Default: `3`). It also checks for the presence of samplesheet using `--compare_str` parameter. By default, the `--compare_str all` to ensure comparing different groups in the samplesheet.

For example,

1. if the user has a samplesheet with **two groups**, "_control_" and "_treatment_", the user can set the `--compare_str "control,treatment"` to compare the two groups. The output will be a CSV file with the differentially methylated regions and genes.

2. if the user has a design file with **three groups**, "_control_", "_treatment1_", and "_treatment2_", the user can set the `--compare_str "control,treatment1,treatment2"` to compare the three groups. The output will be a CSV file with the differentially methylated regions and genes.

| Parameters             | Description                                                                                                                    |
| :--------------------- | :----------------------------------------------------------------------------------------------------------------------------- |
| `--coverage_threshold` | Minimum coverage threshold for filtering CpG sites. Default is `3`.                                                            |
| `--compare_str`        | String of groups to compare (e.g., `control,disease`). Default is `all` to compare all groups in the samplesheet.              |
| `--diff_meth_method`   | Method to use for differential methylation analysis. Default is `dss`. Provide comma-separated list for multiple methods.      |
| `--skip_diff_meth`     | Skip differential methylation analysis. Default is `false`. `--skip_diff_meth true` to skip differential methylation analysis. |

### Post-processing and Enrichment Analysis

The pipeline performs post-processing and functional enrichment analysis on the differentially methylated regions and genes. For edgeR, it requires annotation with a GTF file (`--gtf_file`). For methylKit and DSS, it uses RefSeq data (`--refseq_file`). The post-processing steps produce a unified results layer that integrates statistical summaries of CpGs, DMRs, and genes.

#### Functional Enrichment

The pipeline performs advanced enrichment analysis using the **clusterProfiler** package:

- **GO Enrichment**: Molecular Function, Cellular Component, and Biological Process.
- **KEGG Pathway Enrichment**: Identification of significantly enriched biological pathways.
- **Disease Annotation**: Automated disease association analysis using the **DisGeNET** database.

The pipeline also generates a **Chord Diagram** (using `GOChord`) and Dot Plots to visualize the relationship between genes and their associated pathways.

#### Key Parameters

| Parameters              | Description                                                                   |
| :---------------------- | :---------------------------------------------------------------------------- |
| `--top_n_genes`         | Number of top genes to use for enrichment analysis. Default is `100`.         |
| `--mode`                | Pipeline mode: `research` (default) or `clinical` (unified reporting enabled) |
| `--run_clinical_report` | Force generation of Quarto clinical PDF report (default: false)               |
| `--promoter_dist`       | Distance from TSS to define a Promoter region (default: 2000)                 |
| `--enhancer_dist`       | Distance from TSS to define an Enhancer/Distal region (default: 10000)        |

The post-processing also generates volcano plots for all comparisons. You can adjust the plotting aesthetics in `conf/params.config`.

| Parameters        | Description                                             |
| :---------------- | :------------------------------------------------------ |
| `--logfc_cutoff`  | Log fold change cutoff for significance. Default `0.5`. |
| `--pvalue_cutoff` | P-value cutoff for significance. Default `0.05`.        |
| `--hyper_color`   | Color for hypermethylated regions. Default `red`.       |
| `--hypo_color`    | Color for hypomethylated regions. Default `blue`.       |
| `--nonsig_color`  | Color for non-significant regions. Default `black`.     |

## Runtime estimates

Runtime Varies based on dataset size and computational resources.

With **_CPU track_**, it can take several hours to days depending on the number of samples on a single node (dual Intel(R) Xeon(R) Platinum 8592+ CPU @3.90GHz). The most time-consuming step is _bismark alignment_ step. Approximately ~14-15 hours per sample is required to perform _bismark alignment_ step. Next, the bismark methylation calls step takes ~2-3 hours per sample.

While on **_GPU track_** (with 3 x L40S GPU with 48GB VRAM), for alignment step, it takes only 15-20 minutes per sample and similar time for methylation calls step. Typically memory ranges from <1 GB to 40 GB depending on the step. Alignment and differential methylation analysis are more memory-intensive.

Approximately 2 TB for 24 paired-end samples, including intermediate files and results.

???+ info "Runtime estimates"

    | Feature | CPU Track (Standard) | GPU Track (Parabricks) |
    | :--- | :--- | :--- |
    | Time/sample | 16-18 hours | 15-20 minutes |
    | Hardware | 12+ CPU Cores | NVIDIA GPU (16GB+ VRAM) |
    | Memory | ~10 GB | ~40 GB |
    | Storage | ~2 TB | ~2 TB |

## Reproducibility & Determinism

MethylFlow is designed for **Bitwise Reproducibility**. Using the version tag, the user can run the pipeline with the same version of the code (`-r 1.1.0`).

Furthermore, the pipeline enforces **Statistical Determinism** by injecting fixed random seeds (`set.seed(42)`) into all R-based modules (edgeR, methylKit, DSS, Enrichment). This ensures that even algorithms relying on random sampling will produce identical P-values and results across different computational environments.

## Clinical Data Integrity

To meet clinical-grade standards, the pipeline implements automated data governance:

1.  **Input Integrity (SHA256)**: The pipeline automatically calculates the cryptographic SHA256 checksum of every input FASTQ file. These hashes are stored in the results and printed in the Clinical Report, providing a verifiable audit trail that the data has not been corrupted during transfer or processing.
2.  **Output Sanity Checks**: The reporting layer performs automated Pass/Fail validation. It checks if samples meet the required coverage threshold and mapping quality. Failures are highlighted as high-visibility warnings in the final report.
3.  **Full Audit Trail**: The Clinical Report embeds a complete snapshot of all **resolved Nextflow parameters** in JSON format, ensuring absolute transparency regarding the thresholds and settings used for the analysis.

## Core Nextflow arguments

???+ info "Core Nextflow arguments"

    These options are passed directly to Nextflow using a _single_ hyphen.

    `-profile`

    Using the `-profile` option, the user can select a profile to run the pipeline. The available profiles are `singularity`, `docker`, and `conda`. The user can also combine profiles using a comma, e.g. `-profile singularity`. It will run directly on the contenarized system using the cpu. To run on GPU, use `-profile singularity,gpu`.

    `-resume`

    Using the `-resume` option, the user can resume a previous run of the pipeline. The user can use this option to resume a previous run of the pipeline. The user can use this option to resume a previous run of the pipeline. The user can use this option to resume a previous run of the pipeline.

    `-c`

    Using the `-c` option, the user can specify a configuration file to run the pipeline. The user can use this option to specify a configuration file to run the pipeline. The user can use this option to specify a configuration file to run the pipeline. The user can use this option to specify a configuration file to run the pipeline.

    `-name`

    Using the `-name` option, the user can specify a name for the run. The user can use this option to specify a name for the run. The user can use this option to specify a name for the run. The user can use this option to specify a name for the run.

## Nextflow memory requirements

Nextflow Java virtual machines can start to request a large amount of memory. User can add the following line to the `~/.bashrc` or `~/.zshrc` file to increase the memory limit:

```bash
NXF_OPTS="-Xms4g -Xmx16g"
```

For a full list of flags, see the [Parameters Reference](parameters.md).
