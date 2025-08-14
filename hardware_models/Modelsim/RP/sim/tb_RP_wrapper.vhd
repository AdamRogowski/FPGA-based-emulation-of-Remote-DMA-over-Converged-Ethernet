library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity tb_RP_wrapper is
end entity;

architecture rtl of tb_RP_wrapper is

  -- Component declaration for the DUT
  component RP_wrapper is
    port (
      clk                  : in  std_logic;
      rst                  : in  std_logic;
      -- CNP notification input
      cnp_valid_i          : in  std_logic;
      cnp_flow_id_i        : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      -- Data notification input
      data_valid_i         : in  std_logic;
      data_flow_id_i       : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_i          : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
      -- Rate memory interface
      wrapper_flow_id_o    : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      wrapper_rate_o       : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      wrapper_rate_valid_o : out std_logic
    );
  end component;

  -- Signals to connect to the DUT
  signal clk_s                  : std_logic := '0';
  signal rst_s                  : std_logic;
  signal cnp_valid_i_s          : std_logic;
  signal cnp_flow_id_i_s        : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal data_valid_i_s         : std_logic;
  signal data_flow_id_i_s       : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal data_sent_i_s          : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
  signal wrapper_flow_id_o_s    : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal wrapper_rate_o_s       : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal wrapper_rate_valid_o_s : std_logic;

  -- Clock period
  constant CLK_PERIOD : time := 10 ns;

begin

  -- Instantiate the DUT
  dut_inst: RP_wrapper
    port map (
      clk                  => clk_s,
      rst                  => rst_s,
      cnp_valid_i          => cnp_valid_i_s,
      cnp_flow_id_i        => cnp_flow_id_i_s,
      data_valid_i         => data_valid_i_s,
      data_flow_id_i       => data_flow_id_i_s,
      data_sent_i          => data_sent_i_s,
      wrapper_flow_id_o    => wrapper_flow_id_o_s,
      wrapper_rate_o       => wrapper_rate_o_s,
      wrapper_rate_valid_o => wrapper_rate_valid_o_s
    );

  -- Clock generation process
  clk_process: process
  begin
    clk_s <= '0';
    wait for CLK_PERIOD / 2;
    clk_s <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Stimulus process
  stimulus_process: process
  begin
    -- 1. Initialize signals
    rst_s <= '1';
    cnp_valid_i_s <= '0';
    cnp_flow_id_i_s <= (others => '0');
    data_valid_i_s <= '0';
    data_flow_id_i_s <= (others => '0');
    data_sent_i_s <= (others => '0');
    wait for CLK_PERIOD * 2;

    -- 2. Apply reset
    rst_s <= '0';
    wait for CLK_PERIOD;

    -- 3. Send a data notification for flow 5
    data_valid_i_s <= '1';
    data_flow_id_i_s <= "0000101";
    data_sent_i_s <= "1";
    wait for CLK_PERIOD;
    data_valid_i_s <= '0';
    data_sent_i_s <= "0";

    -- Wait for some time to let the pipeline process
    wait for CLK_PERIOD;

    -- 4. Send a CNP for flow 5
    cnp_valid_i_s <= '1';
    cnp_flow_id_i_s <= "0000101";
    wait for CLK_PERIOD;
    cnp_valid_i_s <= '0';

    -- Wait for some time to let the pipeline process
    wait for CLK_PERIOD * 20;

    -- 5. Send a data notification for flow 9
    data_valid_i_s <= '1';
    data_flow_id_i_s <= "0001001";
    data_sent_i_s <= "1";
    wait for CLK_PERIOD;
    data_valid_i_s <= '0';
    data_sent_i_s <= "0";

    wait for CLK_PERIOD * 20;

    -- End of simulation
    wait;
  end process;

end architecture;
