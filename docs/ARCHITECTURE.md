# milou Pipeline Architecture

This document contains the master architecture diagram for the **milou** pipeline. It is designed for use in manuscripts, documentation, and technical presentations.

## Master Clinical Architecture (Mermaid)

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Arial, sans-serif",
    "fontSize": "35px",
    "primaryColor": "#ffffff",
    "primaryBorderColor": "#4b5563",
    "primaryTextColor": "#111827",
    "lineColor": "#000000ff",
    "secondaryColor": "#f8fafc",
    "tertiaryColor": "#e6d80fff",
    "clusterBkg": "#ffffff",
    "clusterBorder": "#9ca3af",
    "subgraph-padding": 80
  },
  "flowchart": {
    "curve": "linear",
    "nodeSpacing": 50,
    "rankSpacing": 0,
    "padding": 10,
    "wrappingWidth": 2000,
    "subGraphTitleMargin": {
        "top": 10,
        "bottom": 10,
        "left": 0,
        "right": 0
    }
  }
}}%%

flowchart TB

%% =========================================================
%% I. CLINICAL GOVERNANCE & INTEGRITY
%% =========================================================
subgraph S1["I. Clinical Governance & Integrity"]
    direction LR
    subgraph S1A["0. Clinical DevSecOps Audit"]
        direction LR
        LINT["nf-core lint / Semgrep"] --> SCAN["Trivy / Snyk / Grype"] --> SBOM["Syft (SBOM)"] --> SIGN["Cosign OCI Sign"]
    end

    subgraph S1B["1. Data Integrity"]
        direction LR
        B1["Raw FastQ"] --> B2["SHA256 Checksum"] --> B3["Metadata Privacy Audit"]
    end
    
    S1A --> S1B
end

%% =========================================================
%% II. DUAL-TRACK EXECUTION ENGINE
%% =========================================================
subgraph S2["II. Dual-Track Execution Engine"]
    direction TB
    M{"Mode Selection"}

    subgraph GPU["GPU Track (NVIDIA Parabricks)"]
        direction LR
        G1["fq2bam_meth"] --> G2["Qualimap"] --> G3["MethylDackel"]
    end

    subgraph CPU["CPU Track (Bismark)"]
        direction LR
        CP1["FastQ Splitting"] --> CP2["Align + Dedup"] --> CP3["Qualimap"] --> CP4["MethylDackel"]
    end

    S1B --> M
    M -->|GPU| GPU
    M -->|CPU| CPU
end

%% =========================================================
%% III. ANALYTICAL CONSENSUS LAYER
%% =========================================================
subgraph S3["III. Analytical Consensus Layer"]
    direction TB
    P["Coverage Filtering & Normalization"]

    subgraph METHODS["Differential Methylation Methods"]
        direction LR
        D1["methylKit"] ~~~ D2["edgeR"] ~~~ D3["DSS"]
    end

    GPU & CPU --> P
    P --> METHODS
end

%% =========================================================
%% IV. INTERPRETATION & REPORTING
%% =========================================================
subgraph S4["IV. Interpretation & Reporting"]
    direction TB
    U["Unified Analysis Layer (π-Value)"]
    
    subgraph INT["Biological Mapping"]
        direction LR
        I1["GO / KEGG"] ~~~ I2["DisGeNET"] ~~~ I3["Promoter/Enhancer"]
    end

    R["Quarto Clinical Report Engine"]
    MQC["MultiQC Technical Summary"]

    METHODS --> U
    U --> INT
    INT --> R
    
    R --> OUT1["Clinical PDF"] & OUT2["Interactive HTML"]
    
    %% Technical QC Aggregation
    S1B & GPU & CPU --> MQC
end

%% =========================================================
%% STYLING
%% =========================================================
classDef default fill:#ffffff,stroke:#4b5563,stroke-width:2px,color:#111827,font-size:35px;
classDef emphasis fill:#f3f4f6,stroke:#374151,stroke-width:3px,color:#111827,font-weight:bold,font-size:35px;

class M,U,R,P,MQC emphasis;

%% Subgraph Styling (Headers)
style S1 font-size:45px,font-weight:bold
style S1A font-size:40px,font-weight:bold
style S1B font-size:40px,font-weight:bold
style S2 font-size:45px,font-weight:bold
style GPU font-size:40px,font-weight:bold
style CPU font-size:40px,font-weight:bold
style S3 font-size:45px,font-weight:bold
style METHODS font-size:40px,font-weight:bold
style S4 font-size:45px,font-weight:bold
style INT font-size:40px,font-weight:bold

%% Global Link Style (Wider Arrows)
linkStyle default stroke-width:4px,stroke:gray;
```

## Figure Legend (Manuscript Draft)

**Figure 1: The milou end-to-end clinical-grade DNA methylation orchestration.** 
(0) The pipeline utilizes an integrated 'nf-security-audit' suite (nf-core lint, Semgrep, Trivy, Snyk, Grype, Syft, and Cosign) for comprehensive static analysis, OCI vulnerability scanning, SBOM generation, and cryptographic signing. 
(1) All input data undergoes mandatory SHA256 integrity verification and privacy-aware metadata schema validation to ensure data de-identification and integrity. 
(2) Users can select between a high-speed GPU track (NVIDIA Parabricks) or a highly-optimized parallelized CPU track (Bismark). 
(3) Statistical analysis is performed across three independent mathematical frameworks (methylKit, edgeR, and DSS) to identify differentially methylated regions (DMRs). 
(4) A Unified Analysis Layer synthesizes results using a consensus scoring system, which is then mapped to biological pathways (GO/KEGG) and clinical disease descriptors (DisGeNET). 
(5) The final output is an automated, physician-ready clinical report generated via Quarto.
