# Constrain the main clock
create_clock -name "sys_clk" -period 5.12 [get_ports {clk}]

# Automatically derive clock uncertainty, which is good practice
derive_clock_uncertainty