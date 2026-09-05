process DSS_ANALYSIS {
    label 'process_medium'    

    input:
    path coverage_files
    path design_file
    val compare_str
    val coverage_threshold
    val p_threshold
    val diff_threshold

    output:
    path "DSS_*.csv", emit: results
    path "versions.yml", emit: versions
    path "dss_log.txt", emit: log

    script:
    def args = task.ext.args ?: ''
    def coverage_files_list = coverage_files.collect { it.toString() }.join(' ')
    
    """
    Rscript ${projectDir}/bin/dss_analysis.R \\
        --design "${design_file}" \\
        --compare "${compare_str}" \\
        --output . \\
        --coverage_threshold ${coverage_threshold} \\
        --p_threshold ${p_threshold} \\
        --diff_threshold ${diff_threshold} \\
        $args \\
        ${coverage_files_list} > dss_log.txt 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | grep -oP '(?<=R version )[0-9.]+' )
        bioconductor-dss: \$( Rscript -e "library(DSS); cat(as.character(packageVersion('DSS')))" | xargs )
    END_VERSIONS
    """
}
