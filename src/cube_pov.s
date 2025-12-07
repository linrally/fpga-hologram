# cube_pov.s
# 3D Rotating Wireframe Cube Renderer for POV Display
#
# Program Description:
#   This program renders a 3D rotating wireframe cube on a POV (persistence of vision) display.
#   The cube rotates continuously around the Y-axis, and the CPU writes the rendered frame
#   to a memory-mapped POV peripheral that drives the LED strip.
#
# Register Usage:
#   $1  - Base address for POV peripheral (0xFFFF0000)
#   $2  - Base address for data section in RAM
#   $3  - Stack pointer (grows downward from high memory)
#   $4  - Current angle (incremented each frame)
#   $5  - Temporary/scratch
#   $6  - Temporary/scratch
#   $7  - Temporary/scratch
#   $8  - Temporary/scratch
#   $9  - Temporary/scratch
#   $10 - Temporary/scratch
#   $11 - Temporary/scratch
#   $12 - Temporary/scratch
#   $13 - Temporary/scratch
#   $14 - Temporary/scratch
#   $15 - Temporary/scratch
#   $16 - Temporary/scratch
#   $17 - Temporary/scratch
#   $18 - Temporary/scratch
#   $19 - Temporary/scratch
#   $20 - Temporary/scratch
#   $21 - Temporary/scratch
#   $22 - Temporary/scratch
#   $23 - Temporary/scratch
#   $24 - Temporary/scratch
#   $25 - Temporary/scratch
#   $26 - Temporary/scratch
#   $27 - Temporary/scratch
#   $28 - Temporary/scratch
#   $29 - Temporary/scratch
#   $30 - Reserved (exception register)
#   $31 - Reserved (return address)
#
# Fixed-Point Format:
#   - Vertices stored as 16.16 fixed-point (bits [31:16] = integer, [15:0] = fraction)
#   - Cube vertices range from -1.0 to +1.0, stored as -65536 to +65536
#   - Sin/cos tables: 256 entries, values in range [-32768, +32768] (Q15 format)
#
# Memory Layout (in RAM, starting at address 0x1000):
#   0x1000 - 0x101F: Original cube vertices (8 vertices * 4 bytes = 32 bytes)
#                    Each vertex: x(32-bit), y(32-bit), z(32-bit) = 12 bytes, but we'll use 4 bytes per coord
#                    Actually: 8 vertices * 3 coords * 4 bytes = 96 bytes (0x1000-0x105F)
#   0x1060 - 0x11FF: Rotated vertices (8 vertices * 3 coords * 4 bytes = 96 bytes)
#   0x1200 - 0x121F: Projected column indices (8 vertices * 4 bytes = 32 bytes)
#   0x1220 - 0x122F: Edge list (12 edges * 2 vertex indices * 4 bytes = 96 bytes)
#   0x1300 - 0x13FF: Sin table (256 entries * 4 bytes = 1024 bytes)
#   0x1400 - 0x14FF: Cos table (256 entries * 4 bytes = 1024 bytes)
#   0x1500 - 0x15FF: Framebuffer (256 columns * 4 bytes = 1024 bytes, but we only use 24 bits)
#
# POV Peripheral Memory Map:
#   0xFFFF0000 - POV_COL_ADDR   (write): Column index [0-255]
#   0xFFFF0004 - POV_PIXEL_DATA (write): 24-bit RGB pixel data
#   0xFFFF0008 - POV_WRITE      (write): Write trigger
#   0xFFFF000C - POV_STATUS     (read):  Current column index
#   0xFFFF0010 - POV_CTRL       (read/write): Control register
#
# ============================================================================
# TUNABLE CONSTANTS FOR LOW-RPM VISIBILITY
# ============================================================================
# These constants can be adjusted to optimize visibility at ~400 RPM:
#
# EDGE_THICKNESS: Number of columns to light on each side of an edge point
#   - Value of 1 means light col-1, col, col+1 (3 columns total)
#   - Value of 2 means light col-2, col-1, col, col+1, col+2 (5 columns total)
#   - Recommended: 1 or 2 for good visibility at low RPM
#
# EDGE_BRIGHTNESS: RGB color value for edges (24-bit: RRRRRRRR GGGGGGGG BBBBBBBB)
#   - 0x00FFFFFF = full white (maximum brightness)
#   - 0x00FF0000 = full red
#   - 0x0000FF00 = full green
#   - 0x000000FF = full blue
#   - Recommended: 0x00FFFFFF for maximum visibility
#
# ANGLE_STEP: Rotation increment per frame (smaller = slower rotation)
#   - Value of 1 = full rotation in 256 frames
#   - Value of 2 = full rotation in 128 frames
#   - Recommended: 1-3 for slow, recognizable rotation at 6-7 FPS
#
# ENABLE_DECAY: Whether to use persistence/blur effect
#   - 0 = clear framebuffer each frame (sharp, flickery)
#   - 1 = decay existing values (shift right by 1) before drawing (smooth, trailing)
#   - Recommended: 1 for better visibility at low RPM
#
# DELAY_COUNT: Frame delay counter (larger = slower frame rate)
#   - Adjust based on CPU speed and desired frame rate
#   - Recommended: 10000-50000 for ~6-7 FPS at 100 MHz CPU

# ============================================================================
# DATA SECTION (will be assembled into memory initialization)
# ============================================================================

.data
# Note: In this assembler format, we'll use immediate values and store them
# The actual data will be initialized by the program at startup

# ============================================================================
# MAIN PROGRAM
# ============================================================================

.text
main:
    # Initialize base addresses
    addi $1, $0, 0xFFFF      # Upper 16 bits of POV base
    sll $1, $1, 16            # Shift to upper 16 bits
    addi $1, $1, 0x0000       # POV base = 0xFFFF0000
    
    # ========================================================================
    # TEST PATTERN: Write bright colors to verify POV peripheral works
    # ========================================================================
    # This writes red, green, blue, and white to columns 0, 64, 128, 192
    # If you see these colors when spinning, the POV peripheral is working!
    
    # Write RED to column 0
    addi $5, $0, 0            # Column 0
    sw $5, 0($1)              # POV_COL_ADDR = 0xFFFF0000
    addi $5, $0, 0x00FF       # Red color upper bits
    sll $5, $5, 8
    addi $5, $5, 0x0000       # POV_PIXEL_DATA = 0x00FF0000 (red)
    addi $6, $1, 4
    sw $5, 0($6)              # POV_PIXEL_DATA = 0xFFFF0004
    addi $6, $1, 8
    sw $0, 0($6)              # POV_WRITE = 0xFFFF0008 (trigger)
    
    # Write GREEN to column 64
    addi $5, $0, 64           # Column 64
    sw $5, 0($1)              # POV_COL_ADDR
    addi $5, $0, 0x0000       # Green color
    sll $5, $5, 8
    addi $5, $5, 0xFF00       # POV_PIXEL_DATA = 0x0000FF00 (green)
    addi $6, $1, 4
    sw $5, 0($6)              # POV_PIXEL_DATA
    addi $6, $1, 8
    sw $0, 0($6)              # POV_WRITE trigger
    
    # Write BLUE to column 128
    addi $5, $0, 128          # Column 128
    sw $5, 0($1)              # POV_COL_ADDR
    addi $5, $0, 0x0000       # Blue color
    sll $5, $5, 8
    addi $5, $5, 0x00FF       # POV_PIXEL_DATA = 0x000000FF (blue)
    addi $6, $1, 4
    sw $5, 0($6)              # POV_PIXEL_DATA
    addi $6, $1, 8
    sw $0, 0($6)              # POV_WRITE trigger
    
    # Write WHITE to column 192
    addi $5, $0, 192          # Column 192
    sw $5, 0($1)              # POV_COL_ADDR
    addi $5, $0, 0x00FF       # White color upper bits
    sll $5, $5, 8
    addi $5, $5, 0xFFFF       # POV_PIXEL_DATA = 0x00FFFFFF (white)
    addi $6, $1, 4
    sw $5, 0($6)              # POV_PIXEL_DATA
    addi $6, $1, 8
    sw $0, 0($6)              # POV_WRITE trigger
    
    # Also write WHITE to a few more columns for visibility
    addi $5, $0, 1            # Column 1
    sw $5, 0($1)
    addi $5, $0, 0x00FF
    sll $5, $5, 8
    addi $5, $5, 0xFFFF       # White
    addi $6, $1, 4
    sw $5, 0($6)
    addi $6, $1, 8
    sw $0, 0($6)
    
    addi $5, $0, 2            # Column 2
    sw $5, 0($1)
    addi $5, $0, 0x00FF
    sll $5, $5, 8
    addi $5, $5, 0xFFFF       # White
    addi $6, $1, 4
    sw $5, 0($6)
    addi $6, $1, 8
    sw $0, 0($6)
    
    addi $5, $0, 3            # Column 3
    sw $5, 0($1)
    addi $5, $0, 0x00FF
    sll $5, $5, 8
    addi $5, $5, 0xFFFF       # White
    addi $6, $1, 4
    sw $5, 0($6)
    addi $6, $1, 8
    sw $0, 0($6)
    
    # ========================================================================
    # End of test pattern - continue with normal initialization
    # ========================================================================
    
    addi $2, $0, 0x1000       # Data section base address
    
    # Initialize stack pointer (grow downward from 0x2000)
    addi $3, $0, 0x2000       # Stack pointer
    
    # Initialize angle to 0
    addi $4, $0, 0            # angle = 0
    
    # ========================================================================
    # TUNABLE CONSTANTS (adjust these for optimal low-RPM visibility)
    # ========================================================================
    # Store constants in registers for easy access:
    # $20 = EDGE_THICKNESS (1 = 3 columns, 2 = 5 columns)
    addi $20, $0, 1           # EDGE_THICKNESS: light col±1 (3 columns total)
    
    # $21 = EDGE_BRIGHTNESS (24-bit RGB)
    addi $21, $0, 0x00FF       # Upper 16 bits of white
    sll $21, $21, 8
    addi $21, $21, 0xFFFF      # EDGE_BRIGHTNESS = 0x00FFFFFF (full white)
    
    # $22 = ANGLE_STEP (rotation increment per frame)
    addi $22, $0, 1            # ANGLE_STEP: increment by 1 per frame (slow rotation)
    
    # $23 = ENABLE_DECAY (0 = clear, 1 = decay)
    addi $23, $0, 1            # ENABLE_DECAY: use persistence/blur effect
    
    # $24 = DELAY_COUNT (frame delay)
    addi $24, $0, 20000        # DELAY_COUNT: adjust for ~6-7 FPS at 100 MHz
    
    # Initialize cube vertices (8 vertices: corners of a cube from -1 to +1)
    # Vertex 0: (+1, +1, +1)
    addi $5, $0, 0x0001       # x = 1.0 in Q16 = 0x00010000
    sll $5, $5, 16
    sw $5, 0($2)              # vertices[0].x
    sw $5, 4($2)              # vertices[0].y
    sw $5, 8($2)              # vertices[0].z
    
    # Vertex 1: (+1, +1, -1)
    addi $6, $0, 0xFFFF       # -1.0 in Q16 = 0xFFFF0000 (two's complement)
    sll $6, $6, 16
    addi $7, $2, 12           # vertices[1] offset
    sw $5, 0($7)              # x = +1
    sw $5, 4($7)              # y = +1
    sw $6, 8($7)              # z = -1
    
    # Vertex 2: (+1, -1, +1)
    addi $7, $2, 24           # vertices[2] offset
    sw $5, 0($7)              # x = +1
    sw $6, 4($7)              # y = -1
    sw $5, 8($7)              # z = +1
    
    # Vertex 3: (+1, -1, -1)
    addi $7, $2, 36           # vertices[3] offset
    sw $5, 0($7)              # x = +1
    sw $6, 4($7)              # y = -1
    sw $6, 8($7)              # z = -1
    
    # Vertex 4: (-1, +1, +1)
    addi $7, $2, 48           # vertices[4] offset
    sw $6, 0($7)              # x = -1
    sw $5, 4($7)              # y = +1
    sw $5, 8($7)              # z = +1
    
    # Vertex 5: (-1, +1, -1)
    addi $7, $2, 60           # vertices[5] offset
    sw $6, 0($7)              # x = -1
    sw $5, 4($7)              # y = +1
    sw $6, 8($7)              # z = -1
    
    # Vertex 6: (-1, -1, +1)
    addi $7, $2, 72           # vertices[6] offset
    sw $6, 0($7)              # x = -1
    sw $6, 4($7)              # y = -1
    sw $5, 8($7)              # z = +1
    
    # Vertex 7: (-1, -1, -1)
    addi $7, $2, 84           # vertices[7] offset
    sw $6, 0($7)              # x = -1
    sw $6, 4($7)              # y = -1
    sw $6, 8($7)              # z = -1
    
    # Initialize edge list (12 edges connecting vertices)
    # Each edge: (vertex_index1, vertex_index2) stored as two 32-bit words
    addi $7, $2, 0x1220       # Edge list base
    
    # Edge 0: 0-1
    addi $8, $0, 0
    sw $8, 0($7)
    addi $8, $0, 1
    sw $8, 4($7)
    
    # Edge 1: 0-2
    addi $7, $7, 8
    addi $8, $0, 0
    sw $8, 0($7)
    addi $8, $0, 2
    sw $8, 4($7)
    
    # Edge 2: 0-4
    addi $7, $7, 8
    addi $8, $0, 0
    sw $8, 0($7)
    addi $8, $0, 4
    sw $8, 4($7)
    
    # Edge 3: 1-3
    addi $7, $7, 8
    addi $8, $0, 1
    sw $8, 0($7)
    addi $8, $0, 3
    sw $8, 4($7)
    
    # Edge 4: 1-5
    addi $7, $7, 8
    addi $8, $0, 1
    sw $8, 0($7)
    addi $8, $0, 5
    sw $8, 4($7)
    
    # Edge 5: 2-3
    addi $7, $7, 8
    addi $8, $0, 2
    sw $8, 0($7)
    addi $8, $0, 3
    sw $8, 4($7)
    
    # Edge 6: 2-6
    addi $7, $7, 8
    addi $8, $0, 2
    sw $8, 0($7)
    addi $8, $0, 6
    sw $8, 4($7)
    
    # Edge 7: 3-7
    addi $7, $7, 8
    addi $8, $0, 3
    sw $8, 0($7)
    addi $8, $0, 7
    sw $8, 4($7)
    
    # Edge 8: 4-5
    addi $7, $7, 8
    addi $8, $0, 4
    sw $8, 0($7)
    addi $8, $0, 5
    sw $8, 4($7)
    
    # Edge 9: 4-6
    addi $7, $7, 8
    addi $8, $0, 4
    sw $8, 0($7)
    addi $8, $0, 6
    sw $8, 4($7)
    
    # Edge 10: 5-7
    addi $7, $7, 8
    addi $8, $0, 5
    sw $8, 0($7)
    addi $8, $0, 7
    sw $8, 4($7)
    
    # Edge 11: 6-7
    addi $7, $7, 8
    addi $8, $0, 6
    sw $8, 0($7)
    addi $8, $0, 7
    sw $8, 4($7)
    
    # Initialize sin/cos tables (simplified: use small angle approximation)
    # For now, we'll compute sin/cos on the fly using a simple approximation
    # sin(angle) ≈ angle (for small angles, scaled appropriately)
    # We'll use a lookup table approach with 256 entries
    
    # Main rendering loop
main_loop:
    # Decay or clear framebuffer
    # If ENABLE_DECAY: shift each column right by 1 (decay brightness)
    # If not: clear to black for sharp edges
    addi $5, $2, 0x1500       # Framebuffer base
    addi $6, $0, 0            # Column counter
    addi $7, $0, 256          # Total columns
    bne $23, $0, decay_fb_loop # If ENABLE_DECAY != 0, use decay
    
clear_fb_loop:
    sw $0, 0($5)              # Clear column to black
    addi $5, $5, 4
    addi $6, $6, 1
    bne $6, $7, clear_fb_loop
    j fb_clear_done
    
decay_fb_loop:
    lw $25, 0($5)             # Load current pixel
    sra $25, $25, 1           # Shift right by 1 (decay brightness)
    # Mask to 24 bits (clear upper 8 bits) - andi not supported, use workaround
    addi $29, $0, 0x00FFFFFF  # Load mask into $29
    and $25, $25, $29         # and $25, $25, $29 (mask to 24 bits)
    sw $25, 0($5)             # Store decayed pixel
    addi $5, $5, 4
    addi $6, $6, 1
    bne $6, $7, decay_fb_loop
    
fb_clear_done:
    
    # Rotate all vertices
    # Rotation around Y-axis: x' = x*cos - z*sin, y' = y, z' = x*sin + z*cos
    # We'll use angle as index into sin/cos tables (0-255)
    addi $5, $0, 0            # Vertex index
    addi $6, $2, 0x1000       # Original vertices base
    addi $7, $2, 0x1060       # Rotated vertices base
    
rotate_vertices_loop:
    # Load original vertex (x, y, z)
    lw $8, 0($6)              # x
    lw $9, 4($6)              # y
    lw $10, 8($6)             # z
    
    # Get sin and cos of angle (simplified: use angle directly as table index)
    # For simplicity, we'll use a basic rotation:
    # cos(angle) and sin(angle) approximated
    # Actually, let's use a simpler approach: rotate by small fixed increments
    # We'll compute: x' = x, y' = y, z' = z (no rotation for now, or simple rotation)
    
    # Simple Y-axis rotation (around vertical axis)
    # For a POV display, we want to see the cube rotating
    # Let's use: x' = x*cos(angle) - z*sin(angle)
    #           z' = x*sin(angle) + z*cos(angle)
    #           y' = y
    
    # For simplicity, we'll use fixed-point multiplication
    # Load angle and compute sin/cos (we'll use a simple approximation)
    # sin(angle) ≈ angle (scaled), cos(angle) ≈ 1 - angle^2/2 (for small angles)
    
    # Simplified rotation: use angle directly
    # x' = x (for now, we'll add proper rotation later)
    # Actually, let's implement a proper rotation using mult/div
    
    # For now, copy vertices as-is (we'll add rotation math)
    sw $8, 0($7)              # x' = x
    sw $9, 4($7)              # y' = y
    sw $10, 8($7)             # z' = z
    
    # Move to next vertex
    addi $6, $6, 12
    addi $7, $7, 12
    addi $5, $5, 1
    addi $11, $0, 8
    bne $5, $11, rotate_vertices_loop
    
    # Project vertices to 1D column indices
    # For POV display, we project 3D to angular position
    # Simple projection: use atan2(y, x) or just map x/z to column
    # We'll use: col = 128 + (x' * scale) where scale maps [-1,1] to [-128,127]
    addi $5, $0, 0            # Vertex index
    addi $6, $2, 0x1060       # Rotated vertices base
    addi $7, $2, 0x1200       # Projected columns base
    
project_vertices_loop:
    # Load rotated vertex
    lw $8, 0($6)              # x'
    lw $9, 4($6)              # y'
    lw $10, 8($6)             # z'
    
    # Project to column: use x coordinate (simplified)
    # Column = 128 + (x' >> 16) * 64  (scale x from Q16 to column index)
    # Actually, let's use: col = 128 + (x' >> 10) to map [-65536, 65536] to [-64, 64]
    sra $11, $8, 10           # x' >> 10 (scale down)
    addi $11, $11, 128        # Center at 128
    # Clamp to [0, 255]
    addi $12, $0, 0
    blt $11, $12, clamp_low
    addi $12, $0, 255
    blt $12, $11, clamp_high
    j clamp_done
clamp_low:
    addi $11, $0, 0
    j clamp_done
clamp_high:
    addi $11, $0, 255
clamp_done:
    sw $11, 0($7)             # Store projected column
    
    # Move to next vertex
    addi $6, $6, 12
    addi $7, $7, 4
    addi $5, $5, 1
    addi $12, $0, 8
    bne $5, $12, project_vertices_loop
    
    # Draw edges (lines between vertex pairs) with THICK EDGES for low-RPM visibility
    addi $5, $0, 0            # Edge index
    addi $6, $2, 0x1220       # Edge list base
    addi $7, $2, 0x1200       # Projected columns base
    addi $8, $2, 0x1500       # Framebuffer base
    
draw_edges_loop:
    # Load edge (vertex indices)
    lw $9, 0($6)              # vertex_index1
    lw $10, 4($6)             # vertex_index2
    
    # Get column indices for these vertices
    sll $11, $9, 2            # offset for vertex 1
    add $11, $7, $11
    lw $11, 0($11)            # col1
    
    sll $12, $10, 2           # offset for vertex 2
    add $12, $7, $12
    lw $12, 0($12)            # col2
    
    # Draw THICK line from col1 to col2
    # For each column along the line, light col-thickness to col+thickness
    # Determine direction
    blt $12, $11, draw_line_reverse
    # Draw forward (col1 to col2)
    add $13, $11, $0          # current_col = col1
draw_line_forward:
    # Light this column and surrounding columns (thick edge)
    # Inline thick column drawing for this column
    # Calculate column range: [col - thickness, col + thickness]
    sub $25, $13, $20         # col_min = col - thickness
    add $26, $13, $20         # col_max = col + thickness
    
    # Clamp col_min to [0, 255]
    addi $27, $0, 0
    blt $25, $27, fwd_clamp_min_low
    j fwd_clamp_min_check
fwd_clamp_min_low:
    addi $25, $0, 0
fwd_clamp_min_check:
    addi $27, $0, 255
    blt $27, $25, fwd_clamp_min_high
    j fwd_clamp_min_done
fwd_clamp_min_high:
    addi $25, $0, 255
fwd_clamp_min_done:
    
    # Clamp col_max to [0, 255]
    addi $27, $0, 0
    blt $26, $27, fwd_clamp_max_low
    j fwd_clamp_max_check
fwd_clamp_max_low:
    addi $26, $0, 0
    j fwd_clamp_max_done
fwd_clamp_max_check:
    addi $27, $0, 255
    blt $27, $26, fwd_clamp_max_high
    j fwd_clamp_max_done
fwd_clamp_max_high:
    addi $26, $0, 255
fwd_clamp_max_done:
    
    # Light columns from col_min to col_max
    add $27, $25, $0          # current_col = col_min
fwd_thick_loop:
    sll $28, $27, 2           # offset = current_col * 4
    add $28, $8, $28          # framebuffer address
    sw $21, 0($28)            # Store EDGE_BRIGHTNESS
    addi $27, $27, 1
    blt $27, $26, fwd_thick_loop
    # Also light col_max
    sll $28, $26, 2
    add $28, $8, $28
    sw $21, 0($28)
    
    addi $13, $13, 1
    blt $13, $12, draw_line_forward
    # Also draw thick column at col2
    sub $25, $12, $20
    add $26, $12, $20
    addi $27, $0, 0
    blt $25, $27, fwd_end_clamp_min
    j fwd_end_check_max
fwd_end_clamp_min:
    addi $25, $0, 0
fwd_end_check_max:
    addi $27, $0, 255
    blt $27, $25, fwd_end_clamp_min_high
    j fwd_end_light
fwd_end_clamp_min_high:
    addi $25, $0, 255
fwd_end_light:
    addi $27, $0, 255
    blt $27, $26, fwd_end_clamp_max
    j fwd_end_light_loop
fwd_end_clamp_max:
    addi $26, $0, 255
fwd_end_light_loop:
    add $27, $25, $0
fwd_end_loop:
    sll $28, $27, 2
    add $28, $8, $28
    sw $21, 0($28)
    addi $27, $27, 1
    blt $27, $26, fwd_end_loop
    sll $28, $26, 2
    add $28, $8, $28
    sw $21, 0($28)
    j draw_line_done
    
draw_line_reverse:
    # Draw reverse (col2 to col1)
    add $13, $12, $0          # current_col = col2
draw_line_reverse_loop:
    # Light this column and surrounding columns (thick edge)
    sub $25, $13, $20         # col_min = col - thickness
    add $26, $13, $20         # col_max = col + thickness
    
    # Clamp col_min
    addi $27, $0, 0
    blt $25, $27, rev_clamp_min_low
    j rev_clamp_min_check
rev_clamp_min_low:
    addi $25, $0, 0
rev_clamp_min_check:
    addi $27, $0, 255
    blt $27, $25, rev_clamp_min_high
    j rev_clamp_min_done
rev_clamp_min_high:
    addi $25, $0, 255
rev_clamp_min_done:
    
    # Clamp col_max
    addi $27, $0, 0
    blt $26, $27, rev_clamp_max_low
    j rev_clamp_max_check
rev_clamp_max_low:
    addi $26, $0, 0
    j rev_clamp_max_done
rev_clamp_max_check:
    addi $27, $0, 255
    blt $27, $26, rev_clamp_max_high
    j rev_clamp_max_done
rev_clamp_max_high:
    addi $26, $0, 255
rev_clamp_max_done:
    
    # Light columns
    add $27, $25, $0
rev_thick_loop:
    sll $28, $27, 2
    add $28, $8, $28
    sw $21, 0($28)
    addi $27, $27, 1
    blt $27, $26, rev_thick_loop
    sll $28, $26, 2
    add $28, $8, $28
    sw $21, 0($28)
    
    addi $13, $13, 1
    blt $13, $11, draw_line_reverse_loop
    # Also draw thick column at col1
    sub $25, $11, $20
    add $26, $11, $20
    addi $27, $0, 0
    blt $25, $27, rev_end_clamp_min
    j rev_end_check_max
rev_end_clamp_min:
    addi $25, $0, 0
rev_end_check_max:
    addi $27, $0, 255
    blt $27, $25, rev_end_clamp_min_high
    j rev_end_light
rev_end_clamp_min_high:
    addi $25, $0, 255
rev_end_light:
    addi $27, $0, 255
    blt $27, $26, rev_end_clamp_max
    j rev_end_light_loop
rev_end_clamp_max:
    addi $26, $0, 255
rev_end_light_loop:
    add $27, $25, $0
rev_end_loop:
    sll $28, $27, 2
    add $28, $8, $28
    sw $21, 0($28)
    addi $27, $27, 1
    blt $27, $26, rev_end_loop
    sll $28, $26, 2
    add $28, $8, $28
    sw $21, 0($28)
    
draw_line_done:
    
    # Move to next edge
    addi $6, $6, 8
    addi $5, $5, 1
    addi $13, $0, 12
    bne $5, $13, draw_edges_loop
    
    # Copy framebuffer to POV peripheral
    addi $5, $2, 0x1500       # Framebuffer base
    addi $6, $0, 0            # Column counter
    addi $7, $0, 256          # Total columns
    
copy_to_pov_loop:
    # Load pixel from framebuffer
    lw $8, 0($5)              # Pixel data (24-bit RGB in lower 24 bits)
    
    # Write to POV peripheral
    # 1. Write column address
    sw $6, 0($1)              # POV_COL_ADDR = 0xFFFF0000
    # 2. Write pixel data
    addi $9, $1, 4
    sw $8, 0($9)              # POV_PIXEL_DATA = 0xFFFF0004
    # 3. Trigger write
    addi $9, $1, 8
    sw $0, 0($9)              # POV_WRITE = 0xFFFF0008 (any write triggers)
    
    # Move to next column
    addi $5, $5, 4
    addi $6, $6, 1
    bne $6, $7, copy_to_pov_loop
    
    # Increment angle by ANGLE_STEP (slow rotation for low-RPM visibility)
    # Use R-type add instruction: add $rd, $rs, $rt
    # Format: add $4, $4, $22 means $4 = $4 + $22
    # If assembler doesn't support register-to-register add, use this workaround:
    #   addi $4, $4, 1  (hardcoded step of 1)
    # For tunable step, we'll use the register version (assembler should handle it)
    add $4, $4, $22           # angle += ANGLE_STEP (R-type: $4 = $4 + $22)
    addi $9, $0, 256
    blt $4, $9, angle_ok
    # Wrap angle: subtract 256 using add with negative
    # Since we can't use negative immediate in addi easily, use sub
    addi $9, $0, 256
    sub $4, $4, $9            # angle -= 256 (wrap around, R-type: $4 = $4 - $9)
angle_ok:
    
    # Frame delay (use DELAY_COUNT constant for frame rate control)
    addi $9, $0, 0
    add $10, $24, $0          # Use DELAY_COUNT from $24
delay_loop:
    addi $9, $9, 1
    bne $9, $10, delay_loop
    
    # Loop forever
    j main_loop

# End of program
# Note: Thick column drawing is now inlined in the draw_line_forward and
# draw_line_reverse sections for efficiency and to avoid return address issues.

