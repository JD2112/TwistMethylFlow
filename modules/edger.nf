process EDGER_ANALYSIS {
    label 'process_medium'    

    // conda "bioconda::bioconductor-edger=3.34.0"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'quay.io/biocontainers/bioconductor-edger:3.34.0--r41h399db7b_0' :
    //     'quay.io/biocontainers/bioconductor-edger:3.34.0--r41h399db7b_0' }"

    input:
    path coverage_files
    path design_file
    val compare_str
    val coverage_threshold
    val p_threshold
    val diff_threshold

    output:
    path "EdgeR_*.csv", emit: results
    path "versions.yml", emit: versions
    path "edger_log.txt", emit: log

    script:
    def coverage_files_list = coverage_files.collect { it.toString() }.join(' ')
    
    """
    Rscript ${projectDir}/bin/edgeR_analysis.R \\
        --design "${design_file}" \\
        --compare "${compare_str}" \\
        --output . \\
        --coverage_threshold ${coverage_threshold} \\
        --p_threshold ${p_threshold} \\
        --diff_threshold ${diff_threshold} \\
        ${coverage_files_list} > edger_log.txt 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | grep -oP '(?<=R version )[0-9.]+' )
        bioconductor-edger: \$( Rscript -e "library(edgeR); cat(as.character(packageVersion('edgeR')))" | xargs )
    END_VERSIONS
    """
}