library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants
  use work.bram_init_pkg.all; -- Import memory initialization package

entity tb_RP_Flow_Update is
end entity;

architecture sim of tb_RP_Flow_Update is

  -- DUT signals
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal flow_rdy_i  : std_logic                                        := '0';
  signal is_cnp_i    : std_logic                                        := '0';
  signal flow_id_i   : std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal data_sent_i : std_logic                                        := '0';

  -- Instantiate DUT
  component RP_Flow_Update
    port (
      clk         : in std_logic;
      rst         : in std_logic;
      flow_rdy_i  : in std_logic;
      is_cnp_i    : in std_logic;
      flow_id_i   : in std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0);
      data_sent_i : in std_logic
    );
  end component;

begin

  DUT: RP_Flow_Update
    port map (
      clk         => clk,
      rst         => rst,
      flow_rdy_i  => flow_rdy_i,
      is_cnp_i    => is_cnp_i,
      flow_id_i   => flow_id_i,
      data_sent_i => data_sent_i
    );

  -- Clock generation
  clk_proc: process
  begin
    while true loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end loop;
  end process;

  -- Stimulus process
  stim_proc: process
  begin
    -- Apply reset
    wait for 20 ns;
    rst <= '0';

    -- Wait few clocks
    wait for 20 ns;

    -- Test case 1: Normal packet
    flow_rdy_i <= '1';
    is_cnp_i <= '0';
    flow_id_i <= std_logic_vector(to_unsigned(0, RP_MEM_ADDR_WIDTH));
    data_sent_i <= '1';
    wait for CLK_PERIOD;
    flow_rdy_i <= '0';

    -- Wait pipeline delay
    wait for 200 ns;

    -- Test case 2: CNP received
    flow_rdy_i <= '1';
    is_cnp_i <= '1';
    flow_id_i <= std_logic_vector(to_unsigned(1, RP_MEM_ADDR_WIDTH));
    data_sent_i <= '0';
    wait for CLK_PERIOD;
    flow_rdy_i <= '0';

    -- Wait pipeline delay
    wait for 200 ns;

    -- Finish simulation
    wait;
  end process;

end architecture;
