#!/usr/bin/env python3
"""Add coordinates from updated_csv_only_coordinates_for_adding_back.csv to GBIF_occurrence_fixed.csv.
   Match by (locality, verbatimLocality), not gbifID. Only use rows where match? column's first string is 'yes'.
"""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
COORDS_CSV = os.path.join(BASE, "updated_csv_only_coordinates_for_adding_back.csv")
GBIF_FIXED_CSV = os.path.join(BASE, "GBIF_occurrence_fixed.csv")


def norm(v):
    if v is None:
        return ""
    return str(v).strip()


def norm_loc(v):
    s = norm(v)
    if s == "0":
        return ""
    return s


def main():
    if not os.path.isfile(COORDS_CSV):
        print(f"Not found: {COORDS_CSV}")
        return
    if not os.path.isfile(GBIF_FIXED_CSV):
        print(f"Not found: {GBIF_FIXED_CSV}")
        return

    # Find match? column (may be "match?" or "match? " etc.)
    with open(COORDS_CSV, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        match_col = None
        for k in reader.fieldnames or []:
            if k.strip().startswith("match"):
                match_col = k
                break
        if match_col is None:
            match_col = "match?"

    # Build lookup by (locality, verbatimLocality) for rows where match? first string is "yes".
    # If the same locality key is repeated in the coords file, we keep one set of coords per key
    # (first occurrence). That set is then applied to every fixed-sheet row with that key.
    coords_by_locality = {}
    with open(COORDS_CSV, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            match_val = norm(row.get(match_col, ""))
            first_str = match_val.split(",")[0].strip().split()[0] if match_val else ""
            if first_str.lower() != "yes":
                continue
            loc = norm_loc(row.get("locality", ""))
            vloc = norm_loc(row.get("verbatimLocality", ""))
            key = (loc, vloc)
            if key not in coords_by_locality:
                coords_by_locality[key] = {
                    "decimalLatitude": norm(row.get("decimalLatitude", "")),
                    "decimalLongitude": norm(row.get("decimalLongitude", "")),
                    "coordinateUncertaintyInMeters": norm(row.get("coordinateUncertaintyInMeters", "")),
                }
    print(f"Coordinate entries (match? = yes), keyed by locality: {len(coords_by_locality)}")

    # Apply those coordinates to every row in the fixed sheet that has a matching (locality, verbatimLocality).
    # So when the same locality is repeated in the fixed sheet, all such rows get the coordinates.
    rows = []
    updated = 0
    with open(GBIF_FIXED_CSV, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            key = (norm_loc(row.get("locality", "")), norm_loc(row.get("verbatimLocality", "")))
            if key in coords_by_locality:
                c = coords_by_locality[key]
                if c["decimalLatitude"]:
                    row["decimalLatitude"] = c["decimalLatitude"]
                if c["decimalLongitude"]:
                    row["decimalLongitude"] = c["decimalLongitude"]
                if c["coordinateUncertaintyInMeters"]:
                    row["coordinateUncertaintyInMeters"] = c["coordinateUncertaintyInMeters"]
                updated += 1
            rows.append(row)

    with open(GBIF_FIXED_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

    print(f"Updated {updated} rows in GBIF_occurrence_fixed.csv with coordinates (matched by locality).")


if __name__ == "__main__":
    main()
