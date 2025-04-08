library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_ARITH.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;

entity FlowInitMemory is
  port (
    flow_index : in  integer range 0 to 9; -- Adjust this manually to match NUM_FLOWS
    QP         : out std_logic_vector(23 downto 0);
    max_rate   : out std_logic_vector(8 downto 0);
    cur_rate   : out std_logic_vector(8 downto 0)
  );
end entity;

architecture Behavioral of FlowInitMemory is
  constant NUM_FLOWS : integer := 10;

  type FlowEntry is record
    QP       : std_logic_vector(23 downto 0);
    max_rate : std_logic_vector(8 downto 0);
    cur_rate : std_logic_vector(8 downto 0);
  end record;

  type FlowArray is array (0 to NUM_FLOWS - 1) of FlowEntry;

  constant FLOWS : FlowArray := (
    0 => ("000000000000000000000000", "110000000", "101000000"),
    1 => ("000000000000000000000001", "110000000", "100000000"),
    2 => ("000000000000010000000000", "110000000", "101100000"),
    3 => ("000000000000010000000001", "110000000", "100101010"),
    4 => ("000000000000100000000000", "110000000", "101110000"),
    5 => ("000000000000100000000001", "110000000", "101011110"),
    6 => ("000000000000110000000000", "110000000", "100010000"),
    7 => ("000000000000110000000001", "110000000", "101111111"),
    8 => ("000000000001010000000000", "110000000", "011100000"),
    9 => ("000000000001010000000001", "110000000", "011001010")
  );

begin
  process (flow_index)
  begin
    QP <= FLOWS(flow_index).QP;
    max_rate <= FLOWS(flow_index).max_rate;
    cur_rate <= FLOWS(flow_index).cur_rate;
  end process;

end architecture;
