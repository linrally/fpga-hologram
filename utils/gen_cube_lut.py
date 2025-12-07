#!/usr/bin/env python3
"""
Generate precomputed lookup table for rotating wireframe cube
Creates cube.mem file with all rotation angles precomputed
"""

import math

# Parameters
TEX_WIDTH = 256   # Number of angular columns (rotation angles)
LED_COUNT = 52    # Number of LEDs on the strip
CUBE_SIZE = 0.8   # Cube size (scale factor, larger = more visible)

# Cube vertices (8 corners) - scaled by CUBE_SIZE
vertices = [
    [ CUBE_SIZE,  CUBE_SIZE,  CUBE_SIZE],  # 0
    [ CUBE_SIZE,  CUBE_SIZE, -CUBE_SIZE],  # 1
    [ CUBE_SIZE, -CUBE_SIZE,  CUBE_SIZE],  # 2
    [ CUBE_SIZE, -CUBE_SIZE, -CUBE_SIZE],  # 3
    [-CUBE_SIZE,  CUBE_SIZE,  CUBE_SIZE],  # 4
    [-CUBE_SIZE,  CUBE_SIZE, -CUBE_SIZE],  # 5
    [-CUBE_SIZE, -CUBE_SIZE,  CUBE_SIZE],  # 6
    [-CUBE_SIZE, -CUBE_SIZE, -CUBE_SIZE],  # 7
]

# Cube edges (12 edges connecting vertices)
edges = [
    (0, 1), (0, 2), (0, 4),  # From vertex 0
    (1, 3), (1, 5),          # From vertex 1
    (2, 3), (2, 6),          # From vertex 2
    (3, 7),                  # From vertex 3
    (4, 5), (4, 6),          # From vertex 4
    (5, 7),                  # From vertex 5
    (6, 7),                  # From vertex 6
]

def rotate_y(vertices, angle):
    """Rotate vertices around Y-axis"""
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    rotated = []
    for v in vertices:
        x, y, z = v
        # Rotation matrix: [cos 0 sin; 0 1 0; -sin 0 cos]
        x_new = x * cos_a + z * sin_a
        y_new = y
        z_new = -x * sin_a + z * cos_a
        rotated.append([x_new, y_new, z_new])
    return rotated

def project_to_2d(x, y, z):
    """
    Project 3D point to 2D (column, LED) for POV display
    - Column (X): based on x coordinate after rotation, maps to [0, 255]
    - LED (Y): based on y coordinate, maps to [0, LED_COUNT-1]
    """
    # Project X to column
    x_clamped = max(-1.0, min(1.0, x))
    col = int((x_clamped + 1.0) * 127.5)
    col = max(0, min(255, col))
    
    # Project Y to LED index
    # Map y from [-CUBE_SIZE, CUBE_SIZE] to [0, LED_COUNT-1]
    # Center the cube vertically
    y_normalized = (y + CUBE_SIZE) / (2 * CUBE_SIZE)  # [0, 1]
    led = int(y_normalized * (LED_COUNT - 1))
    led = max(0, min(LED_COUNT - 1, led))
    
    return col, led

def draw_line_2d(framebuffer, x1, y1, x2, y2):
    """
    Draw a line in 2D framebuffer using Bresenham's line algorithm
    Ensures all pixels along the line are drawn
    """
    # Convert to integers
    x1, y1, x2, y2 = int(round(x1)), int(round(y1)), int(round(x2)), int(round(y2))
    
    # Clamp to framebuffer bounds
    x1 = max(0, min(TEX_WIDTH - 1, x1))
    y1 = max(0, min(LED_COUNT - 1, y1))
    x2 = max(0, min(TEX_WIDTH - 1, x2))
    y2 = max(0, min(LED_COUNT - 1, y2))
    
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = 1 if x1 < x2 else -1
    sy = 1 if y1 < y2 else -1
    err = dx - dy
    
    x, y = x1, y1
    
    while True:
        # Set pixel
        framebuffer[y][x] = 255
        
        # Also set adjacent pixels for thickness (makes edges more visible)
        if x > 0:
            framebuffer[y][x-1] = max(framebuffer[y][x-1], 255)
        if x < TEX_WIDTH - 1:
            framebuffer[y][x+1] = max(framebuffer[y][x+1], 255)
        if y > 0:
            framebuffer[y-1][x] = max(framebuffer[y-1][x], 255)
        if y < LED_COUNT - 1:
            framebuffer[y+1][x] = max(framebuffer[y+1][x], 255)
        
        if x == x2 and y == y2:
            break
        
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy

def generate_cube_frame(angle):
    """
    Generate a 2D framebuffer for the rotating cube at given angle
    Returns: 2D array [LED_COUNT][TEX_WIDTH] indicating which pixels should be lit
    """
    # Rotate vertices
    rotated_vertices = rotate_y(vertices, angle)
    
    # Project all vertices to 2D (col, led)
    # Use floating point for more precision
    projected_2d = []
    for v in rotated_vertices:
        x, y, z = v[0], v[1], v[2]
        # Project X to column (floating point)
        x_clamped = max(-1.0, min(1.0, x))
        col = (x_clamped + 1.0) * 127.5
        
        # Project Y to LED (floating point)
        y_normalized = (y + CUBE_SIZE) / (2 * CUBE_SIZE)  # [0, 1]
        led = y_normalized * (LED_COUNT - 1)
        
        projected_2d.append((col, led))
    
    # Create 2D framebuffer: LED_COUNT rows × TEX_WIDTH columns
    framebuffer = [[0 for _ in range(TEX_WIDTH)] for _ in range(LED_COUNT)]
    
    # Draw edges using Bresenham line algorithm
    for v1_idx, v2_idx in edges:
        col1, led1 = projected_2d[v1_idx]
        col2, led2 = projected_2d[v2_idx]
        draw_line_2d(framebuffer, col1, led1, col2, led2)
    
    return framebuffer

def main():
    output_file = "src/cube.mem"
    
    print(f"Generating precomputed cube LUT...")
    print(f"  Angles: {TEX_WIDTH}")
    print(f"  LEDs: {LED_COUNT}")
    print(f"  Total entries: {TEX_WIDTH * LED_COUNT}")
    
    # Precompute all rotation frames
    print("  Precomputing rotation frames...")
    rotation_frames = []
    for angle_idx in range(TEX_WIDTH):
        angle = (angle_idx / TEX_WIDTH) * 2 * math.pi
        frame_2d = generate_cube_frame(angle)
        rotation_frames.append(frame_2d)
        if (angle_idx + 1) % 64 == 0:
            print(f"    Computed {angle_idx + 1}/{TEX_WIDTH} frames...")
    
    with open(output_file, "w") as f:
        # Memory layout: LED-major order
        # Address = LED * TEX_WIDTH + column
        # So we write: LED 0 (all columns), LED 1 (all columns), ..., LED 51 (all columns)
        #
        # For address = LED * 256 + col:
        #   - 'col' is the angular viewing position (0-255)
        #   - We show the cube rotated by angle = col * 2π / 256
        #   - rotation_frames[col] is a 2D array [LED_COUNT][TEX_WIDTH]
        #   - rotation_frames[col][led][col] tells us if pixel (led, col) should be lit
        
        for led in range(LED_COUNT):
            for col in range(TEX_WIDTH):
                # Get the rotation frame for this viewing angle
                # When viewing from angular position 'col', show cube at rotation angle 'col'
                frame_2d = rotation_frames[col]
                
                # Check if this (LED, column) pixel is lit in the rotation frame
                brightness = frame_2d[led][col]
                
                # Convert to RGB (white for edges, black for background)
                if brightness > 0:
                    # Full white for maximum visibility
                    r, g, b = 255, 255, 255
                else:
                    # Black background
                    r, g, b = 0, 0, 0
                
                # Write in GRB format (WS2812 order)
                # Format: GGRRBB (24-bit, 6 hex digits)
                f.write(f"{g:02X}{r:02X}{b:02X}\n")
            
            if (led + 1) % 10 == 0:
                print(f"  Generated {led + 1}/{LED_COUNT} LEDs...")
    
    print(f"Done! Generated {output_file}")
    print(f"  File size: {TEX_WIDTH * LED_COUNT} lines")
    print(f"  Format: GRB (24-bit RGB per pixel)")

if __name__ == "__main__":
    main()

