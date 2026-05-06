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
| `original_gbif_download/` | Original bulk GBIF download material (e.g. XML under `dataset/`) |
| `Datasheet_mis-sort_fix_files/` | Python scripts to fix, compare, and rebuild datasheet/GBIF-related CSVs (coordinate checks, removals, rebuilds, etc.) |
| `images/` | Image assets |
| Root CSV / XLSX / TXT | Examples: `GBIF_occurrence_fixed.csv`, `Removals_fixed_031326.csv`, `Annotated_CAS_specimen_list.xlsx`, `CCH2_2025_full_ID_list.txt`, `Redo_Climate_Specimens.csv` — plus other project spreadsheets as needed |

This list is **navigational**, not an inventory of every JSON or intermediate file.

## Version control and ignores

`.gitignore` excludes typical R/RStudio noise (e.g. `.Rhistory`, `.Rproj.user/`) and **many rendered or binary artifacts**: patterns such as `*html`, `*pdf`, `*png`, `*jpeg`, plus `climateNA_full_data_tall.csv`. It also ignores **`**/gbif_images/`** so bulk-downloaded specimen images stay local and out of GitHub.

If something expected is missing from the repo clone, check whether it is generated, ignored, or stored only locally.

### Git notes (bulk images, housekeeping, collaborators)

- **Do not commit `**/gbif_images/`** — Those folders can be gigabytes and will make `git push` hang or fail. They are gitignored; keep downloads local only.
- **`git gc --prune=now`** — Rebuilds and compresses objects under `.git` and drops unreachable history. It does **not** delete normal files in your working tree (including pictures on disk).
- **Pull blocked by `.DS_Store`** — If Git reports local changes to `.DS_Store` would be overwritten, those paths are still *tracked* (ignore rules do not apply to files already in the repo). Discard or stash them, then pull, e.g. `git restore .DS_Store Figures/.DS_Store …` (list every path Git names), then `git pull`. Long-term fix: stop tracking `.DS_Store` project-wide (`git rm` tracked `*.DS_Store`, commit, push) so macOS metadata stops causing merge noise.
