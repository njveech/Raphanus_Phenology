"""Run the 2026 Roboflow model on assembled scoring images.

Copy of image_handling_scripts/roboflow_to_json_parellelize.py with the new
MODEL_ID and scoring directory.

    export ROBOFLOW_API_KEY="your_key"
    python3 GBIF_2026_update/roboflow_to_json_parellelize.py
"""

import csv
import json
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from inference_sdk import InferenceHTTPClient
from PIL import Image

API_KEY = os.environ.get("ROBOFLOW_API_KEY")
if not API_KEY:
    raise SystemExit(
        "Set ROBOFLOW_API_KEY in the environment, e.g. export ROBOFLOW_API_KEY=..."
    )

SCORING_DIR = Path(
    os.environ.get(
        "GBIF_2026_SCORING_DIR",
        "/Volumes/Radishes/GBIF_2026_update_scoring_images",
    )
)
MODEL_ID = "raphanus-specimen-phenology/phenologyscoringeve-11-yolov8x-seg-t1"

CLIENT = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key=API_KEY,
)


def process_image(image_path: Path):
    """Run inference and save output to JSON.

    Pillow images are used on purpose: with serverless API v0 the SDK otherwise
    uses OpenCV (imread/imencode), which is not thread-safe across workers and
    can yield corrupted base64 under ThreadPoolExecutor.
    """
    with Image.open(image_path) as im:
        rgb = im.convert("RGB")
        result = CLIENT.infer(inference_input=rgb, model_id=MODEL_ID)
    out_file = image_path.with_suffix(".json")
    with open(out_file, "w") as f:
        json.dump(result, f, indent=4)
    return image_path.name, out_file.name


def main():
    files = sorted(
        p
        for p in SCORING_DIR.glob("*.jpg")
        if not p.name.startswith("._") and not p.with_suffix(".json").exists()
    )
    already = sum(
        1
        for p in SCORING_DIR.glob("*.jpg")
        if not p.name.startswith("._") and p.with_suffix(".json").exists()
    )
    if not files:
        print(f"Nothing to score in {SCORING_DIR} (already had JSON: {already})")
        return

    print(f"Scoring {len(files)} images ({already} already have JSON) in {SCORING_DIR}")
    max_workers = min(5, len(files))
    n_ok = 0
    n_fail = 0
    fail_path = Path(__file__).resolve().parent / "roboflow_failures.csv"
    write_header = not fail_path.exists()
    with fail_path.open("a", newline="") as fail_f:
        writer = csv.writer(fail_f)
        if write_header:
            writer.writerow(["filename", "error"])
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(process_image, p): p for p in files}
            for future in as_completed(futures):
                path = futures[future]
                try:
                    in_name, out_name = future.result()
                    n_ok += 1
                    print(f"Processed {in_name} -> {out_name}  [{n_ok + n_fail}/{len(files)}]")
                except Exception as exc:
                    n_fail += 1
                    print(f"FAILED {path.name}: {exc}  [{n_ok + n_fail}/{len(files)}]")
                    writer.writerow([path.name, str(exc)])
                    fail_f.flush()
    print(f"Done. ok={n_ok} failed={n_fail} skipped_existing={already}")


if __name__ == "__main__":
    main()
