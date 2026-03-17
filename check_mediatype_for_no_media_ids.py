#!/usr/bin/env python3
"""Check mediaType in occurrence.txt for gbifIDs from No_Media_No_Reference_Remove_031126.csv."""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
NO_MEDIA_CSV = os.path.join(BASE, "No_Media_No_Reference_Remove_031126.csv")
OCCURRENCE_TXT = os.path.join(BASE, "original_gbif_download", "occurrence.txt")
OUTPUT_REPORT = os.path.join(BASE, "mediatype_check_report.txt")


def main():
    if not os.path.isfile(NO_MEDIA_CSV):
        print("No_Media CSV not found:", NO_MEDIA_CSV)
        return
    if not os.path.isfile(OCCURRENCE_TXT):
        print("occurrence.txt not found:", OCCURRENCE_TXT)
        return

    no_media_ids = set()
    with open(NO_MEDIA_CSV, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            gid = (row.get("gbifID") or "").strip()
            if gid:
                no_media_ids.add(gid)
    print("No_Media gbifIDs:", len(no_media_ids))

    occurrence_media = {}
    with open(OCCURRENCE_TXT, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            gid = (row.get("gbifID") or "").strip()
            if gid:
                occurrence_media[gid] = (row.get("mediaType") or "").strip()
    print("occurrence.txt rows:", len(occurrence_media))

    has_value = []
    empty = []
    missing = []
    for gid in no_media_ids:
        if gid not in occurrence_media:
            missing.append(gid)
        else:
            val = occurrence_media[gid]
            if val and val != "0":
                has_value.append((gid, val))
            else:
                empty.append(gid)

    lines = [
        "MediaType check: No_Media_No_Reference_Remove_031126.csv vs occurrence.txt",
        "",
        "Total gbifIDs in No_Media CSV: " + str(len(no_media_ids)),
        "  With non-empty mediaType in occurrence.txt: " + str(len(has_value)),
        "  With empty/zero mediaType in occurrence.txt: " + str(len(empty)),
        "  Not found in occurrence.txt: " + str(len(missing)),
        "",
    ]
    if has_value:
        lines.append("gbifIDs that HAVE mediaType in occurrence.txt (discrepancies):")
        for gid, val in sorted(has_value, key=lambda x: x[0]):
            lines.append("  " + gid + "\tmediaType=" + val)
    else:
        lines.append("All No_Media gbifIDs have empty/zero mediaType in occurrence.txt (consistent).")

    report = "\n".join(lines)
    with open(OUTPUT_REPORT, "w", encoding="utf-8") as f:
        f.write(report)
    print(report)
    print("Report written to", OUTPUT_REPORT)


if __name__ == "__main__":
    main()
