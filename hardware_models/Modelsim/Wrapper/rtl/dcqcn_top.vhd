library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity DCQCN_Top is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    -- CNP notification input for RP
    cnp_valid_i    : in  std_logic;
    cnp_flow_id_i  : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    -- Final outputs from the system
    qp_out         : out std_logic_vector(QP_WIDTH - 1 downto 0);
    seq_nr_out     : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
    flow_ready_out : out std_logic
  );
end entity;

architecture rtl of DCQCN_Top is

  -- Component for the Scheduler core logic
  component scheduler_pipeline_main is
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      qp_out         : out std_logic_vector(QP_WIDTH - 1 downto 0);
      seq_nr_out     : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
      flow_ready_out : out std_logic;
      rate_mem_ena   : out std_logic;
      rate_mem_wea   : out std_logic;
      rate_mem_addra : out std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      rate_mem_dia   : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
      rate_mem_doa   : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
    );
  end component;

  -- Component for the RP core logic
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

  -- Component for the shared Rate Memory
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

  -- Signals for Scheduler <-> Rate_mem (Port A)
  signal scheduler_rate_mem_ena_s   : std_logic;
  signal scheduler_rate_mem_wea_s   : std_logic;
  signal scheduler_rate_mem_addra_s : std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
  signal scheduler_rate_mem_dia_s   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
  signal scheduler_rate_mem_doa_s   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);

  -- Signals for RP <-> Rate_mem (Port B)
  signal rp_flow_id_s    : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal rp_rate_s       : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal rp_rate_valid_s : std_logic;

  -- Signals for Scheduler -> RP loopback
  signal loopback_qp_s         : std_logic_vector(QP_WIDTH - 1 downto 0);
  signal loopback_flow_ready_s : std_logic;

begin

  -- Instantiate the Scheduler
  scheduler_inst: scheduler_pipeline_main
    port map (
      clk            => clk,
      rst            => rst,
      qp_out         => loopback_qp_s,         -- Internal loopback
      seq_nr_out     => seq_nr_out,            -- To top-level output
      flow_ready_out => loopback_flow_ready_s, -- Internal loopback
      rate_mem_ena   => scheduler_rate_mem_ena_s,
      rate_mem_wea   => scheduler_rate_mem_wea_s,
      rate_mem_addra => scheduler_rate_mem_addra_s,
      rate_mem_dia   => scheduler_rate_mem_dia_s,
      rate_mem_doa   => scheduler_rate_mem_doa_s
    );

  -- Instantiate the Reaction Point
  rp_inst: RP_wrapper
    port map (
      clk                  => clk,
      rst                  => rst,
      cnp_valid_i          => cnp_valid_i,
      cnp_flow_id_i        => cnp_flow_id_i,
      -- Connect loopback signals from Scheduler
      data_valid_i         => loopback_flow_ready_s,
      data_flow_id_i       => loopback_qp_s(FLOW_ADDRESS_WIDTH - 1 downto 0),
      data_sent_i          => (others => '1'), -- Data sent is always 1 byte
      -- Outputs to Rate_mem Port B
      wrapper_flow_id_o    => rp_flow_id_s,
      wrapper_rate_o       => rp_rate_s,
      wrapper_rate_valid_o => rp_rate_valid_s
    );

  -- Instantiate the shared Rate Memory
  rate_mem_inst: Rate_mem
    generic map (
      LATENCY => RATE_MEM_LATENCY
    )
    port map (
      clk   => clk,
      -- Port A connected to the Scheduler
      ena   => scheduler_rate_mem_ena_s,
      wea   => scheduler_rate_mem_wea_s,
      addra => scheduler_rate_mem_addra_s,
      dia   => scheduler_rate_mem_dia_s,
      doa   => scheduler_rate_mem_doa_s,
      -- Port B connected to the RP
      enb   => rp_rate_valid_s,
      web   => rp_rate_valid_s,
      addrb => rp_flow_id_s(RATE_MEM_ADDR_WIDTH - 1 downto 0), -- Slice to match address width
      dib   => std_logic_vector(rp_rate_s),
      dob   => open -- RP does not read from Rate_mem
    );

  -- Connect final outputs
  qp_out         <= loopback_qp_s;
  flow_ready_out <= loopback_flow_ready_s;

end architecture;
