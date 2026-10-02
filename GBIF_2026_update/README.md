# GBIF 2026 update

Working copy for the 09.10.2026 GBIF + CCH2 re-score. Do not edit older
project files for this run (`RaphanusPhenology.qmd`, `GBIF_data_combining/`,
originals in `image_handling_scripts/`).

Model: `raphanus-specimen-phenology/phenologyscoringeve-11-yolov8x-seg-t1`.

Scoring folder: `/Volumes/Radishes/GBIF_2026_update_scoring_images`.
Mount Radishes before steps 2–8.

## Run order (from project root)

Stop after step 2, check the audit, then continue. That is how previously
excluded CCH2 occid-named photos get into scoring (Excel `id` → catalogNumber
→ GBIF row).

1. `Rscript GBIF_2026_update/build_unified_occurrence.R`  
   Builds `occurrence_unified.csv`. Keeps CCH2 overlap and county-only sheets.

2. `Rscript GBIF_2026_update/build_image_id_audit.R`  
   **Pause.** Open `image_id_audit.csv` and `image_id_audit_needs_review.csv`.  
   Confirm `cch2_original` rows you want are `ok` and `selected_for_scoring`.  
   Only `ok` unique matches are copied later.

3. `Rscript GBIF_2026_update/assemble_scoring_images.R`  
   Copies selected files to the scoring folder as `{gbifID}.jpg`.

4. `Rscript GBIF_2026_update/download_new_gbif_images.R`  
   Writes `new_gbif_images_to_download.csv`. Review it, then:

5. `python3 GBIF_2026_update/gbif_image_pull_from_multimedia.py`

6. `Rscript GBIF_2026_update/update_audit_from_scoring_dir.R`  
   Adds newly downloaded files to the audit.

7. `Rscript GBIF_2026_update/resize_scoring_images.R`  
   `sips` any jpg over 20 MB to `SML_{gbifID}.jpg`.

8. `export ROBOFLOW_API_KEY="your_key"`  
   `python3 GBIF_2026_update/roboflow_to_json_parellelize.py`  
   Skips images that already have a JSON sidecar.

9. `python3 GBIF_2026_update/json_to_df.py`

10. `Rscript GBIF_2026_update/merge_counts_gbif_data.R`

## Filters

- Drop excluded `stateProvince` values (`paths.R`)
- `countryCode == "US"`, `basisOfRecord == "PRESERVED_SPECIMEN"`
- Drop only when locality, verbatimLocality, **and** county are blank
- Do **not** drop CCH2 catalog overlap; no StillImage filter

## Image matching (fail closed)

One scoring file per `gbifID`. Priority: CDA/YOSE, then SD barcodes (`SD000…`
only), then CCH2 occid filenames, then previous GBIF, then new downloads.

CCH2 filenames are occids. They join through the CCH2 Excel catalog when GBIF
has no `occid=` URL.

Do not keep gbifID-named files in the SD folder.

## Outputs

| File | Role |
| --- | --- |
| `occurrence_unified.csv` | Filtered occurrence + researched coords |
| `image_id_audit.csv` | Per-image ID check |
| `image_id_audit_needs_review.csv` | Unmatched / ambiguous |
| `new_gbif_images_to_download.csv` | URLs for step 5 |
| `gbif_repro_counts` | Counts from JSON |
| `gbif_repro_counts_merged.csv` | Analysis-ready merge |
