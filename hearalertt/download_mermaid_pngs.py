import base64
import zlib
import urllib.request
import os
import glob

def render_kroki(diagram_text, filename):
    try:
        compressed = zlib.compress(diagram_text.encode('utf-8'), 9)
        encoded = base64.urlsafe_b64encode(compressed).decode('utf-8')
        url = f"https://kroki.io/mermaid/png/{encoded}"
        print(f"Downloading {filename} from {url}...")
        
        req = urllib.request.Request(
            url, 
            data=None, 
            headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.47 Safari/537.36'
            }
        )
        with urllib.request.urlopen(req) as response, open(filename, 'wb') as out_file:
            data = response.read()
            out_file.write(data)
        print(f"Successfully downloaded {filename}")
    except Exception as e:
        print(f"Failed to download {filename}: {e}")

if __name__ == "__main__":
    mmd_files = glob.glob("*.mmd")
    for file in mmd_files:
        with open(file, 'r') as f:
            content = f.read()
        
        output_filename = file.replace('.mmd', '.png')
        render_kroki(content, output_filename)
