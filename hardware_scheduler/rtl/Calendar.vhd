library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all; -- Import constants

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

architecture RTL of Calendar is

  --type calendar_array_t is array (0 to CALENDAR_SLOTS - 1) of std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  --signal calendar_wheel : calendar_array_t := (others => FLOW_NULL_ADDRESS); -- initialized with reset
  component CalendarCnt
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      cur_slot : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      update   : out std_logic
    );
  end component;

  component Calendar_mem
    generic (
      LATENCY : integer := 2 -- number of pipeline stages
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

  signal cur_slot_int : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal update_int   : std_logic                                   := '0';

  -- Internal signals for the calendar memory
  signal calendar_mem_ena, calendar_mem_enb     : std_logic                                              := '0';
  signal calendar_mem_wea, calendar_mem_web     : std_logic                                              := '0';
  signal calendar_mem_addra, calendar_mem_addrb : std_logic_vector(CALENDAR_MEM_ADDR_WIDTH - 1 downto 0) := CALENDAR_MEM_DEFAULT_ADDRESS;
  signal calendar_mem_dia, calendar_mem_dib     : std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0) := CALENDAR_MEM_NULL_ENTRY;
  signal calendar_mem_doa, calendar_mem_dob     : std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0) := CALENDAR_MEM_NULL_ENTRY;

  -- Pipelines for synchronizing: current_slot_o, slot_advance_o with head_address_o after MEM_LATENCY
  constant PIPE_SYNCH_LATECY : integer := MEM_LATENCY + 1; -- Number of pipeline stages for synchronization
  type current_slot_pipe_type is array (0 to PIPE_SYNCH_LATECY - 1) of unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
  type slot_advance_pipe_type is array (0 to PIPE_SYNCH_LATECY - 1) of std_logic;

  signal current_slot_pipe : current_slot_pipe_type := (others => (others => '0'));
  signal slot_advance_pipe : slot_advance_pipe_type := (others => '0');

  -- Signal for CalendarCnt
  --signal slot_counter : unsigned(CALENDAR_INTERVAL_WIDTH - 1 downto 0) := (others => '0');
  --signal slot_index   : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)    := (others => '0');
  --signal update_reg   : std_logic                                      := '0';

begin

  CalendarCounter_inst: CalendarCnt
    port map (
      clk      => clk,
      rst      => rst,
      cur_slot => cur_slot_int,
      update   => update_int
    );

  -- Calendar memory instantiation
  Calendar_mem_inst: Calendar_mem
    generic map (
      LATENCY => MEM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => calendar_mem_ena,
      enb   => calendar_mem_enb,
      wea   => calendar_mem_wea,
      web   => calendar_mem_web,
      addra => calendar_mem_addra,
      addrb => calendar_mem_addrb,
      dia   => calendar_mem_dia,
      dib   => calendar_mem_dib,
      doa   => calendar_mem_doa,
      dob   => calendar_mem_dob
    );

  process (clk)
  begin
    if rising_edge(clk) then

      --if slot_counter = to_unsigned(CALENDAR_INTERVAL - 1, slot_counter'length) then
      --  slot_counter <= (others => '0');
      --
      --      if slot_index = to_unsigned(CALENDAR_SLOTS - 1, slot_index'length) then
      --    slot_index <= (others => '0');
      --    else
      --   slot_index <= slot_index + 1;
      --end if;

      --update_reg <= '1';
      --else
      -- slot_counter <= slot_counter + 1;
      -- update_reg <= '0';
      --end if;

      -- Shift the pipeline for current_slot and slot_advance
      for i in PIPE_SYNCH_LATECY - 1 downto 1 loop
        current_slot_pipe(i) <= current_slot_pipe(i - 1);
        slot_advance_pipe(i) <= slot_advance_pipe(i - 1);
      end loop;

      current_slot_pipe(0) <= cur_slot_int;
      slot_advance_pipe(0) <= update_int;

      --current_slot_pipe(0) <= current_slot;
      --slot_advance_pipe(0) <= slot_tick_int;
      if insert_enable = '1' then
        -- Write to calendar memory using port A
        -- Read the previous head address using port A
        calendar_mem_ena <= '1';
        calendar_mem_wea <= '1';
        calendar_mem_addra <= std_logic_vector(insert_slot);
        calendar_mem_dia <= insert_data;
      else
        calendar_mem_ena <= '0';
        calendar_mem_wea <= '0';
      end if;

      if update_int = '1' then
        -- Read the previous head address using port B
        calendar_mem_enb <= '1';
        calendar_mem_web <= '1';
        calendar_mem_addrb <= std_logic_vector(cur_slot_int);
        calendar_mem_dib <= FLOW_NULL_ADDRESS;
      else
        calendar_mem_enb <= '0';
        calendar_mem_web <= '0';
      end if;

      if rst = '1' then
        --cur_slot_int <= (others => '0');
        --update_int <= '0';
        calendar_mem_ena <= '0';
        calendar_mem_enb <= '0';
        calendar_mem_wea <= '0';
        calendar_mem_web <= '0';
        calendar_mem_addra <= (others => '0');
        calendar_mem_addrb <= (others => '0');
        calendar_mem_dia <= (others => '0');
        calendar_mem_dib <= (others => '0');
        --current_slot_pipe <= (others => (others => '0'));
        --slot_advance_pipe <= (others => '0');
        --slot_counter <= (others => '0');
        --slot_index <= (others => '0');
        --update_reg <= '0';
      end if;

    end if;
  end process;

  slot_advance_o      <= slot_advance_pipe(PIPE_SYNCH_LATECY - 1);
  current_slot_o      <= current_slot_pipe(PIPE_SYNCH_LATECY - 1);
  head_address_o      <= calendar_mem_dob;
  prev_head_address_o <= calendar_mem_doa;

end architecture;
