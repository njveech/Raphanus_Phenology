# GBIF 2026 update

Redo of the GBIF + CCH2 phenology pipeline. **Do not edit older project files
for this work** (Quarto, `GBIF_data_combining/`, originals in
`image_handling_scripts/`). This folder is the working copy. Project-level
orientation, including this redo, is in [`NOTES.md`](../NOTES.md).

New Roboflow model: `raphanus-specimen-phenology/phenologyscoringeve-11-yolov8x-seg-t1`.
Re-score **all** assembled images, not only new ones.

## What this redo keeps that the old pipeline dropped

The old Quarto filter dropped GBIF rows whose `catalogNumber` was in
`CCH2_2025_full_ID_list.txt`. This unified occurrence table **keeps** that
CCH2 overlap so original CCH2-scored sheets, UCD-imaged SD sheets, and
locally photographed CDA/YOSE sheets can sit in one GBIF-keyed table.

Unmatched CCH2 / SD / CDA / YOSE rows go to `unmatched_cch2_sd_for_review.csv`
only. They are **not** appended to the analysis occurrence table.

## Run order (from project root)

1. `Rscript GBIF_2026_update/build_unified_occurrence.R`
2. `Rscript GBIF_2026_update/build_image_id_audit.R`
3. `Rscript GBIF_2026_update/assemble_scoring_images.R`
4. `Rscript GBIF_2026_update/download_new_gbif_images.R`
5. `python3 GBIF_2026_update/gbif_image_pull_from_multimedia.py`
6. `Rscript GBIF_2026_update/update_audit_from_scoring_dir.R`
7. Resize any scoring image over 20 MB (`sips --resampleWidth 5000`, `SML_` prefix).
8. `export ROBOFLOW_API_KEY=...` then `python3 GBIF_2026_update/roboflow_to_json_parellelize.py`
9. `python3 GBIF_2026_update/json_to_df.py`
10. `Rscript GBIF_2026_update/merge_counts_gbif_data.R`

Scoring images live on the Radishes drive:
`/Volumes/Radishes/GBIF_2026_update_scoring_images`.

## Filters (same as current Quarto, minus the CCH2 drop)

- Drop excluded `stateProvince` values (see `paths.R`)
- Keep `countryCode == "US"`
- Keep `basisOfRecord == "PRESERVED_SPECIMEN"`
- Drop empty locality (both `locality` and `verbatimLocality` blank)
- **No** `mediaType` / StillImage occurrence filter
- **Do not** drop CCH2 catalog overlap

## Coordinates

Researched coordinates replace GBIF-published / GeoLocate values.

Match keys, in order: (1) `gbifID`, (2) `occurrenceID`, (3)
`institutionCode` + `catalogNumber`, (4) `locality` + `verbatimLocality`.
Because `gbifID` can change between downloads, researched rows are also
joined to `original_gbif_download/occurrence.txt` to recover catalog /
occurrence IDs.

Only rows whose `match?` column **first token** is `yes` are used from
`Datasheet_mis-sort_fix_files/updated_csv_only_coordinates_for_adding_back.csv`.
CCH2 hand-assigned coordinates from `Output_Files/completed_specimen_data.csv`
are applied via occid.

## Image ID audit (fail closed)

`image_id_audit.csv` is one row per candidate scoring image. Copies and
renames happen only when `id_check_status == ok` (exactly one unified
occurrence row). Failures go to `image_id_audit_needs_review.csv`.

| `image_source` | Filename meaning | OK rule |
| --- | --- | --- |
| `cch2_original` | occid (`SML_` stripped) | occid (or catalogNumber) → exactly one new `gbifID` |
| `ucd_imaged_sd` | SD barcode | mapping occid + GBIF catalog/occid agree |
| `locally_imaged_cda_yose` | `CDA-…` / `YOSE…` catalog | catalogNumber → exactly one `gbifID` |
| `gbif_previous_download` | old `gbifID` | still in new download, or remapped via catalog (`gbifID_changed`) |
| `gbif_fresh_download` | new `gbifID` | multimedia `gbifID` = occurrence `gbifID` |

If the same specimen appears in more than one folder (91 SD files were
copied from the CCH2 originals), one scoring file is kept, preferring
local CDA/YOSE, then local SD, then CCH2 original, then previous GBIF.

## New GBIF image downloads

A specimen is **new** if it is in the unified occurrence table **and** was
not in the previous occurrence/multimedia pull, is not already on disk as
a `gbifID` jpg, and is not already covered by an OK CCH2/SD/CDA/YOSE audit
row. Previously failed URLs for **old** IDs are out of scope.

`GBIF_fresh_download_09.10.2026/multimedia.txt` is column-shifted: `type` is
a dataset UUID, `format` is StillImage, `identifier` is often empty, and the
image URL is in `references`. Scripts take the first `http(s)` URL from
`identifier` or `references`.

## Local images (already organized)

- `/Volumes/Radishes/locally_imaged_herbarium_sheets/CDA_YOSE/`
- `/Volumes/Radishes/locally_imaged_herbarium_sheets/SD/`

Do not mix those folders: CDA/YOSE filenames are catalog numbers; SD files
are barcodes. See `local_image_move_log.csv` and `sd_images_missing.csv`.

## Outputs in this folder

| File | Role |
| --- | --- |
| `occurrence_unified.csv` | Filtered 09.10.2026 occurrence + researched coords |
| `occurrence_w_added_coords.csv` | Same table (name kept for merge compatibility) |
| `cch2_gbif_crosswalk.csv` | occid / catalogNumber / gbifID |
| `unmatched_cch2_sd_for_review.csv` | Review only; not in the analysis table |
| `image_id_audit.csv` | Per-image ID check |
| `image_id_audit_needs_review.csv` | Failures / ambiguous matches |
| `new_gbif_images_to_download.csv` | New URLs for the Python puller |
| `gbif_repro_counts` | Counts from JSON (after inference) |
| `gbif_repro_counts_merged.csv` | Analysis-ready merge |
