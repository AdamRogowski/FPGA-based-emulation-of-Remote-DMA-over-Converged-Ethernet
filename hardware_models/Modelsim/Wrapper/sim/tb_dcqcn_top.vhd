library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity tb_dcqcn_top is
end entity;

architecture test of tb_dcqcn_top is

  -- Component declaration for the Device Under Test (DUT)
  component DCQCN_Top is
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      cnp_valid_i    : in  std_logic;
      cnp_flow_id_i  : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      qp_out         : out std_logic_vector(QP_WIDTH - 1 downto 0);
      seq_nr_out     : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
      flow_ready_out : out std_logic
    );
  end component;

  -- Testbench signals
  signal clk_s            : std_logic := '0';
  signal rst_s            : std_logic;
  signal cnp_valid_i_s    : std_logic;
  signal cnp_flow_id_i_s  : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal qp_out_s         : std_logic_vector(QP_WIDTH - 1 downto 0);
  signal seq_nr_out_s     : unsigned(SEQ_NR_WIDTH - 1 downto 0);
  signal flow_ready_out_s : std_logic;

  -- Clock period constant
  constant CLK_PERIOD : time := 5.12 ns;

begin

  -- Instantiate the Device Under Test (DUT)
  dut_inst: DCQCN_Top
    port map (
      clk            => clk_s,
      rst            => rst_s,
      cnp_valid_i    => cnp_valid_i_s,
      cnp_flow_id_i  => cnp_flow_id_i_s,
      qp_out         => qp_out_s,
      seq_nr_out     => seq_nr_out_s,
      flow_ready_out => flow_ready_out_s
    );

  -- Clock generation process
  clk_proc: process
  begin
    clk_s <= '0';
    wait for CLK_PERIOD / 2;
    clk_s <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Stimulus process
  stimulus_proc: process
  begin
    -- 1. Apply reset
    rst_s <= '1';
    cnp_valid_i_s <= '0';
    cnp_flow_id_i_s <= (others => '0');
    wait for CLK_PERIOD * 5;
    rst_s <= '0';
    wait for CLK_PERIOD * 10;
    wait;
  end process;

end architecture;
