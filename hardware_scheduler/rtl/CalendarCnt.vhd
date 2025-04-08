library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_ARITH.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;

entity CalendarCnt is
  generic (
    NUM_SLOTS : integer := 16; -- Total calendar slots
    INTERVAL  : integer := 100 -- Cycles before moving to next slot
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    cur_slot : out integer range 0 to NUM_SLOTS - 1;
    update   : out std_logic -- Pulse when moving to the next slot
  );
end entity;

architecture RTL of CalendarCnt is
  signal slot_counter : integer range 0 to INTERVAL - 1  := 0;
  signal slot_index   : integer range 0 to NUM_SLOTS - 1 := 0;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if slot_counter = INTERVAL - 1 then
        slot_counter <= 0;
        slot_index <= (slot_index + 1) mod NUM_SLOTS;
        update <= '1';
      else
        slot_counter <= slot_counter + 1;
        update <= '0';
      end if;

      if rst = '1' then
        slot_counter <= 0;
        slot_index <= 0;
        update <= '0';
      end if;
    end if;
  end process;

  cur_slot <= slot_index;

end architecture;
