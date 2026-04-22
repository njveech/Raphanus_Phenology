import requests
import os
import csv

# Create folder
os.makedirs("gbif_images", exist_ok=True)

# Track failures
failed = []

# Start session (helps with some hosts)
session = requests.Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0",
    "Referer": "https://www.gbif.org/"
})

# Load file
with open("../Output_Files/filtered_multimedia_260407.txt") as f:
    header = next(f).strip().split("\t")

    gbif_idx = header.index("gbifID")
    url_idx = header.index("identifier")

    rows = [line.strip().split("\t") for line in f if line.strip()]

# Download loop
for row in rows:
    try:
        gbif_id = row[gbif_idx]
        url = row[url_idx]

        if not url or url == "NA":
            continue

        url = url.strip('"')
        filename = f"gbif_images/{gbif_id}.jpg"

        if os.path.exists(filename):
            continue

        response = session.get(url, timeout=20)
        response.raise_for_status()

        with open(filename, "wb") as img_file:
            img_file.write(response.content)

        print(f"Downloaded {gbif_id}")

    except Exception as e:
        print(f"Failed {gbif_id}: {e}")
        failed.append({
            "gbifID": gbif_id,
            "url": url,
            "error": str(e)
        })

# ✅ Write failures to CSV
with open("failed_downloads.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["gbifID", "url", "error"])
    writer.writeheader()
    writer.writerows(failed)

print(f"\nFinished. {len(failed)} failures written to failed_downloads.csv")