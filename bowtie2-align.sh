#!/bin/bash

# Parse arguments
while getopts :ha:b:r:t:o: opt; do
	case $opt in 
		h) printf "USAGE:
bowtie2-align.sh -a <forward reads> -b <reverse reads> -r <reference genome> -o <prefix> -t <number of threads>
bowtie2-align.sh -h
-a\tforward reads
-b\treverse reads
-r\tReference genome (fasta)
-t\tNumber of threads
-o\tOutput bam and bai prefix
-h\tThis help
This script assumes bowtie2, awk, and samtools in the \$PATH\n"; exit;;
		a) READ1="$OPTARG";;
		b) READ2="$OPTARG";;
		r) REF="$OPTARG";;
		t) THREADS="$OPTARG";;
		o) OUT="$OPTARG";;
		\?) echo "Invalid option: -$OPTARG"; exit >&2;;
		:) echo "Option -$OPTARG requires an argument"; exit >&2;;
	esac
done

# For debugging purpose
#rm log
#echo "read1: $READ1" >> log
#echo "read2: $READ2" >> log
#echo "ref: $REF" >> log

# Build the index if it doesn't exist
if [[ ! -e $REF.1.bt2 ]]; then
	bowtie2-build $REF $REF
fi

# Align the reads with bowtie2
bowtie2 -1 $READ1 -2 $READ2 -x $REF --threads $THREADS --very-sensitive \
	--un $OUT-unpair-unalign.fq --un-conc-gz $OUT-pair-unconc.fq |\
	awk 'BEGIN{FS = "[\t]"}{if (($3 != "*" && (length($10)>=20)) || $1 ~ /^@/ ){print}}' |\
        samtools view -Sb - |\
	samtools sort -o $OUT-mapped.bam

# Index the alignment to view in an alignment viewer
samtools index $OUT-mapped.bam

