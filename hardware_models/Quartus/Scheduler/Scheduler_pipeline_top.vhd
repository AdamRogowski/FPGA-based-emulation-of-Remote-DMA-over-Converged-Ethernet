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

  component Rate_RAM_2_PORT is
    port (
      address_a : in  std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      address_b : in  std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      clock     : in  std_logic;
      data_a    : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
      data_b    : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
      rden_a    : in  std_logic;
      rden_b    : in  std_logic;
      wren_a    : in  std_logic;
      wren_b    : in  std_logic;
      q_a       : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
      q_b       : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
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

  -- Rate memory instantiation
  Rate_ram_inst: Rate_RAM_2_PORT
    port map (
      address_a => rate_mem_addra,
      address_b => rate_mem_addrb,
      clock     => clk,
      data_a    => rate_mem_dia,
      data_b    => rate_mem_dib,
      rden_a    => rate_mem_ena, -- <<== enable read
      rden_b    => rate_mem_enb, -- <<== enable read
      wren_a    => rate_mem_wea, -- <<== write enable
      wren_b    => rate_mem_web, -- <<== write enable
      q_a       => rate_mem_doa,
      q_b       => rate_mem_dob
    );

end architecture;
