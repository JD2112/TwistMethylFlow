---
hide:
  - navigation
---

# milou Troubleshooting & Maintenance Guide

This document tracks known runtime issues and their resolutions to ensure pipeline stability across different environments.

## 1. Reporting & LaTeX Issues

### Error: `Package pgfkeys Error: I do not know the key '/tcb/interior hidden'`
- **Cause**: The `tcolorbox` LaTeX package requires the `skins` library to be explicitly loaded to support advanced Quarto styling keys.
- **Fix**: In the `.qmd` header (e.g., `assets/report.qmd`), ensure `tcolorbox` is loaded with the skins and breakable options:
  ```latex
  \usepackage[skins,breakable]{tcolorbox}
  ```
- **Additional Mitigation**: In `modules/report.nf`, use a lightweight highlight style in the YAML metadata to reduce LaTeX complexity:
  ```yaml
  highlight-style: github
  ```

### Missing R Packages in `REPORT` Process
- **Symptom**: `Error in library(tidyverse): there is no package called 'tidyverse'`
- **Fix**: Ensure `tidyverse` is included in the `Dockerfile_report`. 
- **Temporary Workaround**: Pin the `REPORT` process to a known stable image in `conf/containers.config`.

## 2. Channel & Data Flow Issues

### Error: `Not a valid path value type: java.util.LinkedHashMap`
- **Cause**: Nextflow DSL2 often passes metadata maps alongside file paths (e.g., `[meta, file]`). If a process input expects a strict `path`, the presence of the `LinkedHashMap` (meta) will cause a crash.
- **Fix**: Map the channel to extract the file object before passing it to the module:
  ```nextflow
  CHANNEL.map { it[1] }.collect()
  ```

### Process Input File Name Collision
- **Symptom**: `Process UNIFIED_LAYER input file name collision -- epigenetic_metrics.json`
- **Cause**: Multiple statistical methods (EdgeR, MethylKit, DSS) producing files with the same name which are then collected into a single process work directory.
- **Fix**: Prefix output files with the method name in the module definition:
  ```nextflow
  mv epigenetic_metrics.json ${method}_epigenetic_metrics.json
  ```

## 3. Multi-Platform Build Strategy

To build images that work on both Intel/AMD (Server) and Apple Silicon (Mac), use the provided `build_report.sh` script.

**Prerequisites**:
- Docker Desktop with `buildx` enabled.
- `cosign` installed for image signing.

**Commands**:
```bash
# Build, Push, and Sign for both architectures
./build_report.sh
```
The script handles manifest creation and digest signing automatically.

## 4. Memory Scaling in Whole-Genome Sequencing (WGBS)

### DSS Moving-Average Spline Smoothing on ~28M CpGs
- **Symptom**: `Process terminated with an exit status of 137 (Out of Memory)` or memory usage spiking >250 GB during `DIFFERENTIAL_METHYLATION:DSS_ANALYSIS`.
- **Cause**: In human WGBS cohorts, all ~28–30 million CpG sites are evaluated simultaneously. By default, `DSS::DMLtest()` computes 2D moving-average spline smoothing across adjacent genomic loci. While beneficial for targeted capture panels, smoothing across tens of millions of whole-genome loci requires creating large genomic distance matrices that cause massive resident memory spikes (>250 GB RAM).
- **Resolution**:
  Set the smoothing argument to `FALSE`. This can be passed on the command line:
  ```bash
  nextflow run main.nf -profile test_bisulfite_gpu,gpu,singularity \
      -c <(echo "process { withName: '.*DSS_ANALYSIS.*' { ext.args = '--smoothing FALSE'; memory = '64 GB'; cpus = 2 } }")
  ```
- **Impact**: Bypassing moving-average spline smoothing reduces peak RSS to **~30–47 GB**, allowing full whole-genome cohort analyses to complete reliably without OOM errors, while preserving empirical Bayes dispersion shrinkage and contiguous DMR detection via `callDMR()`.

### Singularity / Apptainer `user namespace` Permission Denied
- **Symptom**: `ERROR: Could not write info to setgroups: Permission denied` or `Error while waiting event for user namespace mappings`.
- **Cause**: Older cluster kernel configurations or Apptainer setuid configurations colliding with unprivileged user namespaces on shared HPC nodes.
- **Resolution**:
  1. Switch to the cluster's native Singularity-CE module (`module unload apptainer; module load singularity-ce`).
  2. Ensure the shared bind path is exported in your environment:
     ```bash
     export SINGULARITY_BINDPATH="/data"
     ```
