set_global_assignment -entity "divider" -library "lib_divider" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "divider" -library "lib_divider" -name IP_TOOL_VERSION "20.1"
set_global_assignment -entity "divider" -library "lib_divider" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_divider" -name SPD_FILE [file join $::quartus(sip_path) "divider.spd"]
set_global_assignment -library "lib_divider" -name MISC_FILE [file join $::quartus(sip_path) "../divider.qsys"]

set_global_assignment -library "lib_divider" -name MISC_FILE [file join $::quartus(sip_path) "sim/divider.vhd"]
set_global_assignment -library "lib_divider" -name MISC_FILE [file join $::quartus(sip_path) "lpm_divide_201/sim/divider_lpm_divide_201_gohehnq.vhd"]
