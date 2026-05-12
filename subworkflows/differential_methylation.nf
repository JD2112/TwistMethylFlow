include { EDGER_ANALYSIS } from '../modules/edger'
include { METHYLKIT_ANALYSIS } from '../modules/methylkit'
include { DSS_ANALYSIS } from '../modules/dss'

workflow DIFFERENTIAL_METHYLATION {
    take:
    coverage_files
    design_file
    compare_str
    coverage_threshold
    method
    refseq_file
    methylkit_assembly
    methylkit_mc_cores
    methylkit_diff
    methylkit_qvalue
    methylkit_bed
    dss_p_threshold
    dss_diff_threshold
    edger_p_threshold
    edger_logfc_cutoff
    methylkit_min_per_group

    main:    
    ch_versions = Channel.empty()
    ch_edger_results = Channel.empty()
    ch_methylkit_results = Channel.empty()
    ch_dss_results = Channel.empty()

    def methods = method.split(',').collect { it.trim().toLowerCase() }

    // Prepare the coverage files channel
    coverage_files_prepared = coverage_files
        .map { meta, file -> 
            return file 
        }
        .collect()
    
    log.info "DIFFERENTIAL_METHYLATION: Prepared coverage files for analysis"

    if (methods.contains('edger') || methods.contains('all')) {
        log.info "DIFFERENTIAL_METHYLATION: Running EdgeR analysis"        
        EDGER_ANALYSIS (
            coverage_files_prepared,
            design_file,
            compare_str,
            coverage_threshold,
            edger_p_threshold,
            edger_logfc_cutoff
        )
        ch_edger_results = EDGER_ANALYSIS.out.results
        ch_versions = ch_versions.mix(EDGER_ANALYSIS.out.versions)
    }

    if (methods.contains('methylkit') || methods.contains('all')) {
        log.info "DIFFERENTIAL_METHYLATION: Running MethylKit analysis"        
        METHYLKIT_ANALYSIS (
            coverage_files_prepared,
            design_file,
            compare_str,
            coverage_threshold,
            refseq_file,
            methylkit_assembly,
            methylkit_mc_cores,
            methylkit_diff,
            methylkit_qvalue,
            methylkit_bed,
            methylkit_min_per_group
        )
        ch_methylkit_results = METHYLKIT_ANALYSIS.out.results
        ch_versions = ch_versions.mix(METHYLKIT_ANALYSIS.out.versions)
    }

    if (methods.contains('dss') || methods.contains('all')) {
        DSS_ANALYSIS (
            coverage_files_prepared,
            design_file,
            compare_str,
            coverage_threshold,
            dss_p_threshold,
            dss_diff_threshold
        )
        ch_dss_results = DSS_ANALYSIS.out.results
        ch_versions = ch_versions.mix(DSS_ANALYSIS.out.versions)
    }

    // Combine the results for RESULT_ANALYSIS
    // ch_combined_results = ch_edger_results
    //     .mix(ch_methylkit_results)
    //     .ifEmpty { error "No results generated from either EdgeR or MethylKit" }

    emit:
    edger_results = ch_edger_results
    methylkit_results = ch_methylkit_results
    dss_results = ch_dss_results
    //combined_results = ch_combined_results
    versions = ch_versions
}