process PICARD_COLLECTHSMETRICS {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(bam), path(bai)
    path fasta
    path target_bed

    output:
    tuple val(meta), path("*.hs_metrics.txt"), emit: metrics
    path "versions.yml", emit: versions

    when:
    meta.assay_type == 'twist' && target_bed.name != 'NO_BED'

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # 1. Create Sequence Dictionary
    picard CreateSequenceDictionary \\
        R=${fasta} \\
        O=reference.dict

    # 2. Convert BED to Interval List
    picard BedToIntervalList \\
        I=${target_bed} \\
        O=targets.interval_list \\
        SD=reference.dict

    # 3. Collect Metrics
    picard CollectHsMetrics \\
        I=${bam} \\
        O=${prefix}.hs_metrics.txt \\
        R=${fasta} \\
        BAIT_INTERVALS=targets.interval_list \\
        TARGET_INTERVALS=targets.interval_list \\
        MINIMUM_MAPPING_QUALITY=20 \\
        MINIMUM_BASE_QUALITY=20
        
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        picard: \$(picard CollectHsMetrics --version 2>&1 | grep -o 'Version.*' | cut -d' ' -f2)
    END_VERSIONS
    """
}
