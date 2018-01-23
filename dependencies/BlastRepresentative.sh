#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 25.07.17
# Title: BlastRepresentative.sh
# Goal: To collapse BLAST hits to the same subject
# Usage: nohup ./BlastRepresentative.sh {sample name} {blast results} {nt.fa} > nohup.out 2>&1&
# ------------------------------------------------------------------

##########################
###  Getting Started   ###
##########################

# Run BLASTx with nt.fa and database of interest (--outfmt 6)
# You will need: (1) short name for sample (2) blast output (3) nt.fa

############################
###  Extract Sequences   ###
############################

echo "Collapsing redundant blast hits to generate non-redundant sequence set"

# Renaming variables
echo "...renaming variables"
sample=$1 #sample short name
blastOut=$2 #blast hits
nucleo=$3 #nucleotide query fasta

# Extract representative sequences
echo "...extracting representative BLAST results"
awk '{print $1, $2, $NF}' "$blastOut" | sed 's/ /\t/g' | sort -nrk3,3 | sort -u -k2,2 > blastrep.tab
cut -f 1 blastrep.tab > blastrep.list

# Extract sequences without blast hit
echo "...extracting sequences without BLAST hits"
cut -f 1 "$blastOut" > allblast.list
fastaremove -f "$nucleo" -r allblast.list | grep ">" | sed 's/>//g' | cut -f 1 -d " " > notblast.list

# Make list of sequences of interest (no blast hit + representative blast hits)
echo "...listing sequences of interest"
cat blastrep.list >> seqofinterest.list
cat notblast.list >> seqofinterest.list
sort seqofinterest.list -o seqofinterest.list

# Get the sequences of interest
echo "...extracting sequences of interest"
fasta_formatter -t -i "$nucleo" | sort -k1,1 > "$sample"_fasta.tab
join seqofinterest.list "$sample"_fasta.tab | sed 's/ /\t/g' | awk '{print $1, $NF}' | sed 's/ /\t/g' > seqofinterest.tab
echo "...converting to fasta format with tab2fa.sh"
~/scripts/tab2fa.sh seqofinterest.tab "$sample"_representatives.fa

#tidy
echo "Tidying up!"
rm "$sample"_fasta.tab seqofinterest.tab seqofinterest.list notblast.list allblast.list blastrep.list blastrep.tab

echo "Done!"

