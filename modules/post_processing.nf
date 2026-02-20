process POST_PROCESSING {
    label 'process_medium'

    input:
    tuple val(method), path(results)
    val compare_str
    val logfc_cutoff
    val pvalue_cutoff
    val hyper_color
    val hypo_color
    val nonsig_color

    output:
    tuple val(method), path("*_summary_stats.csv"), emit: summary
    tuple val(method), path("*.png"), emit: plots
    path "versions.yml", emit: versions

    script:
    """
    Rscript ${workflow.projectDir}/bin/post_processing.R \
        --results ${results} \
        --compare "${compare_str}" \
        --output . \
        --method ${method} \
        --logfc_cutoff ${logfc_cutoff} \
        --pvalue_cutoff ${pvalue_cutoff} \
        --hyper_color "${hyper_color}" \
        --hypo_color "${hypo_color}" \
        --nonsig_color "${nonsig_color}"

    cat <<-END_VERSIONS > versions.yml
    
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //' | sed 's/ .*//')
        ggplot2: \$(Rscript -e "library(ggplot2); cat(as.character(packageVersion('ggplot2')))")
        dplyr: \$(Rscript -e "library(dplyr); cat(as.character(packageVersion('dplyr')))")
        tidyr: \$(Rscript -e "library(tidyr); cat(as.character(packageVersion('tidyr')))")
    END_VERSIONS
    """
}