process VALIDATE_SYNC {
    tag "$meta.id"
    label 'process_single'
    
    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path(reads), emit: reads

    script:
    if (meta.single_end) {
        """
        echo "Single-end sample, skipping sync check."
        """
    } else {
        """
        # Extract first 1000 IDs from both files and compare
        # We handle .gz files and look for the first field (the ID)
        zgrep -m 1000 '^@' ${reads[0]} | cut -d' ' -f1 | sort > r1_ids.txt
        zgrep -m 1000 '^@' ${reads[1]} | cut -d' ' -f1 | sort > r2_ids.txt
        
        if diff r1_ids.txt r2_ids.txt > /dev/null; then
            echo "FastQ Synchronicity Check Passed for ${meta.id}"
        else
            echo "========================================================================"
            echo "ERROR: FastQ Synchronicity Check FAILED for ${meta.id}"
            echo "Mismatched read IDs detected between R1 and R2."
            echo "This sample will likely cause Parabricks to hang or crash."
            echo "Please check FastQ integrity."
            echo "========================================================================"
            exit 1
        fi
        """
    }
}
