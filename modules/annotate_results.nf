process ANNOTATE_RESULTS {
    label 'process_medium'

    input:
    tuple val(method), path(result)
    path gtf

    output:
    tuple val(method), path("${result.simpleName}_annotated.csv"), emit: annotated_results
    path "versions.yml", emit: versions
    path "${result.simpleName}_log.txt", emit: log

    script:
    def gtf_arg = gtf.name != 'NO_FILE' ? "--gtf ${gtf}" : ''

    """
    echo "Annotating ${result} ..." > ${result.simpleName}_log.txt

    Rscript ${workflow.projectDir}/bin/annotate_results.R \
        --results ${result} \
        ${gtf_arg} >> ${result.simpleName}_log.txt 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //' | sed 's/ .*//')
        edger: \$(Rscript -e "library(edgeR); cat(as.character(packageVersion('edgeR')))")
    END_VERSIONS
    """
}
