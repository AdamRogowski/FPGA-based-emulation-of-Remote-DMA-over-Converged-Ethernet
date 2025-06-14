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

  -- Pipeline tracker: shift register
  type pipeline_array_t is array (0 to PIPELINE_DEPTH - 1) of std_logic_vector(NUM_FLOWS_WIDTH - 1 downto 0);
  signal pipeline_flows : pipeline_array_t := (others => (others => '0'));

  -- Scanning
  signal scan_flow_id : unsigned(NUM_FLOWS_WIDTH - 1 downto 0) := (others => '0');

  -- Output register
  signal notif_out   : notif_t;
  signal notif_valid : std_logic := '0';

begin

  process (clk)
    variable candidate                           : notif_t;
    variable scan_candidate                      : notif_t;
    variable found                               : boolean;
    variable in_pipeline                         : boolean;
    variable i                                   : integer;
    variable cnp_fifo_rd_v, cnp_fifo_wr_v        : unsigned(FIFO_ADDR_WIDTH - 1 downto 0);
    variable data_fifo_rd_v, data_fifo_wr_v      : unsigned(FIFO_ADDR_WIDTH - 1 downto 0);
    variable cnp_fifo_count_v, data_fifo_count_v : unsigned(FIFO_ADDR_WIDTH downto 0);
    variable pipeline_flows_v                    : pipeline_array_t;
    variable scan_flow_id_v                      : unsigned(NUM_FLOWS_WIDTH - 1 downto 0);
    variable notif_out_v                         : notif_t;
    variable notif_valid_v                       : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnp_fifo_rd <= (others => '0');
        cnp_fifo_wr <= (others => '0');
        cnp_fifo_count <= (others => '0');
        data_fifo_rd <= (others => '0');
        data_fifo_wr <= (others => '0');
        data_fifo_count <= (others => '0');
        pipeline_flows <= (others => (others => '0'));
        scan_flow_id <= (others => '0');
        notif_out <= (flow_id => (others => '0'), is_cnp => '0', data_sent => (others => '0'));
        notif_valid <= '0';
      else
        -- Copy signals to variables for safe update
        cnp_fifo_rd_v := cnp_fifo_rd;
        cnp_fifo_wr_v := cnp_fifo_wr;
        cnp_fifo_count_v := cnp_fifo_count;
        data_fifo_rd_v := data_fifo_rd;
        data_fifo_wr_v := data_fifo_wr;
        data_fifo_count_v := data_fifo_count;
        pipeline_flows_v := pipeline_flows;
        scan_flow_id_v := scan_flow_id;
        notif_out_v := notif_out;
        notif_valid_v := '0';

        -- Input FIFOs for CNP and Data notifications
        if cnp_valid = '1' and cnp_fifo_count_v < FIFO_DEPTH then
          cnp_fifo(to_integer(cnp_fifo_wr_v)).flow_id <= cnp_flow_id;
          cnp_fifo(to_integer(cnp_fifo_wr_v)).is_cnp <= '1';
          cnp_fifo(to_integer(cnp_fifo_wr_v)).data_sent <= (others => '0');
          cnp_fifo_wr_v := (cnp_fifo_wr_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
          cnp_fifo_count_v := cnp_fifo_count_v + 1;
        end if;
        if data_valid = '1' and data_fifo_count_v < FIFO_DEPTH then
          data_fifo(to_integer(data_fifo_wr_v)).flow_id <= data_flow_id;
          data_fifo(to_integer(data_fifo_wr_v)).is_cnp <= '0';
          data_fifo(to_integer(data_fifo_wr_v)).data_sent <= data_sent;
          data_fifo_wr_v := (data_fifo_wr_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
          data_fifo_count_v := data_fifo_count_v + 1;
        end if;

        -- Shift pipeline tracker (simulate pipeline advance)
        for i in 0 to PIPELINE_DEPTH - 2 loop
          pipeline_flows_v(i) := pipeline_flows_v(i + 1);
        end loop;
        pipeline_flows_v(PIPELINE_DEPTH - 1) := (others => '0');

        -- Prepare scan candidate
        scan_candidate.flow_id := std_logic_vector(resize(scan_flow_id_v, NUM_FLOWS_WIDTH));
        scan_candidate.is_cnp := '0';
        scan_candidate.data_sent := (others => '0');

        found := false;

        -- Priority: CNP > Data > Scan
        if cnp_fifo_count_v > 0 then
          if cnp_valid = '0' then
            candidate := cnp_fifo(to_integer(cnp_fifo_rd_v));
            -- Check if in pipeline
            in_pipeline := false;
            for i in 0 to PIPELINE_DEPTH - 1 loop
              if pipeline_flows_v(i) = candidate.flow_id then
                in_pipeline := true;
              end if;
            end loop;
            if not in_pipeline then
              notif_out_v := candidate;
              notif_valid_v := '1';
              pipeline_flows_v(PIPELINE_DEPTH - 1) := candidate.flow_id;
              cnp_fifo_rd_v := (cnp_fifo_rd_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
              cnp_fifo_count_v := cnp_fifo_count_v - 1;
              found := true;
            else
              -- Postpone: put at end of FIFO
              if cnp_fifo_count_v < FIFO_DEPTH then
                cnp_fifo(to_integer(cnp_fifo_wr_v)) <= candidate;
                cnp_fifo_wr_v := (cnp_fifo_wr_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
                cnp_fifo_rd_v := (cnp_fifo_rd_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
                -- count unchanged
              end if;
            end if;
          end if;
        elsif data_fifo_count_v > 0 then
          if data_valid = '0' then
            candidate := data_fifo(to_integer(data_fifo_rd_v));
            -- Check if in pipeline
            in_pipeline := false;
            for i in 0 to PIPELINE_DEPTH - 1 loop
              if pipeline_flows_v(i) = candidate.flow_id then
                in_pipeline := true;
              end if;
            end loop;
            if not in_pipeline then
              notif_out_v := candidate;
              notif_valid_v := '1';
              pipeline_flows_v(PIPELINE_DEPTH - 1) := candidate.flow_id;
              data_fifo_rd_v := (data_fifo_rd_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
              data_fifo_count_v := data_fifo_count_v - 1;
              found := true;
            else
              -- Postpone: put at end of FIFO
              if data_fifo_count_v < FIFO_DEPTH then
                data_fifo(to_integer(data_fifo_wr_v)) <= candidate;
                data_fifo_wr_v := (data_fifo_wr_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
                data_fifo_rd_v := (data_fifo_rd_v + 1) and to_unsigned(FIFO_DEPTH - 1, FIFO_ADDR_WIDTH);
                -- count unchanged
              end if;
            end if;
          end if;
        else
          -- Scanning
          -- Check if in pipeline
          in_pipeline := false;
          for i in 0 to PIPELINE_DEPTH - 1 loop
            if pipeline_flows_v(i) = scan_candidate.flow_id then
              in_pipeline := true;
            end if;
          end loop;
          scan_flow_id_v := (scan_flow_id_v + 1) and to_unsigned(NUM_FLOWS - 1, NUM_FLOWS_WIDTH);
          if not in_pipeline then
            notif_out_v := scan_candidate;
            notif_valid_v := '1';
            pipeline_flows_v(PIPELINE_DEPTH - 1) := scan_candidate.flow_id;
            found := true;
          end if;
        end if;

        -- Write back variables to signals
        cnp_fifo_rd <= cnp_fifo_rd_v;
        cnp_fifo_wr <= cnp_fifo_wr_v;
        cnp_fifo_count <= cnp_fifo_count_v;
        data_fifo_rd <= data_fifo_rd_v;
        data_fifo_wr <= data_fifo_wr_v;
        data_fifo_count <= data_fifo_count_v;
        pipeline_flows <= pipeline_flows_v;
        scan_flow_id <= scan_flow_id_v;
        notif_out <= notif_out_v;
        notif_valid <= notif_valid_v;
      end if;
    end if;
  end process;

  -- Output assignment
  flow_rdy_o  <= notif_valid;
  is_cnp_o    <= notif_out.is_cnp;
  flow_id_o   <= notif_out.flow_id;
  data_sent_o <= notif_out.data_sent;

end architecture;
