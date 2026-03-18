# GBIF occurrence further filtering -------------------------------
# Set working directory to project root (Raphanus_Phenology) before sourcing.

library(dplyr)
library(readr)

# Paths (relative to project root)
path_occurrences <- "GBIF_occurrence_fixed.csv"
path_filtered_out <- "Output_Files/GBIF_occurrence_filtered.csv"
path_removed_county_only <- "Output_Files/GBIF_occurrence_removed_county_only.csv"
path_removed_mediaType_not_StillImage <- "Output_Files/GBIF_occurrence_removed_mediaType_not_StillImage.csv"
path_removed_not_preserved <- "Output_Files/GBIF_occurrence_removed_not_preserved_specimen.csv"
path_removals_breakdown <- "Output_Files/GBIF_filter_removals_breakdown.csv"

# Load occurrence data (read as character to avoid parsing issues with messy GBIF fields)
occ <- read_csv(path_occurrences, col_types = cols(.default = col_character()), show_col_types = FALSE)

# Define US states to exclude due to low specimen counts or irrelevance
states_exclude <- c(
  "Alaska (State)", "Arizona", "Arkansas", "Colorado",
  "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
  "Michigan", "Minnesota", "Missouri", "Montana", "Nebraska", "Nevada",
  "New Mexico", "North Dakota", "Ohio", "Oklahoma", "South Dakota",
  "Tennessee", "Utah", "West Virginia", "Wisconsin", "Wyoming", "0"
)

# Create output directory if needed
dir.create("Output_Files", showWarnings = FALSE)

# Apply filters sequentially to build removal breakdown
n0 <- nrow(occ)
after_state <- occ %>% filter(!stateProvince %in% states_exclude)
n_state <- n0 - nrow(after_state)

after_country <- after_state %>% filter(countryCode == "US")
n_country <- nrow(after_state) - nrow(after_country)

after_basis <- after_country %>% filter(basisOfRecord == "PRESERVED_SPECIMEN")
n_basis <- nrow(after_country) - nrow(after_basis)

after_locality <- after_basis %>% filter(
  !( (is.na(locality) | trimws(locality) == "") &
     (is.na(verbatimLocality) | trimws(verbatimLocality) == "") )
)
n_locality <- nrow(after_basis) - nrow(after_locality)

after_media <- after_locality %>% filter(mediaType == "StillImage")
n_media <- nrow(after_locality) - nrow(after_media)
# Rows actually removed at media step: NA, blank, "0", or any other non-StillImage
mediaType_not_StillImage <- after_locality %>% filter(
  is.na(mediaType) |
  trimws(mediaType) == "" |
  mediaType == "0" |
  mediaType != "StillImage"
)

occ_filtered <- after_media

# Breakdown table of removals (sequential)
removals_breakdown <- tibble(
  reason = c(
    "Excluded state (stateProvince in states_exclude)",
    "Country not US",
    "basisOfRecord not PRESERVED_SPECIMEN",
    "Empty locality (county-only)",
    "mediaType not StillImage"
  ),
  n_removed = c(n_state, n_country, n_basis, n_locality, n_media)
) %>%
  mutate(
    n_remaining_after = n0 - cumsum(n_removed),
    .after = n_removed
  )

# Optional: print or view the table
print(removals_breakdown)

# Specimens with only county information (for potential county-level climate assignment)
county_only <- occ %>%
  filter(
    (is.na(locality) | trimws(locality) == "") &
    (is.na(verbatimLocality) | trimws(verbatimLocality) == "")
  )

# Specimens removed due to basisOfRecord not being PRESERVED_SPECIMEN
not_preserved_specimen <- occ %>% filter(basisOfRecord != "PRESERVED_SPECIMEN")

# Write breakdown table and removed specimens / filtered dataset
write_csv(removals_breakdown, path_removals_breakdown)
write_csv(not_preserved_specimen, path_removed_not_preserved)
write_csv(mediaType_not_StillImage, path_removed_mediaType_not_StillImage)
write_csv(county_only, path_removed_county_only)
write_csv(occ_filtered, path_filtered_out)
