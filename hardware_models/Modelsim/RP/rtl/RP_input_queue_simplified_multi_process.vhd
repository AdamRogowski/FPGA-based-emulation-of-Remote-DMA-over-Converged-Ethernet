-- filepath: c:\Users\jaro\Desktop\git-projects\DCQCN_model\hardware_scheduler\rtl\RP\RP_input_queue_simplified_simplified.vhd
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity RP_input_queue_simplified is
  generic (
    DATA_SENT_WIDTH     : integer := 1;
    NUM_FLOWS_WIDTH     : integer := 8; -- log2(NUM_FLOWS)
    PIPELINE_ADDR_WIDTH : integer := 4; -- log2(PIPELINE_DEPTH)
    FIFO_ADDR_WIDTH     : integer := 4  -- log2(FIFO_DEPTH)
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
end entity;

architecture rtl of RP_input_queue_simplified is

  -- Calculate depths from widths
  constant NUM_FLOWS      : integer := 2 ** NUM_FLOWS_WIDTH;
  constant PIPELINE_DEPTH : integer := 2 ** PIPELINE_ADDR_WIDTH;
  constant FIFO_DEPTH     : integer := 2 ** FIFO_ADDR_WIDTH;

  -- Type for a concatenated vector of all flow IDs in the pipeline
  constant PIPELINE_VECTOR_WIDTH : integer := PIPELINE_DEPTH * NUM_FLOWS_WIDTH;
  type pipeline_vector_t is array (0 to PIPELINE_DEPTH - 1) of std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);

  -- Notification record
  type notif_t is record
    flow_id   : std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);
    is_cnp    : std_logic;
    data_sent : unsigned(DATA_SENT_WIDTH - 1 downto 0);
  end record;

  -- FIFO signals
  type notif_array_t is array (0 to FIFO_DEPTH - 1) of notif_t;
  signal cnp_fifo       : notif_array_t                          := (others => (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0')));
  signal cnp_fifo_rd    : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal cnp_fifo_wr    : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal cnp_fifo_count : unsigned(FIFO_ADDR_WIDTH downto 0)     := (others => '0');

  signal data_fifo       : notif_array_t                          := (others => (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0')));
  signal data_fifo_rd    : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal data_fifo_wr    : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal data_fifo_count : unsigned(FIFO_ADDR_WIDTH downto 0)     := (others => '0');

  -- Pipeline tracker: shift register and concatenated vector for fast lookups
  type pipeline_array_t is array (0 to PIPELINE_DEPTH - 1) of std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);
  signal pipeline_flows  : pipeline_array_t                                     := (others => (others => '0'));
  signal pipeline_vector : std_logic_vector(PIPELINE_VECTOR_WIDTH - 1 downto 0) := (others => '0');

  -- Scanning
  signal scan_flow_id : unsigned(NUM_FLOWS_WIDTH - 1 downto 0) := (others => '0');

  -- Output register
  signal notif_out   : notif_t;
  signal notif_valid : std_logic := '0';

  -- Internal signals for pipeline and output control
  signal pipeline_insert_flow_id : std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0) := (others => '0');
  signal pipeline_insert_en      : std_logic                                      := '0';

  -- Control signals from combinatorial logic to clocked processes
  signal cnp_dequeue_req   : std_logic                              := '0';
  signal data_dequeue_req  : std_logic                              := '0';
  signal scan_req          : std_logic                              := '0';
  signal cnp_postpone_req  : std_logic                              := '0';
  signal cnp_postpone_src  : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal cnp_postpone_dst  : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal data_postpone_req : std_logic                              := '0';
  signal data_postpone_src : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal data_postpone_dst : unsigned(FIFO_ADDR_WIDTH - 1 downto 0) := (others => '0');

  -- Registered FIFO head outputs for timing improvement
  signal cnp_fifo_head  : notif_t;
  signal data_fifo_head : notif_t;

  -- Output of combinatorial logic (to be registered)
  signal next_notif_out   : notif_t;
  signal next_notif_valid : std_logic;

  -- Function for fast parallel check if a flow is in the pipeline
  function is_in_pipeline(flow_id : std_logic_vector; vec : std_logic_vector) return boolean is
    variable is_present : boolean := false;
  begin
    for i in 0 to PIPELINE_DEPTH - 1 loop
      if flow_id = vec((i + 1) * NUM_FLOWS_WIDTH - 1 downto i * NUM_FLOWS_WIDTH) then
        is_present := true;
        exit; -- Exit loop once found
      end if;
    end loop;
    return is_present;
  end function;

begin

  -- CNP FIFO process
  cnp_fifo_proc: process (clk)
    variable cnp_fifo_v : notif_array_t;
    variable wr_en      : boolean;
    variable rd_en      : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnp_fifo_rd <= (others => '0');
        cnp_fifo_wr <= (others => '0');
        cnp_fifo_count <= (others => '0');
        cnp_fifo <= (others => (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0')));
        cnp_fifo_head <= (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0'));
      else
        cnp_fifo_v := cnp_fifo;

        -- Continuously read from the FIFO head for pipelining
        cnp_fifo_head <= cnp_fifo(to_integer(cnp_fifo_rd));

        -- Determine enables for this cycle.
        -- The combinatorial output logic ensures that (dequeue or postpone) and (valid) are mutually exclusive for a given FIFO.
        wr_en := (cnp_valid = '1' and cnp_fifo_count < FIFO_DEPTH) or (cnp_postpone_req = '1');
        rd_en := cnp_dequeue_req = '1' or cnp_postpone_req = '1';

        -- FIFO Memory Write Logic
        if cnp_postpone_req = '1' then
          -- Postpone is a move from the current read pointer to the current write pointer
          cnp_fifo_v(to_integer(cnp_postpone_dst)) := cnp_fifo(to_integer(cnp_postpone_src));
        elsif cnp_valid = '1' and cnp_fifo_count < FIFO_DEPTH then
          -- A new entry is written to the FIFO
          cnp_fifo_v(to_integer(cnp_fifo_wr)).flow_id := cnp_flow_id;
          cnp_fifo_v(to_integer(cnp_fifo_wr)).is_cnp := '1';
          cnp_fifo_v(to_integer(cnp_fifo_wr)).data_sent := (others => '0');
        end if;
        cnp_fifo <= cnp_fifo_v;

        -- FIFO Pointer Update Logic
        if wr_en then
          cnp_fifo_wr <= (cnp_fifo_wr + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
        end if;
        if rd_en then
          cnp_fifo_rd <= (cnp_fifo_rd + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
        end if;

        -- FIFO Count Update Logic
        if wr_en and not rd_en then
          cnp_fifo_count <= cnp_fifo_count + 1;
        elsif not wr_en and rd_en then
          cnp_fifo_count <= cnp_fifo_count - 1;
        end if; -- if both true or both false, count remains the same
      end if;
    end if;
  end process;

  -- Data FIFO process
  data_fifo_proc: process (clk)
    variable data_fifo_v : notif_array_t;
    variable wr_en       : boolean;
    variable rd_en       : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        data_fifo_rd <= (others => '0');
        data_fifo_wr <= (others => '0');
        data_fifo_count <= (others => '0');
        data_fifo <= (others => (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0')));
        data_fifo_head <= (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0'));
      else
        data_fifo_v := data_fifo;

        -- Continuously read from the FIFO head for pipelining
        data_fifo_head <= data_fifo(to_integer(data_fifo_rd));

        -- Determine enables for this cycle
        wr_en := (data_valid = '1' and data_fifo_count < FIFO_DEPTH) or (data_postpone_req = '1');
        rd_en := data_dequeue_req = '1' or data_postpone_req = '1';

        -- FIFO Memory Write Logic
        if data_postpone_req = '1' then
          data_fifo_v(to_integer(data_postpone_dst)) := data_fifo(to_integer(data_postpone_src));
        elsif data_valid = '1' and data_fifo_count < FIFO_DEPTH then
          data_fifo_v(to_integer(data_fifo_wr)).flow_id := data_flow_id;
          data_fifo_v(to_integer(data_fifo_wr)).is_cnp := '0';
          data_fifo_v(to_integer(data_fifo_wr)).data_sent := data_sent;
        end if;
        data_fifo <= data_fifo_v;

        -- FIFO Pointer Update Logic
        if wr_en then
          data_fifo_wr <= (data_fifo_wr + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
        end if;
        if rd_en then
          data_fifo_rd <= (data_fifo_rd + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
        end if;

        -- FIFO Count Update Logic
        if wr_en and not rd_en then
          data_fifo_count <= data_fifo_count + 1;
        elsif not wr_en and rd_en then
          data_fifo_count <= data_fifo_count - 1;
        end if;
      end if;
    end if;
  end process;

  -- Pipeline tracker process (shift register and vector update)
  pipeline_proc: process (clk)
    variable temp_pipeline_vector : std_logic_vector(PIPELINE_VECTOR_WIDTH - 1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pipeline_flows <= (others => (others => '0'));
        pipeline_vector <= (others => '0');
      else
        -- Shift the pipeline
        for i in 0 to PIPELINE_DEPTH - 2 loop
          pipeline_flows(i) <= pipeline_flows(i + 1);
        end loop;
        if pipeline_insert_en = '1' then
          pipeline_flows(PIPELINE_DEPTH - 1) <= pipeline_insert_flow_id;
        else
          pipeline_flows(PIPELINE_DEPTH - 1) <= (others => '0');
        end if;

        -- Update the concatenated vector for fast lookups
        for i in 0 to PIPELINE_DEPTH - 1 loop
          temp_pipeline_vector((i + 1) * NUM_FLOWS_WIDTH - 1 downto i * NUM_FLOWS_WIDTH) := pipeline_flows(i);
        end loop;
        pipeline_vector <= temp_pipeline_vector;
      end if;
    end if;
  end process;

  -- Scan pointer process
  scan_proc: process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        scan_flow_id <= (others => '0');
      else
        if scan_req = '1' then
          scan_flow_id <= (scan_flow_id + 1) and to_unsigned(NUM_FLOWS - 1, NUM_FLOWS_WIDTH);
        end if;
      end if;
    end if;
  end process;

  -- Combinatorial Output Selection Logic
  comb_output_proc: process (cnp_fifo_count, cnp_valid, pipeline_vector, cnp_fifo_head, cnp_fifo_wr, data_fifo_count, data_valid, data_fifo_head, data_fifo_wr, scan_flow_id)
  begin
    -- Default assignments for all control signals
    next_notif_out <= (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0'));
    next_notif_valid <= '0';
    pipeline_insert_en <= '0';
    pipeline_insert_flow_id <= (others => '0');
    scan_req <= '0';
    cnp_dequeue_req <= '0';
    data_dequeue_req <= '0';
    cnp_postpone_req <= '0';
    cnp_postpone_src <= (others => '0');
    cnp_postpone_dst <= (others => '0');
    data_postpone_req <= '0';
    data_postpone_src <= (others => '0');
    data_postpone_dst <= (others => '0');

    -- Priority: CNP > Data > Scan
    -- We only service a FIFO if no new data is arriving for that same FIFO, to prevent write/postpone conflicts.
    if cnp_fifo_count > 0 and cnp_valid = '0' then
      if not is_in_pipeline(cnp_fifo_head.flow_id, pipeline_vector) then
        -- Dequeue CNP: The flow is not in the pipeline, so we can process it.
        next_notif_out <= cnp_fifo_head;
        next_notif_valid <= '1';
        pipeline_insert_en <= '1';
        pipeline_insert_flow_id <= cnp_fifo_head.flow_id;
        cnp_dequeue_req <= '1';
      else
        -- Postpone CNP: The flow is in the pipeline. Move it to the back of the queue to try again later.
        if cnp_fifo_count < FIFO_DEPTH then
          cnp_postpone_req <= '1';
          cnp_postpone_src <= cnp_fifo_rd;
          cnp_postpone_dst <= cnp_fifo_wr;
        end if;
      end if;
    elsif data_fifo_count > 0 and data_valid = '0' then
      if not is_in_pipeline(data_fifo_head.flow_id, pipeline_vector) then
        -- Dequeue Data
        next_notif_out <= data_fifo_head;
        next_notif_valid <= '1';
        pipeline_insert_en <= '1';
        pipeline_insert_flow_id <= data_fifo_head.flow_id;
        data_dequeue_req <= '1';
      else
        -- Postpone Data
        if data_fifo_count < FIFO_DEPTH then
          data_postpone_req <= '1';
          data_postpone_src <= data_fifo_rd;
          data_postpone_dst <= data_fifo_wr;
        end if;
      end if;
    else
      -- Scan for a flow that is not in the pipeline
      if not is_in_pipeline(std_logic_vector(scan_flow_id), pipeline_vector) then
        -- Found a scannable flow
        next_notif_out <= (flow_id => std_logic_vector(scan_flow_id), is_cnp => '0', data_sent => (others => '0'));
        next_notif_valid <= '1';
        pipeline_insert_en <= '1';
        pipeline_insert_flow_id <= std_logic_vector(scan_flow_id);
      end if;
      -- Always advance the scan pointer if we are in the scan phase
      scan_req <= '1';
    end if;
  end process;

  -- Registered output process
  output_reg_proc: process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        notif_out <= (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0'));
        notif_valid <= '0';
      else
        notif_out <= next_notif_out;
        notif_valid <= next_notif_valid;
      end if;
    end if;
  end process;

  -- Output assignment
  flow_rdy_o  <= notif_valid;
  is_cnp_o    <= notif_out.is_cnp;
  flow_id_o   <= notif_out.flow_id;
  data_sent_o <= notif_out.data_sent;

end architecture;
