#!/usr/bin/env python3
"""
Custom texture generator for duke, globe, and gradient with specific resize methods.
"""

from PIL import Image
import os

# Texture dimensions
TEX_WIDTH = 128   # columns (angle resolution)
TEX_HEIGHT = 52   # rows (LED count)

def to_bin_grb(rgb):
    """Convert RGB tuple to binary GRB format (24 bits: G, R, B)."""
    r, g, b = rgb
    return f"{g:08b}{r:08b}{b:08b}"

def resize_gradient(img, target_width, target_height):
    """Crop gradient to fill frame."""
    img_aspect = img.width / img.height
    target_aspect = target_width / target_height
    
    # Crop to fill, maintain aspect
    if img_aspect > target_aspect:
        # Image is wider - crop width
        new_height = target_height
        new_width = int(target_height * img_aspect)
    else:
        # Image is taller - crop height
        new_width = target_width
        new_height = int(target_width / img_aspect)
    
    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    # Crop center
    x_offset = (new_width - target_width) // 2
    y_offset = (new_height - target_height) // 2
    return resized.crop((x_offset, y_offset, x_offset + target_width, y_offset + target_height))

def resize_globe(img, target_width, target_height):
    """Stretch globe to fill max horizontal direction (width to 128)."""
    # Stretch width to target_width, maintain aspect for height
    img_aspect = img.width / img.height
    new_width = target_width
    new_height = int(target_width / img_aspect)
    
    # Resize maintaining aspect
    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # If height is less than target, stretch vertically
    if new_height < target_height:
        # Stretch to fill height
        final = resized.resize((target_width, target_height), Image.Resampling.LANCZOS)
    else:
        # Crop height if needed
        y_offset = (new_height - target_height) // 2
        final = resized.crop((0, y_offset, target_width, y_offset + target_height))
    
    return final

def resize_duke(img, target_width, target_height):
    """Squeeze duke: keep horizontal shape, stretch vertically."""
    # First, scale to fit width maintaining aspect ratio (keep horizontal shape)
    img_aspect = img.width / img.height
    new_width = target_width
    new_height = int(target_width / img_aspect)  # Maintain aspect ratio
    
    # Resize maintaining horizontal aspect
    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Then stretch vertically to fill target height (this will squeeze/stretch vertically)
    final = resized.resize((target_width, target_height), Image.Resampling.LANCZOS)
    
    return final

def main():
    images_dir = "images"
    output_file = "src/texture.mem"
    preview_file = "src/texture.mem.png"
    
    print("Processing 3 textures: duke, globe, gradient\n")
    
    # Load images
    duke_path = os.path.join(images_dir, "duke.png")
    globe_path = os.path.join(images_dir, "globe.png")
    gradient_path = os.path.join(images_dir, "gradient.png")
    
    print(f"Loading duke.png...")
    duke_img = Image.open(duke_path).convert("RGB")
    print(f"  Original: {duke_img.size[0]}×{duke_img.size[1]}")
    
    print(f"Loading globe.png...")
    globe_img = Image.open(globe_path).convert("RGB")
    print(f"  Original: {globe_img.size[0]}×{globe_img.size[1]}")
    
    print(f"Loading gradient.png...")
    gradient_img = Image.open(gradient_path).convert("RGB")
    print(f"  Original: {gradient_img.size[0]}×{gradient_img.size[1]}")
    
    # Resize each image with specific method
    print(f"\nResizing images...")
    
    print(f"  Duke: stretching to fill vertical (height → {TEX_HEIGHT})")
    duke_resized = resize_duke(duke_img, TEX_WIDTH, TEX_HEIGHT)
    print(f"    Result: {duke_resized.size[0]}×{duke_resized.size[1]}")
    
    print(f"  Globe: stretching to fill horizontal (width → {TEX_WIDTH})")
    globe_resized = resize_globe(globe_img, TEX_WIDTH, TEX_HEIGHT)
    print(f"    Result: {globe_resized.size[0]}×{globe_resized.size[1]}")
    
    print(f"  Gradient: cropping to fill frame")
    gradient_resized = resize_gradient(gradient_img, TEX_WIDTH, TEX_HEIGHT)
    print(f"    Result: {gradient_resized.size[0]}×{gradient_resized.size[1]}")
    
    # Concatenate horizontally: duke, globe, gradient
    total_width = TEX_WIDTH * 3
    concatenated = Image.new("RGB", (total_width, TEX_HEIGHT))
    
    concatenated.paste(duke_resized, (0, 0))                    # Texture 0: columns 0-127
    concatenated.paste(globe_resized, (TEX_WIDTH, 0))           # Texture 1: columns 128-255
    concatenated.paste(gradient_resized, (TEX_WIDTH * 2, 0))    # Texture 2: columns 256-383
    
    print(f"\n✓ Concatenated texture: {total_width}×{TEX_HEIGHT} pixels")
    print(f"  3 textures, each {TEX_WIDTH}×{TEX_HEIGHT}")
    
    # Save preview PNG with texture boundaries
    from PIL import ImageDraw
    preview = concatenated.copy()
    draw = ImageDraw.Draw(preview)
    # Draw white lines between textures
    for i in range(1, 3):
        x = i * TEX_WIDTH
        draw.line([(x, 0), (x, TEX_HEIGHT)], fill=(255, 255, 255), width=2)
    
    preview.save(preview_file)
    print(f"✓ Preview saved: {preview_file}")
    
    # Write binary format (row-major order)
    print(f"\nWriting texture.mem file (vertical flip applied for correct display)...")
    pixel_count = 0
    with open(output_file, "w") as f:
        for row in range(TEX_HEIGHT):
            for col in range(total_width):
                # Flip vertically when writing so the display is upright
                src_row = TEX_HEIGHT - 1 - row
                rgb = concatenated.getpixel((col, src_row))
                f.write(to_bin_grb(rgb) + "\n")
                pixel_count += 1
    
    print(f"✓ Successfully wrote {pixel_count} pixels to {output_file}")
    print(f"  Format: Binary GRB (24 bits per pixel, one per line)")
    print(f"  Total size: {total_width}×{TEX_HEIGHT} = {pixel_count} pixels")
    print(f"\n  Texture selection:")
    print(f"    texture_idx 0 (Duke): columns 0-{TEX_WIDTH-1}")
    print(f"    texture_idx 1 (Globe): columns {TEX_WIDTH}-{TEX_WIDTH*2-1}")
    print(f"    texture_idx 2 (Gradient): columns {TEX_WIDTH*2}-{TEX_WIDTH*3-1}")
    
    return True

if __name__ == "__main__":
    main()

