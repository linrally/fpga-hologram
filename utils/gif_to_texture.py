#!/usr/bin/env python3
"""
Convert an animated GIF to texture.mem format for FPGA hologram display.

The output format is a binary file where each pixel is 24 bits (RGB).
Frames are concatenated: [frame0][frame1][frame2]...
Each frame is organized as: [LED0_cols][LED1_cols]...[LED51_cols]
Each LED has 256 columns (one per angle around the circle).

Usage:
    python gif_to_texture.py input.gif output.mem --frames 8
"""

import argparse
from PIL import Image
import numpy as np


def gif_to_texture(gif_path, output_path, num_frames, led_count=52, tex_width=256):
    """
    Convert animated GIF to texture memory file.

    Args:
        gif_path: Path to input GIF file
        output_path: Path to output .mem file
        num_frames: Number of frames to extract from GIF
        led_count: Number of LEDs (height of texture)
        tex_width: Number of columns (width of texture, angles around circle)
    """
    # Open the GIF
    gif = Image.open(gif_path)

    # Get total frames in GIF
    total_gif_frames = 0
    try:
        while True:
            gif.seek(total_gif_frames)
            total_gif_frames += 1
    except EOFError:
        pass

    print(f"GIF has {total_gif_frames} frames")
    print(f"Extracting {num_frames} frames")
    print(f"Target size: {tex_width}x{led_count} per frame")

    # Open output file
    with open(output_path, 'w') as f:
        for frame_idx in range(num_frames):
            # Calculate which GIF frame to use (loop if needed)
            gif_frame_idx = frame_idx % total_gif_frames
            gif.seek(gif_frame_idx)

            # Convert to RGB if needed
            frame = gif.convert('RGB')

            # Resize to target dimensions (tex_width x led_count)
            # Use LANCZOS for high-quality downsampling
            frame = frame.resize((tex_width, led_count), Image.Resampling.LANCZOS)

            # Convert to numpy array
            frame_array = np.array(frame)

            print(f"Processing frame {frame_idx}/{num_frames} (GIF frame {gif_frame_idx})")

            # Write frame data: for each LED (row), write all columns
            for led_num in range(led_count):
                for col in range(tex_width):
                    r, g, b = frame_array[led_num, col]

                    # Write as 24-bit binary: RRRRRRRRGGGGGGGGBBBBBBBB
                    pixel_bin = format(r, '08b') + format(g, '08b') + format(b, '08b')
                    f.write(pixel_bin + '\n')

    total_pixels = num_frames * led_count * tex_width
    print(f"\nDone! Written {total_pixels} pixels to {output_path}")
    print(f"File size: {total_pixels} lines (24 bits each)")


def main():
    parser = argparse.ArgumentParser(
        description='Convert animated GIF to FPGA texture memory format'
    )
    parser.add_argument('input', help='Input GIF file')
    parser.add_argument('output', help='Output .mem file', nargs='?', default='texture.mem')
    parser.add_argument('--frames', '-f', type=int, default=8,
                        help='Number of frames to extract (default: 8)')
    parser.add_argument('--leds', type=int, default=52,
                        help='Number of LEDs / texture height (default: 52)')
    parser.add_argument('--width', '-w', type=int, default=256,
                        help='Texture width / columns (default: 256)')

    args = parser.parse_args()

    gif_to_texture(args.input, args.output, args.frames, args.leds, args.width)


if __name__ == '__main__':
    main()
