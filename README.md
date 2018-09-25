NOTE TO SELF TO DO IN THIS EDIT:

xxxx1. add in this pfam:xxxx

xxx~/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmmxxxx

2. Remove the ono filtering step from the main script

3. don't need the redundancy script now. move to addons dir (and make it stand-alone)

xxxx4. add email as a sixth parameter for input_paramsxxxx

5. add a test dataset.

6. do we still want to use the ensembl metazoa blast database/sequence database? check when we use them/

# assembly2orf

*Laura Grice - Updated 24 September 2018*

A transcriptome preparation pipeline which converts assembled transcriptomes (for example, Trinity output) into frameshift-corrected, redundancy-filtered ORFs.

----

# Quick start
```
nohup ./trigger-assembly2orf.sh {sample_input file} {working directory} {blast.dmnd} {blast.fa} {email} > assembly2orf_nohup.out 2>&1&
```

For those working in-house:
* script to run = /home/laura/scripts/assembly2orf/trigger-assembly2orf.sh
* sample_input = DIY
* working directory = DIY
* blastDB (maybe) = /ngs/db/ensembl_metazoa/pep/allEnsemblMetazoa_pep.all.fa.fam.longest.dmnd
* blastAA (maybe) = /ngs/db/ensembl_metazoa/pep/allEnsemblMetazoa_pep.all.fa.fam.longest.fa
* email = DIY

*How were these BLAST files generated?*
1. Download Ensembl Metazoa data (release 36, June 8th 2017), concatenate files together, perform all-vs-all BLAST, run Silix and flag each sequence with its gene family ID (by Tristan, see file /ngs/db/ensembl_metazoa/pep/cmd)
2. Within each species, pull out the longest representative of each gene family
3. Build a blast DB 

----

# Introduction
**assembly2orf** is a package which will convert any number of **nucleotide.fa** files (e.g. Trinity output) into sets of filtered, frameshift-corrected best ORFs. The package includes several files/folders (pictured below) but the user need only interact with **trigger-assembly2orf.sh**. 

<pre>
assembly2orf/
├── README.md
├── trigger-assembly2orf.sh
└── dependences
     ├──── assembly2orf.sh
     ├──── fasta_header.sh
     ├──── filter_homologues.sh
     └──── PairwiseExonerate.sh
</pre>

The user will create a sample description file (referred to here as **sample_input**, but it can be named anything and saved anywhere) which provides a brief name and file location for each fasta file of interest to be analysed. To start the analysis, the user calls **trigger-assembly2orf.sh** and provides a number of input parameters to the program. **trigger-assembly2orf.sh** reads **sample_input** line-by-line and uses a secondary script called **assembly2orf.sh** (and several other custom scripts provided with this package) to analyse each sample. To know more, see the **Software Overview** section below.

# What is included
* README.md - this readme file
* trigger-assembly2orf.sh - the script which the user will call to run the package
* dependencies/assembly2orf.sh - the script which does most of the heavy lifting to analyse each sample in turn
* dependencies/fasta_header.sh - a script which reformats fasta files (i.e. shortens fasta headers and removes line breaks within sequences) to make them easier to parse by the program
* dependencies/filter_homologues.sh - a script which uses BLAST to remove redundant sequences, based on BLAST hits to a common reference sequence
* dependencies/PairwiseExonerate.sh - a script which pairs sequences with their best reference and attempts to remove any frameshift errors within the sequence of interest

# Software dependencies

The following publicly-available programs must be in your path:
* TransDecoder.LongOrfs, TransDecoder.Predict (part of the Transdecoder package)
* fasta_formatter (part of FASTX Toolkit)
* exonerate, fastaremove (part of Exonerate package)
* diamond
* hmmscan (part of the HMMER package)
* cd-hit-est (part of the CD-HIT package) #/##### edit throughout to insert refs to this where required. added to pairwise exonerate.

To check if you have access to these programs, the following command should print the location of the program (if you do not get any output, the program is not installed)
```
which {program_name}
# if it prints a file string, the program is installed
# if you get no response, the program is not installed
```

# Getting started

If required, download the **assembly2orf** package from Github and unzip. Alternatively, find this package on the server. Regardless, confirm that line 38 of **trigger-assembly2orf.sh** lists the correct **/dependencies** filepath. If not, edit it (it may be best to make your own copy first):
```
vi trigger-assembly2orf.sh +38
```

Make sure all scripts are executable by running the command below while in **assembly2orf** directory. Fix any unexecutable scripts using the `chmod` command.

```
for i in trigger-assembly2orf.sh dependencies/assembly2orf.sh dependencies/fasta_header.sh dependencies/PairwiseExonerate.sh
do
echo "$i" $(test -x "$i" && echo executable || echo "not executable")
done
```

Check that the programs TransDecoder.LongOrfs, TransDecoder.Predict, fasta_formatter, exonerate, fastaremove, diamond, hmmscan and cd-hit-est are in your path (see "Software dependencies" above).
```
which {program}
```

Check that you have access to the required Pfam-A file
```
head -n 3 /home/laura/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm
# if you get an error message you must:
## find the file or download your own version from ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/
## check with hmmscan to make sure the file works as expected
## edit the following lines of dependencies/assembly2orf.sh with the new filestring
vi assembly2orf.sh +152
vi assembly2orf.sh +193
vi assembly2orf.sh +194
```

Create or choose a working directory to hold your output files. It can have any name and be located anywhere you like (**assembly2orf** will generate separate sample-specific sub-directories inside this working directory as it runs). Make a note of the entire file string of your working directory as you will require this information to call **trigger-assembly2orf.sh** 

Create or choose a custom diamond blast database (.dmnd) and the exact amino acid fasta file which was used to create this database. The same files will be used at several points in the analysis:
* as a source of reference sequences for frameshift correction
* as a source of homology information for ORF prediction
* to filter redundant sequences
Make a note of the entire file string of both files as you will require this information to call **trigger-assembly2orf.sh** 
```
# to make a custom diamond blast database
diamond makedb --in someaminoacidfile.fa --db someaminoacidfile
```

Create a tab-delimited file (for example, called **sample_input**) which provides information about all your files to analyse. It is helpful to save this file in your working directory, but it can be anywhere and have any name.
* Column 1 = sample name = abbreviated name of each sample, such as a species code (e.g. AAD3, PCG6, etc.)
* Column 2 = transcriptome = full file string of each nucleotide.fa file (e.g. /path/to/file.fa)
Make a note of the entire file string of **sample_input** as you will require this information to call **trigger-assembly2orf.sh** 

Run the program with the following command:
```
./trigger-assembly2orf.sh {sample_input} {working directory} {dependencies folder} {blast.dmnd} {blast.fa}
# or to nohup and send output to a custom-named file
nohup ./trigger-assembly2orf.sh {sample_input} {working directory} {blast.dmnd} {blast.fa} {email address} > assembly2orf_nohup.out 2>&1&
```
Where
* ./trigger-assembly2orf.sh - the full/relative filestring of the script
* sample_input - the full/relative filestring of your sample_input file
* working directory - the full filestring of your working directory
* blast.dmnd - your custom blast database
* blast.fa - the amino acid file used to build the custom blast database
* email address - you will recieve a single email from the server when the whole assembly2orf analysis is complete

# Software overview
trigger-assembly2orf.sh will loop through each sample of interest specified in **sample_input**. **trigger-assembly2orf.sh** will call **assembly2orf.sh** for Sample A, then again for Sample B, etc.


**INITIALISATION**
* **PREPARE VARIABLES** defines a number of variables based on user-specified input
* **PREPARE DIRECTORIES** moves to the user-specified working directory, and generates a new directory for the current sample. All new files generated by the rest of the script will be saved in this directory.
* **PREPARE PARAMETER SPECIFICATION FILE** generates a file that will tell the user which software versions were used to run which commands and the location of the output files
* **PREPARE FASTA FILES** re-formats the nucleotide.fa file in three different ways:
-- Truncates fasta headers to sequence names only (i.e. remove all description after first space). Why? Some subsequent steps (`fasta_formatter -t`) can't handle multiple spaces in the headers.
-- Converts fasta sequences from multi- to single-line. Why? It is neater and may prevent some file manipulations from breaking.
-- Appends the sample name to the beginning of each sequence. Why? Because it avoids duplicate names if you later combine multiple files from different species. 

**PRE-EXONERATE BLAST**
* Runs blastx (using Diamond) to identify the top blast hit (to a set of asellid/metazoan proteins) for each sequence in the fasta file

**EXONERATE**
* Generates a set of nucleotide files containing [sequences that didn't have frameshifts] + [sequences that had frameshifts but were corrected]. Note that the frameshift-corrected sequences will only be as long as the region of the reference protein to which they were aligned, but the non-frameshift-corrected sequences will remain full-length. This step also removes any sequences that are 100% identical to one another.

**TRANSDECODER**
* Runs TransDecoder to identify candidate ORFs (with homology information - hmmer and blast - used to retain sequences not meeting TransDecoders filtering steps. 

**FILTER REDUNDANCY**
* All ORFs are compared to a BLAST database with BLASTp. All ORFs within a sample which match the same sequence subject are considered to be homologues of one another, and therefore redundant. The sequence producing the best BLAST match (assessed by highest BIT score) to the subject is retained as the representative sequence and the others are discarded
* Any sequences lacking BLAST hits to the database are retained in the dataset

**TIDYING UP**
* Moves all the files to a temp directory

**The final output**
* You will receive an email when assembly2orf is finished analysing all samples
* At the end your working directory will contain one directory per sample. In each sample directory you will see the following files:
<pre>
{sample}
├── {sample}_exonerate
│   ├──── interim_files
│   └──── output_files
│       └────── {sample}_TrinityFS.fa
├── {sample}_input
│   └──── {sample}_trinityinput.fa
├── {sample}_redundancy
│   ├──── {sample}_TrinityFS.fa.transdecoder.pep_blastp.out
│   ├──── {sample}_representatives.cds.fa
│   ├──── {sample}_representatives.mRNA.fa
│   └──── {sample}_representatives.pep.fa
├── {sample}_specfile
└── {sample}_transDecoder
    ├──── interim_files
    └──── output_files
        ├────── {sample}_TrinityFS.fa.transdecoder.bed
        ├────── {sample}_TrinityFS.fa.transdecoder.cds
        ├────── {sample}_TrinityFS.fa.transdecoder.gff3
        ├────── {sample}_TrinityFS.fa.transdecoder.mRNA
        └────── {sample}_TrinityFS.fa.transdecoder.pep
</pre>
You will most likely be interested in the contents of either:
* {sample}_transDecoder/output_files/ - the full set of ORFs
* {sample}_redundancy - these ORFs after homology-based redundancy filtration

# To do
* The nohup file generated by this program is annoying to parse. I have it set so you can skip all the Exonerate lines if you do "grep -v "\^" {nohupfile} " but it is still hard because of the blast and hmmer hits that are written to file (and are not easily parse-out-able). It'd be good to work out how to split these logs up into something more readable (different files for each step? append some kind of code in the log so you can remove everything between the two lines of text?
xxxx* I have linked in the script to my old Pfam-A from Deglab - because I couldn't get it to work here. I think this is because I missed the hmmpress step which is required to convert a .hmm into a file that can actually run. hmmpress will make .h3m, .h3i, .h3f, .h3p files - i think (but i need to check) that these need to be in the same file as the .hmm but you trigger hmmscan with .hmmxxxx
xxxx* (3 May 2018) the script uses hmmscan on the old version of Pfam - i tried running hmmscan for something else using this file and it fails. I will need to update the script (~/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm) I think i worked out what the problem was when i was working with Panther HMMs. Find this bit in my notes/blog and see what the fix was.xxxx
* The ono redundancy filtering bit is "over-grouping" different opsin paralogues and filteirng them out - i will need to re-thibk this strategy.

# Version history
v00.01 - 28 July 2017
v00.02 - 13 August 2017
* Original incorrect $blastDB and $blastFA files (erroneously containing a mix of nucleotide and amino acid sequences) were replaced with correct (amino acid only) sequences. No change to the script, just to the files specified in lines 28-29 of Run_TransPipeline.sh.
v01.00 - 16-24 January 2018
* Updated for new Asellus server and to make the program into more of a "bundle" that can be run by anyone
* Updated text based on new pipeline implementation
v01.01 - 24 September 2018
* Changed link to Pfam-A file required for hmmscan. The current version is compatible with the February 2015 version of HMMER (3.1b2) which is currently on Asellus.
* Removed requirement to manually specify location of dependencies directory each time the script is run
* User receives an email when the run is finished


* TO DO: Remove the "Ono filtering step" so the final output is the transdecoder output.
