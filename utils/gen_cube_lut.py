#!/usr/bin/env python3
"""
Generate precomputed lookup table for rotating wireframe cube
Creates cube.mem file with all rotation angles precomputed
"""

import math

# Parameters
TEX_WIDTH = 256   # Number of angular columns (rotation angles)
LED_COUNT = 52    # Number of LEDs on the strip
CUBE_SIZE = 0.6   # Cube size (scale factor, smaller = more visible edges)

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

def project_to_column(x, y, z):
    """
    Project 3D point to 1D column index for POV display
    Simple projection: use x coordinate (after rotation)
    Maps x from [-1, 1] to column [0, 255]
    """
    # Clamp x to [-1, 1] range
    x_clamped = max(-1.0, min(1.0, x))
    # Map [-1, 1] to [0, 255]
    col = int((x_clamped + 1.0) * 127.5)
    return max(0, min(255, col))

def draw_line_1d(framebuffer, col1, col2, brightness=255):
    """
    Draw a line in 1D framebuffer between col1 and col2
    Uses thick edges (3 columns) for low-RPM visibility
    """
    thickness = 1  # Light col±1 (3 columns total)
    start_col = min(col1, col2)
    end_col = max(col1, col2)
    
    # Light all columns in the range, plus thickness on each side
    for col in range(max(0, start_col - thickness), min(256, end_col + thickness + 1)):
        framebuffer[col] = max(framebuffer[col], brightness)

def generate_cube_column(angle):
    """
    Generate one column of the rotating cube at given angle
    Returns: column data (256 entries, one per column index)
    The cube is the same for all LEDs, so we generate one pattern per angle
    """
    # Rotate vertices
    rotated_vertices = rotate_y(vertices, angle)
    
    # Project vertices to column indices (where they appear in the 1D projection)
    projected_cols = [project_to_column(v[0], v[1], v[2]) for v in rotated_vertices]
    
    # Create column framebuffer: 256 columns (one per possible column index)
    # This represents what columns should be lit for this rotation angle
    column_fb = [0 for _ in range(TEX_WIDTH)]
    
    # Draw edges with thickness
    for v1_idx, v2_idx in edges:
        col1 = projected_cols[v1_idx]
        col2 = projected_cols[v2_idx]
        draw_line_1d(column_fb, col1, col2, brightness=255)
    
    return column_fb

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
        column_fb = generate_cube_column(angle)
        rotation_frames.append(column_fb)
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
        #   - The cube's edges project to certain column indices
        #   - We check if viewing column 'col' matches any projected edge columns
        
        for led in range(LED_COUNT):
            for col in range(TEX_WIDTH):
                # Get the rotation frame for this viewing angle
                # When viewing from angular position 'col', show cube at rotation angle 'col'
                rotation_frame = rotation_frames[col]
                
                # Check if this viewing column 'col' is lit in the rotation frame
                # rotation_frame[col] tells us if column 'col' should be lit when cube is at rotation angle 'col'
                brightness = rotation_frame[col]
                
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

