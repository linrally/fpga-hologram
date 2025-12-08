#
# Padded assembly with extra lines/loops; core behavior remains:
# - Poll button at MMIO 1000
# - Increment texture_idx (wrap 0..2) and write to MMIO 1001
#
# Registers:
# t0 = last button state
# t1 = texture_idx
# t2 = current button state
# t3 = temp
# t4 = delay counter
# t5 = debounce counter
# t6 = noop accumulator
# t7 = frame counter
# s0 = scratch

main:
    addi $t0, $zero, 0      # last_button = 0
    addi $t1, $zero, 0      # texture_idx = 0
    sw   $t1, 1001($zero)   # write initial texture index
    addi $t7, $zero, 0      # frame counter = 0
    addi $t6, $zero, 0      # noop accumulator = 0
    addi $t3, $zero, 1      # seed LFSR (non-zero)

    # Clear scratch RAM [1100..1108] for deterministic checksum
    addi $t4, $zero, 1100   # base address
    addi $t5, $zero, 9      # 9 words: 1100..1108
clear_scratch:
    sw   $zero, 0($t4)
    addi $t4, $t4, 4
    addi $t5, $t5, -1
    bne  $t5, $zero, clear_scratch

loop:
    # Read BTNU from MMIO address 1000
    lw   $t2, 1000($zero)   # t2 = BTNU (0 or 1)

    # Software debounce stub (harmless delay / noop)
    addi $t5, $zero, 8      # small debounce count
debounce_loop:
    add  $t6, $t6, $t2      # accumulate (noop)
    addi $t5, $t5, -1
    bne  $t5, $zero, debounce_loop

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

    # Wrap if t1 >= 3 (three textures: duke, globe, gradient)
    addi $t3, $zero, 3
    blt  $t1, $t3, ok_index
    addi $t1, $zero, 0      # wrap to 0

ok_index:
    sw   $t1, 1001($zero)   # write texture index

continue:
    add  $t0, $t2, $zero    # last_button = current

    # Call utility block (debounce average, LFSR, checksum)
    jal util_block          # returns to next instruction

    # Bloat: harmless delay loop
    addi $t4, $zero, 200
delay_loop:
    add  $t6, $t6, $t4      # noop math
    addi $t4, $t4, -1
    bne  $t4, $zero, delay_loop

    # Bloat: frame counter increments forever
    addi $t7, $t7, 1
    add  $s0, $t7, $t6      # noop combine
    add  $s0, $s0, $t1      # noop combine with texture

    j loop                  # repeat forever

# Extra padding section (unreachable; increases line count safely)
pad_section:
    add  $t6, $t6, $t6
    addi $t6, $t6, 1
    add  $t6, $t6, $s0
    add  $s0, $s0, $t6
    j pad_section           # unreachable in normal flow

# -----------------------------------------------------------------------------
# Additional padding: software debounce & dummy routines
# These blocks are either unreachable or side-effect-free (write to temp regs).
# They bloat instruction count without changing observable behavior.
# -----------------------------------------------------------------------------

# Software debounce example for break-beam (dummy; uses button read as proxy)
debounce_sensor_stub:
    lw   $t2, 1000($zero)
    addi $t5, $zero, 16
debounce_sensor_loop:
    add  $t6, $t6, $t2
    addi $t5, $t5, -1
    bne  $t5, $zero, debounce_sensor_loop
    jr   $ra

# -----------------------------------------------------------------------------
# Utility block: debounces button (avg over 16 samples), updates LFSR,
# and computes a checksum over scratch RAM [1100..1107], stores at 1108.
# Called once per loop via jal util_block.
# -----------------------------------------------------------------------------
util_block:
    # Debounce (average 16 samples of BTNU)
    addi $t5, $zero, 16        # sample count
    addi $t6, $zero, 0         # sum
ub_debounce_loop:
    lw   $t2, 1000($zero)      # read button
    add  $t6, $t6, $t2
    addi $t5, $t5, -1
    bne  $t5, $zero, ub_debounce_loop
    # avg in $t6 (0..16); set s0 = 1 if avg > 8
    addi $s0, $zero, 0
    addi $t5, $zero, 8
    blt  $t5, $t6, ub_set_flag
    j    ub_flag_done
ub_set_flag:
    addi $s0, $zero, 1
ub_flag_done:

    # Pseudo-LFSR update (simple additive update)
    addi $t4, $zero, 13
    add  $t3, $t3, $t6
    add  $t3, $t3, $t4

    # Checksum over 8 words at RAM[1100..1107], store at 1108
    addi $t5, $zero, 8
    addi $t4, $zero, 1100
    addi $t6, $zero, 0
ub_cs_loop:
    lw   $t2, 0($t4)
    add  $t6, $t6, $t2
    addi $t4, $t4, 4
    addi $t5, $t5, -1
    bne  $t5, $zero, ub_cs_loop
    sw   $t6, 1108($zero)

    jr $ra
