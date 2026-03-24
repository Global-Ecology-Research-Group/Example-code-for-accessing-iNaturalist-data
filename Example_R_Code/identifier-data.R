# Code to get identifers matching search criteria

# The output is a table of identifiers and counts of identifications that match the filters, plus a CSV.
# The API returns at most 500 identifiers.

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
base_url <- "https://api.inaturalist.org/v2/observations/identifiers"
rate_limit_delay <- 1  # seconds between requests (60 requests per minute max)

# Before creating a customized request, the v2 API requires that users specify desired data fields
# The code below will provide an example of all data available from iNaturalist along with field names
fields <- fromJSON(content(GET("https://api.inaturalist.org/v2/observations?fields=all"), as = "text", encoding = "UTF-8"))
colnames(fields$results)

# Use this code to customize the request
# By default, API v2 returns minimal result objects. Request attributes via comma-separated `fields`.
# See https://api.inaturalist.org/v2/docs/.
params <- list(
  # enter one or more taxon IDs
  taxon_id = 28339, # Garter snakes
  
  # enter one or more place IDs
  place_id = 10, # Oregon, US
  
  # start (d1) and end date (d2) of observations, if all observations are desired these can be removed
  d1 = "2025-01-01",                         
  d2 = "2025-04-30",
  
  # Specify desired data fields (see lines 28-29 above for all available fields)
  fields = paste("count", "user.id", "user.login", "user.created_at", "user.name", "user.observations_count",
                 "user.identifications_count", sep=","),
  
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
# If total observations is greater than 500, then this script will only return the first 500 results.

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
cat("Total data fetched:", nrow(output_data), "\n")

# Check to see if output data includes all results for specified endpoint.
ifelse(total_results > nrow(output_data), 
       "Note: total_results is larger than the rows in this response — this endpoint returns at most 500 ranked identifiers per request, so this response is only a subset.",
       "This endpoint returned all results for the specified endpoint")

# Write to CSV
output_file <- "identifer_data.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
write.csv(output_data, file = output_file, row.names = FALSE)
cat("\nData written to", output_file, "\n")
cat("Rows:", nrow(csv_data), ", Columns:", ncol(csv_data), "\n")
