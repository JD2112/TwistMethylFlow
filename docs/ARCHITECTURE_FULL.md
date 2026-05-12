# MethylFlow Pipeline Architecture (Supplemental / Full Version)

This document contains the high-detail architecture diagram for the **MethylFlow** pipeline, suitable for Supplemental Information or technical posters.

## Detailed Clinical Architecture (Mermaid)

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Helvetica, Arial, sans-serif",
    "fontSize": "15px",
    "primaryColor": "#ffffff",
    "primaryBorderColor": "#4b5563",
    "primaryTextColor": "#111827",
    "lineColor": "#6b7280",
    "secondaryColor": "#f8fafc",
    "tertiaryColor": "#ffffff",
    "clusterBkg": "#ffffff",
    "clusterBorder": "#9ca3af"
  },
  "flowchart": {
    "curve": "basis",
    "nodeSpacing": 35,
    "rankSpacing": 50,
    "padding": 10
  }
}}%%

flowchart TB

%% =========================================================
%% SECTION 1: CLINICAL FOUNDATION
%% =========================================================
subgraph S_FOUNDATION["I. Clinical Foundation (Security & Integrity)"]
    direction LR
    subgraph S0["0. Clinical DevSecOps"]
        direction LR
        DS1["Multi-Arch Build"] --> DS2["Trivy Scan"] --> DS3["Cosign Sign"] --> DS4["Hardened Registry"]
    end

    subgraph S1["1. Clinical Data Integrity"]
        direction LR
        FQ["Raw FastQ"] --> SHA["SHA256 Checksum"] --> HP["HIPAA PII Validation"]
    end
    
    S0 --> S1
end

%% =========================================================
%% SECTION 2: EXECUTION ENGINE
%% =========================================================
subgraph S2["II. Dual-Track Execution Engine"]
direction TB

M{"Execution Mode"}

subgraph GPU["GPU Pipeline (Parabricks)"]
direction LR
G1["fq2bam_meth"] --> G2["MethylDackel"]
end

subgraph CPU["CPU Pipeline (Bismark)"]
direction LR
C1["FastQ Splitting"] --> C2["Align + Dedup"] --> C3["Extractor"]
end

HP --> M
M -->|GPU| G1
M -->|CPU| C1

end

%% =========================================================
%% SECTION 3: DIFFERENTIAL METHYLATION
%% =========================================================
subgraph S3["III. Multi-Method Differential Methylation"]
direction TB

P["Coverage Filtering<br/>Normalization"]

D1["methylKit"]
D2["edgeR"]
D3["DSS"]

G2 --> P
C3 --> P

P --> D1
P --> D2
P --> D3

end

%% =========================================================
%% SECTION 4: INTERPRETATION
%% =========================================================
subgraph S4["IV. Biological Interpretation"]
direction TB

U["Unified Analysis Layer<br/>π-Value Score"]

B1["GO / KEGG"]
B2["DisGeNET"]
B3["Promoter / Enhancer"]

D1 --> U
D2 --> U
D3 --> U

U --> B1
U --> B2
U --> B3

end

%% =========================================================
%% SECTION 5: REPORTING
%% =========================================================
subgraph S5["V. Automated Reporting Suite"]
direction TB

R1["Quarto Report Engine"]

R2["Clinical PDF"]
R3["Interactive HTML"]
R4["MultiQC Summary"]

B1 --> R1
B2 --> R1
B3 --> R1

R1 --> R2
R1 --> R3

HP --> R4
G1 --> R4
C2 --> R4

end

%% =========================================================
%% STYLING
%% =========================================================
classDef default fill:#ffffff,stroke:#4b5563,stroke-width:1.2px,color:#111827,font-size:15px;
classDef emphasis fill:#f3f4f6,stroke:#374151,stroke-width:1.8px,color:#111827,font-weight:bold;

class M,U,R1 emphasis;
```
