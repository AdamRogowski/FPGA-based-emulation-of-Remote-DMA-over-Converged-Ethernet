library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity RP_wrapper is
  port (
    clk                  : in  std_logic;
    rst                  : in  std_logic;
    -- CNP notification input
    cnp_valid_i          : in  std_logic;
    cnp_flow_id_i        : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
    -- Data notification input
    data_valid_i         : in  std_logic;
    data_flow_id_i       : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
    data_sent_i          : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
    -- Rate memory interface
    wrapper_flow_id_o    : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
    wrapper_rate_o       : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    wrapper_rate_valid_o : out std_logic
  );
end entity;

architecture rtl of RP_wrapper is

  constant DIVIDER_LATENCY : natural := 3;

  component RP_input_queue_simplified is
    generic (
      PIPELINE_ADDR_WIDTH : integer := 4;
      FIFO_ADDR_WIDTH     : integer := 4
    );
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      -- CNP notification input
      cnp_valid    : in  std_logic;
      cnp_flow_id  : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      -- Data notification input
      data_valid   : in  std_logic;
      data_flow_id : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent    : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
      -- Interface to RP_flow_update
      flow_rdy_o   : out std_logic;
      is_cnp_o     : out std_logic;
      flow_id_o    : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_o  : out unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)
    );
  end component;

  component RP_Flow_Update is
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      -- Input from packet processing stage
      flow_rdy_i     : in  std_logic;
      is_cnp_i       : in  std_logic;
      flow_id_i      : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_i    : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);

      rate_out       : out unsigned(RP_RATE_WIDTH - 1 downto 0);
      rate_out_valid : out std_logic;
      flow_id_out    : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0)
    );
  end component;

  component rate_2_slot_conv is
    generic (
      PIPELINE_STAGES : natural := DIVIDER_LATENCY;
      INPUT_WIDTH     : natural := RP_RATE_WIDTH;
      OUTPUT_WIDTH    : natural := CALENDAR_SLOTS_WIDTH
    );
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      x_in       : in  unsigned(INPUT_WIDTH - 1 downto 0);
      result_out : out unsigned(OUTPUT_WIDTH - 1 downto 0)
    );
  end component;

  -- Signals from input queue
  signal flow_id_from_queue_reg   : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal data_sent_from_queue_reg : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
  signal is_cnp_reg               : std_logic;
  signal flow_rdy_reg             : std_logic;

  -- Signals from flow update component
  signal rate_out_reg       : unsigned(RP_RATE_WIDTH - 1 downto 0);
  signal rate_out_valid_reg : std_logic;
  signal flow_id_out_reg    : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);

  -- Signals from simple divider
  signal slot_out_reg : unsigned(16 downto 0); -- Output of the divider, 17 bits wide

  -- Synchronization pipeline signals
  -- On purpose the pipeline is larger than the divider latency to adjust for slot_out_reg assignment
  type T_VALID_PIPELINE is array (0 to DIVIDER_LATENCY) of std_logic;
  type T_FLOW_ID_PIPELINE is array (0 to DIVIDER_LATENCY) of std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);

  signal valid_pipeline   : T_VALID_PIPELINE;
  signal flow_id_pipeline : T_FLOW_ID_PIPELINE;

begin

  RP_input_queue_inst: RP_input_queue_simplified
    generic map (
      PIPELINE_ADDR_WIDTH => 4, -- Corresponds to RP_flow_update pipeline depth (RP_PIPELINE_SIZE)
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
      flow_rdy_o   => flow_rdy_reg,
      is_cnp_o     => is_cnp_reg,
      flow_id_o    => flow_id_from_queue_reg,
      data_sent_o  => data_sent_from_queue_reg
    );

  RP_flow_update_inst: RP_Flow_Update
    port map (
      clk            => clk,
      rst            => rst,
      flow_rdy_i     => flow_rdy_reg,
      is_cnp_i       => is_cnp_reg,
      flow_id_i      => flow_id_from_queue_reg,
      data_sent_i    => data_sent_from_queue_reg,
      rate_out       => rate_out_reg,
      rate_out_valid => rate_out_valid_reg,
      flow_id_out    => flow_id_out_reg
    );

  rate_2_slot_conv_inst: rate_2_slot_conv
    generic map (
      PIPELINE_STAGES => DIVIDER_LATENCY,
      INPUT_WIDTH     => RP_RATE_WIDTH,
      OUTPUT_WIDTH    => CALENDAR_SLOTS_WIDTH
    )
    port map (
      clk        => clk,
      rst        => rst,
      x_in       => rate_out_reg,
      result_out => slot_out_reg
    );

  sync_pipeline: process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid_pipeline <= (others => '0');
        flow_id_pipeline <= (others => (others => '0'));
      else
        valid_pipeline(0) <= rate_out_valid_reg;
        flow_id_pipeline(0) <= flow_id_out_reg;
        for i in 1 to DIVIDER_LATENCY loop
          valid_pipeline(i) <= valid_pipeline(i - 1);
          flow_id_pipeline(i) <= flow_id_pipeline(i - 1);
        end loop;
      end if;
    end if;
  end process;

  wrapper_rate_o       <= slot_out_reg;
  wrapper_flow_id_o    <= flow_id_pipeline(DIVIDER_LATENCY);
  wrapper_rate_valid_o <= valid_pipeline(DIVIDER_LATENCY);

end architecture;
