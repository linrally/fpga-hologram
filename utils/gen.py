from PIL import Image
import numpy as np
import sys

TEX_WIDTH = 256
TEX_HEIGHT = 52

def avg_color(img, x0, y0, x1, y1):
    region = np.array(img.crop((x0, y0, x1, y1)))
    if region.size == 0:
        return (0, 0, 0)
    return tuple(region.reshape(-1, 3).mean(axis=0).astype(int))

def to_hex_grb(rgb):
    r, g, b = rgb
    return f"{g:02X}{r:02X}{b:02X}"

def main():
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    img = Image.open(input_file).convert("RGB")
    W, H = img.size

    cell_w = W / TEX_WIDTH
    cell_h = H / TEX_HEIGHT

    preview = Image.new("RGB", (TEX_WIDTH, TEX_HEIGHT))

    with open(output_file, "w") as f:
        for row in range(TEX_HEIGHT):
            # flip vertically: logical row 0 uses bottom of the source image
            src_row = TEX_HEIGHT - 1 - row

            for col in range(TEX_WIDTH):
                src_col = TEX_WIDTH - 1 - col
                x0 = int(src_col * cell_w)
                x1 = int((src_col + 1) * cell_w)
                y0 = int(src_row * cell_h)
                y1 = int((src_row + 1) * cell_h)

                rgb = avg_color(img, x0, y0, x1, y1)
                f.write(to_hex_grb(rgb) + "\n")

                # preview in the logical (flipped) orientation
                preview.putpixel((col, row), rgb)

    preview.show()

if __name__ == "__main__":
    main()