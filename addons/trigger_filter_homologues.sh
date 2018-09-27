#!/bin/bash
set -e
# ------------------------------------------------------------------
# Author:	Laura Grice
# Title:	trigger-redundancyfilt.sh
# Version:	v01.01
# Goal:		To feed the samples in to addons/filter_homologues.sh
# Requirements:	The user must have already made a tab-delimited file ("input_param") listing the sample ID and file location of each transcriptome of interest
# Usage:	nohup ./TriggerPipeline.sh {paramfile} {wkdir} {blastdb} {blastfasta} {email} > TransPipeline_nohup.out 2>&1&
# Basically, call exactly the same way as trigger_assembly2orf.sh
# ------------------------------------------------------------------
# VERSION INFORMATION
# v01.00 28 July 2017
# v01.01 19 January 2018
# Updated to run on Asellus
# ------------------------------------------------------------------
# TO DO
# Add "email" as a sixth parameter if/when the "mail" command is installed on Asellus
# ------------------------------------------------------------------


# ------------------------------------------------------------------
# Check and prepare arguments
# ------------------------------------------------------------------

# Check if correct number of arguments (n = 5) provided
if [ $# != 5 ]; then
    echo "...ERROR: 5 arguments expected for TriggerPipeline - exiting!"
    exit 1
fi

# Rename variables
paramfile=$1 	#location of "input_param" file, full file string
wkdir=$2 	#desired working directory location
blastdb=$3	#location of the blast database to use
blastfasta=$4	#location of the fasta file used to create this blastdb
email=$5	#user email to recieve email at the end of the run

# set location of dependencies - user can change this if required
scriptlib=/home/laura/scripts/assembly2orf/addons

#######################
## FILTER REDUNDANCY ##
#######################

echo -e filtering sequence redundancy with BLASTp at $(date) @
## NB: This approach is based on that from Ono et al. BMC Genomics (2015) 16:1031

# Make sure I am back in the right place
cd "$wkdir"/"$sample" || { echo "could not return to sample directory - exiting! @"; exit 1 ; }
mkdir "$wkdir"/"$sample"/redundancy
cd "$wkdir"/"$sample"/redundancy || { echo "could not return to sample directory - exiting! @"; exit 1 ; }

# Run BLAST search
diamond blastp --sensitive --db "$blastDB" --query "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 100 | sort -u -k1,1 > "$sample"_TrinityFS.fa.transdecoder.pep_blastp.out

# Perform redundancy filtration
$scriptlib/filter_homologues.sh "$sample" "$sample"_TrinityFS.fa.transdecoder.pep_blastp.out "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.pep
mv "$sample"_representatives.fa "$sample"_representatives.pep.fa

# Extract the same representatives from .cds and .mrna files
grep ">" "$sample"_representatives.pep.fa | sed 's/>//g' | sort > "$sample"_representatives.list
fasta_formatter -t -i "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.cds | sort -k1,1 > ./"$sample"_allsequences.cds.tab
fasta_formatter -t -i "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.mRNA | sort -k1,1 > ./"$sample"_allsequences.mRNA.tab
# make a table of sequences of interest
join "$sample"_representatives.list "$sample"_allsequences.cds.tab | sed 's/ /\t/g' | awk '{print $1, $NF}' | sed 's/ /\t/g' > "$sample"_seqofinterest.cds.tab
join "$sample"_representatives.list "$sample"_allsequences.mRNA.tab | sed 's/ /\t/g' | awk '{print $1, $NF}' | sed 's/ /\t/g' > "$sample"_seqofinterest.mRNA.tab
# convert to fasta 
sed 's/^/>/g' "$sample"_seqofinterest.mRNA.tab | sed 's/\t/\n/g' > "$sample"_representatives.mRNA.fa
sed 's/^/>/g' "$sample"_seqofinterest.cds.tab | sed 's/\t/\n/g' > "$sample"_representatives.cds.fa

# Tidy up
for i in "$sample"_representatives.list "$sample"_allsequences.cds.tab "$sample"_allsequences.mRNA.tab "$sample"_seqofinterest.cds.tab "$sample"_seqofinterest.mRNA.tab
	do
	rm $i
done

# Make a note in the spec file about the redundancy filtration step
cat >> "$wkdir"/"$sample"/"$sample"_specfile <<COMMENT
STEP 4: REDUNDANCY FILTRATION
	Tool: $(diamond --version)
	BLASTp Command: diamond blastp --sensitive --db $blastDB --query $(echo $wkdir)/$(echo $sample)/$(echo $sample)_transDecoder/output_files/$(echo $sample)_TrinityFS.fa.transdecoder.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 100 | sort -u -k1,1 > $(echo $sample)_TrinityFS.fa.transdecoder.pep_blastp.out
	Tool: $(fastaremove | head -n 1)
	Tool: $(fasta_formatter -h | head -n 2 | tail -n 1)
COMMENT
