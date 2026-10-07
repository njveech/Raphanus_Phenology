# Append freshly downloaded scoring images to the ID audit sheet.
# Run after gbif_image_pull_from_multimedia.py:
#   Rscript GBIF_2026_update/update_audit_from_scoring_dir.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

# Need the unified table and the existing audit sheet.
if (!file.exists(path_occ_unified) || !file.exists(path_audit)) {
  stop("Run occurrence + audit builders first.")
}

# Unified rows supply metadata for new downloads. The audit is what those downloads get appended to.
occ <- read_csv(path_occ_unified, col_types = cols(.default = col_character()), show_col_types = FALSE)
audit <- read_csv(path_audit, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
  mutate(
    source_priority = as.integer(source_priority),
    selected_for_scoring = as.logical(selected_for_scoring)
  )

# Filename stems of jpgs now in the scoring folder.
scored <- list_jpgs(dir_scoring)
stems <- stem_filename(scored)
# IDs already recorded on the audit sheet, from gbifID or either filename column.
already <- unique(na.omit(c(
  as.character(audit$gbifID),
  stem_filename(audit$scoring_filename),
  stem_filename(audit$original_filename)
)))

# Scoring-folder gbifIDs that are in the unified table and not yet on the audit.
new_stems <- setdiff(stems, already)
new_stems <- new_stems[new_stems %in% occ$gbifID]

if (length(new_stems) == 0) {
  message("No new scoring-dir gbifIDs to add to the audit.")
} else {
  # Append one ok audit row per new download. The filename is the gbifID.
  occ_small <- occ %>%
    filter(gbifID %in% new_stems) %>%
    select(any_of(c(
      "gbifID", "catalogNumber", "institutionCode", "cch2_occid",
      "occurrenceID", "locality", "eventDate", "scientificName",
      "otherCatalogNumbers"
    ))) %>%
    mutate(
      image_source = "gbif_fresh_download",
      source_dir = dir_scoring,
      original_filename = paste0(gbifID, ".jpg"),
      original_stem = gbifID,
      scoring_filename = paste0(gbifID, ".jpg"),
      id_check_status = "ok",
      id_check_notes = "unique gbifID from 09.10.2026 multimedia download",
      source_priority = match("gbif_fresh_download", image_source_priority),
      selected_for_scoring = TRUE
    )
  audit <- bind_rows(audit, occ_small)
  write_csv(audit, path_audit)
  # Refresh the review sheet so it still lists only non-ok rows.
  review <- audit %>% filter(id_check_status != "ok")
  write_csv(review, path_audit_review)
  message("Added ", nrow(occ_small), " gbif_fresh_download rows to ", path_audit)
}

# Print the updated audit counts.
print(
  audit %>% count(image_source, id_check_status),
  n = Inf
)
message("Selected for scoring: ", sum(as.logical(audit$selected_for_scoring)))
