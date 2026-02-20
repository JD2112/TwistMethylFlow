include { ANNOTATE_RESULTS } from '../modules/annotate_results'
include { POST_PROCESSING as POST_PROCESSING_EDGER } from '../modules/post_processing'
include { POST_PROCESSING as POST_PROCESSING_METHYLKIT } from '../modules/post_processing'
include { GO_ANALYSIS as GO_ANALYSIS_EDGER } from '../modules/go_analysis'
include { GO_ANALYSIS as GO_ANALYSIS_METHYLKIT } from '../modules/go_analysis'

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
    if (method == 'edger' || method == 'both') {
        ch_edger_results = ch_inputs.filter { it[0] == 'edger' }

        // Run annotation for EdgeR results
        ch_annotated_edger = ANNOTATE_RESULTS(ch_edger_results, gtf_file)

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

        // GO Analysis
        GO_ANALYSIS_EDGER(
            ch_annotated_edger.annotated_results,
            logfc_cutoff,
            pvalue_cutoff,
            top_n_genes
        )

        ch_versions = ch_versions.mix(
            ANNOTATE_RESULTS.out.versions,
            POST_PROCESSING_EDGER.out.versions,
            GO_ANALYSIS_EDGER.out.versions
        )
    }

    // --- MethylKit Branch ---
    if (method == 'methylkit' || method == 'both') {
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

        GO_ANALYSIS_METHYLKIT(
            ch_methylkit_results,
            logfc_cutoff,
            pvalue_cutoff,
            top_n_genes
        )

        ch_versions = ch_versions.mix(
            POST_PROCESSING_METHYLKIT.out.versions,
            GO_ANALYSIS_METHYLKIT.out.versions
        )
    }

    emit:
    versions = ch_versions
    edger_summary = (method == 'edger' || method == 'both') ? POST_PROCESSING_EDGER.out.summary : Channel.empty()
    methylkit_summary = (method == 'methylkit' || method == 'both') ? POST_PROCESSING_METHYLKIT.out.summary : Channel.empty()
}
