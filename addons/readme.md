This folder contains additional stand-alone tools which are associated with the assembly2orf pipeline.

**example** contains files required to test assembly2orf on a sample dataset

You can run `RunBUSCO.sh` to test for completeness of your transcriptomes.

Once you have analysed all your samples, you can combine the desired fasta files and use ``RunSilix.sh`` to create gene families. This script will actually test a range of overlap and % ID parameters (from 60 - 80%) and you can choose the "best".

If you have already created Silix gene families, you can run `getOrthos_1-1.sh` and `getOrthos_nonzero.sh` to count the numbers of orthologous families.




