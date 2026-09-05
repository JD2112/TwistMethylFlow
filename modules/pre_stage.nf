process PRE_STAGE_FILES {
    label 'process_long'
    cache false
    
    output:
    val true, emit: done

    script:
    """
    echo "===================================================="
    echo "PRE-STAGE: System and Sample Sheet Audit"
    echo "===================================================="
    
    if command -v nvidia-smi &> /dev/null; then
        echo "GPU Audit:"
        nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv,noheader || true
    else
        echo "No NVIDIA GPUs detected on host."
    fi

    # Validate Sample Sheet Hardware column
    python3 <<EOF
import csv
import sys
import os

sample_sheet = "${params.sample_sheet}"
if not os.path.exists(sample_sheet):
    print(f"Sample sheet not found: {sample_sheet}")
    sys.exit(0)

try:
    with open(sample_sheet, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            hw = row.get('hardware', '').lower()
            if not hw:
                print(f"WARNING: No hardware specified for sample {row.get('sample_id', 'unknown')}. Defaulting to GPU.")
            elif hw not in ['cpu', 'gpu']:
                print(f"ERROR: Invalid hardware type '{hw}' for sample {row.get('sample_id', 'unknown')}")
                print("Allowed values: 'cpu' or 'gpu'")
                sys.exit(1)
    print("Sample sheet validation complete.")
except Exception as e:
    print(f"Validation skipped: {e}")
EOF

    # Download test data if script exists
    if [ -f "${projectDir}/bin/download_test_data.sh" ]; then
        bash ${projectDir}/bin/download_test_data.sh ${projectDir} ${params.sample_sheet}
    fi
    """
}

workflow PRE_STAGE {
    main:
    PRE_STAGE_FILES()
    
    emit:
    done = PRE_STAGE_FILES.out.done
}
