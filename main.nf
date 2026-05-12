#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import subworkflows
include { PREPARE_GENOME } from './subworkflows/prepare_genome'
include { READ_PROCESSING } from './subworkflows/read_processing'
include { BISMARK_ANALYSIS } from './subworkflows/bismark_analysis'
include { QC_REPORTING } from './subworkflows/qc_reporting'
include { DIFFERENTIAL_METHYLATION } from './subworkflows/differential_methylation'
include { RESULT_ANALYSIS } from './subworkflows/result_analysis'
include { ALIGNED_BAM_WORKFLOW } from './subworkflows/aligned_bam_workflow'
include { PARABRICKS_ANALYSIS } from './subworkflows/parabricks_analysis'
include { PRE_STAGE } from './modules/pre_stage'
include { UNIFIED_LAYER } from './modules/unified_layer'
include { REPORT } from './modules/report'
include { CLINICAL_REPORTING } from './subworkflows/clinical_reporting'
include { validateParameters; paramsHelp } from 'plugin/nf-validation'

def validate_input_parameters() {
    // Validate mutually exclusive profiles based on parameters
    if (params.mode != 'clinical' && params.mode != 'research') {
        error "Invalid mode: ${params.mode}. Please use -profile clinical or -profile research."
    }

    def valid_dmr_methods = ['edger', 'methylkit', 'dss', 'all']
    def user_dmr_methods = params.diff_meth_method ? params.diff_meth_method.split(',').collect { it.trim().toLowerCase() } : []
    user_dmr_methods.each { m ->
        if (!valid_dmr_methods.contains(m)) {
            error "Invalid DMR method: ${m}. Valid options are: edger, methylkit, dss, all."
        }
    }

    // Show help message
    if (params.help) {
        def helpMessage = file("$projectDir/conf/USAGE.md").text
        log.info"""
        ===========================================================================
                      MethylFlow DNA Methylation Data Analysis Pipeline
        ===========================================================================
        ${helpMessage}
        """.stripIndent()
        exit 0
    }

    // Validate parameters using nf-validation
    validateParameters()

    // Print pipeline info
    log.info """
    ===============================================================================
    ▗▄▄▄▖▗▖ ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▖  ▗▖▗▄▄▄▖▗▄▄▄▖▗▖ ▗▖▗▖  ▗▖▗▖   ▗▄▄▄▖▗▖    ▗▄▖ ▗▖ ▗▖
      █  ▐▌ ▐▌  █  ▐▌     █  ▐▛▚▞▜▌▐▌     █  ▐▌ ▐▌ ▝▚▞▘ ▐▌   ▐▌   ▐▌   ▐▌ ▐▌▐▌ ▐▌
      █  ▐▌ ▐▌  █   ▝▀▚▖  █  ▐▌  ▐▌▐▛▀▀▘  █  ▐▛▀▜▌  ▐▌  ▐▌   ▐▛▀▀▘▐▌   ▐▌ ▐▌▐▌ ▐▌
      █  ▐▙█▟▌▗▄█▄▖▗▄▄▞▘  █  ▐▌  ▐▌▐▙▄▄▖  █  ▐▌ ▐▌  ▐▌  ▐▙▄▄▖▐▌   ▐▙▄▄▖▝▚▄▞▘▐▙█▟▌

    MethylFlow DNA Methylation Data Analysis Pipeline
    ================================================================================
    Execution Profile       : \${workflow.profile}
    Operating Mode          : \${params.mode}
    Sample Sheet            : \${params.sample_sheet}
    Output Directory        : \${params.outdir}

    [Reference & Environment]
    Genome Fasta            : \${params.genome_fasta}
    Pre-stage Test Data     : \${params.pre_stage_test_data}

    [Alignment Strategy]
    Primary Aligner         : \${params.aligner}
    GPU Acceleration        : \${params.use_parabricks}

    [DMR & Clinical Setup]
    Compare String          : \${params.compare_str}
    Coverage Threshold      : \${params.coverage_threshold}x
    DMR Method              : \${params.diff_meth_method}
    Skip Diff Meth          : \${params.skip_diff_meth}

    [Consensus Thresholds]
    MethylKit (Diff / Q)    : \${params.methylkit.diff} / \${params.methylkit.qvalue}
    DSS (Diff / P)          : \${params.dss.diff_threshold} / \${params.dss.p_threshold}
    EdgeR (LogFC / P)       : \${params.edger.logfc_cutoff} / \${params.edger.p_threshold}
    Top N Genes Exported    : \${params.top_n_genes}
    ================================================================================
    """
}


def create_sample_channel(sample_sheet) {
    return Channel
        .fromPath(sample_sheet)
        .splitCsv(header:true)
        .map { row -> 
            def id = row.sample_id ?: row.sample
            def read1 = row.read1 ?: row.fastq_1
            def read2 = row.read2 ?: row.fastq_2
            def meta = [
                id: id, 
                single_end: read2 ? false : true
            ]
            def reads = meta.single_end ? [file(read1)] : [file(read1), file(read2)]
            return [meta, reads]
        }
}

// Main workflow
workflow {
    validate_input_parameters()
    // Initialize report channels
    ch_versions = Channel.empty()
    ch_fastqc_reports = Channel.empty()
    ch_trimming_reports = Channel.empty()
    ch_align_reports = Channel.empty()
    ch_dedup_reports = Channel.empty()
    ch_methylation_reports = Channel.empty()
    ch_summary_report = Channel.empty()
    ch_qualimap_results = Channel.empty()

    // Input channels
    if (params.pre_stage_test_data) {
        PRE_STAGE()
        ch_staging_done = PRE_STAGE.out.done
    } else {
        ch_staging_done = Channel.value(true)
    }

    if (params.aligned_bams) {
        log.info "Starting from aligned BAM files: ${params.aligned_bams}"
        // Gate the BAM channel with the staging channel
        ch_aligned_bams = Channel.fromPath(params.aligned_bams)
            .combine(ch_staging_done)
            .map { file, done -> file }
        
        ALIGNED_BAM_WORKFLOW(ch_aligned_bams)
        ch_coverage_files = ALIGNED_BAM_WORKFLOW.out.coverage_files
        ch_methylation_reports = ALIGNED_BAM_WORKFLOW.out.methylation_reports
        ch_dedup_reports = ALIGNED_BAM_WORKFLOW.out.dedup_reports
        ch_summary_report = ALIGNED_BAM_WORKFLOW.out.bismark_reports
        ch_qualimap_results = ALIGNED_BAM_WORKFLOW.out.qualimap_results
        ch_versions = ch_versions.mix(ALIGNED_BAM_WORKFLOW.out.versions)

    } else if (params.sample_sheet) {
        log.info "Creating sample channel from: ${params.sample_sheet}"
        
        // Ensure paths are resolved AFTER staging is complete
        ch_samples = ch_staging_done.flatMap { done ->
            def rows = []
            file(params.sample_sheet).splitCsv(header:true).each { row ->
                def id = row.sample_id ?: row.sample
                def read1 = row.read1 ?: row.fastq_1
                def read2 = row.read2 ?: row.fastq_2
                def hardware = row.hardware ?: (params.use_parabricks ? 'gpu' : 'cpu')
                
                // Log hardware assignment for visibility
                log.info "Sample [${id}] assigned to [${hardware.toUpperCase()}] track"
                
                // Handle remote URLs vs local paths
                def r1_path = read1
                def r2_path = read2
                
                // If auto-staging is on, reroute URLs to the local test_data folder 
                if (params.pre_stage_test_data && (read1.startsWith('http') || read1.startsWith('ftp'))) {
                    r1_path = "${projectDir}/data/test_data/" + file(read1).name
                } else if (!read1.startsWith('http') && !read1.startsWith('ftp')) {
                    r1_path = "${projectDir}/${read1}"
                }
                
                if (read2 && params.pre_stage_test_data && (read2.startsWith('http') || read2.startsWith('ftp'))) {
                    r2_path = "${projectDir}/data/test_data/" + file(read2).name
                } else if (read2 && !read2.startsWith('http') && !read2.startsWith('ftp')) {
                    r2_path = "${projectDir}/${read2}"
                }
                
                def r1 = file(r1_path)
                def r2 = r2_path ? file(r2_path) : null
                
                def meta = [ id: id, single_end: r2 ? false : true, hardware: hardware ]
                def reads = r2 ? [r1, r2] : [r1]
                rows << [meta, reads]
            }
            return rows
        }

        // Genome preparation
        ch_index = Channel.empty()
        if (!params.use_parabricks) {
            if (!params.bismark_index) {
                ch_genome = ch_staging_done.map { file(params.genome_fasta) }
                PREPARE_GENOME(ch_genome)
                ch_index = PREPARE_GENOME.out.index
                ch_versions = ch_versions.mix(PREPARE_GENOME.out.versions)
            } else {
                ch_index = ch_staging_done.map { file(params.bismark_index) }.first()
            }
        }

        // Read processing
        READ_PROCESSING(ch_samples)
        ch_versions = ch_versions.mix(READ_PROCESSING.out.versions)
        ch_fastqc_reports = READ_PROCESSING.out.fastqc_reports
        ch_trimming_reports = READ_PROCESSING.out.trimming_reports
        ch_checksums = READ_PROCESSING.out.checksums

        // Branching based on hardware
        READ_PROCESSING.out.trimmed_reads
            .branch { meta, reads ->
                gpu: meta.hardware == 'gpu'
                cpu: meta.hardware == 'cpu'
            }
            .set { ch_branched_reads }

        // Parabricks analysis (GPU)
        ch_coverage_files_pb = Channel.empty()
        ch_qualimap_results_pb = Channel.empty()
        
        ch_branched_reads.gpu
            .ifEmpty([])
            .set { ch_gpu_reads }

        ch_genome_pb = ch_staging_done.map { done -> params.genome_fasta ? file(params.genome_fasta) : null }
        
        PARABRICKS_ANALYSIS(ch_gpu_reads, ch_genome_pb)
        ch_coverage_files_pb = PARABRICKS_ANALYSIS.out.coverage_files
        ch_qualimap_results_pb = PARABRICKS_ANALYSIS.out.qualimap_results
        ch_versions = ch_versions.mix(PARABRICKS_ANALYSIS.out.versions)

        // Bismark analysis (CPU)
        ch_branched_reads.cpu
            .ifEmpty([])
            .set { ch_cpu_reads }

        BISMARK_ANALYSIS(ch_cpu_reads, ch_index.collect())
        ch_coverage_files_bis = BISMARK_ANALYSIS.out.coverage_files
        ch_qualimap_results_bis = BISMARK_ANALYSIS.out.qualimap_results
        ch_align_reports = BISMARK_ANALYSIS.out.align_reports
        ch_dedup_reports = BISMARK_ANALYSIS.out.dedup_reports
        ch_methylation_reports = BISMARK_ANALYSIS.out.methylation_reports
        ch_summary_report = BISMARK_ANALYSIS.out.summary_report
        ch_versions = ch_versions.mix(BISMARK_ANALYSIS.out.versions)

        // Combine results from both tracks
        ch_coverage_files = ch_coverage_files_pb.mix(ch_coverage_files_bis)
        ch_qualimap_results = ch_qualimap_results_pb.mix(ch_qualimap_results_bis)
    } else {
        error "Either sample_sheet or aligned_bams must be provided"
    }

    // Common analysis steps
    ch_refseq = params.refseq_file ? Channel.fromPath(params.refseq_file).collect() : Channel.value([])
    ch_gtf = params.gtf_file ? Channel.fromPath(params.gtf_file).collect() : Channel.value([])

    // Channel for clinical reporting results (DMRs, GO, KEGG)
    ch_clinical_results = Channel.empty()

    if (!params.skip_diff_meth) {
        // Differential Methylation Analysis
        DIFFERENTIAL_METHYLATION(
            ch_coverage_files,
            file(params.sample_sheet),
            params.compare_str,
            params.coverage_threshold,
            params.diff_meth_method,
            ch_refseq,
            params.methylkit.assembly,
            params.methylkit.mc_cores,
            params.methylkit.diff,
            params.methylkit.qvalue,
            params.methylkit.bed_file ? file(params.methylkit.bed_file) : [],
            params.dss.p_threshold,
            params.dss.diff_threshold,
            params.edger.p_threshold,
            params.edger.logfc_cutoff,
            params.methylkit.min_per_group
        )
        ch_versions = ch_versions.mix(DIFFERENTIAL_METHYLATION.out.versions)

        DIFFERENTIAL_METHYLATION.out.edger_results
            .flatten()
            .map { file -> ['edger', file] }
            .set { ch_edger_results }
        DIFFERENTIAL_METHYLATION.out.methylkit_results
            .flatten()
            .map { file -> ['methylkit', file] }
            .set { ch_methylkit_results }
        DIFFERENTIAL_METHYLATION.out.dss_results
            .flatten()
            .map { file -> ['dss', file] }
            .set { ch_dss_results }
        ch_diff_meth_results = ch_edger_results.mix(ch_methylkit_results, ch_dss_results)

        ch_diff_meth_results.view { method, file -> "SUBMITTING TO ANALYSIS: [${method}] ${file}" }

        log.info "Submitting to DIFFERENTIAL_METHYLATION with method: ${params.diff_meth_method}"

        // Result Analysis Branch
        log.info "Running RESULT_ANALYSIS..."
        def selected_methods = params.diff_meth_method.split(',').collect { it.trim().toLowerCase() }
        def res_analysis_method = params.diff_meth_method
        def res_analysis_input = ch_diff_meth_results.filter { selected_methods.contains('all') || selected_methods.contains(it[0]) }
        
        analytical_results_map = RESULT_ANALYSIS(
            res_analysis_input,
            params.compare_str,
            params.logfc_cutoff,
            params.pvalue_cutoff,
            params.hyper_color,
            params.hypo_color,
            params.nonsig_color,
            ch_gtf,
            res_analysis_method,
            params.top_n_genes
        )
        ch_versions = ch_versions.mix(analytical_results_map.versions)
        
        // 🧬 Final Clinical Reporting Modules (Enrichment, Disease, Annotation)
        
        CLINICAL_REPORTING(
            analytical_results_map.annotated_results,
            params.logfc_cutoff,
            params.pvalue_cutoff,
            params.kegg_logfc_cutoff,
            params.kegg_pvalue_cutoff,
            params.top_n_genes,
            params.promoter_dist ?: 2000,
            params.enhancer_dist ?: 10000,
            ch_coverage_files,
            Channel.fromPath(params.sample_sheet),
            ch_gtf,
            params.methylkit.assembly ?: 'hg38'
        )
        ch_versions = ch_versions.mix(CLINICAL_REPORTING.out.versions)
        ch_clinical_results = CLINICAL_REPORTING.out.results
    } else {
        log.info "Skipping Differential Methylation Analysis and Result Analysis as requested"
    }

    // Call QC_REPORTING at the end to collect all reports and versions
    QC_REPORTING(
        ch_fastqc_reports ?: Channel.empty(),
        ch_trimming_reports ?: Channel.empty(),
        ch_align_reports ?: Channel.empty(),
        ch_dedup_reports ?: Channel.empty(),
        ch_methylation_reports ?: Channel.empty(),
        ch_summary_report ?: Channel.empty(),
        ch_qualimap_results ?: Channel.empty(),
        ch_versions.unique().collect()
    )

    if (params.run_clinical_report) {
        log.info "Starting Unified Clinical Results Layer..."
        
        UNIFIED_LAYER(
            QC_REPORTING.out.multiqc_data,
            file(params.sample_sheet),
            ch_clinical_results.collect().ifEmpty([]),
            file("${projectDir}/assets/methods_description.yml"),
            file("${projectDir}/assets/citations.bib"),
            ch_checksums.map { it[1] }.collect().ifEmpty([])
        )
        // Note: UNIFIED_LAYER currently doesn't emit versions, and versions are already collected for MultiQC above.


        // Then run Report
        REPORT(
            UNIFIED_LAYER.out.results_dir,
            file("${projectDir}/assets/report.qmd"),
            file("${projectDir}/assets/methylflow_logo.png"),
            file("${projectDir}/assets/citations.bib")
        )
    }

}

// Completion handler
workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${workflow.success ? 'OK' : 'failed'}"
    log.info "Execution duration: $workflow.duration"
}

// Error handler
workflow.onError {
    log.error "Oops... Pipeline execution stopped with the following message: ${workflow.errorMessage}"
}