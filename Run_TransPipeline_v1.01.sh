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

echo "Welcome to assembly2orf.sh v01.01. It is currently $(date) @" #####maybe change the name

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
echo -e "$sample""\nanalysis date: $(date)" >> "$sample"_specfile

#--------------------------
# Prepare FASTA files
#--------------------------

echo "...reformatting raw transcriptome FASTA file @"

# Make a note in the spec file about which original FASTA file was used
echo -e "Input file: ""$trinity"" ("$(wc -c "$trinity" | awk '{print $1}')" bytes)" >> "$sample"_specfile

# Format Trinity file to look pretty (and contain sample name in header)
	# INPUT: "$trinity"
	# OUTPUT: "$sample"_trinity.fa
$scriptlib/fasta_header.sh "$sample" "$trinity" y
mv "$sample"_clean.fa "$sample"_trinity.fa

# Make a note in the spec file about how the original FASTA file was modified
echo -e Reformatting of "$trinity" performed by fasta_formatter $(fasta_formatter -h | head -n 2 | tail -n 1) >> "$sample"_specfile

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
echo -e "Pre-Exonerate BLASTx performed with" $(diamond --version) "with the following command:\ndiamond blastx --sensitive --db "$blastDB" --query "$sample"_trinity.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_FSblastx.out" >> "$sample"_specfile

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

# Make a note in the spec file about which Exonerate parameters were used
echo -e "Frameshift correction performed with" $(exonerate | head -n 1) "with the following command:\nexonerate --model protein2dna --query tempAA.fa --target tempNT.fa --verbose 0 --showalignment 0 --showvulgar no --showcigar yes -n 1 --ryo" "\">%ti (%tab - %tae)\\\n%tcs\\\n\"" >> "$sample"_specfile
echo -e "Frameshift correction also employed fasta_formatter ("$(fasta_formatter -h | head -n 2 | tail -n 1)") and cd-hit-est (version" $(cd-hit-est -h | head -n 1)")" >> "$sample"_specfile 

##################
## TRANSDECODER ##
##################

echo "Identifying ORFs with TransDecoder at $(date) @"

# Make sure I am back in the right place
cd "$wkdir"/"$sample" || { echo "could not return to sample directory - exiting! @"; exit 1 ; }

# To identify candidate ORFs for each transcript
	# INPUT: "$sample"_TrinityFS.fa #frameshift corrected file produced by Exonerate
	# OUTPUT: "$sample"_ORFs.fa ##### make this more clear - is this what it will be at the end? is this aa or nt? cds/mrna? change so all the versions are analysed in the same way for later
	
# Identify preliminary ORFs (>300aa)
TransDecoder.LongOrfs -t "$sample"_TrinityFS.fa

# Perform homology searches
cd "$sample"_TrinityFS.fa.transdecoder_dir || { echo "could not move to TransDecoder directory - exiting! @"; exit 1 ; }
# Run BLAST search
echo "...performing BLASTx for TransDecoder @"
diamond blastp --sensitive --db "$blastDB" --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_blastp.out
# Run HMMSCAN
echo "...performing hmmscan for TransDecoder @"
hmmscan --cpu 2 --domE 0.00001 -E 0.00001 --domtblout "$sample"_domtblout /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm longest_orfs.pep
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
echo -e "Default TransDecoder analysis run with version" $(ll -lth $(which TransDecoder.LongOrfs)) "including homology evidence." >> "$sample"_specfile
echo -e "Transdecoder BLASTp performed with" $(diamond --version) "with the following command: diamond blastp --sensitive --db "$blastDB" --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_blastp.out" >> "$sample"_specfile
echo -e "Transdecoder HMMSCAN performed with" $(hmmscan -h | head -n 2 | tail -n 1) against a Pfam-A database from" $(head -n 1 /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm) "with the following command:hmmscan --cpu 2 --domE 0.00001 -E 0.00001 --domtblout "$sample"_domtblout /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm longest_orfs.pep"  >> "$sample"_specfile



################
## TIDYING UP ##
################

echo "Organising final output directory"

#/###### come back to this reorganisation once i see what the end result is
#mkdir TransPipeline_interim
#for files in "$sample"_trinity.fa "$sample"_FSblastx.out "$sample"_transDecoderTemp "$sample"_ORFs.info "$sample"_exonerate_tempfiles "$sample"_TrinityFS.fa
#	do
#	mv "$files" TransPipeline_interim
#done

echo "...output directory organised"
echo ...output file of ORFs are "$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.[cds/mRNA/pep] @

cd "$wkdir" || { echo "could not return to working directory - exiting! @"; exit 1 ; }

