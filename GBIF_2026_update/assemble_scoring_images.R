# Copy ID-checked images into the Radishes scoring folder, renamed to gbifID.jpg.
# Only rows with id_check_status == ok and selected_for_scoring are copied.
# Run from project root after build_image_id_audit.R:
#   Rscript GBIF_2026_update/assemble_scoring_images.R

library(dplyr)
library(readr)

source("GBIF_2026_update/paths.R")

# Stop until the audit sheet exists, then make the scoring folder.
if (!file.exists(path_audit)) {
  stop("Run GBIF_2026_update/build_image_id_audit.R first.")
}

dir.create(dir_scoring, showWarnings = FALSE, recursive = TRUE)

# selected_for_scoring is stored as text in the CSV.
audit <- read_csv(path_audit, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
  mutate(selected_for_scoring = as.logical(selected_for_scoring))

# Copy only ID-checked rows that were chosen as the scoring photo.
to_copy <- audit %>%
  filter(selected_for_scoring %in% TRUE, id_check_status == "ok", !is_blank(gbifID))

if (nrow(to_copy) == 0) {
  stop("No audit rows selected for scoring.")
}

# Source path, destination gbifID.jpg path, and a place to record whether the copy worked.
copy_log <- to_copy %>%
  mutate(
    from_path = file.path(source_dir, original_filename),
    to_path = file.path(dir_scoring, scoring_filename),
    copied = FALSE,
    copy_note = NA_character_
  )

# Copy each file. A missing source is a failure. A file already at the destination
# is left in place. Any other existing destination is overwritten.
for (i in seq_len(nrow(copy_log))) {
  from <- copy_log$from_path[[i]]
  to <- copy_log$to_path[[i]]
  if (!file.exists(from)) {
    copy_log$copy_note[[i]] <- "source file missing"
    next
  }
  if (file.exists(to) && normalizePath(from) == normalizePath(to, mustWork = FALSE)) {
    copy_log$copied[[i]] <- TRUE
    copy_log$copy_note[[i]] <- "already at destination"
    next
  }
  ok <- file.copy(from, to, overwrite = TRUE)
  copy_log$copied[[i]] <- isTRUE(ok)
  copy_log$copy_note[[i]] <- ifelse(ok, "copied", "file.copy failed")
}

# Record what was copied and what failed.
write_csv(
  copy_log %>% select(
    gbifID, image_source, original_filename, scoring_filename,
    from_path, to_path, copied, copy_note
  ),
  file.path(this_dir, "scoring_image_copy_log.csv")
)

# Report how many copies succeeded, and list any that did not.
message(
  "Copied ", sum(copy_log$copied), " / ", nrow(copy_log),
  " images to ", dir_scoring
)
failed <- copy_log %>% filter(!copied)
if (nrow(failed) > 0) {
  message("Copy failures: ", nrow(failed))
  print(failed %>% select(original_filename, from_path, copy_note), n = Inf)
}
