library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;
  use work.IPG_reciprocal_pkg.all;

entity CalendarMain is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    QP_out     : out std_logic_vector(23 downto 0);
    seq_nr_out : out std_logic_vector(23 downto 0)
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
      QP_out          : out std_logic_vector(QP_WIDTH - 1 downto 0);
      max_rate_out    : out std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
      cur_rate_out    : out std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0);
      seq_nr_out      : out std_logic_vector(SEQ_NR_WIDTH - 1 downto 0);
      next_addr_out   : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      active_flag_out : out std_logic
    );
  end component;

  -- ONLY FOR SIMULATION
  constant reciprocal_table : reciprocal_table_type := generate_reciprocal_table;

  -- Signals from CalendarCnt
  signal cur_slot : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal update   : std_logic                                   := '0';

  -- Flow input from FlowLoader
  signal flow_ready_in  : std_logic                                                := '0';
  signal QP_in          : std_logic_vector(QP_WIDTH - 1 downto 0)                  := (others => '0');
  signal seq_nr_in      : std_logic_vector(SEQ_NR_WIDTH - 1 downto 0)              := (others => '0');
  signal max_rate_in    : std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0) := (others => '0');
  signal cur_rate_in    : std_logic_vector(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0) := (others => '0');
  signal next_addr_in   : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0)        := (others => '0');
  signal active_flag_in : std_logic                                                := '0';
  signal scheduled_in   : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)              := (others => '0'); -- Scheduled slot index
  signal target_slot_s  : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)              := (others => '0');
  --signal rate_val       : unsigned(RATE_BIT_RESOLUTION_WIDTH - 1 downto 0)         := (others => '0'); -- Rate value

begin

  FlowLoaderInstance: FlowLoader
    port map (
      clk             => clk,
      rst             => rst,
      flow_ready      => flow_ready_in,
      QP_out          => QP_in,
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
    -- Intermediate signals/variables
    variable rate_val : integer;

  begin
    if rising_edge(clk) then

      if flow_ready_in = '1' then

        -- Compute rate (minimum of cur and max)
        if unsigned(cur_rate_in) < unsigned(max_rate_in) then
          rate_val := to_integer(unsigned(cur_rate_in));
          --rate_val := 320; -- Convert to Kbps

        else
          rate_val := to_integer(unsigned(max_rate_in));
        end if;

        scheduled_in <= reciprocal_table(rate_val);

        target_slot_s <= (cur_slot + scheduled_in) and to_unsigned(CALENDAR_SLOTS - 1, CALENDAR_SLOTS_WIDTH);

        QP_out <= QP_in;
        seq_nr_out <= seq_nr_in;
      end if;

      if rst = '1' then
        QP_out <= (others => '0');
        seq_nr_out <= (others => '0');
      end if;

    end if;
  end process;

end architecture;
