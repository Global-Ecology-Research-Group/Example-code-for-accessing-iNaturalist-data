# Code to get species count data for a specified region, taxon, or project

# The output is a table with a count and taxonomic information for all species
# in the defined dataset, plus a CSV of selected fields. 

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
base_url <- "https://api.inaturalist.org/v2/observations/species_counts"
rate_limit_delay <- 1  # seconds between requests (60 requests per minute max)

# Before creating a customized request, the v2 API requires that users specify desired data fields
# The code below will provide an example of all data available from iNaturalist along with field names
fields <- fromJSON(content(GET("https://api.inaturalist.org/v2/observations/species_counts?fields=all"), as = "text", encoding = "UTF-8"))
colnames(fields$results %>% unnest_wider(taxon, names_sep = "."))

# Use this code to customize the request
# See https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_species_counts for all possible parameters
params <- list(
  # taxon ID - flowering plants (Angiospermae) are used in this example
  taxon_id = 47125,       
  
  # place ID - Florida, US is used in this example
  place_id = 21, 
  
  # Project ID can also be used
  # project_id = "2025-uf-deluca-bioblitz",   
  
  # start (d1) and end date (d2) of observations, if all observations are desired these can be removed
  d1 = "2025-01-01",                         
  d2 = "2025-03-01",
  
  # Research Grade observations only
  quality_grade = "research",
  
  # Specify desired data fields (see lines 28-29 above for all available fields)
  fields = paste("count", "taxon.id", "taxon.rank", "taxon.name", "taxon.preferred_common_name",
                 sep=","),
  
  # results per page, which we specified as 500, the maximum allowed for this API call
  per_page = 500                        
)

# Before making the request, let's see how much data is contained in the URL and get an estimated time to extract all the data

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

# The following code is used to extract data from the customized URL

# fetch the first page
all_pages <- list()

# fetch additional pages if needed
for (page in 1:total_pages) {
    message("Fetching page ", page)
    
    query_url <- modifyList(params, list(page = page))
    response <- GET(base_url, query = query_url)
    stop_for_status(response)
    
    data_parsed <- fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)
    
    results_df <- as_tibble(data_parsed$results)
    
    if (nrow(results_df) == 0) break
    
    all_pages[[page]] <- results_df
    
    # Sleep between requests except after last page
    if (page < total_pages) Sys.sleep(rate_limit_delay)
}

# Combine all pages
output_data <- bind_rows(all_pages)

# Write CSV
output_file <- "species_counts.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
write.csv(output_data, file = output_file, row.names = FALSE)
message("\nData written to ", output_file)
message("Rows: ", nrow(output_data), ", Columns: ", ncol(output_data))





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
  
  # Calculate total pages from total_results if available
  total_results <- data_parsed$total_results
  total_pages <- ceiling(total_results / params$per_page)
  
  if (page >= total_pages) {
    message("Reached last page: ", page)
    break
  }
  
  page <- page + 1
  
  # Rate limit control: 60 requests per minute
  Sys.sleep(rate_limit_delay) 
}

# Combine all pages
output_data <- bind_rows(all_pages)
print(output_data)

# Convert to a data frame
output_data <- as.data.frame(output_data)
