-- https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Dual-Port-Block-RAM-with-Two-Write-Ports-in-Read-First-Mode-VHDL

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.bram_init_pkg.all;
  use work.constants_pkg.all; -- Import constants

entity Rate_mem is
  generic (
    LATENCY : integer := 3 -- number of pipeline stages
  );
  port (
    clk          : in  std_logic;
    ena, enb     : in  std_logic;
    wea, web     : in  std_logic;
    addra, addrb : in  std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
    dia, dib     : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
    doa, dob     : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of Rate_mem is

  signal ram : rate_mem_type;

begin

  -- Port A
  process (clk)
  begin
    if rising_edge(clk) then
      if ena = '1' then
        doa <= ram(to_integer(unsigned(addra)));
        if wea = '1' then
          ram(to_integer(unsigned(addra))) <= dia;
        end if;
      end if;
    end if;
  end process;

  -- Port B
  process (clk)
  begin
    if rising_edge(clk) then
      if enb = '1' then
        dob <= ram(to_integer(unsigned(addrb)));
        if web = '1' then
          ram(to_integer(unsigned(addrb))) <= dib;
        end if;
      end if;
    end if;
  end process;

end architecture;
