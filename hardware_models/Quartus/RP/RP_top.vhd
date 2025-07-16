library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity RP_top is
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
end entity;

architecture rtl of RP_top is

  -- Component declaration for the RP_wrapper
  component RP_wrapper is
    port (
      clk                  : in  std_logic;
      rst                  : in  std_logic;
      cnp_valid_i          : in  std_logic;
      cnp_flow_id_i        : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_valid_i         : in  std_logic;
      data_flow_id_i       : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_i          : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
      wrapper_flow_id_o    : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      wrapper_rate_o       : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      wrapper_rate_valid_o : out std_logic
    );
  end component;

  -- Component declaration for the Rate_mem
  component Rate_mem is
    generic (
      LATENCY : integer
    );
    port (
      clk          : in  std_logic;
      ena, enb     : in  std_logic;
      wea, web     : in  std_logic;
      addra, addrb : in  std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      dia, dib     : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
      doa, dob     : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
    );
  end component;

  -- Internal signals to connect the components
  signal wrapper_flow_id_s    : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
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
  Rate_mem_inst: Rate_mem
    generic map (
      LATENCY => RATE_MEM_LATENCY
    )
    port map (
      clk   => clk,
      -- Port A is used for writing the new rate from the wrapper
      ena   => wrapper_rate_valid_s, -- Enable write when the rate is valid
      wea   => wrapper_rate_valid_s, -- Write enable
      addra => wrapper_flow_id_s,
      dia   => std_logic_vector(wrapper_rate_s),
      doa   => open,                 -- Not used in this context
      -- Port B is not used in this top-level module
      enb   => '0',
      web   => '0',
      addrb => (others => '0'),
      dib   => (others => '0'),
      dob   => open
    );

end architecture;
