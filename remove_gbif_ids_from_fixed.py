#!/usr/bin/env python3
"""Remove from GBIF_occurrence_fixed.csv any gbifID that appears in Removals_030926.csv or state_removals_030926.csv."""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
REMOVALS_CSV = os.path.join(BASE, "Removals_030926.csv")
STATE_REMOVALS_CSV = os.path.join(BASE, "state_removals_030926.csv")
GBIF_FIXED_CSV = os.path.join(BASE, "GBIF_occurrence_fixed.csv")


def norm(v):
    if v is None:
        return ""
    return str(v).strip()


def main():
    # Collect all gbifIDs from both removal files
    removal_ids = set()
    for path in (REMOVALS_CSV, STATE_REMOVALS_CSV):
        if not os.path.isfile(path):
            print(f"Skip (not found): {path}")
            continue
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for row in csv.DictReader(f):
                gid = norm(row.get("gbifID"))
                if gid:
                    removal_ids.add(gid)
    print(f"gbifIDs to exclude (from Removals + state_removals): {len(removal_ids)}")

    # Read GBIF_occurrence_fixed.csv, keep only rows whose gbifID is NOT in removal_ids
    if not os.path.isfile(GBIF_FIXED_CSV):
        print(f"Not found: {GBIF_FIXED_CSV}")
        return
    kept = []
    removed_count = 0
    with open(GBIF_FIXED_CSV, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            gid = norm(row.get("gbifID"))
            if gid in removal_ids:
                removed_count += 1
            else:
                kept.append(row)

    with open(GBIF_FIXED_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(kept)

    print(f"Removed {removed_count} rows from GBIF_occurrence_fixed.csv")
    print(f"Remaining rows: {len(kept)}")


if __name__ == "__main__":
    main()
