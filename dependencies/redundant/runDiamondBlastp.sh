#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 26.07.17
# Title: runDiamondBlastp.sh
# Goal: To run blastp to identify top blast hit per sequence
# Usage: ./run_diamondblastp.sh {sample} {aa.fa} {database}
# ------------------------------------------------------------------

echo "Commencing runDiamondBlastp.sh at $(date)"

# ------------------------------------------------------------------
# Check and prepare arguments
# ------------------------------------------------------------------

# Check if correct number of arguments (n = 3) provided
if [ $# != 3 ]; then
    echo "...ERROR: 3 arguments expected - exiting!"
    exit 1
fi

# Rename variables
sample=$1 	#short sample name
amino=$2 	#fasta file
db=$3

# ------------------------------------------------------------------
# Run diamond blastp
# ------------------------------------------------------------------

# Run diamond blastp
diamond blastp --sensitive --db "$db" --query "$amino" --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_blastp.out

# ------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------

echo "Completed runDiamondBlastp.sh at $(date)"


