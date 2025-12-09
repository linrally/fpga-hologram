params:
    addi $t3, $zero, 4 # MAX BRIGHTNESS LEVEL 
    addi $t6, $zero, 16 # DEBOUNCE THRESHOLD

main: # main event loop
    addi $t0, $zero, 0 # previous raw button state
    addi $t1, $zero, 0 # brightness counter
    addi $t2, $zero, 0 # current button state
    addi $t4, $zero, 0 # debounce counter
    addi $t5, $zero, 0 # previous stable button state

loop:
    lw $t2, 1000($zero) # read button into current
    bne $t2, $t0, debounce_reset # if the raw value has changed, reset debounce counter
    addi $t4, $t4, 1 # otherwise, the raw value has not changed, so increment the debounce counter
    blt $t4, $t6, debounce_continue # if the debounce counter is less than the threshold, continue
    blt $t5, $t2, increment # if the stable value has risen, go to increment (blt will trigger rising 0 -> 1 unlike bne which triggers both rising and falling)
    j continue

increment:
    addi $t1, $t1, 1 # increment brightness counter
    blt $t1, $t3, write # if less than max, jump to write without wrapping
    addi $t1, $zero, 0 # wrap to 0, then fall through to write
    j write

write:
    sw $t1, 1002($zero) # write to brightness level
    sw $t1, 1001($zero) # write to LED (for debugging, 4 bits)
    j debounce_continue

debounce_continue:
    add $t5, $t2, $zero # update prev stable to cur
    j continue

debounce_reset:
    addi $t4, $zero, 0 # reset debounce counter
    j continue

continue:
    add $t0, $t2, $zero # update prev raw to cur
    j loop