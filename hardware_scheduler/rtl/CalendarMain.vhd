library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;
  --use work.IPG_reciprocal_pkg.all;

entity CalendarMain is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    QP_out     : out std_logic_vector(QP_WIDTH - 1 downto 0);
    seq_nr_out : out unsigned(SEQ_NR_WIDTH - 1 downto 0)
  );
end entity;

architecture Behavioral of CalendarMain is

  component CalendarCnt
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      cur_slot : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      update   : out std_logic
    );
  end component;

  component FlowLoader
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
  end component;

  -- Temporary solution, ONLY FOR SIMULATION
  constant QP_padding : std_logic_vector(QP_WIDTH - FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0'); -- Padding for QP

  -- Signals from CalendarCnt
  signal cur_slot : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal update   : std_logic                                   := '0';

  -- Flow input from FlowLoader
  signal flow_ready_in  : std_logic                                         := '0';
  signal flow_addr_in   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal seq_nr_in      : unsigned(SEQ_NR_WIDTH - 1 downto 0)               := (others => '0');
  signal max_rate_in    : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)  := (others => '0');
  signal cur_rate_in    : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)  := (others => '0');
  signal next_addr_in   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal active_flag_in : std_logic                                         := '0';
  signal scheduled_in   : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)       := (others => '0'); -- Scheduled slot index
  signal target_slot_s  : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)       := (others => '0');

begin

  FlowLoaderInstance: FlowLoader
    port map (
      clk             => clk,
      rst             => rst,
      flow_ready      => flow_ready_in,
      flow_addr_out   => flow_addr_in,
      max_rate_out    => max_rate_in,
      cur_rate_out    => cur_rate_in,
      seq_nr_out      => seq_nr_in,
      next_addr_out   => next_addr_in,
      active_flag_out => active_flag_in
    );

  CalendarCntInstance: CalendarCnt
    port map (
      clk      => clk,
      rst      => rst,
      cur_slot => cur_slot,
      update   => update
    );

  process (clk)
    variable rate_val : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);

  begin
    if rising_edge(clk) then

      if flow_ready_in = '1' then
        if cur_rate_in > max_rate_in then
          rate_val := cur_rate_in;
        else
          rate_val := max_rate_in;
        end if;

        target_slot_s <= (cur_slot + rate_val) and to_unsigned(CALENDAR_SLOTS - 1, CALENDAR_SLOTS_WIDTH); -- schedule in a circular manner

        QP_out <= QP_padding & flow_addr_in; -- TODO: temporary padding to match QP width
        seq_nr_out <= seq_nr_in;
      end if;

      if rst = '1' then
        QP_out <= (others => '0');
        seq_nr_out <= (others => '0');
      end if;

    end if;
  end process;

end architecture;
