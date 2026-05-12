process PARABRICKS_FQ2BAMMETH {
    tag "$meta.id"
    label 'gpu'

    input:
    tuple val(meta), path(reads)
    path fasta
    path index

    output:
    tuple val(meta), path("*.bam"), emit: bam
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def in_reads = meta.single_end ? "--in-fq ${reads}" : "--in-fq ${reads[0]} ${reads[1]}"
    
    """
    pbrun fq2bam_meth \\
        --ref ${fasta} \\
        ${in_reads} \\
        --out-bam ${prefix}.bam \\
        ${args}

    cat <<EOF > versions.yml
    "${task.process}":
        pbrun: \$(pbrun version | head -n 1 | grep -oP '(?<=v)[0-9.]+' || pbrun version | head -n 1)
    EOF
    """
}

process METHYLDACKEL_EXTRACT {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/methyldackel:0.6.1--h577a1d6_9'

    input:
    tuple val(meta), path(bam), path(bai)
    path fasta
    path fasta_index   // .fai file

    output:
    tuple val(meta), path("*.bedGraph"), emit: bedgraph
    path "versions.yml",                emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    MethylDackel extract \\
        ${args} \\
        -o ${prefix} \\
        ${fasta} \\
        ${bam}

    cat <<EOF > versions.yml
    "${task.process}":
        MethylDackel: \$(MethylDackel --version 2>&1 | head -n 1 | grep -oP '[0-9.]+')
    EOF
    """
}
