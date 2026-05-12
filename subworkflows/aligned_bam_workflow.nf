// File: subworkflows/aligned_bam_workflow.nf

include { BISMARK_DEDUPLICATE } from '../modules/bismark'
include { BISMARK_METHYLATION_EXTRACTOR } from '../modules/bismark'
include { BISMARK_REPORT } from '../modules/bismark'
include { SAMTOOLS_SORT; SAMTOOLS_INDEX } from '../modules/samtools'
include { QUALIMAP } from '../modules/qualimap'

workflow ALIGNED_BAM_WORKFLOW {
    take:
    aligned_bams

    main:
    // Deduplicate alignments
    BISMARK_DEDUPLICATE(aligned_bams)

    // Sort and index for QUALIMAP (requires coordinate-sorted, indexed BAMs)
    SAMTOOLS_SORT(BISMARK_DEDUPLICATE.out.deduplicated_bam)
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)

    // Combine sorted BAM and its index for QUALIMAP
    ch_sorted_indexed_bam = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)
    QUALIMAP(ch_sorted_indexed_bam)

    // Extract methylation calls
    BISMARK_METHYLATION_EXTRACTOR(BISMARK_DEDUPLICATE.out.deduplicated_bam)

    // Generate sample report
    ch_reports = BISMARK_DEDUPLICATE.out.dedup_report
        .mix(BISMARK_METHYLATION_EXTRACTOR.out.splitting_report)
        .groupTuple()

    BISMARK_REPORT(ch_reports)

    emit:
    coverage_files = BISMARK_METHYLATION_EXTRACTOR.out.coverage
    bedgraph_files = BISMARK_METHYLATION_EXTRACTOR.out.bedgraph
    methylation_reports = BISMARK_METHYLATION_EXTRACTOR.out.splitting_report
    dedup_reports = BISMARK_DEDUPLICATE.out.dedup_report
    bismark_reports = BISMARK_REPORT.out.summary_report
    qualimap_results = QUALIMAP.out.results
    sorted_bam       = SAMTOOLS_SORT.out.bam
    bam_index        = SAMTOOLS_INDEX.out.bai
    versions = BISMARK_METHYLATION_EXTRACTOR.out.versions.mix(
        BISMARK_DEDUPLICATE.out.versions,
        BISMARK_REPORT.out.versions,
        SAMTOOLS_SORT.out.versions,
        SAMTOOLS_INDEX.out.versions,
        QUALIMAP.out.versions
    )
}