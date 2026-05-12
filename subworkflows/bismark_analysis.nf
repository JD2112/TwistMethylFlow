include { BISMARK_ALIGN; BISMARK_DEDUPLICATE; BISMARK_METHYLATION_EXTRACTOR; BISMARK_REPORT } from '../modules/bismark'
include { SAMTOOLS_SORT; SAMTOOLS_INDEX; SAMTOOLS_MERGE } from '../modules/samtools'
include { QUALIMAP } from '../modules/qualimap'

workflow BISMARK_ANALYSIS {
    take:
    trimmed_reads
    bismark_index

    main:
    ch_versions = Channel.empty()

    // Align reads to reference genome with Bismark
    if (params.bismark_split_reads > 0) {
        // Split FASTQ into chunks for parallel alignment
        ch_chunks = trimmed_reads
            .splitFastq(by: params.bismark_split_reads, pe: true)
            .map { meta, reads ->
                // Create a unique prefix for each chunk to avoid filename collisions
                // We use the file's hash or a unique string from the path
                def chunk_id = reads instanceof List ? reads[0].name.split(/\.f/)[0] : reads.name.split(/\.f/)[0]
                def new_meta = meta + [ id: "${meta.id}_${chunk_id}", original_id: meta.id ]
                return [ new_meta, reads ]
            }

        BISMARK_ALIGN ( ch_chunks, bismark_index )
        ch_versions = ch_versions.mix(BISMARK_ALIGN.out.versions.first())

        // Group chunks by original sample ID and merge BAMs
        ch_bams_to_merge = BISMARK_ALIGN.out.bam
            .map { meta, bam -> [ meta.original_id, meta, bam ] }
            .groupTuple(by: 0)
            .map { original_id, metas, bams -> 
                def new_meta = metas[0].clone()
                new_meta.id = original_id
                return [ new_meta, bams ]
            }

        SAMTOOLS_MERGE ( ch_bams_to_merge )
        ch_aligned_bam = SAMTOOLS_MERGE.out.bam
        
        // For reports, we take the first chunk's report as a proxy, 
        // or we could collect all (bismark2report doesn't support multiple align reports natively)
        ch_align_reports = BISMARK_ALIGN.out.report
            .map { meta, report -> [ meta.original_id, report ] }
            .groupTuple(by: 0)
            .map { id, reports -> [ [id: id], reports[0] ] } // Just take the first for now
    } else {
        BISMARK_ALIGN ( trimmed_reads, bismark_index )
        ch_versions = ch_versions.mix(BISMARK_ALIGN.out.versions.first())
        ch_aligned_bam = BISMARK_ALIGN.out.bam
        ch_align_reports = BISMARK_ALIGN.out.report
    }
    
    BISMARK_DEDUPLICATE(ch_aligned_bam)

    SAMTOOLS_SORT(BISMARK_DEDUPLICATE.out.deduplicated_bam)
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)
    
    // Combine sorted BAM and its index
    ch_sorted_indexed_bam = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)
    
    QUALIMAP(ch_sorted_indexed_bam)

    BISMARK_METHYLATION_EXTRACTOR(BISMARK_DEDUPLICATE.out.deduplicated_bam)
    
    // BISMARK_REPORT(
    //     BISMARK_ALIGN.out.report.join(BISMARK_DEDUPLICATE.out.report).join(BISMARK_METHYLATION_EXTRACTOR.out.report).join(BISMARK_ALIGN.out.report)
    // )
    reports_ch = ch_align_reports
    .mix(BISMARK_DEDUPLICATE.out.dedup_report)  // Change 'report' to 'dedup_report'
    .mix(BISMARK_METHYLATION_EXTRACTOR.out.splitting_report)  // Change 'report' to 'splitting_report'
    .groupTuple()

    BISMARK_REPORT(reports_ch)

    emit:
    coverage_files = BISMARK_METHYLATION_EXTRACTOR.out.coverage
    align_reports = ch_align_reports
    dedup_reports = BISMARK_DEDUPLICATE.out.dedup_report
    methylation_reports = BISMARK_METHYLATION_EXTRACTOR.out.splitting_report
    summary_report = BISMARK_REPORT.out.summary_report
    deduplicated_bam     = BISMARK_DEDUPLICATE.out.deduplicated_bam
    sorted_bam           = SAMTOOLS_SORT.out.bam
    bam_index            = SAMTOOLS_INDEX.out.bai
    qualimap_results     = QUALIMAP.out.results
    bam      = ch_aligned_bam               // channel: [ val(meta), [ bam ] ]
    report   = ch_align_reports             // channel: [ val(meta), [ txt ] ]
    unmapped = BISMARK_ALIGN.out.unmapped   // channel: [ val(meta), [ fq.gz ] ]
    versions = ch_versions                  // channel: [ versions.yml ]
}