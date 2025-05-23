# -----------------------------------------
# Title: Accurate Fund-Level Revenue Loss from TIFs by Municipality (2014–2024)
# -----------------------------------------

# Load libraries
library(dplyr)
library(stringr)
library(readr)
library(tibble)
library(here)

# Load full TIF dataset
tif_all <- read_csv(here("data", "Jefferson_TIF_Details_All_Years.csv"))

# -----------------------------------------
# Step 1: Clean + classify property type
tif_all <- tif_all %>%
  mutate(
    TaxDistrict = as.character(TaxDistrict),
    TaxYear = as.integer(TaxYear),
    PropertyClass = case_when(
      TaxRateType == "Res/Agr" ~ "ResAgr",
      TaxRateType == "Com/Ind" ~ "ComInd",
      TRUE ~ "Unknown"
    ),
    TIFPercentage = as.numeric(TIFPercentage),
    AssessedTotal = as.numeric(AssessedTotal),
    EffectiveBase = AssessedTotal * (TIFPercentage / 100)
  )

# -----------------------------------------
# Step 1b: Add Municipality based on TaxDistrict
tif_all <- tif_all %>%
  mutate(
    Municipality = case_when(
      TaxDistrict == "170" ~ "Jefferson Unincorporated",
      TaxDistrict == "027" ~ "Gahanna",
      TaxDistrict == "067" ~ "Reynoldsburg",
      TaxDistrict %in% c("171", "175") ~ "Columbus",
      TRUE ~ "Other"
    )
  )

# -----------------------------------------
# Step 2: Millage table by TaxYear × TaxDistrict × PropertyClass
millage_data <- tibble(
  TaxYear = rep(2018:2024, each = 8),
  TaxDistrict = rep(c("170", "175", "027", "067"), times = 7 * 2),
  PropertyClass = rep(c("ResAgr", "ComInd"), each = 4, times = 7),
  GeneralRate = rep(c(1.000, 1.170, 1.620, 1.000), times = 7 * 2),
  FireRate = rep(c(8.2237, 8.2237, 8.2237, 8.2237), times = 7 * 2),
  RoadRate = rep(c(2.5043, 0, 0, 0), times = 7 * 2)
)

# -----------------------------------------
# Step 3: Join millage data
tif_all <- tif_all %>%
  left_join(millage_data, by = c("TaxYear", "TaxDistrict", "PropertyClass"))

# -----------------------------------------
# Step 4: Calculate lost revenue by fund
tif_all <- tif_all %>%
  mutate(
    Lost_General = EffectiveBase * (GeneralRate / 1000),
    Lost_Fire = EffectiveBase * (FireRate / 1000),
    Lost_Road = EffectiveBase * (RoadRate / 1000)
  )

# -----------------------------------------
# Step 5: Summarize by year and municipality
loss_summary_by_year_muni_tif <- tif_all %>%
  group_by(TaxYear, Municipality) %>%
  summarise(
    Total_Lost_General = sum(Lost_General, na.rm = TRUE),
    Total_Lost_Fire = sum(Lost_Fire, na.rm = TRUE),
    Total_Lost_Road = sum(Lost_Road, na.rm = TRUE),
    Total_Lost_Township = Total_Lost_General + Total_Lost_Fire + Total_Lost_Road,
    .groups = "drop"
  ) %>%
  arrange(TaxYear, Municipality)

# -----------------------------------------
# Step 6: Output
print(loss_summary_by_year_muni_tif)

# Optionally save
write_csv(loss_summary_by_year_muni_tif, here("outputs", "accurate_tif_loss_by_year_municipality.csv"))
