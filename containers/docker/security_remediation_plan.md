# Security Remediation Plan: MethylFlow Docker Image

The `docker scout` scan revealed **277 vulnerabilities**, including **9 Critical** and **66 High** severity issues. Most of these stem from an outdated base OS (Debian 11 Bullseye) and older versions of bioinformatics tools and Python libraries.

## 1. Key Vulnerabilities Identified

| Component | Version | Critical/High CVEs | Resolution |
| :--- | :--- | :--- | :--- |
| **OS (Debian 11)** | Bullseye | OpenSSL, GLIBC, Git, Curl | Upgrade to Debian 12 (Bookworm) via newer base image. |
| **Python** | 3.9.2 | 10 High (CVE-2015-20107, etc.) | Upgrade to Python 3.11+. |
| **urllib3** | 2.1.0 / 2.5.0 | 3 High (CVE-2026-21441, etc.) | Upgrade to >= 2.6.3. |
| **requests** | 2.31.0 | 3 Medium (CVE-2024-35195) | Upgrade to >= 2.32.4. |
| **MultiQC** | 1.13 | (Transitive deps) | Upgrade to 1.21+. |
| **Samtools** | 1.15 | (Transitive deps) | Upgrade to 1.20+. |

## 2. Proposed Remediation Steps

### Phase A: Base Image & OS Hardening
*   **Switch Base Image**: Move from `24.3.0-0` (Debian 11) to `24.11.1-0` (Debian 12 Bookworm).
*   **Force Upgrades**: Include `apt-get upgrade -y` during the build to capture the latest security patches.

### Phase B: Tool Environment Update
*   **Python 3.11**: Modernize the Python runtime for security and performance.
*   **Update Core Tools**:
    *   `fastqc`: 0.11.9 -> 0.12.1
    *   `multiqc`: 1.13 -> 1.21
    *   `samtools`: 1.15 -> 1.20
    *   `bowtie2`: 2.4.4 -> 2.5.4
    *   `bismark`: 0.23.1 -> 0.24.2

### Phase C: Dependency Pinning for Security
*   Explicitly pin `urllib3>=2.6.3` and `requests>=2.32.4` if they aren't automatically updated by other tools.

## 3. Implementation Plan

1.  **Update `Dockerfile_main`**:
    *   Change base image to `continuumio/miniconda3:24.11.1-0`.
    *   Add `apt-get upgrade -y` to the system dependencies step.
2.  **Update `environment_main.yml`**:
    *   Bump tool versions to the latest stable releases.
    *   Upgrade Python to 3.11.
    *   Add explicit security pins for `urllib3` and `requests`.
