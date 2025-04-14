library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  --  use IEEE.STD_LOGIC_ARITH.all;
  --  use IEEE.STD_LOGIC_UNSIGNED.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity FlowInitMemory is
  port (
    flow_index : in  integer range 0 to NUM_FLOWS_TOTAL - 1;
    flow_addr  : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    max_rate   : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate   : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)
  );
end entity;

architecture Behavioral of FlowInitMemory is

  type FlowEntry is record
    flow_addr : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    max_rate  : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate  : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
  end record;

  type FlowArray is array (0 to NUM_FLOWS_TOTAL - 1) of FlowEntry;

  constant FLOWS : FlowArray := (
    0 => ("00000", "1111111111", "0000000111"), -- 4
    1 => ("00001", "1111111111", "0000000100"), -- 4
    2 => ("00010", "1111111111", "0101110111"), -- 3
    3 => ("00011", "1111111111", "0101110100"), -- 3
    4 => ("00100", "1111111111", "1100100000"), -- 2
    5 => ("00101", "1111111111", "1100100011"), -- 2
    6 => ("00110", "1111111111", "0000000110"), -- 4
    7 => ("00111", "1111111111", "0000001111"), -- 4
    8 => ("01000", "1111111111", "1100111111"), -- 2
    9 => ("01001", "1111111111", "1111111000") -- 2
  );

begin
  process (flow_index)
  begin
    flow_addr <= FLOWS(flow_index).flow_addr;
    max_rate <= FLOWS(flow_index).max_rate;
    cur_rate <= FLOWS(flow_index).cur_rate;
  end process;

end architecture;
