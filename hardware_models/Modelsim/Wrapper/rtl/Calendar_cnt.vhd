library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all; -- Import constants

  -- ============================================================================
  -- Entity: Calendar_cnt
  -- Description:
  --   Calendar slot counter for DCQCN scheduler.
  --   - Generates current slot index and update pulse at each interval.
  --   - Handles slot wrap-around and synchronous reset.
  -- ============================================================================

entity Calendar_cnt is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    slot_index  : out unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0);
    slot_update : out std_logic -- Pulse when moving to the next slot
  );
end entity;

architecture rtl of Calendar_cnt is

  signal interval_counter : unsigned(CALENDAR_INTERVAL_WIDTH - 1 downto 0) := (others => '0');
  signal slot_counter     : unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0)    := (others => '0');
  signal update_reg       : std_logic                                      := '0';

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        interval_counter <= (others => '0');
        slot_counter <= (others => '0');
        update_reg <= '0';
      else
        if interval_counter = to_unsigned(CALENDAR_INTERVAL - 1, interval_counter'length) then
          interval_counter <= (others => '0');
          if slot_counter = to_unsigned(CALENDAR_SLOTS - 1, slot_counter'length) then
            slot_counter <= (others => '0');
          else
            slot_counter <= slot_counter + 1;
          end if;
          update_reg <= '1';
        else
          interval_counter <= interval_counter + 1;
          update_reg <= '0';
        end if;
      end if;
    end if;
  end process;

  slot_index  <= slot_counter;
  slot_update <= update_reg;

end architecture;
