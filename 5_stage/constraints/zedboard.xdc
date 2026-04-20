# ----------------------------------------------------------------------------
# Clock Signal (100MHz Oscillator)
# ----------------------------------------------------------------------------
create_clock -period 10.0 -name clk_100m -waveform {0.000 5.000} [get_ports clk_100m]
set_property PACKAGE_PIN Y9    [get_ports {clk_100m}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk_100m}]

# ----------------------------------------------------------------------------
# Reset Button (Center Pushbutton - BTNC)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN P16   [get_ports {rst_btn}]
set_property IOSTANDARD LVCMOS18 [get_ports {rst_btn}]

# ----------------------------------------------------------------------------
# User LEDs (LD0 - LD7)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN T22   [get_ports {ld[0]}]
set_property PACKAGE_PIN T21   [get_ports {ld[1]}]
set_property PACKAGE_PIN U22   [get_ports {ld[2]}]
set_property PACKAGE_PIN U21   [get_ports {ld[3]}]
set_property PACKAGE_PIN V22   [get_ports {ld[4]}]
set_property PACKAGE_PIN W22   [get_ports {ld[5]}]
set_property PACKAGE_PIN U19   [get_ports {ld[6]}]
set_property PACKAGE_PIN U14   [get_ports {ld[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ld[*]}]

# ----------------------------------------------------------------------------
# User Switches (SW0 - SW7)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN F22   [get_ports {sw[0]}]
set_property PACKAGE_PIN G22   [get_ports {sw[1]}]
set_property PACKAGE_PIN H22   [get_ports {sw[2]}]
set_property PACKAGE_PIN F21   [get_ports {sw[3]}]
set_property PACKAGE_PIN H19   [get_ports {sw[4]}]
set_property PACKAGE_PIN H18   [get_ports {sw[5]}]
set_property PACKAGE_PIN M15   [get_ports {sw[6]}]
set_property PACKAGE_PIN H17   [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[*]}]

# ----------------------------------------------------------------------------
# UART (PMOD JA — connect USB-TTL adapter to JA header)
#   JA1 (Y11)  -> uart_rx_pin  (FPGA receives, wire to adapter TX)
#   JA2 (AA11) -> uart_tx_pin  (FPGA transmits, wire to adapter RX)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN Y11   [get_ports {uart_rx_pin}]
set_property PACKAGE_PIN AA11  [get_ports {uart_tx_pin}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx_pin}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx_pin}]

# ----------------------------------------------------------------------------
# UART DMA Toggle (debug signal — PMOD JA3, probe with logic analyser)
#   Reassign to a LED or other pin if you want it visible on-board
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN Y10   [get_ports {uart_dma_toggle}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_dma_toggle}]