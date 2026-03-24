# Download iNaturalist images from URLs

# The URL of iNaturalist images can be obtained from GBIF, the iNaturalist export tool, the API, or the Amazon Open Data program
# In this example, we will use a small dataset from the iNaturalist API
# The script will download images and save a CSV of associated metadata
# Note: This script will not download All Rights Reserved images, which are hosted directly by iNaturalist and have rate limits.

import requests
import pandas as pd
import os
from concurrent.futures import ThreadPoolExecutor, as_completed  # concurrent downloads

REQUEST_TIMEOUT = 60  # seconds for API and image downloads (connect + read)

# Make a single request for observation data, photo_licensed=true ensures that at least one photo in each observation is licensed and hosted via the iNaturalist Open Data program.
response = requests.get(
    "https://api.inaturalist.org/v2/observations?taxon_id=47224&d1=2025-01-01&photo_licensed=true&per_page=100&fields=id,observation_photos.photo.url,observation_photos.photo.license_code,observation_photos.photo.attribution",
    timeout=REQUEST_TIMEOUT,
)
response.raise_for_status()
data_parsed = response.json()
image_data = pd.json_normalize(data_parsed["results"])

# Because iNaturalist observations can contain multiple photos, the image URLs are saved in a list object within
# the data frame, so we have to extract those images URLs from this list.
# To keep the photos tied to the original observation, the observation id will also be extracted along with the 
# photo_number to indicate how many photos are to be downloaded per observation.

# Licensed photos are hosted by Amazon through the iNaturalist Open Data program and can be downloaded concurrently without rate limiting. Here we select images that are also GBIF compatible.
ALLOWED_LICENSES = {"cc", "cc-by", "cc-by-nc"}

photo_rows = []
# Loop through each observation
for _, row in image_data.iterrows():
    obs_id = row["id"]
    obs_photos_raw = row.get("observation_photos", [])
    obs_photos = obs_photos_raw if isinstance(obs_photos_raw, list) else []
    
    # loop through each photo in the observation
    for photo_num, photo in enumerate(obs_photos, start=1):
        photo_data = photo.get("photo", {})
        license_code = str(photo_data.get("license_code", ""))
        
        # if the photo is licensed under one of the allowed licenses, add the photo to the data frame along with the metadata and a generated filename for saving the photo to the local directory
        if license_code in ALLOWED_LICENSES:
            photo_url = photo_data.get("url", "")
            if photo_url:
                # Generate a filename from the URL, observation ID, and photo number
                filename = photo_url.split('/')[-1].split('?')[0]
                file_ext = os.path.splitext(filename)[1].lstrip(".") or "jpg" # default to jpg if no extension found
                file_name = f"{obs_id}_{photo_num}.{file_ext}"
                
                # if you want additional metadata, e.g. user.login, observed_on, etc., you can add them to the fields parameter in the API request and then add them to the data frame here.
                photo_rows.append({
                    "id": obs_id,
                    "photo_number": photo_num,
                    "photo_url": photo_url,
                    "photo.license_code": license_code,
                    "photo.attribution": photo_data.get("attribution", ""),
                    "filename": file_name # The local filename we generated
                })

photo_df = pd.DataFrame(photo_rows)

# View result
if not photo_df.empty:
    print(photo_df.head())
else:
    print("No photos found matching the license criteria.")
    print("Exiting - no images to download.")
    raise SystemExit(0)

# It is recommended to save this data frame to store appropriate attributes for the images.
# In this script, we save it to CSV after filtering to only S3-hosted photos below.

# By default, the URL points to the square (thumbnail) version of the images (75x75 pixels)
# To get the original-sized images (2048 pixels), replace "square" with "original"
# Other size options include: thumb (100 pixels), small (240 pixels), medium (500 pixels), and large (1024 pixels)
photo_df["photo_url"] = photo_df["photo_url"].str.replace("square", "original", regex=False)

# images with ALLOWED_LICENSES should be hosted on S3, but we double-check here
S3_BASE_URL = "https://inaturalist-open-data.s3.amazonaws.com/photos/"
photo_df["is_s3"] = photo_df["photo_url"].str.startswith(S3_BASE_URL)

non_s3_photos = photo_df[~photo_df["is_s3"]]
if not non_s3_photos.empty:
    print(f"ERROR: {len(non_s3_photos)} photos are NOT hosted on S3 (unexpected for ALLOWED_LICENSES):")
    for _, row in non_s3_photos.iterrows():
        print(f"  Observation {row['id']}, photo {row['photo_number']}: {row['photo_url']}")
        print(f"    License: {row['photo.license_code']}")
    print("\nThese photos will be skipped. Only S3-hosted photos will be downloaded.\n")

# Filter to only S3 photos for downloading
# any images hosted directly by iNaturalist should be downloaded sequentially with rate limiting, since
# we are only downlading s3 images here, we will download concurrently with threading
photo_df = photo_df[photo_df["is_s3"]].copy()

# If you only want the first image of an observation, uncomment the line below
# photo_df = photo_df[photo_df["photo_number"] == 1]

# Save metadata to CSV
if not photo_df.empty:
    output_file = "iNat_photo_metadata.csv"
    # Drop the is_s3 column before saving (it's just for filtering)
    photo_df.drop(columns=["is_s3"], inplace=True)
    photo_df.to_csv(output_file, index=False)
    print(f"Metadata saved to {output_file}\n")

# Download and save the photos under a folder in your home directory (full paths — no os.chdir).
photo_folder = os.path.join(os.path.expanduser("~"), "iNat_Photos")
os.makedirs(photo_folder, exist_ok=True)
print(f"Saving images under: {photo_folder}")

# Photos will be named by the observation id number and photo number so that they can be 
# linked to full observation details later on.

def download_image(row, dest_dir):
    """Download a single image; write to dest_dir using the row's filename."""
    url = row["photo_url"]
    file_name = row["filename"]
    path = os.path.join(dest_dir, file_name)
    try:
        img_response = requests.get(url, timeout=REQUEST_TIMEOUT)
        img_response.raise_for_status()
        with open(path, "wb") as f:
            f.write(img_response.content)
        return f"Downloaded: {path}"
    except Exception as e:
        return f"Failed to download: {url} - Error: {e}"

# Download S3 images concurrently (10 workers = 10 concurrent downloads)
# Adjust max_workers based on your network capacity (10-50 is typical)
# S3 can handle high request rates, so no rate limiting needed
if not photo_df.empty:
    print(f"Downloading {len(photo_df)} S3-hosted images using threading...")
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {
            executor.submit(download_image, row, photo_folder): row
            for _, row in photo_df.iterrows()
        }
        for future in as_completed(futures):
            print(future.result())
else:
    print("No S3-hosted images to download.")
