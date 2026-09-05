# Project Philosophy & Design Goals

## 1. Naming & Scope

**milou** is a high-performance, platform-agnostic Nextflow pipeline designed for end-to-end DNA methylation profiling. The name "milou" reflects its modular, stream-oriented architecture—a "flow" of data that remains consistent across diverse sequencing projects. While the current version is optimized for high-throughput short-read data (such as Illumina), the pipeline’s infrastructure is strategically engineered to be technology-agnostic, providing a stable framework that can scale with evolving methylation-capture technologies.

## 2. Technological Versatility (EM-seq & Bismark)

A core strength of milou is its seamless support for diverse conversion chemistries, including both **Enzymatic Methyl-seq (EM-seq)** and traditional **Bisulfite sequencing**. Although the pipeline utilizes gold-standard, bisulfite-aware tools like **Bismark**, the underlying logic remains perfectly suited for EM-seq analysis. Because both methods rely on the chemical or enzymatic conversion of unmethylated cytosines to uracil (read as thymine), milou leverages these mature, highly-validated aligners to ensure maximum mapping accuracy and full reproducibility across legacy and modern datasets.

## 3. The Unified Results Framework (Consensus)

Beyond read-mapping and methylation calling, milou introduces a **Unified Results Framework** that bridges the gap between raw data and biological interpretation. This architecture supports multiple statistical frameworks, including `DSS`, `edgeR`, and `methylKit`. Users have the flexibility to run a single method for rapid profiling or execute a **multi-method consensus workflow** that automatically aggregates findings into a standardized schema. This cross-method validation empowers researchers to prioritize high-confidence epigenetic markers while ensuring a consistent, diagnostic-ready reporting format regardless of the chosen analytical depth.

## 4. Closing the Translational Gap

While existing community pipelines (such as `nf-core/methylseq`) excel at the initial stages of read alignment and quality control, they often leave a significant gap between raw methylation calls and actionable biological insight. milou is specifically designed to close this "translational gap" by integrating downstream analysis—such as **Disease Mapping (DisGeNET)**, **Regional Annotation (Promoter/Enhancer)**, and **Pathway Enrichment**—into a single, automated execution. The result is not just a collection of data tables, but a comprehensive, clinical-ready synthesis of the epigenetic landscape.

## 5. Mathematical Foundation: The Unified Score (π-value)

To prioritize biologically meaningful findings, milou implements a **Unified Significance Score** (also known as a π-value) to rank differentially methylated regions and genes. This score balances statistical significance with the magnitude of the epigenetic change (effect size).

**Mathematical Definition:**
The Unified Score ($\pi$) for each gene or region is calculated as:
$$\pi = | \overline{\log_2(FC)} | \times (-\log_{10}(P_{min}))$$

Where:

- $| \overline{\log_2(FC)} |$: The absolute mean log2 Fold Change across all detecting methods.
- $P_{min}$: The minimum (most significant) P-value (or FDR) observed across methods.

**Rationale & Validation:**
Ranking by $P$-value alone often highlights regions with tiny, biologically irrelevant changes that happen to have very low variance. Conversely, ranking by Fold Change alone ignores statistical noise. By utilizing the π-value framework, milou ensures that top-ranked features are both statistically robust and biologically significant.

_Reference: Xiao, Y., et al. (2014). "π-value: a biological significant value for differential expression analysis of transcriptome data." Bioinformatics, 30(11), 1606–1611._
