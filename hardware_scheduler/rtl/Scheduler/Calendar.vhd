library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

  -- ============================================================================
  -- Entity: Calendar
  -- Description:
  --   Calendar structure for DCQCN scheduler.
  --   - Handles slot advancement and flow insertion.
  --   - Synchronizes outputs with memory latency.
  -- ============================================================================

entity Calendar is
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
end entity;

architecture rtl of Calendar is

  component CalendarCnt is
    port (
      clk         : in  std_logic;
      rst         : in  std_logic;
      slot_index  : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      slot_update : out std_logic
    );
  end component;

  component Calendar_mem is
    generic (
      LATENCY : integer
    );
    port (
      clk          : in  std_logic;
      ena, enb     : in  std_logic;
      wea, web     : in  std_logic;
      addra, addrb : in  std_logic_vector(CALENDAR_MEM_ADDR_WIDTH - 1 downto 0);
      dia, dib     : in  std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0);
      doa, dob     : out std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0)
    );
  end component;

  -- Internal signals
  signal slot_index_int  : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal slot_update_int : std_logic                                   := '0';

  -- Calendar memory interface
  signal cal_mem_ena, cal_mem_enb     : std_logic                                              := '0';
  signal cal_mem_wea, cal_mem_web     : std_logic                                              := '0';
  signal cal_mem_addra, cal_mem_addrb : std_logic_vector(CALENDAR_MEM_ADDR_WIDTH - 1 downto 0) := CALENDAR_MEM_DEFAULT_ADDRESS;
  signal cal_mem_dia, cal_mem_dib     : std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0) := CALENDAR_MEM_NULL_ENTRY;
  signal cal_mem_doa, cal_mem_dob     : std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0) := CALENDAR_MEM_NULL_ENTRY;

  -- Pipelines for synchronizing outputs with memory latency
  constant PIPE_SYNC_LATENCY : integer := CALENDAR_MEM_LATENCY + 1;
  type slot_pipe_t is array (0 to PIPE_SYNC_LATENCY - 1) of unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  type adv_pipe_t is array (0 to PIPE_SYNC_LATENCY - 1) of std_logic;

  signal slot_pipe    : slot_pipe_t := (others => (others => '0'));
  signal advance_pipe : adv_pipe_t  := (others => '0');

begin

  -- Calendar slot counter
  CalendarCnt_inst: CalendarCnt
    port map (
      clk         => clk,
      rst         => rst,
      slot_index  => slot_index_int,
      slot_update => slot_update_int
    );

  -- Calendar memory instantiation
  Calendar_mem_inst: Calendar_mem
    generic map (
      LATENCY => CALENDAR_MEM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => cal_mem_ena,
      enb   => cal_mem_enb,
      wea   => cal_mem_wea,
      web   => cal_mem_web,
      addra => cal_mem_addra,
      addrb => cal_mem_addrb,
      dia   => cal_mem_dia,
      dib   => cal_mem_dib,
      doa   => cal_mem_doa,
      dob   => cal_mem_dob
    );

  -- Synchronize slot and advance signals with memory latency
  process (clk)
  begin
    if rising_edge(clk) then

      -- Shift pipelines for slot and advance
      for i in PIPE_SYNC_LATENCY - 1 downto 1 loop
        slot_pipe(i) <= slot_pipe(i - 1);
        advance_pipe(i) <= advance_pipe(i - 1);
      end loop;
      slot_pipe(0) <= slot_index_int;
      advance_pipe(0) <= slot_update_int;

      -- Handle insert operation (port A)
      if insert_enable = '1' then
        cal_mem_ena <= '1';
        cal_mem_wea <= '1';
        cal_mem_addra <= std_logic_vector(insert_slot);
        cal_mem_dia <= insert_data;
      else
        cal_mem_ena <= '0';
        cal_mem_wea <= '0';
      end if;

      -- Handle slot advance operation (port B)
      if slot_update_int = '1' then
        cal_mem_enb <= '1';
        cal_mem_web <= '1';
        cal_mem_addrb <= std_logic_vector(slot_index_int);
        cal_mem_dib <= FLOW_NULL_ADDRESS;
      else
        cal_mem_enb <= '0';
        cal_mem_web <= '0';
      end if;

      -- Synchronous reset
      if rst = '1' then
        cal_mem_ena <= '0';
        cal_mem_enb <= '0';
        cal_mem_wea <= '0';
        cal_mem_web <= '0';
        cal_mem_addra <= (others => '0');
        cal_mem_addrb <= (others => '0');
        cal_mem_dia <= (others => '0');
        cal_mem_dib <= (others => '0');
        slot_pipe <= (others => (others => '0'));
        advance_pipe <= (others => '0');
      end if;

    end if;
  end process;

  -- Output assignments (synchronized with memory latency)
  slot_advance_o      <= advance_pipe(PIPE_SYNC_LATENCY - 1);
  current_slot_o      <= slot_pipe(PIPE_SYNC_LATENCY - 1);
  head_address_o      <= cal_mem_dob;
  prev_head_address_o <= cal_mem_doa;

end architecture;
