library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  --  use IEEE.STD_LOGIC_ARITH.all;
  --  use IEEE.STD_LOGIC_UNSIGNED.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity FlowInitMemory is
  port (
    flow_index : in  integer range 0 to NUM_FLOWS_TOTAL - 1;
    QP         : out std_logic_vector(QP_WIDTH - 1 downto 0);
    max_rate   : out std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate   : out std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)
  );
end entity;

architecture Behavioral of FlowInitMemory is

  type FlowEntry is record
    QP       : std_logic_vector(QP_WIDTH - 1 downto 0);
    max_rate : std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate : std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
  end record;

  type FlowArray is array (0 to NUM_FLOWS_TOTAL - 1) of FlowEntry;

  constant FLOWS : FlowArray := (
    0 => ("000000000000000000000000", "1100000000", "1010000000"),
    1 => ("000000000000000000000001", "1100000000", "1000000000"),
    2 => ("000000000000010000000000", "1100000000", "1011000000"),
    3 => ("000000000000010000000001", "1100000000", "1001010100"),
    4 => ("000000000000100000000000", "1100000000", "1011100000"),
    5 => ("000000000000100000000001", "1100000000", "1010111100"),
    6 => ("000000000000110000000000", "1100000000", "1000100000"),
    7 => ("000000000000110000000001", "1100000000", "1011111110"),
    8 => ("000000000001010000000000", "1100000000", "0111000000"),
    9 => ("000000000001010000000001", "1100000000", "0110010100")
  );

begin
  process (flow_index)
  begin
    QP <= FLOWS(flow_index).QP;
    max_rate <= FLOWS(flow_index).max_rate;
    cur_rate <= FLOWS(flow_index).cur_rate;
  end process;

end architecture;
