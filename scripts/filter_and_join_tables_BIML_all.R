library(tidyverse)

# 1. READ THE FILE SAFELY (Variable MUST be named 'biml_flat')
biml_flat <- readr::read_delim(
  file = "data/USGS_DRO_flat.txt.gz", 
  delim = '$', 
  quote = "", 
  escape_backslash = FALSE,
  escape_double = FALSE,
  col_types = cols(.default = "c")
) %>%
  rename(datasetID = email) 

# 2. IMPORT PROJECT IDENTIFIERS
projID_table <- read_csv(file = 'data/Project_Identifiers_Table.csv') %>%
  rename(collectionCode = collectionID) %>% 
  bind_rows(
    tibble(
      ID = 4,
      datasetID = 'BIML',
      collectionCode = 'BIML',
      datasetName = 'Insect Species Occurrence Data from Multiple Projects Worldwide with Focus on Bees and Wasps in North America',
      institutionCode = 'USGS',
      institutionID = 'https://ror.org/035a68863',
      ownerInstitutionCode = 'USGS',
      publisher = 'USGS'
    ) 
  )

# 3. FILTER DATA
# Remove rows without species names
biml_flat <- biml_flat %>%
  filter(!is.na(name))

# 4. JOIN DATA
# Update datasetID defaults and merge
filteredData <- biml_flat %>%
  mutate(datasetID = ifelse(!(datasetID %in% projID_table$datasetID), "BIML", datasetID))

species_projects_joined_new <- filteredData %>%
  left_join(x = ., y = projID_table, by = 'datasetID')

# 5. DIAGNOSTIC CHECK (Prints to console)
if("note" %in% names(species_projects_joined_new)) {
  print("SUCCESS: 'note' column found. Pipeline is safe to proceed.")
} else {
  stop("CRITICAL ERROR: 'note' column is STILL missing. Check read_delim settings.")
}