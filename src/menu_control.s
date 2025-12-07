# menu_control.s
# Interactive menu control system for POV display
#
# Menu System:
#   0. Mode: Globe/Cube
#   1. Brightness: 0-100% (0-255)
#   2. Effect: Normal/Grayscale/Sepia/Inverted/Rainbow
#   3. Speed: (reserved for future use)
#   4. Reset: Reset to defaults
#
# Controls:
#   BTNU (Up): Navigate menu up
#   BTND (Down): Navigate menu down
#   BTNC (Center): Select/Activate menu item
#
# Register Usage:
#   $1  - Display peripheral base address (0xFFFF1000)
#   $2  - Button status register address
#   $3  - Current menu selection
#   $4  - Current brightness value
#   $5  - Current effect value
#   $6  - Current mode value (0=globe, 1=cube)
#   $7  - Temporary register
#   $8  - Temporary register
#   $9  - Temporary register
#   $10 - Button status (read from peripheral)
#   $11 - Previous button state (for edge detection)
#   $12 - Menu item value (for adjustments)
#   $13 - Loop counter
#   $14 - Delay counter
#   $15 - Temporary calculations
#   $16 - Temporary calculations
#   $17 - Temporary calculations
#   $18 - Temporary calculations
#   $19 - Temporary calculations
#   $20 - Temporary calculations
#   $21 - Temporary calculations
#   $22 - Temporary calculations
#   $23 - Temporary calculations
#   $24 - Temporary calculations
#   $25 - Temporary calculations
#   $26 - Temporary calculations
#   $27 - Temporary calculations
#   $28 - Temporary calculations
#   $29 - Temporary calculations
#   $30 - Temporary calculations
#   $31 - Return address (for jal)

.text

# Memory-mapped register addresses (offsets from base 0xFFFF1000)
# DISP_MODE      = 0xFFFF1000 (offset 0)
# DISP_BRIGHTNESS = 0xFFFF1004 (offset 4)
# DISP_EFFECT    = 0xFFFF1008 (offset 8)
# DISP_SPEED     = 0xFFFF100C (offset 12)
# BTN_STATUS     = 0xFFFF1010 (offset 16)
# MENU_SEL       = 0xFFFF1014 (offset 20)
# LED_OUT        = 0xFFFF1018 (offset 24)

# Button bit positions: 0=UP, 1=DOWN, 2=CENTER
# Menu item indices: 0=Mode, 1=Brightness, 2=Effect, 3=Speed, 4=Reset
# Effect values: 0=Normal, 1=Grayscale, 2=Sepia, 3=Inverted, 4=Rainbow
# Default values: brightness=255, effect=0, mode=0

main:
    # Initialize base addresses
    # Build 0xFFFF1000: Start with 0xFFFF, shift left 12, add 0x1000
    addi $1, $0, -1           # Load 0xFFFFFFFF
    sll $1, $1, 16            # Shift left 16: 0xFFFF0000
    addi $1, $1, 0x1000       # Add 0x1000: 0xFFFF1000 (DISP_BASE)
    
    # Initialize registers
    addi $3, $0, 0            # menu_sel = 0 (start at menu item 0)
    addi $4, $0, 255          # brightness = 255 (full, DEFAULT_BRIGHTNESS)
    addi $5, $0, 0            # effect = 0 (normal, DEFAULT_EFFECT)
    addi $6, $0, 0            # mode = 0 (globe, DEFAULT_MODE)
    addi $11, $0, 0            # prev_button_state = 0
    
    # Write initial values to peripheral
    sw $6, 0($1)               # DISP_MODE: Set mode to globe (offset 0)
    sw $4, 4($1)               # DISP_BRIGHTNESS: Set brightness to full (offset 4)
    sw $5, 8($1)               # DISP_EFFECT: Set effect to normal (offset 8)
    sw $3, 20($1)              # MENU_SEL: Set menu selection to 0 (offset 20)
    
    # Set LED to show menu item 0 selected
    addi $7, $0, 1             # LED pattern: bit 0 = 1
    sw $7, 24($1)              # LED_OUT: Write LED output (offset 24)
    
    # Main menu loop
menu_loop:
    # Read button status
    lw $10, 16($1)             # BTN_STATUS: Read button status (offset 16)
    
    # Check for button presses (edge detection: pressed now but not before)
    # For each button: check if current bit is set AND previous bit was not set
    
    # Check UP button press (bit 0): current[0] AND NOT previous[0]
    addi $9, $0, 1             # Load 1 (mask for bit 0)
    and $15, $10, $9           # Get current UP bit
    and $16, $11, $9           # Get previous UP bit
    bne $16, $0, check_down    # If previous was set, skip (not a new press)
    bne $15, $0, handle_up     # If current is set and previous wasn't, handle UP
    
check_down:
    # Check DOWN button press (bit 1): current[1] AND NOT previous[1]
    addi $9, $0, 1             # Load 1
    sll $9, $9, 1              # Shift to bit 1
    and $15, $10, $9           # Get current DOWN bit
    and $16, $11, $9           # Get previous DOWN bit
    bne $16, $0, check_center  # If previous was set, skip
    bne $15, $0, handle_down   # If current is set and previous wasn't, handle DOWN
    
check_center:
    # Check CENTER button press (bit 2): current[2] AND NOT previous[2]
    addi $9, $0, 1             # Load 1
    sll $9, $9, 2              # Shift to bit 2
    and $15, $10, $9           # Get current CENTER bit
    and $16, $11, $9           # Get previous CENTER bit
    bne $16, $0, no_button     # If previous was set, skip
    bne $15, $0, handle_center # If current is set and previous wasn't, handle CENTER
    
no_button:
    # No button press, update previous state and continue
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

handle_up:
    # Navigate menu up (decrement menu selection)
    bne $3, $0, up_decrement   # If not at menu 0, decrement
    addi $3, $0, 4             # If at menu 0, wrap to max (4)
    j update_menu_display      # Update display
up_decrement:
    addi $3, $3, -1            # Decrement menu selection
    j update_menu_display      # Update display

handle_down:
    # Navigate menu down (increment menu selection)
    addi $7, $0, 4             # Load max menu index (MENU_MAX = 4)
    bne $3, $7, down_increment # If not at max, increment
    addi $3, $0, 0             # If at max, wrap to 0
    j update_menu_display      # Update display
down_increment:
    addi $3, $3, 1             # Increment menu selection
    j update_menu_display      # Update display

update_menu_display:
    # Update LED display to show current menu selection
    # LED pattern: bit N = 1 means menu item N is selected
    # Since sll requires immediate, use conditional branches
    bne $3, $0, check_led_1
    addi $7, $0, 1             # menu_sel=0: LED pattern = 0x0001
    j write_led
check_led_1:
    addi $8, $0, 1
    bne $3, $8, check_led_2
    addi $7, $0, 2             # menu_sel=1: LED pattern = 0x0002
    j write_led
check_led_2:
    addi $8, $0, 2
    bne $3, $8, check_led_3
    addi $7, $0, 4             # menu_sel=2: LED pattern = 0x0004
    j write_led
check_led_3:
    addi $8, $0, 3
    bne $3, $8, check_led_4
    addi $7, $0, 8             # menu_sel=3: LED pattern = 0x0008
    j write_led
check_led_4:
    addi $7, $0, 16            # menu_sel=4: LED pattern = 0x0010
write_led:
    sw $7, 24($1)              # LED_OUT: Write LED output (offset 24)
    sw $3, 20($1)              # MENU_SEL: Write menu selection to peripheral (offset 20)
    
    # Update previous button state
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

handle_center:
    # Handle menu item selection based on current menu_sel
    bne $3, $0, check_menu1    # If not menu 0, check next
    j menu_mode                # Menu 0: Mode
check_menu1:
    addi $7, $0, 1
    bne $3, $7, check_menu2    # If not menu 1, check next
    j menu_brightness          # Menu 1: Brightness
check_menu2:
    addi $7, $0, 2
    bne $3, $7, check_menu3    # If not menu 2, check next
    j menu_effect              # Menu 2: Effect
check_menu3:
    addi $7, $0, 3
    bne $3, $7, check_menu4    # If not menu 3, check next
    j menu_speed               # Menu 3: Speed
check_menu4:
    addi $7, $0, 4
    bne $3, $7, menu_loop      # If not menu 4, continue
    j menu_reset               # Menu 4: Reset

menu_mode:
    # Toggle between globe (0) and cube (1)
    bne $6, $0, set_globe_mode # If not globe (i.e., cube), switch to globe
    addi $6, $0, 1             # Set to cube
    j write_mode

set_globe_mode:
    addi $6, $0, 0             # Set to globe

write_mode:
    sw $6, 0($1)               # DISP_MODE: Write mode to peripheral (offset 0)
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

menu_brightness:
    # Adjust brightness: cycle through 0%, 25%, 50%, 75%, 100%
    # Brightness values: 0, 64, 128, 192, 255
    addi $7, $0, 0             # Check if brightness = 0
    bne $4, $7, check_bright_64
    j set_bright_25
check_bright_64:
    addi $7, $0, 64            # Check if brightness = 64
    bne $4, $7, check_bright_128
    j set_bright_50
check_bright_128:
    addi $7, $0, 128           # Check if brightness = 128
    bne $4, $7, check_bright_192
    j set_bright_75
check_bright_192:
    addi $7, $0, 192           # Check if brightness = 192
    bne $4, $7, check_bright_255
    j set_bright_100
check_bright_255:
    addi $7, $0, 255           # Check if brightness = 255
    bne $4, $7, set_bright_0_default
    j set_bright_0
set_bright_0_default:
    # Default: set to 0
    addi $4, $0, 0
    j write_brightness

set_bright_0:
    addi $4, $0, 0
    j write_brightness

set_bright_25:
    addi $4, $0, 64            # 25% of 255 ≈ 64
    j write_brightness

set_bright_50:
    addi $4, $0, 128           # 50% of 255 = 128
    j write_brightness

set_bright_75:
    addi $4, $0, 192           # 75% of 255 ≈ 192
    j write_brightness

set_bright_100:
    addi $4, $0, 255           # 100% of 255 = 255
    j write_brightness

write_brightness:
    sw $4, 4($1)               # DISP_BRIGHTNESS: Write brightness to peripheral (offset 4)
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

menu_effect:
    # Cycle through effects: Normal (0), Grayscale (1), Sepia (2), Inverted (3), Rainbow (4)
    addi $7, $0, 0             # EFFECT_NORMAL = 0
    bne $5, $7, check_effect_1
    j set_effect_grayscale
check_effect_1:
    addi $7, $0, 1             # EFFECT_GRAYSCALE = 1
    bne $5, $7, check_effect_2
    j set_effect_sepia
check_effect_2:
    addi $7, $0, 2             # EFFECT_SEPIA = 2
    bne $5, $7, check_effect_3
    j set_effect_inverted
check_effect_3:
    addi $7, $0, 3             # EFFECT_INVERTED = 3
    bne $5, $7, check_effect_4
    j set_effect_rainbow
check_effect_4:
    addi $7, $0, 4             # EFFECT_RAINBOW = 4
    bne $5, $7, set_effect_normal_default
    j set_effect_normal
set_effect_normal_default:
    # Default: set to normal
    addi $5, $0, 0             # EFFECT_NORMAL = 0
    j write_effect

set_effect_normal:
    addi $5, $0, 0             # EFFECT_NORMAL = 0
    j write_effect

set_effect_grayscale:
    addi $5, $0, 1             # EFFECT_GRAYSCALE = 1
    j write_effect

set_effect_sepia:
    addi $5, $0, 2             # EFFECT_SEPIA = 2
    j write_effect

set_effect_inverted:
    addi $5, $0, 3             # EFFECT_INVERTED = 3
    j write_effect

set_effect_rainbow:
    addi $5, $0, 4             # EFFECT_RAINBOW = 4
    j write_effect

write_effect:
    sw $5, 8($1)               # DISP_EFFECT: Write effect to peripheral (offset 8)
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

menu_speed:
    # Speed control (reserved for future use)
    # For now, just acknowledge the selection
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

menu_reset:
    # Reset all settings to defaults
    addi $3, $0, 0             # menu_sel = 0
    addi $4, $0, 255           # brightness = 255 (DEFAULT_BRIGHTNESS)
    addi $5, $0, 0             # effect = 0 (DEFAULT_EFFECT)
    addi $6, $0, 0             # mode = 0 (DEFAULT_MODE)
    
    # Write all defaults to peripheral
    sw $6, 0($1)               # DISP_MODE: Set mode to globe (offset 0)
    sw $4, 4($1)               # DISP_BRIGHTNESS: Set brightness to full (offset 4)
    sw $5, 8($1)               # DISP_EFFECT: Set effect to normal (offset 8)
    sw $3, 20($1)              # MENU_SEL: Set menu selection to 0 (offset 20)
    
    # Update LED display
    addi $7, $0, 1             # LED pattern: bit 0 = 1
    sw $7, 24($1)              # LED_OUT: Write LED output (offset 24)
    
    add $11, $0, $10           # Update previous button state
    j delay_loop               # Delay before next check

delay_loop:
    # Delay loop to debounce buttons and reduce CPU load
    # Delay for approximately 100,000 cycles at 100MHz = 1ms
    addi $14, $0, 0            # Initialize delay counter
    addi $13, $0, 10000        # Loop count (adjust for desired delay)
    
delay_inner:
    addi $14, $14, 1           # Increment counter
    blt $14, $13, delay_inner  # Continue if not done
    
    # After delay, return to menu loop
    j menu_loop                 # Return to main menu loop

# End of program (should never reach here, but included for safety)
end:
    j end                      # Infinite loop

