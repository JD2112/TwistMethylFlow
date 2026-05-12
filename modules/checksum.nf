process CHECKSUM_VERIFY {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.sha256"), emit: checksums

    script:
    def single_end = meta.single_end ? true : false
    """
    if [ "${single_end}" = "true" ]; then
        sha256sum ${reads[0]} > ${meta.id}_R1.sha256
    else
        sha256sum ${reads[0]} > ${meta.id}_R1.sha256
        sha256sum ${reads[1]} > ${meta.id}_R2.sha256
    fi
    """
}
