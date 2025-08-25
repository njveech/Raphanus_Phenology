#Histogram Practice 8.19-??.25------------------------------------------------

#Read in Complete Data CSV
fulldata<- read.csv("completed_specimen_data.csv")


#Code to fix specimen with no reprod structure counts manually:
fulldata <- fulldata %>%
     mutate(
           Bud.Cluster = if_else(id == 1368028, 3, Bud.Cluster),
        Flower = if_else(id == 1368028, 2, Flower),
         Fruit = if_else(id == 1368028, 2, Fruit))

#Export this adjusted change back into CSV
write.csv(fulldata, "completed_specimen_data.csv", row.names = FALSE)

#Code to explicitly store PAT for Github
#install.packages("gitcreds")
library(gitcreds)
gitcreds::gitcreds_set()
usethis::use_git_config(user.name = "njveech", user.email = "njveech@ucdavis.edu)



#Create RProject from Github HTTPS Link
usethis::create_from_github("https://github.com/njveech/Raphanus_Phenology.git", destdir = "/Users/natalieveech/Desktop/EVE_2025/")

