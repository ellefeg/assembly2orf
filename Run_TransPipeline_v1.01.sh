#!/bin/bash
# ------------------------------------------------------------------
# Author:	Laura Grice
# Title:	Run_TransPipeline.sh #####Change name????#####
# Version:	v01.01
# Goal:		To convert a .fa transcriptome assembly to a filtered set of transcript ORFs
# Usage:	nohup ./Run_TransPipeline.sh {sample} {trinity.fa} {working dir} > nohup.out 2>&1&
# Output:	"$sample"_ORFs.fa which can be used for clustering methods downstream #####CHANGE THIS#####
# ------------------------------------------------------------------
# VERSION INFORMATION
# v01.00 28 July 2017
# v01.01 19 January 2018
# Updated to run on Asellus
# ------------------------------------------------------------------

echo "Welcome to assembly2orf.sh v01.01. It is currently $(date) @"

####################
## INITIALISATION ##
####################

echo "Initialising analysis at $(date) @"

#--------------------------
# Prepare variables
#--------------------------

echo "...setting variables @"

# User-supplied variables
sample=$1	# Brief sample name (sample-specific)
trinity=$2	# Trinity.fa file (sample-specific)
wkdir=$3	# Base working directory
scriptlib=$4	# Location where the scripts live
blastDB=$5	# Location of the blast database
blastFA=$6	# Location of the fasta file used to create the blast database

#--------------------------
# Prepare directories
#--------------------------

echo "...generating sample-specific working directory @"

# Move to working directory
cd "$wkdir" || { echo "Could not move to wkdir - exiting! @"; exit 1 ; }
# Create sample-specific directory
if [ -d "$wkdir"/"$sample" ]
then
    echo "...Sample directory exists. Moving there now. @"
    cd "$wkdir"/"$sample" || { echo "Could not move to sample directory - exiting! @"; exit 1 ; }
else
    echo "...sample directory does not exist. Creating now. @"
    mkdir "$wkdir"/"$sample"
    cd "$wkdir"/"$sample" || { echo "Could not move to sample directory - exiting! @"; exit 1 ; }
fi

#--------------------------
# Prepare parameter specification file
#--------------------------

# This spec file will contain information about the run, intended for reproducibility/writing up methods
touch "$sample"_specfile
echo "$sample" >> "$sample"_specfile
echo date of analysis is $(date) >> "$sample"_specfile

#--------------------------
# Prepare FASTA files
#--------------------------

echo "...reformatting raw transcriptome FASTA file @"

# Make a note in the spec file about which original FASTA file was used
echo "$sample" analysis used input file "$trinity" which contains $(wc -c "$trinity" | awk '{print $1}') bytes >> "$sample"_specfile
echo >> "$sample"_specfile

# Format Trinity file to look pretty (and contain sample name in header)
	# INPUT: "$trinity"
	# OUTPUT: "$sample"_trinity.fa
$scriptlib/fasta_header.sh "$sample" "$trinity" y
mv "$sample"_clean.fa "$sample"_trinity.fa

# Make a note in the spec file about how the original FASTA file was modified
echo the file "$trinity" was formatted with fasta_formatter, $(fasta_formatter -h | head -n 2 | tail -n 1)
echo >> "$sample"_specfile

#########################
## PRE-EXONERATE BLAST ##
#########################

echo "Running BLASTX in preparation for Exonerate at $(date) @"

# Identify best protein BLAST hits for each transcript
	# INPUT: "$sample"_trinity.fa
	# OUTPUT: "$sample"_FSblastx.out
diamond blastx --sensitive --db "$blastDB" --query "$sample"_trinity.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_FSblastx.out
echo "...BLASTX complete at $(date) @"	

# Make a note in the spec file about which BLAST parameters were used
echo pre-Exonerate BLAST used the following parameters: >> "$sample"_specfile
diamond --version >> "$sample"_specfile
echo diamond was run with the following command: >> "$sample"_specfile
echo diamond blastx --sensitive --db "$blastDB" --query "$sample"_trinity.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_FSblastx.out >> "$sample"_specfile
echo >> "$sample"_specfile

###############
## EXONERATE ##
###############

echo "Correcting frameshifts with Exonerate at $(date) @"

# Correct any frameshifts in each transcript
	# INPUT: "$sample"_FSblastx.out and "$sample"_trinity.fa
	# OUTPUT: "$sample"_TrinityFS.fa
$scriptlib/PairwiseExonerate.sh "$sample" "$sample"_FSblastx.out "$sample"_trinity.fa "$blastFA"

# Rename temporary directory
mv "$sample"_tempfiles "$sample"_exonerate_tempfiles

# Move temporary files
for i in "$sample"_FScorrected.fa "$sample"_FScorrected.cigar
do
	mv "$i" "$sample"_exonerate_tempfiles
done

echo "...completed Exonerate analysis at $(date) @"

# Make a note in the spec file about which Exonerate parameters were used
echo Exonerate used the following parameters: >> "$sample"_specfile
echo files were formatted with fasta_formatter, $(fasta_formatter -h | head -n 2 | tail -n 1)
echo exonerate was run with this command: >> "$sample"_specfile
echo exonerate --model protein2dna --query tempAA.fa --target tempNT.fa --verbose 0 --showalignment 0 --showvulgar no --showcigar yes -n 1 --ryo ">%ti (%tab - %tae)\n%tcs\n" >> "$sample"_exonerateTemp.out >> "$sample"_specfile
echo fasta files were filtered using $(fasta_formatter | head -n 1) >> "$sample"_specfile

##################
## TRANSDECODER ##
##################

echo "Identifying ORFs with TransDecoder at $(date) @"

# Make sure I am back in the right place
cd "$wkdir"/"$sample" || { echo "could not return to sample directory - exiting! @"; exit 1 ; }

# To identify candidate ORFs for each transcript
	# INPUT: "$sample"_TrinityFS.fa
	# OUTPUT: "$sample"_ORFs.fa
# Identify preliminary ORFs (>300aa)
echo "...running TransDecoder.LongORFs @"
TransDecoder.LongOrfs -t "$sample"_TrinityFS.fa

# Perform homology searches
cd "$sample"_TrinityFS.fa.transdecoder_dir || { echo "could not move to TransDecoder directory - exiting! @"; exit 1 ; }
echo "...performing BLASTx for TransDecoder @"
$scriptlib/runDiamondBlastp.sh "$sample" longest_orfs.pep "$blastDB"
echo "...performing hmmscan for TransDecoder @"
$scriptlib/run_hmmscan.sh "$sample" longest_orfs.pep
cd .. || exit

# Perform final ORF prediction
echo "...performing final ORF prediction for TransDecoder @"
TransDecoder.Predict -t "$sample"_TrinityFS.fa --retain_blastp_hits "$sample"_TrinityFS.fa.transdecoder_dir/"$sample"_blastp.out --retain_pfam_hits "$sample"_TrinityFS.fa.transdecoder_dir/"$sample"_domtblout

# Tidy up
echo "...tidying up after TransDecoder @"
mkdir "$sample"_TrinityFS.fa.transdecoder_dir/interim_files
mv $(find ./"$sample"_TrinityFS.fa.transdecoder_dir -maxdepth 1 -type f) "$sample"_TrinityFS.fa.transdecoder_dir/interim_files
mkdir "$sample"_TrinityFS.fa.transdecoder_dir/output_files
for filetype in cds pep bed gff3
	do
	mv "$sample"_TrinityFS.fa.transdecoder."$filetype" "$sample"_TrinityFS.fa.transdecoder_dir/output_files
done
cp "$sample"_TrinityFS.fa.transdecoder.mRNA "$sample"_TrinityFS.fa.transdecoder_dir/output_files
mv "$sample"_TrinityFS.fa.transdecoder.mRNA "$sample"_ORFs.fa
mv "$sample"_TrinityFS.fa.transdecoder_dir/ "$sample"_transDecoderTemp

# Extract ORF information for future reference
echo "...extracting ORF details @"
grep ">" "$sample"_ORFs.fa | sed 's/>//g' > "$sample"_ORFs.info

echo "...completed TransDecoder analysis at $(date) @"

############################
## PREPARE FASTA FILES V2 ##
############################

echo "Reformatting FASTA files for end of analysis at $(date) @"

# Format TransDecoder output to look pretty
	# INPUT: "$sample"_ORFs.fa
	# OUTPUT: "$sample"_ORFs.fa #over-writes old version
$scriptlib/fasta_header.sh "$sample" "$sample"_ORFs.fa n
rm "$sample"_ORFs.fa
mv "$sample"_clean.fa "$sample"_ORFs.fa
echo "Generated FASTA files ready for clustering at $(date) @"

################
## TIDYING UP ##
################

echo "Organising final output directory"

mkdir TransPipeline_interim
for files in "$sample"_trinity.fa "$sample"_FSblastx.out "$sample"_transDecoderTemp "$sample"_ORFs.info "$sample"_exonerate_tempfiles AAD3_TrinityFS.fa
	do
	mv "$files" TransPipeline_interim
done

echo "...output directory organised"
echo ...output file of ORFs is "$sample"_ORFs.fa @

####echo "Run_TransPipeline.sh complete for $(sample) at $(date)" | mail -s "Server alert:  Run_TransPipeline.sh complete" "lfgrice@gmail.com"
cd "$wkdir" || { echo "could not return to working directory - exiting! @"; exit 1 ; }

