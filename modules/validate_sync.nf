process VALIDATE_SYNC {
    tag "$meta.id"
    label 'process_single'
    
    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path(reads), emit: reads
    tuple val(meta), path("sync_status.txt"), emit: status

    script:
    if (meta.single_end) {
        """
        echo "passed" > sync_status.txt
        """
    } else {
        """
        # 0. Check for empty files
        if [ ! -s ${reads[0]} ] || [ ! -s ${reads[1]} ]; then
            echo "zombie" > sync_status.txt
            exit 0
        fi

        # 1. Check first 1000 IDs (Maintain order, strip suffixes)
        zgrep -m 1000 '^@' ${reads[0]} | cut -d' ' -f1 | sed 's/\\/[12]\$//; s/_[12]\$//' > r1_head.txt
        zgrep -m 1000 '^@' ${reads[1]} | cut -d' ' -f1 | sed 's/\\/[12]\$//; s/_[12]\$//' > r2_head.txt
        
        # 2. Check last 1000 IDs (To catch truncation, strip suffixes)
        zcat ${reads[0]} | tail -n 4000 | grep '^@' | cut -d' ' -f1 | sed 's/\\/[12]\$//; s/_[12]\$//' > r1_tail.txt
        zcat ${reads[1]} | tail -n 4000 | grep '^@' | cut -d' ' -f1 | sed 's/\\/[12]\$//; s/_[12]\$//' > r2_tail.txt

        HEAD_DIFF=0
        TAIL_DIFF=0
        diff r1_head.txt r2_head.txt > /dev/null || HEAD_DIFF=1
        diff r1_tail.txt r2_tail.txt > /dev/null || TAIL_DIFF=1

        # 3. Strict Read Count Equality Check
        # Optimized: Only check if line counts are identical without reading full file twice if possible
        # We use a subshell to capture exit status 141 (SIGPIPE) as success
        R1_COUNT=\$(zcat ${reads[0]} | wc -l) || [ \$? -eq 141 ]
        R2_COUNT=\$(zcat ${reads[1]} | wc -l) || [ \$? -eq 141 ]

        if [ "\$R1_COUNT" -ne "\$R2_COUNT" ]; then
            echo "zombie (count mismatch: R1=\$R1_COUNT, R2=\$R2_COUNT)" > sync_status.txt
            exit 0
        fi

        if [ \$HEAD_DIFF -eq 0 ] && [ \$TAIL_DIFF -eq 0 ]; then
            echo "passed" > sync_status.txt
        else
            echo "zombie (ID mismatch: head_diff=\$HEAD_DIFF, tail_diff=\$TAIL_DIFF)" > sync_status.txt
        fi
        """
    }
}
