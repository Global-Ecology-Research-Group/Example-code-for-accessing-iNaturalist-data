# Code to get observation data for specified regions, taxa, or projects

# The output is a table containing observation data and all associated fields, plus a CSV of selected columns.

# This script can handle both queries returning fewer than 10,000 observations and queries returning more than 10,000 observations because it uses the pyinaturalist library, which handles batching and pagination automatically.

# Load relevant packages
from pyinaturalist import get_observations, enable_logging
import pandas as pd

# Logging shows time estimates and details of each request, can be toggled off
enable_logging()

# Use this code to customize the request
# See https://api.inaturalist.org/v2/docs/#/Observations/get_observations for all possible parameters
params = {
    # enter one or more taxon IDs
    "taxon_id": [47224, 47607], # butterflies (Papilionoidea) and owlet moths (Noctuoidea)
    # "taxon_id": [47224], # butterflies only

    # enter one or more place IDs
    "place_id": [18], # Texas, US
    
    # Project ID can also be used
    # "project_id": "texas-butterflies-and-moths",
    
    # start (d1) and end date (d2) of observations, if all observations are desired these can be removed
    "d1": "2025-01-01",
    "d2": "2025-02-01",
    
    # Research Grade observations only
    "quality_grade": "research",
    
    # When calling the API directly, at most 10,000 observations will be returned.
    # pyinaturalist can handle larger queries, and it also does pagination and rate limiting; "all" is not normally available in the API
    "page": "all"
}

# Fetch all observations
print("Fetching all observations...")
data_parsed = get_observations(**params)

# Convert results to DataFrame
if data_parsed["results"]:
    output_data_df = pd.json_normalize(data_parsed["results"])
    print(f"Total observations: {data_parsed['total_results']}")
    print("\nPreview:")
    print(output_data_df.head())
    # print(list(output_data_df.columns)) # uncomment to see every column returned by this request
    
    # Select specified columns to write to CSV (many more are available, see output_data_df.columns for all columns)
    columns_to_keep = ['id', 'uuid', 'quality_grade', 'created_at', 'observed_on', 'location', 
                       'obscured', 'public_positional_accuracy', 'license_code', 'description', 
                       'community_taxon_id', 'taxon.name', 'taxon.rank', 'taxon.id', 'user.login']
    # Only keep columns that exist in the DataFrame
    available_columns = [col for col in columns_to_keep if col in output_data_df.columns]
    csv_data = output_data_df[available_columns]
    
    # Write to CSV
    output_file = 'observations.csv'
    csv_data.to_csv(output_file, index=False)
    print(f"\nData written to {output_file}")
    print(f"Rows: {len(csv_data)}, Columns: {len(csv_data.columns)}")
else:
    print("No observations found.")
