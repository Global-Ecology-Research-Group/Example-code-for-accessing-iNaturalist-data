# Code to get observers matching search criteria

# The output is a table of observation counts, species counts, observers, and observer details, plus a CSV.
# The API returns at most 500 observers total.

# Check and install required packages
required_packages <- c("httr", "jsonlite", "dplyr")

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

# Get the base URL
base_url <- "https://api.inaturalist.org/v2/observations/observers"

# Before creating a customized request, the v2 API requires that users specify desired data fields
# The code below will provide an example of all data available from iNaturalist along with field names
fields <- fromJSON(content(GET("https://api.inaturalist.org/v2/observations/observers?fields=all"), as = "text", encoding = "UTF-8"))
colnames(fields$results)

# Use this code to customize the request
# See https://api.inaturalist.org/v2/docs/#!/Observations/get_observations_observers for all possible parameters
params <- list(
  # enter one or more taxon IDs
  taxon_id = 49199, # yellow stingray
  
  # enter one or more place IDs
  place_id = 21, # Florida, US
  
  # start (d1) and end date (d2) of observations, if all observations are desired these can be removed
  d1 = "2025-01-01",                         
  d2 = "2025-12-31",
  
  # Research Grade observations only
  quality_grade = "research",
  
  # Specify desired data fields (see lines 24-27 above for all available fields)
  fields = paste("observation_count", "species_count", "user.id", "user.login", 
                 "user.created_at", "user.name", "user.observations_count",
                 "user.identifications_count", sep=","),
  
  # Maximum results for this endpoint
  per_page = 500                         
)

response <- GET(base_url, query = params)
stop_for_status(response)

data_parsed <- fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)

total_results <- data_parsed$total_results
message(
  "Total observer rows (API): ",
  if (is.null(total_results)) "(not reported)" else as.integer(total_results)
)

res <- data_parsed$results
output_data <- if (is.null(res)) tibble() else as_tibble(res)

message("Rows in this response: ", nrow(output_data))
if (!is.null(total_results) && as.integer(total_results) > nrow(output_data)) {
  message(
    "Note: total_results is larger than the rows in this response — ",
    "the observers endpoint returns at most 500 rows total, ",
    "so this response may be only a subset."
  )
}

# Examine data
head(output_data)
cat("Total rows fetched:", nrow(output_data), "\n")

# Write to CSV
output_file <- "observer_data.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")
if (nrow(output_data) == 0) {
  message("\nNo rows returned; not writing ", output_file, ".")
} else {
  write.csv(output_data, file = output_file, row.names = FALSE)
  cat("\nData written to", output_file, "\n")
  cat("Rows:", nrow(output_data), ", Columns:", ncol(output_data), "\n")
}
