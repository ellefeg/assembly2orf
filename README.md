# assembly2orf
*Laura Grice - Updated 16 January 2018*
A transcriptome preparation pipeline which converts assembled transcriptomes (for example, Trinity output) into frameshift-corrected, filtered ORFs. ####
NOTE TO SELF: #### rows = changed but still need to check after editing everything
----

# Introduction
By calling **TriggerPipeline.sh**, you can convert any number of **nucleotide.fa** files (for example, output from Trinity) into sets of filtered, frameshift-corrected best ORFs. ####EDIT IF REDUNDANCY FILTRATION ADDED#### 

The user will provide a file called **input_param** which lists all the samples to analyse, and will call the program **TriggerPipeline.sh**. The latter program reads **input_param** line-by-line, and analyses each sample in turn by automatically calling the script **Run_TransPipeline.sh** (which will in turn call several other pre-existing and in-house scripts). To know more, see the **Software Overview** section below.

# What is included
Here i will list the things that should be bundled together in the package before it can run

# Software dependencies

SOME OF THIS INFO WOULD BE BETTER IN THE "GETTING STARTED" SECTION ####
The following publicly-available programs must be in your path:
* TransDecoder.LongOrfs, TransDecoder.Predict (part of the Transdecoder package)
* fasta_formatter (part of FASTX Toolkit)
* exonerate, fastaremove (part of Exonerate package)
* diamond
* hmmscan (part of the HMMER package)

To check if you have access to these programs, the following command should show you the help information (if you get an error message the program is not correctly installed).
```
which {program_name}
# if it prints a file string, the program is installed
# if you get no response, the program is not installed
```

Most users will run **assembly2orf** on the Asellus server and will need to make minimal changes before running the program. In this case, the only scripts you need to be concerned with are located in the main **assembly2orf** directory and are called:
* Run_TransPipeline.sh
* TriggerPipeline.sh

Before you modify these files, you will need to copy them to your working directory (see **Getting Started** below)####

There are additional custom scripts that **assembly2orf** requires to run. If you are using the Asellus server you should already have access to these scripts and won't have to change anything. However, if you want to run your own local version, you must edit **Run_TransPipeline.sh**

**assembly2orf** also contains a set of custom scripts (`/assembly2orf/dependencies/`). ~~If you are running **assembly2orf** from `/home/laura/scripts/pipelines/assembly2orf` on the Asellus server, you will automatically have access to these scripts. However, if you want to run your own local version you will need to edit the filepaths specified at the lines of **Run_TransPipeline.sh** specified in brackets below:
* fasta_header.sh (lines 64, 161)
* runDiamondBlastx.sh (line 78)
* PairwiseExonerate.sh (line 92)
* runDiamondBlastp.sh (line 124)
* run_hmmscan.sh (line 126)~~ #by providing assembly2orf with the location of the script library, this is an unnecessary step. But include where the "Default" set is in the readme for inhouse users.

Information about how to do this is given in the **Getting Started** section below.

For BLAST searches using Diamond, you will also require an amino acid blast database (.dmnd format), and also the set of amino acid fasta sequences that were used to build this database. If you want to use the default databases (containing the longest representative sequences from all asellid gene families found in at least 25% of species, plus the longest representative gene family members from the Ensembl Metazoa database) you don't have to make any changes, but if you have a custom database, you will have to edit lines 28 and 29 of **Run_TransPipeline.sh** to add the location of your amino acid fasta file and associated blast diamond database.

# Getting started

Check that the programs TransDecoder.LongOrfs, TransDecoder.Predict, fasta_formatter, exonerate, fastaremove, diamond and hmmscan are in your path:
```
{program_name} -h #or --help for diamond
```

Create a single working directory where your files will be saved. It can have any name and be located wherever you like: the program will generate separate directories for each sample in turn:
```
mkdir /path/to/directory
```

Copy **Trigger_Pipeline.sh** and **Run_TransPipeline.sh** to your working directory BEFORE you modify these files. Do not change the names of the scripts.
```
cp /home/laura/scripts/pipelines/assembly2orf/Run_TransPipeline.sh /path/to/directory
cp /home/laura/scripts/pipelines/assembly2orf/Trigger_Pipeline.sh /path/to/directory
```

If you will be running **assembly2orf** on the Asellus server, navigate to the `/dependencies` directory and check if you have run permissions.
```
cd /home/laura/scripts/pipelines/assembly2orf/dependencies
ls -lth
# each row should start with the following four characters: -rwx
# the x means you can execute the script
```

~~Alternatively, if you will be running your own local version you will need to edit the following lines of your new copy of **Run_TransPipeline.sh**:
* fasta_header.sh (lines 64, 161)
* runDiamondBlastx.sh (line 78)
* PairwiseExonerate.sh (line 92)
* runDiamondBlastp.sh (line 124)
* run_hmmscan.sh (line 126)~~

~~```
vi +{linenumber} Run_TransPipeline.sh # This will take you directly to the correct line
i #now use the cursor/keyboard to edit the filestring
<escape>
:wq #this will save the changes
```~~


~~If you want to use your own amino acid file for BLAST searching, make a Diamond database and edit **Run_TransPipeline.sh** to specify the new filestring
```
diamond makedb --in myAAfasta.fa --db desired_database_name
vi +28 Run_TransPipeline.sh #edit line 28 (diamond database file location) and line 29 (amino acid file location)
```~~ #change to discuss how this is called by the program when you run it







OPTIONAL: generate a custom BLAST fasta file and diamond blast database (.dmnd).
 
In your working directory, create a tab-delimited table called **input_param** which lists all your **nucleotide.fa** files: `{sample name}	{transcript}	{workdir}`
* Sample name = abbreviated name of each sample. Usually this will be a species code (e.g. AAD3, PCG6 etc.)
* Transcript = full filestring for each nucleotide.fa file
* Workdir = full filestring for your working directory. This will be the same for each row.

Edit the filestring in the final line (line 13) of **TriggerPipeline.sh** to contain the full and correct filestring of **input_param**. Make sure **TriggerPipeline.sh** is executable.
```
$ vi +13 TriggerPipeline.sh #will take you directly to the correct line
```
Edit lines 27-29 of **Run_TransPipeline.sh** to specifiy the correct locations of the script library, blast database and blast library sequence files (if different to current specifications). Edit line 181 of the same file to add your own email address. Make sure **Run_TransPipeline.sh** is executable and located in the same folder as **TriggerPipeline.sh** (*see note below*).
```
$ vi +27 Run_TransPipeline.sh
$ vi +181 Run_TransPipeline.sh
```
***NOTE:** If for some reason you want to save **TriggerPipeline.sh** and **Run_TransPipeline.sh** in different locations (e.g. the trigger in your working directory and the pipeline in your scripts folder), make sure you also edit the penultimate line (line 12) of **TriggerPipeline.sh** to indicate the full filestring of **Run_TransPipeline.sh***

Run the program with the following command:
```
$ nohup ./TriggerPipeline.sh > TransPipeline_nohup.out 2>&1&
```

# Software overview
**Run_TransPipeline.sh** will loop through each sample of interest specified in **input_param**. Therefore, the whole script will be run for Sample A, then again for Sample B, etc. 

**INITIALISATION**
* **PREPARE VARIABLES** defines a number of variables based on user/script-specified input
* **PREPARE DIRECTORIES** moves to the user-specified working directory, and generates a new directory for the current sample. All new files generated by the rest of the script will be saved in this directory.
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

**PREPARE FASTA FILES**
* Re-formats the Transdecoder output as described in PREPARE FASTA FILES above

**TIDYING UP**
* Moves all the files to a temp directory

**The final output**
* At the end, your working directory will contain a number of directories, one for each sample. In each directory, you will see:
-- {sample}_TrinityFS.fa: the re-formatted version of the input file. There is no new information here, just the headers are neater etc. (see PREPARE FASTA FILES above)
-- {sample}_ORFs.fa: the final output file (mRNA format; not CDS)
-- TransPipeline_interim: directory containing all the temp files
    1.  OPTIONAL: {sample}_trinity.fa - <for some samples this file is here, elsewhere it is back a directory, not sure why?
    2.  {sample}_FSblastx.out - the results of the blast search used to work out which sequences to use for frameshift correction
    3.  {sample}_exonerate_tempfiles - directory with exonerate output
    4.  {sample}_transDecoderTemp - directory with transdecoder output
    5.  {sample}_ORFs.info - the header information produced by TransDecoder, just in case the truncated names in the final output file are insufficient

# Next steps
*This section added 6 December 2017*
Based on the paper by Ono et al. 2013 (BMC Genomics 2015 16:1031), I tested various methods of filtering transcriptomes. By reducing the redundancy in a transcriptome dataset, you remove sequences that are too similar to one another to be able to be properly mapped/distinguished between in DGE analysis. By removing this data, DGE outcomes were found to be improved. The method I settled on involves BLASTing a sequence dataset (within a species) against a reference database, and for all new sequences with a top BLAST hit to SeqA, take only the longest sequence. The results of this analysis (nt or aa) can be found here:
/home/laura/data/inhouse_data/TransPipeline/1_pipeline/OnoFiltering/

# To do
* Remove the need for new users to edit the scripts to add e.g. path names, by allowing this to be specified elsewhere e.g. in **TriggerPipeline.sh**
* The nohup file generated by this program is annoying to parse. I have it set so you can skip all the Exonerate lines if you do "grep -v "\^" {nohupfile} " but it is still hard because of the blast and hmmer hits that are written to file (and are not easily parse-out-able). It'd be good to work out how to split these logs up into something more readable (different files for each step? append some kind of code in the log so you can remove everything BETWEEN TWO LINES OF TEXT?

# Version history
v00.01 - 28 July 2017
v00.02 - 13 August 2017
* Original incorrect $blastDB and $blastFA files (erroneously containing a mix of nucleotide and amino acid sequences) were replaced with correct (amino acid only) sequences. No change to the script, just to the files specified in lines 28-29 of Run_TransPipeline.sh.

v01.00 - 16 January 2018
* Updated for new Asellus server and to make the program into more of a "bundle" that can be run by anyone
* Changed pipeline name from TransPipeline to assembly2orf

