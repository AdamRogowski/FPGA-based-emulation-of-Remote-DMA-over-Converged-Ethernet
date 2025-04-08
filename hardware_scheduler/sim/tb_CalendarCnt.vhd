library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_ARITH.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;

entity CalendarCnt_tb is
end entity;

architecture TB of CalendarCnt_tb is
  constant CLK_PERIOD : time    := 2 ns;
  constant NUM_SLOTS  : integer := 16;
  constant INTERVAL   : integer := 20;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal cur_slot : integer range 0 to 15;
  signal update   : std_logic;

  -- Instantiate the DUT (Device Under Test)
  component CalendarCnt
    generic (
      NUM_SLOTS : integer := NUM_SLOTS;
      INTERVAL  : integer := INTERVAL -- Smaller value for quicker testing
    );
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      cur_slot : out integer range 0 to 15;
      update   : out std_logic
    );
  end component;

begin
  -- DUT instance
  uut: CalendarCnt
    generic map (NUM_SLOTS, INTERVAL)
    port map (
      clk      => clk,
      rst      => rst,
      cur_slot => cur_slot,
      update   => update
    );

  -- Clock process
  clk_process: process
  begin
    while now < 1000 ns loop
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

    -- Run for a few cycles
    --wait for 1000 ns;

    -- Stop simulation
    --assert false report "Simulation completed" severity failure;
  end process;
end architecture;
