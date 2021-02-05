#!/bin/bash

set -eu -o pipefail

ref=$1
bam=$2
reg=$3
contig=$(head -n1 "$ref" | sed 's/>//')
ref=$(basename "$ref")

samtools view -h -F 2068 "$bam" "${contig[@]}":"$reg" | # filter flags UNMAP,SUPPLEMENTARY,REVERSE
samtools fastq > "$ref"."$reg".fvd.fastq

samtools view -h -F 2052 -f 16 "$bam" "${contig[@]}":"$reg" | # filter flags UNMAP,SUPPLEMENTARY
samtools fastq | seqkit seq -rp -t dna --quiet > "$ref"."$reg".rev.fastq

