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
include { CONVERSION_QC } from './modules/conversion_qc'
include { PICARD_COLLECTHSMETRICS } from './modules/picard'
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
        log.info """
        ========================================================================================
                      milou: Methylation Integrated Layer for Omics Unification
        ========================================================================================
        ${helpMessage}
        """.stripIndent()
        exit 0
    }

    // Validate parameters using nf-validation
    // validateParameters()
}

validate_input_parameters()

// Print pipeline info
log.info """
           _ _               
 _ __ ___ (_) | ___  _   _ 
| '_ ` _ \\| | |/ _ \\| | | |
| | | | | | | | (_) | |_| |
|_| |_| |_|_|_|\\___/ \\__,_|

milou: Methylation Integrated Layer for Omics Unification
================================================================================
╔══════════════════════════════════════════════════════════════════════════════╗
║                          milou Nextflow Pipeline                             ║
║                     Version ${workflow.manifest.version}                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  📋 Pipeline Information:                                                    ║
║  • Methylation Integrated Layer for Omics Unification                        ║
║  • Versatile handling of Bisulfite-seq, EM-seq, & Targeted Twist Panel       ║
║  • High-performance CPU (Bismark) & GPU (NVIDIA Parabricks) tracks           ║
║  • Multi-method consensus (DSS, methylKit, edgeR)                            ║
║  • Automated regional annotation & DOSE/GO/KEGG path enrichment              ║
║  • Unified clinical-grade HTML/PDF report rendering                          ║
║                                                                              ║
║  • Developer: Jyotirmoy Das                                                  ║
║  • Email: jyotirmoy.das@liu.se                                               ║
║  • Institution: Linköping University                                         ║
║                                                                              ║
║  📚 Citation (Please cite if used):                                          ║
║  Das, J. milou: Methylation Integrated Layer for Omics Unification.          ║
║  Zenodo DOI: https://doi.org/10.5281/zenodo.14204260                         ║
║                                                                              ║
║  🔗 Additional Resources:                                                    ║
║  • GitHub Repository: https://github.com/JD2112/milou                        ║
║  • License: MIT                                                              ║
║  • Documentation: https://jd2112.github.io/milou/                            ║
║                                                                              ║
║  ⚠️  Important Notes:                                                        ║
║  • This pipeline is for RESEARCH USE ONLY                                    ║
║  • Not validated for clinical diagnostic use                                 ║
║  • Results should be interpreted by qualified professionals                  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

================================================================================
    Execution Profile       : ${workflow.profile}
    Operating Mode          : ${params.mode}
    Sample Sheet            : ${params.sample_sheet}
    Output Directory        : ${params.outdir}

    [Reference & Environment]
    Genome Fasta            : ${params.genome_fasta}
    Pre-stage Test Data     : ${params.pre_stage_test_data}

    [Alignment Strategy]
    Primary Aligner         : ${params.aligner}
    GPU Acceleration        : ${params.use_parabricks}

    [DMR & Clinical Setup]
    Compare String          : ${params.compare_str}
    Coverage Threshold      : ${params.coverage_threshold}x
    DMR Method              : ${params.diff_meth_method}
    Skip Diff Meth          : ${params.skip_diff_meth}

    [Consensus Thresholds]
    MethylKit (Diff / Q)    : ${params.methylkit.diff} / ${params.methylkit.qvalue}
    DSS (Diff / P)          : ${params.dss.diff_threshold} / ${params.dss.p_threshold}
    EdgeR (LogFC / P)       : ${params.edger.logfc_cutoff} / ${params.edger.p_threshold}
    Top N Genes Exported    : ${params.top_n_genes}
    ================================================================================
    """

/**
 ********************************** milou Nextflow ******************************************
 * 1 - Base calling, alignment and data preparation
 *  a. Raw QC : FastQC
 *  b. Adapter trimming : TrimGalore
 *  c. Alignment : Bismark (CPU) or BWA-meth (GPU Track with Clara Parabricks fq2bam_meth)
 *  d. Deduplication and Indexing : Bismark deduplicate (CPU) or Parabricks internal (GPU)
 * 2 - Methylation Extraction
 *  a. Bismark Methylation Extractor (CPU) or MethylDackel (GPU)
 *  b. Samtools Index and Faidx
 * 3 - Alignment Quality Control
 *  a. Qualimap BamQC & MultiQC Report Generation
 * 4 - Differential Methylation Engine
 *  a. EdgeR analysis
 *  b. MethylKit analysis
 *  c. DSS analysis
 * 5 - Consensus & Enrichment Analysis
 *  a. Unified consensus layer (DSS + methylKit + edgeR intersections)
 *  b. Regional annotation (Promoter, Enhancer, Intergenic mapping)
 *  c. DOSE disease ontology, GO, and KEGG pathway enrichment analysis
 *  d. Pathview visualization
 * 6 - Report Rendering
 *  a. Quarto-based PDF & HTML clinical-grade reports
 *******************************************************************************************
*/


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
    ch_bams_for_picard = Channel.empty()

    // Input channels
    if (params.pre_stage_test_data) {
        PRE_STAGE()
        ch_staging_done = PRE_STAGE.out.done
    } else {
        ch_staging_done = Channel.value(true)
    }

    // Secure Translation Index setup (PHI Boundaries)
    def phi_index_file = file("${params.outdir}/.secure_phi_index.tsv")
    if (!phi_index_file.exists()) {
        phi_index_file.parent.mkdirs()
        phi_index_file.text = "Original_ID\tPseudo_ID\n"
    }
    
    def phi_mapping = new java.util.concurrent.ConcurrentHashMap()
    if (phi_index_file.exists()) {
        phi_index_file.splitCsv(header:true, sep:'\t').each { row ->
            phi_mapping[row.Original_ID] = row.Pseudo_ID
        }
    }
    def sample_counter = new java.util.concurrent.atomic.AtomicInteger(phi_mapping.size() + 1)

    if (params.aligned_bams) {
        log.info "Starting from aligned BAM files: ${params.aligned_bams}"
        // Gate the BAM channel with the staging channel
        ch_aligned_bams = Channel.fromPath(params.aligned_bams)
            .combine(ch_staging_done)
            .map { file, done -> 
                def original_id = file.simpleName
                def id = original_id
                
                // PHI Intercept: Strip Swedish Personnummer (YYYYMMDD-XXXX or YYMMDD-XXXX)
                if (original_id ==~ /.*\d{6,8}-\d{4}.*/) {
                    if (phi_mapping.containsKey(original_id)) {
                        id = phi_mapping[original_id]
                    } else {
                        def new_count = sample_counter.getAndIncrement()
                        id = "MILOU-SPEC-" + String.format("%03d", new_count)
                        phi_mapping[original_id] = id
                        phi_index_file.append("${original_id}\t${id}\n")
                        log.warn "🔒 PHI DETECTED: Anonymizing sample ID to ${id}. Translation index saved to .secure_phi_index.tsv"
                    }
                }
                def meta = [ id: id, single_end: false, assay_type: params.assay_type ] // Assume PE for BAMs
                return [meta, file]
            }
        
        ALIGNED_BAM_WORKFLOW(ch_aligned_bams)
        ch_coverage_files = ALIGNED_BAM_WORKFLOW.out.coverage_files
        ch_methylation_reports = ALIGNED_BAM_WORKFLOW.out.methylation_reports
        ch_dedup_reports = ALIGNED_BAM_WORKFLOW.out.dedup_reports
        ch_summary_report = ALIGNED_BAM_WORKFLOW.out.bismark_reports
        ch_qualimap_results = ALIGNED_BAM_WORKFLOW.out.qualimap_results
        ch_bams_for_picard = ALIGNED_BAM_WORKFLOW.out.sorted_bam.join(ALIGNED_BAM_WORKFLOW.out.bam_index)
        ch_versions = ch_versions.mix(ALIGNED_BAM_WORKFLOW.out.versions)

    } else if (params.sample_sheet) {
        log.info "Creating sample channel from: ${params.sample_sheet}"
        
        // Ensure paths are resolved AFTER staging is complete
        ch_samples = ch_staging_done.flatMap { done ->
            def rows = []
            file(params.sample_sheet).splitCsv(header:true).each { row ->
                def original_id = row.sample_id ?: row.sample
                def id = original_id
                
                // PHI Intercept: Strip Swedish Personnummer (YYYYMMDD-XXXX or YYMMDD-XXXX)
                if (original_id ==~ /.*\d{6,8}-\d{4}.*/) {
                    if (phi_mapping.containsKey(original_id)) {
                        id = phi_mapping[original_id]
                    } else {
                        def new_count = sample_counter.getAndIncrement()
                        id = "MILOU-SPEC-" + String.format("%03d", new_count)
                        phi_mapping[original_id] = id
                        phi_index_file.append("${original_id}\t${id}\n")
                        log.warn "🔒 PHI DETECTED: Anonymizing sample ID to ${id}. Translation index saved to .secure_phi_index.tsv"
                    }
                }
                def read1 = row.read1 ?: row.fastq_1
                def read2 = row.read2 ?: row.fastq_2
                
                // Handle remote URLs vs local paths
                def r1_path = read1
                def r2_path = read2
                
                def is_remote_r1 = read1.startsWith('http') || read1.startsWith('ftp') || read1.startsWith('s3://') || read1.startsWith('gs://') || read1.startsWith('az://')
                
                // If auto-staging is on, reroute URLs to the local test_data folder 
                if (params.pre_stage_test_data && (read1.startsWith('http') || read1.startsWith('ftp'))) {
                    r1_path = "${projectDir}/data/test_data/" + file(read1).name
                } else if (!is_remote_r1) {
                    r1_path = "${projectDir}/${read1}"
                }
                
                def is_remote_r2 = read2 ? (read2.startsWith('http') || read2.startsWith('ftp') || read2.startsWith('s3://') || read2.startsWith('gs://') || read2.startsWith('az://')) : false
                
                if (read2 && params.pre_stage_test_data && (read2.startsWith('http') || read2.startsWith('ftp'))) {
                    r2_path = "${projectDir}/data/test_data/" + file(read2).name
                } else if (read2 && !is_remote_r2) {
                    r2_path = "${projectDir}/${read2}"
                }
                
                def r1 = file(r1_path)
                def r2 = r2_path ? file(r2_path) : null
                
                def row_assay = row.assay_type ?: params.assay_type
                def meta = [ id: id, single_end: r2 ? false : true, assay_type: row_assay ]
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

        // Process validation results and filter zombies
        READ_PROCESSING.out.trimmed_reads
            .join(READ_PROCESSING.out.sync_status)
            .map { meta, reads, status_file ->
                def status = status_file.text.trim()
                [ meta + [ status: status ], reads ]
            }
            .branch { meta, reads ->
                zombie: meta.status.startsWith('zombie')
                passed: true
            }
            .set { ch_validated_reads }

        // Report excluded zombies
        def total_input_samples = 0
        ch_samples.count().subscribe { total_input_samples = it }

        ch_validated_reads.zombie
            .map { meta, reads -> meta.id }
            .collect()
            .subscribe { ids ->
                if (ids) {
                    log.warn "=========================================================================="
                    log.warn "ZOMBIE SAMPLES DETECTED: ${ids.join(', ')}"
                    log.warn "These samples have mismatched/truncated reads and were EXCLUDED."
                    log.warn "Proceeding with remaining healthy samples."
                    log.warn "=========================================================================="
                }
            }

        // Alignment & Methylation Calling Track (Compile-time selection)
        if (params.use_parabricks) {
            log.info "Executing PARABRICKS_ANALYSIS (GPU Track)..."
            ch_genome_pb = ch_staging_done.map { done -> params.genome_fasta ? file(params.genome_fasta) : null }
            
            PARABRICKS_ANALYSIS(ch_validated_reads.passed, ch_genome_pb)
            ch_raw_coverage_files = PARABRICKS_ANALYSIS.out.coverage_files
            ch_qualimap_results = PARABRICKS_ANALYSIS.out.qualimap_results
            ch_bams_for_picard = PARABRICKS_ANALYSIS.out.bam.join(PARABRICKS_ANALYSIS.out.bai)
            ch_versions = ch_versions.mix(PARABRICKS_ANALYSIS.out.versions)
            
            // Empty channel initializers to avoid unbound errors in QC reporting
            ch_align_reports = Channel.empty()
            ch_dedup_reports = Channel.empty()
            ch_methylation_reports = Channel.empty()
            ch_summary_report = Channel.empty()
        } else {
            log.info "Executing BISMARK_ANALYSIS (CPU Track)..."
            
            BISMARK_ANALYSIS(ch_validated_reads.passed, ch_index.collect())
            ch_raw_coverage_files = BISMARK_ANALYSIS.out.coverage_files
            ch_qualimap_results = BISMARK_ANALYSIS.out.qualimap_results
            ch_align_reports = BISMARK_ANALYSIS.out.align_reports
            ch_dedup_reports = BISMARK_ANALYSIS.out.dedup_reports
            ch_methylation_reports = BISMARK_ANALYSIS.out.methylation_reports
            ch_summary_report = BISMARK_ANALYSIS.out.summary_report
            ch_bams_for_picard = BISMARK_ANALYSIS.out.sorted_bam.join(BISMARK_ANALYSIS.out.bam_index)
            ch_versions = ch_versions.mix(BISMARK_ANALYSIS.out.versions)
        }
        
        // 2.2 Conversion QC Guardrail
        CONVERSION_QC(ch_raw_coverage_files)
        ch_versions = ch_versions.mix(CONVERSION_QC.out.versions)

        ch_raw_coverage_files
            .join(CONVERSION_QC.out.status)
            .branch { meta, cov, status_file ->
                failed: status_file.text.trim().startsWith('failed')
                passed: true
            }
            .set { ch_validated_coverage }

        ch_validated_coverage.failed
            .map { meta, cov, status_file -> "${meta.id} (${status_file.text.trim()})" }
            .collect()
            .subscribe { failures ->
                if (failures) {
                    log.error "=========================================================================="
                    log.error "DIAGNOSTIC ANALYSIS FAILED: QUALITY THRESHOLDS NOT MET"
                    log.error "The following samples failed wet-lab bisulfite/enzymatic conversion:"
                    failures.each { log.error "  - ${it}" }
                    log.error "These samples have been EXCLUDED from downstream clinical reporting."
                    log.error "=========================================================================="
                }
            }

        ch_coverage_files = ch_validated_coverage.passed.map { meta, cov, status -> [meta, cov] }

    } else {
        error "Either sample_sheet or aligned_bams must be provided"
    }

    // 2.3 Twist Targeted Capture Metrics (Picard)
    def target_bed = params.methylkit.bed_file ? file(params.methylkit.bed_file) : file("NO_BED")
    def fasta_file = params.genome_fasta ? file(params.genome_fasta) : file("NO_FASTA")
    if (params.genome_fasta) {
        PICARD_COLLECTHSMETRICS(ch_bams_for_picard, fasta_file, target_bed)
        ch_qualimap_results = ch_qualimap_results.mix(PICARD_COLLECTHSMETRICS.out.metrics)
        ch_versions = ch_versions.mix(PICARD_COLLECTHSMETRICS.out.versions)
    }

    // Common analysis steps
    ch_refseq = params.refseq_file ? Channel.fromPath(params.refseq_file).collect() : Channel.value([])
    ch_gtf = params.gtf_file ? Channel.fromPath(params.gtf_file).collect() : Channel.value([])
    ch_disgenet = params.disgenet_db ? Channel.fromPath(params.disgenet_db).collect() : Channel.value(file("NO_FILE"))

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
            params.methylkit.assembly ?: 'hg38',
            ch_disgenet
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
            file("${projectDir}/assets/milou_logo.png"),
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