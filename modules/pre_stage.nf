process PRE_STAGE_FILES {
    label 'process_low'
    cache false
    
    output:
    val true, emit: done

    script:
    """
    echo "===================================================="
    echo "Reviewer Mode: Auto-Staging Human EM-seq Test Data"
    echo "===================================================="
    
    # Check for GPU availability if parabricks is intended to be used
    if [ "${params.use_parabricks}" = "true" ]; then
        echo "Checking for NVIDIA GPU availability..."
        if command -v nvidia-smi &> /dev/null; then
            nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        else
            echo "WARNING: nvidia-smi not found. GPU acceleration may fail or fall back to CPU!"
        fi
    fi

    # Validate sample sheet hardware column if it exists
    echo "Validating sample sheet hardware assignments..."
    python3 -c "
import csv
import sys
try:
    with open('${params.sample_sheet}', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            hw = row.get('hardware', '').lower()
            if hw and hw not in ['cpu', 'gpu']:
                print(f\"ERROR: Invalid hardware type '{hw}' for sample {row.get('sample_id', 'unknown')}\")
                sys.exit(1)
    print(\"Sample sheet hardware validation passed.\")
except Exception as e:
    print(f\"Validation skipped: {e}\")
"

    bash ${projectDir}/bin/download_test_data.sh ${projectDir} ${params.sample_sheet}
    """
}

workflow PRE_STAGE {
    main:
    PRE_STAGE_FILES()
    
    emit:
    done = PRE_STAGE_FILES.out.done
}
