# Append freshly downloaded scoring images to the ID audit sheet.
# Run after gbif_image_pull_from_multimedia.py:
#   Rscript GBIF_2026_update/update_audit_from_scoring_dir.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

if (!file.exists(path_occ_unified) || !file.exists(path_audit)) {
  stop("Run occurrence + audit builders first.")
}

occ <- read_csv(path_occ_unified, col_types = cols(.default = col_character()), show_col_types = FALSE)
audit <- read_csv(path_audit, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
  mutate(
    source_priority = as.integer(source_priority),
    selected_for_scoring = as.logical(selected_for_scoring)
  )

scored <- list_jpgs(dir_scoring)
stems <- stem_filename(scored)
  already <- unique(na.omit(c(
    as.character(audit$gbifID),
    stem_filename(audit$scoring_filename),
    stem_filename(audit$original_filename)
  )))

new_stems <- setdiff(stems, already)
new_stems <- new_stems[new_stems %in% occ$gbifID]

if (length(new_stems) == 0) {
  message("No new scoring-dir gbifIDs to add to the audit.")
} else {
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
  review <- audit %>% filter(id_check_status != "ok")
  write_csv(review, path_audit_review)
  message("Added ", nrow(occ_small), " gbif_fresh_download rows to ", path_audit)
}

print(
  audit %>% count(image_source, id_check_status),
  n = Inf
)
message("Selected for scoring: ", sum(as.logical(audit$selected_for_scoring)))
