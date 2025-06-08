library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;
  use work.bram_init_pkg.all; -- Import constants

entity pipelined_stack_processor is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    -- Flow cmd output
    qp_o           : out std_logic_vector(QP_WIDTH - 1 downto 0);
    seq_nr_o       : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
    flow_rdy_o     : out std_logic;
    -- External Rate_mem interface
    rate_mem_ena   : out std_logic;
    rate_mem_wea   : out std_logic;
    rate_mem_addra : out std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
    rate_mem_dia   : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
    rate_mem_doa   : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of pipelined_stack_processor is

  -- BRAM component declaration
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
      ADDR_WIDTH : integer := 2
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

  constant QP_padding : std_logic_vector(QP_WIDTH - FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0'); -- Padding for QP

  -- Pipeline registers
  type pipe_stage is record
    --qp          : std_logic_vector(QP_WIDTH - 1 downto 0); qp ommitted in the pipeline, current address is used instead
    cur_addr    : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    next_addr   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    cur_rate    : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    seq_nr      : unsigned(SEQ_NR_WIDTH - 1 downto 0);
    active_flag : std_logic;
    cur_slot    : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0); -- Current slot in the calendar
  end record;

  type pipe_type is array (0 to SCHEDULER_PIPELINE_SIZE - 1) of pipe_stage;

  signal pipe_valid : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := (others => '0');
  signal pipe       : pipe_type                                              := (others => (cur_addr => FLOW_NULL_ADDRESS, next_addr => FLOW_NULL_ADDRESS, cur_rate => (others => '0'), seq_nr => (others => '0'), active_flag => '0', cur_slot => (others => '0')));

  -- Internal flow_mem signals
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
  signal insert_enable       : std_logic                                         := '0';
  signal insert_slot         : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)       := (others => '0');
  signal insert_data         : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal prev_head_address_o : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal head_address_o      : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal current_slot_o      : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal slot_advance_o      : std_logic;

  -- Fifo signals
  signal append_enable  : std_logic                                                                := '0';
  signal new_element    : std_logic_vector(FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal pop_enable     : std_logic                                                                := '0';
  signal popped_element : std_logic_vector(FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH - 1 downto 0);
  signal empty          : std_logic;
  signal full           : std_logic;

  --signal slot_advance_rdy : std_logic                        := '0'; -- Ready signal for slot advance operation
  signal fifo_access : std_logic_vector(2 - 1 downto 0) := (others => '0');

  -- Output signals
  signal qp_s       : std_logic_vector(QP_WIDTH - 1 downto 0) := (others => '0');
  signal seq_nr_s   : unsigned(SEQ_NR_WIDTH - 1 downto 0)     := (others => '0');
  signal flow_rdy_s : std_logic                               := '0';

begin

  -- Instantiate the BRAM internally
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

  -- Instantiate Calendar
  calendar_inst: Calendar
    port map (
      clk                 => clk,
      rst                 => rst,
      insert_enable       => insert_enable,
      insert_slot         => insert_slot,
      insert_data         => insert_data,
      prev_head_address_o => prev_head_address_o,
      head_address_o      => head_address_o,
      current_slot_o      => current_slot_o,
      slot_advance_o      => slot_advance_o
    );

  fifo_instance: fifo
    generic map (
      DATA_WIDTH => FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH,
      ADDR_WIDTH => 2
    )
    port map (
      clk            => clk,
      rst            => rst,
      append_enable  => append_enable,
      new_element    => new_element,
      pop_enable     => pop_enable,
      popped_element => popped_element,
      empty          => empty,
      full           => full
    );

  -- Main pipeline logic
  process (clk)
  begin

    if rising_edge(clk) then

      -- Shift pipeline stages
      for i in SCHEDULER_PIPELINE_SIZE - 1 downto 1 loop
        pipe(i) <= pipe(i - 1);
        pipe_valid(i) <= pipe_valid(i - 1);
      end loop;

      -- Shift fifo access
      fifo_access(1) <= fifo_access(0);
      if slot_advance_o = '1' and head_address_o /= FLOW_NULL_ADDRESS then
        append_enable <= '1';
        new_element <= head_address_o & std_logic_vector(current_slot_o);
      else
        append_enable <= '0';
      end if;

      if (empty = '0') and (pipe_valid = "000000000000" or pipe_valid = "000001000000" or pipe_valid = "000010000000" or pipe_valid = "000100000000" or pipe_valid = "001000000000" or pipe_valid = "010000000000") then
        -- If the FIFO is not empty and the pipeline is empty, pop an element from the FIFO
        pop_enable <= '1';
        fifo_access(0) <= '1'; -- Pop operation
        pipe_valid <= '1' & pipe_valid(SCHEDULER_PIPELINE_SIZE - 2 downto 0); -- Set the first stage valid
      else
        pop_enable <= '0';
        fifo_access(0) <= '0'; -- No operation
      end if;

      -- constant SCHEDULER_PIPELINE_SIZE         : integer := FLOW_MEM_LATENCY + CALENDAR_MEM_LATENCY + 6; -- Number of pipeline stages for the scheduler
      -- constant SCHEDULER_PIPELINE_STAGE_0      : integer := 0;
      -- constant SCHEDULER_PIPELINE_STAGE_1      : integer := FLOW_MEM_LATENCY + 1;
      -- constant SCHEDULER_PIPELINE_STAGE_2      : integer := FLOW_MEM_LATENCY + 2;
      -- constant SCHEDULER_PIPELINE_STAGE_3      : integer := FLOW_MEM_LATENCY + CALENDAR_MEM_LATENCY + 5;

      -- Stage -1: input address or feedback
      if fifo_access(1) = '1' then
        pipe(SCHEDULER_PIPELINE_STAGE_0).cur_slot <= unsigned(popped_element(CALENDAR_SLOTS_WIDTH - 1 downto 0));
        pipe(SCHEDULER_PIPELINE_STAGE_0).cur_addr <= popped_element(FLOW_ADDRESS_WIDTH + CALENDAR_SLOTS_WIDTH - 1 downto CALENDAR_SLOTS_WIDTH);
        pipe_valid(SCHEDULER_PIPELINE_STAGE_0) <= '1';
        --TODO: handle the improbable case when slot_advance_o = '1' and pipe_valid(SCHEDULER_PIPELINE_STAGE_2) = '1' and pipe(SCHEDULER_PIPELINE_STAGE_2).next_addr /= FLOW_NULL_ADDRESS at the same time
      elsif pipe_valid(SCHEDULER_PIPELINE_STAGE_2) = '1' and pipe(SCHEDULER_PIPELINE_STAGE_2).next_addr /= FLOW_NULL_ADDRESS then
        pipe(SCHEDULER_PIPELINE_STAGE_0).cur_addr <= pipe(SCHEDULER_PIPELINE_STAGE_2).next_addr;
        pipe_valid(SCHEDULER_PIPELINE_STAGE_0) <= '1';
      else
        pipe_valid(SCHEDULER_PIPELINE_STAGE_0) <= '0';
      end if;

      -- Stage 0 issues address to both BRAMs
      if pipe_valid(SCHEDULER_PIPELINE_STAGE_0) = '1' then
        flow_mem_ena <= '1';
        flow_mem_wea <= '0';
        -- NOTE: mapping FLOW_ADDRESS_WIDTH of cur_addr to FLOW_MEM_ADDR_WIDTH which effectively truncates the null address bit in front of the cur_addr
        flow_mem_addra <= pipe(SCHEDULER_PIPELINE_STAGE_0).cur_addr(FLOW_MEM_ADDR_WIDTH - 1 downto 0);

        rate_mem_ena <= '1';
        rate_mem_wea <= '0';
        rate_mem_addra <= pipe(SCHEDULER_PIPELINE_STAGE_0).cur_addr(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      else
        flow_mem_ena <= '0';
        rate_mem_ena <= '0';
      end if;

      -- Stage 1: BRAMs data arrives
      -- The flow_mem data is expected to be in the format:
      -- msb -> lsb
      -- [active_flag, seq_nr, next_addr, cur_addr]
      -- [ 1, SEQ_NR_WIDTH, FLOW_ADDRESS_WIDTH, QP_WIDTH[empty bits: QP_padding, FLOW_ADDRESS_WIDTH]]

      -- The rate_mem data is expected to be in the format:
      -- msb -> lsb
      -- [cur_rate]
      -- [CALENDAR_SLOTS_WIDTH]
      if pipe_valid(SCHEDULER_PIPELINE_STAGE_1) = '1' then
        pipe(SCHEDULER_PIPELINE_STAGE_2).cur_addr <= flow_mem_doa(FLOW_ADDRESS_WIDTH - 1 downto 0);
        pipe(SCHEDULER_PIPELINE_STAGE_2).next_addr <= flow_mem_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH - 1 downto QP_WIDTH);
        pipe(SCHEDULER_PIPELINE_STAGE_2).seq_nr <= unsigned(flow_mem_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH + SEQ_NR_WIDTH - 1 downto FLOW_ADDRESS_WIDTH + QP_WIDTH)) + 1; -- increment seq_nr by 1
        pipe(SCHEDULER_PIPELINE_STAGE_2).active_flag <= flow_mem_doa(FLOW_ADDRESS_WIDTH + QP_WIDTH + SEQ_NR_WIDTH);

        pipe(SCHEDULER_PIPELINE_STAGE_2).cur_rate <= unsigned(rate_mem_doa(CALENDAR_SLOTS_WIDTH - 1 downto 0));

      end if;

      -- Stage 2: update flow data and insert into calendar
      if pipe_valid(SCHEDULER_PIPELINE_STAGE_2) = '1' then
        insert_enable <= '1';
        insert_slot <= (pipe(SCHEDULER_PIPELINE_STAGE_2).cur_slot + pipe(SCHEDULER_PIPELINE_STAGE_2).cur_rate) and to_unsigned(CALENDAR_SLOTS - 1, CALENDAR_SLOTS_WIDTH); -- schedule in a circular manner
        insert_data <= pipe(SCHEDULER_PIPELINE_STAGE_2).cur_addr;
        --if active_flag = '1' then send output to the calendar
        if pipe(SCHEDULER_PIPELINE_STAGE_2).active_flag = '1' then
          qp_s <= QP_padding & pipe(SCHEDULER_PIPELINE_STAGE_2).cur_addr;
          seq_nr_s <= pipe(SCHEDULER_PIPELINE_STAGE_2).seq_nr;
          flow_rdy_s <= '1';
        end if;

      else
        insert_enable <= '0';

        qp_s <= QP_padding & FLOW_NULL_ADDRESS;
        seq_nr_s <= (others => '0');
        flow_rdy_s <= '0';
      end if;

      -- Stage 3: write back to flow_mem with updated next_addr
      -- At this point prev_head_address_o is ready so flow can be written back to the memory
      if pipe_valid(SCHEDULER_PIPELINE_STAGE_3) = '1' then
        --pipe(SCHEDULER_PIPELINE_STAGE_3 + 1).next_addr <= prev_head_address_o;
        flow_mem_enb <= '1';
        flow_mem_web <= '1';
        flow_mem_addrb <= pipe(SCHEDULER_PIPELINE_STAGE_3).cur_addr(FLOW_MEM_ADDR_WIDTH - 1 downto 0);
        flow_mem_dib <= pipe(SCHEDULER_PIPELINE_STAGE_3).active_flag & std_logic_vector(pipe(SCHEDULER_PIPELINE_STAGE_3).seq_nr) & prev_head_address_o & QP_padding & pipe(SCHEDULER_PIPELINE_STAGE_3).cur_addr;
      else
        flow_mem_enb <= '0';
        flow_mem_web <= '0';
      end if;

      if rst = '1' then
        pipe_valid <= (others => '0');
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

        qp_s <= (others => '0');
        seq_nr_s <= (others => '0');
        flow_rdy_s <= '0';
      end if;
    end if;
  end process;

  qp_o       <= qp_s;
  seq_nr_o   <= seq_nr_s;
  flow_rdy_o <= flow_rdy_s;

end architecture;
