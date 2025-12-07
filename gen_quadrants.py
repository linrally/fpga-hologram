# gen_quadrants.py
TEX_WIDTH = 256
TEX_HEIGHT = 52

colors = [
    (0x00,0xFF,0x00), # Green  (quadrant 1)
    (0xFF,0x00,0x00), # Red    (quadrant 2)
    (0x00,0x00,0xFF), # Blue   (quadrant 3)
    (0xFF,0xFF,0x00), # Yellow (quadrant 4)
]

def to_hex_grb(c):
    g, r, b = c
    return f"{g:02X}{r:02X}{b:02X}"

with open("texture.mem", "w") as f:
    for row in range(TEX_HEIGHT):
        for col in range(TEX_WIDTH):
            quad = col // (TEX_WIDTH // 4)
            f.write(to_hex_grb(colors[quad]) + "\n")
