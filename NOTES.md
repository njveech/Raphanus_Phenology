# Raphanus phenology — project notes

**NOTES.md** (this file) is the primary orientation document for humans and coding agents.

This repository supports **Raphanus** (radish) **phenology** work and **code sharing** for the EVE Summer 2025 effort (see the minimal [README.md](README.md)). The sections below document top-level layout, data locations, and version-control ignores.

## Repository structure (top level)

| Item | Role |
|------|------|
| `Raphanus_Phenology.Rproj` | RStudio project file |
| `RaphanusPhenology.qmd` | Main Quarto analysis document |
| `RaphanusPhenology_files/` | Supporting assets for `RaphanusPhenology.qmd` |
| `ClimateNA_data_pull.qmd` | Quarto document for ClimateNA data pull |
| `ClimateNA_data_pull_files/` | Supporting assets for `ClimateNA_data_pull.qmd` |
| `RScripts/` | R utilities: `GBIF_filter_dplyr.R`, `PhenologyLoadIn1.R`, `Misc.R`, `Practice1.R` |
| `Input_Files/` | Tabular and other inputs |
| `Output_Files/` | Tabular and other analysis outputs |
| `Figures/` | Figure outputs |
| `maps/` | Interactive HTML maps (California specimens by **PC1**, **PC2**, and **month**), each with companion `*_files/` directories |
| `image_handling_scripts/` | Python helpers for images (e.g. GBIF/CCH2 pulls, checks, Roboflow-related scripts) |
| `json_to_df.py` | Root Python helper for JSON → tabular conversion |
| `pull_images from_direct_links_2026.py` | Root Python helper for pulling images from direct links (filename includes a space; a copy also exists under `image_handling_scripts/`) |
| `GBIF_jsons/` | Bulk per-record JSON from GBIF |
| `CCH2_jsons_2025/` | Bulk per-record JSON from CCH2 |
| `original_gbif_download/` | Original bulk GBIF download material (e.g. XML under `dataset/`, `occurrence.txt`, `multimedia.txt`) |
| `GBIF_data_combining/` | GBIF phenology-count merge: inputs, `merge_counts_gbif_data.R`, merged outputs (see below) |
| `Datasheet_mis-sort_fix_files/` | Python scripts to fix, compare, and rebuild datasheet/GBIF-related CSVs (coordinate checks, removals, rebuilds, etc.) |
| `images/` | Image assets |
| Root CSV / XLSX / TXT | Examples: `GBIF_occurrence_fixed.csv`, `Removals_fixed_031326.csv`, `Annotated_CAS_specimen_list.xlsx`, `CCH2_2025_full_ID_list.txt`, `Redo_Climate_Specimens.csv` — plus other project spreadsheets as needed |

This list is **navigational**, not an inventory of every JSON or intermediate file.

## GBIF repro counts + occurrence merge (`GBIF_data_combining/`)

Script: [`GBIF_data_combining/merge_counts_gbif_data.R`](GBIF_data_combining/merge_counts_gbif_data.R)

Combines Roboflow/model **phenology counts** with GBIF **occurrence metadata** and optional **added coordinates**, producing one analysis-ready table for downstream R/Quarto work.

### Inputs

| File | Role |
|------|------|
| `gbif_repro_counts` | Counts per image: `image`, `Bud Cluster`, `Flower`, `Fruit` (CSV, no extension) |
| `occurrence.txt` | Tab-delimited GBIF occurrence download (Darwin Core fields) |
| `occurence_w_added_coords.csv` | Same schema as occurrence, plus manually added/fixed coordinates for some records |

### Outputs (generated; re-run script to refresh)

| File | Role |
|------|------|
| `gbif_repro_counts_merged.csv` | Main merged table |
| `gbif_repro_counts_unmatched_no_metadata.csv` | Numeric `image` IDs with **no row** in `occurrence.txt` (see matching notes) |

### How to run

From the **project root**:

```bash
Rscript GBIF_data_combining/merge_counts_gbif_data.R
```

Requires **dplyr** and **readr**.

### Matching logic

1. **Exclude unscorable images** — A fixed list of `image` IDs (roots, wrong species, etc.) is dropped before any join. Edit `unscorable_image_ids` in the script to add or remove IDs.

2. **Resolve `gbifID` from `image`** (column `image` is the specimen key used in count files):
   - **`SML_<gbifID>`** — Strip the `SML_` prefix; use the remainder as `gbifID` (same convention as [`RScripts/PhenologyLoadIn1.R`](RScripts/PhenologyLoadIn1.R)).
   - **`CDA-…` / `YOSE…`** — Treat `image` as **`catalogNumber`**, look up `gbifID` in `occurrence.txt` and `occurence_w_added_coords.csv`, then join metadata on that `gbifID`. If no catalog match, `gbifID` is left `NA` (these rows stay in output but lack occurrence fields).
   - **Plain numeric IDs** — Used directly as `gbifID`.

3. **Join occurrence fields** on resolved `gbifID`: `institutionCode`, `recordedBy`, `eventDate`, `startDayOfYear`, `endDayOfYear`, `year`, `month`, `day`, `verbatimEventDate`, `stateProvince`, `county`, `municipality`, `locality`, `decimalLatitude`, `decimalLongitude`, `coordinateUncertaintyInMeters`, `scientificName`, `specificEpithet`. Output also keeps `catalogNumber` (= `image` for catalog-style IDs).

4. **Fill coordinates** — If lat/long/`coordinateUncertaintyInMeters` are still empty after the occurrence join, fill from `occurence_w_added_coords.csv` by `gbifID`.

### “Matched” vs “unmatched” reporting

- **Matched to occurrence** means the resolved `gbifID` exists in `occurrence.txt`, **not** that `institutionCode` is populated. Some publishers (e.g. Naturalis) leave `institutionCode` blank but still provide `recordedBy`, `eventDate`, `locality`, etc.
- Console output lists all rows with **no** `occurrence.txt` match (including CDA/YOSE catalog gaps).
- `gbif_repro_counts_unmatched_no_metadata.csv` lists only **numeric** image IDs missing from `occurrence.txt` (catalog-style gaps are excluded from that file).

### Practical notes

- **CDA** catalog numbers in counts generally match `catalogNumber` in `occurrence.txt` (26 of 31 in a recent run); five CDA IDs and four **YOSE** IDs were absent from the occurrence files used here.
- **Do not** use `institutionCode` alone to judge merge success — check `recordedBy`, `eventDate`, or `scientificName` for Naturalis-style records.
- Coordinate backfill from `occurence_w_added_coords.csv` only applies where that file has non-empty coordinate fields for the `gbifID`.
- To change exclusions or add inputs, edit paths and vectors at the top of `merge_counts_gbif_data.R`.

## Version control and ignores

`.gitignore` excludes typical R/RStudio noise (e.g. `.Rhistory`, `.Rproj.user/`) and **many rendered or binary artifacts**: patterns such as `*html`, `*pdf`, `*png`, `*jpeg`, plus `climateNA_full_data_tall.csv`. It also ignores **`**/gbif_images/`** so bulk-downloaded specimen images stay local and out of GitHub.

If something expected is missing from the repo clone, check whether it is generated, ignored, or stored only locally.

### Git notes (bulk images, housekeeping, collaborators)

- **Do not commit `**/gbif_images/`** — Those folders can be gigabytes and will make `git push` hang or fail. They are gitignored; keep downloads local only.
- **`git gc --prune=now`** — Rebuilds and compresses objects under `.git` and drops unreachable history. It does **not** delete normal files in your working tree (including pictures on disk).
- **Pull blocked by `.DS_Store`** — If Git reports local changes to `.DS_Store` would be overwritten, those paths are still *tracked* (ignore rules do not apply to files already in the repo). Discard or stash them, then pull, e.g. `git restore .DS_Store Figures/.DS_Store …` (list every path Git names), then `git pull`. Long-term fix: stop tracking `.DS_Store` project-wide (`git rm` tracked `*.DS_Store`, commit, push) so macOS metadata stops causing merge noise.
