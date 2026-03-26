
# Output QAQC of original data ------------------------------------

#source('scripts/BIML_QAQC.R')

# Run filter_and_join_tables_BIML_all.R -----------------------------------

#source('scripts/filter_and_join_tables_BIML_all.R')

# crosswalk data and write out for publication ---------------------------

#source('scripts/crosswalk_BIML.R')

#source('scripts/crosswalk_GLRI.R')

# 1. Quality Control
source('scripts/BIML_QAQC.R')

# 2. Data Loading & Joining (Loads "species_projects_joined_new")
source('scripts/filter_and_join_tables_BIML_all.R')

# 3. Master Crosswalk (Cleans & Exports ALL projects)
source('scripts/crosswalk_MASTER.R')