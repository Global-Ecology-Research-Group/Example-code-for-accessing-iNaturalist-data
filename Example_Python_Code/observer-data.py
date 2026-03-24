# Code to get observers matching search criteria

# The output is a table of observation counts, species counts, observers, and observer details, plus a CSV.

import pandas as pd
from pyinaturalist import get_observation_observers, enable_logging

enable_logging()

params = {
    "taxon_id": 49199,  # Yellow stingray
    "place_id": 21,  # Florida, US
    "d1": "2025-01-01",
    "d2": "2025-12-31",
    "quality_grade": "research",
}

print("Fetching observation observers...")
data = get_observation_observers(**params)
results = data.get("results") or []
n_rows = len(results)
output_data = pd.json_normalize(results) if results else pd.DataFrame()

columns_to_keep = [
    "observation_count",
    "species_count",
    "user.id",
    "user.login",
    "user.created_at",
    "user.name",
    "user.observations_count",
    "user.identifications_count",
]
if not output_data.empty:
    available = [c for c in columns_to_keep if c in output_data.columns]
    output_data = output_data[available]

total = data.get("total_results")
if total is not None:
    print(f"Total observer rows (API): {total}")
print(f"Rows in response: {n_rows}")
if total is not None and total > n_rows:
    print(
        "Note: total_results is larger than the rows in this response — "
        "the observers endpoint returns at most 500 rows per request, "
        "so this response may be only a subset."
    )
print(output_data.head())

output_file = "observer_data.csv"
if output_data.empty:
    print(f"\nNo rows returned; not writing {output_file}.")
else:
    output_data.to_csv(output_file, index=False)
    print(f"\nData written to {output_file}")
    print(f"Rows: {len(output_data)}, Columns: {len(output_data.columns)}")
