library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants

package bram_init_pkg is

  -- Memory
  type flow_mem_type is array (0 to 2 ** 4 - 1) of std_logic_vector(16 - 1 downto 0);
  type rate_mem_type is array (0 to 2 ** 4 - 1) of std_logic_vector(3 - 1 downto 0);
  type calendar_mem_type is array (0 to 2 ** 3 - 1) of std_logic_vector(5 - 1 downto 0);

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
    12 => "1000001111101011",
    13 => "1000001111101011",
    14 => "1000001111101011",
    15 => "1000001111101011"
  );

  constant init_rate_mem_16 : rate_mem_type := (
    0  => "111",
    1  => "111",
    2  => "111",
    3  => "111",
    4  => "111",
    5  => "111",
    6  => "111",
    7  => "111",
    8  => "111",
    9  => "110",
    10 => "110",
    11 => "110",
    --11 => "100001", -- Test values for scheduler
    12 => "111",
    13 => "111",
    14 => "111",
    15 => "111"
  );

  constant init_calendar_mem_16 : calendar_mem_type := (
    0 => "00000",
    1 => "11111",
    2 => "11111",
    3 => "11111",
    4 => "11111",
    5 => "11111",
    6 => "11111",
    7 => "11111"
  );

end package;
