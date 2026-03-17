#!/usr/bin/env python3
"""
Coordinate mismatch report: match rows between occurrence.txt and GBIF_occurance_dataset_030926.csv
by (locality, verbatimLocality). Output CSVs for manual checking of location vs coordinate correspondence.

Output 1 - coordinate_mismatch_for_manual_check.csv:
  A) Same location key: .txt has NO coordinates, CSV HAS coordinates (use gbifID from .txt).
  B) Same location key: .txt HAS coordinates, CSV has NO coordinates (use gbifID from .txt).

Output 2 - csv_only_coordinates_for_manual_check.csv:
  All (lat, lon) pairs that appear in the CSV but never in the .txt (canonical source).
  One row per CSV row with those coordinates, with locality columns (stateProvince, county,
  municipality, locality, verbatimLocality). Reverse-geocodes coordinates and adds an auto_check
  column (likely_match / possible_mismatch) to help prioritize manual verification.
"""

import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ORIGINAL_TSV = os.path.join(SCRIPT_DIR, "original_gbif_download", "occurrence.txt")
ORIGINAL_CSV = os.path.join(SCRIPT_DIR, "GBIF_occurance_dataset_030926.csv")
OUTPUT_CSV = os.path.join(SCRIPT_DIR, "coordinate_mismatch_for_manual_check.csv")
OUTPUT_CSV_ONLY_COORDS = os.path.join(SCRIPT_DIR, "csv_only_coordinates_for_manual_check.csv")


def norm(v):
    if v is None:
        return ""
    s = str(v).strip()
    if s == "0" and v is not None:
        try:
            if float(v) == 0:
                return ""
        except (ValueError, TypeError):
            pass
    return s


def has_coords(row, lat_key="decimalLatitude", lon_key="decimalLongitude"):
    lat = norm(row.get(lat_key, ""))
    lon = norm(row.get(lon_key, ""))
    return bool(lat and lon)


def coord_key(lat, lon):
    """Normalize (lat, lon) to a comparable tuple (6 decimal places) for set membership."""
    try:
        return (round(float(lat), 6), round(float(lon), 6))
    except (ValueError, TypeError):
        return (str(lat).strip(), str(lon).strip())


def load_txt_coord_pairs(path):
    """Return set of (lat, lon) tuples (normalized) that appear in the .txt."""
    seen = set()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            lat = norm(row.get("decimalLatitude", ""))
            lon = norm(row.get("decimalLongitude", ""))
            if lat and lon:
                seen.add(coord_key(lat, lon))
    return seen


def load_csv_rows_with_coords_only_in_csv(path, txt_coord_set):
    """
    Yield CSV rows that have both lat and lon and whose (lat, lon) is NOT in txt_coord_set.
    Each yielded dict includes locality columns: gbifID, stateProvince, county, municipality,
    locality, verbatimLocality, decimalLatitude, decimalLongitude, coordinateUncertaintyInMeters.
    """
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            lat = norm(row.get("decimalLatitude", ""))
            lon = norm(row.get("decimalLongitude", ""))
            if not lat or not lon:
                continue
            key = coord_key(lat, lon)
            if key in txt_coord_set:
                continue
            yield {
                "gbifID": norm(row.get("gbifID", "")),
                "stateProvince": norm(row.get("stateProvince", "")) or "",
                "county": norm(row.get("county", "")) or "",
                "municipality": norm(row.get("municipality", "")) or "",
                "locality": norm(row.get("locality", "")) or "",
                "verbatimLocality": norm(row.get("verbatimLocality", "")) or "",
                "decimalLatitude": lat,
                "decimalLongitude": lon,
                "coordinateUncertaintyInMeters": norm(row.get("coordinateUncertaintyInMeters", "")) or "",
            }


# Nominatim: 1 request per second for bulk. User-Agent required.
NOMINATIM_DELAY_SEC = 1.1
USER_AGENT = "RaphanusPhenology/1.0 (coordinate verification; mail optional)"


def reverse_geocode(lat, lon, cache):
    """
    Return display_name for (lat, lon) from OpenStreetMap Nominatim. Uses cache to avoid
    duplicate requests. Respects rate limit with sleep. Returns "" on error.
    """
    key = coord_key(lat, lon)
    if key in cache:
        return cache[key]
    url = f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read().decode("utf-8")
        obj = json.loads(data)
        display = (obj.get("display_name") or "").strip()
        cache[key] = display
        return display
    except (urllib.error.URLError, urllib.error.HTTPError, ValueError, KeyError) as e:
        cache[key] = ""
        return ""


def words_for_match(*parts):
    """Normalize and split non-empty parts into words (alphanumeric, len >= 2) for matching."""
    words = set()
    for p in parts:
        if not p or not isinstance(p, str):
            continue
        for w in re.split(r"[^\w]+", p.strip().lower()):
            if len(w) >= 2:
                words.add(w)
    return words


def auto_check_match(display_name, state_province, county, municipality, locality, verbatim_locality):
    """
    Return "likely_match" if reverse-geocode display_name shares meaningful words with
    locality fields; otherwise "possible_mismatch". Empty display_name -> "possible_mismatch".
    """
    if not (display_name or "").strip():
        return "possible_mismatch"
    loc_words = words_for_match(state_province, county, municipality, locality, verbatim_locality)
    if not loc_words:
        return "possible_mismatch"
    disp_lower = display_name.lower()
    matches = sum(1 for w in loc_words if w in disp_lower)
    # At least one meaningful locality word appears in the reverse-geocode result
    if matches >= 1:
        return "likely_match"
    return "possible_mismatch"


def load_txt_by_location(path):
    """Return dict: (locality, verbatimLocality) -> list of {gbifID, locality, verbatimLocality, lat, lon, unc}."""
    key_to_rows = {}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            loc = norm(row.get("locality", ""))
            vloc = norm(row.get("verbatimLocality", ""))
            key = (loc or "", vloc or "")
            gid = norm(row.get("gbifID", ""))
            if not gid:
                continue
            key_to_rows.setdefault(key, []).append({
                "gbifID": gid,
                "locality": loc or "",
                "verbatimLocality": vloc or "",
                "decimalLatitude": norm(row.get("decimalLatitude", "")),
                "decimalLongitude": norm(row.get("decimalLongitude", "")),
                "coordinateUncertaintyInMeters": norm(row.get("coordinateUncertaintyInMeters", "")),
            })
    return key_to_rows


def load_csv_by_location(path):
    """Return dict: (locality, verbatimLocality) -> list of {lat, lon, unc} and has_coords flag."""
    key_to_rows = {}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            loc = norm(row.get("locality", ""))
            vloc = norm(row.get("verbatimLocality", ""))
            key = (loc or "", vloc or "")
            key_to_rows.setdefault(key, []).append({
                "decimalLatitude": norm(row.get("decimalLatitude", "")),
                "decimalLongitude": norm(row.get("decimalLongitude", "")),
                "coordinateUncertaintyInMeters": norm(row.get("coordinateUncertaintyInMeters", "")),
            })
    return key_to_rows


def main():
    if not os.path.isfile(ORIGINAL_TSV):
        print(f"Original TSV not found: {ORIGINAL_TSV}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(ORIGINAL_CSV):
        print(f"Original CSV not found: {ORIGINAL_CSV}", file=sys.stderr)
        sys.exit(1)

    print("Loading occurrence.txt (by location key)...")
    txt_by_key = load_txt_by_location(ORIGINAL_TSV)
    print(f"  {len(txt_by_key)} unique (locality, verbatimLocality) keys.")

    print("Loading GBIF CSV (by location key)...")
    csv_by_key = load_csv_by_location(ORIGINAL_CSV)
    print(f"  {len(csv_by_key)} unique (locality, verbatimLocality) keys.")

    # Keys that appear in both
    common_keys = set(txt_by_key.keys()) & set(csv_by_key.keys())
    print(f"  {len(common_keys)} keys appear in both.")

    out_rows = []
    for key in common_keys:
        txt_list = txt_by_key[key]
        csv_list = csv_by_key[key]
        csv_has_any = any(has_coords(r) for r in csv_list)
        csv_missing_any = any(not has_coords(r) for r in csv_list)
        # Representative CSV row with coords / without coords for display
        csv_row_with = next((r for r in csv_list if has_coords(r)), None)
        csv_row_without = next((r for r in csv_list if not has_coords(r)), None)

        for tr in txt_list:
            txt_has = has_coords(tr)
            # A) .txt has NO coords, CSV HAS coords
            if not txt_has and csv_has_any and csv_row_with:
                out_rows.append({
                    "gbifID": tr["gbifID"],
                    "locality": tr["locality"],
                    "verbatimLocality": tr["verbatimLocality"],
                    "mismatch_type": "txt_no_coords_csv_has_coords",
                    "decimalLatitude_txt": tr["decimalLatitude"],
                    "decimalLongitude_txt": tr["decimalLongitude"],
                    "coordinateUncertaintyInMeters_txt": tr["coordinateUncertaintyInMeters"],
                    "decimalLatitude_csv": csv_row_with["decimalLatitude"],
                    "decimalLongitude_csv": csv_row_with["decimalLongitude"],
                    "coordinateUncertaintyInMeters_csv": csv_row_with["coordinateUncertaintyInMeters"],
                })
            # B) .txt HAS coords, CSV has NO coords
            elif txt_has and csv_missing_any and csv_row_without is not None:
                out_rows.append({
                    "gbifID": tr["gbifID"],
                    "locality": tr["locality"],
                    "verbatimLocality": tr["verbatimLocality"],
                    "mismatch_type": "txt_has_coords_csv_no_coords",
                    "decimalLatitude_txt": tr["decimalLatitude"],
                    "decimalLongitude_txt": tr["decimalLongitude"],
                    "coordinateUncertaintyInMeters_txt": tr["coordinateUncertaintyInMeters"],
                    "decimalLatitude_csv": csv_row_without["decimalLatitude"],
                    "decimalLongitude_csv": csv_row_without["decimalLongitude"],
                    "coordinateUncertaintyInMeters_csv": csv_row_without["coordinateUncertaintyInMeters"],
                })

    fieldnames = [
        "gbifID", "locality", "verbatimLocality", "mismatch_type",
        "decimalLatitude_txt", "decimalLongitude_txt", "coordinateUncertaintyInMeters_txt",
        "decimalLatitude_csv", "decimalLongitude_csv", "coordinateUncertaintyInMeters_csv",
    ]
    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(out_rows)

    print(f"\nWrote {len(out_rows)} mismatch rows to {OUTPUT_CSV}")

    # --- CSV-only coordinates: (lat, lon) in CSV but not in .txt ---
    print("\n--- CSV-only coordinates (in CSV but not in .txt) ---")
    txt_coord_set = load_txt_coord_pairs(ORIGINAL_TSV)
    print(f"  Coordinate pairs in .txt: {len(txt_coord_set)}")

    csv_only_rows = list(load_csv_rows_with_coords_only_in_csv(ORIGINAL_CSV, txt_coord_set))
    unique_pairs = len(set((r["decimalLatitude"], r["decimalLongitude"]) for r in csv_only_rows))

    # Reverse-geocode each unique (lat, lon) and set auto_check for each row (1 req/sec for Nominatim)
    geocode_cache = {}
    for row in csv_only_rows:
        lat, lon = row["decimalLatitude"], row["decimalLongitude"]
        key = coord_key(lat, lon)
        if key not in geocode_cache:
            if geocode_cache:
                time.sleep(NOMINATIM_DELAY_SEC)
            reverse_geocode(lat, lon, geocode_cache)
        display = geocode_cache.get(key, "")
        row["reverse_geocode_display_name"] = display or ""
        row["auto_check"] = auto_check_match(
            display,
            row.get("stateProvince", ""),
            row.get("county", ""),
            row.get("municipality", ""),
            row.get("locality", ""),
            row.get("verbatimLocality", ""),
        )

    csv_only_fieldnames = [
        "gbifID", "stateProvince", "county", "municipality", "locality", "verbatimLocality",
        "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters",
        "reverse_geocode_display_name", "auto_check",
    ]
    with open(OUTPUT_CSV_ONLY_COORDS, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=csv_only_fieldnames)
        w.writeheader()
        w.writerows(csv_only_rows)

    likely = sum(1 for r in csv_only_rows if r.get("auto_check") == "likely_match")
    print(f"  CSV rows with coordinates not in .txt: {len(csv_only_rows)} (unique coord pairs: {unique_pairs})")
    print(f"  Reverse-geocode: {likely} likely_match, {len(csv_only_rows) - likely} possible_mismatch")
    print(f"  Wrote reduced CSV to {OUTPUT_CSV_ONLY_COORDS}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
