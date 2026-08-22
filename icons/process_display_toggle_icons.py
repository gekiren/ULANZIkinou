import os
from PIL import Image
import numpy as np
from scipy import ndimage

src_dir = r"c:\ULANZIkinou\com.ulanzi.displaytoggle.ulanziPlugin\assets"
workspace_assets_dir = r"c:\ULANZIkinou\com.ulanzi.displaytoggle.ulanziPlugin\assets"
deploy_assets_dir = r"C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins\com.ulanzi.displaytoggle.ulanziPlugin\assets"
brain_dir = r"C:\Users\toshi\.gemini\antigravity\brain\5adada3b-9255-4bf7-b7c6-016ec7ab84d0"

os.makedirs(workspace_assets_dir, exist_ok=True)
os.makedirs(deploy_assets_dir, exist_ok=True)
os.makedirs(brain_dir, exist_ok=True)

def process_icon(src_path, thresh=100, pad_ratio=0.15):
    """Processes icon.png (switch/transfer monitor icon)"""
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    
    brightness = np.maximum(np.maximum(r, g), b)
    neon_core = (b > thresh) | (brightness > thresh + 15)
    
    h, w = neon_core.shape
    border_mask = np.zeros_like(neon_core, dtype=bool)
    border_mask[120:h-120, 100:w-100] = True
    neon_core &= border_mask
    
    labeled, num_features = ndimage.label(neon_core)
    sizes = ndimage.sum(neon_core, labeled, range(num_features + 1))
    
    major_mask = np.zeros_like(neon_core, dtype=bool)
    for i in range(1, num_features + 1):
        if sizes[i] > 2000:
            major_mask |= (labeled == i)
            
    filled = ndimage.binary_fill_holes(major_mask)
    dilated = ndimage.binary_dilation(filled, structure=np.ones((18, 18)))
    
    dist = ndimage.distance_transform_edt(dilated)
    feather = np.clip(dist / 8.0, 0, 1.0)
    
    alpha_raw = np.clip((brightness - 15.0) / (255.0 - 15.0) * 255.0 * 1.4, 0, 255)
    final_alpha = np.where(dilated, alpha_raw * feather, 0)
    final_alpha = np.clip(final_alpha, 0, 255)
    
    color_mult = np.where(final_alpha > 0, 255.0 / np.maximum(final_alpha, 35.0), 1.0)
    color_mult = np.clip(color_mult, 1.0, 1.6)
    
    r_out = np.clip(r * color_mult, 0, 255)
    g_out = np.clip(g * color_mult, 0, 255)
    b_out = np.clip(b * color_mult, 0, 255)
    
    rgba = np.dstack((r_out, g_out, b_out, final_alpha)).astype(np.uint8)
    res_img = Image.fromarray(rgba, "RGBA")
    
    alpha_ch = rgba[:, :, 3]
    y_idx, x_idx = np.where(alpha_ch > 15)
    cropped = res_img.crop((x_idx.min(), y_idx.min(), x_idx.max() + 1, y_idx.max() + 1))
    
    max_dim = max(cropped.width, cropped.height)
    target_canvas_size = int(max_dim / (1.0 - 2.0 * pad_ratio))
    square_img = Image.new("RGBA", (target_canvas_size, target_canvas_size), (0, 0, 0, 0))
    paste_x = (target_canvas_size - cropped.width) // 2
    paste_y = (target_canvas_size - cropped.height) // 2
    square_img.paste(cropped, (paste_x, paste_y), cropped)
    return square_img

def process_pc_only(src_path, pad_ratio=0.15):
    """Processes pc_only.png (single monitor icon)"""
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    
    brightness = np.maximum(np.maximum(r, g), b)
    
    # Target monitor + stand region: y: 280..720, x: 210..790
    crop_mask = np.zeros((1024, 1024), dtype=bool)
    crop_mask[280:720, 210:790] = True
    
    neon_pixels = (b > 85) & crop_mask
    filled = ndimage.binary_fill_holes(neon_pixels)
    
    dilated = ndimage.binary_dilation(filled, structure=np.ones((16, 16)))
    dist = ndimage.distance_transform_edt(dilated)
    feather = np.clip(dist / 8.0, 0, 1.0)
    
    outer_glow_alpha = np.clip((b - 15.0) / (255.0 - 15.0) * 255.0 * 1.5, 0, 255) * feather
    final_alpha = np.where(filled, 255.0, np.where(dilated, outer_glow_alpha, 0.0))
    final_alpha = np.clip(final_alpha, 0, 255)
    
    # Compensate color vibrance
    color_mult = np.where(final_alpha > 0, 255.0 / np.maximum(final_alpha, 40.0), 1.0)
    color_mult = np.clip(color_mult, 1.0, 1.5)
    
    r_out = np.clip(r * color_mult, 0, 255)
    g_out = np.clip(g * color_mult, 0, 255)
    b_out = np.clip(b * color_mult, 0, 255)
    
    rgba = np.dstack((r_out, g_out, b_out, final_alpha)).astype(np.uint8)
    res_img = Image.fromarray(rgba, "RGBA")
    
    alpha_ch = rgba[:, :, 3]
    y_idx, x_idx = np.where(alpha_ch > 20)
    cropped = res_img.crop((x_idx.min(), y_idx.min(), x_idx.max() + 1, y_idx.max() + 1))
    
    max_dim = max(cropped.width, cropped.height)
    target_canvas_size = int(max_dim / (1.0 - 2.0 * pad_ratio))
    square_img = Image.new("RGBA", (target_canvas_size, target_canvas_size), (0, 0, 0, 0))
    paste_x = (target_canvas_size - cropped.width) // 2
    paste_y = (target_canvas_size - cropped.height) // 2
    square_img.paste(cropped, (paste_x, paste_y), cropped)
    return square_img

def process_extend(src_path, pad_ratio=0.15):
    """Processes extend.png (dual extend monitor icon)"""
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    
    brightness = np.maximum(np.maximum(r, g), b)
    core = (brightness > 60) & (b > 50)
    
    h, w = core.shape
    border_mask = np.zeros_like(core, dtype=bool)
    border_mask[200:h-200, 120:w-120] = True
    core &= border_mask
    
    labeled, num_features = ndimage.label(core)
    sizes = ndimage.sum(core, labeled, range(num_features + 1))
    
    major_mask = np.zeros_like(core, dtype=bool)
    for i in range(1, num_features + 1):
        if sizes[i] > 800:
            major_mask |= (labeled == i)
            
    filled = ndimage.binary_fill_holes(major_mask)
    dilated = ndimage.binary_dilation(filled, structure=np.ones((16, 16)))
    
    dist = ndimage.distance_transform_edt(dilated)
    feather = np.clip(dist / 8.0, 0, 1.0)
    
    soft_alpha = np.clip((brightness - 15.0) / (255.0 - 15.0) * 255.0 * 1.35, 0, 255)
    final_alpha = np.where(dilated, soft_alpha * feather, 0)
    final_alpha = np.clip(final_alpha, 0, 255)
    
    color_mult = np.where(final_alpha > 0, 255.0 / np.maximum(final_alpha, 35.0), 1.0)
    color_mult = np.clip(color_mult, 1.0, 1.6)
    
    r_out = np.clip(r * color_mult, 0, 255)
    g_out = np.clip(g * color_mult, 0, 255)
    b_out = np.clip(b * color_mult, 0, 255)
    
    rgba = np.dstack((r_out, g_out, b_out, final_alpha)).astype(np.uint8)
    res_img = Image.fromarray(rgba, "RGBA")
    
    alpha_ch = rgba[:, :, 3]
    y_idx, x_idx = np.where(alpha_ch > 10)
    cropped = res_img.crop((x_idx.min(), y_idx.min(), x_idx.max() + 1, y_idx.max() + 1))
    
    max_dim = max(cropped.width, cropped.height)
    target_canvas_size = int(max_dim / (1.0 - 2.0 * pad_ratio))
    square_img = Image.new("RGBA", (target_canvas_size, target_canvas_size), (0, 0, 0, 0))
    paste_x = (target_canvas_size - cropped.width) // 2
    paste_y = (target_canvas_size - cropped.height) // 2
    square_img.paste(cropped, (paste_x, paste_y), cropped)
    return square_img

print("Processing images...")
icon_square = process_icon(os.path.join(src_dir, "icon.png"))
pc_only_square = process_pc_only(os.path.join(src_dir, "pc_only.png"))
extend_square = process_extend(os.path.join(src_dir, "extend.png"))

def save_all_formats(target_dir):
    os.makedirs(target_dir, exist_ok=True)
    # Standard Ulanzi Assets from icon_square
    icon_square.resize((144, 144), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "icon.png"), "PNG")
    icon_square.resize((232, 232), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "actionDefaultImage.png"), "PNG")
    icon_square.resize((196, 196), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "categoryIcon.png"), "PNG")
    icon_square.resize((40, 40), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "actionIcon.png"), "PNG")
    
    # State Images
    pc_only_square.resize((232, 232), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "pc_only.png"), "PNG")
    extend_square.resize((232, 232), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "extend.png"), "PNG")
    print(f"Saved all assets to: {target_dir}")

# Save to Workspace
save_all_formats(workspace_assets_dir)

# Save to Deploy directory
save_all_formats(deploy_assets_dir)

# Save preview to Brain directory for markdown display
icon_square.resize((232, 232), Image.Resampling.LANCZOS).save(os.path.join(brain_dir, "preview_icon.png"), "PNG")
pc_only_square.resize((232, 232), Image.Resampling.LANCZOS).save(os.path.join(brain_dir, "preview_pc_only.png"), "PNG")
extend_square.resize((232, 232), Image.Resampling.LANCZOS).save(os.path.join(brain_dir, "preview_extend.png"), "PNG")

print("Processing and Deployment Complete!")
