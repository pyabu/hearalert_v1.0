import os
from PIL import Image

def trim_transparent(image_path):
    print(f"Processing {image_path}...")
    try:
        img = Image.open(image_path).convert("RGBA")
        # Get bounding box of non-transparent pixels
        bbox = img.getbbox()
        if bbox:
            print(f"Trimming {image_path}: bbox={bbox}")
            cropped_img = img.crop(bbox)
            cropped_img.save(image_path)
            print(f"Saved trimmed image for {image_path}")
        else:
            print(f"No content found in {image_path} that could be trimmed (image might be completely transparent or empty).")
    except Exception as e:
        print(f"Failed to trim {image_path}: {e}")

if __name__ == "__main__":
    directory = "/Users/abusaleem/hearalert-v1.1/hearalertt"
    for filename in os.listdir(directory):
        if filename.endswith(".png"):
            trim_transparent(os.path.join(directory, filename))
