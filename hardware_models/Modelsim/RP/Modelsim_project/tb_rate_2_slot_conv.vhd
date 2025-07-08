library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_rate_2_slot_conv is
end entity;

architecture sim of tb_rate_2_slot_conv is

  signal clk        : std_logic                     := '0';
  signal rst        : std_logic                     := '1';
  signal x_in       : std_logic_vector(15 downto 0) := (others => '0');
  signal result_out : std_logic_vector(16 downto 0);

  component rate_2_slot_conv
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      x_in       : in  std_logic_vector(15 downto 0);
      result_out : out std_logic_vector(16 downto 0)
    );
  end component;

begin

  uut: rate_2_slot_conv
    port map (
      clk        => clk,
      rst        => rst,
      x_in       => x_in,
      result_out => result_out
    );

  -- Clock generation
  clk_process: process
  begin
    while now < 1 ms loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end loop;
    wait;
  end process;

  -- Stimulus
  stim_proc: process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';

    -- Test a few input values
    x_in <= x"0100"; -- 256
    wait for 10 ns;
    -- Expected: 23437500 / 256 = 91552
    x_in <= x"0200"; -- 512
    wait for 10 ns;
    -- Expected: 23437500 / 512 = 45776
    x_in <= x"FFFF"; -- 65535
    wait for 10 ns;
    -- Expected: 23437500 / 65535 = 357
    x_in <= x"0001"; -- 1
    wait for 10 ns;
    -- Expected: 23437500 / 1 = 23437500 (will overflow 17 bits, should saturate)
    x_in <= (others => '0'); -- 0
    wait for 10 ns;
    -- Expected: Max value
    wait for 100 ns;
    wait;
  end process;

end architecture;
