#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 28 July 2017
# Title: Run_TransPipeline.sh
# Goal: To call the sub-component scripts to generate filtered transcript datase
# Usage: nohup ./Run_TransPipeline.sh {sample} {trinity.fa} {working dir} > nohup.out 2>&1&
# Expected output: "$sample"_ORFs.fa which can be used for clustering methods downstream
# ------------------------------------------------------------------

echo "Welcome to Run_TransPipeline.sh. It is currently $(date) @"

####################
## INITIALISATION ##
####################

echo "Initialising analysis at $(date) @"

#--------------------------
# Prepare variables
#--------------------------

echo "...setting variables @"

# Databases
## Change if required
scriptlib='/home/laura/scripts/pipelines/TransPipeline' #Location of pipeline scripts
blastDB='/home/laura/data/inhouse_data/blastDB_fam25p+metaz_longestreps/fam25p+metaz_longreps.dmnd'
blastFA='/home/laura/data/inhouse_data/blastDB_fam25p+metaz_longestreps/fam25p+metaz_longreps.fa'

# User-supplied variables
sample=$1	# Brief sample name
trinity=$2	# Trinity.fa file
wkdir=$3	# Base working directory

#--------------------------
# Prepare directories
#--------------------------

echo "...generating working directories @"

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
# Prepare FASTA files
#--------------------------

echo "...preparing FASTA files @"

# Format Trinity file to look pretty (and contain sample name in header)
	# INPUT: "$trinity"
	# OUTPUT: "$sample"_trinity.fa
$scriptlib/fasta_header.sh "$sample" "$trinity" y
mv "$sample"_clean.fa "$sample"_trinity.fa

echo "...FASTA file ready for analysis. @"

#########################
## PRE-EXONERATE BLAST ##
#########################

echo "Running BLASTX in preparation for Exonerate at $(date) @"

# Identify best protein BLAST hits for each transcript
	# INPUT: "$sample"_trinity.fa
	# OUTPUT: "$sample"_blastx.out
$scriptlib/runDiamondBlastx.sh "$sample" "$sample"_trinity.fa "$blastDB"
mv "$sample"_blastx.out "$sample"_FSblastx.out

echo "...BLASTX complete at $(date) @"

###############
## EXONERATE ##
###############

echo "Correcting frameshifts with Exonerate at $(date) @"

# Correct any frameshifts in each transcript
	# INPUT: "$sample"_blastx.out and "$sample"_trinity.fa
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

echo "Run_TransPipeline.sh complete for $(sample) at $(date)" | mail -s "Server alert:  Run_TransPipeline.sh complete" "lfgrice@gmail.com"
cd "$wkdir" || { echo "could not return to working directory - exiting! @"; exit 1 ; }

