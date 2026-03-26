library(tidyverse)

# add this to scripts/investigate_errors.R


# 1. Read the list of errors  generated
# (This contains the ID and the specific error flags)
errors <- read_csv("output/BIML_flag_table.csv")

# 2. Read the full raw data
# (We use read_delim with '$' because that is your file format)
raw_data <- read_delim("data/USGS_DRO_flat.txt.gz", 
                       delim = "$", 
                       show_col_types = FALSE)

# 3. Extract the full rows for the bad records
# We match the raw 'ID.' column to the error 'ID' column
bad_records_full <- raw_data %>%
  inner_join(errors, by = c("ID." = "ID")) %>%
  
  # Reorder columns so the ID and the Flag Description are the first things you see
  select(ID., flags, everything())

# 4. Check how many we found
print(paste("Found", nrow(bad_records_full), "records to investigate."))

# 5. Save 
write_csv(bad_records_full, "output/records_to_investigate.csv")