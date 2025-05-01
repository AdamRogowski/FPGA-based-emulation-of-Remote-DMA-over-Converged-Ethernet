-- Testbench for the Calendar module

library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity Calendar_tb is
end entity;

architecture TB of Calendar_tb is

  signal clk            : std_logic                                         := '0';
  signal rst            : std_logic                                         := '1';
  signal insert_enable  : std_logic                                         := '0';
  signal insert_slot    : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)       := (others => '0');
  signal insert_address : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal current_slot_o : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal head_address_o : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal slot_advance_o : std_logic;

  constant CLK_PERIOD : time := 10 ns;

begin

  -- Clock process
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Instantiate Calendar
  DUT: entity work.Calendar
    port map (
      clk            => clk,
      rst            => rst,
      insert_enable  => insert_enable,
      insert_slot    => insert_slot,
      insert_address => insert_address,
      current_slot_o => current_slot_o,
      head_address_o => head_address_o,
      slot_advance_o => slot_advance_o
    );

  -- Stimulus process
  stim_proc: process
  begin
    -- Reset
    wait for 20 ns;
    rst <= '0';

    -- Insert flow into slot 3
    wait for 10 ns;
    insert_enable <= '1';
    insert_slot <= to_unsigned(3, CALENDAR_SLOTS_WIDTH);
    insert_address <= "00110";
    wait for CLK_PERIOD;
    insert_enable <= '0';

    -- Insert flow into slot 5
    wait for 10 ns;
    insert_enable <= '1';
    insert_slot <= to_unsigned(5, CALENDAR_SLOTS_WIDTH);
    insert_address <= "01100";
    wait for CLK_PERIOD;
    insert_enable <= '0';

    -- Finish simulation
    wait;
  end process;

end architecture;
