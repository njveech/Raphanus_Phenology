# Build filtered occurrence table from the 09.10.2026 GBIF download,
# overlay researched coordinates, and write CCH2/SD/CDA/YOSE unmatched
# rows for review (not appended to the analysis table).
# Run from project root:
#   Rscript GBIF_2026_update/build_unified_occurrence.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

dir.create(this_dir, showWarnings = FALSE)

occ <- read_gbif_tsv(path_fresh_occ) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber),
    occurrenceID = as.character(occurrenceID),
    institutionCode = as.character(institutionCode),
    cch2_occid = coalesce(
      extract_cch2_occid_vec(references),
      extract_cch2_occid_vec(occurrenceID),
      extract_cch2_occid_vec(otherCatalogNumbers)
    )
  )

n0 <- nrow(occ)
after_state <- occ %>% filter(!stateProvince %in% states_exclude)
n_state <- n0 - nrow(after_state)
after_country <- after_state %>% filter(countryCode == "US")
n_country <- nrow(after_state) - nrow(after_country)
after_basis <- after_country %>% filter(basisOfRecord == "PRESERVED_SPECIMEN")
n_basis <- nrow(after_country) - nrow(after_basis)
after_locality <- after_basis %>%
  filter(!(is_blank(locality) & is_blank(verbatimLocality)))
n_locality <- nrow(after_basis) - nrow(after_locality)

# Keep CCH2 catalog overlap (do not drop). No mediaType filter.
occ_unified <- after_locality

removals_breakdown <- tibble(
  reason = c(
    "Excluded state (stateProvince in states_exclude)",
    "Country not US",
    "basisOfRecord not PRESERVED_SPECIMEN",
    "Empty locality (county-only)"
  ),
  n_removed = c(n_state, n_country, n_basis, n_locality)
) %>%
  mutate(n_remaining_after = n0 - cumsum(n_removed), .after = n_removed)

write_csv(removals_breakdown, path_filter_breakdown)
print(removals_breakdown)

cch2_catalog <- read_csv(
  path_cch2_catalog,
  show_col_types = FALSE
) %>%
  pull(1) %>%
  as.character() %>%
  trimws() %>%
  unique()
cch2_catalog <- cch2_catalog[nzchar(cch2_catalog)]

sd_map <- read_tsv(
  path_sd_map,
  col_names = c("sd_filename", "occid_filename"),
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    sd_barcode = stem_filename(sd_filename),
    cch2_occid = stem_filename(occid_filename)
  )

# Fill CCH2 occid from catalogNumber when the GBIF catalog is an occid from the CCH2 list,
# or from the SD barcode mapping.
occ_unified <- occ_unified %>%
  left_join(
    sd_map %>%
      select(sd_barcode, cch2_occid_from_sd = cch2_occid) %>%
      distinct(sd_barcode, .keep_all = TRUE),
    by = c("catalogNumber" = "sd_barcode")
  ) %>%
  mutate(
    cch2_occid = coalesce(
      cch2_occid,
      ifelse(catalogNumber %in% cch2_catalog, catalogNumber, NA_character_),
      cch2_occid_from_sd
    )
  ) %>%
  select(-cch2_occid_from_sd)

# --- researched GBIF coordinates (match? first token = yes) ---
coords_raw <- read_csv(
  path_researched_coords,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
match_col <- names(coords_raw)[grepl("^match", names(coords_raw), ignore.case = TRUE)]
if (length(match_col) == 0) {
  stop("No match? column in researched coords file")
}

old_occ <- read_gbif_tsv(path_old_occ) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber),
    occurrenceID = as.character(occurrenceID),
    institutionCode = as.character(institutionCode)
  ) %>%
  select(gbifID, catalogNumber, occurrenceID, institutionCode) %>%
  distinct(gbifID, .keep_all = TRUE)

researched <- coords_raw %>%
  filter(match_yes(.data[[match_col[[1]]]])) %>%
  mutate(
    gbifID = as.character(gbifID),
    across(all_of(coord_cols), norm_chr),
    locality_key = paste(norm_chr(locality), norm_chr(verbatimLocality), sep = "||")
  ) %>%
  left_join(
    old_occ %>% rename(
      catalogNumber_old = catalogNumber,
      occurrenceID_old = occurrenceID,
      institutionCode_old = institutionCode
    ),
    by = "gbifID"
  ) %>%
  mutate(
    catalogNumber = catalogNumber_old,
    occurrenceID = occurrenceID_old,
    institutionCode = institutionCode_old
  ) %>%
  select(-ends_with("_old")) %>%
  filter(!is_blank(decimalLatitude) | !is_blank(decimalLongitude))

old_added <- read_csv(
  path_old_added_coords,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber),
    across(all_of(intersect(coord_cols, names(.))), norm_chr)
  )

cch2_done <- read_csv(
  path_cch2_completed,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    cch2_occid = as.character(id),
    across(any_of(coord_cols), norm_chr)
  )

# researched / replace=TRUE overwrites GBIF/GeoLocate; fill-only only fills blanks.
apply_coords <- function(df, donor, by_cols, replace = TRUE) {
  present_by <- intersect(by_cols, names(donor))
  present_coords <- intersect(coord_cols, names(donor))
  if (length(present_by) < length(by_cols) || length(present_coords) == 0) {
    return(df)
  }
  donor_small <- donor %>%
    select(all_of(present_by), all_of(present_coords)) %>%
    filter(if_all(all_of(present_by), ~ !is_blank(.x))) %>%
    distinct(across(all_of(present_by)), .keep_all = TRUE) %>%
    rename_with(~ paste0(.x, "__res"), all_of(present_coords))
  if (nrow(donor_small) == 0) {
    return(df)
  }
  out <- df %>% left_join(donor_small, by = present_by)
  for (col in present_coords) {
    res <- paste0(col, "__res")
    if (!res %in% names(out)) {
      next
    }
    if (replace) {
      out[[col]] <- ifelse(!is_blank(out[[res]]), out[[res]], out[[col]])
    } else {
      out[[col]] <- ifelse(is_blank(out[[col]]) & !is_blank(out[[res]]), out[[res]], out[[col]])
    }
  }
  out %>% select(-ends_with("__res"))
}

occ_unified <- occ_unified %>%
  mutate(
    across(all_of(coord_cols), norm_chr),
    locality_key = paste(norm_chr(locality), norm_chr(verbatimLocality), sep = "||")
  )

n_coords_before <- sum(!is_blank(occ_unified$decimalLatitude))

# Fill blanks from the previous added-coords dump, then overwrite with researched yes-rows.
occ_unified <- apply_coords(
  occ_unified,
  old_added %>% select(gbifID, all_of(coord_cols)),
  "gbifID",
  replace = FALSE
)
occ_unified <- apply_coords(
  occ_unified,
  old_added %>% select(catalogNumber, all_of(coord_cols)),
  "catalogNumber",
  replace = FALSE
)
occ_unified <- apply_coords(
  occ_unified,
  researched %>% select(gbifID, all_of(coord_cols)),
  "gbifID",
  replace = TRUE
)
occ_unified <- apply_coords(
  occ_unified,
  researched %>% select(occurrenceID, all_of(coord_cols)),
  "occurrenceID",
  replace = TRUE
)
occ_unified <- apply_coords(
  occ_unified,
  researched %>% select(institutionCode, catalogNumber, all_of(coord_cols)),
  c("institutionCode", "catalogNumber"),
  replace = TRUE
)
occ_unified <- apply_coords(
  occ_unified,
  researched %>% select(locality_key, all_of(coord_cols)),
  "locality_key",
  replace = FALSE
)
occ_unified <- apply_coords(
  occ_unified,
  cch2_done %>% select(cch2_occid, all_of(coord_cols)),
  "cch2_occid",
  replace = TRUE
)

n_coords_after <- sum(!is_blank(occ_unified$decimalLatitude))

crosswalk <- occ_unified %>%
  select(
    gbifID, catalogNumber, institutionCode, cch2_occid,
    locality, eventDate, scientificName
  ) %>%
  mutate(in_unified_occurrence = TRUE)

cda_yose_ids <- stem_filename(list_jpgs(dir_cda_yose_images))

cch2_from_images <- tibble(
  source = "cch2_image_file",
  cch2_occid = stem_filename(list_jpgs(dir_cch2_images)),
  catalogNumber = NA_character_,
  institutionCode = NA_character_,
  locality = NA_character_
) %>%
  filter(!is_blank(cch2_occid)) %>%
  distinct(cch2_occid, .keep_all = TRUE)

cch2_from_list <- tibble(
  source = "cch2_2025_full_id_list",
  cch2_occid = cch2_catalog,
  catalogNumber = NA_character_,
  institutionCode = NA_character_,
  locality = NA_character_
)

cch2_from_completed <- cch2_done %>%
  transmute(
    source = "completed_specimen_data",
    cch2_occid,
    catalogNumber = NA_character_,
    institutionCode,
    locality
  )

sd_from_map <- sd_map %>%
  transmute(
    source = "ucd_imaged_sd",
    cch2_occid,
    catalogNumber = sd_barcode,
    institutionCode = "SD",
    locality = NA_character_
  )

cda_yose_from_files <- tibble(
  source = "locally_imaged_cda_yose",
  cch2_occid = NA_character_,
  catalogNumber = cda_yose_ids,
  institutionCode = ifelse(startsWith(cda_yose_ids, "CDA"), "CDA", "YOSE"),
  locality = NA_character_
)

candidates <- bind_rows(
  cch2_from_images, cch2_from_list, cch2_from_completed, sd_from_map, cda_yose_from_files
)

matched_occids <- unique(na.omit(occ_unified$cch2_occid))
matched_cats <- unique(na.omit(norm_chr(occ_unified$catalogNumber)))

unmatched <- candidates %>%
  mutate(
    matched_by_occid = !is_blank(cch2_occid) & cch2_occid %in% matched_occids,
    matched_by_catalog = !is_blank(catalogNumber) & catalogNumber %in% matched_cats
  ) %>%
  filter(!matched_by_occid & !matched_by_catalog) %>%
  mutate(
    match_fail_reason = case_when(
      source == "locally_imaged_cda_yose" ~
        "catalogNumber not found in filtered 09.10.2026 GBIF occurrence",
      source == "ucd_imaged_sd" ~
        "SD barcode / mapped CCH2 occid not found in filtered 09.10.2026 GBIF occurrence",
      TRUE ~ "CCH2 occid not found via GBIF references URL (occid=) or catalogNumber in filtered occurrence"
    )
  ) %>%
  distinct() %>%
  arrange(source, cch2_occid, catalogNumber)

occ_out <- occ_unified %>% select(-locality_key)
write_csv(unmatched, path_unmatched_review)
write_csv(crosswalk, path_crosswalk)
write_csv(occ_out, path_occ_unified)
write_csv(occ_out, path_occ_added_coords)

message(
  "Unified occurrence rows: ", nrow(occ_unified),
  ". Coords before overlay: ", n_coords_before,
  "; after overlay: ", n_coords_after, "."
)
message(
  "CCH2 occids on unified GBIF rows: ",
  sum(!is_blank(occ_unified$cch2_occid)), "."
)
message(
  "Unmatched CCH2/SD/CDA/YOSE rows for review: ", nrow(unmatched),
  " -> ", path_unmatched_review
)
print(unmatched %>% count(source), n = Inf)
