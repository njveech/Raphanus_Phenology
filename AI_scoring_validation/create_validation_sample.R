# Random validation sample: gbifID, image link, AI y/n scores, blank manual columns.
# Run from project root: Rscript AI_scoring_validation/create_validation_sample.R

library(dplyr)
library(readr)

set.seed(20260527)

n_sample <- 100L
path_counts <- "GBIF_data_combining/gbif_repro_counts"
path_merged <- "GBIF_data_combining/gbif_repro_counts_merged.csv"
path_multimedia <- "original_gbif_download/multimedia.txt"
path_out <- "AI_scoring_validation/validation_sample_100.csv"

yn <- function(x) ifelse(as.numeric(x) > 0, "y", "n")

counts <- read_csv(path_counts, show_col_types = FALSE)

gbif_lookup <- read_csv(path_merged, show_col_types = FALSE) %>%
  mutate(
    image = as.character(image),
    gbifID = as.character(gbifID)
  ) %>%
  distinct(image, .keep_all = TRUE) %>%
  select(image, gbifID)

multimedia <- read_tsv(path_multimedia, show_col_types = FALSE) %>%
  mutate(
    gbifID = as.character(gbifID),
    multimedia_link = coalesce(
      na_if(trimws(identifier), ""),
      na_if(trimws(references), "")
    )
  ) %>%
  filter(!is.na(multimedia_link)) %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  select(gbifID, multimedia_link)

eligible <- counts %>%
  mutate(image = as.character(image)) %>%
  left_join(gbif_lookup, by = "image") %>%
  filter(!is.na(gbifID), gbifID != "") %>%
  inner_join(multimedia, by = "gbifID")

if (n_distinct(eligible$gbifID) < n_sample) {
  stop(
    "Only ", n_distinct(eligible$gbifID),
    " gbifIDs with multimedia links; need ", n_sample, "."
  )
}

sampled <- eligible %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  slice_sample(n = n_sample) %>%
  transmute(
    gbifID,
    multimedia_link,
    buds = yn(`Bud Cluster`),
    flowers = yn(Flower),
    fruit = yn(Fruit),
    `V.buds` = "",
    `V.flowers` = "",
    `V.fruit` = ""
  ) %>%
  arrange(gbifID)

write_csv(sampled, path_out)
message("Wrote ", nrow(sampled), " rows to ", path_out)
