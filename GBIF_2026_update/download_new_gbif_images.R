# Diff unified occurrence against previous GBIF pulls and already-assembled
# scoring images. Write a download list for specimens new to the 09.10.2026
# download. Does not retry previously failed old IDs.
# Run from project root after build_image_id_audit.R:
#   Rscript GBIF_2026_update/download_new_gbif_images.R
# Then:
#   python3 GBIF_2026_update/gbif_image_pull_from_multimedia.py

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

if (!file.exists(path_occ_unified) || !file.exists(path_audit)) {
  stop("Run build_unified_occurrence.R and build_image_id_audit.R first.")
}

occ <- read_csv(path_occ_unified, col_types = cols(.default = col_character()), show_col_types = FALSE)
audit <- read_csv(path_audit, col_types = cols(.default = col_character()), show_col_types = FALSE)

old_occ <- read_gbif_tsv(path_old_occ) %>% mutate(gbifID = as.character(gbifID))
old_media <- read_gbif_multimedia(path_old_media)

media <- read_gbif_multimedia(path_fresh_media) %>%
  filter(!is_blank(image_url)) %>%
  distinct(gbifID, .keep_all = TRUE)

already_ok <- audit %>%
  filter(id_check_status == "ok", !is_blank(gbifID)) %>%
  pull(gbifID) %>%
  unique()

prev_attempted <- unique(c(old_occ$gbifID, old_media$gbifID))

on_disk_gbif <- unique(c(
  stem_filename(list_jpgs(dir_gbif_prev_images)),
  stem_filename(list_jpgs(dir_gbif_too_large)),
  stem_filename(list_jpgs(dir_scoring))
))

new_ids <- occ %>%
  filter(
    !gbifID %in% prev_attempted,
    !gbifID %in% already_ok,
    !gbifID %in% on_disk_gbif
  ) %>%
  select(gbifID, catalogNumber, institutionCode, scientificName)

to_download <- new_ids %>%
  inner_join(media, by = "gbifID") %>%
  mutate(
    dest_path = file.path(dir_scoring, paste0(gbifID, ".jpg")),
    image_source = "gbif_fresh_download"
  )

no_url <- new_ids %>%
  anti_join(media, by = "gbifID") %>%
  mutate(match_fail_reason = "new to 09.10.2026 download but no http URL in multimedia identifier/references")

write_csv(to_download, path_new_downloads)
write_csv(no_url, file.path(this_dir, "new_gbif_images_missing_url.csv"))

message(
  "New GBIF IDs in unified occurrence not in previous attempts / existing images: ",
  nrow(new_ids), "."
)
message("With a downloadable URL: ", nrow(to_download), " -> ", path_new_downloads)
message("New IDs missing a URL: ", nrow(no_url), ".")
