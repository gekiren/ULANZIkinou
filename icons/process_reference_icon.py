import os
from PIL import Image
import numpy as np

# Load source image
src_path = r"C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea\.user_uploaded\media_1787428071880.jpg"
img = Image.open(src_path).convert("RGBA")

# Extract RGBA numpy array
arr = np.array(img, dtype=np.float32)
r, g, b, _ = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]

# Black background extraction:
# Background is dark around rgb(10-15, 10-15, 10-15).
# Brightness = max(r, g, b)
brightness = np.maximum(np.maximum(r, g, b), 0)

# Black threshold cutoff around 16
black_floor = 18.0
alpha = np.clip((brightness - black_floor) / (255.0 - black_floor) * 255.0 * 1.3, 0, 255)

# Boost color vibrance to compensate for alpha blending
color_mult = np.where(alpha > 0, 255.0 / np.maximum(alpha, 30.0), 1.0)
color_mult = np.clip(color_mult, 1.0, 1.8)

r_out = np.clip(r * color_mult, 0, 255)
g_out = np.clip(g * color_mult, 0, 255)
b_out = np.clip(b * color_mult, 0, 255)

rgba_out = np.dstack((r_out, g_out, b_out, alpha)).astype(np.uint8)
transparent_img = Image.fromarray(rgba_out, "RGBA")

# Crop tight bounding box with comfortable padding
bbox = transparent_img.getbbox()
cropped = transparent_img.crop(bbox)

# Make square with padding
max_dim = max(cropped.width, cropped.height)
# Add 12% padding for stream deck button
target_dim = int(max_dim * 1.25)
square_img = Image.new("RGBA", (target_dim, target_dim), (0, 0, 0, 0))
paste_x = (target_dim - cropped.width) // 2
paste_y = (target_dim - cropped.height) // 2
square_img.paste(cropped, (paste_x, paste_y), cropped)

def save_resized(out_path, size):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    res = square_img.resize((size, size), Image.Resampling.LANCZOS)
    res.save(out_path, "PNG")
    print(f"Saved: {out_path} ({size}x{size})")

# Target directories
assets_dir = r"C:\ULANZIkinou\com.ulanzi.pcsleep.ulanziPlugin\assets"
deploy_dir = r"C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins\com.ulanzi.pcsleep.ulanziPlugin\assets"
preview_dir = r"C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"

for target_dir in [assets_dir, deploy_dir]:
    save_resized(os.path.join(target_dir, "icon.png"), 144)
    save_resized(os.path.join(target_dir, "actionDefaultImage.png"), 232)
    save_resized(os.path.join(target_dir, "categoryIcon.png"), 196)
    save_resized(os.path.join(target_dir, "actionIcon.png"), 40)

save_resized(os.path.join(preview_dir, "exact_reference_sleep_icon.png"), 232)
