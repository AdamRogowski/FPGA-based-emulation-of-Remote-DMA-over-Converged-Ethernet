library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
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
  signal slot_counter : unsigned(CALENDAR_INTERVAL_WIDTH - 1 downto 0) := (others => '0');
  signal slot_index   : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0) := (others => '0');
  signal update_reg   : std_logic := '0';
begin

  process(clk)
  begin
    if rising_edge(clk) then

      if slot_counter = to_unsigned(CALENDAR_INTERVAL - 1, slot_counter'length) then
        slot_counter <= (others => '0');

        if slot_index = to_unsigned(CALENDAR_SLOTS - 1, slot_index'length) then
          slot_index <= (others => '0');
        else
          slot_index <= slot_index + 1;
        end if;

        update_reg <= '1';
      else
        slot_counter <= slot_counter + 1;
        update_reg <= '0';
      end if;

      if rst = '1' then
        slot_counter <= (others => '0');
        slot_index   <= (others => '0');
        update_reg   <= '0';
      end if;
    end if;
  end process;

  cur_slot <= slot_index;
  update   <= update_reg;

end architecture;
