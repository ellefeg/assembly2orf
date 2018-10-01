#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 28 September 2018
# Title: RunSilix.sh
# Goal: To generate Silix gene families from a dataset of interest
# Output files will be named according to the name of the fasta file (minus the last file extension after the last dot). Each fasta must begin with >Species_xxxx
# Usage: RunSilix.sh fasta.fa email
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Check and prepare arguments
# ------------------------------------------------------------------
# Check if correct number of arguments (n = 5) provided
if [ $# != 2 ]; then
    echo "...ERROR: 2 arguments expected for Silix - exiting!"
    exit 1
fi

# Rename variables
fasta=$1	#a file containing ALL the peptide sequences of ALL the samples of interest
fasta_suffix=.$(echo "$fasta" | rev | cut -f 1 -d "." | rev)
fastaBN=$(basename --suffix="$fasta_suffix" "$fasta")
email=$2

# ------------------------------------------------------------------
# Run all-vs-all blast
# ------------------------------------------------------------------

#make diamond db
diamond makedb --in "$fasta" --db "$fastaBN"

#run all-vs-all blast
diamond blastp --sensitive --outfmt 6 --evalue 1e-10 --max-target-seqs 100 --query "$fasta" --db "$fastaBN".dmnd --out "$fastaBN".blastp.out

# ------------------------------------------------------------------
# Run Silix
# ------------------------------------------------------------------

#run silix
for i in `seq 0.6 0.1 0.8`;
do
	for r in `seq 0.6 0.1 0.8`;
	do
		silix -i $i -r $r -f FAM "$fasta" "$fastaBN".blastp.out > "$fastaBN".paramtest_silix_i${i}_r${r}.fnodes

		silix2table.pl "$fastaBN".paramtest_silix_i${i}_r${r}.fnodes > "$fastaBN".paramtest_silix_i${i}_r${r}.fnodes.tab

		# make stats file
		echo i = "${i}", r = "${r}" >> "$fastaBN"_param_stats
		echo total rows: $(grep "FAM" "$fastaBN".paramtest_silix_i${i}_r${r}.fnodes.tab | wc -l) >> "$fastaBN"_param_stats
		echo number of i${i}/r${r} 1:1... orthologues: $(egrep '^\S+(\s+1)+$' "$fastaBN".paramtest_silix_i${i}_r${r}.fnodes.tab | wc -l) >> "$fastaBN"_param_stats
		echo number of i${i}/r${r} total non-zero rows: $(egrep '^\S+(\s+[1-9][0-9]*)+$' "$fastaBN".paramtest_silix_i${i}_r${r}.fnodes.tab | wc -l) >> "$fastaBN"_param_stats
		echo >> "$fastaBN"_param_stats	
	done
done

# ------------------------------------------------------------------
# Tidy up
# ------------------------------------------------------------------

mkdir -p "$fastaBN"_silix/blastout "$fastaBN"_silix/silixout
mv "$fastaBN".dmnd "$fastaBN".blastp.out "$fastaBN"_silix/blastout
mv "$fastaBN"_param_stats "$fastaBN"_silix
mv "$fastaBN".paramtest_silix_*.fnodes "$fastaBN".paramtest_silix_*.fnodes.tab "$fastaBN"_silix/silixout

#send progress email
echo "silix finished at $(date) in $(pwd) - job complete" | mail -s "Server alert: silix complete" "$email"
