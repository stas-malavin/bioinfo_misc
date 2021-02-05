#!/bin/bash

#set -eu -o pipefail
set -u

bam=$1
dir=$2

for file in "$dir"/*; do

  contig=$(head -n1 "$file" | sed 's/>//')
  file=$(basename "$file")
  echo "***** Processing "$file" *****"

  # === Forward reads ===
  echo "Processing forward reads ..."
  ## --- Left forward reads ---
  samtools view -h -F 2068 "$bam" "${contig[@]}" | # filter flags UNMAP,SUPPLEMENTARY,REVERSE
  grep -E '^@|[0-9]{1,3}S[0-9]{1,3}=' | # select soft-clipped at the left edge by CIGAR
  samtools fasta > "$file".fl.fasta
  
  ## --- Right forward reads ---
  samtools view -h -F 2068 "$bam" "${contig[@]}" | # filter flags UNMAP,SUPPLEMENTARY,REVERSE
  grep -E '^@|[0-9]{1,3}=[0-9]{1,3}S' | # select soft-clipped at the right edge by CIGAR
  samtools fasta > "$file".fr.fasta
  
  # === Reverse reads ===
  echo "Processing reverse reads ..."
  ## --- Left reverse reads ---
  samtools view -h -F 2052 -f 16 "$bam" "${contig[@]}" | # filter flags UNMAP,SUPPLEMENTARY
  grep -E '^@|[0-9]{1,3}S[0-9]{1,3}=' | # select soft-clipped at the left edge by CIGAR
  samtools fasta |
  seqkit seq -rp -t dna --quiet > "$file".rl.fasta # reverse complement the reads
  
  ## --- Right reverse reads ---
  samtools view -h -F 2052 -f 16 "$bam" "${contig[@]}" | # filter flags UNMAP,SUPPLEMENTARY
  grep -E '^@|[0-9]{1,3}=[0-9]{1,3}S' | # select soft-clipped at the right edge by CIGAR
  samtools fasta |
  seqkit seq -rp -t dna --quiet > "$file".rr.fasta # reverse complement the reads
  
  ## === Combine everything into one file and align ===
  flen=$(seqkit stats -T "$dir"/"$file" | cut -f 8 | grep -o '[0-9]*') # get the contig length
  if [ "$flen" -gt 100000 ]; then # if the contig's too big, cut out the ends, align, then glue back
    echo "Aligning reads to the ends of the contig with clustal-omega,
then aligning the result to the whole contig with mafft FFT-NS-2 ..."
    seqkit concat --id-regexp "^(.*)$" \
      <(seqkit subseq -r "1:300" "$dir"/"$file") \
      <(seqkit subseq -r "-300:-1" "$dir"/"$file") |
      cat /dev/stdin "$file".fl.fasta "$file".fr.fasta "$file".rl.fasta "$file".rr.fasta |
      seqkit rmdup -s | # remove duplicated reads
      clustalo -i - -t DNA --infmt=fasta --dealign --output-order=tree-order --threads=8 --force |
      mafft --thread 8 --add "$dir"/"$file" /dev/stdin \
      > "$file".fasta
  else
    echo "Aligning reads to the contig with clustal-omega ..."
    cat "$dir"/"$file" "$file".fl.fasta "$file".fr.fasta "$file".rl.fasta "$file".rr.fasta |
    seqkit rmdup -s | # remove duplicated reads
    clustalo -i - -t DNA --infmt=fasta --dealign --output-order=tree-order --threads=8 --force > "$file".fasta
  fi

  ## Clean up
  rm "$file".fl.fasta "$file".fr.fasta "$file".rl.fasta "$file".rr.fasta

done

if [[ -e "$dir"/*.fai ]]; then rm "$dir"/*.fai; fi
  
