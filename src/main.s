# Animation frame controller
# Auto-cycles through animation frames
#
# MMIO addresses:
#   1002: frame_idx (output)

main:
    addi $t0, $zero, 0      # $t0 = current frame index
    addi $t1, $zero, 0      # $t1 = frame counter/timer

loop:
    # Increment timer
    addi $t1, $t1, 1

    # Check if it's time to advance frame (adjust 30000 for speed)
    addi $t2, $zero, 30000
    blt  $t1, $t2, loop

    # Reset timer
    addi $t1, $zero, 0

    # Advance to next frame
    addi $t0, $t0, 1

    # Wrap at frame 24 (adjust for your number of frames)
    addi $t3, $zero, 24
    blt  $t0, $t3, no_wrap
    addi $t0, $zero, 0

no_wrap:
    # Write frame index to MMIO
    sw   $t0, 1002($zero)

    j    loop
