NOTE TO SELF TO DO IN THIS EDIT:

xxxx1. add in this pfam:xxxx

xxx~/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmmxxxx

2. Remove the ono filtering step from the main script

3. don't need the redundancy script now. move to addons dir (and make it stand-alone)

xxxx4. add email as a sixth parameter for input_paramsxxxx

5. add a test dataset.

xxxx6. do we still want to use the ensembl metazoa blast database/sequence database? check when we use them/xxxx

7. fix the trees showing file hierarchies





# assembly2orf

*Laura Grice - Updated 24 September 2018*

A transcriptome preparation pipeline which converts any number of assembled transcriptomes (for example, Trinity output) into sets of frameshift-corrected ORFs. Although the package contains a number of scripts, the user only needs to interact with one, `trigger-assembly2orf.sh`.

----

## Quick start

Run the following command with these parameters:
* `sample_input` - a tab-delimited file where col 1 = sampleID and col 2 = /path/to/transcriptome.fa (nucleotides)
* `path/to/output/dir` - full filepath to an output directory (which must already exist)
* `reference.dmnd` - a Diamond blast database made from `reference.fa`
* `reference.fa` - reference file of amino acid sequences (e.g. all sequences on Ensembl Metazoa)
* `email`

```
trigger-assembly2orf.sh sample_input {path/to/output/dir} reference.dmnd reference.fa {email address}
```

You can find some exemplar fasta files in `assembly2orf/addons/example` to get you started.

----

## Installation and pre-requisites

### (a) Installation

1. Download the `assembly2orf` package from Github and unzip, or find the package on the server (`/home/laura/scripts/assembly2orf`). 

2. Confirm that line 38 of `trigger-assembly2orf.sh` lists the correct location of the `assembly2orf/dependencies` folder. If not, edit `trigger-assembly2orf.sh` accordingly (optional: make a copy first).
```
vi trigger-assembly2orf.sh +38
```

3. Ensure that all the required scripts are executable by running the following command (you must be in the `assembly2orf` directory). Fix any unexecutable scripts using the `chmod` command.
```
for i in trigger-assembly2orf.sh dependencies/assembly2orf.sh dependencies/fasta_header.sh dependencies/PairwiseExonerate.sh
do
echo "$i" $(test -x "$i" && echo executable || echo "not executable")
done
```

### (b) Third-party software
`assembly2orf` requires that a number of publicly-available commands are in your path:
* `TransDecoder.LongOrfs`, `TransDecoder.Predict` (part of the Transdecoder package)
* `fasta_formatter` (part of FASTX Toolkit)
* `exonerate`, `fastaremove` (part of Exonerate package)
* `diamond`
* `hmmscan` (part of the HMMER package)
* `cd-hit-est` (part of the CD-HIT package)

Run the following command to identify missing programs. If required, install them and/or add them to your path.
```
for i in TransDecoder.LongOrfs TransDecoder.Predict fasta_formatter exonerate fastaremove diamond hmmscan cd-hit-est
do
command -v "$i" || echo >&2 "assembly2orf requires "$i" but it's not in your path"
done
```

### (c) Pfam-A file
Run the following command to ensure that `assembly2orf` can access the necessary Pfam-A file (The expected output is: `HMMER3/f [3.1b2 | February 2015]`).
```
head -n 1 /home/laura/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm
```

If you get an error message or want to use a different Pfam-A file, you must find it or download one from Pfam (ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/). Do a test with hmmscan to make sure that the new file works as expected. Then edit the following lines of `./dependencies/assembly2orf.sh` to the new filepath to the Pfam-A.hmm file.
```
vi assembly2orf.sh +152
vi assembly2orf.sh +193
vi assembly2orf.sh +194
```

### (d) User input

For each run of `assembly2orf`, the user must provide several files.

**Input 1: `sample_input` file**

Create a tab-delimited file which provides information about all the nucleotide transcriptome files that you want to analyse. It is helpful down the track if you have saved this file in your output directory (*Input 2*) but it can be anywhere and have any name. Provide the full filepath when you call `trigger-assembly2orf.sh`
* Column 1 = sample name = abbreviated name of each sample, such as a species code (e.g. AAD3, PCG6, etc.)
* Column 2 = transcriptome = full file string of each nucleotide.fa file (e.g. /path/to/file.fa)

If you have a sufficiently large server, you may want to split `sample_output` into several smaller files and run them concurrently. It is OK to use the same output directory for each run, as long as there are no double-ups in the sample names provided. Inversely, it is fine to split up similar samples and run them in different runs or on different days - each sample is processed separately.

**Input 2: Output directory**

Create or choose a directory to hold your output files. It can have any name and be located anywhere you like, but you must provide the full filepath and the directory must already exist before you run `assembly2orf`. The program will generate separate sample-specific sub-directories inside this working directory as it runs.

**Input 3: Reference Diamond blast database**

**Input 4: Reference fasta file**

`assembly2orf` uses a reference set of amino acid sequences as a source of reference sequences for frameshift correction and as a source of homology information for ORF prediction. This reference set can be anything you like, but if you are working on a non-model animal species, you may like to use sequences from a wide range of animal species. For instance, we use a bulk download of sequences from Ensembl Metazoa which has been processed as follows (see also `/ngs/db/ensembl_metazoa/pep/cmd`):

1. Download all `*.pep.all.fa.gz` files from Ensembl Metazoa (ftp://ftp.ensemblgenomes.org/pub/release-36/metazoa/fasta/). We used Release 36 from June 8th 2018.
2. Concatenate all files together
3. Perform all-vs-all BLAST
4. Run Silix and flag each sequence with its gene family ID
5. Within each species, pull out the longest representative of each gene family. **Make a note of this filestring for the fourth input parameter!**
6. Make a Diamond BLAST database. **Make a note of this filestring for the third input parameter!** The file will be called something like `someaminoacidfile.dmnd`

```
diamond makedb --in someaminoacidfile.fa --db someaminoacidfile
```

If you want to use these inhouse datasets they are found:
* blastDB = /ngs/db/ensembl_metazoa/pep/allEnsemblMetazoa_pep.all.fa.fam.longest.dmnd
* blastAA = /ngs/db/ensembl_metazoa/pep/allEnsemblMetazoa_pep.all.fa.fam.longest.fa

**Input 5: Email**

A single email will be sent to this address when `assembly2orf` is complete

## Testing 

`assembly2orf` is run the following way. 

```
trigger-assembly2orf.sh sample_input {path/to/output/dir} reference.dmnd reference.fa {email address}
```

This package includes test files (`assembly2orf/addons/example`). If you are running this on Asellus, and `assembly2orf` is saved in `/home/laura/scripts/assembly2orf`, you shouldn't need to make any changes. Otherwise, you'll need to edit column 2 of `sample_input` to link to the correct nucleotide files.

If you are on Asellus in the directory `/home/laura/scripts/assembly2orf/addons/example`, simply run:

```
/home/laura/scripts/assembly2orf/trigger-assembly2orf.sh sample_input /home/laura/scripts/assembly2orf/addons/example /ngs/db/ensembl_metazoa/pep/allEnsemblMetazoa_pep.all.fa.fam.longest.dmnd /ngs/db/ensembl_metazoa/pep/allEnsemblMetazoa_pep.all.fa.fam.longest.fa {email}
```

----

## Software overview

The following diagram describes the file hierarchy of the `assembly2orf` package:
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

To start the analysis, the user calls `trigger-assembly2orf.sh` and provides a number of input parameters to the program. `trigger-assembly2orf.sh` is a simple script whose role is to read `sample_input` line-by-line and feed this information as input into `assembly2orf.sh` (which in turn calls other scripts). The roles of the files included in this package are described below:  

* `README.md` - this readme file
* `trigger-assembly2orf.sh` - the script which the user will call to run the package
* `dependencies/assembly2orf.sh` - the script which does most of the heavy lifting to analyse each sample in turn
* `dependencies/fasta_header.sh` - a script which reformats fasta files (i.e. shortens fasta headers and removes line breaks within sequences) to make them easier to parse by the program
* `dependencies/filter_homologues.sh` - a script which uses BLAST to remove redundant sequences, based on BLAST hits to a common reference sequence
* `dependencies/PairwiseExonerate.sh` - a script which pairs sequences with their best reference and attempts to remove any frameshift errors within the sequence of interest

## assembly2orf, step by step

This section describes the different steps in the assembly2orf pipeline in detail.

**INITIALISATION**
* **PREPARE VARIABLES** defines a number of variables based on user-specified input
* **PREPARE DIRECTORIES** moves to the user-specified working directory, and generates a new directory for the current sample. All new files generated by the rest of the script will be saved in this directory.
* **PREPARE PARAMETER SPECIFICATION FILE** generates a file that will tell the user which software versions were used to run which commands and the location of the output files, which may be useful for writing up methods sections later.
* **PREPARE FASTA FILES** re-formats the nucleotide.fa file in three different ways: (a) Truncates fasta headers to sequence names only (i.e. remove all description after first space). Why? Some subsequent steps (`fasta_formatter -t`) can't handle multiple spaces in the headers. (b) Converts fasta sequences from multi- to single-line. Why? It is neater and may prevent some file manipulations from breaking. (c) Appends the sample name to the beginning of each sequence. Why? Because it avoids duplicate names if you later combine multiple files from different species. 

**PRE-EXONERATE BLAST**
* Runs blastx (using Diamond) to identify the top blast hit (to a set of asellid/metazoan proteins) for each sequence in the fasta file

**EXONERATE**
* Generates a set of nucleotide files containing [sequences that didn't have frameshifts] + [sequences that had frameshifts but were corrected]. Note that the frameshift-corrected sequences will only be as long as the region of the reference protein to which they were aligned, but the non-frameshift-corrected sequences will remain full-length. This step also removes any sequences that are 100% identical to one another.
* The idea to incorporate frameshift correction into the ORF finding pipeline is inspired by the work of internship student Maury Damien (2014) in collaboration with LBBE (Laurent DURET) and LEHNA (Tristan LEFÉBURE). In this earlier work, the frameshift correction was implemented using the software Geneshift and the use of an ACNUC database.

**TRANSDECODER**
* Runs TransDecoder to identify candidate ORFs (with homology information - hmmer and blast - used to retain sequences not meeting TransDecoders filtering steps. 

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
You will most likely be interested in the contents of *{sample}_transDecoder/output_files/*, the full set of ORFs. The *{sample}_specfile*, which lists software versions and output file locations, may also be useful for publishing your work later.

## To do
* The nohup file generated by this program is annoying to parse. I have it set so you can skip all the Exonerate lines if you do "grep -v "\^" {nohupfile} " but it is still hard because of the blast and hmmer hits that are written to file (and are not easily parse-out-able). It'd be good to work out how to split these logs up into something more readable (different files for each step? append some kind of code in the log so you can remove everything between the two lines of text?
xxxx* I have linked in the script to my old Pfam-A from Deglab - because I couldn't get it to work here. I think this is because I missed the hmmpress step which is required to convert a .hmm into a file that can actually run. hmmpress will make .h3m, .h3i, .h3f, .h3p files - i think (but i need to check) that these need to be in the same file as the .hmm but you trigger hmmscan with .hmmxxxx
xxxx* (3 May 2018) the script uses hmmscan on the old version of Pfam - i tried running hmmscan for something else using this file and it fails. I will need to update the script (~/data/external_data/Pfam/latestDownload_runFails/Pfam-A.hmm) I think i worked out what the problem was when i was working with Panther HMMs. Find this bit in my notes/blog and see what the fix was.xxxx
* The ono redundancy filtering bit is "over-grouping" different opsin paralogues and filteirng them out - i will need to re-thibk this strategy.
* TO DO: Remove the "Ono filtering step" so the final output is the transdecoder output.

## Test

## Version history

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

## Authors and acknowledgements

assembly2orf was built by **Laura Grice** in 2017-2018. This pipeline was developed in collaboration with Tristan Lefébure. The work of internship student Maury Damien - who was supervised by Laurent Duret (LBBE) and Tristan Lefébure (LEHNA) in 2014 - was particularly important for the development of this tool.
