library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity tb_pipelined_stack_processor is
end entity;

architecture sim of tb_pipelined_stack_processor is

  -- Component under test
  component pipelined_stack_processor is
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      qp_o       : out std_logic_vector(QP_WIDTH - 1 downto 0);
      seq_nr_o   : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
      flow_rdy_o : out std_logic
    );
  end component;

  signal clk        : std_logic := '0';
  signal rst        : std_logic := '1';
  signal qp_o       : std_logic_vector(QP_WIDTH - 1 downto 0);
  signal seq_nr_o   : unsigned(SEQ_NR_WIDTH - 1 downto 0);
  signal flow_rdy_o : std_logic;

begin

  -- Clock process
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- DUT instantiation
  dut: pipelined_stack_processor
    port map (
      clk        => clk,
      rst        => rst,
      qp_o       => qp_o,
      seq_nr_o   => seq_nr_o,
      flow_rdy_o => flow_rdy_o
    );

  -- Stimulus process
  stim_proc: process
  begin
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

end architecture;
