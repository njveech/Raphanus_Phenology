# Build filtered occurrence table from the 09.10.2026 GBIF download
# and overlay researched coordinates. Writes occurrence_unified.csv.
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

# stateProvince is not filtered here. states_exclude in paths.R is for a later
# stage, after Roboflow phenology scores exist for these specimens.
# This download is already all countryCode "US" and basisOfRecord
# "PRESERVED_SPECIMEN". CCH2 catalog overlap is kept, and there is no mediaType filter.
# is_blank is true when a value is NA, blank, "NA", or "0".
# A row is kept when county is present even if both locality fields are blank.
n0 <- nrow(occ)
occ_unified <- occ %>%
  filter(!(is_blank(locality) & is_blank(verbatimLocality) & is_blank(county)))
n_geo <- n0 - nrow(occ_unified)

# Record how many rows the locality filter removed and how many remained.
removals_breakdown <- tibble(
  reason = "Empty locality and empty county",
  n_removed = n_geo,
  n_remaining_after = nrow(occ_unified)
)

write_csv(removals_breakdown, path_filter_breakdown)
print(removals_breakdown)

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
  select(
    catalogNumber,
    institutionCode_excel_cat = institutionCode,
    occid_from_excel_cat = cch2_occid
  )
excel_by_oid <- cch2_excel %>%
  filter(!is_blank(occurrenceID)) %>%
  add_count(occurrenceID) %>%
  filter(n == 1) %>%
  select(occurrenceID, occid_from_excel_oid = cch2_occid)

# Fill cch2_occid on filtered rows that have no references URL occid.
# Catalog number joins the Excel catalog, occurrenceID joins the Excel
# occurrenceID, and an SD barcode joins the SD map. coalesce keeps the first hit.
# A catalog match is dropped when both institution codes are present and differ
# (KU catalog 87141 is not MBNHM catalog 87141). A blank GBIF institution still matches.
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
    occid_from_excel_cat = if_else(
      !is_blank(institutionCode) &
        !is_blank(institutionCode_excel_cat) &
        institutionCode != institutionCode_excel_cat,
      NA_character_,
      occid_from_excel_cat
    ),
    cch2_occid = coalesce(
      cch2_occid,
      occid_from_excel_cat,
      occid_from_excel_oid,
      cch2_occid_from_sd
    )
  ) %>%
  select(
    -occid_from_excel_cat, -institutionCode_excel_cat,
    -occid_from_excel_oid, -cch2_occid_from_sd
  )

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
  select(-ends_with("_old"))

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
apply_coords <- function(df, donor, by_cols, replace = FALSE) {
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
# researched yes-rows by gbifID, occurrenceID, and institutionCode + catalogNumber (blanks only);
# researched locality text (fill blanks only);
# completed CCH2 specimens by cch2_occid (blanks only).
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
  replace = FALSE
)
occ_unified <- apply_coords(
  occ_unified,
  researched %>% select(occurrenceID, all_of(coord_cols)),
  "occurrenceID",
  replace = FALSE
)
occ_unified <- apply_coords(
  occ_unified,
  researched %>% select(institutionCode, catalogNumber, all_of(coord_cols)),
  c("institutionCode", "catalogNumber"),
  replace = FALSE
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
  replace = FALSE
)

# is_blank counts unified rows that have a latitude after the coordinate overlay.
n_coords_after <- sum(!is_blank(occ_unified$decimalLatitude))

# A CCH2 occid must not land on a different institution's catalog.
# This is the KU 87141 / MBNHM 87141 collision.
excel_ids <- cch2_excel %>%
  transmute(
    cch2_occid,
    institutionCode_excel = institutionCode,
    catalogNumber_excel = catalogNumber
  )
id_clashes <- occ_unified %>%
  filter(!is_blank(cch2_occid)) %>%
  inner_join(excel_ids, by = "cch2_occid") %>%
  filter(
    !is_blank(institutionCode),
    !is_blank(institutionCode_excel),
    institutionCode != institutionCode_excel,
    !is_blank(catalogNumber),
    !is_blank(catalogNumber_excel),
    catalogNumber != catalogNumber_excel
  ) %>%
  select(
    gbifID, institutionCode, catalogNumber, cch2_occid,
    institutionCode_excel, catalogNumber_excel
  )

# An SD barcode's stored occid must match the occid= in its own references URL.
sd_occid_clash <- occ_unified %>%
  filter(grepl("^SD000", catalogNumber)) %>%
  mutate(occid_from_references = extract_cch2_occid_vec(references)) %>%
  filter(
    !is_blank(cch2_occid),
    !is_blank(occid_from_references),
    cch2_occid != occid_from_references
  ) %>%
  select(gbifID, catalogNumber, cch2_occid, occid_from_references, locality)

message("Known collision rows:")
print(
  occ_unified %>%
    filter(gbifID %in% c("177016185", "2562127169") | catalogNumber == "SD00062562") %>%
    select(
      gbifID, institutionCode, catalogNumber, cch2_occid,
      decimalLatitude, decimalLongitude, locality
    ),
  n = Inf
)

if (nrow(id_clashes) > 0 || nrow(sd_occid_clash) > 0) {
  if (nrow(id_clashes) > 0) {
    message("CCH2 occid attached to a different institution's catalog:")
    print(id_clashes, n = Inf)
  }
  if (nrow(sd_occid_clash) > 0) {
    message("SD barcode occid disagrees with references URL:")
    print(sd_occid_clash, n = Inf)
  }
  stop("ID alignment check failed. occurrence_unified.csv was not written.")
}

occ_out <- occ_unified %>% select(-locality_key)
write_csv(occ_out, path_occ_unified)

message(
  "Unified occurrence rows: ", nrow(occ_unified),
  ". Coords before overlay: ", n_coords_before,
  "; after overlay: ", n_coords_after, "."
)
message(
  "CCH2 occids on unified GBIF rows: ",
  sum(!is_blank(occ_unified$cch2_occid)), "."
)
message("Wrote ", path_occ_unified)
message("Next: Rscript GBIF_2026_update/build_image_id_audit.R")
