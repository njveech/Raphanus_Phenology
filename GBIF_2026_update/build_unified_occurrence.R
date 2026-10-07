# Build filtered occurrence table from the 09.10.2026 GBIF download,
# overlay researched coordinates, and write CCH2/SD/CDA/YOSE unmatched
# rows for review (not appended to the analysis table).
# Run from project root:
#   Rscript GBIF_2026_update/build_unified_occurrence.R

library(dplyr)
library(readr)
library(readxl)

source("GBIF_2026_update/paths.R")

# Create the output folder on a first run so later writes have somewhere to go.
dir.create(this_dir, showWarnings = FALSE)

# read_gbif_tsv reads a GBIF TSV with every column kept as character.
# Here it loads the 09.10.2026 occurrence download.
# extract_cch2_occid_vec pulls the numeric CCH2 occid from strings that contain "occid=".
# Here it sets cch2_occid from references.
occ <- read_gbif_tsv(path_fresh_occ) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber),
    occurrenceID = as.character(occurrenceID),
    institutionCode = as.character(institutionCode),
    cch2_occid = extract_cch2_occid_vec(references)
  )

# Count rows removed for an excluded state, a non-US country, and a non-specimen basis.
n0 <- nrow(occ)
after_state <- occ %>% filter(!stateProvince %in% states_exclude)
n_state <- n0 - nrow(after_state)
after_country <- after_state %>% filter(countryCode == "US")
n_country <- nrow(after_state) - nrow(after_country)
after_basis <- after_country %>% filter(basisOfRecord == "PRESERVED_SPECIMEN")
n_basis <- nrow(after_country) - nrow(after_basis)
# is_blank is true when a value is NA, blank, "NA", or "0".
# Here a row is kept when county is present even if both locality fields are blank.
after_geo <- after_basis %>%
  filter(!(is_blank(locality) & is_blank(verbatimLocality) & is_blank(county)))
n_geo <- nrow(after_basis) - nrow(after_geo)

# Keep CCH2 catalog overlap (do not drop). No mediaType filter.
occ_unified <- after_geo

# Record how many rows each filter removed and how many remained afterward.
removals_breakdown <- tibble(
  reason = c(
    "Excluded state (stateProvince in states_exclude)",
    "Country not US",
    "basisOfRecord not PRESERVED_SPECIMEN",
    "Empty locality and empty county"
  ),
  n_removed = c(n_state, n_country, n_basis, n_geo)
) %>%
  mutate(n_remaining_after = n0 - cumsum(n_removed), .after = n_removed)

write_csv(removals_breakdown, path_filter_breakdown)
print(removals_breakdown)

# Local image moves supply SD and CDA/YOSE filenames that are no longer in the
# image folders. A missing log becomes an empty table so those lookups still run.
local_move_log <- if (file.exists(path_local_move_log)) {
  read_csv(path_local_move_log, col_types = cols(.default = col_character()), show_col_types = FALSE)
} else {
  tibble(from_path = character(), to_path = character(), filename = character(), action = character())
}

# load_sd_map reads the SD barcode to CCH2 occid map, falling back to the local image move log.
# load_cch2_excel reads the CCH2 workbook and keeps the ID and locality columns.
# Here both tables supply occids used to fill cch2_occid on GBIF rows that do not already have one.
sd_map <- load_sd_map()
cch2_excel <- load_cch2_excel()

# True CCH2 occid: URL occid= first, then Excel catalog/occurrenceID, then SD map.
# Do not copy catalogNumber from CCH2_2025_full_ID_list.txt into cch2_occid.
# is_blank drops Excel rows whose join key is missing so blank catalog numbers and occurrenceIDs are not matched.
excel_by_cat <- cch2_excel %>%
  filter(!is_blank(catalogNumber)) %>%
  distinct(catalogNumber, .keep_all = TRUE) %>%
  select(catalogNumber, occid_from_excel_cat = cch2_occid)
excel_by_oid <- cch2_excel %>%
  filter(!is_blank(occurrenceID)) %>%
  add_count(occurrenceID) %>%
  filter(n == 1) %>%
  select(occurrenceID, occid_from_excel_oid = cch2_occid)

# Fill cch2_occid on filtered rows that have no references URL occid.
# Catalog number joins the Excel catalog, occurrenceID joins the Excel
# occurrenceID, and an SD barcode joins the SD map. coalesce keeps the first hit.
# The temporary join columns are dropped once cch2_occid is set.
occ_unified <- occ_unified %>%
  left_join(excel_by_cat, by = "catalogNumber") %>%
  left_join(excel_by_oid, by = "occurrenceID") %>%
  left_join(
    sd_map %>%
      select(sd_barcode, cch2_occid_from_sd = cch2_occid) %>%
      distinct(sd_barcode, .keep_all = TRUE),
    by = c("catalogNumber" = "sd_barcode")
  ) %>%
  mutate(
    cch2_occid = coalesce(
      cch2_occid,
      occid_from_excel_cat,
      occid_from_excel_oid,
      cch2_occid_from_sd
    )
  ) %>%
  select(-occid_from_excel_cat, -occid_from_excel_oid, -cch2_occid_from_sd)

# --- researched GBIF coordinates (match? first token = yes) ---
# Read the researched-coordinate sheet and require a column whose name starts with "match".
coords_raw <- read_csv(
  path_researched_coords,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
match_col <- names(coords_raw)[grepl("^match", names(coords_raw), ignore.case = TRUE)]
if (length(match_col) == 0) {
  stop("No match? column in researched coords file")
}

# read_gbif_tsv loads the original GBIF occurrence so researched coordinates can be tied back to catalog, occurrence, and institution IDs.
old_occ <- read_gbif_tsv(path_old_occ) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber),
    occurrenceID = as.character(occurrenceID),
    institutionCode = as.character(institutionCode)
  ) %>%
  select(gbifID, catalogNumber, occurrenceID, institutionCode) %>%
  distinct(gbifID, .keep_all = TRUE)

# match_yes is true when the first word of a comma-separated string is "yes".
# Here it keeps researched coordinate rows marked as a match.
# norm_chr turns blanks, "NA", and "0" into NA.
# Here it cleans coordinates and builds locality_key from locality and verbatimLocality.
# is_blank then drops rows that still have neither a latitude nor a longitude.
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

# norm_chr cleans coordinate columns in the previous added-coords file before they fill blank GBIF coordinates.
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

# norm_chr cleans coordinate columns on completed CCH2 specimens before those coordinates overwrite GBIF values.
cch2_done <- read_csv(
  path_cch2_completed,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(
    cch2_occid = as.character(id),
    across(any_of(coord_cols), norm_chr)
  )

# apply_coords joins donor coordinates onto the occurrence table.
# is_blank skips donor rows with a missing join key and treats a coordinate cell as empty when it is NA, blank, "NA", or "0".
# replace = TRUE overwrites GBIF/GeoLocate coordinates; replace = FALSE only fills blanks.
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

# norm_chr cleans GBIF coordinates and builds the same locality_key used to match researched rows.
occ_unified <- occ_unified %>%
  mutate(
    across(all_of(coord_cols), norm_chr),
    locality_key = paste(norm_chr(locality), norm_chr(verbatimLocality), sep = "||")
  )

# is_blank counts unified rows that still lack a latitude before the coordinate overlay.
n_coords_before <- sum(!is_blank(occ_unified$decimalLatitude))

# Overlay coordinates in this order:
# previous added-coords by gbifID, then by catalogNumber (fill blanks only);
# researched yes-rows by gbifID, occurrenceID, and institutionCode + catalogNumber (overwrite);
# researched locality text (fill blanks only);
# completed CCH2 specimens by cch2_occid (overwrite).
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

# is_blank counts unified rows that have a latitude after the coordinate overlay.
n_coords_after <- sum(!is_blank(occ_unified$decimalLatitude))

# Small ID table for rows kept in the analysis occurrence file.
crosswalk <- occ_unified %>%
  select(
    gbifID, catalogNumber, institutionCode, cch2_occid,
    locality, eventDate, scientificName
  ) %>%
  mutate(in_unified_occurrence = TRUE)

# Unmatched review: CCH2 full download + local SD/CDA/YOSE images vs the
# unfiltered 09.10.2026 GBIF occurrence.txt (not the filtered analysis table).
# norm_chr drops blank catalog numbers, occids, and occurrenceIDs.
# split_id_tokens splits otherCatalogNumbers on ";", ",", or "|" into unique non-blank tokens.
# Together they list every ID present in that unfiltered download.
gbif_catalog <- unique(c(
  na.omit(norm_chr(occ$catalogNumber)),
  split_id_tokens(occ$otherCatalogNumbers)
))
gbif_occid <- unique(na.omit(norm_chr(occ$cch2_occid)))
gbif_occurrence_id <- unique(na.omit(norm_chr(occ$occurrenceID)))
gbif_id_any <- unique(c(gbif_catalog, gbif_occid, gbif_occurrence_id))

# Label CCH2 Excel rows so the review sheet can tell them from local image IDs.
cch2_full <- cch2_excel %>%
  mutate(source = "cch2_full_download")

# list_jpgs lists JPEG files in a directory, skipping macOS "._" sidecar files.
# stem_filename reduces each path to its filename stem, dropping the extension and a leading "SML_".
# Here those stems are the local CDA, YOSE, and SD barcodes checked against GBIF.
cda_yose_ids <- unique(c(
  stem_filename(list_jpgs(dir_cda_yose_images)),
  stem_filename(
    local_move_log$filename[grepl("^(CDA-|YOSE)", ifelse(is.na(local_move_log$filename), "", local_move_log$filename))]
  )
))
sd_files <- unique(c(
  stem_filename(list_jpgs(dir_sd_images)),
  stem_filename(
    local_move_log$filename[grepl("^SD000", ifelse(is.na(local_move_log$filename), "", local_move_log$filename))]
  )
))
# Drop blank stems so they are not treated as IDs.
sd_files <- sd_files[nzchar(sd_files) & !is.na(sd_files)]
cda_yose_ids <- cda_yose_ids[nzchar(cda_yose_ids) & !is.na(cda_yose_ids)]

# SD review rows: barcode as catalogNumber, institution SD, mapped occid when the SD map has it.
sd_from_files <- tibble(
  source = "ucd_imaged_sd",
  catalogNumber = sd_files,
  institutionCode = "SD",
  occurrenceID = NA_character_,
  otherCatalogNumbers = NA_character_,
  locality = NA_character_
) %>%
  left_join(
    sd_map %>%
      select(catalogNumber = sd_barcode, cch2_occid) %>%
      distinct(catalogNumber, .keep_all = TRUE),
    by = "catalogNumber"
  )

# CDA/YOSE review rows: the filename stem is the catalog number. These files have no CCH2 occid.
cda_yose_from_files <- tibble(
  source = "locally_imaged_cda_yose",
  cch2_occid = NA_character_,
  catalogNumber = cda_yose_ids,
  institutionCode = ifelse(startsWith(cda_yose_ids, "CDA"), "CDA", "YOSE"),
  occurrenceID = NA_character_,
  otherCatalogNumbers = NA_character_,
  locality = NA_character_
)

# All CCH2, SD, and CDA/YOSE IDs to test against the full GBIF download.
candidates <- bind_rows(cch2_full, sd_from_files, cda_yose_from_files)

# norm_chr and split_id_tokens collect this row's occid, catalog number, occurrenceID, and other catalog tokens.
# A row counts as present when any of those tokens is in the full GBIF ID set.
present_in_full_gbif <- function(occid, catalog, occurrence_id, other) {
  vapply(seq_along(occid), function(i) {
    toks <- unique(na.omit(c(
      norm_chr(occid[[i]]),
      norm_chr(catalog[[i]]),
      norm_chr(occurrence_id[[i]]),
      split_id_tokens(other[[i]])
    )))
    length(toks) > 0 && any(toks %in% gbif_id_any)
  }, logical(1))
}

# is_blank keeps a missing ID from counting as a match against the full GBIF ID set.
unmatched <- candidates %>%
  mutate(
    matched_by_occid = !is_blank(cch2_occid) &
      (cch2_occid %in% gbif_occid | cch2_occid %in% gbif_catalog),
    matched_by_catalog = !is_blank(catalogNumber) & catalogNumber %in% gbif_catalog,
    matched_by_occurrenceID = !is_blank(occurrenceID) & occurrenceID %in% gbif_occurrence_id,
    matched_any = present_in_full_gbif(
      cch2_occid, catalogNumber, occurrenceID, otherCatalogNumbers
    )
  ) %>%
  filter(!matched_any) %>%
  mutate(
    match_fail_reason = case_when(
      source == "locally_imaged_cda_yose" ~
        "catalogNumber not found in full 09.10.2026 GBIF occurrence.txt",
      source == "ucd_imaged_sd" ~
        "SD barcode / mapped CCH2 occid not found in full 09.10.2026 GBIF occurrence.txt",
      TRUE ~
        "CCH2 occid, catalogNumber, and occurrenceID all absent from full 09.10.2026 GBIF occurrence.txt"
    )
  ) %>%
  select(-matched_any) %>%
  distinct() %>%
  arrange(source, cch2_occid, catalogNumber)

# Write the review sheet, the ID crosswalk, and the unified table.
# occurrence_w_added_coords.csv is that same table after the coordinate overlay.
occ_out <- occ_unified %>% select(-locality_key)
write_csv(unmatched, path_unmatched_review)
write_csv(crosswalk, path_crosswalk)
write_csv(occ_out, path_occ_unified)
write_csv(occ_out, path_occ_added_coords)

# Summarize row counts, coordinates, occids, and where the unmatched review sheet went.
message(
  "Unified occurrence rows: ", nrow(occ_unified),
  ". Coords before overlay: ", n_coords_before,
  "; after overlay: ", n_coords_after, "."
)
# is_blank counts unified rows that received a CCH2 occid.
message(
  "CCH2 occids on unified GBIF rows: ",
  sum(!is_blank(occ_unified$cch2_occid)), "."
)
message(
  "Unmatched CCH2/SD/CDA/YOSE rows for review: ", nrow(unmatched),
  " -> ", path_unmatched_review
)
message(
  "CCH2 full-download rows not in full GBIF occurrence: ",
  sum(unmatched$source == "cch2_full_download"), " of ", nrow(cch2_full), "."
)
print(unmatched %>% count(source), n = Inf)
message("Next: Rscript GBIF_2026_update/build_image_id_audit.R")
