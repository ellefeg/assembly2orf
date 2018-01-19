#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 27.07.17
# Title: run_hmmscan.sh
# Goal: To run hmmscan
# Usage: ./run_hmmscan.sh {sample name} {amino acid file}
# ------------------------------------------------------------------

echo "Commencing run_hmmscan.sh at $(date)"

# ------------------------------------------------------------------
# Check and prepare arguments
# ------------------------------------------------------------------

# Check if correct number of arguments (n = 2) provided
if [ $# != 2 ]; then
    echo "...ERROR: 2 arguments expected - exiting!"
    exit 1
fi

# Rename variables
sample=$1 	#short sample name
amino=$2 	#amino acid fasta file

# ------------------------------------------------------------------
# Run hmmscan
# ------------------------------------------------------------------

# Run hmmscan
hmmscan --cpu 2 --domE 0.00001 -E 0.00001 --domtblout "$sample"_domtblout /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm "$amino"

# ------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------

echo "Completed run_hmmscan.sh at $(date)"
