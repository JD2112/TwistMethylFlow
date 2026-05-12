---
hide:
  - navigation
---
# MethylFlow Developer Guide & Technical History

This document serves as a "brain dump" and maintenance manual for the **MethylFlow** pipeline. It tracks the major architectural shifts made during the v1.1.0 update to address reviewer feedback and clinical requirements.

---

## 1. Maintenance Workflow (How to Update)

To maintain clinical reproducibility, follow this exact sequence when updating tools or dependencies:

### Step A: Update the Conda Environment
1.  Modify the source `.yml` files in `containers/conda/` (e.g., `environment_main.yml`).
2.  **Always pin the version** (e.g., `samtools=1.19` instead of just `samtools`).
3.  If adding an R package, consider if it needs to be in the Conda env or the `rocker`-based Dockerfiles.

### Step B: Sync and Build
1.  **Sync**: Copy the updated `.yml` to `containers/docker/` to keep the build context current:
    ```bash
    cp containers/conda/environment_main.yml containers/docker/
    ```
2.  **Build**: Build the new image with an incremented version tag:
    ```bash
    cd containers/docker
    docker build -f Dockerfile_main -t jd21/methylflow:1.1.1 .
    ```
3.  **Verify**: Run `docker inspect <ID>` to ensure the `HEALTHCHECK` passes.

### Step C: Update Pipeline Config
1.  Open `conf/containers.config`.
2.  Update the version tag for the relevant process or the global `container` variable.
3.  Update the `nextflow_schema.json` or `params.config` if new parameters were added.

---

## 2. Technical Change Log (v1.1.0 Refinement)

### **A. Scientific Innovations**
*   **Multi-Resolution Analysis**: Integrated `callDMR` into the DSS module. The pipeline now calls both **DMCs** (Sites) and **DMRs** (Regions) simultaneously.
*   **The π-Value Unified Score**: Implemented a consensus layer that merges results from DSS, edgeR, and MethylKit using the π-value formula: $\pi = | \overline{\log_2(FC)} | \times (-\log_{10}(P_{min}))$.
*   **Gene-Centric Bridging**: Added logic to map regional (DMR) coordinates to the nearest TSS, allowing site-level and region-level data to be aggregated at the gene level for clinical interpretation.

### **B. Clinical Hardening**
*   **Clinical Gates**: Added `min_30x_pc` parameter to `params.config`. The pipeline now formally warns (or fails) if a sample doesn't meet the clinical gold-standard of 80% targets at >30x coverage.
*   **Integrity Checks**: Implemented SHA256 checksumming for all results and metadata to ensure data provenance during clinical audits.
*   **Security Patching**: 
    *   Migrated all containers to **non-root users** (`appuser`).
    *   Added **HEALTHCHECKs** to every image.
    *   Pinned base images to verified releases (`miniconda3:26.1.1`, `rocker/r-ver:4.3.3`, `rocker/tidyverse:4.3.3`).
    *   Kept `apt-get upgrade` intentionally to patch system-level CVEs (documented in each Dockerfile).

---

## 3. Publication Narrative (The "Story")

When writing the manuscript or responding to reviewers, emphasize these three pillars:

### **Pillar 1: The Translational Gap**
Standard pipelines (like `nf-core/methylseq`) stop at the `bedGraph` level. **MethylFlow** bridges the gap between raw methylation math and clinical pathology by providing automated gene-disease enrichment (DisGeNET) and a Unified Consensus Score.

### **Pillar 2: Mathematical Rigor**
Address "lack of innovation" comments by highlighting the **π-value consensus**. Instead of relying on a single tool's p-value, we use a validated mathematical framework to find the "biological truth" where multiple tools agree.

### **Pillar 3: Clinical Readiness**
MethylFlow is designed for regulated environments. The inclusion of **30x coverage gates**, **checksumming**, and **security-hardened containers** makes it a "turnkey" solution for diagnostic labs, not just a research script.

---

## 4. Benchmarking Strategy
To prove performance, the current strategy is a head-to-head run against `nf-core/methylseq` using the **NEB EM-seq** public dataset. 
*   **Metric 1**: Concordance of methylation calls (should be >99%).
*   **Metric 2**: Time-to-Insight (MethylFlow provides the Quarto report automatically; nf-core requires manual downstream work).

---

## 5. Version Management

All versioning across the pipeline is managed by a centralized release automation script that enforces **Semantic Versioning (SemVer)** across every file in the repository.

### The Release Automation Script: `scripts/publish.py`

When you are ready to release a new version (e.g., after benchmarking is complete), run this command from the project root:

```bash
python3 scripts/publish.py
```

#### What the script does:
1.  **Version Calculation**: Reads the current version from `conf/base.config` and asks if you want to bump a **Patch** (1.1.1), **Minor** (1.2.0), or **Major** (2.0.0) version.
2.  **Global Update**: Automatically scans and updates the version tags in:
    *   **Nextflow Configs**: `nextflow.config` (Manifest) and `conf/base.config`.
    *   **Containers**: Every `Dockerfile_*` in `containers/docker/` and the tags in `conf/containers.config`.
    *   **Reports**: The Quarto template (`assets/report.qmd`) and the workflow summary.
    *   **Documentation**: `README.md`, `BENCHMARKING.md`, and all files in `docs/`.
    *   **Binaries**: The version default in `bin/build_unified_results.py`.
3.  **Git Automation**:
    *   Stages all changes (`git add .`).
    *   Creates a commit: `Release vX.Y.Z`.
    *   Creates an **Annotated Git Tag** (e.g., `v1.1.1`).
4.  **GitHub Deployment**: Prompts to push the code and tags to `origin main`.

#### When to bump:
| Change Type | Bump | Example |
|-------------|------|---------|
| Bug fix, typo, dep patch | **Patch** | `1.1.0` → `1.1.1` |
| New feature, new module | **Minor** | `1.1.0` → `1.2.0` |
| Breaking config/API change | **Major** | `1.1.0` → `2.0.0` |

---

*Last Updated: April 29, 2026*

