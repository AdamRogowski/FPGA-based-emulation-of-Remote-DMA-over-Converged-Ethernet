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
      cnp_flow_id_i  : in std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      -- Data notification input
      data_valid_i   : in std_logic;
      data_flow_id_i : in std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_i    : in unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)
    );
  end component;

  --Inputs
  signal clk            : std_logic                                              := '0';
  signal rst            : std_logic                                              := '0';
  signal cnp_valid_i    : std_logic                                              := '0';
  signal cnp_flow_id_i  : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal data_valid_i   : std_logic                                              := '0';
  signal data_flow_id_i : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal data_sent_i    : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)              := (others => '0');

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
    wait for CLK_PERIOD;

    -- Stimulus 1: Data packet for flow 5
    report "Stimulus 1: Data packet for flow 5";
    data_valid_i <= '1';
    data_flow_id_i <= std_logic_vector(to_unsigned(5, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent_i <= (others => '1');
    wait for CLK_PERIOD;
    data_valid_i <= '0';
    wait for CLK_PERIOD * 10;

    -- Stimulus 2: CNP for flow 5
    report "Stimulus 2: CNP for flow 5";
    cnp_valid_i <= '1';
    cnp_flow_id_i <= std_logic_vector(to_unsigned(5, FLAT_FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    cnp_valid_i <= '0';
    wait for CLK_PERIOD * 20;

    -- Stimulus 3: Data packet for flow 10
    report "Stimulus 3: Data packet for flow 10";
    data_valid_i <= '1';
    data_flow_id_i <= std_logic_vector(to_unsigned(10, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent_i <= (others => '1');
    wait for CLK_PERIOD;
    data_valid_i <= '0';
    wait for CLK_PERIOD * 10;

    -- Stimulus 4: CNP for flow 10
    report "Stimulus 4: CNP for flow 10";
    cnp_valid_i <= '1';
    cnp_flow_id_i <= std_logic_vector(to_unsigned(10, FLAT_FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    cnp_valid_i <= '0';
    wait for CLK_PERIOD * 20;

    -- Stimulus 5: Simultaneous data and CNP for different flows
    report "Stimulus 5: Simultaneous data (flow 2) and CNP (flow 3)";
    data_valid_i <= '1';
    data_flow_id_i <= std_logic_vector(to_unsigned(2, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent_i <= (others => '1');
    cnp_valid_i <= '1';
    cnp_flow_id_i <= std_logic_vector(to_unsigned(3, FLAT_FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    data_valid_i <= '0';
    cnp_valid_i <= '0';
    wait for CLK_PERIOD * 20;

    -- Stimulus 6: Burst of data packets to test queue
    report "Stimulus 6: Burst of data packets for flows 1, 2, 3, 4";
    -- Flow 1
    data_valid_i <= '1';
    data_flow_id_i <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent_i <= (others => '1');
    wait for CLK_PERIOD;
    -- Flow 2
    data_flow_id_i <= std_logic_vector(to_unsigned(2, FLAT_FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    -- Flow 3
    data_flow_id_i <= std_logic_vector(to_unsigned(3, FLAT_FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    -- Flow 4
    data_flow_id_i <= std_logic_vector(to_unsigned(4, FLAT_FLOW_ADDRESS_WIDTH));
    wait for CLK_PERIOD;
    data_valid_i <= '0';
    wait for CLK_PERIOD * 30;

    report "Stimulus 7: Triggering scan and wraparound with flow 15";
    data_valid_i <= '1';
    data_flow_id_i <= std_logic_vector(to_unsigned(15, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent_i <= (others => '1');
    wait for CLK_PERIOD;
    data_valid_i <= '0';
    wait;
  end process;

end architecture;
