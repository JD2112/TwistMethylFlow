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
    ch_edger_results = Channel.empty()
    ch_methylkit_results = Channel.empty()
    ch_post_processing_edger = Channel.empty()
    ch_post_processing_methylkit = Channel.empty()
    ch_go_analysis_edger_plot = Channel.empty()
    ch_go_analysis_edger_goplot = Channel.empty()
    ch_go_analysis_edger_results = Channel.empty()
    ch_go_analysis_methylkit_plot = Channel.empty()
    ch_go_analysis_methylkit_goplot = Channel.empty()
    ch_go_analysis_methylkit_results = Channel.empty()
    ch_versions = Channel.empty()

    if (method == 'edger' || method == 'both') {
        ch_edger_results = diff_meth_results.filter { it[0] == 'edger' }

        // Flatten list of result files if multiple are emitted together
        ch_edger_results = ch_edger_results.flatMap { method, results ->
            if (results instanceof Path && results.isDirectory()) {
                // If the process emitted a directory, list CSV files in it and
                // return a plain List of [method, file] pairs so flatMap can
                // expand them correctly. Do NOT return a Channel here.
                def dir = results.toFile()
                def csvs = dir.listFiles()?.findAll { it.name.toLowerCase().endsWith('.csv') } ?: []
                return csvs.collect { f -> [method, file(f)] }
            } else if (results instanceof List) {
                return results.collect { [method, it] }
            } else {
                return [[method, results]]
            }
        }

        // Run annotation for each EdgeR result individually
        ch_annotated_edger = ANNOTATE_RESULTS(ch_edger_results, gtf_file)

        // Then pass all annotated files to post-processing and GO steps
        POST_PROCESSING_EDGER(
            //ANNOTATE_RESULTS.out.annotated_results,
            ch_annotated_edger.annotated_results,
            compare_str,
            logfc_cutoff,
            pvalue_cutoff,
            hyper_color,
            hypo_color,
            nonsig_color
        )

        GO_ANALYSIS_EDGER(
            //ANNOTATE_RESULTS.out.annotated_results,
            ch_annotated_edger.annotated_results,
            logfc_cutoff,
            pvalue_cutoff,
            top_n_genes
        )

        ch_post_processing_edger = POST_PROCESSING_EDGER.out.summary
        ch_go_analysis_edger_plot = GO_ANALYSIS_EDGER.out.plot
        ch_go_analysis_edger_goplot = GO_ANALYSIS_EDGER.out.goplot
        ch_go_analysis_edger_results = GO_ANALYSIS_EDGER.out.results
        ch_versions = ch_versions.mix(
            ANNOTATE_RESULTS.out.versions
        ).mix(
            POST_PROCESSING_EDGER.out.versions
        ).mix(
            GO_ANALYSIS_EDGER.out.versions
        )
    }

    if (method == 'methylkit' || method == 'both') {
        ch_methylkit_results = diff_meth_results
            .filter { it[0] == 'methylkit' }
            .map { method, results -> 
                def results_file = results instanceof Path ? results : results[1]
                [method, results_file]
            }
        
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

        ch_post_processing_methylkit = POST_PROCESSING_METHYLKIT.out.summary
        ch_go_analysis_methylkit_plot = GO_ANALYSIS_METHYLKIT.out.plot
        ch_go_analysis_methylkit_goplot = GO_ANALYSIS_METHYLKIT.out.goplot
        ch_go_analysis_methylkit_results = GO_ANALYSIS_METHYLKIT.out.results
        ch_versions = ch_versions.mix(POST_PROCESSING_METHYLKIT.out.versions).mix(GO_ANALYSIS_METHYLKIT.out.versions)
    }

    emit:
    edger_results = ch_edger_results
    methylkit_results = ch_methylkit_results
    post_processing_edger = ch_post_processing_edger
    post_processing_methylkit = ch_post_processing_methylkit
    go_analysis_edger_plot = ch_go_analysis_edger_plot
    go_analysis_edger_goplot = ch_go_analysis_edger_goplot
    go_analysis_edger_results = ch_go_analysis_edger_results
    go_analysis_methylkit_plot = ch_go_analysis_methylkit_plot
    go_analysis_methylkit_goplot = ch_go_analysis_methylkit_goplot
    go_analysis_methylkit_results = ch_go_analysis_methylkit_results
    versions = ch_versions
}
