#!/bin/bash
set -e
# ------------------------------------------------------------------
# Author:	Laura Grice
# Title:	assembly2orf.sh
# Version:	v01.01
# Goal:		To convert a .fa transcriptome assembly to a filtered set of transcript ORFs
# Usage:	nohup ./Run_TransPipeline.sh {sample} {trinity.fa} {working dir} > nohup.out 2>&1&
# Output:	Redundancy-filtered ORFs which can be used for clustering methods downstream
# ------------------------------------------------------------------
# VERSION INFORMATION
# v01.00 28 July 2017
# v01.01 19 January 2018
# Updated to run on Asellus
# ------------------------------------------------------------------

####################
## INITIALISATION ##
####################

#--------------------------
# Prepare variables
#--------------------------

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

echo Commencing assembly2orf.sh v01.01 for sample "$sample" at $(date) @

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

# Create spec file for run info (versions, commands, output) useful for writing methods
touch "$sample"_specfile
cat >> "$sample"_specfile <<COMMENT
Sample: $sample
	Analysis date: $(date)
COMMENT

#--------------------------
# Prepare FASTA files
#--------------------------

echo Reformatting sample "$sample" input file @

# Make a note in the spec file about which original FASTA file was used
cat >> "$sample"_specfile <<COMMENT
	Pipeline input file: $trinity ($(wc -c $trinity | awk '{print $1}') bytes)
COMMENT

# Format Trinity file to look pretty (and contain sample name in header)
	# INPUT: "$trinity"
	# OUTPUT: "$sample"_trinityinput.fa
$scriptlib/fasta_header.sh "$sample" "$trinity" y
mv "$sample"_clean.fa "$sample"_trinityinput.fa

# Make a note in the spec file about how the original FASTA file was modified
cat >> "$sample"_specfile <<COMMENT
STEP 1: SAMPLE REFORMATTING
	Tool: fasta_formatter ($(fasta_formatter -h | head -n 2 | tail -n 1))
COMMENT

#########################
## PRE-EXONERATE BLAST ##
#########################

echo Analysing sample "$sample" with BLASTx ahead of Exonerate at $(date) @

# Identify best protein BLAST hits for each transcript
	# INPUT: "$sample"_trinityinput.fa
	# OUTPUT: "$sample"_FSblastx.out
diamond blastx --sensitive --db "$blastDB" --query "$sample"_trinityinput.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 100 | sort -u -k1,1 > "$sample"_FSblastx.out

# Make a note in the spec file about which BLAST parameters were used
cat >> "$sample"_specfile <<COMMENT
STEP 2A: PRE-EXONERATE BLASTx
	Tool: $(diamond --version)
	Command: diamond blastx --sensitive --db $blastDB --query $(echo $sample)_trinityinput.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 100 | sort -u -k1,1 > $(echo $sample)_FSblastx.out
COMMENT

###############
## EXONERATE ##
###############

# The idea to incorporate frameshift correction into the ORF finding pipeline is inspired by the work of internship student Maury Damien (2014) in collaboration with LBBE (Laurent DURET) and LEHNA (Tristan LEFÉBURE)

echo Correcting frameshifts in sample "$sample" with Exonerate at $(date) @

# Correct any frameshifts in each transcript
	# INPUT: "$sample"_FSblastx.out and "$sample"_trinityinput.fa
	# OUTPUT: "$sample"_TrinityFS.fa
$scriptlib/PairwiseExonerate.sh "$sample" "$sample"_FSblastx.out "$sample"_trinityinput.fa "$blastFA"

# Rename temporary directory
mv "$sample"_tempfiles "$sample"_exonerate_tempfiles
mv "$sample"_FSblastx.out "$sample"_exonerate_tempfiles

# Make a note in the spec file about which Exonerate parameters were used
cat >> "$sample"_specfile <<COMMENT
STEP 2B: EXONERATE
	Tool: $(exonerate | head -n 1)
	Command: exonerate --model protein2dna --query tempAA.fa --target tempNT.fa --verbose 0 --showalignment 0 --showvulgar no --showcigar yes -n 1 --ryo ">%ti (%tab - %tae)\n%tcs\n"
	Tool: fasta_formatter ($(fasta_formatter -h | head -n 2 | tail -n 1))
	Tool: CD-HIT-EST (version $(cd-hit-est -h | head -n 1))
	Command: cd-hit-est -i $(echo $sample)_TrinityFS_redundant.fa -o $(echo $sample)_TrinityFS.fa -c 1
COMMENT

##################
## TRANSDECODER ##
##################

echo Identifying ORFs for sample $sample with TransDecoder at $(date) @

# Make sure I am back in the right place
cd "$wkdir"/"$sample" || { echo "could not return to sample directory - exiting! @"; exit 1 ; }

# To identify candidate ORFs for each transcript
	# INPUT: "$sample"_TrinityFS.fa #frameshift corrected file produced by Exonerate
	# OUTPUT: "$sample"_TrinityFS.fa.transdecoder.[bed/cds/gff3/mRNA/pep]
	
# Identify preliminary ORFs (>300aa)
TransDecoder.LongOrfs -t "$sample"_TrinityFS.fa

# Perform homology searches
cd "$sample"_TrinityFS.fa.transdecoder_dir || { echo "could not move to TransDecoder directory - exiting! @"; exit 1 ; }
# Run BLAST search
echo "...performing BLASTx for TransDecoder @"
diamond blastp --sensitive --db "$blastDB" --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 100 | sort -u -k1,1 > "$sample"_blastp.out
# Run HMMSCAN
echo "...performing hmmscan for TransDecoder @"
hmmscan --cpu 2 --domE 0.00001 -E 0.00001 --domtblout "$sample"_domtblout /home/laura/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm longest_orfs.pep
cd .. || exit
# Perform final ORF prediction
echo "...performing final ORF prediction for TransDecoder @"
TransDecoder.Predict -t "$sample"_TrinityFS.fa --retain_blastp_hits "$sample"_TrinityFS.fa.transdecoder_dir/"$sample"_blastp.out --retain_pfam_hits "$sample"_TrinityFS.fa.transdecoder_dir/"$sample"_domtblout

# Tidy up
echo "...tidying up after TransDecoder @"
# Move the working files of transdecoder one level deeper
mkdir "$sample"_TrinityFS.fa.transdecoder_dir/interim_files
mv $(find ./"$sample"_TrinityFS.fa.transdecoder_dir -maxdepth 1 -type f) "$sample"_TrinityFS.fa.transdecoder_dir/interim_files

# Move non-fasta output into output directory
mkdir "$sample"_TrinityFS.fa.transdecoder_dir/output_files
for filetype in bed gff3
	do
	mv "$sample"_TrinityFS.fa.transdecoder."$filetype" "$sample"_TrinityFS.fa.transdecoder_dir/output_files
done
# Format TransDecoder output to look pretty and then move into output directory
	# INPUT: "$sample"_ORFs.fa
	# OUTPUT: "$sample"_ORFs.fa #over-writes old version
for filetype in cds pep mRNA
	do
	# Reformat results to look pretty
	$scriptlib/fasta_header.sh "$sample" "$sample"_TrinityFS.fa.transdecoder."$filetype" n
	rm "$sample"_TrinityFS.fa.transdecoder."$filetype"
	mv "$sample"_clean.fa "$sample"_TrinityFS.fa.transdecoder."$filetype"
	# Move to output directory
	mv "$sample"_TrinityFS.fa.transdecoder."$filetype" "$sample"_TrinityFS.fa.transdecoder_dir/output_files
done
mv "$sample"_TrinityFS.fa.transdecoder_dir/ "$sample"_transDecoder

echo "...completed TransDecoder analysis and generated FASTA files ready for clustering at $(date) @"

# Make a note in the spec file about which TransDecoder parameters were used
cat >> "$sample"_specfile <<COMMENT
STEP 3: TRANSDECODER
	Tool: TransDecoder (run with default parameters and homology evidence)
	Tool: $(diamond --version)
	BLASTp Command: diamond blastp --sensitive --db $blastDB --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 100 | sort -u -k1,1 > $(echo $sample)_blastp.out
	Tool: $(hmmscan -h | head -n 2 | tail -n 1)
	PFAM-A Database: $(head -n 1 /home/laura/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm) at /home/laura/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm
	HMMSCAN Command: hmmscan --cpu 2 --domE 0.00001 -E 0.00001 --domtblout $(echo $sample)_domtblout /home/laura/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm longest_orfs.pep
COMMENT

################
## TIDYING UP ##
################

# Make sure I am back in the right place
cd "$wkdir"/"$sample" || { echo "could not return to sample directory - exiting! @"; exit 1 ; }

echo "Organising final output directory"

mkdir "$sample"_exonerate_tempfiles/interim_files
mv $(find ./"$sample"_exonerate_tempfiles -maxdepth 1 -type f) "$sample"_exonerate_tempfiles/interim_files
mv "$sample"_exonerate_tempfiles "$sample"_exonerate
mkdir "$sample"_exonerate/output_files
mv "$sample"_TrinityFS.fa "$sample"_exonerate/output_files

##############################
# Deleting some large things #
##############################
# If you don't want to delete things, uncomment this:
	#mkdir "$sample"_input
	#mv "$sample"_trinityinput.fa "$sample"_input
#Add these lines back into the specfile note below:
	#Input data folder: $(echo $sample)_input
	#Input data file: $(echo $sample)_trinityinput.fa
# and comment this out
rm "$sample"_trinityinput.fa

echo "...output directory organised"

# Make a note in the spec file about the final output
cat >> "$sample"_specfile <<COMMENT
ANALYSIS OF $sample COMPLETE
	Frameshift correction folder: $(echo $sample)_exonerate/output_files
	Frameshift output file: $(echo $sample)_TrinityFS.fa
	ORF prediction folder: $(echo $sample)_transDecoder/output_files
	ORF prediction files: $(echo $sample)_TrinityFS.fa.transdecoder.[bed/cds/gff3/mRNA/pep]
COMMENT

cd "$wkdir" || { echo "could not return to working directory - exiting! @"; exit 1 ; }

