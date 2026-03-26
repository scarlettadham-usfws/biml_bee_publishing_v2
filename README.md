***

# BIML to Darwin Core Publishing Pipeline

This repository contains the R-based ETL (Extract, Transform, Load) pipeline for converting the USGS/USFWS Interagency Native Bee Lab (BIML) database flat files into Darwin Core Archive (DwC-A) format for publication to the Global Biodiversity Information Facility (GBIF).

**Original workflow and guideline:** [Aligning BIML Database to Darwin Core for Publication to GBIF](https://sformel.github.io/biml_bee_publishing/) by S. Formel

Current contacts: Scarlett Adham hilola_adham@fws.gov
                  Clare Maffei   clare_maffei@fws.gov

## Overview

The BIML database captures wild bee occurrence and sampling event details using custom fields. This pipeline:
1. **Reads** the massive, compressed `USGS_DRO_flat.txt.gz` file.
2. **Performs QA/QC** to flag invalid dates, coordinates, and taxonomic names.
3. **Joins** the occurrence data with project-level metadata (e.g., USFWS GLRI).
4. **Queries** the GBIF Backbone Taxonomy API to validate and standardize scientific names (Takes around 40 mins).
5. **Transforms** the custom BIML fields into standard Darwin Core terms.
6. **Exports** the final dataset into three standard DwC tables: `event`, `occurrence`, and `extended measurement or fact (EMoF)`.

## Prerequisites

To run this pipeline, you must have R and RStudio installed, along with the following packages:
```r
install.packages(c("tidyverse", "httr2", "lubridate", "sf", "readr", "stringr", "lutz", "countrycode", "rgbif"))
```
- **R:** Version 4.0 or higher
- **RStudio:** Recommended
- **Required R packages:**
  
## Project Structure & Required Files

**IMPORTANT: Raw data files are NOT included in this repository due to size limits.**

Before running the code, you must place two files into the `data/` folder on your local machine:

1. **`USGS_DRO_flat.txt.gz`**: The raw, `$`-delimited database export from the BIML SQL Server. Do not unzip it; the script reads it compressed.
2. **`Project_Identifiers_Table.csv`**: A CSV containing the project metadata (Dataset ID, Institution Code, ROR IDs, etc.) used to map the records to specific FWS or USGS projects.

Your local directory should look like this:
```text
/biml_bee_publishing
├── publishing_workflow.R         <-- Master execution script
├── data/
│   ├── USGS_DRO_flat.txt.gz      <-- YOU MUST ADD THIS
│   └── Project_Identifiers_Table.csv <-- YOU MUST ADD THIS
├── scripts/
│   ├── BIML_QAQC.R
│   ├── filter_and_join_tables_BIML_all.R
│   └── crosswalk_MASTER.R
└── output/                       <-- Generated files will appear here
```

## How to Run the Pipeline

1. Open `publishing_workflow.R` in RStudio.
2. Source the script:
   ```r
   source('publishing_workflow.R')
   ```

### Execution Steps
The master script will execute the pipeline in three phases:

* **Phase 1 (`BIML_QAQC.R`)**: Scans the raw data for structural errors, impossible coordinates, and unparseable dates. Generates flag reports in the `output/` folder.
* **Phase 2 (`filter_and_join...`)**: Filters out records missing a scientific name, maps the internal `email` field to a `datasetID`, and joins the project metadata.
* **Phase 3 (`crosswalk_MASTER.R`)**: 
    * Converts all timestamps to ISO 8601 UTC based on spatial coordinates.
    * Queries the GBIF API in slow, safe batches to retrieve full taxonomic hierarchies.
    * Maps BIML fields (e.g., `how0`, `how2`) to DwC terms (e.g., `samplingProtocol`, `TrapSize`).
    * Exports a separate set of DwC tables (Event, Occ, EMoF) for *each* unique project identified in the metadata.

## Output

Upon successful completion, the `output/` directory will contain:
* `BIML_flag_summary_table.csv` (QAQC Error Summary)
* `BIML_flag_table.csv` (Detailed QAQC Flags per Record)
* `[ProjectID]_DwC_event_[Date].csv.gz` 
* `[ProjectID]_DwC_occ_[Date].csv.gz`
* `[ProjectID]_DwC_EMoF_[Date].csv.gz`

These `.gz` files are ready to be uploaded directly to the GBIF Integrated Publishing Toolkit (IPT).
