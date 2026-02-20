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

// Show help message
if (params.help) {
    def helpMessage = file("$projectDir/conf/USAGE.md").text
    log.info"""
    ===========================================================================
                  Twist DNA Methylation Data Analysis Pipeline
    ===========================================================================
    ${helpMessage}
    """.stripIndent()
    exit 0
}

// Print pipeline info
log.info """
===============================================================================
▗▄▄▄▖▗▖ ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▖  ▗▖▗▄▄▄▖▗▄▄▄▖▗▖ ▗▖▗▖  ▗▖▗▖   ▗▄▄▄▖▗▖    ▗▄▖ ▗▖ ▗▖
  █  ▐▌ ▐▌  █  ▐▌     █  ▐▛▚▞▜▌▐▌     █  ▐▌ ▐▌ ▝▚▞▘ ▐▌   ▐▌   ▐▌   ▐▌ ▐▌▐▌ ▐▌
  █  ▐▌ ▐▌  █   ▝▀▚▖  █  ▐▌  ▐▌▐▛▀▀▘  █  ▐▛▀▜▌  ▐▌  ▐▌   ▐▛▀▀▘▐▌   ▐▌ ▐▌▐▌ ▐▌
  █  ▐▙█▟▌▗▄█▄▖▗▄▄▞▘  █  ▐▌  ▐▌▐▙▄▄▖  █  ▐▌ ▐▌  ▐▌  ▐▙▄▄▖▐▌   ▐▙▄▄▖▝▚▄▞▘▐▙█▟▌

Twist NGS DNA Methylation Data Analysis Pipeline
================================================================================
sample sheet : ${params.sample_sheet}
genome       : ${params.genome_fasta}
bismark index: ${params.bismark_index}
aligned bams : ${params.aligned_bams}
outdir       : ${params.outdir}
diff method  : ${params.diff_meth_method}
run both     : ${params.run_both_methods}
skip diff    : ${params.skip_diff_meth}
methylkit assembly: ${params.methylkit.assembly}
methylkit mc_cores: ${params.methylkit.mc_cores}
methylkit diff   : ${params.methylkit.diff}
methylkit qvalue : ${params.methylkit.qvalue}
"""

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
    // Input channels
    if (params.aligned_bams) {
        log.info "Starting from aligned BAM files: ${params.aligned_bams}"
        ch_aligned_bams = Channel.fromPath(params.aligned_bams)
        ALIGNED_BAM_WORKFLOW(ch_aligned_bams)
        ch_coverage_files = ALIGNED_BAM_WORKFLOW.out.coverage_files
        ch_qc_reports = ALIGNED_BAM_WORKFLOW.out.qc_reports
    } else if (params.sample_sheet) {
        log.info "Creating sample channel from: ${params.sample_sheet}"
        ch_samples = create_sample_channel(params.sample_sheet)

        // Genome preparation
        ch_index = Channel.empty()
        if (!params.use_parabricks) {
            if (!params.bismark_index) {
                ch_genome = Channel.fromPath(params.genome_fasta, checkIfExists: true)
                PREPARE_GENOME(ch_genome)
                ch_index = PREPARE_GENOME.out.index
            } else {
                ch_index = Channel.fromPath(params.bismark_index, checkIfExists: true)
            }
        }

        // Read processing
        READ_PROCESSING(ch_samples)

        if (params.use_parabricks) {
            // Parabricks analysis (GPU)
            ch_fasta = Channel.fromPath(params.genome_fasta, checkIfExists: true).collect()
            PARABRICKS_ANALYSIS(READ_PROCESSING.out.trimmed_reads, ch_fasta)
            ch_coverage_files = PARABRICKS_ANALYSIS.out.coverage_files
            
            // QC Reporting for Parabricks
            ch_qc_reports = QC_REPORTING(
                READ_PROCESSING.out.fastqc_reports,
                READ_PROCESSING.out.trimming_reports,
                Channel.empty(), // align_reports
                Channel.empty(), // dedup_reports
                Channel.empty(), // methylation_reports
                Channel.empty(), // summary_report
                Channel.empty()  // qualimap_results
            )
        } else {
            // Bismark analysis (CPU)
            BISMARK_ANALYSIS(READ_PROCESSING.out.trimmed_reads, ch_index.collect())
            ch_coverage_files = BISMARK_ANALYSIS.out.coverage_files
            
            ch_qc_reports = QC_REPORTING(
                READ_PROCESSING.out.fastqc_reports,
                READ_PROCESSING.out.trimming_reports,
                BISMARK_ANALYSIS.out.align_reports,
                BISMARK_ANALYSIS.out.dedup_reports,
                BISMARK_ANALYSIS.out.methylation_reports,
                BISMARK_ANALYSIS.out.summary_report,
                BISMARK_ANALYSIS.out.qualimap_results
            )
        }
    } else {
        error "Either sample_sheet or aligned_bams must be provided"
    }

    // Create a channel for the RefSeq file
    ch_refseq = params.refseq_file ? Channel.fromPath(params.refseq_file).collect() : Channel.value(null)

    // Create a channel for the GTF file
    ch_gtf = params.gtf_file ? Channel.fromPath(params.gtf_file).collect() : Channel.value('NO_FILE')

    if (!params.skip_diff_meth) {
        // Differential Methylation Analysis
        DIFFERENTIAL_METHYLATION(
            ch_coverage_files,
            file(params.sample_sheet),
            params.compare_str,
            params.coverage_threshold,
            params.run_both_methods ? 'both' : params.diff_meth_method,
            ch_refseq,
            params.methylkit.assembly,
            params.methylkit.mc_cores,
            params.methylkit.diff,
            params.methylkit.qvalue
        )

        ch_diff_meth_results = Channel.empty()
        DIFFERENTIAL_METHYLATION.out.edger_results
            .flatten()
            .map { file -> ['edger', file] }
            .set { ch_edger_results }
        DIFFERENTIAL_METHYLATION.out.methylkit_results
            .flatten()
            .map { file -> ['methylkit', file] }
            .set { ch_methylkit_results }
        ch_diff_meth_results = ch_edger_results.mix(ch_methylkit_results)

        ch_diff_meth_results.view { method, file -> "SUBMITTING TO ANALYSIS: [${method}] ${file}" }

        // Result Analysis
        //log.info "Differential methylation results channel: ${ch_diff_meth_results.dump()}"
        //log.info "Starting RESULT_ANALYSIS with method: ${params.run_both_methods ? 'both' : params.diff_meth_method}"

        if (params.run_both_methods) {
            log.info "Running RESULT_ANALYSIS for both methods"
            results = RESULT_ANALYSIS(
                ch_diff_meth_results,
                params.compare_str,
                params.logfc_cutoff,
                params.pvalue_cutoff,
                params.hyper_color,
                params.hypo_color,
                params.nonsig_color,
                ch_gtf,
                'both',
                params.top_n_genes
            )
        } else {
            log.info "Running RESULT_ANALYSIS for ${params.diff_meth_method}"
            results = RESULT_ANALYSIS(
                ch_diff_meth_results.filter { it[0] == params.diff_meth_method },
                params.compare_str,
                params.logfc_cutoff,
                params.pvalue_cutoff,
                params.hyper_color,
                params.hypo_color,
                params.nonsig_color,
                ch_gtf,
                params.diff_meth_method,
                params.top_n_genes
            )
        }
    } else {
        log.info "Skipping Differential Methylation Analysis and Result Analysis as requested"
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