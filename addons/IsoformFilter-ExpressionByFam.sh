#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 22 November 2018
# Title: IsoformFilter-ExpressionByFam.sh
# Goal: To filter WITHIN gene families to remove redundant TRINITY isoforms and Transdecoder *|m.xxxx sequences
# Usage: IsoformFilter-Expression.sh {species} {fasta/s to filter} {fnodes} {kallisto matrix}
# ------------------------------------------------------------------

# Assumptions and requirements
# assembly2orf output (.cds or .pep OK)
	# OPTIONAL: You can input multiple files as long as they have identical sequence IDs (e.g. cds and pep) - separate with a comma: file1,file2
		# The first file will be used to pull out sequences of interest and to calculate sizes for the |m.... duplicate ORFs - the order shouldn't matter too much but it may be a bit quicker to calculate lengths for .pep files than .cds files
	# The names should look like:
	# PAL6_TRINITY_DN28196_c3_g1_i12|m.16421
		# Where PAL6 = species code
		# TRINITY_DN28196_c3_g1_i12 is a code output by Trinity (the script won't work if there's not a T at the start of this bit)
		# |m.16421 is a code appended by Transdecoder (in assembly2orf)
# tab-delimited gene family table
	# col1 = gene family, col2 = gene ID
	# this should only contain genes from your species of interest
# gene count matrix
	# must be a Kallisto matrix (abundance.tsv)
	# or any 5-column tsv file where col1 = gene ID, col5 = tpm

# The script is happy to have plain file IDs (e.g. myfile) or paths (e.g. /path/to/myfile)

# ----------------
# rename variables
# ----------------

species=$1
fasta=$2
	fasta_string=$(echo "$fasta" | sed 's/,/ /g')
	main_fasta=$(echo "$fasta" | cut -f 1 -d ",")
	# get a reference of fasta names
	grep ">" "$main_fasta" | sed 's/>//g' | awk '{print $1, $1}' | sed 's/ /\t/g' | sed 's/^[0-9a-zA-Z]*_//' | sort -k1,1 > "$species"_nameReference
fnodes_unsorted=$3
	sort -k2,2 "$fnodes_unsorted" > $(basename "$fnodes_unsorted")_"$species"_sorted
	fnodes=$(basename "$fnodes_unsorted")_"$species"_sorted
counts_unsorted=$4
	sort -k1,1 "$counts_unsorted" > $(basename "$counts_unsorted")_"$species"_sorted
	counts=$(basename "$counts_unsorted")_"$species"_sorted

# -----------------------------------------
# Select longest |m.xxxxxx ORF per family
# -----------------------------------------

# TransDecoder can output multiple ORFs per isoform (e.g. PAL6_TRINITY_DN28196_c3_g1_i12|m.16421 and PAL6_TRINITY_DN28196_c3_g1_i12|m.16422). This step will select the longest ORF per isoform within a gene family. If different ORFs are present in different gene families, they will not be filtered.

fastalength "$main_fasta" | sed 's/ /\t/g' | sort -k2,2 > "$species"_size

join -1 2 -2 2 "$fnodes" "$species"_size | sed 's/ /\t/g' | awk '{print $1, $1, $2, $3}' | sed 's/ /\t/g' | sed 's/|m\.[0-9]*\t/\t/' | awk '{print $1, $3, $2, $4}' | sed 's/ /#/' | sed 's/ /\t/g' | sort -nrk3,3 | sort -u -k1,1 | cut -f 2 | sort > "$species"_uniqORFs

# -----------------------------------------
# Get fnodes with redundant ORFs removed
# -----------------------------------------

join -1 1 -2 2 "$species"_uniqORFs "$fnodes" | sed 's/ /\t/g' | sed 's/[0-9a-zA-Z]*_//' | awk '{print $1, $1, $2}' | sed 's/ /\t/g' | sed 's/|.*\tT/\tT/' | sort -k1,1 > "$species"_familyXref

join "$species"_familyXref "$counts" | sed 's/ /\t/g' | sed 's/_i[0-9]*\t/\t/g' | awk '{print $1, $3, $2, $4, $5, $6, $7}' | sed 's/ /#/' | sed 's/ /\t/g' | sort -grk6,6 | sort -u -k1,1 | cut -f 2 | grep "TRINITY" | sort > "$species"_seqOfInterest

# -----------------------------------------
# Get sequences
# -----------------------------------------

join "$species"_seqOfInterest "$species"_nameReference | sed 's/ /\t/g' | cut -f 2 > "$species"_seqToGet

for input in $(echo "$fasta_string")
	do
	~/scripts/software/UCSC/faSomeRecords "$input" "$species"_seqToGet $(basename "$input").filtered.fa
done

# -----------------------------------------
# Make a reference showing removed sequences
# -----------------------------------------

# This is the rate limiting step so it is commented out by default

# makes a list of ORFs removed within a family
# i.e. 2+ *|m.xxxxxx versions within one *ix isoform
#grep -v -f "$species"_uniqORFs "$fnodes" | cut -f 2 > "$species"_ORFs_removed

# makes a list of isoforms removed within a family
# i.e. 2+ *ix isoforms within one *gx gene
#grep -v -f "$species"_seqToGet "$species"_uniqORFs > "$species"_isoforms_removed 

# -----------------------------------------
# Cleanup
# -----------------------------------------
rm "$species"_nameReference $(basename "$fnodes_unsorted")_"$species"_sorted "$species"_size "$species"_uniqORFs "$species"_familyXref "$species"_seqOfInterest "$species"_seqToGet $(basename "$counts_unsorted")_"$species"_sorted

# -----------------------------------------
# Done
# -----------------------------------------

echo -e "Isoform filtering complete for sample "$species" at $(date).\nYour output is in $(pwd).\nFile/s *.filtered.fa contain the filtered fasta sequences.\nFile "$species"_ORFs_removed lists Transdecoder ORFs which were filtered by size and file "$species"_isoforms_removed lists Trinity isoforms which were filtered by expression.\n\nScript made by Laura Grice 22.11.18"
