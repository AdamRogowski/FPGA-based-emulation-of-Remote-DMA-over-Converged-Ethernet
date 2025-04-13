library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  --  use IEEE.STD_LOGIC_ARITH.all;
  --  use IEEE.STD_LOGIC_UNSIGNED.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity FlowLoader_tb is
end entity;

architecture Behavioral of FlowLoader_tb is

  -- Component declaration
  component FlowLoader
    port (
      clk             : in  std_logic;
      rst             : in  std_logic;
      flow_ready      : out std_logic;
      QP_out          : out std_logic_vector(QP_WIDTH - 1 downto 0);
      max_rate_out    : out std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
      cur_rate_out    : out std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
      seq_nr_out      : out std_logic_vector(SEQ_NR_WIDTH - 1 downto 0);
      next_addr_out   : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      active_flag_out : out std_logic
    );
  end component;

  -- Signals
  signal clk             : std_logic := '0';
  signal rst             : std_logic := '1';
  signal flow_ready      : std_logic;
  signal QP_out          : std_logic_vector(QP_WIDTH - 1 downto 0);
  signal max_rate_out    : std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
  signal cur_rate_out    : std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
  signal seq_nr_out      : std_logic_vector(SEQ_NR_WIDTH - 1 downto 0);
  signal next_addr_out   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal active_flag_out : std_logic;

begin

  -- Clock generation
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Unit under test
  uut: FlowLoader
    port map (
      clk             => clk,
      rst             => rst,
      flow_ready      => flow_ready,
      QP_out          => QP_out,
      max_rate_out    => max_rate_out,
      cur_rate_out    => cur_rate_out,
      seq_nr_out      => seq_nr_out,
      next_addr_out   => next_addr_out,
      active_flag_out => active_flag_out
    );

  -- Reset and monitor process
  stim_proc: process
  begin
    -- Initial reset
    wait for 5 ns;
    rst <= '0';

    --wait;
  end process;

end architecture;
