#!/bin/bash
set -e
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 25.07.17
# Title: BlastRepresentative.sh
# Goal: To collapse BLAST hits to the same subject in a database (as determined by best BIT score)
# Usage: nohup ./BlastRepresentative.sh {sample name} {blast results} {aa.fa} > nohup.out 2>&1&
# ------------------------------------------------------------------
# VERSION INFORMATION
# v01.00 25 July 2017
# v01.01 23 January 2018
# blastp instead of blastx
# ------------------------------------------------------------------

##########################
###  Getting Started   ###
##########################

# Run BLASTp with aa.fa and database of interest (--outfmt 6)
# You will need: (1) short name for sample (2) blast output (3) aa.fa

############################
###  Extract Sequences   ###
############################

echo "Collapsing redundant blast hits to generate non-redundant sequence set"

# Renaming variables
echo "...renaming variables"
sample=$1 #sample short name
blastOut=$2 #blast hits
amino=$3 #amino acid query fasta

# Extract representative sequences
echo "...extracting representative BLAST results"
awk '{print $1, $2, $NF}' "$blastOut" | sed 's/ /\t/g' | sort -nrk3,3 | sort -u -k2,2 > "$sample"_blastrep.tab
cut -f 1 "$sample"_blastrep.tab > "$sample"_blastrep.list

# Extract sequences without blast hit
echo "...extracting sequences without BLAST hits"
cut -f 1 "$blastOut" > "$sample"_allblast.list
fastaremove -f "$amino" -r "$sample"_allblast.list | grep ">" | sed 's/>//g' | cut -f 1 -d " " > "$sample"_notblast.list

# Make list of sequences of interest (no blast hit + representative blast hits)
echo "...listing sequences of interest"
cat "$sample"_blastrep.list >> "$sample"_seqofinterest.list
cat "$sample"_notblast.list >> "$sample"_seqofinterest.list
sort "$sample"_seqofinterest.list -o "$sample"_seqofinterest.list

# Get the sequences of interest
echo "...extracting sequences of interest"
fasta_formatter -t -i "$amino" | sort -k1,1 > "$sample"_fasta.tab
join "$sample"_seqofinterest.list "$sample"_fasta.tab | sed 's/ /\t/g' | awk '{print $1, $NF}' | sed 's/ /\t/g' > "$sample"_seqofinterest.tab
echo "...converting to fasta format"
sed 's/^/>/g' "$sample"_seqofinterest.tab | sed 's/\t/\n/g' > "$sample"_representatives.fa

#tidy
echo "Tidying up!"
rm "$sample"_fasta.tab "$sample"_seqofinterest.tab "$sample"_seqofinterest.list "$sample"_notblast.list "$sample"_allblast.list "$sample"_blastrep.list "$sample"_blastrep.tab

echo "Done!"

