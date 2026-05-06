import glob
import json
import pandas as pd
from collections import Counter

# Desired class order
class_order = ["Bud Cluster", "Flower", "Fruit"]

rows = []

# Loop through all JSON files
for file in glob.glob("*.json"):
    with open(file, "r") as f:
        result = json.load(f)
    
    # Extract class names from predictions
    classes = [pred["class"] for pred in result.get("predictions", [])]
    
    # Count how many of each class were detected
    counts = Counter(classes)
    
    # Image ID without extension
    image_id = file.replace(".json", "")
    
    # Build row dict with all classes in fixed order
    row = {"image": image_id}
    for cls in class_order:
        row[cls] = counts.get(cls, 0)
    
    rows.append(row)

# Build DataFrame with class order
df = pd.DataFrame(rows, columns=["image"] + class_order)

# Set image as index if desired (optional)
# df = df.set_index("image")

# Save to CSV
df.to_csv("missing_inference_counts.csv", index=False)

print("Saved dataset to missing_inference_counts.csv")
print(df)

