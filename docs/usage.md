---
hide:
  - navigation
---

# milou User Manual

## 1. Prerequisites & Environment

milou requires a POSIX-compliant environment (Linux/macOS) with the following minimum software foundations:

1. **Nextflow**: Version `>= 24.04.2` (tested up through `25.10.x`).
2. **Container Engine**: **Singularity / Apptainer** (`>= 3.8.0`, recommended for HPC) or **Docker** (`>= 20.10`).
3. **NVIDIA CUDA Driver & Toolkit** (`>= 12.0`): Required *only* when executing the high-throughput GPU alignment track.

???+ note "Nextflow JVM Memory Configuration"
    For large cohorts, ensure Nextflow has sufficient Java heap memory allocated in your shell environment (`~/.bashrc` or `~/.zshrc`):
    ```bash
    export NXF_OPTS="-Xms4g -Xmx16g"
    ```
???+ danger "Important Information"
    Almost all tools in milou run with Conda, but for GPU runs, it is recommended to use Singularity or Docker. 
    
    **Conda implementation for GPU runs is not recommended.**

## 2. Quick Start & Execution Profiles

### 2.1 Basic Execution Syntax

Run the pipeline using the base syntax:

```bash
nextflow run JD2112/milou \
    -r 1.2.0 \
    -profile singularity,clinical \
    --sample_sheet samplesheet.csv \
    --genome_fasta /data/genomes/GRCh38.fa \
    --diff_meth_method dss,edger \
    --outdir results/milou_clinical
```

???+ note "Run Information"

    **Key Arguments:**

    - **`-r`**: Specifies the version or branch of the pipeline (e.g., `-r main` or `-r 1.2.0`).

    - **`-profile`**: Defines the execution environment and mode. You can combine multiple profiles using commas (e.g., `singularity,gpu,clinical`).
        - `singularity`: Recommended for HPC environments.
        - `docker`: Executes pipeline using Docker containers.
        - `conda`: Executes pipeline using Conda environments (requires `environment_main.yml`).
        - `clinical`: Enables clinical-style reporting mode.
        - `clinical_offline`: Enables strict air-gapped clinical mode, disabling all external internet egress.
        - `research`: Enables research mode (default).
        - `test_local`: Executes pipeline with a minimal test dataset (6 samples).
        - `test_full`: Executes pipeline with a test dataset mapping full differential methylation steps.
        - `gpu`: Enables NVIDIA Parabricks acceleration.

???+ info "Test the Pipeline"

    It is highly recommended to run the test profile on your system to ensure everything is configured properly before processing your own full datasets. The test runs require a GPU (from Parabricks) for maximum throughput and test real human genome data over varying sub-samples:

    **Local Test** (runs quickly, uses small subset of data):

    ```bash
    nextflow run main.nf -profile test_local,singularity,gpu,clinical
    ```

    **Full Pipeline Test** (multi-group evaluation across 24 samples):

    ```bash
    nextflow run main.nf -profile test_full,singularity,gpu
    ```

    Running the test command will generate standard pipeline files in your working directory:

    ```
    work/                               # Nextflow intermediate task executions
    .nextflow.log                       # Detailed execution log
    results/milou_gpu/                  # Published outputs, QC dashboards, and Quarto reports
    ```

### 2.2 Cohort Execution Archetypes

=== "Whole-Genome Bisulfite (WGBS) - GPU"
    ```bash
    nextflow run JD2112/milou -r 1.2.0 \
        -profile gpu,singularity,clinical \
        --sample_sheet samplesheet_wgbs.csv \
        --genome_fasta GRCh38.primary_assembly.fa \
        --diff_meth_method all \
        --smoothing FALSE \
        --outdir results/wgbs_cohort
    ```
    *(Note: `--smoothing FALSE` is recommended for whole-genome cohorts to contain DSS memory under 50 GB RAM across all 28M human CpGs).*

=== "Enzymatic Methyl-Seq (EM-seq) - CPU"
    ```bash
    nextflow run JD2112/milou -r 1.2.0 \
        -profile singularity,clinical \
        --sample_sheet samplesheet_emseq.csv \
        --genome_fasta GRCh38.fa \
        --assay_type emseq \
        --diff_meth_method dss,edger \
        --outdir results/emseq_cohort
    ```

=== "Targeted Hybridization Capture (Twist Panel)"
    ```bash
    nextflow run JD2112/milou -r 1.2.0 \
        -profile gpu,singularity,clinical \
        --sample_sheet samplesheet_twist.csv \
        --genome_fasta GRCh38.fa \
        --assay_type twist \
        --diff_meth_method all \
        --outdir results/twist_cohort
    ```

???+ info "Running JD2112/milou with your data"

    Running the pipeline with your own data is as simple as running the base command with your:

    1. Prepare a samplesheet,
    2. Prepare reference files (Genome FASTA file, RefSeq BED file, and GTF file for annotation). If you are using **Twist Target Region BED file**, download it [here](https://www.twistbioscience.com/resources/data-files/twist-human-methylome-panel-target-bed-file).
    3. Select workflows to run (select one or more methods).
    4. Select a profile to run the pipeline (singularity, docker, conda, gpu, clinical, research).
    5. Run the pipeline with the base command.

## 3. Sample Sheet & Reference Specifications

### 3.1 Sample Sheet Format (`samplesheet.csv`)
The pipeline requires a CSV samplesheet with a header row. This file maps your raw sequencing data to specific groups for comparison.

#### 3.1.1 Required Column Schema

| Column Header | Requirement | Description |
| :--- | :---: | :--- |
| `sample_id` | Required | Unique alphanumeric sample identifier (`A-Z`, `a-z`, `0-9`, `-`, `_`). |
| `group` | Required | Experimental group or clinical condition (e.g., `Control`, `Treated`). Minimum 3 replicates per group required for differential methylation. |
| `read1` | Required | Local filepath or remote URL to the forward paired-end FASTQ (`.fastq.gz`). |
| `read2` | Required | Local filepath or remote URL to the reverse paired-end FASTQ (`.fastq.gz`). |
| `assay_type` | Optional | Per-sample assay override: `wgbs`, `emseq`, or `twist`. |

???+ danger "HIPAA Compliance & PII"
    The `sample_id` field is strictly validated via JSON schema to prevent the accidental inclusion of Patient Identifiable Information (PII). **Spaces and special characters are forbidden.** This ensures that patient names or medical record numbers are not leaked into filenames, logs, or clinical reports.

#### 3.1.2 Minimal & Benchmark Cohort Examples

**Minimal Example Samplesheet (DONOT RUN)**

```bash
sample_id,group,read1,read2
SN09,Healthy,SN09_R1_001.fastq.gz,SN09_R2_001.fastq.gz
SN10,Disease,SN10_R1_001.fastq.gz,SN10_R2_001.fastq.gz
```

**Full Example Samplesheet**

[Check out benchmarked Sample_sheet.csv](https://github.com/JD2112/milou)

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

### 3.2 Reference Files & Genome Builds
* **Genome FASTA (`--genome_fasta`)**: Uncompressed or `.gz` FASTA containing primary assembly chromosomes.
* **GTF Annotation (`--gtf_file`)**: Ensembl/GENCODE GTF for genomic feature mapping (promoters, exons, introns).
* **RefSeq BED (`--refseq_file`)**: Gene model coordinates for Gviz locus visualizations.
* **Target BED (`--methylkit.bed_file`)**: Required for targeted hybrid-capture panels (e.g. Twist Human Methylome).

??? warning "Reference Files"

    The reference files should matched with the parameters configuration file in the pipeline. Check the [parameters configuration file](parameters.md) for more information.

    **Example: For human genome assembly GRCh38**

    1. Download the [Genome Fasta file](https://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.toplevel.fa.gz).

    2. Download the [RefSeq bed file](https://sourceforge.net/projects/rseqc/files/BED/Human_Homo_sapiens/hg38_RefSeq.bed.gz/download).

    3. Download the [GTF file](https://ftp.ensembl.org/pub/release-104/gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz).

    4. Download the [Twist Target Region BED file](https://www.twistbioscience.com/resources/data-files/twist-human-methylome-panel-target-bed-file).


## 4. Pipeline Architecture & Subworkflows

As mentioned above, milou has several subworkflows, each with its own set of parameters and outputs:

1. Running the pipeline with default CPU track (`bismark`) or GPU track (`parabricks`). To run with the GPU track, the user need to set the `--profile gpu`. By default, the pipeline will run with the CPU track.
2. User can choose to run the pipeline with directly with reference genome fasta file `--genome_fasta [path/to/fasta]` or bismark indexed file `--bismark_index [path/to/index]`. Default is `--genome_fasta [path/to/fasta]`.
3. User also has the option to run the pipeline with aligned BAM files `--aligned_bams [path/to/bams]`. Default is `false`.
4. For the differential methylation analysis, the user can choose to run the pipeline with one or more methods: `--diff_meth_method dss`, `--diff_meth_method edger` or `--diff_meth_method methylkit`. Default is `dss`. If the user wants to run multiple methods, the user can provide a comma-separated list, e.g. `--diff_meth_method dss,edger`. They can also choose to skip the differential methylation analysis by setting the `--skip_diff_meth true`.

### 4.1 Quality Control & Adapter Trimming

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

### 4.2 Read Alignment & BAM Processing

Aligment is the default track used in the pipeline if not the `--aligned_bams true` is specified. The standard CPU track uses the Bismark suite for comprehensive bisulfite analysis.

#### 4.2.1 Bismark Alignment (CPU Track)

Prepares the reference genome for bisulfite alignment by converting it _in silico_ (**C->T** and **G->A**). The default parameter is `--genome_fasta [path/to/fasta]`. User can also use `--bismark_index [path/to/index]` to skip this step if they already have a pre-built index. Maps trimmed reads to the converted reference using Bowtie2. The default parameter is `--aligner bismark`. Removes PCR duplicates based on mapping position. The default process is `BISMARK_DEDUPLICATE`. It is essential for accurate methylation estimation, as duplicates can bias the counts. `samtools` is used to convert the Bismark output into sorted/indexed BAM files for downstream compatibility.

#### 4.2.2 BWA-meth / Clara Parabricks (GPU Track)

Since `bismark` is quite slow and runs only on CPU, we recommend using the GPU track for larger datasets. User can modify the GPU runs by changing the `conf/gpu.config` file.

When the GPU profile is active, the pipeline automatically builds a **BWA-meth index**, which is required by NVIDIA Parabricks. Use `--aligner bwameth` to use the GPU track. A highly optimized, GPU-accelerated version of the alignment and deduplication process. The default parameter is `--use_parabricks true` and `-profile gpu`. User can also use `--aligner bwameth` to use the GPU track.

### 4.3 Methylation Calling & Extraction

This stage converts aligned BAM files into site-specific methylation counts.

#### 4.3.1 Bismark Methylation Extractor (CPU Track)

The pipeline extracts CpG, CHG, and CHH methylation calls using the `BISMARK_METHYLATION_EXTRACTOR` process and generates `.cov.gz` files containing methylation percentages and coverage.

#### 4.3.2 MethylDackel Extraction (GPU Track)

Used in the GPU track for rapid extraction of methylation metrics directly from Parabricks BAMs. The pipeline extracts CpG, CHG, and CHH methylation calls using the `METHYLDACKEL_EXTRACT` process and generates `.cov.gz` files containing methylation percentages and coverage.

| Parameters         | Description                                                                                          |
| :----------------- | :--------------------------------------------------------------------------------------------------- |
| `--profile`        | use cpu or gpu track. Default is `cpu`. `--profile gpu` to use GPU track.                            |
| `--aligner`        | aligner to use. Default is `bismark`. Change to `bwameth` to use BWA-meth.                           |
| `--use_parabricks` | use NVIDIA Parabricks. Default is `false`. `--use_parabricks true` to use NVIDIA Parabricks.         |
| `--genome_fasta`   | genome fasta file. Default is `false`. `--genome_fasta [path/to/fasta]` to use genome fasta file.    |
| `--bismark_index`  | bismark index file. Default is `false`. `--bismark_index [path/to/index]` to use bismark index file. |
| `--aligned_bams`   | aligned bams file. Default is `false`. `--aligned_bams [path/to/bams]` to use aligned bams file.     |

## 5. Downstream Statistical Analysis

Once methylation calls are extracted, the pipeline performs statistical analysis to identify differentially methylated regions and genes, if not skipped by the user using `--skip_diff_meth true`. By default, the pipeline will run the differential methylation analysis using `diff_meth_method` parameter. The default parameter is `--diff_meth_method dss`. User can also use `--diff_meth_method edger` or `--diff_meth_method methylkit` to run the differential methylation analysis using EdgeR or MethylKit. If the user wants to run all methods, the user can set the `--diff_meth_method all`.

### 5.1 Coverage Filtering & Group Comparisons

Before the differential methylation analysis, CpG sites with low read depth are filtered out to ensure statistical power using `--coverage_threshold` (Default: `3`). It also checks for the presence of samplesheet using `--compare_str` parameter. By default, the `--compare_str all` to ensure comparing different groups in the samplesheet.

For example:

1. If the user has a samplesheet with **two groups**, "_control_" and "_treatment_", the user can set the `--compare_str "control,treatment"` to compare the two groups. The output will be a CSV file with the differentially methylated regions and genes.
2. If the user has a design file with **three groups**, "_control_", "_treatment1_", and "_treatment2_", the user can set the `--compare_str "control,treatment1,treatment2"` to compare the three groups. The output will be a CSV file with the differentially methylated regions and genes.

| Parameters             | Description                                                                                                                    |
| :--------------------- | :----------------------------------------------------------------------------------------------------------------------------- |
| `--coverage_threshold` | Minimum coverage threshold for filtering CpG sites. Default is `3`.                                                            |
| `--compare_str`        | String of groups to compare (e.g., `control,disease`). Default is `all` to compare all groups in the samplesheet.              |
| `--diff_meth_method`   | Method to use for differential methylation analysis. Default is `dss`. Provide comma-separated list for multiple methods.      |
| `--skip_diff_meth`     | Skip differential methylation analysis. Default is `false`. `--skip_diff_meth true` to skip differential methylation analysis. |

### 5.2 Multi-Method Consensus Scoring Framework (π-Value)

A central innovation of *milou* is its multi-method consensus scoring framework, designed to overcome the divergence between disparate differential methylation algorithms.

#### 5.2.1 The Epigenetic Challenge
Distinct differential methylation callers rely on fundamentally different mathematical and statistical distributions:

* **DSS**: Employs a Bayesian hierarchical β-binomial distribution with spatial smoothing across adjacent CpGs and empirical Bayes dispersion shrinkage.
* **edgeR**: Models count data via generalized linear models (GLMs) with negative binomial quasi-likelihood *F*-tests.
* **methylKit**: Fits logistic regression models with overdispersion correction.

Because each engine operates under distinct distributional assumptions, candidate gene lists from single tools frequently diverge, especially in cohorts with modest sequencing coverage or high biological variability.

#### 5.2.2 Mathematical Formulation of the π-Value
To synthesize these orthogonal outputs into a deterministic, clinically actionable ranking, *milou* adapts the $\pi$-value framework (Xiao et al., 2014) for DNA methylation data:

$$\pi_{g} = \overline{\left| \log_{2}{(FC)}_{g} \right|} \times \left( - \log_{10}(P_{\min,g}) \right)$$

Where:

* $\overline{\left| \log_{2}{(FC)}_{g} \right|}$ is the mean absolute effect size ($\log_2 \text{FC}$ or $|\Delta\beta|$) across all statistical engines that detected gene $g$ as differentially methylated.
* $P_{\min,g}$ is the most significant (minimum) $p$-value observed across the callers for that gene.

#### 5.2.3 Biological Prioritization vs. Classical Meta-Analysis
Standard meta-analytic methods, such as Fisher's Combined Probability Test:

$$\chi^{2} = - 2\sum_{i=1}^{k}{\ln(p_{i})}$$

rank candidate genes purely on cumulative statistical significance. In high-depth NGS cohorts, this often leads to a major clinical pitfall: **biologically trivial methylation shifts** (e.g., $|\Delta\beta| < 0.05$) can achieve extreme $p$-values simply due to large sample numbers or high read counts.

In contrast, the $\pi$-value:

1. **Balances Statistical Rigor and Biological Magnitude**: It directly weights biological effect size ($|\Delta\beta|$), ensuring that top-ranked biomarkers exhibit substantial epigenetic perturbation.
2. **Suppresses Analytical Noise**: Features detected by only a single engine with marginal significance are de-prioritized.
3. **Strong Empirical Concordance**: As demonstrated in our whole-genome Alzheimer's benchmark (Fetahu et al. cohort), $\pi$-value ranking correlates strongly with Fisher's test ($r_s = 0.9269, p < 2.2 \times 10^{-16}$) while correctly reprioritizing biologically critical targets (e.g., *ABCA13*, *IMPG1*) over candidates with negligible effect sizes.

#### 5.2.4 Consensus Modes & Output Artifacts

* `--mode research` (*default*): Retains all detected features while calculating cross-engine $\pi$-values and rank orders.
* `--mode clinical`: Enforces strict **majority consensus voting** (requires a feature to be independently called by at least 2 out of 3 differential callers), filtering out single-caller artifacts before clinical reporting.

The resulting prioritized tables are output to:
* `results/unified_layer/consensus_pi_value_ranking.tsv`
* `results/unified_layer/unified_consensus_ranking.csv`
* The interactive candidate tables and volcano plots in `results/clinical_reporting/milou_clinical_report.html` (and `.pdf`).

### 5.3 Post-Processing & Functional Enrichment Analysis

The pipeline performs post-processing and functional enrichment analysis on the differentially methylated regions and genes. For edgeR, it requires annotation with a GTF file (`--gtf_file`). For methylKit and DSS, it uses RefSeq data (`--refseq_file`). The post-processing steps produce a unified results layer that integrates statistical summaries of CpGs, DMRs, and genes.

#### 5.3.1 Functional Enrichment (GO, KEGG, DisGeNET)

The pipeline performs advanced enrichment analysis using the **clusterProfiler** package:

- **GO Enrichment**: Molecular Function, Cellular Component, and Biological Process.
- **KEGG Pathway Enrichment**: Identification of significantly enriched biological pathways.
- **Disease Annotation**: Automated disease association analysis using the **DisGeNET** database.

The pipeline also generates a **Chord Diagram** (using `GOChord`) and Dot Plots to visualize the relationship between genes and their associated pathways.

#### 5.3.2 Key Parameters & Visualization Controls

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

## 6. Performance, Reproducibility & Data Governance

### 6.1 Runtime Estimates & Hardware Benchmarks

Runtime varies based on dataset size and computational resources.

With the **_CPU track_**, processing can take several hours to days depending on the number of samples on a single node (dual Intel(R) Xeon(R) Platinum 8592+ CPU @3.90GHz). The most time-consuming step is the _bismark alignment_ step, requiring approximately ~14–15 hours per sample. The bismark methylation calling step takes ~2–3 hours per sample.

On the **_GPU track_** (with 3 x NVIDIA L40S GPUs, 48GB VRAM), alignment takes only 15–20 minutes per sample, and a similar duration for methylation extraction. Memory ranges from <1 GB to 40 GB depending on the step.

Storage footprint is approximately 2 TB for a 24 paired-end sample cohort, including intermediate work files and final results.

???+ info "Runtime Benchmarks Overview"

    | Feature | CPU Track (Standard) | GPU Track (Parabricks) |
    | :--- | :--- | :--- |
    | Time/sample | 16-18 hours | 15-20 minutes |
    | Hardware | 12+ CPU Cores | NVIDIA GPU (16GB+ VRAM) |
    | Memory | ~10 GB | ~40 GB |
    | Storage | ~2 TB | ~2 TB |

### 6.2 Bitwise Reproducibility & Statistical Determinism

milou is designed for **Bitwise Reproducibility**. Using the version tag, users can execute the pipeline with the identical codebase across any compute cluster (`-r 1.2.0`).

Furthermore, the pipeline enforces **Statistical Determinism** by injecting fixed random seeds (`set.seed(42)`) into all R-based modules (edgeR, methylKit, DSS, Enrichment). This guarantees that algorithms relying on stochastic sampling produce identical P-values and results across different compute environments.

### 6.3 Clinical Data Governance & Input Integrity

To meet rigorous IVDR Class C standards, the pipeline implements automated data governance:

1.  **Input Integrity (SHA256)**: The pipeline automatically calculates cryptographic SHA256 checksums for every input FASTQ file. Hashes are recorded in the results and printed in the Clinical Report, providing a verifiable audit trail against transfer corruption.
2.  **Output Sanity Checks**: The reporting layer performs automated Pass/Fail validation, evaluating sample coverage thresholds and mapping quality. Failures are flagged prominently in the final report.
3.  **PHI Segregation**: The pipeline intercepts patient identifiers right at the data ingress layer, dynamically stripping them and assigning secured pseudo-IDs (e.g., `MILOU-SPEC-001`).
4.  **Conversion Efficiency Gating**: For bisulfite and enzymatic sequencing, the pipeline actively probes lambda phage spike-in controls. If non-conversion exceeds 1%, downstream statistical analysis halts and a diagnostic failure is flagged.
5.  **Offline Determinism**: The `clinical_offline` profile locks the pipeline into zero-trust air-gapped execution. All disease ontologies, such as sovereign DisGeNET annotations, run entirely locally without external network calls.
6.  **Full Audit Trail**: The Clinical Report embeds a complete snapshot of all **resolved Nextflow parameters** in JSON format alongside the execution cryptographic `UUID`.

### 6.4 Core Nextflow Arguments & JVM Memory Configuration

???+ info "Core Nextflow Command-Line Arguments"

    These options are passed directly to Nextflow using a _single_ hyphen.

    `-profile`

    Selects execution profiles (`singularity`, `docker`, `conda`, `gpu`, `clinical`, `clinical_offline`). Profiles can be combined with commas, e.g. `-profile singularity,gpu,clinical`.

    `-resume`

    Restarts the pipeline using cached results for any tasks whose inputs and code have not changed.

    `-c`

    Specifies a custom configuration file to override or extend pipeline settings.

    `-name`

    Assigns a custom execution name to the run for easy tracking in Nextflow Tower and local logs.

Nextflow Java virtual machines can request a large amount of memory for high-throughput cohorts. Set the following in your shell configuration (`~/.bashrc` or `~/.zshrc`):

```bash
NXF_OPTS="-Xms4g -Xmx16g"
```

For a full list of flags, see the [Parameters Reference](usage.md#7-complete-parameter-reference).

## 7. Complete Parameter Reference

This section provides a complete reference for all command-line parameters available in **milou**. Default values are appropriately showcased. 

To modify or adjust any parameters, please edit:

1. `conf/params.config`,  
2. `conf/resources.config` for resource allocation, and 
3. `conf/gpu.config` for GPU configuration.
4. `conf/test_local.config` for minimal test data run
5. `conf/test_full.config` for full test data run
6. `conf/benchmark.config` for performance tracking and resource usage benchmarking
7. `conf/replicate_article.config` for replicate article run

DAG rendering options can also be adjusted in `conf/dag.config`.

### 7.1 Input/Output Options

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--sample_sheet` | Path to Samplesheet.csv with following headers: `sample_id, group, read1, read2, assay_type` (optional). | `string` | `null` | Yes |
| `--genome_fasta` | Path to the reference genome FASTA file. | `string` | `null` | Yes |
| `--assay_type` | Global chemistry override for clipping offsets (`'wgbs'`, `'emseq'`, `'twist'`). | `string` | `'wgbs'` | No |
| `--save_reference` | If `true`, the Bismark/BWA-meth index is saved to a persistent storeDir for reuse. | `boolean` | `false` | No |
| `--bismark_index` | Path to a pre-built Bismark index directory. | `string` | `false` | No |
| `--aligned_bams` | Start the pipeline from previously aligned BAM files instead of fastQ. | `boolean` | `false` | No |
| `--outdir` | Output directory where results will be stored. | `string` | `'results'` | Yes |
| `--design_file` | Path to a custom design matrix for specialized comparisons. | `string` | `null` | No |

### 7.2 QC & Alignment Parameters

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--aligner` | Aligner to use: `'bismark'` or `'bwameth'`. | `string` | `'bismark'` | No |
| `--use_parabricks` | Set to `true` to use NVIDIA Parabricks for alignment. | `boolean` | `false` | No |
| `--qualimap_args` | Additional arguments to pass to Qualimap. | `string` | `""` | No |
| `--multiqc_config` | multiqc config file. Default is `null`. `--multiqc_config [path/to/config]` to use multiqc config file. | `string` | `null` | No |
| `--multiqc_title` | multiqc title. Default is `null`. `--multiqc_title [title]` to use multiqc title. | `string` | `null` | No |

### 7.3 Methylation Calling & Extraction Parameters

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--coverage_threshold`| Minimum read coverage for analysis **AND** the threshold for automated Clinical Report Pass/Fail validation. | `integer`| `3` | Yes |

### 7.4 Differential Methylation Analysis Parameters

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--diff_meth_method` | Differential method(s) to use: `'dss'`, `'edger'`, `'methylkit'`, or a comma-separated list. | `string` | `'dss'` | Yes |
| `--compare_str` | The group comparison string limit (e.g., `'Healthy-Tumor'`). | `string` | `'all'` | Yes |
| `--smoothing` | Enable or disable moving-average spline smoothing in DSS. Set to `false` (`--smoothing FALSE`) for whole-genome WGBS cohorts (~28M CpGs) to reduce peak RAM from >250 GB to <50 GB. | `boolean` | `true` | No |
| `--skip_diff_meth` | Skip the differential methylation stage completely. | `boolean` | `false` | No |
| `--methylkit.assembly`| Assembly name for MethylKit context. | `string` | `'hg38'` | Yes |
| `--methylkit.diff` | Minimum methylation difference percentage for Methylkit. | `number` | `0.05` | Yes |
| `--methylkit.qvalue` | Maximum Q-value threshold for Methylkit. | `number` | `1` | Yes |
| `--methylkit.mc_cores` | Number of cores to use for MethylKit. | `integer` | `16` | Yes |
| `--methylkit.bed_file` | Path to the Twist Target region BED file for MethylKit context. | `string` | `null` | No |

### 7.5 Functional Annotation & Enrichment Parameters

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--gtf_file` | Path to a GTF annotation file (e.g., Gencode/Ensembl) for gene mapping. | `string` | `null` | Yes |
| `--refseq_file` | Path to a RefSeq BED file for annotation. | `string` | `null` | Yes |
| `--disgenet_db` | Path to a sovereign, local DisGeNET TSV release for clinical offline mapping. | `string` | `null` | No |
| `--post_processing` | Enable post-processing summaries and visualization. | `boolean`| `true` | Yes |
| `--logfc_cutoff` | Log2 Fold Change threshold for significance. | `number` | `0.5` | Yes |
| `--pvalue_cutoff` | P-value threshold for statistical significance. | `number` | `0.05` | Yes |
| `--top_n_genes` | Number of top genes to include in GO/KEGG enrichment analysis. | `integer`| `100` | Yes |
| `--hyper_color` | Color for hyper-methylated points in graphs. | `string` | `'red'` | Yes |
| `--hypo_color` | Color for hypo-methylated points in graphs. | `string` | `'blue'` | Yes |
| `--nonsig_color` | Color for non-significant points in graphs. | `string` | `'black'` | Yes |

### 7.6 Clinical Reporting Layer Parameters

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--mode` | Pipeline mode: `'research'` (standard) or `'clinical'` (enforces 2-out-of-3 consensus voting). | `string` | `'research'` | No |
| `--offline` | Disables internet access and API queries. Enforced automatically in `clinical_offline` profile. | `boolean` | `false` | No |
| `--run_clinical_report` | Force generation of automated Quarto clinical PDF/HTML report. | `boolean` | `false` | No |
| `--promoter_dist` | Distance from TSS (upstream) to define a Promoter region. | `integer` | `2000` | No |
| `--enhancer_dist` | Distance from TSS to define an Enhancer/Distal region. | `integer` | `10000` | No |

### 7.7 Logging & Resource Management Parameters

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `--max_memory` | Maximum amount of RAM available for any single task. | `string` | `'128.GB'` | No |
| `--max_cpus` | Maximum number of CPUs available for any single task. | `integer`| `16` | No |
| `--max_time` | Maximum walltime for any single task. | `string` | `'240.h'` | No |
| `--dag.file` | Path to the output DAG file. | `string` | `'workflow_dag.dot'` | No |
| `--dag.overwrite` | Overwrite the output DAG file if it already exists. | `boolean` | `false` | No |
| `--dag.renderHTML` | Render the DAG as HTML. | `boolean` | `true` | No |
| `--dag.renderFormat` | Format to render the DAG. | `string` | `'png'` | No |
| `--dag.renderOptions` | Options to pass to the rendering tool. | `string` | `'-Tpng -Gdpi=300'` | No |

### 7.8 Generic Pipeline Options

| Parameter | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `-profile` | Configuration profile: `docker`, `singularity`, `gpu`, `clinical`, `clinical_offline`, `benchmark`. | `string` | *variable* | Yes |
| `-resume` | Re-start the pipeline from where it left off. | `boolean`| `false` | No |
| `-w` | Custom working directory for intermediate files. | `string` | `'work/'` | No |
| `--help` | Display the pipeline help message. | `boolean`| `false` | No |

## 8. Operational Troubleshooting

### 8.1 Memory Scaling in Whole-Genome Sequencing (WGBS)
* **Symptom:** `Process terminated with exit status 137 (Out of Memory)` during `DIFFERENTIAL_METHYLATION:DSS_ANALYSIS`.
* **Root Cause:** By default, `DSS::DMLtest()` computes 2D moving-average spline smoothing across adjacent genomic loci. On whole-genome human sequencing spanning all ~28–30 million CpGs, calculating continuous moving-average splines constructs large distance matrices that cause memory spikes exceeding 250 GB RAM.
* **Resolution:** Pass `--smoothing FALSE` to disable the moving-average spline fitting while preserving empirical Bayes dispersion shrinkage and contiguous DMR detection via `callDMR()`:
  ```bash
  nextflow run main.nf -profile test_bisulfite_gpu,gpu,singularity \
      --smoothing FALSE
  ```
  *Bypassing spline smoothing reduces peak resident memory to ~30–47 GB RAM, allowing WGBS cohorts to run smoothly on standard 64–256 GB nodes.*

### 8.2 Singularity / Apptainer User Namespace Collisions
* **Symptom:** `ERROR: Could not write info to setgroups: Permission denied` or `Error while waiting event for user namespace mappings`.
* **Root Cause:** Newer Apptainer versions (>=1.3+) colliding with host cluster user namespace permission restrictions.
* **Resolution:**
  1. Load the cluster's native Singularity-CE module:
     ```bash
     module unload apptainer
     module load singularity-ce
     ```
  2. Set the global bind path explicitly:
     ```bash
     export SINGULARITY_BINDPATH="/data"
     ```

### 8.3 Resuming Interrupted Workflows
Nextflow tracks all completed tasks via cryptographic input hashes. To resume an interrupted pipeline execution without re-computing upstream steps:
```bash
nextflow run JD2112/milou -profile singularity,gpu -resume
```
