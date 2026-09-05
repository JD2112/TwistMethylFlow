#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { CONVERSION_QC } from '../modules/conversion_qc'
include { PICARD_COLLECTHSMETRICS } from '../modules/picard'

/*
 * ====================================================================================
 *  MILOU - Deterministic Test Bench (Layer 5: CI / Reproducibility)
 * ====================================================================================
 *  This test bench script validates core analytical modules independently.
 *  Run this before merging any pull requests to ensure algorithmic determinism.
 */

params.test_bams = "tests/test_data/*.bam"
params.test_bed = "tests/test_data/targets.bed"
params.test_fasta = "tests/test_data/reference.fasta"
params.test_cov = "tests/test_data/*.cov.gz"

workflow {
    log.info "Starting Deterministic Test Bench..."

    // 1. Test Picard Target Capture (Twist)
    ch_bams = Channel.fromPath(params.test_bams)
        .map { file -> [ [id: file.baseName, assay_type: 'twist'], file, file.parent.resolve(file.name + '.bai') ] }
    
    ch_fasta = Channel.fromPath(params.test_fasta).first()
    ch_bed = Channel.fromPath(params.test_bed).first()

    PICARD_COLLECTHSMETRICS(ch_bams, ch_fasta, ch_bed)
    PICARD_COLLECTHSMETRICS.out.metrics.view { "✅ Picard Test Output: ${it[1]}" }

    // 2. Test Conversion QC
    ch_covs = Channel.fromPath(params.test_cov)
        .map { file -> [ [id: file.baseName, assay_type: 'wgbs'], file ] }

    CONVERSION_QC(ch_covs)
    CONVERSION_QC.out.qc_status.view { "✅ Conversion QC Status: ${it[1].text.trim()}" }
}
