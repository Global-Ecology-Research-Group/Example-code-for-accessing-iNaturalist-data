# Code to get observation data for a specified region, taxon, or project

# The output is a table containing observation data and all associated fields, plus a CSV of selected columns

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

# Get the base URL
base_url <- "https://api.inaturalist.org/v1/observations"
rate_limit_delay <- 1  # seconds between requests (60 requests per minute max)

# Use this code to customize the request
# See https://api.inaturalist.org/v1/docs/#!/Observations/get_observations for all possible parameters
params <- list(
  # enter one or more taxon IDs
  taxon_id = paste(47224, 47607, sep=","), # butterflies (Papilionoidea) and owlet moths (Noctuoidea)
  # taxon_id = 47224, # butterflies only
  
  # enter one or more place IDs
  place_id = 18, # Texas, US
  
  # Project ID can also be used
  # project_id = "texas-butterflies-and-moths",   
  
  # start (d1) and end date (d2) of observations, if all observations are desired these can be removed
  d1 = "2025-01-01",                         
  d2 = "2025-02-01",
  
  # Research Grade observations only
  quality_grade = "research",
  
  # Set per page to the maximum allowed
  per_page = 200                         
)

# Make one test request and document the run time
start_time <- Sys.time()

response <- GET(base_url, query = params)
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
rate_limit_pause <- time_per_request + rate_limit_delay
estimated_seconds <- total_pages * rate_limit_pause
estimated_minutes <- estimated_seconds / 60

message("Total observations: ", total_results)
message("Estimated pages: ", total_pages)
message(sprintf("Rough estimate of runtime: ~%.1f seconds (~%.1f minutes)", 
                estimated_seconds, estimated_minutes))
# keep in mind that the actual time is variable on how long each individual request takes which is not always consistent

# Fetch all observations
page <- 1
all_pages <- list()

repeat {
  message("Fetching page ", page)
  
  # Build URL
  query_url <- modifyList(params, list(page = page))
  response <- GET(base_url, query = query_url)
  
  stop_for_status(response)
  
  data_json <- content(response, as = "text", encoding = "UTF-8")
  data_parsed <- fromJSON(data_json, flatten = TRUE)
  
  results_df <- as_tibble(data_parsed$results)
  
  # Stop if no results
  if (nrow(results_df) == 0) {
    message("No more results, stopping.")
    break
  }
  
  # Append this page's results
  all_pages[[page]] <- results_df
  
  page <- page + 1
  
  Sys.sleep(rate_limit_delay)
}

# Combine all pages
output_data <- bind_rows(all_pages)

# Examine data
head(output_data)

# Print total observations
cat("Total observations fetched:", nrow(output_data), "\n")

# Select specified columns to write to CSV (many more are available)
columns_to_keep <- c(
  "id", "uuid", "quality_grade", "created_at", "observed_on", "location", 
  "obscured", "public_positional_accuracy", "license_code", "description", 
  "community_taxon_id", "taxon.name", "taxon.rank", "taxon.id", "user.login"
)

available_columns <- intersect(columns_to_keep, colnames(output_data))
csv_data <- output_data[, available_columns, drop = FALSE]

# Write to CSV
output_file <- "observations.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
write.csv(csv_data, file = output_file, row.names = FALSE)
cat("\nData written to", output_file, "\n")
cat("Rows:", nrow(csv_data), ", Columns:", ncol(csv_data), "\n")
