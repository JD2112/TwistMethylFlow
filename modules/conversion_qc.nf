process CONVERSION_QC {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(coverage)

    output:
    tuple val(meta), path("conversion_status.txt"), emit: status
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    import gzip
    import sys

    cov_file = "${coverage}"
    meth_count = 0
    unmeth_count = 0
    lambda_found = False

    # Read the coverage file (can be gzipped or plain text)
    def open_file(filename):
        if filename.endswith('.gz'):
            return gzip.open(filename, 'rt')
        return open(filename, 'rt')

    with open_file(cov_file) as f:
        for line in f:
            parts = line.strip().split('\\t')
            if len(parts) >= 6:
                chrom = parts[0].lower()
                # Check for common lambda phage contig names
                if 'lambda' in chrom or 'phage' in chrom or chrom == 'chrl':
                    lambda_found = True
                    meth_count += int(parts[4])
                    unmeth_count += int(parts[5])

    status_msg = "passed"
    conversion_rate = 100.0

    if lambda_found:
        total = meth_count + unmeth_count
        if total > 0:
            non_conversion = (meth_count / total) * 100
            conversion_rate = 100 - non_conversion
            if non_conversion > 1.0:
                status_msg = f"failed (Conversion: {conversion_rate:.2f}%)"
            else:
                status_msg = f"passed (Conversion: {conversion_rate:.2f}%)"
        else:
            status_msg = "passed (Lambda found but 0 coverage)"
    else:
        # If lambda isn't present, check CHH/CHG globally if needed, or pass safely
        status_msg = "passed (No Lambda spike-in detected)"

    with open("conversion_status.txt", "w") as out:
        out.write(status_msg + "\\n")

    with open("versions.yml", "w") as out:
        out.write('\\"${task.process}\\":\\n')
        out.write('    python: \\"' + sys.version.split()[0] + '\\"\\n')
    """
}
