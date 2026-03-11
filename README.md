# Supplemental Resources and Example Code for "Guidelines and best practices for the scientific use of global iNaturalist data"

This repository contains supplemental resources and example code for accessing iNaturalist data, as referenced in "Best Practices for Using iNaturalist Data in Scientific Research." These materials focus on retrieving data through the iNaturalist API when needed data is not available via GBIF or the iNaturalist Export Tool. 

## References

[External resources](https://github.com/brittanymmason/iNaturalist-best-practices/blob/main/Resources/External_resources.md)

[Introduction to modifying request URLs for the API](https://github.com/brittanymmason/iNaturalist-best-practices/blob/main/Resources/how_to_modify_url.md)

[Introduction on how to batch query data](https://github.com/brittanymmason/iNaturalist-best-practices/blob/main/Resources/Batch_query.md)

## Example R Code

This folder contains three code examples to:

1.  **annotations:** Code to get annotation data from an API request.

2.  **download-picture-from-url:** Code to download iNaturalist images from URL path. In the example, observations are gathered from the iNaturalist API and images are saved with the naming scheme of observation id_photo number so that users can later link the photo to the full observation details.

3.  **identifier-data:** Code to get information on identifiers from an API request.

4.  **observations-less-than-10k:** Code to get observations from an API request with less than 10K results.

5.  **observations-more-than-10k:** Code to get observations from the API request when there are more than 10K results.

6.  **observer-data:** Code to get information on observer from an API request.

7.  **popular-field-values:** Code to get relevant controlled term values and monthly histogram of observations.

8.  **species-counts:** Code to get a table of species counts from an API request.
