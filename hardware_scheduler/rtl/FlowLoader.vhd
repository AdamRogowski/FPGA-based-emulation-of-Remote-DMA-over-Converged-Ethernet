library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  --  use IEEE.STD_LOGIC_ARITH.all;
  --  use IEEE.STD_LOGIC_UNSIGNED.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity FlowLoader is
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    flow_ready      : out std_logic;
    flow_addr_out   : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    max_rate_out    : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    cur_rate_out    : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
    seq_nr_out      : out unsigned(SEQ_NR_WIDTH - 1 downto 0);
    next_addr_out   : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    active_flag_out : out std_logic
  );
end entity;

architecture Behavioral of FlowLoader is
  component FlowInitMemory
    port (
      flow_index : in  integer range 0 to NUM_FLOWS_TOTAL - 1;
      flow_addr  : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      max_rate   : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
      cur_rate   : out unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)
    );
  end component;

  -- Memory I/O
  signal flow_addr_mem : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal max_rate_mem  : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
  signal cur_rate_mem  : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);

  signal flow_index       : integer range 0 to NUM_FLOWS_TOTAL - 1 := 0;
  signal group_id_counter : integer range 0 to NUM_GROUPS - 1      := 0;
  signal flow_id_counter  : integer range 0 to NUM_FLOWS - 1       := 0;

  signal clk_counter : integer range 0 to FLOW_LOADER_INTERVAL := 0; --On purpose left 0 to FLOW_LOADER_INTERVAL, instead of 0 to FLOW_LOADER_INTERVAL - 1
  signal ready_reg   : std_logic                               := '0';

  signal total_flows_read : integer range 0 to NUM_FLOWS_TOTAL := 0; --On purpose left 0 to NUM_FLOWS_TOTAL, instead of 0 to NUM_FLOWS_TOTAL - 1
  signal all_flows_done   : std_logic                          := '0';

begin

  -- Memory Instance
  FlowMemory: FlowInitMemory
    port map (
      flow_index => flow_index,
      flow_addr  => flow_addr_mem,
      max_rate   => max_rate_mem,
      cur_rate   => cur_rate_mem
    );

  -- Clocked control
  process (clk)
  begin
    if rising_edge(clk) then
      if all_flows_done = '0' then
        if clk_counter < FLOW_LOADER_INTERVAL then
          clk_counter <= clk_counter + 1;
          ready_reg <= '0';
        else
          clk_counter <= 0;
          ready_reg <= '1';

          -- Compute flow_index
          flow_index <= group_id_counter * NUM_FLOWS + flow_id_counter;

          total_flows_read <= total_flows_read + 1;

          -- Stop once all flows are read
          if total_flows_read = NUM_FLOWS_TOTAL - 1 then
            all_flows_done <= '1';
          end if;

          -- Advance group and flow counters
          if group_id_counter = NUM_GROUPS - 1 then
            group_id_counter <= 0;

            if flow_id_counter < NUM_FLOWS - 1 then
              flow_id_counter <= flow_id_counter + 1;
            else
              flow_id_counter <= 0; -- Should never happen due to read limit
            end if;
          else
            group_id_counter <= group_id_counter + 1;
          end if;
        end if;
      else
        ready_reg <= '0'; -- Disable output once done
      end if;

      if rst = '1' then
        clk_counter <= 0;
        flow_id_counter <= 0;
        group_id_counter <= 0;
        total_flows_read <= 0;
        all_flows_done <= '0';
        ready_reg <= '0';
      end if;

    end if;
  end process;

  -- Output assignment
  process (clk)
  begin
    if rising_edge(clk) then
      if ready_reg = '1' then
        flow_addr_out <= flow_addr_mem;
        max_rate_out <= max_rate_mem;
        cur_rate_out <= cur_rate_mem;
        seq_nr_out <= (others => '0');
        next_addr_out <= (others => '0');
        active_flag_out <= '1';
      end if;
      flow_ready <= ready_reg;
    end if;
  end process;

end architecture;
