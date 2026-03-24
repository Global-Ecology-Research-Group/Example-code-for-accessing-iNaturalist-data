# Code to get species count data for a specified region, taxon, or project

# The output is a table with a count and taxonomic information for all species
# in the defined dataset, plus a CSV of selected fields. 
import requests
import pandas as pd
import time
import math

# Constants
BASE_URL = "https://api.inaturalist.org/v2/observations/species_counts"
RATE_LIMIT_DELAY = 1  # seconds between requests (60 requests per minute max)
REQUEST_TIMEOUT = 60  # seconds (connect + read) for each HTTP request

# By default, the API v2 returns minimal result objects (count + taxon.id only). Request the taxon
# attributes we need via `fields`.
# See https://api.inaturalist.org/v2/docs/.
FIELDS = "count,taxon.id,taxon.rank,taxon.name,taxon.preferred_common_name"

# Use this code to customize the request
# See https://api.inaturalist.org/v2/docs for all possible parameters
params = {
    # taxon ID - flowering plants (Angiospermae) are used in this example
    "taxon_id": 47125,
    
    # place ID - Florida, US is used in this example
    "place_id": 21,
    
    # Project ID can also be used
    # "project_id": "2025-uf-deluca-bioblitz",
    
    # start (d1) and end date (d2) of observations, if all observations are desired these can be removed
    "d1": "2025-01-01",
    "d2": "2025-03-01",
    
    # Research Grade observations only
    "quality_grade": "research",
    
    # results per page, which we specified as 500, the maximum allowed for this API call
    "per_page": 500,
    
    "fields": FIELDS,
}

with requests.Session() as session:
    # Before making the request, let's see how much data is contained in the URL and get an estimated time to extract all the data

    # Make one test request and document the run time
    start_time = time.time()

    response = session.get(BASE_URL, params=params, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()

    end_time = time.time()

    time_per_request = end_time - start_time

    # Parse JSON
    data_parsed = response.json()

    # Extract total results and compute pages
    total_results = int(data_parsed.get("total_results") or 0)
    per_page = params["per_page"]
    total_pages = math.ceil(total_results / per_page) if per_page else 0

    # Estimate runtime given 1 seconds between requests
    # This lag ensures that no more than 60 requests are made per minute to meet the iNaturalist rate limits
    rate_limit_pause = time_per_request + RATE_LIMIT_DELAY
    estimated_seconds = total_pages * rate_limit_pause
    estimated_minutes = estimated_seconds / 60

    print(f"Total species: {total_results}")
    print(f"Estimated pages: {total_pages}")
    print(f"Rough estimate of runtime: ~{estimated_seconds:.1f} seconds (~{estimated_minutes:.1f} minutes)")
    # keep in mind that the actual time is variable on how long each individual request takes which is not always consistent

    # The following code is used to extract data from the customized URL

    # Save page 1 data from the initial request
    all_pages = []
    if data_parsed.get("results"):
        page1_df = pd.json_normalize(data_parsed["results"])
        all_pages.append(page1_df)
        print("Fetched page 1")

    # Fetch additional pages if needed
    if total_pages > 1:
        for page in range(2, total_pages + 1):
            print(f"Fetching page {page}")
            
            # Build URL
            query_params = {**params, "page": page}
            response = session.get(
                BASE_URL, params=query_params, timeout=REQUEST_TIMEOUT
            )
            
            response.raise_for_status()
            
            data_parsed = response.json()
            
            # Convert results to DataFrame
            raw_results = data_parsed.get("results") or []
            results_df = pd.json_normalize(raw_results)
            if results_df.empty:
                print("No more results, stopping.")
                break
            
            # Append this page's results
            all_pages.append(results_df)
            
            # Rate limit control: 60 requests per minute (skip sleep after last page)
            if page < total_pages:
                time.sleep(RATE_LIMIT_DELAY)

# Combine all pages
if all_pages:
    output_data = pd.concat(all_pages, ignore_index=True)

    # Write to CSV
    output_file = "species_counts.csv"
    output_data.to_csv(output_file, index=False)
    print(f"\nData written to {output_file}")
    print(f"Rows: {len(output_data)}, Columns: {len(output_data.columns)}")
else:
    print(
        "\nNo species count rows were returned (empty or missing `results` in the API response)."
    )
    print(
        f"API total_results was {total_results}. Not writing species_counts.csv."
    )