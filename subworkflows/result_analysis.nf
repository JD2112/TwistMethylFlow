include { ANNOTATE_RESULTS as ANNOTATE_RESULTS_EDGER } from '../modules/annotate_results'
include { ANNOTATE_RESULTS as ANNOTATE_RESULTS_DSS } from '../modules/annotate_results'
include { POST_PROCESSING as POST_PROCESSING_EDGER } from '../modules/post_processing'
include { POST_PROCESSING as POST_PROCESSING_METHYLKIT } from '../modules/post_processing'
include { POST_PROCESSING as POST_PROCESSING_DSS } from '../modules/post_processing'
include { ENRICHMENT_ANALYSIS as ENRICHMENT_ANALYSIS_EDGER } from '../modules/enrichment_analysis'
include { ENRICHMENT_ANALYSIS as ENRICHMENT_ANALYSIS_METHYLKIT } from '../modules/enrichment_analysis'
include { ENRICHMENT_ANALYSIS as ENRICHMENT_ANALYSIS_DSS } from '../modules/enrichment_analysis'

workflow RESULT_ANALYSIS {
    take:
    diff_meth_results // Channel: [ val(method), path(results) ]
    compare_str
    logfc_cutoff
    pvalue_cutoff
    hyper_color
    hypo_color
    nonsig_color
    gtf_file
    method // String: 'edger', 'methylkit', or 'both'
    top_n_genes

    main:
    ch_versions = Channel.empty()
    
    def methods = method.split(',').collect { it.trim().toLowerCase() }

    // Initialize outputs for all possible methods
    ch_edger_summary = Channel.empty()
    ch_methylkit_summary = Channel.empty()
    ch_dss_summary = Channel.empty()
    
    ch_edger_annotated = Channel.empty()
    ch_methylkit_raw = Channel.empty()
    ch_dss_annotated = Channel.empty()
    
    ch_edger_go = Channel.empty()
    ch_methylkit_go = Channel.empty()
    ch_dss_go = Channel.empty()
    
    ch_edger_kegg = Channel.empty()
    ch_methylkit_kegg = Channel.empty()
    ch_dss_kegg = Channel.empty()

    // Flatten any grouped results (if they came in as a list or directory) 
    // and process each comparison file individually
    ch_inputs = diff_meth_results.flatMap { m, res ->
        if (res instanceof List) {
            return res.collect { [m, it] }
        } else if (res instanceof Path && res.isDirectory()) {
            def files = res.toFile().listFiles()?.findAll { it.name.toLowerCase().endsWith('.csv') } ?: []
            return files.collect { [m, file(it)] }
        } else {
            return [[m, res]]
        }
    }

    // --- EdgeR Branch ---
    if (methods.contains('edger') || methods.contains('all')) {
        ch_edger_results = ch_inputs.filter { it[0] == 'edger' }

        // Run annotation for EdgeR results
        ch_annotated_edger = ANNOTATE_RESULTS_EDGER(ch_edger_results, gtf_file)

        // Post-processing (Volcano, MA plots)
        POST_PROCESSING_EDGER(
            ch_annotated_edger.annotated_results,
            compare_str,
            logfc_cutoff,
            pvalue_cutoff,
            hyper_color,
            hypo_color,
            nonsig_color
        )

        // Enrichment Analysis
        ENRICHMENT_ANALYSIS_EDGER(
            ch_annotated_edger.annotated_results,
            logfc_cutoff,
            pvalue_cutoff,
            top_n_genes
        )

        ch_versions = ch_versions.mix(
            ANNOTATE_RESULTS_EDGER.out.versions,
            POST_PROCESSING_EDGER.out.versions,
            ENRICHMENT_ANALYSIS_EDGER.out.versions
        )

        ch_edger_summary = POST_PROCESSING_EDGER.out.summary
        ch_edger_annotated = ANNOTATE_RESULTS_EDGER.out.annotated_results
        ch_edger_go = ENRICHMENT_ANALYSIS_EDGER.out.results.map{ it[1] }
        ch_edger_kegg = ENRICHMENT_ANALYSIS_EDGER.out.kegg_results.map{ it[1] }
    }

    // --- MethylKit Branch ---
    if (methods.contains('methylkit') || methods.contains('all')) {
        ch_methylkit_results = ch_inputs.filter { it[0] == 'methylkit' }

        // Note: Currently passing raw MethylKit results directly to post-processing
        POST_PROCESSING_METHYLKIT(
            ch_methylkit_results,
            compare_str,
            logfc_cutoff,
            pvalue_cutoff,
            hyper_color,
            hypo_color,
            nonsig_color
        )

        ENRICHMENT_ANALYSIS_METHYLKIT(
            ch_methylkit_results,
            logfc_cutoff,
            pvalue_cutoff,
            top_n_genes
        )

        ch_versions = ch_versions.mix(
            POST_PROCESSING_METHYLKIT.out.versions,
            ENRICHMENT_ANALYSIS_METHYLKIT.out.versions
        )

        ch_methylkit_summary = POST_PROCESSING_METHYLKIT.out.summary
        ch_methylkit_raw = ch_methylkit_results
        ch_methylkit_go = ENRICHMENT_ANALYSIS_METHYLKIT.out.results.map{ it[1] }
        ch_methylkit_kegg = ENRICHMENT_ANALYSIS_METHYLKIT.out.kegg_results.map{ it[1] }
    }

    // --- DSS Branch ---
    if (methods.contains('dss') || methods.contains('all')) {
        ch_dss_results = ch_inputs.filter { it[0] == 'dss' && it[1].name.endsWith('_sig.csv') }

        // Run annotation for DSS results
        ch_annotated_dss = ANNOTATE_RESULTS_DSS(ch_dss_results, gtf_file)

        POST_PROCESSING_DSS(
            ch_annotated_dss.annotated_results,
            compare_str,
            logfc_cutoff,
            pvalue_cutoff,
            hyper_color,
            hypo_color,
            nonsig_color
        )

        ENRICHMENT_ANALYSIS_DSS(
            ch_annotated_dss.annotated_results,
            logfc_cutoff,
            pvalue_cutoff,
            top_n_genes
        )

        ch_versions = ch_versions.mix(
            ANNOTATE_RESULTS_DSS.out.versions,
            POST_PROCESSING_DSS.out.versions,
            ENRICHMENT_ANALYSIS_DSS.out.versions
        )

        ch_dss_summary = POST_PROCESSING_DSS.out.summary
        ch_dss_annotated = ANNOTATE_RESULTS_DSS.out.annotated_results
    }

    emit:
    versions = ch_versions
    
    edger_summary = ch_edger_summary
    methylkit_summary = ch_methylkit_summary
    dss_summary = ch_dss_summary

    // Annotated results to be passed to clinical reporting
    // NOTE: MethylKit results are included as raw (un-annotated) since
    // MethylKit performs its own internal annotation during DML/DMR calling.
    annotated_results = Channel.empty().mix(
        ch_edger_annotated,
        ch_methylkit_raw,
        ch_dss_annotated
    )
}
