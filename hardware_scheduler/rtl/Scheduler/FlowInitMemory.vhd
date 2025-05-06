library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  --  use IEEE.STD_LOGIC_ARITH.all;
  --  use IEEE.STD_LOGIC_UNSIGNED.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;
  use work.flow_array_pkg.all;

entity FlowInitMemory is
  port (
    flow_index : in  integer range 0 to NUM_FLOWS_TOTAL - 1;
    flow_addr  : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    max_rate   : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate   : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)
  );
end entity;

architecture Behavioral of FlowInitMemory is

begin
  process (flow_index)
  begin
    flow_addr <= FLOWS(flow_index).flow_addr;
    max_rate <= FLOWS(flow_index).max_rate;
    cur_rate <= FLOWS(flow_index).cur_rate;
  end process;

end architecture;
