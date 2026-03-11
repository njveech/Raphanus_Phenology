#!/usr/bin/env python3
"""
1) Disjoint analysis: Compare CSV vs .txt for gbifID 122994729 (and optionally others),
   ignoring eventDate. Identify contiguous column regions where values don't match (disjoints).
2) Build new CSV: gbifIDs from original CSV (order preserved), row data from .txt for each ID,
   then fill missing decimalLatitude, decimalLongitude, coordinateUncertaintyInMeters from
   original CSV by matching on (locality, verbatimLocality).
"""

import csv
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ORIGINAL_TSV = os.path.join(SCRIPT_DIR, "original_gbif_download", "occurrence.txt")
ORIGINAL_CSV = os.path.join(SCRIPT_DIR, "..", "GBIF_occurance_dataset_030926.csv")
OUTPUT_CSV = os.path.join(SCRIPT_DIR, "GBIF_occurrence_fixed.csv")
DISJOINT_REPORT = os.path.join(SCRIPT_DIR, "disjoint_analysis_report.txt")


def norm(v):
    if v is None:
        return ""
    return str(v).strip()


def load_original_tsv(path):
    """Return (list of column names in order, dict gbifID -> row dict)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        cols = reader.fieldnames
        by_id = {}
        for row in reader:
            gid = norm(row.get("gbifID"))
            if gid:
                by_id[gid] = row
    return cols, by_id


def load_csv_rows(path):
    """Return (list of column names, list of row dicts)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        cols = [c for c in (reader.fieldnames or []) if c and c != "0" and not c.isdigit()]
        rows = list(reader)
    return cols, rows


def find_disjoint_regions(txt_cols, txt_row, csv_row, skip_cols=None):
    """
    Compare txt_row vs csv_row column by column (using txt_cols order).
    skip_cols: set of column names to ignore (e.g. {'eventDate'}).
    Returns list of (start_col_index, end_col_index, start_col_name, end_col_name) for disjoint regions.
    """
    skip = set(skip_cols or []) | {"eventDate"}
    match_status = []  # list of (col_name, 0=match, 1=mismatch)
    for col in txt_cols:
        if col in skip:
            match_status.append((col, 0))  # treat as match for region detection
            continue
        tv = norm(txt_row.get(col, ""))
        cv = norm(csv_row.get(col, ""))
        # Normalize for comparison: empty and "0" as equivalent
        if not tv:
            tv = ""
        if not cv or cv == "0":
            cv = ""
        match_status.append((col, 0 if tv == cv else 1))

    # Find contiguous disjoint (mismatch) regions
    regions = []
    i = 0
    while i < len(match_status):
        col_name, status = match_status[i]
        if status == 1:
            start_i = i
            start_name = col_name
            while i < len(match_status) and match_status[i][1] == 1:
                i += 1
            end_i = i
            end_name = match_status[end_i - 1][0] if end_i > start_i else start_name
            regions.append((start_i, end_i, start_name, end_name))
        else:
            i += 1
    return regions


def run_disjoint_analysis(txt_cols, txt_by_id, csv_rows):
    """Run for gbifID 122994729 and any other gbifIDs that appear in both; write report."""
    # Find CSV row by gbifID
    csv_by_id = {}
    for r in csv_rows:
        gid = norm(r.get("gbifID"))
        if gid:
            csv_by_id[gid] = r

    test_ids = ["122994729"]
    # Add a few more that are in both, if present
    for gid in list(csv_by_id.keys())[:5]:
        if gid not in test_ids and gid in txt_by_id:
            test_ids.append(gid)
            if len(test_ids) >= 4:
                break

    lines = [
        "Disjoint analysis (CSV vs original .txt)",
        "Comparing columns in .txt order; eventDate IGNORED.",
        "=" * 70,
    ]
    for gid in test_ids:
        if gid not in txt_by_id or gid not in csv_by_id:
            lines.append(f"\ngbifID {gid}: not in both files, skipping.")
            continue
        txt_row = txt_by_id[gid]
        csv_row = csv_by_id[gid]
        regions = find_disjoint_regions(txt_cols, txt_row, csv_row)
        lines.append(f"\ngbifID {gid}:")
        lines.append(f"  Number of disjoint regions: {len(regions)}")
        for idx, (start_i, end_i, start_name, end_name) in enumerate(regions):
            lines.append(f"  Region {idx + 1}: columns [{start_i}:{end_i}] from '{start_name}' through '{end_name}'")
        # Show first/last few columns that differ for first region
        if regions:
            start_i, end_i, start_name, end_name = regions[0]
            lines.append(f"  Example columns in first disjoint: {txt_cols[start_i]}, ..., {txt_cols[end_i-1]}")

    report_text = "\n".join(lines)
    with open(DISJOINT_REPORT, "w", encoding="utf-8") as out:
        out.write(report_text)
    print(report_text)
    print(f"\nDisjoint report saved to: {DISJOINT_REPORT}")
    return report_text


def build_coord_lookup(csv_rows):
    """
    Build (locality, verbatimLocality) -> (decimalLatitude, decimalLongitude, coordinateUncertaintyInMeters).
    Only include CSV rows that have at least one of lat/long non-empty.
    """
    lookup = {}
    for row in csv_rows:
        loc = norm(row.get("locality", ""))
        vloc = norm(row.get("verbatimLocality", ""))
        lat = norm(row.get("decimalLatitude", ""))
        lon = norm(row.get("decimalLongitude", ""))
        unc = norm(row.get("coordinateUncertaintyInMeters", ""))
        if not lat and not lon:
            continue
        key = (loc or "", vloc or "")
        # Prefer row that has both lat and lon
        if key not in lookup or (lat and lon):
            lookup[key] = (lat or "", lon or "", unc or "")
    return lookup


def main():
    if not os.path.isfile(ORIGINAL_TSV):
        print(f"Original TSV not found: {ORIGINAL_TSV}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(ORIGINAL_CSV):
        print(f"Original CSV not found: {ORIGINAL_CSV}", file=sys.stderr)
        sys.exit(1)

    print("Loading original occurrence.txt ...")
    txt_cols, txt_by_id = load_original_tsv(ORIGINAL_TSV)
    print(f"  Loaded {len(txt_by_id)} rows, {len(txt_cols)} columns.")

    print("Loading original CSV ...")
    csv_cols, csv_rows = load_csv_rows(ORIGINAL_CSV)
    print(f"  Loaded {len(csv_rows)} rows.")

    # --- 1) Disjoint analysis ---
    print("\n--- Disjoint analysis ---")
    run_disjoint_analysis(txt_cols, txt_by_id, csv_rows)

    # --- 2) Build new CSV ---
    print("\n--- Building new CSV ---")
    # gbifID order from CSV
    gbif_ids_from_csv = []
    for row in csv_rows:
        gid = norm(row.get("gbifID"))
        if gid:
            gbif_ids_from_csv.append(gid)

    coord_lookup = build_coord_lookup(csv_rows)
    print(f"  Coordinate lookup: {len(coord_lookup)} (locality, verbatimLocality) pairs with coords from CSV.")

    # Use only columns that exist in .txt (no extra CSV columns)
    out_cols = [c for c in txt_cols if c]
    out_rows = []
    filled_count = 0
    for gid in gbif_ids_from_csv:
        if gid not in txt_by_id:
            continue
        row = dict(txt_by_id[gid])
        # Fill missing coordinates from CSV lookup by locality/verbatimLocality
        loc = norm(row.get("locality", ""))
        vloc = norm(row.get("verbatimLocality", ""))
        key = (loc or "", vloc or "")
        if key in coord_lookup:
            lat, lon, unc = coord_lookup[key]
            need_lat = not norm(row.get("decimalLatitude")) and lat
            need_lon = not norm(row.get("decimalLongitude")) and lon
            need_unc = unc and not norm(row.get("coordinateUncertaintyInMeters"))
            if need_lat or need_lon:
                if lat:
                    row["decimalLatitude"] = lat
                if lon:
                    row["decimalLongitude"] = lon
                if need_unc and unc:
                    row["coordinateUncertaintyInMeters"] = unc
                filled_count += 1
        out_rows.append(row)

    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(out_rows)

    print(f"  Wrote {len(out_rows)} rows to {OUTPUT_CSV}")
    print(f"  Filled missing coordinates for {filled_count} rows using (locality, verbatimLocality) from original CSV.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
