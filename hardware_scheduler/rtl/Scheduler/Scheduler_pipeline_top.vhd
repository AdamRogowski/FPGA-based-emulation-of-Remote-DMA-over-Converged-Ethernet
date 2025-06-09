library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity Scheduler_pipeline_top is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    qp_out         : out std_logic_vector(QP_WIDTH - 1 downto 0);
    seq_nr_out     : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
    flow_ready_out : out std_logic
      -- Optionally, expose Rate_mem port B here if needed
  );
end entity;

architecture rtl of Scheduler_pipeline_top is

  -- Internal signals for Rate_mem port A
  signal rate_mem_ena   : std_logic;
  signal rate_mem_wea   : std_logic;
  signal rate_mem_addra : std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
  signal rate_mem_dia   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
  signal rate_mem_doa   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);

  -- Unused Rate_mem port B signals (can be exposed if needed)
  signal rate_mem_enb   : std_logic                                          := '0';
  signal rate_mem_web   : std_logic                                          := '0';
  signal rate_mem_addrb : std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0) := RATE_MEM_DEFAULT_ADDRESS;
  signal rate_mem_dib   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal rate_mem_dob   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);

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

  component Rate_mem is
    generic (
      LATENCY : integer := 3
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

begin

  -- Instantiate the scheduler pipeline
  scheduler_inst: scheduler_pipeline_main
    port map (
      clk            => clk,
      rst            => rst,
      qp_out         => qp_out,
      seq_nr_out     => seq_nr_out,
      flow_ready_out => flow_ready_out,
      rate_mem_ena   => rate_mem_ena,
      rate_mem_wea   => rate_mem_wea,
      rate_mem_addra => rate_mem_addra,
      rate_mem_dia   => rate_mem_dia,
      rate_mem_doa   => rate_mem_doa
    );

  -- Instantiate Rate_mem
  rate_mem_inst: Rate_mem
    generic map (
      LATENCY => RATE_MEM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => rate_mem_ena,
      wea   => rate_mem_wea,
      addra => rate_mem_addra,
      dia   => rate_mem_dia,
      doa   => rate_mem_doa,
      enb   => rate_mem_enb,
      web   => rate_mem_web,
      addrb => rate_mem_addrb,
      dib   => rate_mem_dib,
      dob   => rate_mem_dob
    );

end architecture;
