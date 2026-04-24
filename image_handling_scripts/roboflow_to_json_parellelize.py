import json
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from inference_sdk import InferenceHTTPClient
from PIL import Image

# Do not hardcode keys in this file; export before running:
#   export ROBOFLOW_API_KEY="your_key"
API_KEY = os.environ.get("ROBOFLOW_API_KEY")
if not API_KEY:
    raise SystemExit(
        "Set ROBOFLOW_API_KEY in the environment, e.g. export ROBOFLOW_API_KEY=..."
    )

SCRIPT_DIR = Path(__file__).resolve().parent
MODEL_ID = "phenologyscoringeve/10"

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
    files = sorted(SCRIPT_DIR.glob("*.jpg"))
    if not files:
        print(f"No .jpg files in {SCRIPT_DIR}")
        return

    max_workers = min(5, len(files))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(process_image, p): p for p in files}
        for future in as_completed(futures):
            path = futures[future]
            try:
                in_name, out_name = future.result()
                print(f"Processed {in_name} -> {out_name}")
            except Exception as exc:
                print(f"FAILED {path.name}: {exc}")


if __name__ == "__main__":
    main()
