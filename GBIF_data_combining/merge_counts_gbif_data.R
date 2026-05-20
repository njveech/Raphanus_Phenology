# Merge gbif_repro_counts with GBIF occurrence metadata and added coordinates.
# For CDA-/YOSE-style image IDs (catalog numbers), resolve gbifID via catalogNumber
# before joining occurrence fields. Run from project root:
#   Rscript GBIF_data_combining/merge_counts_gbif_data.R

library(dplyr)
library(readr)

data_dir <- "GBIF_data_combining"
path_counts <- file.path(data_dir, "gbif_repro_counts")
path_occurrence <- file.path(data_dir, "occurrence.txt")
path_added_coords <- file.path(data_dir, "occurence_w_added_coords.csv")
path_out <- file.path(data_dir, "gbif_repro_counts_merged.csv")
path_unmatched_no_metadata <- file.path(data_dir, "gbif_repro_counts_unmatched_no_metadata.csv")

occ_cols <- c(
  "institutionCode", "recordedBy", "eventDate", "startDayOfYear", "endDayOfYear",
  "year", "month", "day", "verbatimEventDate", "stateProvince", "county",
  "municipality", "locality", "decimalLatitude", "decimalLongitude",
  "coordinateUncertaintyInMeters", "scientificName", "specificEpithet"
)
coord_cols <- c("decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters")

coalesce_char <- function(primary, secondary) {
  primary <- na_if(trimws(as.character(primary)), "")
  secondary <- na_if(trimws(as.character(secondary)), "")
  coalesce(primary, secondary)
}

is_catalog_image <- function(x) {
  grepl("^(CDA-|YOSE)", x)
}

counts <- read_csv(path_counts, show_col_types = FALSE) %>%
  mutate(image = as.character(image))

occ <- read_tsv(
  path_occurrence,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber)
  )

added_full <- read_csv(
  path_added_coords,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber)
  )

# catalogNumber -> gbifID lookup (occurrence first, then added-coords file)
catalog_to_gbif <- bind_rows(
  occ %>% select(gbifID, catalogNumber),
  added_full %>% select(gbifID, catalogNumber)
) %>%
  filter(!is.na(catalogNumber), catalogNumber != "") %>%
  distinct(catalogNumber, .keep_all = TRUE)

occ_by_gbif <- occ %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  select(gbifID, all_of(occ_cols))

added_coords <- added_full %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  select(gbifID, all_of(coord_cols)) %>%
  rename_with(~ paste0(.x, "__added"), -gbifID)

# Step 1: resolve gbifID (catalogNumber match for CDA/YOSE; else SML-stripped image id)
counts_with_gbif <- counts %>%
  mutate(
    catalogNumber = image,
    gbif_id_from_image = sub("^SML_", "", image)
  ) %>%
  left_join(
    catalog_to_gbif %>% rename(gbifID_from_catalog = gbifID),
    by = c("catalogNumber" = "catalogNumber")
  ) %>%
  mutate(
    gbifID = case_when(
      !is.na(gbifID_from_catalog) ~ gbifID_from_catalog,
      is_catalog_image(image) ~ NA_character_,
      TRUE ~ gbif_id_from_image
    )
  ) %>%
  select(-gbif_id_from_image, -gbifID_from_catalog)

# Step 2: join occurrence metadata on resolved gbifID
merged <- counts_with_gbif %>%
  left_join(occ_by_gbif, by = "gbifID") %>%
  left_join(added_coords, by = "gbifID") %>%
  mutate(
    across(
      all_of(coord_cols),
      ~ coalesce_char(.x, get(paste0(cur_column(), "__added")))
    )
  ) %>%
  select(-ends_with("__added"))

write_csv(merged, path_out)

n_matched_metadata <- sum(!is.na(merged$institutionCode) & merged$institutionCode != "")
n_with_coords <- sum(!is.na(merged$decimalLatitude) & merged$decimalLatitude != "")
n_catalog_resolved <- sum(
  is_catalog_image(merged$image) &
    !is.na(merged$gbifID) &
    merged$gbifID != ""
)

message(
  "Wrote ", nrow(merged), " rows to ", path_out, ". ",
  "Matched occurrence metadata for ", n_matched_metadata, " rows; ",
  "coordinates present for ", n_with_coords, " rows; ",
  "catalog-number images resolved to gbifID: ", n_catalog_resolved, "."
)

unmatched_metadata <- merged %>%
  filter(is.na(institutionCode) | institutionCode == "") %>%
  arrange(image) %>%
  select(image, catalogNumber, gbifID, `Bud Cluster`, Flower, Fruit)

unmatched_no_metadata <- unmatched_metadata %>%
  filter(!is_catalog_image(image))

write_csv(unmatched_no_metadata, path_unmatched_no_metadata)

if (nrow(unmatched_metadata) > 0) {
  message(
    "\nRows without occurrence metadata (", nrow(unmatched_metadata), "):\n"
  )
  print(unmatched_metadata, n = Inf)
} else {
  message("\nAll rows matched occurrence metadata.")
}

if (nrow(unmatched_no_metadata) > 0) {
  message(
    "Wrote ", nrow(unmatched_no_metadata),
    " image IDs lacking metadata to ", path_unmatched_no_metadata, "."
  )
}
