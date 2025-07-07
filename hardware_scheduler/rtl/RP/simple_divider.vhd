library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity simple_divider is
  generic (
    PIPELINE_STAGES : natural := 3
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    x_in       : in  std_logic_vector(15 downto 0);
    result_out : out std_logic_vector(16 downto 0)
  );
end entity;

architecture rtl of simple_divider is
  constant C : natural := 23437500;
  signal result_unsigned : unsigned(16 downto 0);

  -- Pipeline registers for retiming, depth is controlled by the generic
  type T_RESULT_PIPELINE is array (0 to PIPELINE_STAGES - 1) of unsigned(16 downto 0);
  signal result_pipeline : T_RESULT_PIPELINE;

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        result_unsigned <= (others => '0');
        result_pipeline <= (others => (others => '0'));
      else
        -- The division is calculated in one cycle
        if unsigned(x_in) /= 0 then
          result_unsigned <= to_unsigned(C / to_integer(unsigned(x_in)), 17);
        else
          result_unsigned <= (others => '1'); -- Max value for division by zero
        end if;

        -- The result is then passed through a pipeline
        result_pipeline(0) <= result_unsigned;
        for i in 1 to PIPELINE_STAGES - 1 loop
          result_pipeline(i) <= result_pipeline(i - 1);
        end loop;
      end if;
    end if;
  end process;

  result_out <= std_logic_vector(result_pipeline(PIPELINE_STAGES - 1));

end architecture;
