process METHYLKIT_ANALYSIS {
    tag "MethylKit on ${design_file}"
    label 'process_high'    

    input:
    path coverage_files
    path design_file
    val compare_str
    val coverage_threshold
    path refseq_file
    val assembly
    val mc_cores
    val diff
    val qvalue

    output:
    path "MethylKit_*.csv", emit: results
    path "versions.yml", emit: versions
    path "methylkit_log.txt", emit: log

    script:
    def args = task.ext.args ?: ''
    def coverage_files_str = coverage_files.join(',')
    def refseq_param = refseq_file ? "--refseq ${refseq_file}" : ""
    """
    echo "Starting MethylKit analysis" > methylkit_log.txt
    echo "Coverage files: ${coverage_files_str}" >> methylkit_log.txt
    echo "Design file: ${design_file}" >> methylkit_log.txt
    echo "Compare string: ${compare_str}" >> methylkit_log.txt
    echo "Threshold: ${coverage_threshold}" >> methylkit_log.txt
    echo "RefSeq file: ${refseq_file}" >> methylkit_log.txt
    echo "Assembly: ${assembly}" >> methylkit_log.txt
    echo "MC cores: ${mc_cores}" >> methylkit_log.txt
    echo "Difference threshold: ${diff}" >> methylkit_log.txt
    echo "Q-value threshold: ${qvalue}" >> methylkit_log.txt

    # Force re-run for script updates
    Rscript methylkit_analysis.R \\
        --coverage_files ${coverage_files_str} \\
        --design ${design_file} \\
        --compare ${compare_str} \\
        --output . \\
        --threshold ${coverage_threshold} \\
        ${refseq_param} \\
        --assembly ${assembly} \\
        --mc_cores ${mc_cores} \\
        --diff ${diff} \\
        --qvalue ${qvalue} \\
        $args >> methylkit_log.txt 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-methylkit: \$(Rscript -e "library(methylKit); cat(as.character(packageVersion('methylKit')))")
        r-genomation: \$(Rscript -e "library(genomation); cat(as.character(packageVersion('genomation')))")
        r-org.hs.eg.db: \$(Rscript -e "library(org.Hs.eg.db); cat(as.character(packageVersion('org.Hs.eg.db')))")
    END_VERSIONS
    """
}