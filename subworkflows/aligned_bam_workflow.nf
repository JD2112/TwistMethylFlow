// File: subworkflows/aligned_bam_workflow.nf

include { BISMARK_DEDUPLICATE } from '../modules/bismark'
include { BISMARK_METHYLATION_EXTRACTOR } from '../modules/bismark'
include { BISMARK_REPORT } from '../modules/bismark'
include { QUALIMAP } from '../modules/qualimap'

workflow ALIGNED_BAM_WORKFLOW {
    take:
    aligned_bams

    main:
    // Deduplicate alignments
    BISMARK_DEDUPLICATE(aligned_bams)

    // Extract methylation calls
    BISMARK_METHYLATION_EXTRACTOR(BISMARK_DEDUPLICATE.out.deduplicated_bam)

    // Generate sample report
    // Note: BISMARK_REPORT expects a tuple of all relevant reports. 
    // Since we start from aligned BAMs, we might not have the original alignment report,
    // but we can group the available ones.
    ch_reports = BISMARK_DEDUPLICATE.out.dedup_report
        .mix(BISMARK_METHYLATION_EXTRACTOR.out.splitting_report)
        .groupTuple()

    BISMARK_REPORT(ch_reports)

    // Alignment QC
    // We need to create a channel with BAM and BAI files for QUALIMAP
    // If BAI doesn't exist, we should probably index it
    // For now, assume it's there or handle it
    QUALIMAP(BISMARK_DEDUPLICATE.out.deduplicated_bam.map { meta, bam -> [meta, bam, file("${bam}.bai")] })

    emit:
    coverage_files = BISMARK_METHYLATION_EXTRACTOR.out.coverage
    bedgraph_files = BISMARK_METHYLATION_EXTRACTOR.out.bedgraph
    methylation_reports = BISMARK_METHYLATION_EXTRACTOR.out.splitting_report
    dedup_reports = BISMARK_DEDUPLICATE.out.dedup_report
    bismark_reports = BISMARK_REPORT.out.summary_report
    qualimap_results = QUALIMAP.out.results
    versions = BISMARK_METHYLATION_EXTRACTOR.out.versions.mix(
        BISMARK_DEDUPLICATE.out.versions,
        BISMARK_REPORT.out.versions,
        QUALIMAP.out.versions
    )
}