process BWAMETH_INDEX {
    tag "$fasta"
    label 'process_high'
    container 'quay.io/biocontainers/bwameth:0.2.9--pyh7e72e81_0'

    input:
    path fasta

    output:
    path "${fasta}.*", emit: index
    path "versions.yml" , emit: versions

    script:
    """
    if command -v bwameth.py >/dev/null 2>&1; then
        bwameth.py index $fasta
    else
        bwameth index $fasta
    fi

    cat <<EOF > versions.yml
    "${task.process}":
        bwameth: \$(bwameth.py --version 2>&1 | grep -oP '[0-9.]+' || bwameth --version 2>&1 | grep -oP '[0-9.]+' || echo "unknown")
    EOF
    """
}
