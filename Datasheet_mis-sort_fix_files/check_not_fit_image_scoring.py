#!/usr/bin/env python3
"""Count Removals with Reason 'Not fit for image scoring' that do not match occurrence.txt on locality or mediaType."""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
REMOVALS_CSV = os.path.join(BASE, "Removals_030926.csv")
OCCURRENCE_TXT = os.path.join(BASE, "original_gbif_download", "occurrence.txt")
TEMP_MISMATCHES_CSV = os.path.join(BASE, "Not_fit_image_scoring_mismatches_temp.csv")


def norm(v):
    if v is None:
        return ""
    return str(v).strip()


def norm_loc(v):
    s = norm(v)
    if s == "0":
        return ""
    return s


def norm_media(v):
    s = norm(v)
    if s == "0":
        return ""
    return s


def main():
    # Load occurrence.txt: gbifID -> locality, verbatimLocality, mediaType (and stateProvince, county for context)
    txt_by_id = {}
    with open(OCCURRENCE_TXT, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            gid = norm(row.get("gbifID"))
            if gid:
                txt_by_id[gid] = {
                    "locality": norm_loc(row.get("locality", "")),
                    "verbatimLocality": norm_loc(row.get("verbatimLocality", "")),
                    "mediaType": norm_media(row.get("mediaType", "")),
                    "stateProvince": norm(row.get("stateProvince", "")),
                    "county": norm(row.get("county", "")),
                }

    # Load Removals with Reason == "Not fit for image scoring"
    rows = []
    with open(REMOVALS_CSV, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            if norm(row.get("Reason")) == "Not fit for image scoring":
                rows.append(row)

    not_in_occurrence = 0
    match_both = 0
    non_match_locality = 0
    non_match_mediatype = 0
    non_match_both = 0
    mismatch_rows = []

    for rem in rows:
        gid = norm(rem.get("gbifID"))
        rem_loc = norm_loc(rem.get("locality", ""))
        rem_vloc = norm_loc(rem.get("verbatimLocality", ""))
        rem_media = norm_media(rem.get("mediaType", ""))

        if gid not in txt_by_id:
            not_in_occurrence += 1
            continue

        occ = txt_by_id[gid]
        occ_loc = occ["locality"]
        occ_vloc = occ["verbatimLocality"]
        occ_media = occ["mediaType"]

        loc_match = (occ_loc == rem_loc and occ_vloc == rem_vloc) or (not rem_loc and not rem_vloc)
        media_match = occ_media == rem_media

        if loc_match and media_match:
            match_both += 1
        else:
            if not loc_match and not media_match:
                non_match_both += 1
            elif not loc_match:
                non_match_locality += 1
            else:
                non_match_mediatype += 1
            mismatch_type = "both" if (not loc_match and not media_match) else ("locality_only" if not loc_match else "mediatype_only")
            mismatch_rows.append({
                "gbifID": gid,
                "mismatch_type": mismatch_type,
                "removal_locality": rem_loc,
                "removal_verbatimLocality": rem_vloc,
                "removal_mediaType": rem_media,
                "occurrence_locality": occ_loc,
                "occurrence_verbatimLocality": occ_vloc,
                "occurrence_mediaType": occ_media,
                "occurrence_stateProvince": occ.get("stateProvince", ""),
                "occurrence_county": occ.get("county", ""),
            })

    total = len(rows)
    non_match_total = non_match_locality + non_match_mediatype + non_match_both

    print("Removals with Reason == 'Not fit for image scoring' (occurrence.txt as reference)")
    print("=" * 60)
    print(f"Total rows with this reason:        {total}")
    print(f"gbifID not in occurrence.txt:       {not_in_occurrence}")
    print(f"Matching locality and mediaType:   {match_both}")
    print(f"Non-matching (locality or mediaType): {non_match_total}")
    print(f"  - locality mismatch only:         {non_match_locality}")
    print(f"  - mediaType mismatch only:        {non_match_mediatype}")
    print(f"  - both locality and mediaType:   {non_match_both}")

    if mismatch_rows:
        out_cols = ["gbifID", "mismatch_type", "removal_locality", "removal_verbatimLocality", "removal_mediaType",
                    "occurrence_locality", "occurrence_verbatimLocality", "occurrence_mediaType",
                    "occurrence_stateProvince", "occurrence_county"]
        with open(TEMP_MISMATCHES_CSV, "w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=out_cols, extrasaction="ignore")
            w.writeheader()
            w.writerows(mismatch_rows)
        print(f"\nWrote {len(mismatch_rows)} mismatch rows to {TEMP_MISMATCHES_CSV}")


if __name__ == "__main__":
    main()
