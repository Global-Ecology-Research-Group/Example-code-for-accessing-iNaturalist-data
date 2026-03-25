# Code to get observations with annotation data and extract annotations

# The output is a table containing observation data with columns for annotation group and value within that group

# Check and install required packages
required_packages <- c("httr", "jsonlite", "dplyr", "purrr")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing missing package: ", pkg)
    install.packages(pkg)
  }
}

# Load relevant packages
library(httr)
library(jsonlite)
library(dplyr)
library(purrr)

# Define variables 

# Enforce lag to ensure that no more than 60 requests are made per minute to meet the iNaturalist rate limits
DELAY <- 1

# Base URL for API call
base_url <- "https://api.inaturalist.org/v2/observations"

# Before creating a customized request, the v2 API requires that users specify desired data fields
# The code below will provide an example of all data available from iNaturalist along with field names
fields <- fromJSON(content(GET("https://api.inaturalist.org/v2/observations?fields=all"), as = "text", encoding = "UTF-8"))
colnames(fields$results)

# Define annotation groups (term_id)
ATTR <- list(
  "1"  = "life_stage",
  "9"  = "sex",
  "12" = "flowers_and_fruits",
  "36" = "leaves",
  "17" = "alive_or_dead",
  "22" = "evidence_of_presence",
  "33" = "established"
)

# Define values within annotation groups (term_value_id)
VAL <- list(
  # Life Stage
  "2"  = "Adult",
  "3"  = "Teneral",
  "8"  = "Juvenile",
  "16" = "Subimago",
  "5"  = "Nymph",
  "4"  = "Pupa",
  "6"  = "Larva",
  "7"  = "Egg",
  
  # Sex
  "10" = "Female",
  "11" = "Male",
  "20" = "Cannot Be Determined",
  
  # Flowers & Fruits
  "15" = "Flower Buds",
  "13" = "Flowers",
  "14" = "Fruits or Seeds",
  "21" = "No Flowers or Fruits",
  
  # Leaves
  "37" = "Breaking Leaf Buds",
  "38" = "Green Leaves",
  "39" = "Colored Leaves",
  "40" = "No Live Leaves",
  
  # Alive or Dead
  "18" = "Alive",
  "19" = "Dead",
  "20" = "Cannot Be Determined",
  
  # Evidence of Presence
  "27" = "Bone",
  "35" = "Construction",
  "23" = "Feather",
  "30" = "Egg",
  "29" = "Gall",
  "31" = "Hair",
  "32" = "Leafmine",
  "28" = "Molt",
  "24" = "Organism",
  "25" = "Scat",
  "26" = "Track",
  
  # Established status
  "34" = "Not Established"
)

# Customize parameters for API call
# In this example, we pull all common pawpaw observations in Virginia, US during
# 2025 that have at least one annotation
params <- list(
  taxon_id = paste(50897, collapse = ","), # Common pawpaw example
  place_id = 7,                             # Virginia, US
  d1 = "2025-01-01",
  d2 = "2025-12-31",
  quality_grade = "research",
  term_id = paste(names(ATTR), collapse = ","),
  # Specify desired data fields (see lines 29-32 for all options)
  per_page = 200
)

# Fields to request in the response, including annotation attributes and values
fields_obs <- params
fields_obs$fields <- paste(
  "id", "uuid", "quality_grade", "created_at", "observed_on", "location",
  "obscured", "public_positional_accuracy", "license_code", "description",
  "community_taxon_id", "taxon.name", "taxon.rank", "taxon.id", "user.login",
  "annotations.controlled_attribute_id", "annotations.controlled_value_id",
  sep = ","
)

# Make one test request and document the run time
start_time <- Sys.time()

response <- GET(base_url, query = fields_obs)
stop_for_status(response)

end_time <- Sys.time()

time_per_request <- as.numeric(end_time - start_time, units = "secs")

# Parse JSON
data_parsed <- fromJSON(content(response, as = "text", encoding = "UTF-8"))

# Extract total results and compute pages
total_results <- data_parsed$total_results
total_pages <- ceiling(total_results / params$per_page)

# Estimate runtime given 1 second between requests
# This lag ensures that no more than 60 requests are made per minute to meet the iNaturalist rate limits
rate_limit_pause <- time_per_request + DELAY
estimated_seconds <- total_pages * rate_limit_pause
estimated_minutes <- estimated_seconds / 60

message("Total observations: ", total_results)
message("Estimated pages: ", total_pages)
message(sprintf("Rough estimate of runtime: ~%.1f seconds (~%.1f minutes)",
                estimated_seconds, estimated_minutes))
# keep in mind that the actual time is variable on how long each individual request takes which is not always consistent

# Make API call 

# Use the API to obtain all observations from the custom URL
all_pages <- list()
page <- 1
rows_fetched <- 0
repeat {
  message("Fetching page ", page)
  query_url <- modifyList(fields_obs, list(page = page))
  resp <- GET(base_url, query = query_url)
  stop_for_status(resp)
  
  data_json <- content(resp, as = "text", encoding = "UTF-8")
  data_parsed <- fromJSON(data_json, flatten = TRUE)
  results_df <- as_tibble(data_parsed$results)
  
  if (nrow(results_df) == 0) break
  
  all_pages[[page]] <- results_df
  rows_fetched <- rows_fetched + nrow(results_df)
  if (rows_fetched >= total_results) break
  
  page <- page + 1
  Sys.sleep(DELAY)
}

obs_df <- bind_rows(all_pages)
message("Total observations fetched: ", nrow(obs_df))

annotation_rows <- map_dfr(seq_len(nrow(obs_df)), function(i) {
  annos <- obs_df$annotations[[i]]
  obs_id <- obs_df$id[i]

  if (is.null(annos) || length(annos) == 0) return(NULL)

  annos_df <- as_tibble(annos)

  if (nrow(annos_df) == 0) return(NULL)

  annos_df %>%
    mutate(
      id = obs_id,
      controlled_attribute_id = as.character(controlled_attribute_id),
      controlled_value_id = as.character(controlled_value_id),
      attribute = map_chr(controlled_attribute_id, ~ ATTR[[.]] %||% NA_character_),
      value = map_chr(controlled_value_id, ~ VAL[[.]] %||% NA_character_)
    ) %>%
    select(id, attribute, value)
})

# join observation and annotation data, keep all observation columns first
annotations_data <- if (nrow(annotation_rows) > 0L) {
  inner_join(obs_df, annotation_rows, by = "id")
} else {
  annotation_rows
}

# Write to CSV
output_file <- "annotations.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
csv_out <- if (nrow(annotations_data) > 0L) annotations_data else obs_df
csv_out <- csv_out %>% select(where(~ typeof(.) != "list"))
write.csv(csv_out, file = output_file, row.names = FALSE)
cat("\nData written to", output_file, "\n")
cat("Rows:", nrow(csv_out), ", Columns:", ncol(csv_out), "\n")
