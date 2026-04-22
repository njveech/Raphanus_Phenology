import glob
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from inference_sdk import InferenceHTTPClient

## Connect to Roboflow inference API
CLIENT = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="41VMwhwiEiKscncsEEHj"
)

def process_image(file):
    """Run inference and save output to JSON."""
    result = CLIENT.infer(file, model_id="phenologyscoringeve/10")
    out_file = file.rsplit(".", 1)[0] + ".json"
    with open(out_file, "w") as f:
        json.dump(result, f, indent=4)
    return file, out_file

# Get list of JPG images
files = glob.glob("*.jpg")

# Set number of workers (adjust depending on your CPU/network)
max_workers = 5

# Run in parallel
with ThreadPoolExecutor(max_workers=max_workers) as executor:
    futures = {executor.submit(process_image, file): file for file in files}
    for future in as_completed(futures):
        file, out_file = future.result()
        print(f"Processed {file} -> {out_file}")
