# Animation frame controller
# Auto-cycles through animation frames at 24 fps using hardware timer
#
# MMIO addresses:
#   1002: frame_idx (output) - current frame to display
#   1003: frame_tick (input) - pulses high every 1/24 second

main:
    addi $t0, $zero, 0      # $t0 = current frame index
    addi $t1, $zero, 0      # $t1 = last tick state

loop:
    # Read hardware timer tick
    lw   $t2, 1003($zero)

    # Check if tick changed (rising edge detection)
    bne  $t2, $t1, tick_changed
    j    update_state

tick_changed:
    # Only advance on rising edge (0 -> 1)
    blt  $t1, $t2, advance_frame
    j    update_state

advance_frame:
    # Advance to next frame
    addi $t0, $t0, 1

    # Wrap at frame 24 (adjust for your number of frames)
    addi $t3, $zero, 24
    blt  $t0, $t3, no_wrap
    addi $t0, $zero, 0

no_wrap:
    # Write frame index to MMIO
    sw   $t0, 1002($zero)

update_state:
    # Save current tick state
    add  $t1, $t2, $zero
    j    loop
