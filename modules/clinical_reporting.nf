process GO_ENRICHMENT {
    label 'process_medium'
    tag "${method}-${results.name}"

    input:
    tuple val(method), path(results)
    val logfc_cutoff
    val pvalue_cutoff
    val top_n

    output:
    tuple val(method), path("*_go_*"), emit: results
    path "versions.yml", emit: versions

    script:
    """
    Rscript ${workflow.projectDir}/bin/go_enrichment.R \
        --results ${results} \
        --output . \
        --method ${method} \
        --logfc_cutoff ${logfc_cutoff} \
        --pvalue_cutoff ${pvalue_cutoff} \
        --top_n ${top_n}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}

process KEGG_ENRICHMENT {
    label 'process_medium'
    tag "${method}-${results.name}"

    input:
    tuple val(method), path(results)
    val logfc_cutoff
    val pvalue_cutoff
    val top_n

    output:
    tuple val(method), path("*_kegg_*"), emit: results
    path "versions.yml", emit: versions

    script:
    """
    Rscript ${workflow.projectDir}/bin/kegg_enrichment.R \
        --results ${results} \
        --output . \
        --method ${method} \
        --logfc_cutoff ${logfc_cutoff} \
        --pvalue_cutoff ${pvalue_cutoff} \
        --top_n ${top_n}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}

process DISEASE_ENRICHMENT {
    label 'process_medium'
    tag "${method}-${results.name}"

    input:
    tuple val(method), path(results)
    val logfc_cutoff
    val pvalue_cutoff
    path disgenet_db

    output:
    tuple val(method), path("*_disease_*"), emit: results
    path "versions.yml", emit: versions

    script:
    def disgenet_arg = disgenet_db.name != 'NO_FILE' ? "--disgenet_db ${disgenet_db}" : ""
    """
    Rscript ${workflow.projectDir}/bin/disease_enrichment.R \
        --results ${results} \
        --output . \
        --method ${method} \
        --logfc_cutoff ${logfc_cutoff} \
        --pvalue_cutoff ${pvalue_cutoff} \
        ${disgenet_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}

process CLINICAL_ANNOTATION {
    label 'process_low'
    tag "${method}-${results.name}"

    input:
    tuple val(method), path(results)
    val promoter_dist
    val enhancer_dist

    output:
    tuple val(method), path("*_region_annotated.csv"), emit: annotated
    tuple val(method), path("*_gene_prioritized.csv"), emit: prioritized
    tuple val(method), path("${method}_top_gene_metadata.tsv"), emit: tsv_meta
    tuple val(method), path("${method}_top_gene_symbol.txt"), emit: symbol_txt
    tuple val(method), path("${results.simpleName}_epigenetic_metrics.json"), emit: metrics
    path "versions.yml", emit: versions

    script:
    """
    Rscript ${workflow.projectDir}/bin/clinical_annotation.R \
         --results ${results} \
         --output . \
         --method ${method} \
         --promoter_dist ${promoter_dist} \
         --enhancer_dist ${enhancer_dist}

    # Rename outputs to avoid collisions in UNIFIED_LAYER
    mv epigenetic_metrics.json ${results.simpleName}_epigenetic_metrics.json
    mv top_gene_metadata.tsv ${method}_top_gene_metadata.tsv
    mv top_gene_symbol.txt ${method}_top_gene_symbol.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}

process PCA_PLOT {
    label 'process_medium'
    tag "${method}"

    input:
    tuple val(method), path(prioritized)
    path(bedgraphs)
    path(sample_sheet)

    output:
    path "pca_plot.png", emit: plot
    path "versions.yml",  emit: versions

    script:
    def coverage_files = bedgraphs.join(',')
    """
    Rscript ${workflow.projectDir}/bin/generate_pca_plots.R \
        --prioritized_csv ${prioritized} \
        --coverage_files ${coverage_files} \
        --sample_sheet ${sample_sheet} \
        --output pca_plot.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}

process PATHVIEW_PLOT {
    label 'process_medium'
    tag "${method}"

    input:
    tuple val(method), path(kegg_results)
    tuple val(method2), path(prioritized)

    output:
    path "*.png",        emit: plots
    path "versions.yml", emit: versions

    script:
    def kegg_csv = kegg_results.find { it.name.endsWith('.csv') }
    """
    Rscript ${workflow.projectDir}/bin/generate_pathview.R \
        --kegg_tsv ${kegg_csv} \
        --prioritized_csv ${prioritized}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}

process DMR_DETAIL_PLOT {
    label 'process_medium'
    tag "${symbol}"

    input:
    val(symbol)
    path(top_gene_tsv)
    path(bedgraphs)
    path(sample_sheet)
    path(gtf)
    val genome

    output:
    path "top_dmr_detail_plot.png", emit: plot
    path "versions.yml",             emit: versions

    script:
    def coverage_files = bedgraphs.join(',')
    """
    Rscript ${workflow.projectDir}/bin/generate_dmr_plots.R \
        --top_gene_tsv ${top_gene_tsv} \
        --coverage_files ${coverage_files} \
        --sample_sheet ${sample_sheet} \
        --gtf ${gtf} \
        --genome ${genome} \
        --output top_dmr_detail_plot.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$( R --version | head -n 1 | awk '{print \$3}' )
    END_VERSIONS
    """
}
