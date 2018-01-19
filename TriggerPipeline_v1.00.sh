#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 28 July 2017
# Title: TriggerPipeline.sh
# Goal: To feed the samples in to Run_TransPipeline.sh
# Usage: nohup ./TriggerPipeline.sh > TransPipeline_nohup.out 2>&1&
# ------------------------------------------------------------------

while read -r sample_name transcripts workdir; do
	cd "$workdir" || exit 1
	./Run_TransPipeline.sh "$sample_name" "$transcripts" "$workdir"
done < /home/laura/data/inhouse_data/TransPipeline/input_param

