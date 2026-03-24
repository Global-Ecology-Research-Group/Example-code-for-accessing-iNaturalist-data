# Code to get identifiers matching search criteria

# The output is a table of identifiers and counts of identifications that match the filters, plus a CSV.
# The API returns at most 500 identifiers.

import pandas as pd
import requests

BASE_URL = "https://api.inaturalist.org/v2/identifications/identifiers"
REQUEST_TIMEOUT = 60  # seconds (connect + read)

# By default, API v2 returns minimal result objects. Request attributes via comma-separated `fields`.
# See https://api.inaturalist.org/v2/docs/.
FIELDS = "count,user.id,user.login,user.created_at,user.name,user.observations_count,user.identifications_count"

params = {
    "taxon_id": 28339,  # Garter snakes
    "place_id": 10,  # Oregon, US
    "d1": "2025-01-01",
    "d2": "2025-04-30",
    "per_page": 500,
    "fields": FIELDS,
}

resp = requests.get(BASE_URL, params=params, timeout=REQUEST_TIMEOUT)
resp.raise_for_status()
data = resp.json()

total_results = data.get("total_results") or 0
results = data.get("results") or []
output_data = pd.json_normalize(results) if results else pd.DataFrame()

print(f"Total identifier rows (API reports): {total_results}")
print(f"Rows in this response: {len(output_data)}")
if total_results > len(output_data):
    print(
        "Note: total_results is larger than the rows in this response — "
        "this endpoint returns at most 500 ranked identifiers per request, "
        "so this response is only a subset."
    )

print(output_data.head())
print(f"Total rows fetched: {len(output_data)}")

output_file = "identifier_data.csv"
if output_data.empty:
    print(f"\nNo rows returned; not writing {output_file}.")
else:
    output_data.to_csv(output_file, index=False)
    print(f"\nData written to {output_file}")
    print(f"Rows: {len(output_data)}, Columns: {len(output_data.columns)}")
