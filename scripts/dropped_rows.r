library(tidyverse)

# 1. Identify rows in the original data that are NOT in the final Occ table
# match ID. (from raw) to catalogNumber (from final)
dropped_rows <- anti_join(biml_flat, occ, by = c("ID." = "catalogNumber"))

# 2. Add a "Reason" column so you know why they were dropped
dropped_rows_explained <- dropped_rows %>%
  mutate(
    Drop_Reason = case_when(
      datasetID == 'USFWS GLRI' ~ "Excluded Project (GLRI)",
      COLLECTION.db == 'USA' ~ "Invalid Collection Event (USA)",
      name %in% c("Deleted", "Destroyed", "Destroyed ", "Destoryed", "Destroy", "destroyed", "no ID", "Unknown") ~ "Specimen Destroyed/Unknown",
      is.na(name) ~ "Missing Scientific Name",
      TRUE ~ "Other/Unknown" # Likely filtered during the 'Destroyed' check at the very end
    )
  )

# 3. View the breakdown in the console
print("Summary of why rows were dropped:")
print(table(dropped_rows_explained$Drop_Reason))

# 4. Save to CSV for Excel
write_csv(dropped_rows_explained, "output/dropped_records_report.csv")

print("Report saved to: output/dropped_records_report.csv")