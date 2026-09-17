# Shared paths for the 2026 GBIF + CCH2 redo.
# Run Rscripts from the project root: Rscript GBIF_2026_update/....R

this_dir <- "GBIF_2026_update"

path_fresh_occ <- "GBIF_fresh_download_09.10.2026/occurrence.txt"
path_fresh_media <- "GBIF_fresh_download_09.10.2026/multimedia.txt"
path_old_occ <- "original_gbif_download/occurrence.txt"
path_old_media <- "original_gbif_download/multimedia.txt"
path_cch2_catalog <- "CCH2_2025_full_ID_list.txt"
path_cch2_completed <- "Output_Files/completed_specimen_data.csv"
path_researched_coords <- "Datasheet_mis-sort_fix_files/updated_csv_only_coordinates_for_adding_back.csv"
path_old_added_coords <- "GBIF_data_combining/occurence_w_added_coords.csv"
path_sd_map <- "/Volumes/Radishes/Code/UCD_imaged_SDid_to_COREid.txt"

dir_cch2_images <- "/Volumes/Radishes/OG_CCH2_phenology_scored_specimen_images"
dir_gbif_prev_images <- "/Volumes/Radishes/GBIF_phenology_scored_specimen_images"
dir_sd_images <- "/Volumes/Radishes/locally_imaged_herbarium_sheets/SD"
dir_cda_yose_images <- "/Volumes/Radishes/locally_imaged_herbarium_sheets/CDA_YOSE"
dir_gbif_too_large <- "/Volumes/Radishes/GBIF_too_large"
dir_raw_big_images <- "/Volumes/Radishes/raw_big_images"
dir_scoring <- "/Volumes/Radishes/GBIF_2026_update_scoring_images"

# Prefer local photos, then CCH2 originals, then previous GBIF files.
image_source_priority <- c(
  "locally_imaged_cda_yose",
  "ucd_imaged_sd",
  "cch2_original",
  "gbif_previous_download",
  "gbif_too_large",
  "raw_big_images",
  "gbif_fresh_download"
)

path_occ_unified <- file.path(this_dir, "occurrence_unified.csv")
path_occ_added_coords <- file.path(this_dir, "occurrence_w_added_coords.csv")
path_crosswalk <- file.path(this_dir, "cch2_gbif_crosswalk.csv")
path_unmatched_review <- file.path(this_dir, "unmatched_cch2_sd_for_review.csv")
path_audit <- file.path(this_dir, "image_id_audit.csv")
path_audit_review <- file.path(this_dir, "image_id_audit_needs_review.csv")
path_new_downloads <- file.path(this_dir, "new_gbif_images_to_download.csv")
path_failed_downloads <- file.path(this_dir, "failed_downloads.csv")
path_counts <- file.path(this_dir, "gbif_repro_counts")
path_merged <- file.path(this_dir, "gbif_repro_counts_merged.csv")
path_filter_breakdown <- file.path(this_dir, "filter_removals_breakdown.csv")

states_exclude <- c(
  "Alaska (State)", "Arizona", "Arkansas", "Colorado",
  "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
  "Michigan", "Minnesota", "Missouri", "Montana", "Nebraska", "Nevada",
  "New Mexico", "North Dakota", "Ohio", "Oklahoma", "South Dakota",
  "Tennessee", "Utah", "West Virginia", "Wisconsin", "Wyoming", "0"
)

coord_cols <- c("decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters")

norm_chr <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x) | x %in% c("", "NA", "0")] <- NA_character_
  x
}

is_blank <- function(x) {
  x <- norm_chr(x)
  is.na(x)
}

extract_cch2_occid <- function(...) {
  text <- paste(..., sep = " ")
  m <- regmatches(text, regexpr("occid=([0-9]+)", text, perl = TRUE))
  ifelse(length(m) == 1 && nzchar(m), sub("occid=", "", m), NA_character_)
}

extract_cch2_occid_vec <- function(x) {
  vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) {
      return(NA_character_)
    }
    m <- regmatches(s, regexpr("occid=([0-9]+)", s, perl = TRUE))
    if (length(m) == 1 && nzchar(m)) sub("^occid=", "", m) else NA_character_
  }, character(1), USE.NAMES = FALSE)
}

stem_filename <- function(x) {
  x <- basename(as.character(x))
  x <- sub("\\.[^.]+$", "", x)
  sub("^SML_", "", x)
}

first_http_url <- function(...) {
  vals <- unlist(list(...), use.names = FALSE)
  vals <- trimws(as.character(vals))
  vals <- vals[!is.na(vals) & vals != "" & vals != "NA"]
  hit <- grep("^https?://", vals, value = TRUE)
  if (length(hit) == 0) NA_character_ else hit[[1]]
}

match_yes <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x)] <- ""
  first <- vapply(strsplit(x, ","), function(p) {
    if (length(p) == 0) return("")
    tok <- strsplit(trimws(p[[1]]), "\\s+")[[1]]
    if (length(tok) == 0) "" else tok[[1]]
  }, character(1))
  tolower(first) == "yes"
}

list_jpgs <- function(dir, recursive = FALSE) {
  if (!dir.exists(dir)) {
    return(character(0))
  }
  files <- list.files(
    dir,
    pattern = "\\.(jpe?g|JPE?G)$",
    full.names = TRUE,
    recursive = recursive
  )
  files[!startsWith(basename(files), "._")]
}

read_gbif_tsv <- function(path) {
  readr::read_tsv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    quote = "",
    show_col_types = FALSE,
    lazy = FALSE,
    progress = FALSE
  )
}

# multimedia.txt can have extra trailing fields (license URLs) that break vroom.
read_gbif_multimedia <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    if (length(lines) < 2) {
    return(data.frame(gbifID = character(), image_url = character(), stringsAsFactors = FALSE))
  }
  header <- strsplit(lines[[1]], "\t", fixed = TRUE)[[1]]
  id_idx <- match("identifier", header)
  ref_idx <- match("references", header)
  rows <- lapply(lines[-1], function(line) {
    if (!nzchar(line)) {
      return(NULL)
    }
    parts <- strsplit(line, "\t", fixed = TRUE)[[1]]
    gbif_id <- if (length(parts) >= 1) parts[[1]] else NA_character_
    ident <- if (!is.na(id_idx) && length(parts) >= id_idx) parts[[id_idx]] else NA_character_
    refs <- if (!is.na(ref_idx) && length(parts) >= ref_idx) parts[[ref_idx]] else NA_character_
    url <- first_http_url(ident, refs)
    if (is.na(url)) {
      url <- first_http_url(parts)
      if (!is.na(url) && grepl("creativecommons\\.org|canadensys\\.net/collection", url)) {
        img <- grep("^https?://", parts, value = TRUE)
        img <- img[!grepl("creativecommons\\.org|canadensys\\.net/collection", img)]
        url <- if (length(img)) img[[1]] else url
      }
    }
    data.frame(gbifID = as.character(gbif_id), image_url = url, stringsAsFactors = FALSE)
  })
  dplyr::bind_rows(rows)
}
