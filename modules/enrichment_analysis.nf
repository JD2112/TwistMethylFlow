process ENRICHMENT_ANALYSIS {
    label 'process_medium'

    input:
    tuple val(method), path(results)
    val logfc_cutoff
    val pvalue_cutoff
    val top_n

    output:
    tuple val(method), path("*_gochord_plot.png"), emit: plot
    tuple val(method), path("*_gochord_plot.svg"), emit: goplot
    tuple val(method), path("*_dotplot.png"), emit: dotplot
    tuple val(method), path("*_barplot.png"), emit: barplot
    tuple val(method), path("*_go_enrichment_results.csv"), emit: results
    tuple val(method), path("*_kegg_enrichment_results.csv"), emit: kegg_results
    tuple val(method), path("*_kegg_dotplot.png"), emit: kegg_dotplot
    tuple val(method), path("*_kegg_barplot.png"), emit: kegg_barplot
    path "versions.yml", emit: versions

    script:
    """
    # Process each result file found in the staged inputs
    for result_file in ${results}; do
        echo "Running Enrichment analysis for ${method} with result file: \${result_file}"

        if Rscript ${workflow.projectDir}/bin/enrichment_analysis.R \\
            --results "\${result_file}" \\
            --output . \\
            --method ${method} \\
            --logfc_cutoff ${logfc_cutoff} \\
            --pvalue_cutoff ${pvalue_cutoff} \\
            --top_n ${top_n}; then
            echo "Enrichment analysis done for \${result_file}"
        else
            echo "Skipping \${result_file}: no significant results or analysis failed."
            prefix=\$(basename "\${result_file}" .csv)
            touch "\${prefix}_gochord_plot.png"
            touch "\${prefix}_gochord_plot.svg"
            touch "\${prefix}_dotplot.png"
            touch "\${prefix}_barplot.png"
            touch "\${prefix}_go_enrichment_results.csv"
            touch "\${prefix}_kegg_enrichment_results.csv"
            touch "\${prefix}_kegg_dotplot.png"
            touch "\${prefix}_kegg_barplot.png"
        fi
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | grep -oP '(?<=R version )[0-9.]+' )
        r-goplot: \$(Rscript -e "if(requireNamespace('GOplot', quietly=TRUE)) { cat(as.character(packageVersion('GOplot'))) } else { cat('NA') }" | xargs)
        r-clusterprofiler: \$(Rscript -e "if(requireNamespace('clusterProfiler', quietly=TRUE)) { cat(as.character(packageVersion('clusterProfiler'))) } else { cat('NA') }" | xargs)
    END_VERSIONS
    """
}

