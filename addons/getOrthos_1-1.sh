#!/bin/bash
# ------------------------------------------------------------------
# Author: Laura Grice
# Date: 17 April 2018
# Title: 1-1orthologues.sh
# Goal: To take a tab-delim table and find all rows where every value is "1" (except rowname) - i.e. to find the 1-1 orthologues in a table
# Usage: 1-1orthologues.sh <my.file>
# ------------------------------------------------------------------

# Renaming variables
myfile=$1

egrep '^\S+(\s+1)+$' $myfile
