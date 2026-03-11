# Code to get relevant controlled term values and monthly histogram data

# The output is a table list of observation count by month and relevant control term values

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
base_url <- "https://api.inaturalist.org/v1/observations/popular_field_values"
rate_limit_delay <- 1  # seconds between requests (60 requests per minute max)

# Use this code to customize the request
# See https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_popular_field_values for all possible parameters
params <- list(
  # enter one or more taxon IDs
  taxon_id = 3, # Birds
  
  # enter one or more place IDs
  place_id = 18 # Texas, US
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
# Build URL
response <- GET(base_url, query = params)
stop_for_status(response)
data_json <- content(response, as = "text", encoding = "UTF-8")
data_parsed <- fromJSON(data_json, flatten = TRUE)
  
results_df <- as_tibble(data_parsed$results)

# Combine all pages
output_data <- bind_rows(results_df)

# Examine data
head(output_data)

# Print total observations
cat("Total data fetched:", nrow(output_data), "\n")

# Write to CSV
output_file <- "popular_field_values_data.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
write.csv(output_data, file = output_file, row.names = FALSE)
cat("\nData written to", output_file, "\n")
cat("Rows:", nrow(csv_data), ", Columns:", ncol(csv_data), "\n")
