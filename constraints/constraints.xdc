## Clock signal (100 MHz on Nexys A7)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk_100mhz}];

## Buttons
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { btn_start }]; #IO_L4N_T0_D05_14 Sch=btnu
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { btn_reset }]; #IO_L9P_T1_DQS_14 Sch=btnc

## LED Data Output (PMOD JB[1] - connect to level shifter, then to WS2812B DIN)
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { led_data }]; #IO_L1P_T0_AD0P_15 Sch=jb[1] # Pin JB[1]
