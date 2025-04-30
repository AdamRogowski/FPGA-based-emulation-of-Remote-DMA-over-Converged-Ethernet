library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all;

entity bram_tb is
end entity;

architecture sim of bram_tb is

  -- DUT parameters
  constant DATA_WIDTH : integer := 8;
  constant ADDR_WIDTH : integer := 3;
  constant LATENCY    : integer := 3;

  signal clk                : std_logic                                 := '0';
  signal ena, enb, wea, web : std_logic                                 := '0';
  signal addra, addrb       : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal dia, dib           : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
  signal doa, dob           : std_logic_vector(DATA_WIDTH - 1 downto 0);

  procedure wait_cycles(signal clk : in std_logic; n : integer) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure;

begin

  -- Instantiate the DUT
  DUT: entity work.bram_model
    generic map (
      DATA_WIDTH => DATA_WIDTH,
      ADDR_WIDTH => ADDR_WIDTH,
      LATENCY    => LATENCY
    )
    port map (
      clk   => clk,
      ena   => ena,
      enb   => enb,
      wea   => wea,
      web   => web,
      addra => addra,
      addrb => addrb,
      dia   => dia,
      dib   => dib,
      doa   => doa,
      dob   => dob
    );

  -- Clock process
  clk_process: process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- Stimulus process
  stimulus: process
  begin

    ------------------------------------------------------------------------
    -- Test 1: Write to A, read from A (same cycle), NO_CHANGE behavior
    ------------------------------------------------------------------------
    wait for 20 ns;
    wait until rising_edge(clk);
    addra <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
    dia <= x"AA";
    ena <= '1';
    wea <= '1';

    addrb <= std_logic_vector(to_unsigned(3, ADDR_WIDTH));
    dib <= x"DD";
    enb <= '1';
    web <= '1';

    wait until rising_edge(clk);
    --wea <= '0';
    --ena <= '0'; -- Disable A after write
    addra <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
    dia <= x"BB";

    addrb <= std_logic_vector(to_unsigned(4, ADDR_WIDTH));
    dib <= x"EE";
    --ena <= '1';
    --wea <= '1';
    wait until rising_edge(clk);
    addra <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    dia <= x"CC";

    addrb <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    dib <= x"FF";

    wait until rising_edge(clk);
    addra <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    wea <= '0';

    addrb <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    web <= '0';

    wait until rising_edge(clk);
    addra <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
    addrb <= std_logic_vector(to_unsigned(4, ADDR_WIDTH));

    wait until rising_edge(clk);
    addra <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
    addrb <= std_logic_vector(to_unsigned(3, ADDR_WIDTH));

    wait until rising_edge(clk);
    ena <= '0';
    enb <= '0';

    wait until rising_edge(clk);

    addra <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    dia <= x"22";
    ena <= '1';
    wea <= '1';

    addrb <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    enb <= '1';

    wait until rising_edge(clk);

    addra <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    wea <= '0';

    wait until rising_edge(clk);

    ------------------------------------------------------------------------
    -- Test 3: Write via B, read via B
    ------------------------------------------------------------------------
    addrb <= std_logic_vector(to_unsigned(4, ADDR_WIDTH));
    dib <= x"BB";
    enb <= '1';
    web <= '1';

    wait until rising_edge(clk);
    web <= '0';

    wait_cycles(clk, LATENCY);

    -- Now read the newly written value
    enb <= '1';
    web <= '0';
    wait_cycles(clk, LATENCY);

    ------------------------------------------------------------------------
    -- Test 4: Port A and B write/read different addresses concurrently
    ------------------------------------------------------------------------
    addra <= std_logic_vector(to_unsigned(5, ADDR_WIDTH));
    dia <= x"AA";
    ena <= '1';
    wea <= '1';

    addrb <= std_logic_vector(to_unsigned(6, ADDR_WIDTH));
    dib <= x"CC";
    enb <= '1';
    web <= '1';

    wait until rising_edge(clk);
    wea <= '0';
    web <= '0';

    -- Read both
    ena <= '1';
    wea <= '0';
    enb <= '1';
    web <= '0';
    wait_cycles(clk, LATENCY);

    ------------------------------------------------------------------------
    -- Test 5: Conflict — both ports access same address
    ------------------------------------------------------------------------
    addra <= std_logic_vector(to_unsigned(7, ADDR_WIDTH));
    dia <= x"11";
    ena <= '1';
    wea <= '1';

    addrb <= std_logic_vector(to_unsigned(7, ADDR_WIDTH));
    dib <= x"22";
    enb <= '1';
    web <= '1';

    wait until rising_edge(clk);
    wea <= '0';
    web <= '0';

    -- Read back from both ports
    ena <= '1';
    wea <= '0';
    enb <= '1';
    web <= '0';
    wait_cycles(clk, LATENCY);

    -- This test may result in one write overriding the other depending on order
    -- No assert here unless arbiter is defined.

    ------------------------------------------------------------------------
    -- Done
    ------------------------------------------------------------------------
    wait;

  end process;

end architecture;
