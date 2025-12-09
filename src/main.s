# event loop for processor
# debounces BTNU and BTND, then increments brightness and toggles invert between 0 and 1
# could be cleaned up with functions, but our processor does not have a stack

# main parameters:
#   BTNU MMIO: 1000
#   BTND MMIO: 1003
#   LED MMIO: 1001
#   brightness MMIO: 1002
#   invert MMIO: 1004
#   max brightness level: 4
#   debounce threshold: 16

main: # main event loop
    addi $t0, $zero, 0 # previous raw BTNU state
    addi $t1, $zero, 0 # brightness counter
    addi $t2, $zero, 0 # current BTNU state
    addi $t4, $zero, 0 # BTNU debounce counter
    addi $t5, $zero, 0 # previous stable button state

    addi $s0, $zero, 0 # previous raw BTND state
    addi $s1, $zero, 0 # invert (1 or 0)
    addi $s2, $zero, 0 # current BTND state
    addi $s4, $zero, 0 # BTND debounce counter
    addi $s5, $zero, 0 # previous stable button state

loop:
    lw $t2, 1000($zero) # read BTNU into current
    lw $s2, 1003($zero) # read BTND

    bne $t2, $t0, debounce_reset_btnu # if the raw value has changed, reset debounce counter
    addi $t4, $t4, 1 # otherwise, the raw value has not changed, so increment the debounce counter
    addi $t3, $zero, 16 # debounce threshold
    blt $t4, $t3, debounce_continue_btnu # if the debounce counter is less than the threshold, continue
    blt $t5, $t2, increment_btnu # if the stable value has risen, go to increment (blt will trigger rising 0 -> 1 unlike bne which triggers both rising and falling)
    j after_btnu

increment_btnu:
    addi $t1, $t1, 1 # increment brightness counter
    addi $t3, $zero, 4 # max brightness level
    blt $t1, $t3, write # if less than max, jump to write without wrapping
    addi $t1, $zero, 0 # wrap to 0, then fall through to write
    j write

write:
    sw $t1, 1002($zero) # write to brightness level
    sw $t1, 1001($zero) # write to LED (for debugging, 4 bits)
    j debounce_continue_btnu

debounce_continue_btnu:
    add $t5, $t2, $zero # update prev stable to cur
    j after_btnu

debounce_reset_btnu:
    addi $t4, $zero, 0 # reset debounce counter
    j after_btnu

after_btnu: # BTNU debounce complete, now check BTND
    j check_btnd

check_btnd:
    bne $s2, $s0, debounce_reset_btnd 
    addi $s4, $s4, 1
    addi $s3, $zero, 16 
    blt $s4, $s3, debounce_continue_btnd 
    blt $s5, $s2, increment_btnd 
    j continue_btnd

increment_btnd:
    # we dont have xor, so we use this hack
    addi $t6, $zero, 1 # load 1 into temp register
    sub $s1, $t6, $s1 # subtract invert from 1 to toggle it
    sw $s1, 1004($zero) # write invert to mmio
    j debounce_continue_btnd

debounce_continue_btnd:
    add $s5, $s2, $zero
    j continue_btnd

debounce_reset_btnd:
    addi $s4, $zero, 0
    j continue_btnd

continue_btnd:
    j continue

continue:
    add $t0, $t2, $zero # update prev raw to cur
    add $s0, $s2, $zero # BTND
    j loop