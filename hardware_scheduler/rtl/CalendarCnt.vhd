library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants from the package

entity CalendarCnt is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    cur_slot : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    update   : out std_logic -- Pulse when moving to the next slot
  );
end entity;

architecture RTL of CalendarCnt is
  signal slot_counter : unsigned(CALENDAR_INTERVAL_WIDTH - 1 downto 0);
  signal slot_index   : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);

begin
  process (clk)
  begin
    if rising_edge(clk) then
      if slot_counter = to_unsigned(CALENDAR_INTERVAL - 1, slot_counter'length) then
        slot_counter <= (others => '0');
        slot_index <= (slot_index + 1) and to_unsigned(CALENDAR_SLOTS - 1, slot_index'length); -- modulo via masking if CALENDAR_SLOTS is a power of 2
        update <= '1';
      else
        slot_counter <= slot_counter + 1;
        update <= '0';
      end if;

      if rst = '1' then
        slot_counter <= (others => '0');
        slot_index <= (others => '0');
        update <= '0';
      end if;
    end if;
  end process;

  cur_slot <= slot_index;

end architecture;
