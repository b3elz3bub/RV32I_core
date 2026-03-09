# ----------------------------------------------------------------------------
# Clock Signal (100MHz Oscillator)
# ----------------------------------------------------------------------------
create_clock -period 10.000 -name clk_100m [get_ports clk_100m]
set_property PACKAGE_PIN Y9 [get_ports {clk_100m}];  #
set_property IOSTANDARD LVCMOS33 [get_ports {clk_100m}]; #

# ----------------------------------------------------------------------------
# Reset Button (Center Pushbutton - BTNC)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN P16 [get_ports {rst_btn}];  #
set_property IOSTANDARD LVCMOS18 [get_ports {rst_btn}]; #

# ----------------------------------------------------------------------------
# User LEDs (LD0 - LD7)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN T22 [get_ports {ld[0]}]
set_property PACKAGE_PIN T21 [get_ports {ld[1]}]
set_property PACKAGE_PIN U22 [get_ports {ld[2]}]
set_property PACKAGE_PIN U21 [get_ports {ld[3]}]
set_property PACKAGE_PIN V22 [get_ports {ld[4]}]
set_property PACKAGE_PIN W22 [get_ports {ld[5]}]
set_property PACKAGE_PIN U19 [get_ports {ld[6]}]
set_property PACKAGE_PIN U14 [get_ports {ld[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ld[*]}]

# ----------------------------------------------------------------------------
# User Switches (SW0 - SW7)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN F22 [get_ports {sw[0]}]
set_property PACKAGE_PIN G22 [get_ports {sw[1]}]
set_property PACKAGE_PIN H22 [get_ports {sw[2]}]
set_property PACKAGE_PIN F21 [get_ports {sw[3]}]
set_property PACKAGE_PIN H19 [get_ports {sw[4]}]
set_property PACKAGE_PIN H18 [get_ports {sw[5]}]
set_property PACKAGE_PIN M15 [get_ports {sw[6]}]
set_property PACKAGE_PIN H17 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[*]}]