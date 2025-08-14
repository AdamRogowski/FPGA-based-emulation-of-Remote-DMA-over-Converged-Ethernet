library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity Calendar_tb is
end entity;

architecture TB of Calendar_tb is

  -- DUT signals
  signal clk                 : std_logic                                         := '0';
  signal rst                 : std_logic                                         := '1';
  signal insert_enable       : std_logic                                         := '0';
  signal insert_slot         : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)       := (others => '0');
  signal insert_data         : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal prev_head_address_o : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal head_address_o      : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal current_slot_o      : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal slot_advance_o      : std_logic;

begin

  -- DUT
  DUT: entity work.Calendar
    port map (
      clk                 => clk,
      rst                 => rst,
      insert_enable       => insert_enable,
      insert_slot         => insert_slot,
      insert_data         => insert_data,
      prev_head_address_o => prev_head_address_o,
      head_address_o      => head_address_o,
      current_slot_o      => current_slot_o,
      slot_advance_o      => slot_advance_o
    );

  -- Clock generation
  clk_process: process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- Stimulus
  stim_process: process
  begin
    -- Reset
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait for CLK_PERIOD;

    -- Insert into slot 3
    insert_enable <= '1';
    insert_slot <= to_unsigned(3, CALENDAR_SLOTS_WIDTH);
    insert_data <= "01010";
    wait for CLK_PERIOD;
    insert_enable <= '0';

    -- Wait a bit
    wait for 5 * CLK_PERIOD;

    -- Insert into slot 5
    insert_enable <= '1';
    insert_slot <= to_unsigned(5, CALENDAR_SLOTS_WIDTH);
    insert_data <= "01100";
    wait for CLK_PERIOD;
    insert_enable <= '0';

    -- Wait for multiple calendar advances
    wait for 50 * CLK_PERIOD;

    -- Insert into slot 0
    insert_enable <= '1';
    insert_slot <= to_unsigned(0, CALENDAR_SLOTS_WIDTH);
    insert_data <= "00001";
    wait for CLK_PERIOD;
    insert_enable <= '0';

    wait;
  end process;

end architecture;
