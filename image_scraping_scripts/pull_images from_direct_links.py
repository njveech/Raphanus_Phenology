# pip install requests beautifulsoup4

import requests
from bs4 import BeautifulSoup
import os

# Create a folder to store downloaded images
os.makedirs("cch2_images", exist_ok=True)

# Load URLs from file
with open("specimen_urls.txt") as f:
    urls = [line.strip() for line in f if line.strip()]

for url in urls:
    try:
        # Get the HTML content of the page
        response = requests.get(url)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, 'html.parser')

        # Look for the image (usually inside <img> with id or class)
        img_tag = soup.find("img", {"id": "imgScan"})

        if img_tag and img_tag.get("src"):
            img_url = img_tag["src"]
            if img_url.startswith("/"):
                img_url = "https://cch2.org" + img_url

            # Get a unique filename
            occid = url.split('=')[-1]
            filename = f"cch2_images/{occid}.jpg"

            # Download the image
            img_data = requests.get(img_url).content
            with open(filename, 'wb') as f:
                f.write(img_data)

            print(f"Downloaded image for occid={occid}")

        else:
            print(f"No image found at {url}")

    except Exception as e:
        print(f"Error processing {url}: {e}")