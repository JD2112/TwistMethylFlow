---
hide:
  - navigation
---

# milou Technical References, Governance & Developer Manual

This document consolidates pipeline citations, security governance, operational FAQs, and architectural guidelines for **milou**.

## 1. Academic Attribution & Software Citations

### 1.1 Primary Pipeline Citation & Repository Archive

If you use **milou** in your research, please cite the primary publication and Zenodo repository:

> **Das, J., et al. (2026).** *milou: An End-to-End Nextflow Pipeline for Translational DNA Methylation Profiling with Multi-Method Consensus Scoring*.   
> **Software Pipeline Archive:** [https://doi.org/10.5281/zenodo.14204260](https://doi.org/10.5281/zenodo.14204260)  
> **Benchmark Data Archive:** [https://doi.org/10.5281/zenodo.22326688](https://doi.org/10.5281/zenodo.22326688)

### 1.2 Upstream Quality Control & Alignment Engines

#### 1.2.1 FastQC
> Andrews, S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data [Online]. [https://www.bioinformatics.babraham.ac.uk/projects/fastqc/](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)

#### 1.2.2 Trim Galore!
> Krueger, F., James, F., Ewels, P., et al. (2023). FelixKrueger/TrimGalore: v0.6.10. Zenodo. [https://doi.org/10.5281/zenodo.7598955](https://doi.org/10.5281/zenodo.7598955)

#### 1.2.3 Bismark
> Krueger, F., & Andrews, S. R. (2011). Bismark: a flexible aligner and methylation caller for Bisulfite-Seq applications. *Bioinformatics*, 27(11), 1571-1572. [https://doi.org/10.1093/bioinformatics/btr167](https://doi.org/10.1093/bioinformatics/btr167)

#### 1.2.4 Samtools
> Danecek, P., Bonfield, J. K., Liddle, J., et al. (2021). Twelve years of SAMtools and BCFtools. *GigaScience*, 10(2), giab008. [https://doi.org/10.1093/gigascience/giab008](https://doi.org/10.1093/gigascience/giab008)

#### 1.2.5 QualiMap
> Okonechnikov, K., Conesa, A., & García-Alcalde, F. (2016). Qualimap 2: advanced multi-sample quality control for high-throughput sequencing data. *Bioinformatics*, 32(2), 292–294. [https://doi.org/10.1093/bioinformatics/btv566](https://doi.org/10.1093/bioinformatics/btv566)

#### 1.2.6 MultiQC
> Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. *Bioinformatics*, 32(19), 3047-3048. [https://doi.org/10.1093/bioinformatics/btw354](https://doi.org/10.1093/bioinformatics/btw354)

### 1.3 Statistical Differential & Functional Interpretation Engines

#### 1.3.1 edgeR
> Chen, Y., Chen, L., Lun, A. T. L., Baldoni, P., & Smyth, G. K. (2025). edgeR v4: powerful differential analysis of sequencing data with expanded functionality and improved support for small counts and larger datasets. *Nucleic Acids Research*, 53(2), gkaf018. [https://doi.org/10.1093/nar/gkaf018](https://doi.org/10.1093/nar/gkaf018)

#### 1.3.2 methylKit
> Akalin, A., Kormaksson, M., Li, S., et al. (2012). methylKit: a comprehensive R package for the analysis of genome-wide DNA methylation profiles. *Genome Biology*, 13(10), R87. [https://doi.org/10.1186/gb-2012-13-10-r87](https://doi.org/10.1186/gb-2012-13-10-r87)

#### 1.3.3 DSS (Dispersion Shrinkage for Sequencing)
> Feng, H., Conneely, K. N., & Wu, H. (2014). A Bayesian hierarchical model to detect differentially methylated loci from single nucleotide resolution sequencing data. *Nucleic Acids Research*, 42(8), e69. [https://doi.org/10.1093/nar/gku154](https://doi.org/10.1093/nar/gku154)

#### 1.3.4 clusterProfiler & GOplot
> Xu, S., Hu, E., Cai, Y., et al. (2024). Using clusterProfiler to characterize multiomics data. *Nature Protocols*, 19(11), 3292-3320. [https://doi.org/10.1038/s41596-024-01020-z](https://doi.org/10.1038/s41596-024-01020-z)  
> Walter, W., Sánchez-Cabo, F., & Ricote, M. (2015). GOplot: an R package for visually combining expression data with functional analysis. *Bioinformatics*, 31(17), 2912-2914.

#### 1.3.5 ggplot2
> Wickham, H. (2016). *ggplot2: Elegant Graphics for Data Analysis*. Springer-Verlag New York. ISBN 978-3-319-24277-4. [https://ggplot2.tidyverse.org](https://ggplot2.tidyverse.org)

### 1.4 Packaging & Container Infrastructure

#### 1.4.1 Nextflow
> Di Tommaso, P., Chatzou, M., Floden, E. W., et al. (2017). Nextflow enables reproducible computational workflows. *Nature Biotechnology*, 35(4), 316-319. [https://doi.org/10.1038/nbt.3820](https://doi.org/10.1038/nbt.3820)

#### 1.4.2 Docker & BioContainers
> Merkel, D. (2014). Docker: lightweight linux containers for consistent development and deployment. *Linux Journal*, 2014(239), 2.  
> da Veiga Leprevost, F., Grüning, B., Aflitos, S. A., et al. (2017). BioContainers: an open-source and community-driven framework for software standardization. *Bioinformatics*, 33(16), 2580-2582.

#### 1.4.3 Singularity / Apptainer
> Kurtzer, G. M., Sochat, V., & Bauer, M. W. (2017). Singularity: Scientific containers for mobility of compute. *PLoS ONE*, 12(5), e0177459. [https://doi.org/10.1371/journal.pone.0177459](https://doi.org/10.1371/journal.pone.0177459)

#### 1.4.4 Bioconda & Anaconda
> Grüning, B., Dale, R., Sjödin, A., et al. (2018). Bioconda: sustainable and comprehensive software distribution for the life sciences. *Nature Methods*, 15(7), 475-476. [https://doi.org/10.1038/s41592-018-0046-7](https://doi.org/10.1038/s41592-018-0046-7)

#### 1.4.5 R & Bioconductor
> Huber, W., Carey, V. J., Gentleman, R., et al. (2015). Orchestrating high-throughput genomic analysis with Bioconductor. *Nature Methods*, 12(2), 115–121. [https://doi.org/10.1038/nmeth.3252](https://doi.org/10.1038/nmeth.3252)

## 2. Container Security & Governance (Quindecagon)

### 2.1 Zero-Trust Container Auditing & Verification

milou satisfies regulated and institutional zero-trust security standards. All container images utilized in the pipeline are continuously scanned and validated via [**quindecagon**](https://github.com/JD2112/quindecagon):

* **Static Security Auditing**: Code and DSL2 modules are vetted using Semgrep and SonarQube for static analysis.
* **Vulnerability Scanning**: Every container undergoes automated CVE and OCI vulnerability scanning with **Trivy** and **Grype**, with all critical/high OS-level vulnerabilities patched.
* **Software Bill of Materials (SBOM)**: Cryptographic SBOMs are generated for each image via **Syft** and archived for complete software supply chain transparency.
* **Cryptographic Signing**: Container digests are pinned by SHA256 hashes and signed using **Sigstore / Cosign**.
* **Non-Root Execution**: Container environments operate under unprivileged user contexts (`appuser`) to ensure safe execution on shared HPC environments.

## 3. Frequently Asked Questions (FAQs)

### 3.1 Common Methodological & Operational Questions

??? question "How does the GPU alignment track compare to the CPU track?"
    milou implements a dual execution engine:
    
    * **GPU Track**: NVIDIA Parabricks (`fq2bam_meth`) accelerates BWA-meth alignment and PCR deduplication by **18× to 24×** per sample, while MethylDackel extracts CpG calls in minutes.
    * **Concordance**: Evaluated across gold-standard human benchmarks, the GPU track achieves **99.5% coordinate agreement** and a Spearman rank correlation of **$r_s = 0.97 - 0.99$** against CPU Bismark calls. Downstream differential testing (DSS, edgeR, methylKit) runs identically in both tracks.

??? question "How do I prevent memory spikes when running Whole-Genome (WGBS) DSS analysis?"
    Human WGBS cohorts span all ~28–30 million CpG sites. By default, DSS calculates 2D moving-average spline smoothing across adjacent genomic loci, which can cause memory to spike beyond 250 GB RAM. Setting `--smoothing FALSE` bypasses moving-average spline fitting while preserving empirical Bayes dispersion shrinkage and contiguous DMR detection via `callDMR()`, keeping peak resident memory under **50 GB RAM**.

??? question "What is the multi-method consensus score (π-value)?"
    To provide a deterministic clinical ranking, milou merges results from DSS, edgeR, and methylKit into a unified significance score adapted from the $\pi$-value framework:
    $$\pi_{g} = \overline{\left| \log_{2}{(FC)}_{g} \right|} \times \left( - \log_{10}(P_{\min,g}) \right)$$
    Where $\overline{\left| \log_{2}{(FC)}_{g} \right|}$ is the mean log2 fold change across all callers that identified gene *g* as differentially methylated, and $P_{\min,g}$ is the minimum observed *p*-value. This elevates genes that possess both robust statistical significance and large biological effect sizes.

??? question "Can milou automatically download benchmark datasets?"
    **Yes.** When running built-in test profiles or passing `--pre_stage_test_data true`, milou automatically downloads and checksum-verifies raw sequencing runs from public SRA/ENA archives. You can also place direct HTTP, FTP, or S3 URLs directly inside the `read1` and `read2` columns of your own `samplesheet.csv`.

??? question "What makes milou clinical-grade?"
    milou enforces strict data governance:
    
    1. **Input Integrity**: Automated cryptographic SHA256 checksumming of every input FASTQ.
    2. **PHI De-identification**: Automated masking and pseudo-ID assignment (`MILOU-SPEC-001`) preventing patient identifiers in results.
    3. **Conversion Efficiency Gating**: Active monitoring of unmethylated spike-in controls (lambda phage) with automatic diagnostic failure flags if non-conversion exceeds 1%.
    4. **Air-gapped Execution**: Sovereign local disease databases (`--disgenet_db`) allow fully offline clinical operation via `--profile clinical_offline`.

## 4. License & Institutional Acknowledgements

### 4.1 Open-Source MIT License

milou is distributed under the open-source **MIT License**:

```
MIT License
Copyright (c) 2026 Jyotirmoy Das

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

### 4.2 Research Institutions & HPC Facilities

* **Core Facility, Faculty of Medicine and Health Sciences, Linköping University**  
  [Linköping University Core Facility](https://liu.se/en/organisation/liu/medfak/coref)
* **Clinical Genomics Linköping, Science for Life Laboratory, Sweden**  
  [Clinical Genomics Linköping](https://www.scilifelab.se/units/clinical-genomics-linkoping/)
* **National Academic Infrastructure for Supercomputing in Sweden (NAISS)**  
  > The computations and storage were enabled by resources provided by NAISS, partially funded by the Swedish Research Council through grant agreement no. 2022-06725.

### 4.3 Community Acknowledgements

Special thanks to the developers and contributors of Nextflow, Bismark, methylKit, edgeR, and the broader open-source bioinformatics community.

## 5. Developer Guide & Technical History

This section serves as a technical architecture reference and maintenance manual for the **milou** pipeline.

### 5.1 Maintenance & Release Workflow

To maintain clinical reproducibility, follow this exact sequence when updating tools or dependencies:

#### 5.1.1 Step A: Update the Conda Environment
1. Modify the source `.yml` files in `containers/conda/` (e.g., `environment_main.yml`).
2. **Always pin the version** (e.g., `samtools=1.19` instead of just `samtools`).
3. If adding an R package, decide whether it belongs in the Conda env or the `rocker`-based Dockerfiles.

#### 5.1.2 Step B: Sync and Build Container Images
1. **Sync**: Copy the updated `.yml` to `containers/docker/` to keep build contexts current:
   ```bash
   cp containers/conda/environment_main.yml containers/docker/
   ```
2. **Build**: Build the new image with an incremented version tag:
   ```bash
   cd containers/docker
   docker build -f Dockerfile_main -t jd2112/milou:1.2.0 .
   ```
3. **Verify**: Run `docker inspect <ID>` to verify the health check passes.

#### 5.1.3 Step C: Update Pipeline Configurations
1. Open `conf/containers.config`.
2. Update the version tag for the relevant process or the global `container` variable.
3. Update `nextflow_schema.json` and `conf/params.config` if new parameters were introduced.

#### 5.1.4 Centralized Release Automation (`scripts/publish.py`)

When ready to release a new version, run the automated release utility from the project root:

```bash
python3 scripts/publish.py
```

The script manages:
1. **Version Bumping**: Calculates Patch, Minor, or Major increments following Semantic Versioning (SemVer).
2. **Global Sync**: Scans and updates version tags across manifests, container definitions, Quarto report templates, and documentation.
3. **Git Release**: Stages changes, commits, and creates an annotated Git tag matching the release version.

### 5.2 Technical Architecture & Change Log

#### 5.2.1 Scientific Innovations
* **Multi-Resolution Analysis**: Integrated `callDMR` into the DSS module to detect both DMCs (Sites) and DMRs (Regions) simultaneously.
* **The π-Value Consensus Score**: Implemented cross-method consensus merging results from DSS, edgeR, and methylKit using: $\pi = \overline{|\log_2(FC)|} \times (-\log_{10}(P_{\min}))$.
* **Gene-Centric Bridging**: Maps regional DMR coordinates to the nearest TSS, aggregating locus- and region-level metrics at the gene level for clinical interpretation.

#### 5.2.2 Clinical Hardening & Security Compliance
* **Clinical Gating**: The `min_30x_pc` parameter formally evaluates cohorts against the clinical gold-standard (default: 80% targets at >30x coverage).
* **Integrity Audit**: Cryptographic SHA256 hashes generated across input FASTQs and output tables.
* **Security Hardening**: Non-root container execution (`appuser`), pinned base images, and continuous CVE scanning via quindecagon.

#### 5.2.3 Publication Pillars (The Core Narrative)
* **Pillar 1: The Translational Gap**: Standard pipelines stop at bedGraph/BAM files. *milou* bridges the gap by delivering automated gene-disease enrichment (DisGeNET) and a multi-caller consensus score in an executive Quarto report.
* **Pillar 2: Mathematical Rigor**: Highlights the π-value consensus framework, establishing reproducible biological truth where orthogonal statistical distributions agree.
* **Pillar 3: Clinical Readiness**: Built for regulated environments with coverage gating, checksumming, and security-hardened containers.

---

*Last Updated: September 04, 2026*