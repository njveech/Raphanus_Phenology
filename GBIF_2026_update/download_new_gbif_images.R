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

# Both the unified table and the audit sheet are required.
if (!file.exists(path_occ_unified) || !file.exists(path_audit)) {
  stop("Run build_unified_occurrence.R and build_image_id_audit.R first.")
}

# Unified rows are the specimens that might still need an image. The audit says which ones already have one.
occ <- read_csv(path_occ_unified, col_types = cols(.default = col_character()), show_col_types = FALSE)
audit <- read_csv(path_audit, col_types = cols(.default = col_character()), show_col_types = FALSE)

# IDs from the original download count as already attempted, including ones that failed before.
old_occ <- read_gbif_tsv(path_old_occ) %>% mutate(gbifID = as.character(gbifID))
old_media <- read_gbif_multimedia(path_old_media)

# One image URL per gbifID from the fresh multimedia file.
media <- read_gbif_multimedia(path_fresh_media) %>%
  filter(!is_blank(image_url)) %>%
  distinct(gbifID, .keep_all = TRUE)

# gbifIDs that already matched a local or previous image.
already_ok <- audit %>%
  filter(id_check_status == "ok", !is_blank(gbifID)) %>%
  pull(gbifID) %>%
  unique()

# gbifIDs present in the original occurrence or multimedia files.
prev_attempted <- unique(c(old_occ$gbifID, old_media$gbifID))

# Filename stems already on disk in the previous GBIF folders or the scoring folder.
on_disk_gbif <- unique(c(
  stem_filename(list_jpgs(dir_gbif_prev_images)),
  stem_filename(list_jpgs(dir_gbif_too_large)),
  stem_filename(list_jpgs(dir_scoring))
))

# Unified rows whose gbifID is new to this download and not already imaged.
new_ids <- occ %>%
  filter(
    !gbifID %in% prev_attempted,
    !gbifID %in% already_ok,
    !gbifID %in% on_disk_gbif
  ) %>%
  select(gbifID, catalogNumber, institutionCode, scientificName)

# New IDs that have an http URL, with the scoring-folder destination.
to_download <- new_ids %>%
  inner_join(media, by = "gbifID") %>%
  mutate(
    dest_path = file.path(dir_scoring, paste0(gbifID, ".jpg")),
    image_source = "gbif_fresh_download"
  )

# New IDs with no URL, written so they can be checked by hand.
no_url <- new_ids %>%
  anti_join(media, by = "gbifID") %>%
  mutate(match_fail_reason = "new to 09.10.2026 download but no http URL in multimedia identifier/references")

# Download list for the Python pull, plus the IDs that have nothing to download.
write_csv(to_download, path_new_downloads)
write_csv(no_url, file.path(this_dir, "new_gbif_images_missing_url.csv"))

# Report how many new IDs have a URL and how many do not.
message(
  "New GBIF IDs in unified occurrence not in previous attempts / existing images: ",
  nrow(new_ids), "."
)
message("With a downloadable URL: ", nrow(to_download), " -> ", path_new_downloads)
message("New IDs missing a URL: ", nrow(no_url), ".")
