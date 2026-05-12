include { BISMARK_GENOME_PREPARATION } from '../modules/bismark'

workflow PREPARE_GENOME {
    take:
    genome_fasta

    main:
    BISMARK_GENOME_PREPARATION(genome_fasta)

    emit:
    index = BISMARK_GENOME_PREPARATION.out.index
    versions = BISMARK_GENOME_PREPARATION.out.versions
}