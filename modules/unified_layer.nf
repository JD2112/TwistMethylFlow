process UNIFIED_LAYER {
    label 'process_low'

    input:
    path(multiqc_data)
    path(sample_sheet)
    path(dmr_and_go_files)
    path(methods_yml)
    path(citations_bib)
    path(checksums)

    output:
    path("results_dir"), emit: results_dir

    script:
    def params_json = groovy.json.JsonOutput.toJson(params)
    """
    cat <<'PARAMS_EOF' > resolved_params.json
${params_json}
PARAMS_EOF

    python3 ${workflow.projectDir}/bin/build_unified_results.py \
        --run_name "${workflow.runName}" \
        --mode "${params.mode}" \
        --commit "${workflow.commitId ?: 'Not available'}" \
        --command_line "${workflow.commandLine}" \
        --promoter_dist ${params.promoter_dist} \
        --enhancer_dist ${params.enhancer_dist} \
        --pvalue_cutoff ${params.pvalue_cutoff} \
        --logfc_cutoff ${params.logfc_cutoff} \
        --top_n_genes ${params.top_n_genes} \
        --coverage_threshold ${params.coverage_threshold} \
        --min_30x_pc ${params.min_30x_pc} \
        --metadata ${sample_sheet} \
        --methods_yml ${methods_yml} \
        --citations_bib ${citations_bib} \
        --nextflow_version "${workflow.nextflow.version}" \
        --container_engine "${workflow.containerEngine ?: 'Local/Native'}" \
        --genome_build "${params.genome_fasta ?: 'Custom/Unspecified'}" \
        --resolved_params resolved_params.json \
        --checksums_dir .
    """
}
