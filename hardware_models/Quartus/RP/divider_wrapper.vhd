library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  -- This wrapper entity has an interface similar to your original simple_divider

entity divider_wrapper is
  port (
    clock      : in  std_logic;
    x_in       : in  std_logic_vector(15 downto 0);
    result_out : out std_logic_vector(16 downto 0)
  );
end entity;

architecture rtl of divider_wrapper is

  -- Component declaration for the divider IP
  component divider_optimized is
    port (
      numer    : in  std_logic_vector(35 downto 0);
      denom    : in  std_logic_vector(15 downto 0);
      clock    : in  std_logic;
      quotient : out std_logic_vector(35 downto 0);
      remain   : out std_logic_vector(15 downto 0)
    );
  end component;

  -- Constant C for the division
  constant C_VALUE : natural := 23437500;

  -- Signal to connect to the quotient output of the IP
  signal quotient_signal : std_logic_vector(35 downto 0);
  signal remain_signal   : std_logic_vector(15 downto 0);

begin

  -- Instantiate the divider_optimized IP
  divider_inst: component divider_optimized
    port map (
      numer    => std_logic_vector(to_unsigned(C_VALUE, 36)),
      denom    => x_in,
      clock    => clock,
      quotient => quotient_signal,
      remain   => remain_signal
    );

  -- Assign the lower 17 bits of the quotient to the output.

  -- You may need to add logic to handle division by zero if the IP doesn't.
  process (clock)
  begin
    if rising_edge(clock) then
      if to_integer(unsigned(x_in)) = 0 then
        result_out <= (others => '1'); -- Max value for division by zero
      else
        result_out <= quotient_signal(16 downto 0);
      end if;
    end if;
  end process;

end architecture;
