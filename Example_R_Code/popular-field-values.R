# Code to get relevant controlled term values and monthly histogram data

# The output is a table with observation counts, per-month histogram columns, and
# controlled attribute/value metadata, plus a CSV.

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
base_url <- "https://api.inaturalist.org/v2/observations/popular_field_values"

# Use this code to customize the request
# See https://api.inaturalist.org/v2/docs/#!/Observations/get_observations_popular_field_values for all possible parameters
params <- list(
  # enter one or more taxon IDs
  taxon_id = 3, # Birds
  
  # enter one or more place IDs
  place_id = 18, # Texas, US
  
  # obtain all field values
  fields = "all"
)

response <- GET(base_url, query = params)
stop_for_status(response)

data_parsed <- fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)

res <- data_parsed$results
output_data <- if (is.null(res)) tibble() else as_tibble(res)

total_results <- data_parsed$total_results
n_res <- nrow(output_data)
cat(
  "Total result rows:",
  if (is.null(total_results)) n_res else as.integer(total_results),
  "\n"
)

output_file <- "popular_field_values_data.csv" # if the data are to be written in a folder path add that here (e.g., "Data/observations.csv")

if (nrow(output_data) == 0) {
  message("No results.")
} else {
  columns_to_keep <- c(
    "count",
    paste0("month_of_year.", 1:12),
    "controlled_attribute.id",
    "controlled_attribute.multivalued",
    "controlled_attribute.label",
    "controlled_value.id",
    "controlled_value.label"
  )
  available_ordered <- columns_to_keep[columns_to_keep %in% names(output_data)]
  output_data <- output_data |> select(all_of(available_ordered))

  # Examine data
  head(output_data)
  cat(
    "Rows:", nrow(output_data),
    ", Columns:", ncol(output_data), "\n"
  )

  write.csv(output_data, file = output_file, row.names = FALSE)
  cat("\nData written to", output_file, "\n")
}
