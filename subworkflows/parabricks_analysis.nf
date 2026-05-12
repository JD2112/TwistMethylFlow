include { PARABRICKS_FQ2BAMMETH; METHYLDACKEL_EXTRACT } from '../modules/nvidia_parabricks'
include { SAMTOOLS_INDEX; SAMTOOLS_FAIDX } from '../modules/samtools'
include { BWAMETH_INDEX } from '../modules/bwameth'
include { QUALIMAP } from '../modules/qualimap'

workflow PARABRICKS_ANALYSIS {
    take:
    trimmed_reads
    fasta

    main:
    ch_versions = Channel.empty()

    // Index the genome for bwa-meth/Parabricks if needed
    BWAMETH_INDEX(fasta)
    ch_versions = ch_versions.mix(BWAMETH_INDEX.out.versions)

    // Align reads with Parabricks GPU-accelerated bwa-meth
    PARABRICKS_FQ2BAMMETH ( trimmed_reads, fasta, BWAMETH_INDEX.out.index.collect() )
    ch_versions = ch_versions.mix(PARABRICKS_FQ2BAMMETH.out.versions.first())
    
    // Index the BAM
    SAMTOOLS_INDEX(PARABRICKS_FQ2BAMMETH.out.bam)
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)
    
    // Qualimap
    ch_sorted_indexed_bam = PARABRICKS_FQ2BAMMETH.out.bam.join(SAMTOOLS_INDEX.out.bai)
    QUALIMAP(ch_sorted_indexed_bam)
    ch_versions = ch_versions.mix(QUALIMAP.out.versions)

    // Methylation calling with Parabricks
    // Index the genome fasta
    SAMTOOLS_FAIDX(fasta)
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    // Methylation calling with MethylDackel (CPU)
    METHYLDACKEL_EXTRACT(
        PARABRICKS_FQ2BAMMETH.out.bam.join(SAMTOOLS_INDEX.out.bai), 
        fasta, 
        SAMTOOLS_FAIDX.out.fai.collect()
    )
    ch_versions = ch_versions.mix(METHYLDACKEL_EXTRACT.out.versions.first())

    emit:
    coverage_files   = METHYLDACKEL_EXTRACT.out.bedgraph
    bam              = PARABRICKS_FQ2BAMMETH.out.bam
    bai              = SAMTOOLS_INDEX.out.bai
    qualimap_results = QUALIMAP.out.results
    versions         = ch_versions
}
