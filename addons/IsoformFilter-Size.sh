#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 22 November 2018
# Title: IsoformFilter-SizeNoClusters.sh
# Goal: To filter to remove redundant TRINITY isoforms and Transdecoder *|m.xxxx sequences (where the longest isoform is selected).
# Usage: IsoformFilter-Size.sh {species} {fasta/s to filter}
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


# The script is happy to have plain file IDs (e.g. myfile) or paths (e.g. /path/to/myfile)

# ----------------
# rename variables
# ----------------

species=$1
fasta=$2
	fasta_string=$(echo "$fasta" | sed 's/,/ /g')
	main_fasta=$(echo "$fasta" | cut -f 1 -d ",")

# -----------------------------------------
# Select longest *ixx|m.xxxxxx ORF per family
# -----------------------------------------

fastalength "$main_fasta" | sed 's/ /\t/g' | awk '{print $2, $2, $1}' | sed 's/ /\t/g' | sed 's/_i[0-9]*|m\.[0-9]*\t/\t/' | sort -grk3,3 | sort -u -k1,1 | cut -f 2,2 | sort > "$species"_seqToGet

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
rm "$species"_seqToGet

# -----------------------------------------
# Done
# -----------------------------------------

echo -e "Isoform filtering by size complete for sample "$species" at $(date).\nYour output is in $(pwd).\nFile/s *.filtered.fa contain the filtered fasta sequences\n\nScript made by Laura Grice 22.11.18"
