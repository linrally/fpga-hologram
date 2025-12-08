# Main assembly program
# Animation runs automatically in hardware at 24 fps
#
# MMIO addresses:
#   1000: BTNU (input)
#   1001: LED[4:0] (output)

main:
    # Simple loop - animation handled by hardware
    j main
