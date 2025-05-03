library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants

package bram_init_pkg is

  -- Memory
  type flow_mem_type is array (0 to 2 ** FLOW_MEM_ADDR_WIDTH - 1) of std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0);
  type rate_mem_type is array (0 to 2 ** RATE_MEM_ADDR_WIDTH - 1) of std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
  type calendar_mem_type is array (0 to 2 ** CALENDAR_MEM_ADDR_WIDTH - 1) of std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0);

  constant init_flow_mem_16 : flow_mem_type := (
    0  => "1000000000100000",
    1  => "1000000001000001",
    2  => "1000000001100010",
    3  => "1000000010000011",
    4  => "1000000010100100",
    5  => "1000000011000101",
    6  => "1000000011100110",
    7  => "1000000100000111",
    8  => "1000000100101000",
    9  => "1000000101001001",
    10 => "1000000101101010",
    11 => "1000001111101011",
    12 => FLOW_MEM_NULL_ENTRY,
    13 => FLOW_MEM_NULL_ENTRY,
    14 => FLOW_MEM_NULL_ENTRY,
    15 => FLOW_MEM_NULL_ENTRY
  );

  constant init_rate_mem_16 : rate_mem_type := (
    0  => "101001",
    1  => "101001",
    2  => "101001",
    3  => "101001",
    4  => "101001",
    5  => "101001",
    6  => "101001",
    7  => "101001",
    8  => "101001",
    9  => "101001",
    10 => "101001",
    11 => "101001",
    12 => RATE_MEM_NULL_ENTRY,
    13 => RATE_MEM_NULL_ENTRY,
    14 => RATE_MEM_NULL_ENTRY,
    15 => RATE_MEM_NULL_ENTRY
  );

  constant init_calendar_mem_16 : calendar_mem_type := (
    0 => "00000",
    1 => "00001",
    2 => CALENDAR_MEM_NULL_ENTRY,
    3 => "01100",
    4 => CALENDAR_MEM_NULL_ENTRY,
    5 => "00010",
    6 => CALENDAR_MEM_NULL_ENTRY,
    7 => CALENDAR_MEM_NULL_ENTRY
  );

end package;
