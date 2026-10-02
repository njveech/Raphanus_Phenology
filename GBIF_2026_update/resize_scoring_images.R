# Resize scoring jpgs over 20 MB. Writes SML_{gbifID}.jpg and removes the
# oversized original. Run from project root after images are in dir_scoring:
#   Rscript GBIF_2026_update/resize_scoring_images.R

source("GBIF_2026_update/paths.R")

limit_bytes <- 20 * 1024 * 1024
files <- list_jpgs(dir_scoring)
files <- files[!startsWith(basename(files), "SML_")]

resized <- 0L
for (path in files) {
  info <- file.info(path)
  if (is.na(info$size) || info$size <= limit_bytes) {
    next
  }
  stem <- stem_filename(path)
  dest <- file.path(dir_scoring, paste0("SML_", stem, ".jpg"))
  status <- system2(
    "sips",
    c("--resampleWidth", "5000", path, "--out", dest),
    stdout = FALSE,
    stderr = FALSE
  )
  if (!identical(status, 0L) || !file.exists(dest)) {
    message("sips failed: ", path)
    next
  }
  unlink(path)
  resized <- resized + 1L
  message("Resized ", basename(path), " -> ", basename(dest))
}

message("Resized ", resized, " file(s) over 20 MB in ", dir_scoring)
