library(tidyverse)
library(here)

# 1. Find ONLY the .gz files (Stricter pattern)
# pattern = "DwC_EMoF.*\\.gz$" means: Must contain "DwC_EMoF" AND end with ".gz"
files <- list.files(path = here("output"), pattern = "DwC_EMoF.*\\.gz$", full.names = TRUE)

if(length(files) == 0) stop("No .gz files found in output folder.")

print(paste("Successfully found", length(files), "valid data files."))

# 2. Read and Combine
audit_data <- map_df(files, function(file_path) {
  
  file_name <- basename(file_path)
  # Extract Project Name
  project_id <- str_remove(file_name, "_DwC_EMoF_.*$")
  
  # Read safely
  read_csv(file_path, show_col_types = FALSE) %>%
    select(measurementType, measurementValue) %>%
    mutate(ProjectID = project_id)
})

# 3. Summarize
summary_table <- audit_data %>%
  group_by(ProjectID, measurementType, measurementValue) %>%
  summarise(Count = n(), .groups = "drop") %>%
  arrange(ProjectID, measurementType, desc(Count))

# 4. View in RStudio (Safest way, no file permission issues)
View(summary_table)

# 5. Optional: Save to Downloads folder to avoid OneDrive locks
write_csv(summary_table, file.path(Sys.getenv("USERPROFILE"), "Downloads", "EMoF_Audit_Report.csv"))
print("Backup copy saved to your Downloads folder.")