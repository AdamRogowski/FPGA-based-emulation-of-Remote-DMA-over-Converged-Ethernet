library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity tb_RP_top is
end entity;

architecture behavior of tb_RP_top is

  -- Component Declaration for the Unit Under Test (UUT)
  component RP_top is
    port (
      clk            : in std_logic;
      rst            : in std_logic;
      -- CNP notification input
      cnp_valid_i    : in std_logic;
      cnp_flow_id_i  : in std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      -- Data notification input
      data_valid_i   : in std_logic;
      data_flow_id_i : in std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_i    : in unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)
    );
  end component;

  --Inputs
  signal clk            : std_logic                                         := '0';
  signal rst            : std_logic                                         := '0';
  signal cnp_valid_i    : std_logic                                         := '0';
  signal cnp_flow_id_i  : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal data_valid_i   : std_logic                                         := '0';
  signal data_flow_id_i : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal data_sent_i    : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)         := (others => '0');

begin

  -- Instantiate the Unit Under Test (UUT)
  uut: RP_top
    port map (
      clk            => clk,
      rst            => rst,
      cnp_valid_i    => cnp_valid_i,
      cnp_flow_id_i  => cnp_flow_id_i,
      data_valid_i   => data_valid_i,
      data_flow_id_i => data_flow_id_i,
      data_sent_i    => data_sent_i
    );

  -- Clock process definitions
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Stimulus process
  stim_proc: process
  begin
    -- hold reset state for 100 ns.
    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    wait for CLK_PERIOD * 18;

    -- Stimulus 1: Data packet for flow 5
    --report "Stimulus 1: Data packet for flow 5";
    --data_valid_i <= '1';
    --data_flow_id_i <= std_logic_vector(to_unsigned(5, FLOW_ADDRESS_WIDTH));
    --data_sent_i <= (others => '1');
    --wait for CLK_PERIOD;
    --data_valid_i <= '0';
    --wait for CLK_PERIOD * 10;

    -- Stimulus 2: CNP for flow 5
    report "Stimulus 2: CNP for flow 5";
    cnp_valid_i <= '1';
    cnp_flow_id_i <= std_logic_vector(to_unsigned(5, FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    cnp_valid_i <= '0';
    wait for CLK_PERIOD * 25;

    wait;
  end process;

end architecture;
