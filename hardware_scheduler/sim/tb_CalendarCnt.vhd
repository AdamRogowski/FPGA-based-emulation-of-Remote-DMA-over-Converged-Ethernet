library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants from the package

entity CalendarCnt_tb is
end entity;

architecture TB of CalendarCnt_tb is
  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal cur_slot : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal update   : std_logic;

  -- Instantiate the DUT (Device Under Test)
  component CalendarCnt
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      cur_slot : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      update   : out std_logic
    );
  end component;

begin
  -- DUT instance
  uut: CalendarCnt
    port map (
      clk      => clk,
      rst      => rst,
      cur_slot => cur_slot,
      update   => update
    );

  -- Clock process
  clk_process: process
  begin
    while now < 300000 ns loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- Stimulus process
  stim_process: process
  begin
    -- Reset
    wait for 10 ns;
    rst <= '0';

  end process;
end architecture;
