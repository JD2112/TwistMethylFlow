include { MULTIQC } from '../modules/multiqc'

workflow QC_REPORTING {
    take:
    fastqc_reports
    trimming_reports
    align_reports
    dedup_reports
    methylation_reports
    summary_report
    qualimap_results
    versions

    main:
    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(fastqc_reports.flatten().filter { !(it instanceof Map) })
    ch_multiqc_files = ch_multiqc_files.mix(trimming_reports.flatten().filter { !(it instanceof Map) })
    ch_multiqc_files = ch_multiqc_files.mix(align_reports.flatten().filter { !(it instanceof Map) })
    ch_multiqc_files = ch_multiqc_files.mix(dedup_reports.flatten().filter { !(it instanceof Map) })
    ch_multiqc_files = ch_multiqc_files.mix(methylation_reports.flatten().filter { !(it instanceof Map) })
    ch_multiqc_files = ch_multiqc_files.mix(summary_report.flatten().filter { !(it instanceof Map) })
    ch_multiqc_files = ch_multiqc_files.mix(qualimap_results.flatten().filter { !(it instanceof Map) })

    // Generate Workflow Summary for MultiQC
    def summary = [:]
    summary['Workflow Summary'] = [:]
    summary['Workflow Summary']['Pipeline Name'] = 'milou'
    summary['Workflow Summary']['Pipeline Version'] = workflow.manifest.version
    summary['Workflow Summary']['Project Directory'] = workflow.projectDir
    summary['Workflow Summary']['Command Line'] = workflow.commandLine
    summary['Workflow Summary']['Run Name'] = workflow.runName
    
    // Add important parameters
    def params_summary = [:]
    params_summary['Sample Sheet'] = params.sample_sheet
    params_summary['Genome Fasta'] = params.genome_fasta
    params_summary['Output Directory'] = params.outdir
    params_summary['Aligner'] = params.aligner
    params_summary['Diff Meth Method'] = params.diff_meth_method == 'all' ? 'all (methylkit, edger, dss)' : params.diff_meth_method
    params_summary['Use Parabricks'] = params.use_parabricks
    params_summary['Coverage Threshold'] = params.coverage_threshold
    
    def summary_yaml = "id: 'milou-summary'\nsection_name: 'milou Workflow Summary'\nsection_href: 'https://github.com/JD2112/milou'\nplot_type: 'html'\ndescription: ' - this information is collected when the pipeline is started.'\ndata: |\n    <dl class=\"dl-horizontal\">\n"
    params_summary.each { k, v ->
        if (v != null && v != false) summary_yaml += "        <dt>${k}</dt><dd><samp>${v}</samp></dd>\n"
    }
    summary_yaml += "    </dl>"

    ch_workflow_summary = Channel.value(summary_yaml).collectFile(name: 'workflow_summary_mqc.yaml')
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary)

    // Software Versions Section
    ch_software_versions = versions
        .collectFile(name: 'all_software_versions_mqc.yml', newLine: true)
        .map { it ->
            def versions_map = [:]
            it.text.split('\n').each { line ->
                def matcher = line =~ /^\s+([\w\-\.]+):\s*(.+)$/
                if (matcher) {
                    def key = matcher[0][1].trim().replaceAll('"', '')
                    def val = matcher[0][2].trim().replaceAll('"', '')
                    
                    if (key.toLowerCase().contains('last update')) return
                    
                    def key_lower = key.toLowerCase()
                    if (key_lower == 'r-methylkit') key = 'methylKit (R)'
                    else if (key_lower == 'r-edger') key = 'edgeR (R)'
                    else if (key_lower == 'r-dss') key = 'DSS (R)'
                    else if (key_lower == 'pbrun') key = 'NVIDIA Parabricks'
                    else if (key_lower == 'trim_galore') key = 'Trim Galore!'
                    
                    if (val != "" && !val.contains(':')) {
                        versions_map[key] = val
                    }
                }
            }
            
            def version_table = "id: 'software_versions'\nsection_name: 'Software Versions'\nplot_type: 'html'\ndescription: 'Software versions used in this pipeline run.'\ndata: |\n    <div class=\"alert alert-info\">Software versions are captured at runtime for reproducibility.</div>\n    <table class=\"table table-hover table-condensed\">\n        <thead><tr><th>Software</th><th>Version</th></tr></thead>\n        <tbody>\n"
            versions_map.sort { it.key.toLowerCase() }.each { k, v ->
                version_table += "            <tr><td>${k}</td><td><span class=\"label label-info\">${v}</span></td></tr>\n"
            }
            version_table += "        </tbody>\n    </table>"
            return version_table
        }
        .collectFile(name: 'software_versions_mqc.yaml')
    
    ch_multiqc_files = ch_multiqc_files.mix(ch_software_versions)

    // Analytical Step Detection
    def aligner_tool = params.use_parabricks ? "BWA-meth (GPU-accelerated via NVIDIA Parabricks)" : (params.aligner == 'bismark' ? "Bismark" : "BWA-meth")
    def extraction_tool = (params.use_parabricks || params.aligner != 'bismark') ? "MethylDackel" : "Bismark Methylation Extractor"

    // Methods Description
    def methods_html = """
    <h4>Methods</h4>
    <p>Data was processed using <strong>milou v${workflow.manifest.version}</strong> (Methylation Integrated Layer for Omics Unification), a professional DNA methylation analysis framework. The workflow was executed with <strong>Nextflow v${workflow.nextflow.version}</strong> using the following command:</p>
    <pre><code>${workflow.commandLine}</code></pre>
    
    <h5>Analytical Steps:</h5>
    <ul>
        <li><strong>QC & Trimming:</strong> Raw reads were validated with <em>FastQC</em> and adapter-trimmed using <em>Cutadapt</em> (via Trim Galore!).</li>
        <li><strong>Alignment:</strong> Reads were aligned to the reference genome (<em>${params.genome_fasta ?: 'Custom'}</em>) using <strong>${aligner_tool}</strong>.</li>
        <li><strong>Methylation Calling:</strong> DNA methylation metrics were extracted using <strong>${extraction_tool}</strong>.</li>
        <li><strong>Differential Methylation:</strong> Statistical analysis was performed using a consensus approach with <em>${params.diff_meth_method == 'all' ? 'methylKit, DSS, and edgeR' : params.diff_meth_method}</em>.</li>
    </ul>

    <div class="alert alert-info">
        <h5>Notes:</h5>
        <ul>
            <li>The command above represents the entry point. Parameters in config files and profiles may also apply.</li>
            <li>For reproducibility, check the <strong>Software Versions</strong> section for exact versions of all tools.</li>
        </ul>
    </div>
    """.stripIndent()

    def methods_yaml = "id: 'milou-methods-description'\nsection_name: 'milou Methods Description'\nplot_type: 'html'\ndescription: 'Detailed description of the analytical methods.'\ndata: |\n    ${methods_html.replaceAll('\n', '\n    ')}"

    ch_methods_mqc = Channel.value(methods_yaml).collectFile(name: 'methods_description_mqc.yaml')
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_mqc)

    ch_multiqc_files = ch_multiqc_files.filter { it != null }

    // MultiQC Config and Logo
    ch_multiqc_config = Channel.fromPath("${workflow.projectDir}/assets/multiqc_config.yml", checkIfExists: true)
    
    def logo_path = "${workflow.projectDir}/assets/milou_logo.png"
    if (file(logo_path).exists()) {
        ch_multiqc_logo = Channel.fromPath(logo_path)
    } else {
        ch_multiqc_logo = Channel.empty()
    }

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config,
        ch_multiqc_logo.ifEmpty([])
    )

    emit:
    multiqc_report = MULTIQC.out.report
    multiqc_data = MULTIQC.out.data
    multiqc_log = MULTIQC.out.log
    versions = MULTIQC.out.versions
}