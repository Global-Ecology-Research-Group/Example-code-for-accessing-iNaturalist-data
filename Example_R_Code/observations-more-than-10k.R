# Code to get observation data for a specified region, taxon, or project

# The output is a table containing observation data and selected data fields

# This script using batching to get observation data, meaning it is designed to be 
# able to obtain more than 10k observations. However, for this example, we will not 
# be obtaining more than 10K records to reduce strain on the API.

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
base_url <- "https://api.inaturalist.org/v2/observations"
rate_limit_delay <- 1  # seconds between requests (60 requests per minute max)

# Before creating a customized request, the v2 API requires that users specify desired data fields
# The code below will provide an example of all data available from iNaturalist along with field names
fields <- fromJSON(content(GET("https://api.inaturalist.org/v2/observations?fields=all"), as = "text", encoding = "UTF-8"))
colnames(fields$results)

# Use this code to customize the request
# See https://api.inaturalist.org/v1/docs/#!/Observations/get_observations for all possible parameters
params <- list(
  # enter one or more taxon IDs
  taxon_id = 49504, # Atlantic blue crab
  
  # enter one or more place IDs
  place_id = 39, # Maryland, US
  
  # enter end date
  d2 = "2025-12-01",
  
  # Research Grade observations only
  quality_grade = "research",
  
  # Select specific columns to export from iNaturalist (see lines 31-32 above for all possible fields)
  # If all fields are needed, you may instead specify fields = "all"
  fields = paste("id", "uuid", "quality_grade", "created_at", "observed_on", "location", 
                 "obscured", "public_positional_accuracy", "license_code", "description", 
                 "community_taxon_id", "taxon.name", "taxon.rank", "taxon.id", "user.login", sep=","),
  
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

# When making more than one API request, the most straightforward way is to use observation id
# to do this, we have to sort observations by ascending order
order_param_asc <- list(  
  # order by observation ID
  order_by = "id",
  
  # sort by ascending order
  order = "asc")

# these paramaters will be added to the initially defined parameters in the fetch all observations
# repeat request below

# Fetch all observations

# add the number of maximum pages to go through
# in this example, 3 will be used
max_pages <- 3 # use 50 if more than 10K observations are needed

# define the api call with a number
request_num <- 1
all_pages <- list()
id_above <- NULL

repeat {
  
  page <- 1
  pages_fetched <- 0
  last_id <- NULL
  got_any_results <- FALSE
  
  repeat {
    
    if (pages_fetched >= max_pages) break
    
    message("API request ", request_num, ", page ", page)
    
    query_url <- modifyList(c(params, order_param_asc), list(
      page = page,
      id_above = id_above
    ))
    
    response <- GET(base_url, query = query_url)
    stop_for_status(response)
    
    data_parsed <- fromJSON(
      content(response, as = "text", encoding = "UTF-8"),
      flatten = TRUE
    )
    
    results_df <- as_tibble(data_parsed$results)
    
    if (nrow(results_df) == 0) break
    
    got_any_results <- TRUE
    
    all_pages[[length(all_pages) + 1]] <- results_df
    
    last_id <- max(results_df$id, na.rm = TRUE)
    
    page <- page + 1
    pages_fetched <- pages_fetched + 1
    Sys.sleep(rate_limit_delay)
  }
  
  if (pages_fetched < max_pages) {
    message("No more observations — stopping.")
    break
  }
  
  id_above <- last_id
  request_num <- request_num + 1
}

# Combine all pages
output_data <- bind_rows(all_pages)

# Examine data
head(output_data)

# Print total observations
cat("Total observations fetched:", nrow(output_data), "\n")

# Write to CSV
output_file <- "observations.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
write.csv(output_data, file = output_file, row.names = FALSE)
cat("\nData written to", output_file, "\n")
cat("Rows:", nrow(output_data), ", Columns:", ncol(output_data), "\n")
