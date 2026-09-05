process TRIM_GALORE {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*{3prime,5prime,trimmed,val}*.fq.gz"), emit: trimmed_reads
    tuple val(meta), path("*_trimming_report.txt"), emit: reports
    tuple val(meta), path("*unpaired*.fq.gz")                   , emit: trim_unpaired, optional: true
    tuple val(meta), path("*.html")                             , emit: trim_html    , optional: true    
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    def assay_args = ''
    if (meta.assay_type == 'twist' || meta.assay_type == 'emseq') {
        assay_args = '--clip_R1 10 --clip_R2 10 --three_prime_clip_R1 10 --three_prime_clip_R2 10'
    }
    
    """
    trim_galore --paired --cores $task.cpus $args $assay_args $reads
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trim_galore: \$( trim_galore --version | head -n 1 | grep -oP '(?<=version )[0-9.]+' || trim_galore --version | head -n 1 | sed -e "s/^trim_galore //g" )
    END_VERSIONS
    """
}