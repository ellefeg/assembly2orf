#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 22 November 2018
# Title: IsoformFilter-ExpressionNoClusters.sh
# Goal: To filter to remove redundant TRINITY isoforms and Transdecoder *|m.xxxx sequences
# Usage: IsoformFilter-Expression.sh {species} {fasta/s to filter} {kallisto matrix}
# ------------------------------------------------------------------

# Assumptions and requirements
# assembly2orf output (.cds or .pep OK)
	# This is the "filter second" process - i.e. filtering isoforms AFTER assembly2orf - which in trials seemed to give better results than filtering directly from the Trinity
	# OPTIONAL: You can input multiple files as long as they have identical sequence IDs (e.g. cds and pep) - separate with a comma: file1,file2
		# The first file will be used to pull out sequences of interest and to calculate sizes for the |m.... duplicate ORFs - the order shouldn't matter too much but it may be a bit quicker to calculate lengths for .pep files than .cds files
	# The names should look like:
	# PAL6_TRINITY_DN28196_c3_g1_i12|m.16421
		# Where PAL6 = species code
		# TRINITY_DN28196_c3_g1_i12 is a code output by Trinity (the script won't work if there's not a T at the start of this bit)
		# |m.16421 is a code appended by Transdecoder (in assembly2orf)
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
counts_unsorted=$3
	sort -k1,1 "$counts_unsorted" > $(basename "$counts_unsorted")_sorted
	counts=$(basename "$counts_unsorted")_sorted

# -----------------------------------------
# Select longest |m.xxxxxx ORF per family
# -----------------------------------------

# TransDecoder can output multiple ORFs per isoform (e.g. PAL6_TRINITY_DN28196_c3_g1_i12|m.16421 and PAL6_TRINITY_DN28196_c3_g1_i12|m.16422). This step will select the longest ORF per isoform.
# The command works out the size of each *|m.xxxxxx ORF. For each line it prints the full ORF ID plus the isoform ID. Then it sorts sorts longest-to-shortest for each ORF and selects the biggest ORF for each isoform. These longest unique ORFs will be used as input to determine the most expressed isoform per gene.

fastalength "$main_fasta" | sed 's/ /\t/g' | awk '{print $2, $2, $1}' | sed 's/ /\t/g' | sed 's/|m\.[0-9]*\t/\t/' | sort -nrk3,3 | sort -u -k1,1 | sed 's/^[0-9a-zA-Z]*_//' | cut -f 1-2 | sort -k1,1 > "$species"_uniqORFs

# -----------------------------------------
# Join to Kallisto table and get most expressed isoforms
# -----------------------------------------

join "$species"_uniqORFs "$counts" | sed 's/ /\t/g' | awk '{print $1, $1, $2, $3, $4, $5, $6}' | sed 's/ /\t/g' | sed 's/_i[0-9]*\t/\t/' | sort -grk7,7 | sort -u -k1,1 | grep "TRINITY" | cut -f 3 | sort > "$species"_seqToGet

# -----------------------------------------
# Get sequences
# -----------------------------------------

for input in $(echo "$fasta_string")
	do
	~/scripts/software/UCSC/faSomeRecords "$input" "$species"_seqToGet $(basename "$input").filtered.fa
done

# -----------------------------------------
# Cleanup
# -----------------------------------------
#rm "$species"_nameReference $(basename "$fnodes_unsorted")_sorted "$species"_size "$species"_uniqORFs "$species"_familyXref "$species"_seqOfInterest "$species"_seqToGet $(basename "$counts_unsorted")_sorted

rm "$species"_nameReference $(basename "$counts_unsorted")_sorted "$species"_uniqORFs "$species"_seqToGet

# -----------------------------------------
# Done
# -----------------------------------------

echo -e "Isoform filtering complete for sample "$species" at $(date).\nYour output is in $(pwd).\nFile/s *.filtered.fa contain the filtered fasta sequences.\n\nScript made by Laura Grice 26.11.18"
