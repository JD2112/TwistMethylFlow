include { GO_ENRICHMENT } from '../modules/clinical_reporting'
include { KEGG_ENRICHMENT } from '../modules/clinical_reporting'
include { DISEASE_ENRICHMENT } from '../modules/clinical_reporting'
include { CLINICAL_ANNOTATION } from '../modules/clinical_reporting'
include { DMR_DETAIL_PLOT } from '../modules/clinical_reporting'
include { PCA_PLOT } from '../modules/clinical_reporting'
include { PATHVIEW_PLOT } from '../modules/clinical_reporting'

workflow CLINICAL_REPORTING {
    take:
    ch_annotated_results // Channel: [ val(method), path(results) ]
    logfc_cutoff
    pvalue_cutoff
    kegg_logfc_cutoff
    kegg_pvalue_cutoff
    top_n_genes
    promoter_dist
    enhancer_dist
    ch_coverage_files
    ch_sample_sheet
    ch_gtf
    genome
    ch_disgenet

    main:
    ch_versions = Channel.empty()

    // 1. GO Enrichment
    GO_ENRICHMENT(ch_annotated_results, logfc_cutoff, pvalue_cutoff, top_n_genes)
    ch_versions = ch_versions.mix(GO_ENRICHMENT.out.versions)

    // 2. KEGG Enrichment
    KEGG_ENRICHMENT(ch_annotated_results, kegg_logfc_cutoff, kegg_pvalue_cutoff, top_n_genes)
    ch_versions = ch_versions.mix(KEGG_ENRICHMENT.out.versions)

    // 3. Disease Enrichment (Sovereign Localized DisGeNET)
    DISEASE_ENRICHMENT(ch_annotated_results, logfc_cutoff, pvalue_cutoff, ch_disgenet)
    ch_versions = ch_versions.mix(DISEASE_ENRICHMENT.out.versions)

    // 4. Clinical Annotation (Region/Prioritization/OMIM)
    CLINICAL_ANNOTATION(ch_annotated_results, promoter_dist, enhancer_dist)
    ch_versions = ch_versions.mix(CLINICAL_ANNOTATION.out.versions)

    // 5. GENE-Specific DMR Detail Plot (Top ranked gene only)
    // Extract the symbol and coordinates from the clinical annotation output
    ch_top_gene_symbol = CLINICAL_ANNOTATION.out.symbol_txt
        .map { it[1].text.trim() }
        .first()

    ch_top_gene_tsv = CLINICAL_ANNOTATION.out.tsv_meta
        .map { it[1] }
        .first()

    DMR_DETAIL_PLOT(
        ch_top_gene_symbol,
        ch_top_gene_tsv,
        ch_coverage_files.map { it[1] }.collect(),
        ch_sample_sheet.first(),
        ch_gtf,
        genome
    )
    ch_versions = ch_versions.mix(DMR_DETAIL_PLOT.out.versions)

    // 6. PCA Plot
    PCA_PLOT(
        CLINICAL_ANNOTATION.out.prioritized.first(),
        ch_coverage_files.map { it[1] }.collect(),
        ch_sample_sheet.first()
    )
    ch_versions = ch_versions.mix(PCA_PLOT.out.versions)

    // 7. Pathview Plot
    PATHVIEW_PLOT(
        KEGG_ENRICHMENT.out.results.first(),
        CLINICAL_ANNOTATION.out.prioritized.first()
    )
    ch_versions = ch_versions.mix(PATHVIEW_PLOT.out.versions)

    // Collect all results for UNIFIED_LAYER
    ch_results = Channel.empty()
    ch_results = ch_results.mix(
        ch_annotated_results.map { it[1] },
        GO_ENRICHMENT.out.results.map { it[1] },
        KEGG_ENRICHMENT.out.results.map { it[1] },
        DISEASE_ENRICHMENT.out.results.map { it[1] },
        CLINICAL_ANNOTATION.out.annotated.map { it[1] },
        CLINICAL_ANNOTATION.out.prioritized.map { it[1] },
        CLINICAL_ANNOTATION.out.metrics.map { it[1] },
        DMR_DETAIL_PLOT.out.plot,
        PCA_PLOT.out.plot,
        PATHVIEW_PLOT.out.plots
    )

    emit:
    results  = ch_results.collect()
    versions = ch_versions
}
