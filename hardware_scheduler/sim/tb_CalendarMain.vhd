library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  --  use IEEE.STD_LOGIC_ARITH.all;
  --  use IEEE.STD_LOGIC_UNSIGNED.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity tb_CalendarMain is
end entity;

architecture Testbench of tb_CalendarMain is

  -- DUT ports
  signal clk        : std_logic := '0';
  signal rst        : std_logic := '1';
  signal QP_out     : std_logic_vector(QP_WIDTH - 1 downto 0);
  signal seq_nr_out : std_logic_vector(SEQ_NR_WIDTH - 1 downto 0);

  -- DUT instance
  component CalendarMain
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      QP_out     : out std_logic_vector(QP_WIDTH - 1 downto 0);
      seq_nr_out : out std_logic_vector(SEQ_NR_WIDTH - 1 downto 0)
    );
  end component;

begin

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

  -- DUT instantiation
  DUT: CalendarMain
    port map (
      clk        => clk,
      rst        => rst,
      QP_out     => QP_out,
      seq_nr_out => seq_nr_out
    );

  -- Stimulus process
  stimulus: process
  begin
    -- Initial reset
    wait for 20 ns;
    rst <= '0';
  end process;

end architecture;
