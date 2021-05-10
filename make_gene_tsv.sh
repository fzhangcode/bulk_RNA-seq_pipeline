#!/usr/bin/env bash

fa=/data/srlab/mgutierr/annotation/ensembl83_cdna_lincrna/Homo_sapiens.GRCh38.cdna.lincrna.filtered.fa 
tsvgz=Homo_sapiens.GRCh38.cdna.lincrna.filtered.tsv.gz

grep '>' "$fa" | tr ' ' '\t' | pigz > "$tsvgz"

