#!/usr/bin/env python3
"""
Subset Removals_030926.csv for Reason == 'Unreliable Location Data'.
- If gbifID + locality match occurrence.txt: put in Removals_fixed_031326.csv (data from occurrence.txt).
- If they don't match: search occurrence.txt for rows with that locality, output to a temp CSV for manual check.
(GBIF_occurrence_fixed.csv is kept free of removal gbifIDs via remove_gbif_ids_from_fixed.py.)
"""

import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
REMOVALS_CSV = os.path.join(BASE, "Removals_030926.csv")
OCCURRENCE_TXT = os.path.join(BASE, "original_gbif_download", "occurrence.txt")
REMOVALS_FIXED_CSV = os.path.join(BASE, "Removals_fixed_031326.csv")
TEMP_LOCALITY_CANDIDATES_CSV = os.path.join(BASE, "Removals_unreliable_locality_candidates_for_check.csv")


def norm(v):
    if v is None:
        return ""
    return str(v).strip()


def norm_loc(v):
    """Normalize locality for comparison: treat empty and '0' as equivalent."""
    s = norm(v)
    if s == "0":
        return ""
    return s


def load_occurrence_by_id(path):
    """Return (list of column names, dict gbifID -> row)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        cols = [c for c in reader.fieldnames if c]
        by_id = {}
        for row in reader:
            gid = norm(row.get("gbifID"))
            if gid:
                by_id[gid] = row
    return cols, by_id


def build_locality_index(txt_by_id):
    """(norm(locality), norm(verbatimLocality)) -> list of (gbifID, row)."""
    index = {}
    for gid, row in txt_by_id.items():
        loc = norm(row.get("locality", ""))
        vloc = norm(row.get("verbatimLocality", ""))
        key = (loc, vloc)
        index.setdefault(key, []).append((gid, row))
    return index


def main():
    if not os.path.isfile(REMOVALS_CSV):
        print("Removals CSV not found:", REMOVALS_CSV)
        return
    if not os.path.isfile(OCCURRENCE_TXT):
        print("occurrence.txt not found:", OCCURRENCE_TXT)
        return

    print("Loading occurrence.txt ...")
    occ_cols, txt_by_id = load_occurrence_by_id(OCCURRENCE_TXT)
    print(f"  Loaded {len(txt_by_id)} rows.")
    locality_index = build_locality_index(txt_by_id)

    print("Loading Removals, filtering Reason == 'Unreliable Location Data' ...")
    removal_rows = []
    with open(REMOVALS_CSV, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if norm(row.get("Reason")) == "Unreliable Location Data":
                removal_rows.append(row)
    print(f"  Found {len(removal_rows)} rows.")

    matches = []           # (removal row, occurrence row) -> go to Removals_fixed
    non_matches = []      # (removal row, occurrence row) -> locality search for temp CSV
    not_in_occurrence = []  # removal row with gbifID not in occurrence.txt

    for rem in removal_rows:
        gid = norm(rem.get("gbifID"))
        rem_loc = norm_loc(rem.get("locality", ""))
        rem_vloc = norm_loc(rem.get("verbatimLocality", ""))

        if gid not in txt_by_id:
            not_in_occurrence.append(rem)
            continue

        occ_row = txt_by_id[gid]
        occ_loc = norm_loc(occ_row.get("locality", ""))
        occ_vloc = norm_loc(occ_row.get("verbatimLocality", ""))

        # Match when: (1) removal has no locality info (blank both), or (2) locality/verbatimLocality agree
        if (not rem_loc and not rem_vloc) or (occ_loc == rem_loc and occ_vloc == rem_vloc):
            matches.append((rem, occ_row))
        else:
            non_matches.append((rem, occ_row))

    print(f"  Match (gbifID+locality): {len(matches)}")
    print(f"  No match: {len(non_matches)}")
    print(f"  gbifID not in occurrence.txt: {len(not_in_occurrence)}")

    # 1) Removals_fixed_031326.csv — occurrence columns, data from occurrence.txt for matches
    out_cols = [c for c in occ_cols if c]
    with open(REMOVALS_FIXED_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_cols, extrasaction="ignore")
        w.writeheader()
        for _rem, occ_row in matches:
            w.writerow(occ_row)
    print(f"Wrote {len(matches)} rows to {REMOVALS_FIXED_CSV}.")

    # 2) Temp CSV: for each non-match, search occurrence for rows with same (locality, verbatimLocality); output gbifID + locality data for user to check
    # Skip when both locality and verbatimLocality are empty (would match thousands of rows)
    temp_rows = []
    for rem, _occ_row in non_matches:
        rem_loc = norm(rem.get("locality", ""))
        rem_vloc = norm(rem.get("verbatimLocality", ""))
        if not rem_loc and not rem_vloc:
            temp_rows.append({
                "removal_gbifID": norm(rem.get("gbifID")),
                "removal_locality": "",
                "removal_verbatimLocality": "",
                "matched_gbifID": "",
                "locality": "",
                "verbatimLocality": "",
                "stateProvince": "",
                "county": "",
                "municipality": "",
                "decimalLatitude": "",
                "decimalLongitude": "",
                "countryCode": "",
                "note": "Removal had empty locality/verbatimLocality; search occurrence.txt manually by gbifID or other fields.",
            })
            continue
        key = (rem_loc, rem_vloc)
        if key not in locality_index:
            continue
        for gid, row in locality_index[key]:
            temp_rows.append({
                "removal_gbifID": norm(rem.get("gbifID")),
                "removal_locality": rem_loc,
                "removal_verbatimLocality": rem_vloc,
                "matched_gbifID": gid,
                "locality": norm(row.get("locality", "")),
                "verbatimLocality": norm(row.get("verbatimLocality", "")),
                "stateProvince": norm(row.get("stateProvince", "")),
                "county": norm(row.get("county", "")),
                "municipality": norm(row.get("municipality", "")),
                "decimalLatitude": norm(row.get("decimalLatitude", "")),
                "decimalLongitude": norm(row.get("decimalLongitude", "")),
                "countryCode": norm(row.get("countryCode", "")),
                "note": "",
            })
    temp_cols = ["removal_gbifID", "removal_locality", "removal_verbatimLocality", "matched_gbifID",
                 "locality", "verbatimLocality", "stateProvince", "county", "municipality",
                 "decimalLatitude", "decimalLongitude", "countryCode", "note"]
    with open(TEMP_LOCALITY_CANDIDATES_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=temp_cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(temp_rows)
    print(f"Wrote {len(temp_rows)} candidate rows to {TEMP_LOCALITY_CANDIDATES_CSV} (temporary; add back to Removals_fixed after checking).")

    if not_in_occurrence:
        print(f"Note: {len(not_in_occurrence)} removal gbifIDs were not in occurrence.txt (skipped).")


if __name__ == "__main__":
    main()
