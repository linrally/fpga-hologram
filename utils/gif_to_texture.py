#!/usr/bin/env python3
"""
python gif_to_texture.py input.gif output.mem
"""

import argparse
from PIL import Image
import numpy as np


def gif_to_texture(gif_path, output_path, led_count=52, tex_width=64):
    gif = Image.open(gif_path)

    total_frames = 0
    try:
        while True:
            gif.seek(total_frames)
            total_frames += 1
    except EOFError:
        pass

    # Extract first 75 frames (5 seconds at 15 fps)
    num_frames = min(total_frames, 75)

    print(f"GIF has {total_frames} frames")
    print(f"Extracting first {num_frames} frames")
    print(f"Target size: {tex_width}x{led_count} per frame")

    # Create preview image: stack all frames vertically
    preview = Image.new("RGB", (tex_width, led_count * num_frames))

    with open(output_path, 'w') as f:
        for frame_idx in range(num_frames):
            gif.seek(frame_idx)

            frame = gif.convert('RGB')

            frame = frame.resize((tex_width, led_count), Image.Resampling.LANCZOS)

            frame = frame.transpose(Image.FLIP_TOP_BOTTOM)
            frame = frame.transpose(Image.FLIP_LEFT_RIGHT)

            frame_array = np.array(frame)

            print(f"Processing frame {frame_idx}/{num_frames}")

            for led_num in range(led_count):
                for col in range(tex_width):
                    r, g, b = frame_array[led_num, col]

                    pixel_bin = format(g, '08b') + format(r, '08b') + format(b, '08b')
                    f.write(pixel_bin + '\n')

                    # Add to preview
                    preview.putpixel((col, frame_idx * led_count + led_num), (r, g, b))

    total_pixels = num_frames * led_count * tex_width
    print(f"\nDone! Written {total_pixels} pixels to {output_path}")
    print(f"File size: {total_pixels} lines (24 bits each)")

    # Show preview
    preview.show()


def main():
    parser = argparse.ArgumentParser(
        description='Convert animated GIF to FPGA texture memory format'
    )
    parser.add_argument('input', help='Input GIF file')
    parser.add_argument('output', help='Output .mem file', nargs='?', default='texture.mem')
    parser.add_argument('--leds', type=int, default=52,
                        help='Number of LEDs / texture height (default: 52)')
    parser.add_argument('--width', '-w', type=int, default=64,
                        help='Texture width / columns (default: 64)')

    args = parser.parse_args()

    gif_to_texture(args.input, args.output, args.leds, args.width)


if __name__ == '__main__':
    main()
