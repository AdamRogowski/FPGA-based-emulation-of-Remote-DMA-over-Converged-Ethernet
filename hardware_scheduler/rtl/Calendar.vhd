library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all; -- Import constants

entity Calendar is
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    insert_enable  : in  std_logic;
    insert_slot    : in  unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    insert_address : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    current_slot_o : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    head_address_o : out std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
    slot_advance_o : out std_logic -- Pulse when moving to the next slot
  );
end entity;

architecture RTL of Calendar is

  type calendar_array_t is array (0 to CALENDAR_SLOTS - 1) of std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal calendar_wheel : calendar_array_t := (others => FLOW_NULL_ADDRESS);

  component CalendarCnt
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      cur_slot : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
      update   : out std_logic
    );
  end component;

  signal current_slot  : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal slot_tick_int : std_logic                                   := '0';

begin

  CalendarCounter_inst: CalendarCounter
    port map (
      clk      => clk,
      rst      => rst,
      cur_slot => current_slot,
      update   => slot_tick_int
    );

  process (clk)
  begin
    if rising_edge(clk) then

      if insert_enable = '1' then
        calendar_wheel(to_integer(insert_slot)) <= insert_address;
      end if;

      if slot_tick_int = '1' then
        current_slot_o <= current_slot;
        head_address_o <= calendar_wheel(to_integer(current_slot));
        slot_advance_o <= '1';
      else
        slot_advance_o <= '0';
      end if;

      if rst = '1' then
        calendar_wheel <= (others => FLOW_NULL_ADDRESS);
      end if;

    end if;
  end process;

end architecture;
