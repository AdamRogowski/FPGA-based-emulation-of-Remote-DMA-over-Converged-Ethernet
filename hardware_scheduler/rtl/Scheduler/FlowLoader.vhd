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

  -- Internal signals
  signal flow_addr_mem : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal max_rate_mem  : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
  signal cur_rate_mem  : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);

  signal flow_index     : integer range 0 to NUM_FLOWS_TOTAL      := 0;
  signal clk_counter    : integer range 0 to FLOW_LOADER_INTERVAL := 0;
  signal all_flows_done : std_logic                               := '0';

begin

  -- Memory instance
  FlowMemory: FlowInitMemory
    port map (
      flow_index => flow_index,
      flow_addr  => flow_addr_mem,
      max_rate   => max_rate_mem,
      cur_rate   => cur_rate_mem
    );

  -- Main process
  process (clk)
  begin
    if rising_edge(clk) then
      if all_flows_done = '0' then
        if clk_counter < FLOW_LOADER_INTERVAL - 1 then
          clk_counter <= clk_counter + 1;
          flow_ready <= '0';
        else
          -- Counter reached threshold: output current flow
          clk_counter <= 0;
          flow_addr_out <= flow_addr_mem;
          max_rate_out <= max_rate_mem;
          cur_rate_out <= cur_rate_mem;
          seq_nr_out <= (others => '0');
          next_addr_out <= (others => '0');
          active_flag_out <= '1';
          flow_ready <= '1';

          -- Increment index for next cycle
          if flow_index < NUM_FLOWS_TOTAL - 1 then
            flow_index <= flow_index + 1;
          else
            all_flows_done <= '1';
          end if;
        end if;
      else
        flow_ready <= '0';
      end if;

      if rst = '1' then
        flow_index <= 0;
        clk_counter <= 0;
        all_flows_done <= '0';
        flow_ready <= '0';
        flow_addr_out <= (others => '0');
        max_rate_out <= (others => '0');
        cur_rate_out <= (others => '0');
        seq_nr_out <= (others => '0');
        next_addr_out <= (others => '0');
        active_flag_out <= '0';
      end if;
    end if;
  end process;

end architecture;

