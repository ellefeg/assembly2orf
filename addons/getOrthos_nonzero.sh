#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 17 April 2018
# Title: nonzeroes.sh
# Goal: To take a tab-delim table and find all rows where no value is "0" (except rowname) - i.e. to find the "non-zero orthologues"
# Usage: nonzeroes.sh <my.file>
# ------------------------------------------------------------------

# Renaming variables
myfile=$1

egrep '^\S+(\s+[1-9][0-9]*)+$' $myfile
