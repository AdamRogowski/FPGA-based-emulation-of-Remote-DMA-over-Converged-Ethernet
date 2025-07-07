library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package divider_optimized_pkg is
	component divider_optimized_lpm_divide_201_ruc2ypa is
		port (
			numer    : in  std_logic_vector(35 downto 0) := (others => 'X'); -- numer
			denom    : in  std_logic_vector(15 downto 0) := (others => 'X'); -- denom
			clock    : in  std_logic                     := 'X';             -- clock
			quotient : out std_logic_vector(35 downto 0);                    -- quotient
			remain   : out std_logic_vector(15 downto 0)                     -- remain
		);
	end component divider_optimized_lpm_divide_201_ruc2ypa;

end divider_optimized_pkg;
