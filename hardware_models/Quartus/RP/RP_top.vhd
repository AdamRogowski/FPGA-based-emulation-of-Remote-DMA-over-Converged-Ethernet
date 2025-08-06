library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity RP_top is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    -- CNP notification input
    cnp_valid_i    : in  std_logic;
    cnp_flow_id_i  : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    -- Data notification input
    data_valid_i   : in  std_logic;
    data_flow_id_i : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    data_sent_i    : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
    -- Rate memory outputs fake just to synthesis
    flow_id_o      : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    rate_o         : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    rate_valid_o   : out std_logic
  );
end entity;

architecture rtl of RP_top is

  -- Component declaration for the RP_wrapper
  component RP_wrapper is
    port (
      clk                  : in  std_logic;
      rst                  : in  std_logic;
      cnp_valid_i          : in  std_logic;
      cnp_flow_id_i        : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_valid_i         : in  std_logic;
      data_flow_id_i       : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_i          : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
      wrapper_flow_id_o    : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      wrapper_rate_o       : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      wrapper_rate_valid_o : out std_logic
    );
  end component;

  -- Component declaration for the Rate_mem
  component Rate_RAM_2_PORT
    port (
      address_a : in  std_logic_vector(17 downto 0);
      address_b : in  std_logic_vector(17 downto 0);
      clock     : in  std_logic := '1';
      data_a    : in  std_logic_vector(16 downto 0);
      data_b    : in  std_logic_vector(16 downto 0);
      rden_a    : in  std_logic := '1';
      rden_b    : in  std_logic := '1';
      wren_a    : in  std_logic := '0';
      wren_b    : in  std_logic := '0';
      q_a       : out std_logic_vector(16 downto 0);
      q_b       : out std_logic_vector(16 downto 0)
    );
  end component;

  -- Internal signals to connect the components
  signal wrapper_flow_id_s    : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal wrapper_rate_s       : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal wrapper_rate_valid_s : std_logic;

begin

  -- Instantiate the RP_wrapper
  RP_wrapper_inst: RP_wrapper
    port map (
      clk                  => clk,
      rst                  => rst,
      cnp_valid_i          => cnp_valid_i,
      cnp_flow_id_i        => cnp_flow_id_i,
      data_valid_i         => data_valid_i,
      data_flow_id_i       => data_flow_id_i,
      data_sent_i          => data_sent_i,
      wrapper_flow_id_o    => wrapper_flow_id_s,
      wrapper_rate_o       => wrapper_rate_s,
      wrapper_rate_valid_o => wrapper_rate_valid_s
    );

  -- Instantiate the Rate_mem
  Rate_mem_inst: Rate_RAM_2_PORT
    port map (
      clock     => clk,
      -- Port A is used for writing the new rate from the wrapper
      wren_a    => wrapper_rate_valid_s, -- Write enable
      address_a => wrapper_flow_id_s(RATE_MEM_ADDR_WIDTH - 1 downto 0),
      data_a    => std_logic_vector(wrapper_rate_s),
      q_a       => open,                 -- Not used in this context
      -- Port B is not used in this top-level module
      rden_b    => '0',
      wren_b    => '0',
      address_b => (others => '0'),
      data_b    => (others => '0'),
      q_b       => open,
      rden_a    => '1' -- Keep read enabled, as per default
    );

  -- Connect internal signals to top-level outputs to prevent pruning
  flow_id_o    <= wrapper_flow_id_s;
  rate_o       <= wrapper_rate_s;
  rate_valid_o <= wrapper_rate_valid_s;

end architecture;
