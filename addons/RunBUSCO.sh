#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 27 September 2018
# Title: RunBUSCO.sh
# Goal: To use a CDS file to test for transcriptome completeness with BUSCO
# Usage: RunBUSCO.sh {cds.fa} {outdir}
# NOTE: If the file is called e.g. file.cds.fa the output will be called file.busco (and a temp dir called file_buscotemp. If the file is called file.fa, the output will be file.fa.busco etc.
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Check and prepare arguments
# ------------------------------------------------------------------

# Check if correct number of arguments (n = 1) provided
if [ $# != 1 ]; then
    echo "...ERROR: 1 argument expected for BUSCO - exiting!"
    exit 1
fi

# Rename variables
cds=$1
busco_dir=/opt/src/busco/scripts

# ------------------------------------------------------------------
# Run BUSCO
# ------------------------------------------------------------------

python3 $busco_dir/run_BUSCO.py -i "$cds" -o $(basename --suffix=.cds.fa "$cds").busco -c 10 -l /ngs/db/busco/arthropoda_odb9 -m tran

# ------------------------------------------------------------------
# Tidy up
# ------------------------------------------------------------------

# delete temp file if empty, otherwise move to directory
[ "$(ls -A tmp)" ] && mv tmp run*busco || rm -r tmp
