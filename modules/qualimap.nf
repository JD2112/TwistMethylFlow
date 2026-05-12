process QUALIMAP {
    tag "$meta.id"
    label 'process_medium'

    // conda "bioconda::qualimap=2.2.2d"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/qualimap:2.2.2d--1' :
    //     'quay.io/biocontainers/qualimap:2.2.2d--1' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${prefix}"), emit: results
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def memory = task.memory.toGiga() + "G"
    """
    qualimap \\
        bamqc \\
        -bam $bam \\
        -outdir $prefix \\
        -outformat HTML \\
        --java-mem-size=$memory \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qualimap: \$(qualimap 2>&1 | grep 'QualiMap v.' | head -n 1 | sed 's/QualiMap v.//g' | xargs)
    END_VERSIONS
    """
}