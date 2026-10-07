"""Download images listed in GBIF_2026_update/new_gbif_images_to_download.csv.

The 09.10.2026 multimedia.txt file is column-shifted relative to its header:
the image URL is often in `references` rather than `identifier`. The R script
already resolved a single http(s) URL per gbifID into that CSV.

Run from project root after download_new_gbif_images.R:

    python3 GBIF_2026_update/gbif_image_pull_from_multimedia.py
"""

import csv
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "GBIF_2026_update" / "new_gbif_images_to_download.csv"
FAILED_PATH = ROOT / "GBIF_2026_update" / "failed_downloads.csv"

# One session so image hosts see a normal browser request.
session = requests.Session()
session.headers.update(
    {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://www.gbif.org/",
    }
)


def main():
    # The R script writes this CSV. Do not download without it.
    if not CSV_PATH.exists():
        raise SystemExit(
            f"Missing {CSV_PATH}. Run Rscript GBIF_2026_update/download_new_gbif_images.R first."
        )

    # One row per new gbifID, with image_url and dest_path already filled.
    with CSV_PATH.open(newline="") as f:
        rows = list(csv.DictReader(f))

    failed = []
    downloaded = 0
    skipped = 0

    # Skip a row with no id or URL, and skip a file that is already on disk.
    for row in rows:
        gbif_id = (row.get("gbifID") or "").strip()
        url = (row.get("image_url") or row.get("url") or "").strip().strip('"')
        dest = Path(row.get("dest_path") or "")
        if not gbif_id or not url:
            failed.append({"gbifID": gbif_id, "url": url, "error": "missing gbifID or url"})
            continue
        if not dest.parts:
            dest = Path("/Volumes/Radishes/GBIF_2026_update_scoring_images") / f"{gbif_id}.jpg"
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            skipped += 1
            continue
        # Save the image bytes. A failure is recorded and the rest of the list still runs.
        try:
            response = session.get(url, timeout=30)
            response.raise_for_status()
            dest.write_bytes(response.content)
            print(f"Downloaded {gbif_id}")
            downloaded += 1
        except Exception as exc:
            print(f"Failed {gbif_id}: {exc}")
            failed.append({"gbifID": gbif_id, "url": url, "error": str(exc)})

    # Rewrite the failure list, including a header when nothing failed.
    with FAILED_PATH.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["gbifID", "url", "error"])
        writer.writeheader()
        writer.writerows(failed)

    print(
        f"\nFinished. downloaded={downloaded} skipped_existing={skipped} "
        f"failures={len(failed)} -> {FAILED_PATH}"
    )


if __name__ == "__main__":
    main()
