process METHYLKIT_ANALYSIS {
    tag "MethylKit on ${design_file}"
    label 'process_high'
    cache false

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
    path bed_file
    val min_per_group

    output:
    path "MethylKit_*.csv", emit: results
    path "versions.yml", emit: versions
    path "methylkit_log.txt", emit: log

    script:
    def args = task.ext.args ?: ''
    def coverage_files_str = coverage_files.join(',')
    def refseq_param = refseq_file ? "--refseq ${refseq_file}" : ""
    def bed_param = bed_file ? "--bed ${bed_file}" : ""
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
    echo "Min per group: ${min_per_group}" >> methylkit_log.txt

    # Force re-run for script updates
    export OPENBLAS_NUM_THREADS=1
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1

    Rscript ${projectDir}/bin/methylkit_analysis.R \\
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
        ${bed_param} \\
        --min_per_group ${min_per_group} \\
        $args >> methylkit_log.txt 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-methylkit: \$(Rscript -e "library(methylKit); cat(as.character(packageVersion('methylKit')))" | xargs)
        r-genomation: \$(Rscript -e "library(genomation); cat(as.character(packageVersion('genomation')))" | xargs)
        r-org.hs.eg.db: \$(Rscript -e "library(org.Hs.eg.db); cat(as.character(packageVersion('org.Hs.eg.db')))" | xargs)
    END_VERSIONS
    """
}