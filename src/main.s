main:
    addi $t0, $zero, 0
    addi $t1, $zero, 0

loop:
    lw   $t2, 1000($zero)
    bne  $t2, $t0, changed
    j    continue

changed:
    blt  $t0, $t2, rising
    j    continue

rising:
    addi $t1, $t1, 1
    addi $t3, $zero, 6
    blt  $t1, $t3, no_wrap
    addi $t1, $zero, 0

no_wrap:
    sw   $t1, 1001($zero)

continue:
    add  $t0, $t2, $zero
    j loop
