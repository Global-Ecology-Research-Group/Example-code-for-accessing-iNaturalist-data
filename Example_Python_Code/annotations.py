# Code to get observations with annotation data and extract annotations

# The default output is long format: one row per annotation, so observations with multiple annotations will have multiple rows.
# Optionally you can also write a wide CSV: one row per observation with annotations in additional columns; see the commented call near the end of the script.


from pyinaturalist import get_observations, enable_logging
import pandas as pd

enable_logging()

# Annotation groups (controlled_attribute_id -> label)
ATTR = {
    "1": "Life Stage",
    "9": "Sex",
    "12": "Flowers & Fruits",
    "36": "Leaves",
    "17": "Alive or Dead",
    "22": "Evidence of Presence",
    "33": "Established",
}

# Values (controlled_value_id -> label)
VAL = {
    # Life Stage
    "2": "Adult",
    "3": "Teneral",
    "8": "Juvenile",
    "16": "Subimago",
    "5": "Nymph",
    "4": "Pupa",
    "6": "Larva",
    "7": "Egg",
    # Sex
    "10": "Female",
    "11": "Male",
    "20": "Cannot Be Determined",
    # Flowers & Fruits
    "15": "Flower Buds",
    "13": "Flowers",
    "14": "Fruits or Seeds",
    "21": "No Flowers or Fruits",
    # Leaves
    "37": "Breaking Leaf Buds",
    "38": "Green Leaves",
    "39": "Colored Leaves",
    "40": "No Live Leaves",
    # Alive or Dead
    "18": "Alive",
    "19": "Dead",
    # 20 = Cannot Be Determined, already set above
    # Evidence of Presence
    "27": "Bone",
    "35": "Construction",
    "23": "Feather",
    "30": "Egg",
    "29": "Gall",
    "31": "Hair",
    "32": "Leafmine",
    "28": "Molt",
    "24": "Organism",
    "25": "Scat",
    "26": "Track",
    # Established status
    "34": "Not Established",
}

# Customize the request
# In this example, we pull all common pawpaw observations in Virginia, US during
# 2025 that have at least one annotation
params = {
    "taxon_id": 50897,  # Common pawpaw
    "place_id": 7,  # Virginia, US
    "d1": "2025-01-01",
    "d2": "2025-12-31",
    "quality_grade": "research",
    "term_id": [int(k) for k in ATTR],
    "page": "all",
}

print("Fetching observations (with annotations)...")
data_parsed = get_observations(**params)
results = data_parsed.get("results") or []
print(f"Total observations (API): {data_parsed.get('total_results')}")
print(f"Rows retrieved: {len(results)}")

if not results:
    print("No observations found.")
    raise SystemExit(0)

# One row per (observation, annotation) for join
annotation_rows = []
for obs in results:
    oid = obs.get("id")
    for ann in obs.get("annotations") or []:
        aid = ann.get("controlled_attribute_id")
        vid = ann.get("controlled_value_id")
        annotation_rows.append(
            {
                "id": oid,
                "attribute": ATTR.get(str(aid)),
                "value": VAL.get(str(vid)),
            }
        )

annotations_df = pd.DataFrame(annotation_rows)
obs_df = pd.json_normalize(results)

columns_to_keep = [
    "id",
    "uuid",
    "quality_grade",
    "created_at",
    "observed_on",
    "location",
    "obscured",
    "public_positional_accuracy",
    "license_code",
    "description",
    "community_taxon_id",
    "taxon.name",
    "taxon.rank",
    "taxon.id",
    "user.login",
]
available = [c for c in columns_to_keep if c in obs_df.columns]
obs_clean = obs_df[available].copy()

# Function to write a wide CSV (optional)
def _write_annotations_wide_csv(obs_clean, annotations_df, output_path="annotations_wide.csv"):
    # One row per observation; one column per attribute; multiple values -> " | ".
    if annotations_df.empty:
        wide = obs_clean.copy()
    else:
        sub = annotations_df[annotations_df["attribute"].notna()]
        if sub.empty:
            wide = obs_clean.copy()
        else:
            grouped = (
                sub.groupby(["id", "attribute"], as_index=False)["value"].agg(
                    lambda s: " | ".join(sorted({str(x) for x in s if pd.notna(x)}))
                )
            )
            pivoted = grouped.pivot(
                index="id", columns="attribute", values="value"
            ).reset_index()
            wide = obs_clean.merge(pivoted, on="id", how="left")
    wide.to_csv(output_path, index=False)
    print(f"\nData written to {output_path}")
    print(f"Rows: {len(wide)}, Columns: {len(wide.columns)}")


if annotations_df.empty:
    merged = obs_clean
    print("No annotation rows extracted (unexpected if term_id filter matched).")
else:
    merged = obs_clean.merge(annotations_df, on="id", how="left")

output_file = "annotations.csv"
merged.to_csv(output_file, index=False)
print(f"\nData written to {output_file}")
print(f"Rows: {len(merged)}, Columns: {len(merged.columns)}")

# Optional wide CSV (one column per attribute; multi-value cells use " | ").
# Uncomment the next line to also write annotations_wide.csv:
# _write_annotations_wide_csv(obs_clean, annotations_df)
