#!/bin/bash
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
# ------------------------------------------------------------------

##########################
###  Getting Started   ###
##########################

# Run BLASTx with nt.fa and database of interest (--outfmt 6)
# Optional: Run /home/laura/scripts/Blast2SplitHits.sh to retrieve sequences without BLAST hits (required for TransDecoder downstream)
# You will need: (1) short name for sample (2) blast output (3) nt.fa (4) aa.fa underlying database used for BLASTx

#################################
###  Prepare pairwise table   ###
#################################

# Creates a table with headers/sequences of each blast pair
## NB: Allows for duplicates in the protein list (i.e. the same protein appearing multiple times)
## NB: Columns will be {aa name} {aa seq} {nt name} {nt seq}

echo "Preparing pairwise table at $(date)"

# Renaming variables
echo "...renaming variables"
sample=$1 #sample short name
blastOut=$2 #blast hits
nucleo=$3 #nucleotide query fasta
amino=$4 #blastDb fasta

# Convert $nucleo and $amino to sorted tables with simple names
## NB: Start with a command to remove tabs so there shouldn't be any problems in printing the right columns
## NB: Use awk $NF to select the LAST column. Use instead of sed $3 in case sequences lack headers
echo "...generating and sorting data tables"
sed 's/\t/ /g' "$nucleo" | fasta_formatter -t | sort -k1,1 | sed 's/ /\t/' | awk '{print $1, $NF}' > "$nucleo".tab
sed 's/\t/ /g' "$amino" | fasta_formatter -t | sort -k1,1 | sed 's/ /\t/' | awk '{print $1, $NF}' > "$amino".tab
# Convert $blastOut to sorted table
cut -f1-2 "$blastOut" | sort -k1,1 > "$blastOut".tab
#Assign nicer variable names
nucleotab="$nucleo".tab
aminotab="$amino".tab
blasttab="$blastOut".tab

# Merge $blasttab and $nucleotab
## NB: Columns will be {nt name} {aa name} {nt seq}
echo "...adding nucleotide data to table"
join $blasttab $nucleotab | sed 's/ /\t/g' | sort -k2,2 > "$blasttab"_nt

# Merge "$blasttab"_nt and $aminotab
## NB: Columns will be {aa name} {nt name} {nt seq} {aa seq}
echo "...adding amino acid data to table"
join "$blasttab"_nt $aminotab -1 2 -2 1 | sed 's/ /\t/g' > "$blasttab"_nt+aa

# Arrange columns
## NB: Columns will be {aa name} {aa seq} {nt name} {nt seq}
echo "...reorganising sequence table"
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
	echo "^^...analysing "$ntName""
	echo -e ">"$aaName"\n"$aaSeq > tempAA.fa
	echo -e ">"$ntName"\n"$ntSeq > tempNT.fa
	exonerate --model protein2dna --query tempAA.fa --target tempNT.fa --verbose 0 --showalignment 0 --showvulgar no --showcigar yes -n 1 --ryo ">%ti (%tab - %tae)\n%tcs\n" >> "$sample"_exonerateTemp.out
	echo "^    completed Exonerate for "$ntName" (n sequences = $(grep -c ">" "$sample"_exonerateTemp.out))"
	rm tempAA.fa tempNT.fa
done < "$sample"_pairedSeqTab

##################################################################
###  Split Output, Remove Duplicates, Select Fixed Sequences   ###
##################################################################

# Added/modified 20 July 2017, 21 July 2017

# The output currently contains Cigar alignments plus fasta sequences - split up, and remove duplicates

# Extract Cigar alignments
echo -e "\nExtracting Cigar output"
grep "cigar:" "$sample"_exonerateTemp.out | sort | uniq > "$sample"_exonerateCigar.out
echo "...extracted $(grep -c "cigar:" "$sample"_exonerateCigar.out) alignments. NB: $(($(grep -c "cigar:" "$sample"_exonerateTemp.out)-$(grep -c "cigar:" "$sample"_exonerateCigar.out))) duplicates removed."
#Extract only Cigar alignments with frameshift correction
grep "cigar:" "$sample"_exonerateCigar.out | cut -f 6,11- -d " " | sed 's/ /\t/' | awk -F"\t" '$2 ~ /D|I/' > "$sample"_exonerateCigarFS.out
echo -e "There are $(wc -l < "$sample"_exonerateCigarFS.out) frameshift-corrected sequences with an average of $(cut -f 2 "$sample"_exonerateCigarFS.out | sed 's/ //g;s/[0-9]//g' | sed 's/DI/x/g;s/ID/y/g' | sed 's/M//g' | awk '{ print length }' | awk '{sum+=$1} END {print sum / NR}') frameshifts each.\n"
# Get list of changed genes
cut -f 1 "$sample"_exonerateCigarFS.out | sort -k1,1 > "$sample"_FScorrectedgenes.list

# Extract fasta sequences 
echo "Extracting fasta output"
grep -v "cigar:" "$sample"_exonerateTemp.out | fasta_formatter -w 0 | fasta_formatter -t | sed 's/ //g' | sort | uniq | sed 's/ /\t/g' | sed 's/^/>/g' | sed 's/\t/\n/g' > "$sample"_exonerateFastaAllTested.out
#Extract only fasta sequences with frameshift correction
grep -v "cigar:" "$sample"_exonerateTemp.out | fasta_formatter -w 0 | fasta_formatter -t | sed 's/ (/\t/' | sed 's/ //g' | awk '{print $1,$3}' | sort | uniq | sed 's/ /\t/g' | sort -k1,1 > "$sample"_exonerateFastaAll.tab
join "$sample"_FScorrectedgenes.list "$sample"_exonerateFastaAll.tab | sed 's/ /\t/g' | sed 's/^/>/g' | sed 's/\t/\n/g' > "$sample"_exonerateFasta_FScorrected.fa
echo -e "...extracted $(grep -c ">" "$sample"_exonerateFasta_FScorrected.fa) edited sequences. NB: $(($(grep -c ">" "$sample"_exonerateTemp.out)-$(grep -c ">" "$sample"_exonerateFastaAllTested.out))) duplicates removed.\n"

# Make a full dataset (fixed + unfixed)
fastaremove -f $nucleo -r "$sample"_FScorrectedgenes.list > uncorrectedgenes.fa
cat uncorrectedgenes.fa >> "$sample"_TrinityFS.fa
cat "$sample"_exonerateFasta_FScorrected.fa >> "$sample"_TrinityFS.fa

# Exonerate analysis is complete
echo "Exonerate runs complete at $(date)."
echo -e "...started with $(wc -l < "$sample"_pairedSeqTab) sequences, analysed $(grep -c ">" "$sample"_exonerateFastaAllTested.out) and ended with $(grep -c ">" "$sample"_exonerateFasta_FScorrected.fa) edited sequences\n"

#################
###  Tidy Up  ###
#################

echo -e "Tidying up!\n"

# Make a directory to store temporary files
mkdir "$sample"_tempfiles

#Move temporary files to new directory

#rename output
mv "$sample"_exonerateFasta_FScorrected.fa "$sample"_FScorrected.fa
mv "$sample"_exonerateCigarFS.out "$sample"_FScorrected.cigar

for i in "$nucleo".tab "$amino".tab "$blastOut".tab "$blasttab"_nt "$blasttab"_nt+aa "$sample"_pairedSeqTab "$sample"_exonerateTemp.out "$sample"_exonerateCigar.out "$sample"_FScorrectedgenes.list "$sample"_exonerateFastaAll.tab "$sample"_exonerateFastaAllTested.out uncorrectedgenes.fa
	do
	mv $i "$sample"_tempfiles
done

echo -e "Frameshift correction analysis complete at $(date).\nWhere are the output files?\n\t> Working directory: $(pwd)\n\t> Final whole-transcriptome file: "$sample"_TrinityFS.fa \n\t> Final corrected sequences only: "$sample"_FScorrected.fa\n\t> Corrected cigar output: "$sample"_FScorrected.cigar\n\t> Temporary file directory: "$sample"_tempfiles"
echo "Exonerate complete for all samples at $(date)" | mail -s "Server alert: Exonerate complete" "lfgrice@gmail.com"

