#!/usr/bin/env python3
"""Check that gbifID and state (stateProvince) in state_removals_030926.csv match occurrence.txt."""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
STATE_REMOVALS_CSV = os.path.join(BASE, "state_removals_030926.csv")
OCCURRENCE_TXT = os.path.join(BASE, "original_gbif_download", "occurrence.txt")


def norm(v):
    if v is None:
        return ""
    s = str(v).strip()
    if s == "0":
        return ""
    return s


def main():
    # Load occurrence.txt: gbifID -> stateProvince
    occ_state = {}
    with open(OCCURRENCE_TXT, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            gid = norm(row.get("gbifID"))
            if gid:
                occ_state[gid] = norm(row.get("stateProvince", ""))

    # Load state_removals
    rows = []
    with open(STATE_REMOVALS_CSV, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            rows.append(row)

    total = len(rows)
    not_in_occurrence = 0
    match = 0
    non_match = 0

    for r in rows:
        gid = norm(r.get("gbifID"))
        rem_state = norm(r.get("stateProvince", ""))
        if gid not in occ_state:
            not_in_occurrence += 1
            continue
        if occ_state[gid] == rem_state:
            match += 1
        else:
            non_match += 1

    print("state_removals_030926.csv vs occurrence.txt (gbifID + stateProvince)")
    print("=" * 55)
    print(f"Total rows in state_removals:     {total}")
    print(f"gbifID not in occurrence.txt:    {not_in_occurrence}")
    print(f"Matching state:                  {match}")
    print(f"Non-matching state:               {non_match}")


if __name__ == "__main__":
    main()
