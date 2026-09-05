process CHECK_FASTQC_N {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(reports)

    output:
    tuple val(meta), path("fastqc_status.txt"), emit: status

    script:
    """
    STATUS="passed"
    for file in ${reports}; do
        if [[ "\$file" == *.zip ]]; then
            # Unzip summary.txt to stdout, search for FAIL or WARN for Per base N content
            if unzip -p "\$file" "*/summary.txt" | grep -E "^(FAIL|WARN)\\s+Per base N content" > /dev/null; then
                STATUS="zombie (FastQC Per Base N-content flagged)"
            fi
        fi
    done
    echo "\$STATUS" > fastqc_status.txt
    """
}

process MERGE_STATUS {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(sync_status), path(fastqc_status)

    output:
    tuple val(meta), path("combined_status.txt"), emit: status

    script:
    """
    SYNC=\$(cat ${sync_status})
    FASTQC=\$(cat ${fastqc_status})
    if [ "\$SYNC" != "passed" ]; then
        echo "\$SYNC" > combined_status.txt
    elif [ "\$FASTQC" != "passed" ]; then
        echo "\$FASTQC" > combined_status.txt
    else
        echo "passed" > combined_status.txt
    fi
    """
}
