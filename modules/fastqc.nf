process FASTQC {
    tag "$meta.id"
    label 'process_low'

    // conda "bioconda::fastqc=0.11.9"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'quay.io/biocontainers/fastqc:0.11.9--0' :
    //     'quay.io/biocontainers/fastqc:0.11.9--0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_fastqc.{zip,html}"), emit: reports
    path "versions.yml"                         , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    fastqc $args --threads $task.cpus $reads
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$( fastqc --version | head -n 1 | sed -e "s/FastQC v//g" )
    END_VERSIONS
    """
}