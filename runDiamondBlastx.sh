#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 26.07.17
# Title: runDiamondBlastx.sh
# Goal: To run blastx to identify top blast hit per sequence
# Usage: ./run_diamondblastx.sh {sample} {nt.fa} {database}
# ------------------------------------------------------------------

echo "Commencing runDiamondBlastx.sh at $(date)"

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
nucleo=$2 	#fasta file
db=$3

# ------------------------------------------------------------------
# Run diamond blastx
# ------------------------------------------------------------------

# Run diamond blastx
diamond blastx --sensitive --db "$db" --query "$nucleo" --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_blastx.out

# ------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------

echo "Completed runDiamondBlastx.sh at $(date)"
