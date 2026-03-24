# Code to get popular controlled field values (Annotations) and monthly histogram counts

# The output is a table with observation counts, per-month histogram columns, and
# controlled attribute/value metadata, plus a CSV.

from pyinaturalist import get_observation_popular_field_values
import pandas as pd

params = {
    "taxon_id": 3,  # Birds
    "place_id": 18,  # Texas, US
}

data_parsed = get_observation_popular_field_values(**params)
results = data_parsed.get("results") or []

print(f"Total result rows: {data_parsed.get('total_results', len(results))}")
if not results:
    print("No results.")
    raise SystemExit(0)

output_data = pd.json_normalize(results)
# print(list(output_data.columns))  # uncomment to see every column returned by this request

columns_to_keep = (
    ["count"]
    + [f"month_of_year.{m}" for m in range(1, 13)]
    + [
        "controlled_attribute.id",
        "controlled_attribute.multivalued",
        "controlled_attribute.label",
        "controlled_value.id",
        "controlled_value.label",
    ]
)
available_columns = [col for col in columns_to_keep if col in output_data.columns]
output_data = output_data[available_columns]

print(output_data.head())
print(f"Rows: {len(output_data)}, Columns: {len(output_data.columns)}")

output_file = "popular_field_values_data.csv"
output_data.to_csv(output_file, index=False)
print(f"\nData written to {output_file}")
