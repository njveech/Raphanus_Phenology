# Inventory local/CCH2/previous-GBIF images and write an ID audit sheet.
# Fail closed: id_check_status is ok only when the file maps to exactly one
# filtered 09.10.2026 GBIF row.
# Run from project root after build_unified_occurrence.R:
#   Rscript GBIF_2026_update/build_image_id_audit.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

# Stop until the unified occurrence table exists.
if (!file.exists(path_occ_unified)) {
  stop("Run GBIF_2026_update/build_unified_occurrence.R first.")
}

# Unified occurrence is the table each image must match.
occ <- read_csv(path_occ_unified, col_types = cols(.default = col_character()), show_col_types = FALSE)

# The original GBIF download supplies catalog and occurrence IDs when a previous gbifID was republished.
old_occ <- read_gbif_tsv(path_old_occ) %>%
  mutate(
    gbifID = as.character(gbifID),
    catalogNumber = as.character(catalogNumber),
    occurrenceID = as.character(occurrenceID),
    institutionCode = as.character(institutionCode)
  )

# Excel links a CCH2 occid to catalogNumber when the GBIF row has no occid= URL.
cch2_excel <- load_cch2_excel()

# Fresh multimedia is only counted here. Image URLs are not used to match filenames.
media <- read_gbif_multimedia(path_fresh_media)

# Columns copied onto an audit row when a filename matches one occurrence.
occ_lookup_cols <- c(
  "gbifID", "catalogNumber", "institutionCode", "cch2_occid",
  "occurrenceID", "locality", "county", "eventDate", "scientificName",
  "otherCatalogNumbers"
)

occ_small <- occ %>% select(any_of(occ_lookup_cols))

# Accept a match only when exactly one unified row hits. Zero hits are unmatched; more than one needs review.
pick_unique <- function(hits, label) {
  n <- nrow(hits)
  if (n == 1) {
    return(list(hit = hits, status = "ok", notes = paste0("unique ", label)))
  }
  if (n == 0) {
    return(list(
      hit = occ_small[NA_integer_, ],
      status = "unmatched",
      notes = paste0("no unified occurrence row for ", label)
    ))
  }
  list(
    hit = hits,
    status = "needs_review",
    notes = paste0(n, " unified occurrence rows for ", label)
  )
}

# Run a matcher on each file and attach source folder, filename, proposed scoring name, and status.
bind_hits <- function(files, source, source_dir, match_fun) {
  if (length(files) == 0) {
    return(tibble())
  }
  rows <- lapply(files, function(path) {
    original_filename <- basename(path)
    stem <- stem_filename(path)
    res <- match_fun(stem, original_filename)
    hit <- res$hit
    if (nrow(hit) == 0) {
      hit <- occ_small[NA_integer_, ]
    }
    hit %>%
      mutate(
        image_source = source,
        source_dir = source_dir,
        original_filename = original_filename,
        original_stem = stem,
        scoring_filename = ifelse(
          !is_blank(gbifID), paste0(gbifID, ".jpg"), original_filename
        ),
        id_check_status = res$status,
        id_check_notes = res$notes
      )
  })
  bind_rows(rows)
}

# CCH2 filenames are occids. Try that occid, then the stem as a catalog number,
# then the Excel catalog, institution, occurrenceID, and otherCatalogNumbers.
match_cch2 <- function(stem, filename) {
  hits <- occ_small %>% filter(cch2_occid == stem)
  label <- paste0("CCH2 occid=", stem)
  if (nrow(hits) == 0) {
    hits <- occ_small %>% filter(catalogNumber == stem)
    if (nrow(hits) > 0) {
      label <- paste0("CCH2 filename=", stem, " as catalogNumber")
    }
  }
  if (nrow(hits) == 0) {
    x <- cch2_excel %>% filter(cch2_occid == stem)
    if (nrow(x) == 1) {
      cat <- x$catalogNumber[[1]]
      inst <- x$institutionCode[[1]]
      oid <- x$occurrenceID[[1]]
      if (!is_blank(cat)) {
        hits <- occ_small %>% filter(catalogNumber == cat)
        label <- paste0("CCH2 occid=", stem, " via Excel catalogNumber=", cat)
        if (nrow(hits) > 1 && !is_blank(inst)) {
          inst_hits <- hits %>% filter(institutionCode == inst)
          if (nrow(inst_hits) == 1) {
            hits <- inst_hits
            label <- paste0(
              "CCH2 occid=", stem, " via Excel institutionCode+", "catalogNumber=", cat
            )
          }
        }
      }
      if (nrow(hits) == 0 && !is_blank(oid)) {
        hits <- occ_small %>% filter(occurrenceID == oid)
        label <- paste0("CCH2 occid=", stem, " via Excel occurrenceID")
      }
      if (nrow(hits) == 0) {
        toks <- split_id_tokens(x$otherCatalogNumbers[[1]])
        if (length(toks) > 0) {
          hits <- occ_small %>% filter(catalogNumber %in% toks)
          label <- paste0("CCH2 occid=", stem, " via Excel otherCatalogNumbers")
        }
      }
    }
  }
  pick_unique(hits, label)
}

# SD filenames must be SD000 barcodes and must match catalogNumber.
match_sd <- function(stem, filename) {
  if (!grepl("^SD000", stem)) {
    return(list(
      hit = occ_small[0, ],
      status = "unmatched",
      notes = "SD folder file is not an SD000 barcode (skip gbifID-named leftovers)"
    ))
  }
  pick_unique(occ_small %>% filter(catalogNumber == stem), paste0("SD barcode=", stem))
}

# CDA and YOSE filenames are catalog numbers.
match_cda_yose <- function(stem, filename) {
  if (!grepl("^(CDA-|YOSE)", stem)) {
    return(list(
      hit = occ_small[0, ],
      status = "needs_review",
      notes = "filename is not CDA-/YOSE catalog number"
    ))
  }
  hits <- occ_small %>% filter(catalogNumber == stem)
  pick_unique(hits, paste0("catalogNumber=", stem))
}

# Previous GBIF filenames are old gbifIDs. If that ID is absent from the new
# download, try catalogNumber, then institutionCode + catalogNumber, then
# occurrenceID, and mark the row gbifID_changed.
match_prev_gbif <- function(stem, filename) {
  hits <- occ_small %>% filter(gbifID == stem)
  if (nrow(hits) == 1) {
    return(pick_unique(hits, paste0("gbifID=", stem)))
  }
  old_hit <- old_occ %>% filter(gbifID == stem)
  if (nrow(old_hit) == 1 && !is_blank(old_hit$catalogNumber)) {
    new_hits <- occ_small %>% filter(catalogNumber == old_hit$catalogNumber)
    if (nrow(new_hits) > 1 && !is_blank(old_hit$institutionCode)) {
      inst_hits <- new_hits %>% filter(institutionCode == old_hit$institutionCode)
      if (nrow(inst_hits) == 1) {
        new_hits <- inst_hits
        res <- pick_unique(
          new_hits,
          paste0("old gbifID=", stem, " via institutionCode+catalogNumber")
        )
        res$notes <- paste0(res$notes, "; gbifID_changed; old_gbifID=", stem)
        return(res)
      }
    }
    if (nrow(new_hits) == 1) {
      res <- pick_unique(new_hits, paste0("old gbifID=", stem, " via catalogNumber"))
      res$notes <- paste0(res$notes, "; gbifID_changed")
      if (res$status == "ok") {
        res$notes <- paste0(res$notes, "; old_gbifID=", stem)
      }
      return(res)
    }
    if (nrow(new_hits) == 0 && !is_blank(old_hit$occurrenceID)) {
      new_hits <- occ_small %>% filter(occurrenceID == old_hit$occurrenceID)
      res <- pick_unique(new_hits, paste0("old gbifID=", stem, " via occurrenceID"))
      if (nrow(new_hits) == 1) {
        res$notes <- paste0(res$notes, "; gbifID_changed; old_gbifID=", stem)
      }
      return(res)
    }
    res <- pick_unique(new_hits, paste0("old gbifID=", stem, " via catalogNumber"))
    res$notes <- paste0(res$notes, "; gbifID_changed")
    return(res)
  }
  pick_unique(hits, paste0("gbifID=", stem, " (not in new download)"))
}

# Oversized raw files may be named as a CCH2 occid or as an old gbifID.
match_raw_big <- function(stem, filename) {
  as_cch2 <- match_cch2(stem, filename)
  if (as_cch2$status == "ok") {
    as_cch2$notes <- paste0(as_cch2$notes, "; matched as CCH2 occid from raw_big_images")
    return(as_cch2)
  }
  match_prev_gbif(stem, filename)
}

# CCH2 originals are required. The other image folders may be empty.
if (!dir.exists(dir_cch2_images)) {
  stop("CCH2 image folder not found (is Radishes mounted?): ", dir_cch2_images)
}

# List JPEGs in each source folder. SD keeps only SD000 barcode filenames.
cch2_files <- list_jpgs(dir_cch2_images)
sd_files <- list_jpgs(dir_sd_images)
sd_files <- sd_files[grepl("^SD000", basename(sd_files))]
cda_files <- list_jpgs(dir_cda_yose_images)
prev_files <- list_jpgs(dir_gbif_prev_images)
too_large_files <- list_jpgs(dir_gbif_too_large)
raw_big_files <- list_jpgs(dir_raw_big_images)

# One audit row per image, matched with the function for that folder.
audit <- bind_rows(
  bind_hits(cch2_files, "cch2_original", dir_cch2_images, match_cch2),
  bind_hits(sd_files, "ucd_imaged_sd", dir_sd_images, match_sd),
  bind_hits(cda_files, "locally_imaged_cda_yose", dir_cda_yose_images, match_cda_yose),
  bind_hits(prev_files, "gbif_previous_download", dir_gbif_prev_images, match_prev_gbif),
  bind_hits(too_large_files, "gbif_too_large", dir_gbif_too_large, match_prev_gbif),
  bind_hits(raw_big_files, "raw_big_images", dir_raw_big_images, match_raw_big)
)

# Fresh-download multimedia rows that are in the unified table (for later download list)
fresh_media_ids <- media %>%
  filter(!is_blank(image_url), gbifID %in% occ$gbifID) %>%
  distinct(gbifID, .keep_all = TRUE)

# Rank each photo by the preferred source order for that sheet.
audit <- audit %>%
  mutate(
    source_priority = match(image_source, image_source_priority),
    gbifID = as.character(gbifID)
  )

# Keep one scoring file per gbifID: earliest source priority, then filename.
selected_keys <- audit %>%
  filter(id_check_status == "ok", !is.na(gbifID), gbifID != "") %>%
  arrange(source_priority, original_filename) %>%
  distinct(gbifID, .keep_all = TRUE) %>%
  transmute(gbifID, original_filename, image_source, selected_for_scoring = TRUE)

# Mark the chosen file and leave the other copies of the same sheet unselected.
audit <- audit %>%
  left_join(selected_keys, by = c("gbifID", "original_filename", "image_source")) %>%
  mutate(selected_for_scoring = ifelse(is.na(selected_for_scoring), FALSE, selected_for_scoring)) %>%
  arrange(image_source, original_filename)

# Rows that are not a unique match go to the review sheet.
review <- audit %>% filter(id_check_status != "ok")

# Write the full audit and the review subset.
write_csv(audit, path_audit)
write_csv(review, path_audit_review)

# File counts per source, including fresh multimedia rows that already have a URL.
inventory <- tibble(
  image_source = c(
    "cch2_original", "ucd_imaged_sd", "locally_imaged_cda_yose",
    "gbif_previous_download", "gbif_too_large", "raw_big_images",
    "gbif_fresh_download_multimedia"
  ),
  n_files = c(
    length(cch2_files), length(sd_files), length(cda_files),
    length(prev_files), length(too_large_files), length(raw_big_files),
    nrow(fresh_media_ids)
  )
)
write_csv(inventory, file.path(this_dir, "image_inventory.csv"))

# Print the audit summary and pause before any images are copied.
message("Wrote ", nrow(audit), " audit rows to ", path_audit)
print(audit %>% count(image_source, id_check_status), n = Inf)
message("Needs review: ", nrow(review), " -> ", path_audit_review)
message("Selected for scoring (unique gbifID): ", sum(audit$selected_for_scoring))
message(
  "PAUSE here. Review ", path_audit, " (especially cch2_original / selected_for_scoring) ",
  "and ", path_audit_review, " before assembling images."
)
