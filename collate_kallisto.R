#!/usr/bin/env Rscript

library(tximport)
library(stringr)
library(readr)
library(biomaRt)

# Collate all of the Kallisto output files.
files <- Sys.glob(
  "/data/srlab2/fzhang/results/2021-05-03_Helena_bulk_RNA/output/*/abundance.h5"
)
names(files) <- sapply(stringr::str_split(files, "/"), "[[", 8)

# Dataframe with 2 columns: transcript_id, gene_id
genes <- read_tsv(
  file = "/data/srlab/public/srcollab/AMP/amp_phase1_ra/validation_data/Homo_sapiens.GRCh38.cdna.lincrna.filtered.tsv.gz",
  col_names = FALSE
)
genes <- genes[,c("X1", "X4")]
colnames(genes) <- c("transcript_id", "gene_id")
genes$transcript_id <- str_replace(genes$transcript_id, ">", "")
genes$gene_id <- str_replace(genes$gene_id, "gene:", "")
genes$gene_id <- str_replace(genes$gene_id, "\\.\\d+$", "")

genes_tsv <- "Homo_sapiens.GRCh38.cdna.lincrna.filtered.genes.tsv.gz"
if (!file.exists(genes_tsv)) {
  # Convert Ensembl IDs to HGNC gene symbols.
  mart <- useDataset("hsapiens_gene_ensembl", useMart("ensembl"))

  bm <- getBM(
    filters    = "ensembl_gene_id",
    attributes = c("ensembl_gene_id","hgnc_symbol"),
    values     = genes$gene_id,
    mart       = mart
  )

  x <- merge(
    x    = genes,
    y    = bm,
    by.x = "gene_id",
    by.y = "ensembl_gene_id",
    all  = TRUE
  )

  write_tsv(x, genes_tsv)
}

# Read files and collapse to gene level.
txi <- tximport(files, type = "kallisto", tx2gene = genes)

# Save the whole object.
saveRDS(txi, "bulk_ensembl83_txi.rds")

