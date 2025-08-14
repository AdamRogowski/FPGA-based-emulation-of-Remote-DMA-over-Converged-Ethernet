library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity tb_Scheduler_pipeline_top is
end entity;

architecture sim of tb_Scheduler_pipeline_top is

  -- Component under test
  component Scheduler_pipeline_top is
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      qp_out         : out std_logic_vector(QP_WIDTH - 1 downto 0);
      seq_nr_out     : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
      flow_ready_out : out std_logic
    );
  end component;

  signal clk            : std_logic := '0';
  signal rst            : std_logic := '1';
  signal qp_out         : std_logic_vector(QP_WIDTH - 1 downto 0);
  signal seq_nr_out     : unsigned(SEQ_NR_WIDTH - 1 downto 0);
  signal flow_ready_out : std_logic;

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
  dut: Scheduler_pipeline_top
    port map (
      clk            => clk,
      rst            => rst,
      qp_out         => qp_out,
      seq_nr_out     => seq_nr_out,
      flow_ready_out => flow_ready_out
    );

  -- Stimulus process
  stim_proc: process
  begin
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

end architecture;
