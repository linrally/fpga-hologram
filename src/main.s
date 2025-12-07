# t0 = last button state 
# t1 = texture_idx 
# t2 = current button state

main:
    addi $t0, $zero, 0      # last_button = 0
    addi $t1, $zero, 0      # texture_idx = 0
    sw   $t1, 1001($zero)   # write initial texture index

loop:
    # Read BTNU from MMIO address 1000
    lw   $t2, 1000($zero)   # t2 = BTNU (0 or 1)

    # Check if button changed -> if same, skip
    bne  $t2, $t0, changed
    j    continue

changed:
    # Only act on rising edge: last=0 and now=1
    bne  $t2, $zero, rising
    j    continue

rising:
    # Button press detected: increment texture index
    addi $t1, $t1, 1        # texture_idx++

    # Wrap if t1 >= 2
    addi $t3, $zero, 2
    blt  $t1, $t3, ok_index
    addi $t1, $zero, 0      # wrap to 0

ok_index:
    sw   $t1, 1001($zero)

continue:
    add  $t0, $t2, $zero

    j loop                 
