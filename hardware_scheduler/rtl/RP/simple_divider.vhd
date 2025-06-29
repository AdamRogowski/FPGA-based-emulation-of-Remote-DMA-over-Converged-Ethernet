library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity simple_divider is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    x_in       : in  std_logic_vector(15 downto 0);
    result_out : out std_logic_vector(16 downto 0)
  );
end entity;

architecture rtl of simple_divider is
  constant C : natural := 23437500;
  signal x_unsigned      : unsigned(15 downto 0);
  signal result_unsigned : unsigned(16 downto 0);
begin

  x_unsigned <= unsigned(x_in);

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        result_unsigned <= (others => '0');
      else
        if x_unsigned /= 0 then
          result_unsigned <= to_unsigned(C / to_integer(x_unsigned), 17);
        else
          result_unsigned <= (others => '1'); -- Max value for division by zero
        end if;
      end if;
    end if;
  end process;

  result_out <= std_logic_vector(result_unsigned);

end architecture;
