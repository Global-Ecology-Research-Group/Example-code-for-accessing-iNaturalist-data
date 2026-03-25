# Supplemental Resources and Example Code for "Guidelines and Best Practices for the Scientific Use of Global iNaturalist Data"

This repository contains supplemental resources and example code for accessing iNaturalist data, as referenced in "Guidelines and best practices for the scientific use of global iNaturalist data" These materials focus on retrieving data through the iNaturalist API when needed data is not available via GBIF or the iNaturalist Export Tool. Example code is provided in both R and Python. These scripts are designed to be customizable to specific research needs, and they rely on the [iNaturalist Version 2 API](https://api.inaturalist.org/v2/docs/).

## References

[External resources](https://github.com/Global-Ecology-Research-Group/Example-code-for-accessing-iNaturalist-data/blob/main/Resources/External_resources.md)

[Introduction to modifying request URLs for the API](https://github.com/Global-Ecology-Research-Group/Example-code-for-accessing-iNaturalist-data/blob/main/Resources/how_to_modify_url.md)

[Introduction on how to batch query data](https://github.com/Global-Ecology-Research-Group/Example-code-for-accessing-iNaturalist-data/blob/main/Resources/Batch_query.md)

## Example Python Code

This folder contains code examples to obtain:

1.  **annotations:** Code to get observations with annotation data and extract annotations. This script outputs a CSV file in long format where there is one row per annotation, so observations with multiple annotations will have multiple rows.

2.  **identifier-data:** Code to get information on identifiers from an API request. This script outputs a CSV of identifiers and counts of identifications that match the filters.

3.  **images:** Code to download iNaturalist images from URL path. In the example, observations are gathered from the iNaturalist API and images are saved with the naming scheme of observation id_photo number so that users can later link the photo to the full observation details, which is exported as a CSV.

4.  **observations:** Code to get observations using pyinaturalist library. Since this library handles batching and pagination automatically, it can be used to obtain any amount of observations. This script outputs a CSV containing observation data and selected fields.

5.  **observer-data:** Code to get information on observer from an API request. This script outputs a CSV of observation counts, species counts, observers, and observer details.

6.  **popular-field-values:** Code to get relevant controlled term values and monthly histogram of observations. This script outputs a CSV with observation counts, per-month histogram columns, and controlled attribute/value metadata.

7.  **species-counts:** Code to get a table of species counts from one URL request. This script outputs a CSV with count and taxonomic information for all species in the defined data set.

## Example R Code

This folder contains code examples to:

1.  **annotations:** Code to get observations with annotation data and extract annotations. This script outputs a CSV file in long format where there is one row per annotation, so observations with multiple annotations will have multiple rows.

2.  **identifier-data:** Code to get information on identifiers from an API request. This script outputs a CSV of identifiers and counts of identifications that match the filters.

3.  **images:** Code to download iNaturalist images from URL path. In the example, observations are gathered from the iNaturalist API and images are saved with the naming scheme of observation id_photo number so that users can later link the photo to the full observation details, which is exported as a CSV.

4.  **observations-less-than-10k:** Code to get observations from an API request with less than 10K results using pagination. This script outputs a CSV containing observation data and selected fields.

5.  **observations-more-than-10k:** Code to get observations from the API request when there are more than 10K results using batching. This script outputs a CSV containing observation data and selected fields.

6.  **observer-data:** Code to get information on observer from an API request. This script outputs a CSV of observation counts, species counts, observers, and observer details.

7.  **popular-field-values:** Code to get relevant controlled term values and monthly histogram of observations. This script outputs a CSV with observation counts, per-month histogram columns, and controlled attribute/value metadata.

8.  **species-counts:** Code to get a table of species counts from one URL request. This script outputs a CSV with count and taxonomic information for all species in the defined data set.
