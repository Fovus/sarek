process DEEPVARIANT_RUNDEEPVARIANT {
    tag "$meta.id"
    label 'process_high'
    //label 'process_gpu'
    // needed by the module to work properly can be removed when fixed upstream - see: https://github.com/nf-core/modules/issues/7226
    //stageInMode 'copy'

    container "nvcr.io/nvidia/clara/clara-parabricks:4.6.0-1"

    input:
    tuple val(meta), path(input), path(index), path(intervals)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(gzi)
    tuple val(meta5), path(par_bed)


    output:
    tuple val(meta), path("${prefix}.vcf.gz")             , emit: vcf
    tuple val(meta), path("${prefix}.vcf.gz.{tbi,csi}")   , emit: vcf_index
    path "versions.yml"                                   , emit: versions

    //tuple val(meta), path("${prefix}.g.vcf.gz")           , emit: gvcf
    //tuple val(meta), path("${prefix}.g.vcf.gz.{tbi,csi}") , emit: gvcf_index

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        exit(1, "Parabricks module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    //def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    //def output_file = args.contains("--gvcf") ? "${prefix}.g.vcf.gz" : "${prefix}.vcf.gz"
    def interval_command = intervals        ? intervals.collect { intervals -> "--interval-file ${intervals}" }.join(' ') : ""

    """
    pbrun \\
        deepvariant \\
        --ref ${fasta} \\
        --in-bam ${input} \\
        --out-variants ${prefix}.vcf.gz \\
        ${interval_command} \\
        --num-gpus \$FovusOptGpu

    cat <<-END_VERSIONS > versions.yml
	"${task.process}":
		parabricks-deepvariant: \$(echo "4.6.0-1")
    END_VERSIONS


    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def output_cmd = args.contains("--gvcf") ? "echo '' | gzip > ${prefix}.g.vcf.gz" : "echo '' | gzip > ${prefix}.vcf.gz"
    """
    ${output_cmd}

    # Capture the full version output once and store it in a variable
    pbrun_version_output=\$(pbrun deepvariant --version 2>&1)

    # Generate compatible_versions.yml
    cat <<EOF > compatible_versions.yml
    "${task.process}":
        pbrun_version: \$(echo "\$pbrun_version_output" | grep "pbrun:" | awk '{print \$2}')
        compatible_with:
        \$(echo "\$pbrun_version_output" | awk '/Compatible With:/,/^---/{ if (\$1 ~ /^[A-Z]/ && \$1 != "Compatible" && \$1 != "---") { printf "  %s: %s\\n", \$1, \$2 } }')
    EOF
    """
}

