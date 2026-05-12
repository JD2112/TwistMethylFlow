process REPORT {
    label 'process_low'
    publishDir "${params.outdir}/report", mode: 'copy'

    input:
    path(results_dir)
    path(report_qmd)
    path(logo)
    path(citations_bib)

    output:
    path("MethylFlow_Report.pdf"), emit: pdf
    path("MethylFlow_Report.html"), emit: html, optional: true

    script:
    def results_path = results_dir.toRealPath()
    """
    export HOME=\$PWD
    export XDG_CACHE_HOME=\$PWD/quarto-cache
    export QUARTO_DATA_DIR=\$PWD/quarto-data
    export TEXMFVAR=\$PWD/texmf-var
    export TEXMFCONFIG=\$PWD/texmf-config
    
    mkdir -p \$XDG_CACHE_HOME \$QUARTO_DATA_DIR \$TEXMFVAR \$TEXMFCONFIG
    
    cat <<-EOF > report_meta.yml
    format:
      pdf:
        pdf-engine: pdflatex
        latex-auto-install: false
        documentclass: article
        highlight-style: github
    EOF
    
    # 📄 Render PDF
    quarto render ${report_qmd} \
        --to pdf \
        --metadata-file report_meta.yml \
        -P mode=${params.mode} \
        -P sample_metadata=${results_path}/sample_metadata.tsv \
        -P qc_summary=${results_path}/qc_summary.tsv \
        -P dmr_summary=${results_path}/dmr_summary.tsv \
        -P pathway_summary=${results_path}/go_results.csv \
        -P kegg_summary=${results_path}/kegg_results.csv \
        -P disease_summary=${results_path}/disease_enrichment.csv \
        -P gene_summary=${results_path}/gene_prioritized.csv \
        -P run_info=${results_path}/run_info.json \
        -o MethylFlow_Report.pdf

    # 🌐 Render HTML
    quarto render ${report_qmd} \
        --to html \
        -P mode=${params.mode} \
        -P sample_metadata=${results_path}/sample_metadata.tsv \
        -P qc_summary=${results_path}/qc_summary.tsv \
        -P dmr_summary=${results_path}/dmr_summary.tsv \
        -P pathway_summary=${results_path}/go_results.csv \
        -P kegg_summary=${results_path}/kegg_results.csv \
        -P disease_summary=${results_path}/disease_enrichment.csv \
        -P gene_summary=${results_path}/gene_prioritized.csv \
        -P run_info=${results_path}/run_info.json \
        -o MethylFlow_Report.html
    """
}
