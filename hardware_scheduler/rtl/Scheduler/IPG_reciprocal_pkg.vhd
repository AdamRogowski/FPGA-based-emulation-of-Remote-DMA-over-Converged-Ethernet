library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants from the package

package IPG_reciprocal_pkg is

  type reciprocal_table_type is array (0 to RATE_BIT_RESOLUTION - 1) of unsigned(CALENDAR_SLOTS_WIDTH - 1 downto 0); -- highest scheduled value cannot exceed number of calendar slots

  function generate_reciprocal_table return reciprocal_table_type;
end package;

package body IPG_reciprocal_pkg is

  function generate_reciprocal_table return reciprocal_table_type is
    variable table : reciprocal_table_type;
    constant max_rate   : real := TOTAL_MAX_RATE / real(NUM_FLOWS_TOTAL);
    constant min_rate   : real := max_rate / 2.0;
    constant resolution : real := (min_rate) / real(RATE_BIT_RESOLUTION);

    variable rate_i : real;
    variable result : integer;
  begin
    for i in 0 to RATE_BIT_RESOLUTION - 1 loop
      rate_i := min_rate + real(i) * resolution;

      if rate_i = 0.0 then
        result := integer(CALENDAR_SLOTS - 1); -- max fallback value
      else
        result := integer(IPG_DIVIDEND / rate_i);
      end if;

      table(i) := to_unsigned(result, CALENDAR_SLOTS_WIDTH);
    end loop;

    return table;
  end function;
end package body;
