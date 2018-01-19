#!/bin/bash
# ------------------------------------------------------------------
# Author:	Laura Grice
# Title:	trigger-assembly2orf.sh
# Version:	v01.01
# Goal:		To feed the samples in to Run_TransPipeline.sh. 
# Requirements:	The user must have already made a tab-delimited file ("input_param") listing the sample ID and file location of each transcriptome of interest
# Usage:	nohup ./TriggerPipeline.sh {paramfile} {wkdir} {dependencies} {blastdb} {blastfasta} > TransPipeline_nohup.out 2>&1&
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
scriptlib=$3	#location of the script library containing the dependencies
blastdb=$4	#location of the blast database to use
blastfasta=$5	#location of the fasta file used to create this blastdb

# ------------------------------------------------------------------
# Run assembly2orf pipeline on all samples of interest
# ------------------------------------------------------------------
while read -r sample_name transcripts; do
	cd "$workdir" || exit 1
	./assembly2orf.sh "$sample_name" "$transcripts" "$wkdir" "$scriptlib" "$blastdb" "$blastfasta"
done < "$paramfile"

