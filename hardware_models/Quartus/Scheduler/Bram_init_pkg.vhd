library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants

package bram_init_pkg is

  -- Memory
  type flow_mem_type is array (0 to 2 ** FLOW_MEM_ADDR_WIDTH - 1) of std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0);
  type rate_mem_type is array (0 to 2 ** RATE_MEM_ADDR_WIDTH - 1) of std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
  type calendar_mem_type is array (0 to 2 ** CALENDAR_MEM_ADDR_WIDTH - 1) of std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0);
  type RP_mem_type is array (0 to 2 ** RP_MEM_ADDR_WIDTH - 1) of std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0);

  constant init_flow_mem_262144     : flow_mem_type     := (others => FLOW_MEM_NULL_ENTRY);
  constant init_rate_mem_262144     : rate_mem_type     := (others => RATE_MEM_NULL_ENTRY);
  constant init_calendar_mem_262144 : calendar_mem_type := (others => CALENDAR_MEM_NULL_ENTRY);

end package;
