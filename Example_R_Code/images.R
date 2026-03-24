# Download iNaturalist images from URLs

# The URL of iNaturalist images can be obtained from GBIF, the iNaturalist export tool, the API, or the Amazon Open Data program
# In this example, we will use a small dataset from the iNaturalist API
# The script will download images and save a CSV of associated metadata
# Note: This script will not download All Rights Reserved images, which are hosted directly by iNaturalist and have rate limits.

# Check and install required packages
required_packages <- c("httr", "jsonlite", "dplyr", "purrr", "tools", "furrr")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing missing package: ", pkg)
    install.packages(pkg)
  }
}

# load libraries
library(httr)
library(jsonlite)
library(dplyr)
library(purrr)
library(tools)
library(furrr)

# Make a single request for observation data, photo_licensed=true ensures that at least one photo in each observation is licensed and hosted via the iNaturalist Open Data program.
response <- GET("https://api.inaturalist.org/v2/observations?taxon_id=47224&d1=2025-01-01&per_page=100&fields=id,observation_photos.photo.url,observation_photos.photo.license_code,observation_photos.photo.attribution")
data_parsed <- fromJSON(content(response, "text", encoding = "UTF-8"), flatten = TRUE)
image_data <- as.data.frame(data_parsed$results)

# Because iNaturalist observations can contain multiple photos, the image URLs are saved in a list object within
# the data frame, so we have to extract those images URLs from this list.
# To keep the photos tied to the original observation, the observation id will also be extracted along with the 
# photo_number to indicate how many photos are to be downloaded per observation.

# Licensed photos are hosted by Amazon through the iNaturalist Open Data program and can be downloaded concurrently without rate limiting. Here we select images that are also GBIF compatible.
ALLOWED_LICENSES <- c("cc", "cc-by", "cc-by-nc")

# Loop through each observation and extract photos
photo_df <- map_dfr(seq_len(nrow(image_data)), function(i) {
  
  obs_photos <- image_data$observation_photos[[i]]
  obs_id <- image_data$id[i]
  
  # if the photo is licensed under one of the allowed licenses, add the photo to the data frame along with the metadata and a generated filename for saving the photo to the local directory
  if (nrow(obs_photos) == 0) return(NULL)
  
  obs_photos %>%
    mutate(
      id = obs_id,
      photo_number = seq_len(nrow(obs_photos)),
      photo.license_code = as.character(photo.license_code),
      photo_url = as.character(photo.url),
      photo.attribution = as.character(photo.attribution),
      # Generate filename from URL, observation ID, and photo number
      filename = paste0(
        id, "_", photo_number, ".", 
        ifelse(nchar(file_ext(photo_url)) > 0, file_ext(photo_url), "jpg")
      )
    ) %>%
    dplyr::select(id, photo_number, photo_url, photo.license_code, photo.attribution, filename) %>%
    filter(photo.license_code %in% ALLOWED_LICENSES)
})

# View results
if (nrow(photo_df) > 0) {
  print(head(photo_df))
} else {
  message("No photos found matching the license criteria.")
}

# It is recommended to save this data frame to store appropriate attributes for the images.
# In this script, we save it to CSV after filtering to only S3-hosted photos below.

# By default, the URL points to the square (thumbnail) version of the images (75x75 pixels)
# To get the original-sized images (2048 pixels), replace "square" with "original"
# Other size options include: thumb (100 pixels), small (240 pixels), medium (500 pixels), and large (1024 pixels)
photo_df$photo_url <- gsub("square", "original", photo_df$photo_url)

# images with ALLOWED_LICENSES should be hosted on S3, but we double-check here
S3_BASE_URL <- "https://inaturalist-open-data.s3.amazonaws.com/photos/"
photo_df$is_s3 <- grepl(paste0("^", S3_BASE_URL), photo_df$photo_url)
non_s3_photos <- filter(photo_df, !is_s3)
if (nrow(non_s3_photos) > 0) {
  cat("ERROR:", nrow(non_s3_photos), "photos are NOT hosted on S3 (unexpected for ALLOWED_LICENSES):\n")
  
  for (i in seq_len(nrow(non_s3_photos))) {
    row <- non_s3_photos[i, ]
    cat("  Observation", row$id, ", photo", row$photo_number, ":", row$photo_url, "\n")
    cat("    License:", row$photo.license_code, "\n")
  }
  
  cat("\nThese photos will be skipped. Only S3-hosted photos will be downloaded.\n\n")
}

# Filter to only S3 photos for downloading
# any images hosted directly by iNaturalist should be downloaded sequentially with rate limiting, since
# we are only downlading s3 images here, we will download concurrently with threading
photo_df <- filter(photo_df, is_s3)

# If you only want the first image of an observation, uncomment the line below
# photo_df <- photo_df %>% filter(photo_number==1)

# Save metadata to CSV
if (nrow(photo_df) > 0) {
  output_file <- "inat_photo_metadata.csv" # if the data are to be written in a folder path add that here (e.g., "Data/inat_photo_metadata.csv") 
  # Drop the is_s3 column before saving (it's just for filtering)
  photo_df_to_save <- select(photo_df, -is_s3)
  # Write CSV
  write.csv(photo_df_to_save, file = output_file, row.names = FALSE)
  cat("Metadata saved to", output_file, "\n")
}

# Download and save the photos to a folder on your desktop.

# Specify the folder where photos should be saved, then set your working directory to that folder.
photo_folder <- "~/iNat_Photos" 
setwd(photo_folder)
message("Working directory set to: ", getwd())

# Photos will be named by the observation id number and photo number so that they can be 
# linked to full observation details later on.

# Download S3 images concurrently (10 workers = 10 concurrent downloads)
# Adjust max_workers based on your network capacity (10-50 is typical)
# S3 can handle high request rates, so no rate limiting needed
plan(multisession, workers = 10)

# Define a function to download each image
download_image <- function(row) {
  url <- row$photo_url
  file_name <- row$filename  
  
  tryCatch({
    GET(url, write_disk(file_name, overwrite = TRUE))
    paste("Downloaded:", file_name)
  }, error = function(e) {
    paste("Failed to download:", url, "- Error:", e$message)
  })
}

# Run downloads concurrently if photo_df is not empty
if (nrow(photo_df) > 0) {
  message("Downloading ", nrow(photo_df), " S3-hosted images using 10 concurrent workers...")
  
  results <- future_map_chr(
    seq_len(nrow(photo_df)), 
    ~ download_image(photo_df[., ]),
    .progress = TRUE
  )
  
  # Print results
  cat(paste(results, collapse = "\n"), "\n")
  
} else {
  message("No S3-hosted images to download.")
}
