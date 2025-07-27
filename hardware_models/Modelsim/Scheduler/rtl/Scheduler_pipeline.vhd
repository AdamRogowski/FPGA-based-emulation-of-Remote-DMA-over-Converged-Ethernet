library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;
  use work.bram_init_pkg.all;

  -- ============================================================================
  -- Entity: scheduler_pipeline_main
  -- Description:
  --   Main scheduler pipeline for DCQCN hardware scheduler.
  --   - Multi-stage pipeline for flow scheduling
  --   - Externalized Rate_mem interface
  --   - Integrated FIFO for overflow/feedback
  --   - Parameterized pipeline depth and memory latencies
  --   - All memory and FIFO accesses are synchronous
  --
  -- Pipeline stages:
  --   0: Issue address to memories
  --   1: Receive memory data
  --   2: Update flow data, insert into calendar
  --   3: Write back to flow_mem
  --
  -- Data formats:
  --   flow_mem: [active_flag, seq_nr, next_addr, cur_addr]
  --   rate_mem: [cur_rate]
  -- ============================================================================

entity scheduler_pipeline_main is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    -- Flow command output
    qp_out         : out std_logic_vector(QP_WIDTH - 1 downto 0);
    seq_nr_out     : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
    flow_ready_out : out std_logic;
    -- External Rate_mem interface
    rate_mem_ena   : out std_logic;
    rate_mem_wea   : out std_logic;
    rate_mem_addra : out std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
    rate_mem_dia   : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
    rate_mem_doa   : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of scheduler_pipeline_main is

  -- ==========================================================================
  -- Component Declarations
  -- ==========================================================================
  component Flow_mem is
    generic (
      LATENCY : integer
    );
    port (
      clk          : in  std_logic;
      ena, enb     : in  std_logic;
      wea, web     : in  std_logic;
      addra, addrb : in  std_logic_vector(FLOW_MEM_ADDR_WIDTH - 1 downto 0);
      dia, dib     : in  std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0);
      doa, dob     : out std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0)
    );
  end component;

  component Calendar is
    port (
      clk                 : in  std_logic;
      rst                 : in  std_logic;
      insert_enable       : in  std_logic;
      insert_slot         : in  unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      insert_data         : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      prev_head_address_o : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      head_address_o      : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      current_slot_o      : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      slot_advance_o      : out std_logic -- Pulse when moving to the next slot
    );
  end component;

  component fifo
    generic (
      DATA_WIDTH : integer := FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH;
      ADDR_WIDTH : integer := OVERFLOW_BUFFER_SIZE
    );
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      append_enable  : in  std_logic;
      new_element    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      pop_enable     : in  std_logic;
      popped_element : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      empty          : out std_logic;
      full           : out std_logic
    );
  end component;

  -- ==========================================================================
  -- Constants and Types
  -- ==========================================================================

  -- Pipeline stage record
  type pipeline_stage_t is record
    cur_addr    : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    next_addr   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    cur_rate    : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    seq_nr      : unsigned(SEQ_NR_WIDTH - 1 downto 0);
    active_flag : std_logic;
    cur_slot    : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  end record;

  type pipeline_array_t is array (0 to SCHEDULER_PIPELINE_SIZE - 1) of pipeline_stage_t;

  -- ==========================================================================
  -- Internal Signals
  -- ==========================================================================

  -- Pipeline registers
  signal pipeline_valid : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := (others => '0');
  signal pipeline       : pipeline_array_t                                       := (others => (
                                           cur_addr    => FLOW_NULL_ADDRESS,
                                           next_addr   => FLOW_NULL_ADDRESS,
                                           cur_rate    => (others => '0'),
                                           seq_nr      => (others => '0'),
                                           active_flag => '0',
                                           cur_slot    => (others => '0')
                                         ));

  -- Flow_mem signals
  signal flow_mem_ena   : std_logic                                          := '0';
  signal flow_mem_wea   : std_logic                                          := '0';
  signal flow_mem_addra : std_logic_vector(FLOW_MEM_ADDR_WIDTH - 1 downto 0) := FLOW_MEM_DEFAULT_ADDRESS;
  signal flow_mem_dia   : std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal flow_mem_doa   : std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');

  signal flow_mem_enb   : std_logic                                          := '0';
  signal flow_mem_web   : std_logic                                          := '0';
  signal flow_mem_addrb : std_logic_vector(FLOW_MEM_ADDR_WIDTH - 1 downto 0) := FLOW_MEM_DEFAULT_ADDRESS;
  signal flow_mem_dib   : std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal flow_mem_dob   : std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');

  -- Calendar signals
  signal calendar_insert_en   : std_logic                                         := '0';
  signal calendar_insert_slot : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)       := (others => '0');
  signal calendar_insert_data : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal calendar_prev_head   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal calendar_head        : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal calendar_cur_slot    : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal calendar_slot_adv    : std_logic;

  -- FIFO signals
  signal fifo_append_en   : std_logic                                                                := '0';
  signal fifo_new_element : std_logic_vector(FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal fifo_pop_en      : std_logic                                                                := '0';
  signal fifo_popped_elem : std_logic_vector(FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal fifo_empty       : std_logic;
  signal fifo_full        : std_logic;
  signal fifo_access      : std_logic_vector(1 downto 0)                                             := (others => '0');
  signal popped_flag      : std_logic                                                                := '0';

  -- Output registers
  signal qp_reg       : std_logic_vector(QP_WIDTH - 1 downto 0) := (others => '0');
  signal seq_nr_reg   : unsigned(SEQ_NR_WIDTH - 1 downto 0)     := (others => '0');
  signal flow_rdy_reg : std_logic                               := '0';

  -- ==========================================================================
  -- Helper Function: Pipeline Ready Pattern Check
  -- ==========================================================================
  function is_pipeline_ready(
      signal valid : std_logic_vector
    ) return boolean is
  begin
    for i in 0 to PIPE_READY_PATTERNS_SIZE - 1 loop
      if valid = PIPE_READY_PATTERNS(i) then
        return true;
      end if;
    end loop;
    return false;
  end function;

begin

  -- ==========================================================================
  -- Component Instantiations
  -- ==========================================================================
  flow_mem_inst: Flow_mem
    generic map (
      LATENCY => FLOW_MEM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => flow_mem_ena,
      wea   => flow_mem_wea,
      addra => flow_mem_addra,
      dia   => flow_mem_dia,
      doa   => flow_mem_doa,
      enb   => flow_mem_enb,
      web   => flow_mem_web,
      addrb => flow_mem_addrb,
      dib   => flow_mem_dib,
      dob   => flow_mem_dob
    );

  calendar_inst: Calendar
    port map (
      clk                 => clk,
      rst                 => rst,
      insert_enable       => calendar_insert_en,
      insert_slot         => calendar_insert_slot,
      insert_data         => calendar_insert_data,
      prev_head_address_o => calendar_prev_head,
      head_address_o      => calendar_head,
      current_slot_o      => calendar_cur_slot,
      slot_advance_o      => calendar_slot_adv
    );

  fifo_inst: fifo
    generic map (
      DATA_WIDTH => FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH,
      ADDR_WIDTH => OVERFLOW_BUFFER_SIZE
    )
    port map (
      clk            => clk,
      rst            => rst,
      append_enable  => fifo_append_en,
      new_element    => fifo_new_element,
      pop_enable     => fifo_pop_en,
      popped_element => fifo_popped_elem,
      empty          => fifo_empty,
      full           => fifo_full
    );

  -- ==========================================================================
  -- Main Pipeline Process

  -- ==========================================================================
  process (clk)
  begin
    if rising_edge(clk) then

      -- Shift pipeline stages
      for i in SCHEDULER_PIPELINE_SIZE - 1 downto 1 loop
        pipeline(i) <= pipeline(i - 1);
        pipeline_valid(i) <= pipeline_valid(i - 1);
      end loop;

      -- Shift FIFO access tracking
      fifo_access(1) <= fifo_access(0);

      -- FIFO append logic: add new element on slot advance
      if calendar_slot_adv = '1' and calendar_head /= FLOW_NULL_ADDRESS then
        fifo_append_en <= '1';
        fifo_new_element <= calendar_head & std_logic_vector(calendar_cur_slot);
      else
        fifo_append_en <= '0';
      end if;

      -- FIFO pop logic: pop if pipeline is ready and FIFO not empty
      if (fifo_empty = '0') and popped_flag = '0' and is_pipeline_ready(pipeline_valid) then
        fifo_pop_en <= '1';
        fifo_access(0) <= '1';
        popped_flag <= '1';
      else
        fifo_pop_en <= '0';
        fifo_access(0) <= '0';
        popped_flag <= '0';
      end if;

      -- Stage -1: input address or feedback
      if fifo_access(1) = '1' then
        pipeline(SCHEDULER_PIPELINE_STAGE_0).cur_slot <= unsigned(fifo_popped_elem(CALENDAR_SLOTS_WIDTH - 1 downto 0));
        pipeline(SCHEDULER_PIPELINE_STAGE_0).cur_addr <= fifo_popped_elem(FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH - 1 downto CALENDAR_SLOTS_WIDTH);
        pipeline_valid(SCHEDULER_PIPELINE_STAGE_0) <= '1';
      elsif pipeline_valid(SCHEDULER_PIPELINE_STAGE_2) = '1' and pipeline(SCHEDULER_PIPELINE_STAGE_2).next_addr /= FLOW_NULL_ADDRESS then
        pipeline(SCHEDULER_PIPELINE_STAGE_0).cur_addr <= pipeline(SCHEDULER_PIPELINE_STAGE_2).next_addr;
        -- pipeline(SCHEDULER_PIPELINE_STAGE_0).cur_slot is taken from the previous stage, from calendar head
        pipeline_valid(SCHEDULER_PIPELINE_STAGE_0) <= '1';
      else
        pipeline_valid(SCHEDULER_PIPELINE_STAGE_0) <= '0';
      end if;

      -- Stage 0: Issue address to both BRAMs
      if pipeline_valid(SCHEDULER_PIPELINE_STAGE_0) = '1' then
        flow_mem_ena <= '1';
        flow_mem_wea <= '0';
        flow_mem_addra <= pipeline(SCHEDULER_PIPELINE_STAGE_0).cur_addr(FLOW_MEM_ADDR_WIDTH - 1 downto 0);

        rate_mem_ena <= '1';
        rate_mem_wea <= '0';
        rate_mem_addra <= pipeline(SCHEDULER_PIPELINE_STAGE_0).cur_addr(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      else
        flow_mem_ena <= '0';
        rate_mem_ena <= '0';
      end if;

      -- Stage 1: BRAMs data arrives
      if pipeline_valid(SCHEDULER_PIPELINE_STAGE_1) = '1' then
        pipeline(SCHEDULER_PIPELINE_STAGE_2).cur_addr <= flow_mem_doa(FLOW_ADDRESS_WIDTH - 1 downto 0);
        pipeline(SCHEDULER_PIPELINE_STAGE_2).next_addr <= flow_mem_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH - 1 downto QP_WIDTH);
        pipeline(SCHEDULER_PIPELINE_STAGE_2).seq_nr <= unsigned(flow_mem_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH + SEQ_NR_WIDTH - 1 downto FLOW_ADDRESS_WIDTH + QP_WIDTH)) + 1;
        pipeline(SCHEDULER_PIPELINE_STAGE_2).active_flag <= flow_mem_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH + SEQ_NR_WIDTH);
        pipeline(SCHEDULER_PIPELINE_STAGE_2).cur_rate <= unsigned(rate_mem_doa(CALENDAR_SLOTS_WIDTH - 1 downto 0));
      end if;

      -- Stage 2: update flow data and insert into calendar
      if pipeline_valid(SCHEDULER_PIPELINE_STAGE_2) = '1' then
        calendar_insert_en <= '1';
        -- Insert into calendar at current slot + rate
        -- Should be check that slot + rate > calendar_cur_slot (insert slot does not refer to the past, in a corner case of high rate flow being blocked by long chain); ommitted as not probable
        calendar_insert_slot <= (pipeline(SCHEDULER_PIPELINE_STAGE_2).cur_slot + pipeline(SCHEDULER_PIPELINE_STAGE_2).cur_rate) and to_unsigned(CALENDAR_SLOTS - 1, CALENDAR_SLOTS_WIDTH);
        calendar_insert_data <= pipeline(SCHEDULER_PIPELINE_STAGE_2).cur_addr;
        if pipeline(SCHEDULER_PIPELINE_STAGE_2).active_flag = '1' then
          qp_reg <= QP_PADDING & pipeline(SCHEDULER_PIPELINE_STAGE_2).cur_addr;
          seq_nr_reg <= pipeline(SCHEDULER_PIPELINE_STAGE_2).seq_nr;
          flow_rdy_reg <= '1';
        end if;
      else
        calendar_insert_en <= '0';
        --qp_reg <= QP_PADDING & FLOW_NULL_ADDRESS;
        --seq_nr_reg <= (others => '0');
        flow_rdy_reg <= '0';
      end if;

      -- Stage 3: write back to flow_mem with updated next_addr
      if pipeline_valid(SCHEDULER_PIPELINE_STAGE_3) = '1' then
        flow_mem_enb <= '1';
        flow_mem_web <= '1';
        flow_mem_addrb <= pipeline(SCHEDULER_PIPELINE_STAGE_3).cur_addr(FLOW_MEM_ADDR_WIDTH - 1 downto 0);
        flow_mem_dib <= pipeline(SCHEDULER_PIPELINE_STAGE_3).active_flag & std_logic_vector(pipeline(SCHEDULER_PIPELINE_STAGE_3).seq_nr) & calendar_prev_head & QP_PADDING & pipeline(SCHEDULER_PIPELINE_STAGE_3).cur_addr;
      else
        flow_mem_enb <= '0';
        flow_mem_web <= '0';
      end if;

      -- Synchronous reset
      if rst = '1' then
        pipeline_valid <= (others => '0');
        flow_mem_ena <= '0';
        flow_mem_wea <= '0';
        flow_mem_addra <= FLOW_MEM_DEFAULT_ADDRESS;
        flow_mem_dia <= (others => '0');
        flow_mem_enb <= '0';
        flow_mem_web <= '0';
        flow_mem_addrb <= FLOW_MEM_DEFAULT_ADDRESS;
        flow_mem_dib <= (others => '0');
        rate_mem_ena <= '0';
        rate_mem_wea <= '0';
        rate_mem_addra <= RATE_MEM_DEFAULT_ADDRESS;
        rate_mem_dia <= (others => '0');
        qp_reg <= (others => '0');
        seq_nr_reg <= (others => '0');
        flow_rdy_reg <= '0';
      end if;
    end if;
  end process;

  -- ==========================================================================
  -- Output Assignments
  -- ==========================================================================
  qp_out         <= qp_reg;
  seq_nr_out     <= seq_nr_reg;
  flow_ready_out <= flow_rdy_reg;

end architecture;
