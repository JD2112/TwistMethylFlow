include { FASTQC } from '../modules/fastqc'
include { TRIM_GALORE } from '../modules/trim_galore'
include { CHECKSUM_VERIFY } from '../modules/checksum'
include { VALIDATE_SYNC } from '../modules/validate_sync'

workflow READ_PROCESSING {
    take:
    reads

    main:
    ch_versions = Channel.empty()

    VALIDATE_SYNC(reads)

    FASTQC(VALIDATE_SYNC.out.reads)
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    CHECKSUM_VERIFY(VALIDATE_SYNC.out.reads)

    TRIM_GALORE(VALIDATE_SYNC.out.reads)
    ch_versions = ch_versions.mix(TRIM_GALORE.out.versions.first())

    emit:
    trimmed_reads = TRIM_GALORE.out.trimmed_reads
    fastqc_reports = FASTQC.out.reports
    trimming_reports = TRIM_GALORE.out.reports
    checksums = CHECKSUM_VERIFY.out.checksums
    sync_status = VALIDATE_SYNC.out.status
    versions = ch_versions
}