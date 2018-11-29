#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 27 September 2018
# Title: RunBUSCO.sh
# Goal: To use a CDS file to test for transcriptome completeness with BUSCO
# Usage: RunBUSCO.sh {cds.fa} {a/f}
	# a = run arthropod busco only
	# f = run full BUSCO - eukaryote + metazoa + arthropod
# NOTE: If the file is called e.g. file.cds.fa the output will be called file.busco (and a temp dir called file_buscotemp. If the file is called file.fa, the output will be file.fa.busco etc.
# NOTE: If you run arthropod + metazoan + eukaryote mode, the families from each species cannot just be joined because some genes will be associated with families from Euk, Met, Arth and these families will not be perfect overlaps - e.g. not all the genes from Metazoan Fam X will be in Eukaryote Fam Y.
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Check and prepare arguments
# ------------------------------------------------------------------

# Check if correct number of arguments (n = 1) provided
if [ $# != 2 ]; then
    echo "...ERROR: 2 argument expected for BUSCO - exiting!"
    exit 1
fi

# Rename variables
cds=$1
species=$2
busco_dir=/opt/src/busco/scripts

# Check if valid option selected for "arthropod or full"

if [[ "$species" != [afAF] ]]; then
    echo "...ERROR: invalid species argument - exiting!"
    exit 1
fi

# ------------------------------------------------------------------
# Run BUSCO
# ------------------------------------------------------------------

# To run BUSCO for arthropods only
if [[ "$species" == [aA] ]]; then	# First argument starts with a/A for arthropod
	python3 $busco_dir/run_BUSCO.py -i "$cds" -o $(basename --suffix=.cds.fa "$cds").arth.busco -c 10 -l /ngs/db/busco/arthropoda_odb9 -m tran --tmp_path ./$(basename --suffix=.cds.fa "$cds").arth.tmp

# To run BUSCO for eukaryotes, metazoans and arthropods
elif [[ "$species" == [fF] ]]; then	# First argument starts with f/F for full
	# eukaryotes
	python3 $busco_dir/run_BUSCO.py -i "$cds" -o $(basename --suffix=.cds.fa "$cds").euk.busco -c 10 -l /ngs/db/busco/eukaryota_odb9 -m tran --tmp_path ./$(basename --suffix=.cds.fa "$cds").euk.tmp
	# metazoans
	python3 $busco_dir/run_BUSCO.py -i "$cds" -o $(basename --suffix=.cds.fa "$cds").metaz.busco -c 10 -l /ngs/db/busco/metazoa_odb9 -m tran --tmp_path ./$(basename --suffix=.cds.fa "$cds").metaz.tmp
	# arthropods
	python3 $busco_dir/run_BUSCO.py -i "$cds" -o $(basename --suffix=.cds.fa "$cds").arth.busco -c 10 -l /ngs/db/busco/arthropoda_odb9 -m tran --tmp_path ./$(basename --suffix=.cds.fa "$cds").arth.tmp
fi

# ------------------------------------------------------------------
# Tidy up
# ------------------------------------------------------------------

# delete temp file if empty, otherwise move to directory
# eukaryote
[ "$(ls -A ./$(basename --suffix=.cds.fa "$cds").euk.tmp)" ] && mv ./$(basename --suffix=.cds.fa "$cds").euk.tmp run*euk.busco || rm -r ./$(basename --suffix=.cds.fa "$cds").euk.tmp
# metazoa
[ "$(ls -A ./$(basename --suffix=.cds.fa "$cds").metaz.tmp)" ] && mv ./$(basename --suffix=.cds.fa "$cds").metaz.tmp run*metaz.busco || rm -r ./$(basename --suffix=.cds.fa "$cds").metaz.tmp
# arthropod
[ "$(ls -A ./$(basename --suffix=.cds.fa "$cds").arth.tmp)" ] && mv ./$(basename --suffix=.cds.fa "$cds").arth.tmp run*arth.busco || rm -r ./$(basename --suffix=.cds.fa "$cds").arth.tmp
