"""Convert Roboflow JSON sidecars in the scoring folder to a counts table.

Copy of image_handling_scripts/json_to_df.py with paths for the 2026 redo.

    python3 GBIF_2026_update/json_to_df.py
"""

import json
import os
from collections import Counter
from pathlib import Path

import pandas as pd

SCORING_DIR = Path(
    os.environ.get(
        "GBIF_2026_SCORING_DIR",
        "/Volumes/Radishes/GBIF_2026_update_scoring_images",
    )
)
OUT_PATH = Path(__file__).resolve().parent / "gbif_repro_counts"

CLASS_ORDER = ["Bud Cluster", "Flower", "Fruit"]


def main():
    rows = []
    for path in sorted(SCORING_DIR.glob("*.json")):
        with path.open() as f:
            result = json.load(f)
        classes = [pred["class"] for pred in result.get("predictions", [])]
        counts = Counter(classes)
        image_id = path.stem
        if image_id.startswith("SML_"):
            image_id = image_id[len("SML_") :]
        row = {"image": image_id}
        for cls in CLASS_ORDER:
            row[cls] = counts.get(cls, 0)
        rows.append(row)

    df = pd.DataFrame(rows, columns=["image"] + CLASS_ORDER)
    df.to_csv(OUT_PATH, index=False)
    print(f"Saved {len(df)} rows to {OUT_PATH}")
    print(df)


if __name__ == "__main__":
    main()
