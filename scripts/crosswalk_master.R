library(tidyverse)
library(httr2)
library(lubridate)
library(sf)
library(readr)
library(stringr)
library(lutz)

# =========================================================================
# STEP 1: PREPARE THE FULL DATASET
# =========================================================================

if (!exists("species_projects_joined_new")) {
  stop("Error: Data not loaded. Run 'filter_and_join_tables_BIML_all.R' first.")
}

d <- species_projects_joined_new %>%
  filter(COLLECTION.db != 'USA') %>% 
  mutate(
    verbatimLatitude = latitude,
    verbatimLongitude = longitude,
    longitude = str_replace(string = longitude, pattern = '--', replacement = '-'),
    decimalLatitude = case_when(abs(as.numeric(latitude)) > 90 ~ NA_real_, TRUE ~ as.numeric(latitude)),
    decimalLongitude = case_when(abs(as.numeric(longitude)) > 180 ~ NA_real_, TRUE ~ as.numeric(longitude)),
    tz = 'UTC', 
    sex = case_when(
      sex == 'm' ~ 'Male',
      sex == 'f' ~ 'Female',
      sex == 'q' ~ 'Female',
      sex == 'd' ~ 'Female',
      TRUE ~ 'Indeterminate'
    ),
    verbatimEventDate = paste0('time1:', time1, ';', 'time2:', time2)
  )

# =========================================================================
# STEP 2: TIME AND SPACE STANDARDIZATION
# =========================================================================

with_coords <- d %>% filter(!is.na(decimalLongitude) & !is.na(decimalLatitude))
if(nrow(with_coords) > 0) {
  d$tz[!is.na(d$decimalLongitude) & !is.na(d$decimalLatitude)] <- lutz::tz_lookup_coords(
    lat = with_coords$decimalLatitude, lon = with_coords$decimalLongitude, method = "accurate")
}

make_iso8601 <- function(year, month, day, hour, minute, second) {
  case_when(
    is.na(year) ~ NA_character_,
    is.na(month) ~ year,
    is.na(day) ~ str_c(year, month, sep = "-"),
    is.na(hour) ~ str_c(year, month, day, sep = "-"),
    is.na(minute) ~ str_c(year, month, day, "T", hour),
    is.na(second) ~ str_c(year, month, day, "T", hour, ":", minute),
    TRUE ~ str_c(year, month, day, "T", hour, ":", minute, ":", second)
  )
}

d_cleaned <- d %>% 
  mutate(
    year1 = str_sub(time1, start = 1, end = 4),
    year2 = str_sub(time2, start = 1, end = 4),
    month1 = str_sub(time1, start = 5, end = 6),
    month2 = str_sub(time2, start = 5, end = 6),
    day1 = str_sub(time1, start = 7, end = 8),
    day2 = str_sub(time2, start = 7, end = 8),
    hour1 = str_sub(time1, start = 9, end = 10),
    hour2 = str_sub(time2, start = 9, end = 10),
    minute1 = str_sub(time1, start = 11, end = 12),
    minute2 = str_sub(time2, start = 11, end = 12),
    sec1 = str_sub(time1, start = 13, end = 14),
    sec2 = str_sub(time2, start = 13, end = 14)) %>%
  mutate(across(year1:sec2, ~ na_if(.x, "xx")))  %>%
  mutate(
    start_iso8601 = make_iso8601(year1, month1, day1, hour1, minute1, sec1),
    end_iso8601   = make_iso8601(year2, month2, day2, hour2, minute2, sec2)
  ) %>%
  mutate(
    t1final = parse_date_time(start_iso8601, c("Y","Ym", "Ymd", "YmdH", "YmdHM", "YmdHMs")),
    bad_start_dates = case_when(is.na(t1final) ~ start_iso8601),
    t1final = force_tz(t1final, tzone = tz),
    t2final = parse_date_time(end_iso8601, c("Y","Ym", "Ymd", "YmdH", "YmdHM", "YmdHMs")),
    bad_end_dates = case_when(is.na(t1final) ~ end_iso8601),
    t2final = force_tz(t2final, tzone = tz),
    t1final = with_tz(time = t1final, tzone = 'UTC'),
    t2final = with_tz(time = t2final, tzone = 'UTC'),
    year = year(t1final), month = month(t1final), day = day(t1final),
    badTS = case_when(day > day(t2final) & month >= month(t2final) & year >= year(t2final) ~ ID.,
                      month > month(t2final) & year >= year(t2final) ~ ID.,
                      year > year(t2final) ~ ID.),
    t1final = as.character(t1final),
    t2final = as.character(t2final),
    t1final = case_when(t1final != 'NA' & str_detect(t1final, pattern = '\\s', negate = TRUE) ~ t1final, str_detect(t1final, pattern = '\\s') ~ paste0(t1final, 'Z')),
    t2final = case_when(t2final != 'NA' & str_detect(t2final, pattern = '\\s', negate = TRUE) ~ t2final %>% as.character(), str_detect(t2final, pattern = '\\s') ~ paste0(t2final, 'Z')),
    t1final = case_when(is.na(decimalLatitude) | is.na(decimalLongitude) ~ as.character(start_iso8601), TRUE ~ t1final),
    t2final = case_when(is.na(decimalLatitude) | is.na(decimalLongitude) ~ as.character(end_iso8601), TRUE ~ t2final),
    eventDate = case_when(!is.na(t1final) & !is.na(t2final) & (t1final != t2final) ~ paste0(t1final, '/', t2final) %>% str_replace_all(., pattern = '\\s', replacement = 'T'), t1final == t2final ~ t1final),
    eventDate = case_when(!is.na(badTS) ~ t1final, TRUE ~ eventDate),
    tz = case_when(is.na(decimalLatitude) | is.na(decimalLongitude) ~ NA_character_, TRUE ~ tz) 
  )

# =========================================================================
# STEP 3: TAXONOMY (Batched & Safe)
# =========================================================================

patterns_to_trim_to_genus <- paste(c('[^a-zA-Z\\s]', '\\sspecies', '\\sweird', '\\sinteresting', '\\simmature', '\\sAA', '\\sWYCALUT', '\\sWY CAL SD', '\\sMRL'), collapse = '|')
patterns_to_filter_out <- c("Deleted", "Destroyed", "Destroyed ", "Destoryed", "Destroy", "destroyed", "Destroyed", "no ID", "Unknown")

d_cleaned <- d_cleaned %>% filter(!name %in% patterns_to_filter_out)

d_cleaned_tax <- d_cleaned %>% 
  mutate(trim2genus = str_remove(string = name, pattern = '\\s.*$'),
         query_names = case_when(str_detect(string = name, pattern = patterns_to_trim_to_genus) ~ trim2genus, TRUE ~ name))

query_names_vector <- d_cleaned_tax %>% pull(query_names) %>% unique()
query_names_vector[query_names_vector=='Bee'] <- 'Hymenoptera'
query_names_vector[query_names_vector=='Nonbee'] <- 'Insecta'
query_names_vector <- unique(query_names_vector[!query_names_vector == "No_Bees_Found"])

print(paste("Querying GBIF for", length(query_names_vector), "unique names..."))

chunks <- split(query_names_vector, ceiling(seq_along(query_names_vector)/20))
tax_table <- bind_rows(lapply(chunks, function(x) {
  cat(".") 
  Sys.sleep(5) 
  tryCatch({
    rgbif::name_backbone_checklist(name_data = x, kingdom = 'Animalia', class = 'Insecta')
  }, error = function(e) {
    print("Retry...")
    Sys.sleep(10)
    rgbif::name_backbone_checklist(name_data = x, kingdom = 'Animalia', class = 'Insecta')
  })
}))
cat("\nGBIF Query Complete.\n")

# =========================================================================
# STEP 4: MAPPING AND EXPORT LOOP
# =========================================================================

DwC_terms <- read.csv("https://raw.githubusercontent.com/tdwg/dwc/refs/heads/master/vocabulary/term_versions.csv") %>% 
  filter(status == "recommended") %>% 
  pull(term_localName)

unique_projects <- unique(d_cleaned_tax$datasetID)

for (proj in unique_projects) {
  
  print(paste("Processing:", proj))
  project_data <- d_cleaned_tax %>% filter(datasetID == proj)
  
  # EVENT TABLE
  event <- project_data %>% 
    mutate(
      institutionCode, institutionID, datasetName, datasetID = datasetID, eventID = COLLECTION.db, 
      eventRemarks = paste(ifelse(is.na(field_note), "", field_note), ifelse(is.na(note), "", note), ifelse(is.na(decimalLongitude), "Timezone uncertain", ""), sep = " | ") %>% str_remove_all("^ \\| | \\| $"),
      samplingProtocol = case_when(how0 == 'pan trap' ~ 'bowl trap', TRUE ~ how0),
      sampleSizeValue = case_when(samplingProtocol == 'bowl trap' ~ how1, samplingProtocol == 'hand net' ~ as.character(str_count(who, ",") + 1), TRUE ~ NA_character_),
      sampleSizeUnit = case_when(samplingProtocol == 'bowl trap' ~ 'bowl traps collected', samplingProtocol == 'hand net' ~ 'collectors', TRUE ~ NA_character_),
      verbatimEventDate, eventDate, year, month, day, locationID = site, locality = city, county, stateProvince = state,
      countryCode = countrycode::countrycode(country, origin = 'country.name', destination = 'iso2c', warn = TRUE, nomatch = country),
      .keep = 'none') %>%
    select(any_of(DwC_terms)) %>% 
    distinct()
  
  # OCCURRENCE TABLE
  occ <- project_data %>% 
    left_join(tax_table %>% select(verbatim_name, scientificName, kingdom, phylum, class, order, family, genus, species, rank), by = c("query_names" = "verbatim_name")) %>% 
    mutate(
      eventID = COLLECTION.db, occurrenceID = paste0("https://www.discoverlife.org/mp/20l?id=", ID.), catalogNumber = ID.,
      occurrenceStatus = case_when(name == "No_Bees_Found" ~ "absent", TRUE ~ "present"),
      individualCount = case_when(name == "No_Bees_Found" ~ 0, TRUE ~ 1),
      scientificName = case_when(name == "No_Bees_Found" ~ NA_character_, TRUE ~ scientificName),
      basisOfRecord = 'PreservedSpecimen', 
      collectedBy = str_replace_all(who, pattern = ',', replacement = '|'), 
      verbatimIdentification = name, taxonRank = rank,
      recordedBy = str_replace(who, pattern = ", ", replacement = "|"),
      identifiedBy = DeterminedBy, dateIdentified = case_when(DeterminedWhen > '1900-01-01' ~ DeterminedWhen),
      identificationRemarks = SpeciesNotes, sex, 
      datasetID, collectionCode = if("collectionCode" %in% names(.)) collectionCode else 'BIML', 
      collectionID = 'https://scientific-collections.gbif.org/collection/2338a0da-9fd4-42e5-9a61-2607a0b339aa',
      verbatimEventDate, eventDate, year, month, day,
      decimalLatitude = decimalLatitude, decimalLongitude = decimalLongitude, geodeticDatum = "WGS84", 
      coordinatePrecision = case_when(accuracy == 1 ~ 0.1, accuracy == 2 ~ 0.01, accuracy == 3 ~ 0.001, accuracy == 4 ~ 0.0001, accuracy == 5 ~ 0.00001),
      .keep = 'none') %>%
    select(any_of(DwC_terms)) %>% 
    filter(verbatimIdentification != 'Destroyed')
  
  # EMOF TABLE
  emof <- project_data %>% 
    mutate(
      datasetID, occurrenceID = paste0("https://www.discoverlife.org/mp/20l?id=", ID.), eventID = COLLECTION.db,
      'TrapSize' = how2, 'TrapLiquid' = how4, 
      # --- FIX: Replace pan trap with bowl trap in EMoF ---
      'SamplingMethod' = case_when(how0 == 'pan trap' ~ 'bowl trap', TRUE ~ how0),
      .keep = 'none') %>% 
    distinct() %>% 
    pivot_longer(cols = c(`TrapSize`, `TrapLiquid`, `SamplingMethod`), names_to = 'measurementType', values_to = 'measurementValue') %>% 
    filter(!is.na(measurementValue)) 
  
  # EXPORT (Using write_excel_csv to fix Förster/Special Character issues)
  safe_name <- str_replace_all(proj, "[^a-zA-Z0-9]", "_")
  write_excel_csv(event, file = here::here('output', paste0(safe_name, '_DwC_event_', Sys.Date(), '.gz')), na = "")
  write_excel_csv(occ, file = here::here('output', paste0(safe_name, '_DwC_occ_', Sys.Date(), '.gz')), na = "")
  write_excel_csv(emof, file = here::here('output', paste0(safe_name, '_DwC_EMoF_', Sys.Date(), '.gz')), na = "")
}

print("WORKFLOW COMPLETE.")