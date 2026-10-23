# List unified specimens that still have no scoring jpg but do have an image URL.
# Fresh 09.10.2026 URLs are preferred. Old-only URLs are used when the new
# multimedia file has no row for that gbifID.
# Run from project root:
#   Rscript GBIF_2026_update/build_image_recovery_list.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

if (!file.exists(path_occ_unified)) {
  stop("Run build_unified_occurrence.R first.")
}

# One image URL per gbifID. Blank URLs are dropped after the first real http URL is kept.
one_url <- function(media) {
  media %>%
    mutate(gbifID = as.character(gbifID)) %>%
    group_by(gbifID) %>%
    summarise(
      image_url = {
        urls <- image_url[!is_blank(image_url)]
        if (length(urls) == 0) NA_character_ else urls[[1]]
      },
      .groups = "drop"
    )
}

occ <- read_csv(path_occ_unified, col_types = cols(.default = col_character()), show_col_types = FALSE)
fresh <- one_url(read_gbif_multimedia(path_fresh_media))
old <- one_url(read_gbif_multimedia(path_old_media))

# Scoring stems already on disk, including resized SML_ files.
on_disk <- stem_filename(list_jpgs(dir_scoring))

# The five California Academy 403s stay in failed_downloads.csv.
already_failed <- if (file.exists(path_failed_downloads)) {
  read_csv(path_failed_downloads, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
    pull(gbifID)
} else {
  character(0)
}

# Fresh URL, or an old URL when the new multimedia file has no row at all.
to_recover <- occ %>%
  filter(!gbifID %in% on_disk, !gbifID %in% already_failed) %>%
  left_join(fresh %>% rename(fresh_url = image_url), by = "gbifID") %>%
  left_join(old %>% rename(old_url = image_url), by = "gbifID") %>%
  mutate(
    in_fresh_media = gbifID %in% fresh$gbifID,
    url_source = case_when(
      !is_blank(fresh_url) ~ "fresh",
      !in_fresh_media & !is_blank(old_url) ~ "old_only",
      TRUE ~ NA_character_
    ),
    image_url = if_else(url_source == "fresh", fresh_url, old_url),
    dest_path = file.path(dir_scoring, paste0(gbifID, ".jpg"))
  ) %>%
  filter(!is.na(url_source)) %>%
  select(gbifID, catalogNumber, institutionCode, image_url, url_source, dest_path)

path_recover <- file.path(this_dir, "images_to_recover.csv")
write_csv(to_recover, path_recover)

message(
  "Recovery list: ", nrow(to_recover),
  " (fresh=", sum(to_recover$url_source == "fresh"),
  ", old_only=", sum(to_recover$url_source == "old_only"),
  ") -> ", path_recover
)
