#!/bin/bash
# ------------------------------------------------------------------
# Author:	Laura Grice
# Title:	assembly2orf.sh
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

echo "Commencing assembly2orf.sh v01.01 at $(date)"

####################
## INITIALISATION ##
####################

#--------------------------
# Prepare variables
#--------------------------

echo "...setting variables at $(date) @"

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

echo "...reformatting raw transcriptome FASTA file @"

# Make a note in the spec file about which original FASTA file was used
cat >> "$sample"_specfile <<COMMENT
	Pipeline input file: $trinity ($(wc -c $trinity | awk '{print $1}') bytes)
COMMENT

# Format Trinity file to look pretty (and contain sample name in header)
	# INPUT: "$trinity"
	# OUTPUT: "$sample"_trinityinput.fa
$scriptlib/fasta_header.sh "$sample" "$trinity" y
mv "$sample"_clean.fa "$sample"_trinityinput.fa #####change to pipeline input?

# Make a note in the spec file about how the original FASTA file was modified
cat >> "$sample"_specfile <<COMMENT
STEP 1: SAMPLE REFORMATTING
	Tool: fasta_formatter ($(fasta_formatter -h | head -n 2 | tail -n 1))
COMMENT

#########################
## PRE-EXONERATE BLAST ##
#########################

echo "Running BLASTX in preparation for Exonerate at $(date) @"

# Identify best protein BLAST hits for each transcript
	# INPUT: "$sample"_trinityinput.fa
	# OUTPUT: "$sample"_FSblastx.out
diamond blastx --db "$blastDB" --query "$sample"_trinityinput.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_FSblastx.out
#####diamond blastx --sensitive --db "$blastDB" --query "$sample"_trinityinput.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_FSblastx.out
echo "...BLASTX complete at $(date) @"	

# Make a note in the spec file about which BLAST parameters were used
cat >> "$sample"_specfile <<COMMENT
STEP 2A: PRE-EXONERATE BLASTx
	Tool: $(diamond --version)
	Command: diamond blastx --sensitive --db $blastDB --query $(echo $sample)_trinityinput.fa --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out $(echo $sample)_FSblastx.out
COMMENT

###############
## EXONERATE ##
###############

echo "Correcting frameshifts with Exonerate at $(date) @"

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
diamond blastp --db "$blastDB" --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_blastp.out
#####diamond blastp --sensitive --db "$blastDB" --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_blastp.out
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
	# Reformat results to look pretty #/##### come back to this
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
	BLASTp Command: diamond blastp --sensitive --db $blastDB --query longest_orfs.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out $(echo $sample)_blastp.out
	Tool: $(hmmscan -h | head -n 2 | tail -n 1)
	PFAM-A Database: $(head -n 1 /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm) at /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm
	HMMSCAN Command: hmmscan --cpu 2 --domE 0.00001 -E 0.00001 --domtblout $(echo $sample)_domtblout /home/laura/data/external_data/Pfam/Pfam-A_oldComp.hmm longest_orfs.pep
COMMENT

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
#####diamond blastp --sensitive --db "$blastDB" --query "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_TrinityFS.fa.transdecoder.pep_blastp.out
diamond blastp --db "$blastDB" --query "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out "$sample"_TrinityFS.fa.transdecoder.pep_blastp.out

# Perform redundancy filtration
$scriptlib/BLASTRedFilt.sh "$sample" "$sample"_TrinityFS.fa.transdecoder.pep_blastp.out "$wkdir"/"$sample"/"$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.pep
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
	BLASTp Command: diamond blastp --sensitive --db $blastDB --query $(echo $wkdir)/$(echo $sample)/$(echo $sample)_transDecoder/output_files/$(echo $sample)_TrinityFS.fa.transdecoder.pep --outfmt 6 --evalue 1e-5 --max-target-seqs 1 --out $(echo $sample)_TrinityFS.fa.transdecoder.pep_blastp.out
	Tool: $(fastaremove | head -n 1)
	Tool: $(fasta_formatter -h | head -n 2 | tail -n 1)
COMMENT

################
## TIDYING UP ##
################

# Make sure I am back in the right place
cd "$wkdir"/"$sample" || { echo "could not return to sample directory - exiting! @"; exit 1 ; }

echo "Organising final output directory"

mv redundancy "$sample"_redundancy
mkdir "$sample"_exonerate_tempfiles/interim_files
mv $(find ./"$sample"_exonerate_tempfiles -maxdepth 1 -type f) "$sample"_exonerate_tempfiles/interim_files
mv "$sample"_exonerate_tempfiles "$sample"_exonerate
mkdir "$sample"_exonerate/output_files
mv "$sample"_TrinityFS.fa "$sample"_exonerate/output_files
mkdir "$sample"_input
mv "$sample"_trinityinput.fa "$sample"_input

echo "...output directory organised"
echo ...output file of ORFs are "$sample"_transDecoder/output_files/"$sample"_TrinityFS.fa.transdecoder.[cds/mRNA/pep] @
cd "$wkdir" || { echo "could not return to working directory - exiting! @"; exit 1 ; }

# Make a note in the spec file about the final output
cat >> "$sample"_specfile <<COMMENT
ANALYSIS OF $sample COMPLETE
	Input data folder: $(echo $sample)_input
	Input data file: $(echo $sample)_trinityinput.fa
	Frameshift correction folder: $(echo $sample)_exonerate/output_files
	Frameshift output file: $(echo $sample)_TrinityFS.fa
	ORF prediction folder: $(echo $sample)_transDecoder/output_files
	ORF prediction files: $(echo $sample)_TrinityFS.fa.transdecoder.[bed/cds/gff3/mRNA/pep]
	Redundancy filtration folder: $(echo $sample)_redundancy
	Redundancy filtration output: $(echo $sample)_representatives.[cds/mRNA/pep].fa
COMMENT
