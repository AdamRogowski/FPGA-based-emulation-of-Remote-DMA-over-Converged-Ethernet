-- filepath: c:\Users\jaro\Desktop\git-projects\DCQCN_model\hardware_scheduler\sim\Scheduler\tb_fifo_generic.vhd
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity tb_fifo_generic is
end entity;

architecture sim of tb_fifo_generic is

  constant DATA_WIDTH : integer := 8;
  constant ADDR_WIDTH : integer := 3; -- FIFO depth = 8

  signal clk            : std_logic                                 := '0';
  signal rst            : std_logic                                 := '1';
  signal append_enable  : std_logic                                 := '0';
  signal new_element    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
  signal pop_enable     : std_logic                                 := '0';
  signal popped_element : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal empty          : std_logic;
  signal full           : std_logic;

  component fifo
    generic (
      DATA_WIDTH : integer := 8;
      ADDR_WIDTH : integer := 3
    );
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      append_enable  : in  std_logic;
      new_element    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      pop_enable     : in  std_logic;
      popped_element : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      empty          : out std_logic;
      full           : out std_logic
    );
  end component;

begin

  -- Clock generation
  clk_process: process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- DUT instantiation
  dut: fifo
    generic map (
      DATA_WIDTH => DATA_WIDTH,
      ADDR_WIDTH => ADDR_WIDTH
    )
    port map (
      clk            => clk,
      rst            => rst,
      append_enable  => append_enable,
      new_element    => new_element,
      pop_enable     => pop_enable,
      popped_element => popped_element,
      empty          => empty,
      full           => full
    );

  -- Stimulus process
  stim_proc: process
  begin
    -- Reset
    rst <= '1';
    wait for CLK_PERIOD;
    rst <= '0';
    wait for CLK_PERIOD;

    -- Fill FIFO
    for i in 0 to 7 loop
      append_enable <= '1';
      new_element <= std_logic_vector(to_unsigned(i + 1, DATA_WIDTH));
      wait for CLK_PERIOD;
    end loop;
    append_enable <= '0';
    new_element <= (others => '0');
    wait for CLK_PERIOD;

    -- Try to write when full (should not write)
    append_enable <= '1';
    new_element <= std_logic_vector(to_unsigned(99, DATA_WIDTH));
    wait for CLK_PERIOD;
    append_enable <= '0';
    wait for CLK_PERIOD;

    -- Read all elements
    for i in 0 to 7 loop
      pop_enable <= '1';
      wait for CLK_PERIOD;
    end loop;
    pop_enable <= '0';
    wait for CLK_PERIOD;

    -- Try to read when empty (should not read)
    pop_enable <= '1';
    wait for CLK_PERIOD;
    pop_enable <= '0';
    wait for CLK_PERIOD;

    append_enable <= '1';
    new_element <= std_logic_vector(to_unsigned(10, DATA_WIDTH));
    wait for CLK_PERIOD;
    append_enable <= '0';
    wait for CLK_PERIOD;

    -- Simultaneous push and pop (should work as circular buffer)
    for i in 10 to 13 loop
      append_enable <= '1';
      new_element <= std_logic_vector(to_unsigned(i, DATA_WIDTH));
      pop_enable <= '1';
      wait for CLK_PERIOD;
    end loop;
    append_enable <= '0';
    pop_enable <= '0';
    wait for 20 ns;

    -- End simulation
    wait;
  end process;

end architecture;
