process GO_ANALYSIS {
    label 'process_medium'

    input:
    tuple val(method), path(results)
    val logfc_cutoff
    val pvalue_cutoff
    val top_n

    output:
    tuple val(method), path("*_gochord_plot.png"), emit: plot
    tuple val(method), path("*_gochord_plot.svg"), emit: goplot
    tuple val(method), path("*_go_enrichment_results.csv"), emit: results
    path "versions.yml", emit: versions

    script:
    def results_list = results instanceof List ? results : [results]
    def script = results_list.collect { result ->
        """
        echo "Running GO analysis for ${method} with result file: ${result.name}"

        if Rscript ${workflow.projectDir}/bin/go_analysis.R \
            --results ${result.name} \
            --output . \
            --method ${method} \
            --logfc_cutoff ${logfc_cutoff} \
            --pvalue_cutoff ${pvalue_cutoff} \
            --top_n ${top_n}; then
            echo "✅ GO analysis done for ${result.name}"
        else
            echo "⚠️ Skipping ${result.name}: no significant results or analysis failed."
            prefix=\$(basename ${result.name} .csv)
            touch \${prefix}_gochord_plot.png
            touch \${prefix}_gochord_plot.svg
            touch \${prefix}_go_enrichment_results.csv
        fi
        """
    }.join('\n')

    """
    ${script}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //' | sed 's/ .*//')
        goplot: \$(Rscript -e "library(GOplot); cat(as.character(packageVersion('GOplot')))")
        clusterprofiler: \$(Rscript -e "library(clusterProfiler); cat(as.character(packageVersion('clusterProfiler')))")
    END_VERSIONS
    """
}
