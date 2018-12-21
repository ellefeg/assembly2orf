#!/bin/bash
set -e
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 18 July 2017
# Title: PairwiseExonerate.sh 
# Goal: To run Exonerate in a pairwise fashion between matched nt-aa blast pairs
# Usage: nohup ./PairwiseExonerate.sh {sample name} {blast results} {nt.fa} {BlastDB.fa} > nohup.out 2>&1&
# ------------------------------------------------------------------

# Change Log -------------------------------------------------------
# EDIT 19.07.17
## Added section "remove duplicates" to remove 100% identical sequences (same name, same sequence)
## Also wrote a separate script "CigarExonerate.sh" which produced Cigar output only (see "versions" folder)
# Edit 20.07.17
## Altered command to produce fasta and Cigar output in separate files
# EDIT 21.07.17
## Altered output to produce fasta file containing ONLY edited sequences (full fasta files will be in temp folder)
# EDIT 25.07.17
## Altered output to produce fasta file containing edited sequences + the rest of the transcriptome
# EDIT 22.01.18
## Revised comments, slight changes to filtering identical sequences
## Included CD-HIT-EST command to remove redundant sequences
# ------------------------------------------------------------------

##########################
###  Getting Started   ###
##########################

# Run BLASTx with nt.fa and database of interest (--outfmt 6)
# You need to know the following information: (1) short name for sample (2) blast output [of #3 vs db of #4] (3) nt.fa (4) aa.fa underlying BLASTx db

#################################
###  Prepare pairwise table   ###
#################################

# Creates a table matching header+sequence of query with header+sequence of hit/subject. In the next step this table will be read line-by-line so Exonerate knows which two sequences to match up
## Approach: use the "query" column of the blast hit table to pull out the nucleotide sequence information, and then use the "subject" column to pull out the amino acid sequence information
## NB: Columns will be {aa name} {aa seq} {nt name} {nt seq}
## NB: Allows for duplicates in the subject protein list (i.e. the same aa sequence can be the best hit for multiple nt queries)
echo "Running Pairwise Exonerate at $(date)"

# Renaming variables
sample=$1	#sample short name
blastOut=$2	#blast hits
nucleo=$3	#nucleotide query fasta
amino=$4	#blastDb fasta
aminoName=$(basename "$amino")

# Convert $nucleo and $amino fasta files to tabular format and simplify fasta header names
## NB: The first tab removal step will not change anything in most cases - it is simply to prevent any problems with printing the right columns in case the fasta file is weirdly formatted
## NB: The awk $NF is used to select the LAST column, and is used instead of sed $3 in case sequences lack headers
sed 's/\t/ /g' "$nucleo" | fasta_formatter -t | sort -k1,1 | sed 's/ /\t/' | awk '{print $1, $NF}' > "$nucleo".tab
sed 's/\t/ /g' "$amino" | fasta_formatter -t | sort -k1,1 | sed 's/ /\t/' | awk '{print $1, $NF}' > "$aminoName".tab
# Convert $blastOut to sorted table showing query-hit pairs
cut -f1-2 "$blastOut" | sort -k1,1 > "$blastOut".tab
#Assign nicer variable names
nucleotab="$nucleo".tab		#the tabular nt file we just made
aminotab="$aminoName".tab		#the tabular aa file we just made
blasttab="$blastOut".tab	#the tabular blast query-hit file we just made

# Merge $blasttab and $nucleotab
## NB: Columns will be {nt name} {aa name} {nt seq}
join $blasttab $nucleotab | sed 's/ /\t/g' | sort -k2,2 > "$blasttab"_nt
# Merge "$blasttab"_nt and $aminotab
## NB: Columns will be {aa name} {nt name} {nt seq} {aa seq}
join "$blasttab"_nt $aminotab -1 2 -2 1 | sed 's/ /\t/g' > "$blasttab"_nt+aa
# Arrange columns
## NB: Columns will be {aa name} {aa seq} {nt name} {nt seq}
awk '{OFS="\t"; print $1, $4, $2, $3}' "$blasttab"_nt+aa > "$sample"_pairedSeqTab
# Pairwise sequence table is complete
echo -e "Pairwise sequence table "$sample"_pairedSeqTab complete at $(date).\\n"

#############################
###  Linewise Exonerate   ###
#############################

# Reads the pairwise table line-by-line, converts entries back to fasta sequences, runs exonerate
echo "Commencing $(wc -l < "$sample"_pairedSeqTab) Exonerate analyses at $(date)"

# Performs each pairwise comparison
while read aaName aaSeq ntName ntSeq; do
	echo -e ">"$aaName"\n"$aaSeq > tempAA.fa
	echo -e ">"$ntName"\n"$ntSeq > tempNT.fa
	
	# Now we run exonerate
	# this is the key part of the program - how does it work?
		# tempNT.fa = nt sequence of query sequence (from your dataset); tempAA.fa = aa sequence of reference sequence (from BLAST database)
		# Exonerate aligns the query-nt and the subject-aa.
		# The "normal" alignment view is repressed but CIGAR output ("operation, length" pairs: where operation = match/insertion/deletion and length = length of this operation type) is given
		# The ryo bit exports the resulting sequence - with 1-nt or 2-nt indels (=frameshifts) removed, in fasta format
	exonerate --model protein2dna --query tempAA.fa --target tempNT.fa --verbose 0 --showalignment 0 --showvulgar no --showcigar yes -n 1 --ryo ">%ti (%tab - %tae)\n%tcs\n" >> "$sample"_exonerateTemp.out
	
	echo "^    completed Exonerate for "$ntName" (n sequences = $(grep -c ">" "$sample"_exonerateTemp.out))"
	rm tempAA.fa tempNT.fa
done < "$sample"_pairedSeqTab


#############################################################
###  Split Cigar and Sequence Output, Filter Redundancy   ###
#############################################################

# Added/modified 20 July 2017, 21 July 2017, 22 Jan 2018
# At this stage, "$sample"_exonerateTemp.out contains Cigar alignments and fasta sequences of FS corrected sequences - split up into separate Cigar and Fasta files

# Extract all Cigar alignments
echo -e "\nExtracting Cigar output"
grep "cigar:" "$sample"_exonerateTemp.out | sort | uniq > "$sample"_exonerateCigar.out #extract all unique Cigar rows
# Extract only Cigar alignments with frameshift correction
## NB: A frameshift correction has occurred if the Cigar code contains "D" or "I" (i.e. a deletion/insertion relative to the reference)
grep "cigar:" "$sample"_exonerateCigar.out | cut -f 6,11- -d " " | sed 's/ /\t/' | awk -F"\t" '$2 ~ /D|I/' > "$sample"_exonerateCigarFS.out
echo -e "There are $(wc -l < "$sample"_exonerateCigarFS.out) frameshift-corrected sequences with an average of $(cut -f 2 "$sample"_exonerateCigarFS.out | sed 's/ //g;s/[0-9]//g' | sed 's/DI/x/g;s/ID/y/g' | sed 's/M//g' | awk '{ print length }' | awk '{sum+=$1} END {print sum / NR}') frameshifts each.\n"
# Get non-redundant list of changed genes
cut -f 1 "$sample"_exonerateCigarFS.out | sort -k1,1 | uniq > "$sample"_FScorrectedgenes.list

# Extract fasta sequences 
echo "Extracting fasta output"
grep -v "cigar:" "$sample"_exonerateTemp.out | fasta_formatter -w 0 | fasta_formatter -t | sed 's/ //g' | sort | uniq | sed 's/ /\t/g' | sed 's/^/>/g' | sed 's/\t/\n/g' > "$sample"_exonerateFastaAllTested.out
#Extract only fasta sequences with frameshift correction
grep -v "cigar:" "$sample"_exonerateTemp.out | fasta_formatter -w 0 | fasta_formatter -t | sed 's/ (/\t/' | sed 's/ //g' | awk '{print $1,$3}' | sort | uniq | sed 's/ /\t/g' | sort -k1,1 > "$sample"_exonerateFastaAll.tab
join "$sample"_FScorrectedgenes.list "$sample"_exonerateFastaAll.tab | sed 's/ /\t/g' | sed 's/^/>/g' | sed 's/\t/\n/g' > "$sample"_exonerateFasta_FScorrected.fa

##############################################
###  Merge Changed + Unchanged Sequences   ###
##############################################

# Make a full dataset (fixed + unfixed)
fastaremove -f $nucleo -r "$sample"_FScorrectedgenes.list > uncorrectedgenes.fa
cat uncorrectedgenes.fa >> "$sample"_TrinityFS_redundant.fa
cat "$sample"_exonerateFasta_FScorrected.fa >> "$sample"_TrinityFS_redundant.fa
# Remove sequence redundancy (100% ID)
cd-hit-est -i "$sample"_TrinityFS_redundant.fa -o "$sample"_TrinityFS.fa -c 1

# Exonerate analysis is complete
echo -e "Exonerate runs complete at $(date). Run statistics:\n\t>Number of starting sequences: $(grep -c ">" "$nucleo")\n\t>Number of BLAST hits: $(wc -l < "$sample"_pairedSeqTab)\n\t>Number of frameshift-corrected sequences: $(grep -c ">" "$sample"_exonerateFasta_FScorrected.fa)\n\t>Total non-redundant sequence set (changed + unchanged): $(grep -c ">" "$sample"_TrinityFS.fa)"

#################
###  Tidy Up  ###
#################

echo -e "Tidying up!\n"

# Make a directory to store temporary files
echo -e "Making a temp directory!\n"
mkdir "$sample"_tempfiles

#Move temporary files to new directory

#rename output
echo -e "Renaming files!\n"
mv "$sample"_exonerateFasta_FScorrected.fa "$sample"_FScorrectedonly.fa
mv "$sample"_exonerateCigarFS.out "$sample"_FScorrected.cigar

echo -e "Removing reference database tab file!\n"
rm "$aminotab"

echo -e "Removing unnecessary files!\n"
for i in "$nucleo".tab "$blastOut".tab "$blasttab"_nt "$blasttab"_nt+aa "$sample"_pairedSeqTab "$sample"_exonerateTemp.out "$sample"_exonerateCigar.out "$sample"_FScorrectedgenes.list "$sample"_exonerateFastaAll.tab "$sample"_exonerateFastaAllTested.out uncorrectedgenes.fa "$sample"_TrinityFS_redundant.fa "$sample"_FScorrected.cigar "$sample"_FScorrectedonly.fa "$sample"_TrinityFS.fa.clstr
	do
	mv $i "$sample"_tempfiles
done

echo -e "Frameshift correction analysis complete at $(date).\nWhere are the output files?\n\t> Working directory: $(pwd)\n\t> Final whole-transcriptome file: "$sample"_TrinityFS.fa \n\t> Final corrected sequences only: "$sample"_FScorrectedonly.fa (in temp dir)\n\t> Corrected cigar output: "$sample"_FScorrected.cigar (in temp dir)\n\t> Temporary file directory: "$sample"_tempfiles"

