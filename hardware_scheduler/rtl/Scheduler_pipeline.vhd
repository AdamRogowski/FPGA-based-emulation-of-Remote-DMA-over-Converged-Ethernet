library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity pipelined_stack_processor is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    head_update : in  std_logic;
    head_addr   : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    done        : out std_logic
  );
end entity;

architecture rtl of pipelined_stack_processor is

  -- BRAM component declaration
  component bram_model is
    generic (
      DATA_WIDTH : integer;
      ADDR_WIDTH : integer;
      LATENCY    : integer
    );
    port (
      clk   : in  std_logic;
      ena   : in  std_logic;
      enb   : in  std_logic;
      wea   : in  std_logic;
      web   : in  std_logic;
      addra : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
      addrb : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
      dia   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      dib   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      doa   : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      dob   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
  end component;

  constant QP_padding : std_logic_vector(QP_WIDTH - FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0'); -- Padding for QP

  -- Pipeline registers
  type pipe_stage is record
    valid       : std_logic;
    --qp          : std_logic_vector(QP_WIDTH - 1 downto 0); qp ommitted in the pipeline, current address is used instead
    cur_addr    : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    next_addr   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    max_rate    : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate    : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    seq_nr      : unsigned(SEQ_NR_WIDTH - 1 downto 0);
    active_flag : std_logic;
    --data        : std_logic_vector(DATA_WIDTH - 1 downto 0);
    --processed : std_logic_vector(DATA_WIDTH - 1 downto 0);
  end record;

  type pipe_type is array (0 to PIPELINE_SIZE - 1) of pipe_stage;

  signal pipe_valid : std_logic_vector(PIPELINE_SIZE - 1 downto 0) := (others => '0');
  signal pipe       : pipe_type                                    := (others => (valid => '0', cur_addr => FLOW_NULL_ADDRESS, next_addr => FLOW_NULL_ADDRESS, max_rate => (others => '0'), cur_rate => (others => '0'), seq_nr => (others => '0'), active_flag => '0'));

  -- Internal BRAM signals
  signal bram_ena   : std_logic                                      := '0';
  signal bram_wea   : std_logic                                      := '0';
  signal bram_addra : std_logic_vector(BRAM_ADDR_WIDTH - 1 downto 0) := FLOW_NULL_ADDRESS;
  signal bram_dia   : std_logic_vector(BRAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal bram_doa   : std_logic_vector(BRAM_DATA_WIDTH - 1 downto 0) := (others => '0');

begin

  -- Instantiate the BRAM internally
  bram_inst: bram_model
    generic map (
      DATA_WIDTH => BRAM_DATA_WIDTH,
      ADDR_WIDTH => BRAM_ADDR_WIDTH,
      LATENCY    => BRAM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => bram_ena,
      wea   => bram_wea,
      addra => bram_addra,
      dia   => bram_dia,
      doa   => bram_doa,
      enb   => '0',
      web   => '0',
      addrb => FLOW_NULL_ADDRESS,
      dib   => (others => '0'),
      dob   => open
    );

  -- Main pipeline logic
  process (clk)
  begin

    if rising_edge(clk) then

      -- Shift pipeline stages
      for i in PIPELINE_SIZE - 1 downto 1 loop
        pipe(i) <= pipe(i - 1);
        pipe_valid(i) <= pipe_valid(i - 1);
      end loop;

      -- Stage 0: input address or feedback
      if head_update = '1' then
        pipe(0).cur_addr <= head_addr;
        pipe_valid(0) <= '1';
      elsif pipe_valid(BRAM_LATENCY + 2) = '1' and pipe(BRAM_LATENCY + 2).next_addr /= FLOW_NULL_ADDRESS then
        pipe(0).cur_addr <= pipe(BRAM_LATENCY + 2).next_addr;
        pipe_valid(0) <= '1';
      else
        pipe_valid(0) <= '0';
      end if;

      -- Stage 0 issues address to BRAM
      if pipe_valid(0) = '1' then
        bram_ena <= '1';
        bram_wea <= '0';
        bram_addra <= std_logic_vector(resize(unsigned(pipe(0).cur_addr(BRAM_ADDR_WIDTH - 1 downto 0)), BRAM_ADDR_WIDTH));
      else
        bram_ena <= '0';
      end if;

      -- Stage 3: BRAM data arrives
      -- The BRAM data is expected to be in the format:
      -- msb -> lsb
      -- [active_flag, seq_nr, cur_rate, max_rate, next_addr, cur_addr]
      -- [ 1, SEQ_NR_WIDTH, RATE_BIT_RESOLUTION_WIDTH, RATE_BIT_RESOLUTION_WIDTH, FLOW_ADDRESS_WIDTH, QP_WIDTH[empty bits, FLOW_ADDRESS_WIDTH]]
      if pipe_valid(BRAM_LATENCY + 1) = '1' then
        pipe(BRAM_LATENCY + 2).cur_addr <= bram_doa(FLOW_ADDRESS_WIDTH - 1 downto 0);
        pipe(BRAM_LATENCY + 2).next_addr <= bram_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH - 1 downto QP_WIDTH);
        pipe(BRAM_LATENCY + 2).max_rate <= unsigned(bram_doa(RATE_BIT_RESOLUTION_WIDTH + FLOW_ADDRESS_WIDTH + QP_WIDTH - 1 downto FLOW_ADDRESS_WIDTH + QP_WIDTH));
        pipe(BRAM_LATENCY + 2).cur_rate <= unsigned(bram_doa(2 * RATE_BIT_RESOLUTION_WIDTH + FLOW_ADDRESS_WIDTH + QP_WIDTH - 1 downto RATE_BIT_RESOLUTION_WIDTH + FLOW_ADDRESS_WIDTH + QP_WIDTH));
        pipe(BRAM_LATENCY + 2).seq_nr <= unsigned(bram_doa(2 * RATE_BIT_RESOLUTION_WIDTH + FLOW_ADDRESS_WIDTH + QP_WIDTH + SEQ_NR_WIDTH - 1 downto 2 * RATE_BIT_RESOLUTION_WIDTH + FLOW_ADDRESS_WIDTH + QP_WIDTH));
        pipe(BRAM_LATENCY + 2).active_flag <= bram_doa(2 * RATE_BIT_RESOLUTION_WIDTH + FLOW_ADDRESS_WIDTH + QP_WIDTH + SEQ_NR_WIDTH);
      end if;

      -- Stage 4: process 1
      if pipe_valid(BRAM_LATENCY + 2) = '1' then
        pipe(BRAM_LATENCY + 3).seq_nr <= pipe(BRAM_LATENCY + 2).seq_nr + 1;
      end if;

      -- Stage 5: process 2
      --if pipe_valid(BRAM_LATENCY + 2) = '1' then
      --  pipe(BRAM_LATENCY + 3).seq_nr <= pipe(BRAM_LATENCY + 3).seq_nr - 1;
      --end if;

      -- Stage 6: writeback
      if pipe_valid(BRAM_LATENCY + 4) = '1' then
        bram_ena <= '1';
        bram_wea <= '1';
        bram_addra <= std_logic_vector(resize(unsigned(pipe(BRAM_LATENCY + 4).cur_addr(BRAM_ADDR_WIDTH - 1 downto 0)), BRAM_ADDR_WIDTH));
        bram_dia <= pipe(BRAM_LATENCY + 4).active_flag & std_logic_vector(pipe(BRAM_LATENCY + 4).seq_nr) & std_logic_vector(pipe(BRAM_LATENCY + 4).cur_rate) & std_logic_vector(pipe(BRAM_LATENCY + 4).max_rate) & pipe(BRAM_LATENCY + 4).next_addr & QP_padding & pipe(BRAM_LATENCY + 4).cur_addr;
      else
        bram_wea <= '0';
      end if;

      -- Done when reaching a null pointer
      if pipe_valid(BRAM_LATENCY + 2) = '1' and pipe(BRAM_LATENCY + 2).next_addr = FLOW_NULL_ADDRESS then
        done <= '1';
      else
        done <= '0';
      end if;

      if rst = '1' then
        pipe_valid <= (others => '0');
        bram_ena <= '0';
        bram_wea <= '0';
        bram_addra <= FLOW_NULL_ADDRESS;
        bram_dia <= (others => '0');
        done <= '0';
      end if;

    end if;
  end process;

end architecture;
