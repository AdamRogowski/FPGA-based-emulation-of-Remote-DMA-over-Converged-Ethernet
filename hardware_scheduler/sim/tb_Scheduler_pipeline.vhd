library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all;

entity tb_pipelined_stack_processor is
end entity;

architecture sim of tb_pipelined_stack_processor is

  -- Component under test
  component pipelined_stack_processor is
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      start      : in  std_logic;
      first_addr : in  std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0);
      done       : out std_logic
    );
  end component;

  signal clk        : std_logic                                         := '0';
  signal rst        : std_logic                                         := '1';
  signal start      : std_logic                                         := '0';
  signal first_addr : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal done       : std_logic;

begin

  -- Clock process
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- DUT instantiation
  dut: pipelined_stack_processor
    port map (
      clk        => clk,
      rst        => rst,
      start      => start,
      first_addr => first_addr,
      done       => done
    );

  -- Stimulus process
  stim_proc: process
    constant base_addr : unsigned(FLOW_ADDRESS_WIDTH - 1 downto 0) := "000000001";
  begin
    wait for 20 ns;
    rst <= '0';

    -- Start pipeline
    first_addr <= std_logic_vector(base_addr);
    start <= '1';
    wait for CLK_PERIOD;
    start <= '0';

    -- Wait for pipeline to complete
    wait until done = '1';
    wait for 50 ns;

    assert false report "Test complete" severity note;
    wait;
  end process;

end architecture;
