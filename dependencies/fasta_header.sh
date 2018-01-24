#!/bin/bash
set -e
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 26 July 2017
# Title: fasta_header.sh
# Goal: To pre-process user-input fasta files for further analysis
# Usage: ./fasta_header.sh <sample> <fasta> <append name? y/n>
## User input for "Append name?": YyTt1 or NnFf0
# ------------------------------------------------------------------

echo "Commencing fasta_header.sh at $(date)"

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
fasta=$2 	#fasta file
append=$3 	#append sample name? (y/n)

# Check if valid append statement provided
if [[ "$append" != [nN0FfyY1Tt]* ]]; then
    echo "...ERROR: invalid append argument - exiting!"
    exit 1
fi

# ------------------------------------------------------------------
# Process fasta files
# ------------------------------------------------------------------

echo "...reformatting fasta file"

# Remove fasta header descriptions and unnecessary spaces
sed -e 's/^\(>[^[:space:]]*\).*/\1/' $fasta | sed 's/ //g' > "$sample"_header1

# Format sequences onto single lines
fasta_formatter -w 0 -i "$sample"_header1 -o "$sample"_header2

# OPTIONAL: Add sample name to headers
if [[ "$append" == [nN0Ff]* ]]; then	# First argument starts with either n, N, F, f or 0
	mv "$sample"_header2 "$sample"_header3
    echo "...sample name NOT appended to fasta headers"
elif [[ "$append" == [yY1Tt]* ]]; then	# First argument starts with either y, Y, T, t or 1
	sed "s/>/>"$sample"_/" "$sample"_header2 > "$sample"_header3
	rm "$sample"_header2
    echo "...sample name appended to fasta files"
fi

# ------------------------------------------------------------------
# Tidy up
# ------------------------------------------------------------------

# Rename output file and clean up
rm "$sample"_header1
mv "$sample"_header3 "$sample"_clean.fa

# ------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------

echo "Completed fasta_header.sh at $(date)"
