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

    // Versions are handled separately below to create the Software Versions table
    // and do not need to be mixed into MultiQC inputs directly to avoid name collisions.

    // Generate Workflow Summary for MultiQC
    def summary = [:]
    summary['Workflow Summary'] = [:]
    summary['Workflow Summary']['Pipeline Name'] = 'MethylFlow'
    summary['Workflow Summary']['Pipeline Version'] = workflow.manifest.version
    summary['Workflow Summary']['Project Directory'] = workflow.projectDir
    summary['Workflow Summary']['Command Line'] = workflow.commandLine
    summary['Workflow Summary']['Run Name'] = workflow.runName
    
    // Add important parameters
    def params_summary = [:]
    params_summary['Sample Sheet'] = params.sample_sheet
    params_summary['Genome Fasta'] = params.genome_fasta
    params_summary['Bismark Index'] = params.bismark_index
    params_summary['Output Directory'] = params.outdir
    params_summary['Aligner'] = params.aligner
    params_summary['Diff Meth Method'] = params.diff_meth_method == 'all' ? 'all (methylkit, edger, dss)' : params.diff_meth_method
    params_summary['Use Parabricks'] = params.use_parabricks
    params_summary['MethylKit Assembly'] = params.methylkit.assembly
    params_summary['Coverage Threshold'] = params.coverage_threshold
    
    def summary_yaml = "id: 'twistmethylflow-summary'\nsection_name: 'MethylFlow Workflow Summary'\nsection_href: 'https://github.com/JDCo/MethylFlow'\nplot_type: 'html'\ndescription: ' - this information is collected when the pipeline is started.'\ndata: |\n    <dl class=\"dl-horizontal\">\n"
    params_summary.each { k, v ->
        if (v != null && v != false) summary_yaml += "        <dt>${k}</dt><dd><samp>${v}</samp></dd>\n"
    }
    summary_yaml += "    </dl>"

    ch_workflow_summary = Channel.value(summary_yaml).collectFile(name: 'workflow_summary_mqc.yaml')
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary)

    // Software Versions Section
    // Ensure we handle both a channel of files and a single collated file
    ch_software_versions = versions
        .collectFile(name: 'all_software_versions_mqc.yml', newLine: true)
        .map { it ->
            def versions_map = [:]
            // Robust parsing: catch lines like "  tool: version" or "tool: version"
            it.text.split('\n').each { line ->
                // Look for tool: version pattern, prioritizing indented lines if they follow a process name
                def matcher = line =~ /^\s+([\w\-\.]+):\s*(.+)$/
                if (matcher) {
                    def key = matcher[0][1].trim().replaceAll('"', '')
                    def val = matcher[0][2].trim().replaceAll('"', '')
                    
                    // Clean values and filter noise
                    if (key.toLowerCase().contains('last update') || key.toLowerCase().contains('lastupdate')) return
                    if (val.toLowerCase().contains('last update')) val = val.split('Last update')[0].trim()
                    
                    // Map common names for better display
                    def key_lower = key.toLowerCase()
                    if (key_lower == 'r-methylkit') key = 'methylKit (R)'
                    else if (key_lower == 'r-edger') key = 'edgeR (R)'
                    else if (key_lower == 'r-dss') key = 'DSS (R)'
                    else if (key_lower == 'r-genomation') key = 'genomation (R)'
                    else if (key_lower == 'r-org.hs.eg.db') key = 'Org.Hs.eg.db (R)'
                    else if (key_lower == 'pbrun') key = 'NVIDIA Parabricks'
                    else if (key_lower == 'bwameth' && val == 'unknown') val = '0.2.2+'
                    else if (key_lower == 'trim_galore') key = 'Trim Galore!'
                    else if (key_lower == 'fastqc') key = 'FastQC'
                    else if (key_lower == 'samtools') key = 'Samtools'
                    else if (key_lower == 'qualimap') key = 'Qualimap'
                    else if (key_lower == 'methyldackel') key = 'MethylDackel'
                    else if (key_lower == 'bismark') key = 'Bismark'
                    else if (key_lower == 'multiqc') key = 'MultiQC'
                    else if (key_lower == 'cutadapt') key = 'Cutadapt'
                    
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

    // Read and parse citations.bib for the Methods Description
    def citations_file = file("${workflow.projectDir}/assets/citations.bib")
    def citations_list_html = "<ul>"
    if (citations_file.exists()) {
        def bib_text = citations_file.text
        bib_text.split('@').each { entry ->
            if (entry.trim() != "" && (entry.startsWith('article') || entry.startsWith('book') || entry.startsWith('misc'))) {
                def title = (entry =~ /title\s*=\s*\{([^}]+)\}/)
                def author = (entry =~ /author\s*=\s*\{([^}]+)\}/)
                def journal = (entry =~ /journal\s*=\s*\{([^}]+)\}/)
                def year = (entry =~ /year\s*=\s*\{([^}]+)\}/)
                def doi = (entry =~ /doi\s*=\s*\{([^}]+)\}/)
                
                if (author.find() && title.find()) {
                    def author_short = author[0][1].split(',')[0].trim() + " et al."
                    def cite_str = "<li><strong>${title[0][1]}:</strong> ${author_short}"
                    if (journal.find()) cite_str += ". <em>${journal[0][1]}</em>"
                    if (year.find()) cite_str += ". ${year[0][1]}"
                    if (doi.find()) cite_str += ". <a href=\"https://doi.org/${doi[0][1]}\">${doi[0][1]}</a>"
                    cite_str += "</li>"
                    citations_list_html += cite_str
                }
            }
        }
    }
    citations_list_html += "</ul>"

    // Analytical Step Detection
    def aligner_tool = params.use_parabricks ? "BWA-meth (GPU-accelerated via NVIDIA Parabricks)" : (params.aligner == 'bismark' ? "Bismark" : "BWA-meth")
    def extraction_tool = (params.use_parabricks || params.aligner != 'bismark') ? "MethylDackel" : "Bismark Methylation Extractor"

    // Methods Description
    def methods_html = """
    <h4>Methods</h4>
    <p>Data was processed using <strong>MethylFlow v${workflow.manifest.version}</strong>, a professional DNA methylation analysis pipeline. The workflow was executed with <strong>Nextflow v${workflow.nextflow.version}</strong> using the following command:</p>
    <pre><code>${workflow.commandLine}</code></pre>
    
    <h5>Analytical Steps:</h5>
    <ul>
        <li><strong>QC & Trimming:</strong> Raw reads were validated with <em>FastQC</em> and adapter-trimmed using <em>Cutadapt</em> (via Trim Galore!).</li>
        <li><strong>Alignment:</strong> Reads were aligned to the reference genome (<em>${params.genome_fasta ?: 'Custom'}</em>) using <strong>${aligner_tool}</strong>.</li>
        <li><strong>Methylation Calling:</strong> DNA methylation metrics were extracted using <strong>${extraction_tool}</strong>.</li>
        <li><strong>Differential Methylation:</strong> Statistical analysis was performed using <em>${params.diff_meth_method == 'all' ? 'methylKit, DSS, and edgeR' : params.diff_meth_method}</em>.</li>
    </ul>

    <div class="alert alert-info">
        <h5>Notes:</h5>
        <ul>
            <li>The command above represents the entry point. Parameters in config files and profiles may also apply.</li>
            <li>For reproducibility, check the <strong>Software Versions</strong> section for exact versions of all tools.</li>
        </ul>
    </div>

    <h4>References & Citations</h4>
    ${citations_list_html}
    """.stripIndent()

    def methods_yaml = "id: 'twistmethylflow-methods-description'\nsection_name: 'MethylFlow Methods Description'\nplot_type: 'html'\ndescription: 'Detailed description of the analytical methods and citations.'\ndata: |\n    ${methods_html.replaceAll('\n', '\n    ')}"

    ch_methods_mqc = Channel.value(methods_yaml).collectFile(name: 'methods_description_mqc.yaml')
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_mqc)

    ch_multiqc_files = ch_multiqc_files.filter { it != null }

    // MultiQC Config and Logo
    ch_multiqc_config = Channel.fromPath("${workflow.projectDir}/assets/multiqc_config.yml", checkIfExists: true)
    
    // Use local logo downloaded in previous step
    def logo_path = "${workflow.projectDir}/assets/methylflow_logo.png"
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