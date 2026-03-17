# GBIF occurrence further filtering -------------------------------
# Set working directory to project root (Raphanus_Phenology) before sourcing.

library(dplyr)
library(readr)

# Paths (relative to project root)
path_occurrences <- "GBIF_occurrence_fixed.csv"
path_filtered_out <- "Output_Files/GBIF_occurrence_filtered.csv"
path_removed_county_only <- "Output_Files/GBIF_occurrence_removed_county_only.csv"
path_removed_mediaType_not_StillImage <- "Output_Files/GBIF_occurrence_removed_mediaType_not_StillImage.csv"

# Load occurrence data
occ <- read_csv(path_occurrences, show_col_types = FALSE)

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

# Filter for main analysis: only US, selected states, preserved specimens, nonempty locality, and images
occ_filtered <- occ %>%
  filter(
    !stateProvince %in% states_exclude,
    countryCode == "US",
    basisOfRecord == "PRESERVED_SPECIMEN",
    !( (is.na(locality) | trimws(locality) == "") &
       (is.na(verbatimLocality) | trimws(verbatimLocality) == "") ),
    mediatype == "StillImage"
  )

# Specimens with only county information (for potential county-level climate assignment)
county_only <- occ %>%
  filter(
    (is.na(locality) | trimws(locality) == "") &
    (is.na(verbatimLocality) | trimws(verbatimLocality) == "")
  )

# Specimens removed due to mediatype not being StillImage
mediaType_not_StillImage <- occ %>%
  filter(mediatype != "StillImage")

# Write out removed specimens and filtered dataset
write_csv(mediaType_not_StillImage, path_removed_mediaType_not_StillImage)
message("Written: ", path_removed_mediaType_not_StillImage)

write_csv(county_only, path_removed_county_only)
message("Written: ", path_removed_county_only)

write_csv(occ_filtered, path_filtered_out)
message("Written: ", path_filtered_out)
