# Clock constraint - 100 MHz oscillator on E3 (Nexys A7)
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { clk }]; 
create_clock -period 10.000 -name sys_clk [get_ports { clk }]

# WS2812B output on Pmod JB1 (D14)
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { ws2812_dout }];  # Pin JB[1]

# Debug ports are simulation-only - do not constrain for synthesis
# These ports will be optimized away during synthesis if not used
# They are only for testbench access during simulation
