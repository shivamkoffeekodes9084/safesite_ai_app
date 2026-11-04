import os
from PIL import Image

def generate_all_icons(master_icon_path: str, project_root: str):
    print(f"Loading master icon from: {master_icon_path}")
    master = Image.open(master_icon_path).convert("RGBA")
    
    # 1. Android Mipmaps
    android_res = os.path.join(project_root, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    
    for folder, size in android_sizes.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        out_path = os.path.join(dir_path, "ic_launcher.png")
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"Generated Android {folder}/ic_launcher.png ({size}x{size})")

    # 2. iOS AppIcon.appiconset
    ios_iconset = os.path.join(project_root, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_iconset):
        ios_sizes = {
            "Icon-App-20x20@1x.png": 20,
            "Icon-App-20x20@2x.png": 40,
            "Icon-App-20x20@3x.png": 60,
            "Icon-App-29x29@1x.png": 29,
            "Icon-App-29x29@2x.png": 58,
            "Icon-App-29x29@3x.png": 87,
            "Icon-App-40x40@1x.png": 40,
            "Icon-App-40x40@2x.png": 80,
            "Icon-App-40x40@3x.png": 120,
            "Icon-App-60x60@2x.png": 120,
            "Icon-App-60x60@3x.png": 180,
            "Icon-App-76x76@1x.png": 76,
            "Icon-App-76x76@2x.png": 152,
            "Icon-App-83.5x83.5@2x.png": 167,
            "Icon-App-1024x1024@1x.png": 1024,
        }
        for name, size in ios_sizes.items():
            out_path = os.path.join(ios_iconset, name)
            resized = master.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(out_path, "PNG")
            print(f"Generated iOS {name} ({size}x{size})")

    # 3. Web Icons
    web_icons = os.path.join(project_root, "web", "icons")
    if os.path.exists(web_icons):
        for name, size in [
            ("Icon-192.png", 192),
            ("Icon-512.png", 512),
            ("Icon-maskable-192.png", 192),
            ("Icon-maskable-512.png", 512),
        ]:
            out_path = os.path.join(web_icons, name)
            resized = master.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(out_path, "PNG")
            print(f"Generated Web {name} ({size}x{size})")
        
        favicon_path = os.path.join(project_root, "web", "favicon.png")
        master.resize((32, 32), Image.Resampling.LANCZOS).save(favicon_path, "PNG")

    # 4. Save Master Copy in assets
    assets_icon_dir = os.path.join(project_root, "assets", "icon")
    os.makedirs(assets_icon_dir, exist_ok=True)
    master.save(os.path.join(assets_icon_dir, "app_icon.png"), "PNG")
    print(f"Saved master copy to assets/icon/app_icon.png")

if __name__ == "__main__":
    import sys
    icon_path = sys.argv[1] if len(sys.argv) > 1 else "assets/icon/app_icon.png"
    proj_dir = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    generate_all_icons(icon_path, proj_dir)
