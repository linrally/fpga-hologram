# Registers: t0=last_btn, t1=texture_idx, t2=btn_state, t3=temp/LFSR, t4=delay, t5=counter, t6=acc, t7=frame, s0=scratch
# s1=last_inv, s2=last_brt, s3=brightness, s4=invert, t8=btn_inv, t9=btn_brt

main:
    addi $t0, $zero, 0      # last_button = 0
    addi $t1, $zero, 0      # texture_idx = 0
    sw   $t1, 1001($zero)   # write initial texture index
    addi $t7, $zero, 0      # frame counter = 0
    addi $t6, $zero, 0      # noop accumulator = 0
    addi $t3, $zero, 1      # seed LFSR (non-zero)
    addi $s1, $zero, 0      # last BTN_INV state
    addi $s2, $zero, 0      # last BTN_BRT state
    addi $s3, $zero, 0      # brightness level
    addi $s4, $zero, 0      # invert flag

    # Clear scratch RAM 1100-1108
    addi $t4, $zero, 1100
    addi $t5, $zero, 9
clear_scratch:
    sw   $zero, 0($t4)
    addi $t4, $t4, 4
    addi $t5, $t5, -1
    bne  $t5, $zero, clear_scratch

    sw   $s3, 1004($zero)   # init brightness = 0
    sw   $s4, 1005($zero)   # init invert = 0

loop:
    lw   $t2, 1000($zero)   # BTNU
    lw   $t8, 1002($zero)   # BTN_INV
    lw   $t9, 1003($zero)   # BTN_BRT

    addi $t5, $zero, 8      # debounce delay
debounce_loop:
    add  $t6, $t6, $t2
    addi $t5, $t5, -1
    bne  $t5, $zero, debounce_loop

    bne  $t2, $t0, changed  # button state changed?
    j    continue

changed:
    bne  $t2, $zero, rising # only care about press (rising edge)
    j    continue

rising:
    addi $t1, $t1, 1        # cycle to next texture
    addi $t3, $zero, 3      # max textures
    blt  $t1, $t3, ok_index
    addi $t1, $zero, 0      # wrap back to first

ok_index:
    sw   $t1, 1001($zero)   # update texture selection

continue:
    add  $t0, $t2, $zero    # save current state for next iteration

    # Invert button: toggle on rising edge
    bne  $t8, $s1, inv_changed
    j    inv_done
inv_changed:
    bne  $t8, $zero, inv_rising
    j    inv_done
inv_rising:
    addi $s4, $s4, 1        # flip 0->1 or 1->0
    addi $t5, $zero, 2
    blt  $s4, $t5, inv_ok
    addi $s4, $zero, 0      # wrap back to 0
inv_ok:
    sw   $s4, 1005($zero)   # write to MMIO
inv_done:
    add  $s1, $t8, $zero    # remember state

    # Brightness button: step 0..3 on rising edge
    bne  $t9, $s2, brt_changed
    j    brt_done
brt_changed:
    bne  $t9, $zero, brt_rising
    j    brt_done
brt_rising:
    addi $s3, $s3, 1        # increment brightness level
    addi $t5, $zero, 4      # max is 4 (0-3)
    blt  $s3, $t5, brt_ok
    addi $s3, $zero, 0      # wrap to 0
brt_ok:
    sw   $s3, 1004($zero)   # write to MMIO
brt_done:
    add  $s2, $t9, $zero    # remember state

    jal util_block          # debounce, LFSR, checksum

    addi $t4, $zero, 200    # small delay to slow loop
delay_loop:
    add  $t6, $t6, $t4
    addi $t4, $t4, -1
    bne  $t4, $zero, delay_loop

    addi $t7, $t7, 1        # frame counter
    add  $s0, $t7, $t6
    add  $s0, $s0, $t1

    j loop

pad_section:
    add  $t6, $t6, $t6
    addi $t6, $t6, 1
    add  $t6, $t6, $s0
    add  $s0, $s0, $t6
    j pad_section

debounce_sensor_stub:
    lw   $t2, 1000($zero)
    addi $t5, $zero, 16
debounce_sensor_loop:
    add  $t6, $t6, $t2
    addi $t5, $t5, -1
    bne  $t5, $zero, debounce_sensor_loop
    jr   $ra

util_block:
    # Average 16 button samples for debouncing
    addi $t5, $zero, 16
    addi $t6, $zero, 0
ub_debounce_loop:
    lw   $t2, 1000($zero)
    add  $t6, $t6, $t2       # sum samples
    addi $t5, $t5, -1
    bne  $t5, $zero, ub_debounce_loop
    addi $s0, $zero, 0
    addi $t5, $zero, 8       # threshold: if avg > 8, button is pressed
    blt  $t5, $t6, ub_set_flag
    j    ub_flag_done
ub_set_flag:
    addi $s0, $zero, 1
ub_flag_done:

    # Update LFSR state
    addi $t4, $zero, 13
    add  $t3, $t3, $t6
    add  $t3, $t3, $t4

    # Compute checksum of scratch RAM
    addi $t5, $zero, 8       # 8 words
    addi $t4, $zero, 1100    # start address
    addi $t6, $zero, 0
ub_cs_loop:
    lw   $t2, 0($t4)
    add  $t6, $t6, $t2       # accumulate sum
    addi $t4, $t4, 4
    addi $t5, $t5, -1
    bne  $t5, $zero, ub_cs_loop
    sw   $t6, 1108($zero)   # store checksum

    jr $ra
