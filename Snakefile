#!/PHShome/fz049/miniconda3/bin/python
'''
kallisto.snakefile

Quantify transcript expression in paired-end RNA-seq data with kallisto
-----------------------------------------------------------------------

Requirements:

  kallisto
      https://pachterlab.github.io/kallisto/download.html

Usage: 

  snakemake --jobs 999 --cluster 'bsub.py -o stdout'
'''

import json
from os.path import join, basename, dirname
from os import getcwd
from subprocess import check_output
from itertools import chain

# Globals ---------------------------------------------------------------------

# Full path to an uncompressed FASTA file with all chromosome sequences.
CDNA = '/data/srlab/mgutierr/annotation/ensembl83_cdna_lincrna/Homo_sapiens.GRCh38.cdna.lincrna.filtered.fa'

# Full path to a folder where intermediate output files will be created.
OUT_DIR = '/data/srlab2/fzhang/results/2021-05-03_Helena_bulk_RNA/output'
# OUT_DIR = join(getcwd(), 'output')

# Samples and their corresponding filenames.
FILES = json.load(open('./samples.json'))
SAMPLES = sorted(FILES.keys())

# KALLISTO = '/data/srlab/slowikow/src/kallisto_linux-v0.43.1/kallisto'

KALLISTO_VERSION = check_output("echo $(kallisto)", shell=True).split()[1]

# Functions -------------------------------------------------------------------

def rstrip(text, suffix):
    # Remove a suffix from a string.
    if not text.endswith(suffix):
        return text
    return text[:len(text)-len(suffix)]

# Rules -----------------------------------------------------------------------

rule all:
    input:
        'abundance.tsv.gz',
        'n_processed.tsv.gz'

rule kallisto_index:
    input:
        cdna = CDNA
    output:
        index = join(dirname(CDNA), 'kallisto', rstrip(basename(CDNA), '.fa'))
    log:
        join(dirname(CDNA), 'kallisto/kallisto.index.log')
    benchmark:
        join(dirname(CDNA), 'kallisto/kallisto.index.benchmark.tsv')
    version:
        KALLISTO_VERSION
    run:
        # Record the kallisto version number in the log file.
        shell('echo $(kallisto index) &> {log}')
        # Write stderr and stdout to the log file.
        shell('kallisto index'
              ' --index={output.index}'
              ' --kmer-size=21'
              ' --make-unique'
              ' {input.cdna}'
              ' >> {log} 2>&1')

rule kallisto_quant:
    input:
        r1 = lambda wildcards: FILES[wildcards.sample]['R1'],
        r2 = lambda wildcards: FILES[wildcards.sample]['R2'],
        index = rules.kallisto_index.output.index
    output:
        join(OUT_DIR, '{sample}', 'abundance.tsv'),
        join(OUT_DIR, '{sample}', 'run_info.json')
    benchmark:
        join(OUT_DIR, '{sample}', 'kallisto.quant.benchmark.tsv')
    version:
        KALLISTO_VERSION
    threads:
        4
    resources:
        mem = 4000
    run:
        fastqs = ' '.join(chain.from_iterable(zip(input.r1, input.r2)))
        shell('kallisto quant'
              ' --threads={threads}'
              ' --index={input.index}'
              ' --output-dir=' + join(OUT_DIR, '{wildcards.sample}') +
              ' ' + fastqs)

rule collate_kallisto:
    input:
        expand(join(OUT_DIR, '{sample}', 'abundance.tsv'), sample=SAMPLES)
    output:
        'abundance.tsv.gz'
    run:
        import gzip

        b = lambda x: bytes(x, 'UTF8')

        # Create the output file.
        with gzip.open(output[0], 'wb') as out:

            # Print the header.
            header = open(input[0]).readline()
            out.write(b('sample\t' + header))

            for i in input:
                sample = basename(dirname(i))
                lines = open(i)
                # Skip the header in each file.
                lines.readline()
                for line in lines:
                    # Skip transcripts with 0 TPM.
                    fields = line.strip().split('\t')
                    if float(fields[4]) > 0:
                        out.write(b(sample + '\t' + line))

rule n_processed:
    input:
        expand(join(OUT_DIR, '{sample}', 'run_info.json'), sample=SAMPLES)
    output:
        'n_processed.tsv.gz'
    run:
        import json
        import gzip

        b = lambda x: bytes(x, 'UTF8')

        with gzip.open(output[0], 'wb') as out:
            out.write(b('sample\tn_processed\n'))

            for f in input:
                sample = basename(dirname(f))
                n = json.load(open(f)).get('n_processed')
                out.write(b('{}\t{}\n'.format(sample, n)))

