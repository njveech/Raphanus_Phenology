#!/usr/bin/env python3
"""
Build No_Media_No_Reference_Remove_fixed_031326.csv: the 377 gbifIDs with empty mediaType
in occurrence.txt, with full row data from occurrence.txt.
"""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
NO_MEDIA_CSV = os.path.join(BASE, "No_Media_No_Reference_Remove_031126.csv")
OCCURRENCE_TXT = os.path.join(BASE, "original_gbif_download", "occurrence.txt")
OUTPUT_CSV = os.path.join(BASE, "No_Media_No_Reference_Remove_fixed_031326.csv")


def norm(v):
    return "" if v is None else str(v).strip()


def main():
    # Load occurrence.txt: columns + gbifID -> row
    with open(OCCURRENCE_TXT, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        cols = reader.fieldnames
        txt_by_id = {norm(r.get("gbifID")): r for r in reader if norm(r.get("gbifID"))}

    # Which No_Media gbifIDs have empty mediaType in occurrence?
    no_media_ids = set()
    with open(NO_MEDIA_CSV, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            no_media_ids.add(norm(row.get("gbifID")))

    empty_media_ids = []
    for gid in no_media_ids:
        if gid not in txt_by_id:
            continue
        val = norm(txt_by_id[gid].get("mediaType"))
        if not val or val == "0":
            empty_media_ids.append(gid)

    # Preserve order: same as in occurrence.txt (or sort for reproducibility)
    empty_media_ids.sort(key=lambda x: int(x) if x.isdigit() else 0)

    out_cols = [c for c in cols if c]
    out_rows = [txt_by_id[gid] for gid in empty_media_ids if gid in txt_by_id]

    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(out_rows)

    print(f"Wrote {len(out_rows)} rows to {OUTPUT_CSV}")


if __name__ == "__main__":
    main()
