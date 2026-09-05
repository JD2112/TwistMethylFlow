include { FASTQC } from '../modules/fastqc'
include { TRIM_GALORE } from '../modules/trim_galore'
include { CHECKSUM_VERIFY } from '../modules/checksum'
include { VALIDATE_SYNC } from '../modules/validate_sync'
include { CHECK_FASTQC_N; MERGE_STATUS } from '../modules/check_fastqc_n'

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

    // Check FastQC Per Base N Content from the output zip reports
    CHECK_FASTQC_N(FASTQC.out.reports)

    // Merge sync validation status and FastQC N-content status
    ch_combined_status = VALIDATE_SYNC.out.status.join(CHECK_FASTQC_N.out.status)
    MERGE_STATUS(ch_combined_status)

    emit:
    trimmed_reads = TRIM_GALORE.out.trimmed_reads
    fastqc_reports = FASTQC.out.reports
    trimming_reports = TRIM_GALORE.out.reports
    checksums = CHECKSUM_VERIFY.out.checksums
    sync_status = MERGE_STATUS.out.status
    versions = ch_versions
}