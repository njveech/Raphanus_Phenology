#8.12-8.18.2025 Combining Class and CCH2 Data----------------------------------

#Set Working Directory to EVE_2025 folder on computer
#setwd("/Users/natalieveech/Desktop/EVE_2025")

#Install Tidyverse package into R for access to stringr, dplyr
#install.packages("tidyverse")

#Load tidyverse package into R from Library
library(tidyverse)

#Simplify CCH2 data down to the columns of interest
important_specimen_data <- read.csv("FullSpecimenCCH2Data.csv") %>% select(id, 
institutionCode, specificEpithet, recordedBy, eventDate, year:day, 
verbatimEventDate, county, locality, 
decimalLatitude:coordinateUncertaintyInMeters)

#Change "id" column from integer class to character class in CCH2 data frame
important_specimen_data$id <- as.character(important_specimen_data$id)

#Combine Annotated and Unannotated phenology count data into one big data frame
ann <- read.csv("annotated_inference_counts.csv")
unann <- read.csv("inference_counts_RETRY.csv")
entire_class_dataset <- bind_rows(ann, unann)

#Change name of "image" column in Class data frame to be "id"
entire_class_dataset <- entire_class_dataset %>% rename(id = image)

#Remove the "SML_" prefix so that Class and CCH2 data frames can be merged
entire_class_dataset$id <- str_replace(entire_class_dataset$id, "^SML_", "")

#Remove any observation (e.g. duplicates) that is in Class but not CCH2 data
rm <- setdiff(entire_class_dataset$id, important_specimen_data$id)
entire_class_dataset <- entire_class_dataset %>% filter(!entire_class_dataset$id 
                                                        %in% rm)
#Merge CCH2 Data and Entire Class Data into one data frame, matched based on id
totalinfo <- full_join(entire_class_dataset, important_specimen_data, by = "id")

#Export Full Combined Data Frame into a CSV for further use
write.csv(totalinfo, "completed_specimen_data.csv", row.names = FALSE)
