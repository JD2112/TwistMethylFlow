process MULTIQC {
    label 'process_medium'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path(multiqc_files)
    path(multiqc_config)
    path(multiqc_logo)

    output:
    path "*_report.html", emit: report
    path "*_data"       , emit: data
    path "multiqc.log"  , emit: log
    path "versions.yml" , emit: versions

    script:
    def args = task.ext.args ?: ''
    def config = multiqc_config ? "--config ${multiqc_config}" : ''
    // Logo disabled as requested by user to debug exit 2
    // def logo = multiqc_logo ? "--cl_config 'custom_logo: \"${multiqc_logo}\"'" : ''
    """
    multiqc -f $args $config . > multiqc.log 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | head -n 1 | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}