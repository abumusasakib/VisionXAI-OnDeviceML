import urllib.request
import os

font_dir = r"d:\courses\graduate project\xai new project\codeocean project\capsule-5653931\environment\fonts"
os.makedirs(font_dir, exist_ok=True)

urls = {
    "NotoSansBengali-Regular.ttf": "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansBengali/NotoSansBengali-Regular.ttf",
    "NotoSansBengali-Bold.ttf": "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansBengali/NotoSansBengali-Bold.ttf"
}

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

for font_name, url in urls.items():
    dest = os.path.join(font_dir, font_name)
    print(f"Downloading {font_name} from {url}...")
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            with open(dest, 'wb') as out_file:
                out_file.write(response.read())
        print(f"Successfully downloaded {font_name}")
    except Exception as e:
        print(f"Failed to download {font_name}: {e}")
