---
hide:
  - navigation
---

# milou Pipeline Parameters

This page provides a complete reference for all command-line parameters available in **milou**. Default values are appropriately showcased. 

To modify or adjust any parameters, please edit the

1. `conf/params.config`,  
2. `conf/resources.config` for resource allocation, and 
3. `conf/gpu.config` for GPU configuration.
4. `conf/test_local.config` for minimal test data run
5. `conf/test_full.config` for full test data run
6. `conf/benchmark.config` for performance tracking and resource usage benchmarking
7. `conf/replicate_article.config` for replicate article run


User can also adjust the DAG rendering options in `conf/dag.config` file.

## Input/Output Options

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--sample_sheet` | Path to Samplesheet.csv with following headers: `sample_id, group, read1, read2, assay_type` (optional). | `string` | `null` | ✔️ | ❌ |
| `--genome_fasta` | Path to the reference genome FASTA file. | `string` | `null` | ✔️ | ❌ |
| `--assay_type` | Global chemistry override for clipping offsets (`'wgbs'`, `'emseq'`, `'twist'`). | `string` | `'wgbs'` | ❌ | ❌ |
| `--save_reference` | If `true`, the Bismark/BWA-meth index is saved to a persistent storeDir for reuse. | `boolean` | `false` | ❌ | ❌ |
| `--bismark_index` | Path to a pre-built Bismark index directory. | `string` | `false` | ❌ | ❌ |
| `--aligned_bams` | Start the pipeline from previously aligned BAM files instead of fastQ. | `boolean` | `false` | ❌ | ❌ |
| `--outdir` | Output directory where results will be stored. | `string` | `'results'` | ✔️ | ❌ |
| `--design_file` | Path to a custom design matrix for specialized comparisons. | `string` | `null` | ❌ | ✔️ |

## QC & Alignment Parameters

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--aligner` | Aligner to use: `'bismark'` or `'bwameth'`. | `string` | `'bismark'` | ❌ | ❌ |
| `--use_parabricks` | Set to `true` to use NVIDIA Parabricks for alignment. | `boolean` | `false` | ❌ | ❌ |
| `--qualimap_args` | Additional arguments to pass to Qualimap. | `string` | `""` | ❌ | ✔️ |
| `--multiqc_config` | multiqc config file. Default is `null`. `--multiqc_config [path/to/config]` to use multiqc config file. | `string` | `null` | ❌ | ✔️ |
| `--multiqc_title` | multiqc title. Default is `null`. `--multiqc_title [title]` to use multiqc title. | `string` | `null` | ❌ | ✔️ |

## Methylation Calling & Extraction

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--coverage_threshold`| Minimum read coverage for analysis **AND** the threshold for automated Clinical Report Pass/Fail validation. | `integer`| `3` | ✔️ | ❌ |

## Differential Methylation Analysis 

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--diff_meth_method` | Differential method(s) to use: `'dss'`, `'edger'`, `'methylkit'`, or a comma-separated list. | `string` | `'dss'` | ✔️ | ❌ |
| `--compare_str` | The group comparison string limit (e.g., `'Healthy-Tumor'`). | `string` | `'all'` | ✔️ | ❌ |
| `--smoothing` | Enable or disable moving-average spline smoothing in DSS. Set to `false` (`--smoothing FALSE`) for whole-genome WGBS cohorts (~28M CpGs) to reduce peak RAM from >250 GB to <50 GB. | `boolean` | `true` | ❌ | ❌ |
| `--skip_diff_meth` | Skip the differential methylation stage completely. | `boolean` | `false` | ❌ | ❌ |
| `--methylkit.assembly`| Assembly name for MethylKit context. | `string` | `'hg38'` | ✔️ | ❌ |
| `--methylkit.diff` | Minimum methylation difference percentage for Methylkit. | `number` | `0.05` | ✔️ | ❌ |
| `--methylkit.qvalue` | Maximum Q-value threshold for Methylkit. | `number` | `1` | ✔️ | ❌ |
| `--methylkit.mc_cores` | Number of cores to use for MethylKit. | `integer` | `16` | ✔️ | ❌ |
| `--methylkit.bed_file` | Path to the Twist Target region BED file for MethylKit context. | `string` | `null` | ❌ | ❌ |

## Functional Annotation & Enrichment

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--gtf_file` | Path to a GTF annotation file (e.g., Gencode/Ensembl) for gene mapping. | `string` | `null` | ✔️ | ❌ |
| `--refseq_file` | Path to a RefSeq BED file for annotation. | `string` | `null` | ✔️ | ❌ |
| `--disgenet_db` | Path to a sovereign, local DisGeNET TSV release for clinical offline mapping. | `string` | `null` | ❌ | ❌ |
| `--post_processing` | Enable post-processing summaries and visualization. | `boolean`| `true` | ✔️ | ❌ |
| `--logfc_cutoff` | Log2 Fold Change threshold for significance. | `number` | `0.5` | ✔️ | ❌ |
| `--pvalue_cutoff` | P-value threshold for statistical significance. | `number` | `0.05` | ✔️ | ❌ |
| `--top_n_genes` | Number of top genes to include in GO/KEGG enrichment analysis. | `integer`| `100` | ✔️ | ❌ |
| `--hyper_color` | Color for hyper-methylated points in graphs. | `string` | `'red'` | ✔️ | ❌ |
| `--hypo_color` | Color for hypo-methylated points in graphs. | `string` | `'blue'` | ✔️ | ❌ |
| `--nonsig_color` | Color for non-significant points in graphs. | `string` | `'black'` | ✔️ | ❌ |

## Clinical Reporting Layer

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--mode` | Pipeline mode: `'research'` (standard) or `'clinical'` (enforces 2-out-of-3 consensus voting). | `string` | `'research'` | ❌ | ❌ |
| `--offline` | Disables internet access and API queries. Enforced automatically in `clinical_offline` profile. | `boolean` | `false` | ❌ | ❌ |
| `--run_clinical_report` | Force generation of automated Quarto clinical PDF/HTML report. | `boolean` | `false` | ❌ | ❌ |
| `--promoter_dist` | Distance from TSS (upstream) to define a Promoter region. | `integer` | `2000` | ❌ | ❌ |
| `--enhancer_dist` | Distance from TSS to define an Enhancer/Distal region. | `integer` | `10000` | ❌ | ❌ |

## Logging & Resource Management 

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `--max_memory` | Maximum amount of RAM available for any single task. | `string` | `'128.GB'` | ❌ | ✔️ |
| `--max_cpus` | Maximum number of CPUs available for any single task. | `integer`| `16` | ❌ | ✔️ |
| `--max_time` | Maximum walltime for any single task. | `string` | `'240.h'` | ❌ | ✔️ |
| `--dag.file` | Path to the output DAG file. | `string` | `'workflow_dag.dot'` | ❌ | ✔️ |
| `--dag.overwrite` | Overwrite the output DAG file if it already exists. | `boolean` | `false` | ❌ | ✔️ |
| `--dag.renderHTML` | Render the DAG as HTML. | `boolean` | `true` | ❌ | ✔️ |
| `--dag.renderFormat` | Format to render the DAG. | `string` | `'png'` | ❌ | ✔️ |
| `--dag.renderOptions` | Options to pass to the rendering tool. | `string` | `'-Tpng -Gdpi=300'` | ❌ | ✔️ |
---

## Generic Pipeline Options

| Parameter | Description | Type | Default | Required | Hidden? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `-profile` | Configuration profile: `docker`, `singularity`, `gpu`, `clinical`, `clinical_offline`, `benchmark`. | `string` | *variable* | ✔️ | ❌ |
| `-resume` | Re-start the pipeline from where it left off. | `boolean`| `false` | ❌ | ❌ |
| `-w` | Custom working directory for intermediate files. | `string` | `'work/'` | ❌ | ✔️ |
| `--help` | Display the pipeline help message. | `boolean`| `false` | ❌ | ✔️ |
