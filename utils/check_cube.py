#!/usr/bin/env python3
"""Quick check of cube.mem pattern"""

data = open('src/cube.mem').readlines()

print("Checking different columns (rotation angles):")
for col in [0, 32, 64, 96, 128, 160, 192, 224]:
    print(f"\nColumn {col} (angle {col*360/256:.1f}°):")
    led_data = [data[led*256 + col].strip() for led in range(52)]
    white_count = sum(1 for x in led_data if 'FFFFFF' in x)
    print(f"  White pixels: {white_count}/52")
    pattern = " ".join(["W" if "FFFFFF" in x else "." for x in led_data[20:32]])
    print(f"  LEDs 20-31: {pattern}")

