set_global_assignment -entity "divider_optimized" -library "lib_divider_optimized" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "divider_optimized" -library "lib_divider_optimized" -name IP_TOOL_VERSION "20.1"
set_global_assignment -entity "divider_optimized" -library "lib_divider_optimized" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_divider_optimized" -name SPD_FILE [file join $::quartus(sip_path) "divider_optimized.spd"]
set_global_assignment -library "lib_divider_optimized" -name MISC_FILE [file join $::quartus(sip_path) "../divider_optimized.qsys"]

set_global_assignment -library "lib_divider_optimized" -name MISC_FILE [file join $::quartus(sip_path) "sim/divider_optimized.vhd"]
set_global_assignment -library "lib_divider_optimized" -name MISC_FILE [file join $::quartus(sip_path) "lpm_divide_201/sim/divider_optimized_lpm_divide_201_ruc2ypa.vhd"]
