#!/usr/bin/env python3
"""
Compare GBIF_occurance_dataset_030926.csv to original_gbif_download/occurrence.txt.
Finds rows where later columns in the CSV do not match the original data for that gbifID
(e.g. due to Excel sort misaligning columns). Outputs mismatch report and row numbers.
"""

import csv
import os
import sys

# Paths (relative to this script's directory)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ORIGINAL_TSV = os.path.join(SCRIPT_DIR, "original_gbif_download", "occurrence.txt")
FILTERED_CSV = os.path.join(SCRIPT_DIR, "..", "GBIF_occurance_dataset_030926.csv")
OUTPUT_REPORT = os.path.join(SCRIPT_DIR, "gbif_mismatch_report.txt")


def normalize(val):
    """Treat empty, None, and '0' (for missing) as equivalent for comparison."""
    if val is None:
        return ""
    s = str(val).strip()
    if s == "" or s == "0":
        return ""
    return s


def load_original_by_gbifid(path):
    """Load original TSV and return dict: gbifID -> {col: value, ...}."""
    by_id = {}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            gid = row.get("gbifID", "").strip()
            if gid:
                by_id[gid] = {k: v for k, v in row.items()}
    return by_id


def main():
    if not os.path.isfile(ORIGINAL_TSV):
        print(f"Original not found: {ORIGINAL_TSV}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(FILTERED_CSV):
        print(f"Filtered CSV not found: {FILTERED_CSV}", file=sys.stderr)
        sys.exit(1)

    print("Loading original occurrence.txt ...")
    original = load_original_by_gbifid(ORIGINAL_TSV)
    print(f"  Loaded {len(original)} rows keyed by gbifID.")

    # Columns to compare (only those present in original; skip ref_link_ID etc. in CSV)
    sample_key = next(iter(original.values()))
    compare_cols = [c for c in sample_key.keys() if c == c and c != ""]

    mismatches = []  # list of (csv_1based_row, gbifID, list of (col, csv_val, orig_val))

    print("Comparing filtered CSV to original ...")
    with open(FILTERED_CSV, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        csv_cols = reader.fieldnames or []
        for one_based_row_num, row in enumerate(reader, start=2):  # row 1 is header
            if one_based_row_num % 500 == 0:
                print(f"  ... checked {one_based_row_num - 1} rows, {len(mismatches)} mismatches so far")
            gid = (row.get("gbifID") or "").strip()
            if not gid:
                continue
            orig_row = original.get(gid)
            if orig_row is None:
                mismatches.append((one_based_row_num, gid, [("__NOT_IN_ORIGINAL__", gid, "")]))
                continue
            diffs = []
            for col in compare_cols:
                if col not in row:
                    continue
                csv_val = normalize(row[col])
                orig_val = normalize(orig_row.get(col, ""))
                if csv_val != orig_val:
                    diffs.append((col, row[col], orig_row.get(col, "")))
            if diffs:
                mismatches.append((one_based_row_num, gid, diffs))

    # Report
    lines = [
        "GBIF CSV vs original occurrence.txt — mismatch report",
        "=" * 60,
        f"Total CSV data rows checked: {one_based_row_num - 1}",
        f"Rows with one or more column mismatches (or gbifID not in original): {len(mismatches)}",
        "",
    ]

    # Summary: row numbers only
    row_numbers = [m[0] for m in mismatches]
    lines.append("Row numbers (in CSV, 1-based including header) where later columns do not match original:")
    lines.append("  " + ", ".join(map(str, row_numbers)))
    lines.append("")

    # Detail per row
    lines.append("Details (CSV row, gbifID, column, CSV value, original value):")
    lines.append("-" * 60)
    for one_based_row, gid, diffs in mismatches:
        if diffs[0][0] == "__NOT_IN_ORIGINAL__":
            lines.append(f"  Row {one_based_row}: gbifID {gid} — NOT FOUND in original.")
        else:
            lines.append(f"  Row {one_based_row}: gbifID {gid} — {len(diffs)} column(s) differ:")
            for col, csv_val, orig_val in diffs[:20]:  # first 20 diffs per row
                csv_short = (csv_val[:50] + "…") if len(str(csv_val)) > 50 else csv_val
                orig_short = (str(orig_val)[:50] + "…") if len(str(orig_val)) > 50 else orig_val
                lines.append(f"      {col}: CSV={repr(csv_short)}  ORIG={repr(orig_short)}")
            if len(diffs) > 20:
                lines.append(f"      ... and {len(diffs) - 20} more columns")
        lines.append("")

    report_text = "\n".join(lines)
    with open(OUTPUT_REPORT, "w", encoding="utf-8") as out:
        out.write(report_text)
    print(report_text)
    print(f"Report saved to: {OUTPUT_REPORT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
