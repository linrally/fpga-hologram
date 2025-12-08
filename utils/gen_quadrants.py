"""
python utils/gen.py image.png src/texture.mem
"""
from PIL import Image

TEX_WIDTH = 64
TEX_HEIGHT = 52

colors = [
    (0x00,0xFF,0x00), # Green  (quadrant 1)
    (0xFF,0x00,0x00), # Red    (quadrant 2)
    (0x00,0x00,0xFF), # Blue   (quadrant 3)
    (0xFF,0xFF,0x00), # Yellow (quadrant 4)
]

def to_bin_grb(c):
    r, g, b = c
    return f"{g:08b}{r:08b}{b:08b}"

preview = Image.new("RGB", (TEX_WIDTH, TEX_HEIGHT))

with open("src/texture.mem", "w") as f:
    for row in range(TEX_HEIGHT):
        for col in range(TEX_WIDTH):
            quad = col // (TEX_WIDTH // 4)
            f.write(to_bin_grb(colors[quad]) + "\n")

            preview.putpixel((col, row), colors[quad])

preview.show()
