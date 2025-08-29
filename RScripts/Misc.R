#Histogram Practice 8.19-??.25------------------------------------------------

#Bud Clusters
hist(fulldata$Bud.Cluster, breaks = 10, freq = TRUE, col = "darkorchid3", 
     border = "white", main = "Bud Cluster Frequency in California Raphanus 
     Herbarium Specimens", ylab = "Frequency", xlab = "# of Bud Clusters")

#Flowers
hist(fulldata$Flower, breaks = 40, freq = TRUE, col = "firebrick3", 
     border = "white", main = "Flower Frequency in California Raphanus 
     Herbarium Specimens", ylab = "Frequency", xlab = "# of Flowers")

#Fruits
hist(fulldata$Fruit, breaks = 25, freq = TRUE, col = "seagreen1", 
     border = "black", main = "Fruit Frequency in California Raphanus 
     Herbarium Specimens", ylab = "Frequency", xlab = "# of Fruits")

#Flowering and Months
flowering <- fulldata %>% filter(Flower > 0)
hist(flowering$month, breaks = seq(0, 12, 1), freq = TRUE, col = "firebrick3",
     border = "white", main = "Frequency of Specimens Collected While Flowering
     for Each Month", xlab = "Month", ylab = "Frequency")

#Fruits and Months
fruiting <- fulldata %>% filter(Fruit > 0)
hist(fruiting$month, breaks = seq(0, 12, 1), freq = TRUE, col = "seagreen1",
     border = "black", main = "Frequency of Specimens Collected While Fruiting
     for Each Month", xlab = "Month", ylab = "Frequency")

#Miscellaneous------------------------------------------------------------------

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

#attempt to display CSV as nice table
install.packages("knitr")
library(knitr)
legend <- read.csv("Climate_variable_Legend.csv")
kable(legend, format = "markdown")


#Code to explicitly store PAT for Github
#install.packages("gitcreds")
library(gitcreds)
gitcreds::gitcreds_set()
usethis::use_git_config(user.name = "njveech", user.email = "njveech@ucdavis.edu)



#Create RProject from Github HTTPS Link
usethis::create_from_github("https://github.com/njveech/Raphanus_Phenology.git", destdir = "/Users/natalieveech/Desktop/EVE_2025/")

