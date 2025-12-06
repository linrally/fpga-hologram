set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { clk }]; 
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { ws2812_dout }];  # Pin JB[1]

# Debug ports are simulation-only, exclude from synthesis constraints
# set_property DONT_TOUCH true [get_nets { pixel_color_debug next_px_num_debug }]
