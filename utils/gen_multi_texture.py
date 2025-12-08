#!/usr/bin/env python3
"""
Generate texture.mem file from multiple input images.
Concatenates images horizontally to create multiple selectable textures.

Usage:
    python utils/gen_multi_texture.py --dir images/ src/texture.mem
"""

from PIL import Image
import sys
import os
import argparse
from pathlib import Path

# Texture dimensions (128x52 as requested)
TEX_WIDTH = 128   # columns (angle resolution)
TEX_HEIGHT = 52   # rows (LED count)

def to_bin_grb(rgb):
    """Convert RGB tuple to binary GRB format (24 bits: G, R, B)."""
    r, g, b = rgb
    return f"{g:08b}{r:08b}{b:08b}"

def resize_image(img, target_width, target_height, method='fit'):
    """
    Resize image to target dimensions.
    
    Args:
        img: PIL Image
        target_width: Target width in pixels
        target_height: Target height in pixels
        method: 'fit' (maintain aspect, pad), 'crop' (maintain aspect, crop), 'stretch' (ignore aspect)
    
    Returns:
        Resized PIL Image
    """
    if method == 'stretch':
        return img.resize((target_width, target_height), Image.Resampling.LANCZOS)
    
    # Maintain aspect ratio
    img_aspect = img.width / img.height
    target_aspect = target_width / target_height
    
    if method == 'fit':
        # Fit image, pad with black
        if img_aspect > target_aspect:
            # Image is wider - fit to width
            new_width = target_width
            new_height = int(target_width / img_aspect)
        else:
            # Image is taller - fit to height
            new_height = target_height
            new_width = int(target_height * img_aspect)
        
        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        # Create black background and paste centered
        result = Image.new("RGB", (target_width, target_height), (0, 0, 0))
        x_offset = (target_width - new_width) // 2
        y_offset = (target_height - new_height) // 2
        result.paste(resized, (x_offset, y_offset))
        return result
    
    elif method == 'crop':
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

def process_images(image_files, output_file, output_preview, resize_method='fit'):
    """
    Process multiple images and create concatenated texture.mem file.
    
    Args:
        image_files: List of image file paths
        output_file: Output .mem file path
        output_preview: Output preview PNG path
        resize_method: 'fit', 'crop', or 'stretch'
    """
    if not image_files:
        print("Error: No input images provided")
        return False
    
    print(f"Processing {len(image_files)} images...")
    print(f"Target size per texture: {TEX_WIDTH}×{TEX_HEIGHT} pixels\n")
    
    # Load and resize all images
    processed_images = []
    for img_path in image_files:
        print(f"  Loading: {os.path.basename(img_path)}")
        try:
            img = Image.open(img_path).convert("RGB")
            original_size = img.size
            resized = resize_image(img, TEX_WIDTH, TEX_HEIGHT, resize_method)
            processed_images.append(resized)
            print(f"    Original: {original_size[0]}×{original_size[1]} → Resized: {resized.size[0]}×{resized.size[1]}")
        except Exception as e:
            print(f"    Error processing {img_path}: {e}")
            continue
    
    if not processed_images:
        print("Error: No images successfully processed")
        return False
    
    # Concatenate horizontally
    total_width = TEX_WIDTH * len(processed_images)
    concatenated = Image.new("RGB", (total_width, TEX_HEIGHT))
    
    for i, img in enumerate(processed_images):
        x_offset = i * TEX_WIDTH
        concatenated.paste(img, (x_offset, 0))
    
    print(f"\n✓ Concatenated texture: {total_width}×{TEX_HEIGHT} pixels")
    print(f"  {len(processed_images)} textures, each {TEX_WIDTH}×{TEX_HEIGHT}")
    
    # Save preview PNG with texture boundaries
    from PIL import ImageDraw
    preview = concatenated.copy()
    draw = ImageDraw.Draw(preview)
    # Draw white lines between textures
    for i in range(1, len(processed_images)):
        x = i * TEX_WIDTH
        draw.line([(x, 0), (x, TEX_HEIGHT)], fill=(255, 255, 255), width=2)
    
    preview.save(output_preview)
    print(f"✓ Preview saved: {output_preview}")
    
    # Write binary format (row-major order)
    # Format: Each row contains all columns for all textures
    # Address calculation: rom_addr = row * total_width + col
    # For texture selection: rom_addr = row * TEX_WIDTH + col + (texture_idx * TEX_WIDTH)
    
    print(f"\nWriting texture.mem file...")
    pixel_count = 0
    with open(output_file, "w") as f:
        for row in range(TEX_HEIGHT):
            for col in range(total_width):
                rgb = concatenated.getpixel((col, row))
                f.write(to_bin_grb(rgb) + "\n")
                pixel_count += 1
    
    print(f"✓ Successfully wrote {pixel_count} pixels to {output_file}")
    print(f"  Format: Binary GRB (24 bits per pixel, one per line)")
    print(f"  Total size: {total_width}×{TEX_HEIGHT} = {pixel_count} pixels")
    print(f"\n  Texture selection:")
    print(f"    texture_idx 0: columns 0-{TEX_WIDTH-1}")
    for i in range(1, len(processed_images)):
        start_col = i * TEX_WIDTH
        end_col = start_col + TEX_WIDTH - 1
        print(f"    texture_idx {i}: columns {start_col}-{end_col}")
    
    return True

def main():
    parser = argparse.ArgumentParser(
        description="Generate texture.mem from multiple images",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # From directory
  python utils/gen_multi_texture.py --dir images/ src/texture.mem
  
  # With crop instead of fit
  python utils/gen_multi_texture.py --dir images/ --method crop src/texture.mem
        """
    )
    
    parser.add_argument('output', help='Output .mem file path')
    parser.add_argument('--dir', required=True, help='Directory containing input images')
    parser.add_argument('--method', choices=['fit', 'crop', 'stretch'], default='fit',
                       help='Resize method: fit (pad), crop (fill), or stretch (ignore aspect)')
    parser.add_argument('--preview', help='Output preview PNG path (default: output.mem.png)')
    
    args = parser.parse_args()
    
    # Collect image files from directory
    dir_path = Path(args.dir)
    if not dir_path.is_dir():
        print(f"Error: {args.dir} is not a directory")
        return 1
    
    # Find all image files
    extensions = {'.png', '.jpg', '.jpeg', '.bmp', '.gif'}
    image_files = sorted([
        str(p) for p in dir_path.iterdir()
        if p.suffix.lower() in extensions
    ])
    
    if not image_files:
        print(f"Error: No image files found in {args.dir}")
        return 1
    
    print(f"Found {len(image_files)} images in {args.dir}")
    for img in image_files:
        print(f"  - {os.path.basename(img)}")
    print()
    
    # Determine preview output path
    if args.preview:
        preview_path = args.preview
    else:
        preview_path = args.output + ".png"
    
    # Process images
    success = process_images(
        image_files,
        args.output,
        preview_path,
        resize_method=args.method
    )
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())

