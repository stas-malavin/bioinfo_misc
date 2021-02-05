#!/usr/bin/env bash

# Get average length, GC content, and quality of reads using seqkit

FILE=$1
THREADS=8 # Change this

seqkit fx2tab -nilqg -j "$THREADS" "$FILE" | # -ni prins the id's only, no sequences
# The order of -lqn doesn't affect the output column order
cut -f 2,3,4 |
awk '{len += $1; gc += $2; qual += $3} END {print len/NR; print gc/NR; print qual/NR}'
