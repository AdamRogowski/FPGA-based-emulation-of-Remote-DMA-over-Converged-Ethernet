library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity global_timer is
  generic (
    GLOBAL_TIMER_WIDTH : integer := 32
  );
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    global_timer : out unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of global_timer is
  signal timer_reg : unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0) := (others => '0');
begin
  process (clk)
  begin

    if rising_edge(clk) then
      timer_reg <= timer_reg + 1;
    end if;

    if reset = '1' then
      timer_reg <= (others => '0');
    end if;
  end process;

  global_timer <= timer_reg;
end architecture;
