"""
Image URL checker for GBIF multimedia export
============================================
Reads every row from ../Output_Files/filtered_multimedia_260407.txt and checks
whether the image URL in the identifier column is reachable (HTTP GET).

Usage:
    pip install requests
    python check_cch2_images.py

Output: cch2_image_results.csv (one row per line in the multimedia file, including duplicate gbifIDs)
"""

from __future__ import annotations

import csv
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests

MULTIMEDIA_PATH = Path(__file__).resolve().parent.parent / "Output_Files" / "filtered_multimedia_260407.txt"
OUTPUT_FILE = Path(__file__).resolve().parent / "cch2_image_results.csv"

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": "https://www.gbif.org/",
})


def check_image_row(gbif_id: str, image_url: str) -> tuple[str, str, str]:
    """Return (gbif_id, image_url, status)."""
    url = (image_url or "").strip().strip('"')
    if not url or url == "NA":
        return (gbif_id, url, "No URL")

    try:
        with SESSION.get(url, timeout=25, stream=True) as resp:
            resp.raise_for_status()
            chunk = next(resp.iter_content(1024), b"")
            if not chunk:
                return (gbif_id, url, "Error: empty response body")
            return (gbif_id, url, "OK")
    except Exception as e:
        return (gbif_id, url, f"Error: {e}")


def check_indexed(item: tuple[int, str, str]) -> tuple[int, str, str, str]:
    """Return (row_index, gbif_id, image_url, status) for ordered CSV output."""
    idx, gbif_id, image_url = item
    gid, url, status = check_image_row(gbif_id, image_url)
    return (idx, gid, url, status)


def load_rows(path: Path) -> list[tuple[str, str]]:
    rows_out: list[tuple[str, str]] = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            gid = (row.get("gbifID") or "").strip()
            ident = row.get("identifier") or ""
            rows_out.append((gid, ident))
    return rows_out


def main() -> None:
    if not MULTIMEDIA_PATH.is_file():
        raise SystemExit(f"Missing multimedia file: {MULTIMEDIA_PATH}")

    rows = load_rows(MULTIMEDIA_PATH)
    total = len(rows)
    results_by_idx: list[tuple[int, str, str, str]] = []
    completed = 0

    indexed = [(i, gid, url) for i, (gid, url) in enumerate(rows)]
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(check_indexed, item): item[0] for item in indexed}
        for future in as_completed(futures):
            idx, gbif_id, image_url, status = future.result()
            results_by_idx.append((idx, gbif_id, image_url, status))
            completed += 1
            if completed % 100 == 0:
                print(f"  Progress: {completed}/{total}")

    results_by_idx.sort(key=lambda x: x[0])
    with OUTPUT_FILE.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["gbifID", "image_url", "download_status"])
        for _, gbif_id, image_url, status in results_by_idx:
            writer.writerow([gbif_id, image_url, status])

    print(f"\nDone! Wrote {total} rows to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
