-- https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Dual-Port-Block-RAM-with-Two-Write-Ports-in-Read-First-Mode-VHDL

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity bram_model is
  generic (
    DATA_WIDTH : integer := 128;
    ADDR_WIDTH : integer := 18; -- 262k locations
    LATENCY    : integer := 3   -- number of pipeline stages
  );
  port (
    clk   : in  std_logic;
    ena   : in  std_logic;
    enb   : in  std_logic;
    wea   : in  std_logic;
    web   : in  std_logic;
    addra : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    addrb : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    dia   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    dib   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    doa   : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    dob   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of bram_model is

  -- Memory
  type ram_type is array (0 to 2 ** ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram : ram_type := (others => (others => '1'));

  -- Pipelined outputs
  type pipeline_array is array (0 to LATENCY - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal pipeline_a : pipeline_array := (others => (others => '1'));
  signal pipeline_b : pipeline_array := (others => (others => '1'));

begin

  process (clk)
    variable addr_a_int, addr_b_int : integer;
  begin
    if rising_edge(clk) then

      -- Convert addresses
      addr_a_int := to_integer(unsigned(addra));
      addr_b_int := to_integer(unsigned(addrb));

      -- Port A: READ_FIRST
      if ena = '1' then
        -- First capture read value
        pipeline_a(0) <= ram(addr_a_int);
        -- Then perform write (doesn't affect current read output)
        if wea = '1' then
          ram(addr_a_int) <= dia;
        end if;
      end if;

      -- Port B: READ_FIRST
      if enb = '1' then
        pipeline_b(0) <= ram(addr_b_int);
        -- Port B write only if not conflicting
        if web = '1' and not (wea = '1' and addr_a_int = addr_b_int) then
          ram(addr_b_int) <= dib;
        end if;
      end if;

      -- Shift pipelines for latency
      for i in 1 to LATENCY - 1 loop
        pipeline_a(i) <= pipeline_a(i - 1);
        pipeline_b(i) <= pipeline_b(i - 1);
      end loop;

    end if;
  end process;

  -- Outputs after constant latency
  doa <= pipeline_a(LATENCY - 1);
  dob <= pipeline_b(LATENCY - 1);

end architecture;
