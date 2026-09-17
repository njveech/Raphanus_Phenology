# Merge Roboflow counts with the 2026 unified occurrence table.
# Copy/adapt of GBIF_data_combining/merge_counts_gbif_data.R for this redo.
# Run from project root after json_to_df.py has written gbif_repro_counts:
#   Rscript GBIF_2026_update/merge_counts_gbif_data.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

path_unmatched_no_metadata <- file.path(this_dir, "gbif_repro_counts_unmatched_no_metadata.csv")

occ_cols <- c(
  "institutionCode", "recordedBy", "eventDate", "startDayOfYear", "endDayOfYear",
  "year", "month", "day", "verbatimEventDate", "stateProvince", "county",
  "municipality", "locality", "decimalLatitude", "decimalLongitude",
  "coordinateUncertaintyInMeters", "scientificName", "specificEpithet",
  "cch2_occid"
)
coord_cols <- c("decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters")

coalesce_char <- function(primary, secondary) {
  primary <- na_if(trimws(as.character(primary)), "")
  secondary <- na_if(trimws(as.character(secondary)), "")
  coalesce(primary, secondary)
}

is_catalog_image <- function(x) {
  grepl("^(CDA-|YOSE|SD000)", x)
}

# Unscorable images (e.g. roots only, wrong species) — excluded from merge output
unscorable_image_ids <- c(
  "3865376379", "3897880503", "3865094236", "3331193610", "3331194244",
  "2859098605", "SML_1999235118", "3865109363", "3331201163", "3969683961",
  "2517114190", "2265941363", "1998980671", "3865374367", "3865108376",
  "1998922892", "3865096296", "3897882331", "3331193053", "3710072566"
)

if (!file.exists(path_counts)) {
  stop("Counts file not found: ", path_counts, " — run json_to_df.py after Roboflow.")
}

counts <- read_csv(path_counts, show_col_types = FALSE) %>%
  mutate(image = as.character(image)) %>%
  mutate(image = sub("^SML_", "", image)) %>%
  filter(!image %in% unscorable_image_ids, !paste0("SML_", image) %in% unscorable_image_ids)

occ <- read_csv(
  path_occ_unified,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber)
  )

added_full <- read_csv(
  path_occ_added_coords,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber)
  )

audit <- NULL
if (file.exists(path_audit)) {
  audit <- read_csv(path_audit, col_types = cols(.default = col_character()), show_col_types = FALSE)
}

catalog_to_gbif <- bind_rows(
  occ %>% select(gbifID, catalogNumber),
  added_full %>% select(gbifID, catalogNumber)
) %>%
  filter(!is.na(catalogNumber), catalogNumber != "") %>%
  distinct(catalogNumber, .keep_all = TRUE)

occ_by_gbif <- occ %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  select(gbifID, all_of(intersect(occ_cols, names(.))))

occ_gbif_ids <- occ_by_gbif$gbifID

added_coords <- added_full %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  select(gbifID, all_of(coord_cols)) %>%
  rename_with(~ paste0(.x, "__added"), -gbifID)

counts_with_gbif <- counts %>%
  mutate(
    catalogNumber = image,
    gbif_id_from_image = sub("^SML_", "", image)
  ) %>%
  left_join(
    catalog_to_gbif %>% rename(gbifID_from_catalog = gbifID),
    by = "catalogNumber"
  ) %>%
  mutate(
    gbifID = case_when(
      !is.na(gbifID_from_catalog) ~ gbifID_from_catalog,
      is_catalog_image(image) ~ NA_character_,
      TRUE ~ gbif_id_from_image
    )
  ) %>%
  select(-gbif_id_from_image, -gbifID_from_catalog)

# Refuse counts whose image ID is not ok in the audit sheet (when audit exists).
if (!is.null(audit)) {
  ok_gbif <- audit %>%
    filter(id_check_status == "ok", !is_blank(gbifID)) %>%
    pull(gbifID) %>%
    unique()
  ok_stems <- audit %>%
    filter(id_check_status == "ok") %>%
    pull(original_filename) %>%
    stem_filename() %>%
    unique()
  counts_with_gbif <- counts_with_gbif %>%
    mutate(
      audit_ok = gbifID %in% ok_gbif | image %in% ok_stems | catalogNumber %in% ok_stems
    )
  refused <- counts_with_gbif %>% filter(!audit_ok)
  if (nrow(refused) > 0) {
    write_csv(refused, file.path(this_dir, "gbif_repro_counts_refused_failed_id_check.csv"))
    message("Refused ", nrow(refused), " count rows that failed the image ID audit.")
  }
  counts_with_gbif <- counts_with_gbif %>% filter(audit_ok) %>% select(-audit_ok)
}

merged <- counts_with_gbif %>%
  left_join(occ_by_gbif, by = "gbifID") %>%
  left_join(added_coords, by = "gbifID") %>%
  mutate(
    across(
      all_of(coord_cols),
      ~ coalesce_char(.x, get(paste0(cur_column(), "__added")))
    )
  ) %>%
  select(-ends_with("__added")) %>%
  mutate(matched_occurrence = !is.na(gbifID) & gbifID %in% occ_gbif_ids)

write_csv(merged %>% select(-matched_occurrence), path_merged)

n_matched_metadata <- sum(merged$matched_occurrence)
n_with_coords <- sum(!is.na(merged$decimalLatitude) & merged$decimalLatitude != "")
n_catalog_resolved <- sum(
  is_catalog_image(merged$image) &
    !is.na(merged$gbifID) &
    merged$gbifID != ""
)

message(
  "Excluded ", length(unscorable_image_ids), " unscorable image IDs from counts input."
)

message(
  "Wrote ", nrow(merged), " rows to ", path_merged, ". ",
  "Matched occurrence metadata for ", n_matched_metadata, " rows; ",
  "coordinates present for ", n_with_coords, " rows; ",
  "catalog-number images resolved to gbifID: ", n_catalog_resolved, "."
)

unmatched_metadata <- merged %>%
  filter(!matched_occurrence) %>%
  arrange(image) %>%
  select(image, catalogNumber, gbifID, any_of(c("Bud Cluster", "Flower", "Fruit")))

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
