#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate Ulanzi Deck Window Maximize Icons (Perfect Pixel Alignment)
- High-res vector-like rendering using Pillow with super-sampling (4x / 2048px)
- Exports into standard 4 resolutions:
  * actionDefaultImage.png (232x232)
  * categoryIcon.png (196x196)
  * icon.png (144x144)
  * actionIcon.png (40x40)
- Generates two styles:
  1. Transparent background with clean white symbol
  2. Dark framed button background (exact match with user image)
"""

import os
import math
from PIL import Image, ImageDraw

def draw_chevron_arrow(draw, start_pos, end_pos, head_size, line_width, color):
    """
    Draw arrow with line shaft and V-shaped chevron head (matching user reference).
    """
    x0, y0 = start_pos
    x1, y1 = end_pos
    
    dx = x1 - x0
    dy = y1 - y0
    angle = math.atan2(dy, dx)
    
    # Draw central shaft
    draw.line([(x0, y0), (x1, y1)], fill=color, width=int(line_width))
    
    # Chevron wings pointing outwards
    w_ang1 = angle + math.pi * 0.75
    w_ang2 = angle - math.pi * 0.75
    
    w1_x = x1 + head_size * math.cos(w_ang1)
    w1_y = y1 + head_size * math.sin(w_ang1)
    
    w2_x = x1 + head_size * math.cos(w_ang2)
    w2_y = y1 + head_size * math.sin(w_ang2)
    
    # Draw wings
    draw.line([(w1_x, w1_y), (x1, y1)], fill=color, width=int(line_width))
    draw.line([(w2_x, w2_y), (x1, y1)], fill=color, width=int(line_width))
    
    # Round caps on tips
    r_cap = line_width / 2.0
    draw.ellipse([x0 - r_cap, y0 - r_cap, x0 + r_cap, y0 + r_cap], fill=color)
    draw.ellipse([x1 - r_cap, y1 - r_cap, x1 + r_cap, y1 + r_cap], fill=color)
    draw.ellipse([w1_x - r_cap, w1_y - r_cap, w1_x + r_cap, w1_y + r_cap], fill=color)
    draw.ellipse([w2_x - r_cap, w2_y - r_cap, w2_x + r_cap, w2_y + r_cap], fill=color)

def render_master_image(style="transparent", size=2048):
    """
    Renders high-resolution master image (2048x2048)
    style: 'transparent' or 'dark_framed'
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size / 2.0
    WHITE = (255, 255, 255, 255)
    
    if style == "dark_framed":
        # Draw background dark frame like user reference
        bg_margin = size * 0.05
        bg_radius = size * 0.18
        
        # 1. Dark outer border
        draw.rounded_rectangle(
            [bg_margin, bg_margin, size - bg_margin, size - bg_margin],
            radius=bg_radius,
            fill=(28, 30, 34, 255),
            outline=(58, 62, 70, 255),
            width=int(size * 0.035)
        )
        
        # 2. Inner darker body
        inner_m = bg_margin + size * 0.025
        inner_r = bg_radius - size * 0.025
        draw.rounded_rectangle(
            [inner_m, inner_m, size - inner_m, size - inner_m],
            radius=inner_r,
            fill=(21, 23, 27, 255)
        )
    
    # --- Symbol Dimensions ---
    # Center Window Box: width ~ 41% of canvas, height ~ 34% of canvas
    win_w = size * 0.40
    win_h = size * 0.34
    win_x0 = center - win_w / 2.0
    win_y0 = center - win_h / 2.0
    win_x1 = center + win_w / 2.0
    win_y1 = center + win_h / 2.0
    win_radius = size * 0.062
    win_stroke = size * 0.036
    
    # Title bar (top portion of window, filled solid white)
    title_h = win_h * 0.33
    
    # Draw Window Lower Frame (Outline box)
    draw.rounded_rectangle(
        [win_x0, win_y0, win_x1, win_y1],
        radius=win_radius,
        fill=None,
        outline=WHITE,
        width=int(win_stroke)
    )
    
    # Draw Window Title Bar (Top filled solid white with rounded top corners)
    title_mask = Image.new("L", (size, size), 0)
    title_draw = ImageDraw.Draw(title_mask)
    
    # Draw full rounded rectangle on mask
    title_draw.rounded_rectangle(
        [win_x0, win_y0, win_x1, win_y1],
        radius=win_radius,
        fill=255
    )
    # Clip off bottom part so only top `title_h` remains
    title_draw.rectangle(
        [0, win_y0 + title_h, size, size],
        fill=0
    )
    
    # Stamp solid white using title_mask
    white_title = Image.new("RGBA", (size, size), WHITE)
    img.paste(white_title, (0, 0), title_mask)
    
    # Divider line under title bar
    draw.line(
        [(win_x0 + win_stroke * 0.3, win_y0 + title_h), (win_x1 - win_stroke * 0.3, win_y0 + title_h)],
        fill=WHITE,
        width=int(win_stroke * 0.3)
    )
    
    # --- Draw 4 Directional Arrows ---
    arrow_line_width = size * 0.038
    arrow_head_size = size * 0.105
    
    corners = [
        # NW (-1, -1)
        (math.radians(225), (-1, -1)),
        # NE (+1, -1)
        (math.radians(315), (1, -1)),
        # SE (+1, +1)
        (math.radians(45), (1, 1)),
        # SW (-1, +1)
        (math.radians(135), (-1, 1))
    ]
    
    for angle, (sx, sy) in corners:
        start_x = center + sx * (win_w * 0.5 + size * 0.045)
        start_y = center + sy * (win_h * 0.5 + size * 0.045)
        
        # End coordinates safely within the frame
        end_x = start_x + sx * (size * 0.122)
        end_y = start_y + sy * (size * 0.122)
        
        draw_chevron_arrow(
            draw=draw,
            start_pos=(start_x, start_y),
            end_pos=(end_x, end_y),
            head_size=arrow_head_size,
            line_width=arrow_line_width,
            color=WHITE
        )

    return img

def export_all_sizes(master_img, output_dir):
    """
    Exports master image into 4 standard Ulanzi Deck resolutions:
    - actionDefaultImage.png: 232x232
    - categoryIcon.png: 196x196
    - icon.png: 144x144
    - actionIcon.png: 40x40
    """
    os.makedirs(output_dir, exist_ok=True)
    
    sizes = {
        "actionDefaultImage.png": 232,
        "categoryIcon.png": 196,
        "icon.png": 144,
        "actionIcon.png": 40
    }
    
    generated_files = []
    for filename, target_dim in sizes.items():
        out_path = os.path.join(output_dir, filename)
        resized = master_img.resize((target_dim, target_dim), Image.Resampling.LANCZOS)
        resized.save(out_path, format="PNG", optimize=True)
        file_size_kb = os.path.getsize(out_path) / 1024.0
        generated_files.append((filename, target_dim, file_size_kb, out_path))
        print(f"  -> Generated: {filename} ({target_dim}x{target_dim} px, {file_size_kb:.1f} KB)")
        
    return generated_files

def main():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "window_maximize"))
    
    print("=== Generating Ulanzi Deck Window Maximize Icons (Perfect Pixel Alignment) ===")
    
    # 1. Transparent Style
    print("\n[1/2] Generating Transparent Style...")
    master_transparent = render_master_image(style="transparent", size=2048)
    trans_dir = os.path.join(base_dir, "transparent")
    export_all_sizes(master_transparent, trans_dir)
    
    # 2. Dark Framed Style (Matching User Reference)
    print("\n[2/2] Generating Dark Framed Style...")
    master_framed = render_master_image(style="dark_framed", size=2048)
    framed_dir = os.path.join(base_dir, "dark_framed")
    export_all_sizes(master_framed, framed_dir)
    
    print("\nAll assets generated successfully in:", base_dir)

if __name__ == "__main__":
    main()
