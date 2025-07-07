library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity RP_wrapper is
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    -- CNP notification input
    cnp_valid_i     : in  std_logic;
    cnp_flow_id_i   : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
    -- Data notification input
    data_valid_i    : in  std_logic;
    data_flow_id_i  : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
    data_sent_i     : in  unsigned(DATA_SENT_WIDTH - 1 downto 0);
    -- Rate memory interface
    rate_mem_addr_o : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
    rate_mem_data_o : out std_logic_vector(RP_RATE_WIDTH - 1 downto 0);
    rate_mem_we_o   : out std_logic
  );
end entity;

architecture rtl of RP_wrapper is

  component RP_input_queue_simplified is
    generic (
      DATA_SENT_WIDTH     : integer := 1;
      NUM_FLOWS_WIDTH     : integer := FLAT_FLOW_ADDRESS_WIDTH;
      PIPELINE_ADDR_WIDTH : integer := 4; -- Corresponds to RP_flow_update pipeline depth
      FIFO_ADDR_WIDTH     : integer := 4
    );
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      -- CNP notification input
      cnp_valid    : in  std_logic;
      cnp_flow_id  : in  std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);
      -- Data notification input
      data_valid   : in  std_logic;
      data_flow_id : in  std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);
      data_sent    : in  unsigned(DATA_SENT_WIDTH - 1 downto 0);
      -- Interface to RP_flow_update
      flow_rdy_o   : out std_logic;
      is_cnp_o     : out std_logic;
      flow_id_o    : out std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);
      data_sent_o  : out unsigned(DATA_SENT_WIDTH - 1 downto 0)
    );
  end component;

  component RP_Flow_Update is
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      -- Input from packet processing stage
      flow_id_in     : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_in   : in  std_logic;
      cnp_in         : in  std_logic;
      input_valid    : in  std_logic;
      -- Output to scheduler
      rate_out       : out std_logic_vector(RP_RATE_WIDTH - 1 downto 0);
      rate_out_valid : out std_logic;
      flow_id_out    : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0)
    );
  end component;

  component simple_divider is
    generic (
      PIPELINE_STAGES : natural := 3;
      INPUT_WIDTH     : natural := 16;
      OUTPUT_WIDTH    : natural := 17
    );
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      x_in       : in  std_logic_vector(INPUT_WIDTH - 1 downto 0);
      result_out : out std_logic_vector(OUTPUT_WIDTH - 1 downto 0)
    );
  end component;

  signal rate_out_signal       : std_logic_vector(RP_RATE_WIDTH - 1 downto 0);
  signal rate_out_valid_signal : std_logic;
  signal flow_id_out_signal    : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);

  -- Signals from the input queue
  signal flow_id_from_queue_signal   : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal data_sent_from_queue_signal : unsigned(DATA_SENT_WIDTH - 1 downto 0);
  signal is_cnp_signal               : std_logic;
  signal flow_rdy_signal             : std_logic;

  -- Synchronization pipeline signals
  constant DIVIDER_LATENCY : natural := 3;
  type T_VALID_PIPELINE is array (0 to DIVIDER_LATENCY - 1) of std_logic;
  type T_FLOW_ID_PIPELINE is array (0 to DIVIDER_LATENCY - 1) of std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);

  signal valid_pipeline   : T_VALID_PIPELINE;
  signal flow_id_pipeline : T_FLOW_ID_PIPELINE;

begin

  RP_input_queue_inst: RP_input_queue_simplified
    generic map (
      DATA_SENT_WIDTH     => RP_DATA_SENT_WIDTH,
      NUM_FLOWS_WIDTH     => FLAT_FLOW_ADDRESS_WIDTH,
      PIPELINE_ADDR_WIDTH => 4, -- Match to RP_flow_update pipeline depth
      FIFO_ADDR_WIDTH     => 4
    )
    port map (
      clk          => clk,
      rst          => rst,
      cnp_valid    => cnp_valid_i,
      cnp_flow_id  => cnp_flow_id_i,
      data_valid   => data_valid_i,
      data_flow_id => data_flow_id_i,
      data_sent    => data_sent_i,
      flow_rdy_o   => flow_rdy_signal,
      is_cnp_o     => is_cnp_signal,
      flow_id_o    => flow_id_from_queue_signal,
      data_sent_o  => data_sent_from_queue_signal
    );

  RP_flow_update_inst: RP_Flow_Update
    port map (
      clk                 => clk,
      rst                 => rst,
      flow_update_valid_i => flow_rdy_signal,
      is_cnp_i            => is_cnp_signal,
      flow_id_i           => flow_id_from_queue_signal,
      data_sent_i         => data_sent_from_queue_signal,
      rate_out            => rate_out_signal,
      rate_out_valid      => rate_out_valid_signal,
      flow_id_out         => flow_id_out_signal
    );

  simple_divider_inst: simple_divider
    generic map (
      PIPELINE_STAGES => 3, -- Or whatever latency is appropriate
      INPUT_WIDTH     => RP_RATE_WIDTH,
      OUTPUT_WIDTH    => 17
    )
    port map (
      clk        => clk,
      rst        => rst,
      x_in       => rate_out_signal,
      result_out => ipg_out
    );

  sync_pipeline: process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid_pipeline <= (others => '0');
        flow_id_pipeline <= (others => (others => '0'));
      else
        valid_pipeline(0) <= rate_out_valid_signal;
        flow_id_pipeline(0) <= flow_id_out_signal;
        for i in 1 to DIVIDER_LATENCY - 1 loop
          valid_pipeline(i) <= valid_pipeline(i - 1);
          flow_id_pipeline(i) <= flow_id_pipeline(i - 1);
        end loop;
      end if;
    end if;
  end process;

  -- Pass through the valid and flow_id signals
  ipg_out_valid <= valid_pipeline(DIVIDER_LATENCY - 1);
  flow_id_out   <= flow_id_pipeline(DIVIDER_LATENCY - 1);

end architecture;
