# milou Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-09-04

### Added
- **Multi-Method Differential Methylation Consensus Framework ($\pi$-Value)**: Integrated statistical ranking combining effect size ($\overline{|\log_2(\text{FC})_g|}$) with minimum significance ($-\log_{10}(P_{\min,g})$) across DSS, edgeR, and methylKit, bypassing individual caller biases.
- **Interactive Quarto Reporting Engine**: Dual-format generation producing responsive HTML summaries (with `DT::datatable` search, CSV/Excel downloads, and Gviz locus zoom tracks) alongside publication-ready vector PDFs.
- **Picard Hybrid-Selection Target Metrics**: Integrated `picard.nf` for target-capture assays (e.g. Twist Human Methylome) computing fold-enrichment, target coverage, and on-target percentage.
- **FastQC N-Base Quality Module**: Added `check_fastqc_n.nf` providing intelligent parsing of overrepresented N-count flags without causing premature pipeline aborts.
- **Comprehensive Documentation Suite**: Rebuilt MkDocs Material documentation with MathJax 3 LaTeX formula typesetting, responsive collapsible right-hand TOC navigation, and hierarchical decimal section numbering.
- **Standardized Benchmarking Profiles**: 10 reproducible execution profiles across whole-genome EM-seq, WGBS, and targeted hybrid capture with matching CPU and GPU configurations.

### Changed
- **Pipeline Rebranding to 'milou'**: Completed end-to-end name refactoring from `MethylFlow` to `milou` in compliance with project realignment.
- **Branding Assets Upgrade**: Replaced the pipeline's logo with the newly integrated AI-designed round "m" logo `milou_logo.png` across PDF clinical reports, HTML outputs, and GitBook documentation.
- **Reporting Nomenclature Harmonization & Zenodo Reproducibility Transparency**:
  - User-facing reporting strings in `assets/report.qmd` have been updated from legacy diagnostic/clinical phrasing to translational research standards:
    - Running header: `"Clinical Specimen Status"` $\rightarrow$ `"Specimen Status"`.
    - Running footer: `"TwistNext Clinical Report | Pipeline v1.1.0"` $\rightarrow$ `"milou Analysis Report | Pipeline v1.2.0 | UUID: <workflow.sessionId>"`.
    - Callout boxes: `\newtcolorbox{clinicalnote}` (`"Clinical Interpretation Note"`) $\rightarrow$ `\newtcolorbox{reportnote}` (`"Interpretation Note"`).
    - Closing disclaimer: `"Report generated automatically for clinical decision support. Analytical values should be correlated with primary laboratory findings..."` $\rightarrow$ `"Report generated automatically for research purposes only. Analytical values should be validated with primary experimental findings and the MultiQC quality report."`.
    - Branding graphic: `methylflow_logo.png` $\rightarrow$ `milou_logo.png`.
  - **Zenodo Archive Comparison Note**:
    - Benchmark PDF and HTML reports archived under Zenodo ([DOI: 10.5281/zenodo.22326688](https://doi.org/10.5281/zenodo.22326688), directory `03_clinical_quarto_reports/`) were generated during the initial benchmarking phase and intentionally preserve earlier legacy headers/wording for historical audit integrity.
    - Fresh executions of `milou` v1.2.0 will display the new research-use titles and disclaimer text.
    - **Analytical Invariance**: All numerical results, statistical testing (DSS, edgeR, methylKit), consensus $\pi$-value rankings, DMR genomic coordinates, and coverage depths remain 100% computationally identical between the archived Zenodo artifacts and newly generated reports.
- **Report Redirections**: Configured backward-compatible redirections for `-profile test_bisulfite` and `-profile test_emseq` to target their CPU tracks automatically.

### Fixed
- **GPU Read Length Allocation**: Raised the Clara Parabricks read allocation threshold (`--max-read-length`) in `conf/gpu.config` from 100 to 250 to prevent desynchronization crashes when running 150bp WGBS and EM-seq datasets on GPU tracks.
- **Zombie Auditor Threshold Tuning**: Raised the uncalled base (`N`) validation threshold in `validate_sync.nf` from 500 to 50,000 to prevent false-positive "zombie" exclusions of healthy, high-quality public SRA/EBI datasets.
- **Cloud Protocol Path Resolution**: Resolved a critical routing bug in `main.nf` that prepended the project directory path to S3 (`s3://`) and other cloud protocol fastq paths, enabling seamless streaming and validation of cloud-hosted test data.
- **Sample Sheet Typo Interception**: Corrected `sample_sheet` paths in test configs from non-existent `examples/` to `./data/` directories to prevent local launch failures.
- **Quarto Logo Resolution**: Resolved LaTeX header compile failures by migrating graphics inclusions from `methylflow_logo.png` to the new `milou_logo.png`.

## [1.1.0] - 2026-05-16

### Added
- **Sovereign Offline Mode (`clinical_offline`)**: Added a strict offline profile in `nextflow.config` that disables Docker/Singularity network egress (`network = 'none'`), ensuring the pipeline can run in a completely air-gapped clinical environment without reaching out to external APIs.
- **Sovereign DisGeNET Mapping**: Integrated a localized DisGeNET parsing module in `bin/disease_enrichment.R` mapped via `params.disgenet_db`. Replaces DOSE API calls for strict offline reproducibility and IVDR compliance.
- **Automated Conversion QC Guardrails**: Added `modules/conversion_qc.nf` to intercept `bismark` or `MethylDackel` outputs and compute Lambda-phage spike-in conversion efficiency. Samples with >1% non-conversion are automatically flagged as a wet-lab diagnostic failure.
- **Targeted Capture Metrics (Twist Panels)**: Embedded `PICARD_COLLECTHSMETRICS` into the pipeline for dynamic target bed parsing and coverage evaluation. Specifically triggers when `params.assay_type == 'twist'` to provide specialized clinical sequencing depth QC.
- **Algorithmic Consensus Voting**: Enforced a strict 2-out-of-3 mode consensus algorithm inside `bin/build_unified_results.py`. When run with `--mode clinical`, only DMRs statistically validated by at least two independent algorithms (e.g., edgeR and DSS) are permitted into the final diagnostic report.
- **Batch Effect Auditing (PERMANOVA)**: Integrated `vegan::adonis2` statistical testing into `bin/generate_pca_plots.R`. PCA plots now embed a verified $p$-value and $R^2$ score confirming that clinical groups (and not batch flowcells) are the primary drivers of mathematical variance.
- **Cryptographic Traceability**: Dynamically injects Nextflow's internal execution UUID (`workflow.sessionId`) into the headers and footers of all PDF and HTML outputs for clinical audit trails.
- **Secure PHI Data Segregation**: Built a thread-safe `.secure_phi_index.tsv` interceptor in `validate_sync.nf` and `main.nf` that actively scans and strips Swedish Personnummer inputs, replacing them with safe pseudo-IDs (`MILOU-SPEC-XXX`) across the temporary `work/` directories.

### Changed
- **Quarto HTML vs PDF Parity**: Rewrote `assets/report.qmd` logic to ensure strict clinical reporting equivalence across both formats. 
- **Interactive Web Reporting**: Replaced static HTML tables with `DT::datatable`. All outputs now feature native front-end buttons for instant 1-click CSV and Excel extraction.
- **Dynamic Assay Routing**: Updated `trim_galore.nf` to dynamically apply chemistry-specific clip offsets (`--clip_R1 10 --clip_R2 10`) when processing `twist` or `emseq` kits to clear artificial end-repair unmethylated cytosines.

### Fixed
- **Zombie Sample Pre-filtering**: Added a robust FASTQ read synchronicity auditor in `modules/validate_sync.nf` to catch truncated or corrupted files (zombies) and dynamically skip them to avoid pipeline lockups.
- **HPC Process Label Alignment**: Hardened Process scheduler process labels (`process_low`, `process_high`, `gpu`) to match slurm limits and target exact hardware partitions on Dardel and Fraka clusters.
- **MultiQC Version Tracking**: Fixed overlapping multiqc output channels in `qc_reporting.nf` to accurately compile software versions in the final report appendix.
- **Singularity Cache Pre-staging**: Upgraded `pre_stage.nf` fetching routines to cache remote references in absolute cluster paths safely.

### Security
- **Hardened Report Container**: Patched base images and removed critical CVEs in `Dockerfile_report` using dynamic vulnerability scanning to satisfy strict clinical information security protocols.

## [1.0.0] - Initial Release
- Core Nextflow DSL-2 implementation with Bismark, bwa-meth, edgeR, DSS, and methylKit modules.
- Quarto-based markdown PDF reporting engine.
- Parallel processing support for WGBS samples.
