library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.constants_pkg.all; -- Import constants

entity tb_RP_input_queue is
end entity;

architecture sim of tb_RP_input_queue is

  constant PIPELINE_ADDR_WIDTH : integer := 4; -- log2(4)
  constant FIFO_ADDR_WIDTH     : integer := 3; -- log2(8)

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal cnp_valid    : std_logic                                              := '0';
  signal cnp_flow_id  : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal data_valid   : std_logic                                              := '0';
  signal data_flow_id : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
  signal data_sent    : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)              := (others => '0');

  signal flow_rdy_o  : std_logic;
  signal is_cnp_o    : std_logic;
  signal flow_id_o   : std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
  signal data_sent_o : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);

  component RP_input_queue_simplified
    generic (
      PIPELINE_ADDR_WIDTH : integer;
      FIFO_ADDR_WIDTH     : integer
    );
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      cnp_valid    : in  std_logic;
      cnp_flow_id  : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_valid   : in  std_logic;
      data_flow_id : in  std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent    : in  unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
      flow_rdy_o   : out std_logic;
      is_cnp_o     : out std_logic;
      flow_id_o    : out std_logic_vector(FLAT_FLOW_ADDRESS_WIDTH - 1 downto 0);
      data_sent_o  : out unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)
    );
  end component;

begin

  -- Instantiate DUT
  uut: RP_input_queue_simplified
    generic map (
      PIPELINE_ADDR_WIDTH => PIPELINE_ADDR_WIDTH,
      FIFO_ADDR_WIDTH     => FIFO_ADDR_WIDTH
    )
    port map (
      clk          => clk,
      rst          => rst,
      cnp_valid    => cnp_valid,
      cnp_flow_id  => cnp_flow_id,
      data_valid   => data_valid,
      data_flow_id => data_flow_id,
      data_sent    => data_sent,
      flow_rdy_o   => flow_rdy_o,
      is_cnp_o     => is_cnp_o,
      flow_id_o    => flow_id_o,
      data_sent_o  => data_sent_o
    );

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

  -- Stimulus process
  stim_proc: process
  begin
    -- Reset
    rst <= '1';
    wait for CLK_PERIOD;
    rst <= '0';
    wait for CLK_PERIOD;

    wait for 10 * CLK_PERIOD; -- Allow some time for reset to propagate

    -- Send a CNP notification for flow 1
    cnp_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    cnp_valid <= '1';

    data_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent <= "1";
    data_valid <= '1';
    wait for CLK_PERIOD;
    cnp_valid <= '0';
    data_valid <= '0';
    wait for 5 * CLK_PERIOD;

    cnp_flow_id <= std_logic_vector(to_unsigned(3, FLAT_FLOW_ADDRESS_WIDTH));
    cnp_valid <= '1';

    --data_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    --data_sent <= "1";
    --data_valid <= '1';
    wait for CLK_PERIOD;
    cnp_valid <= '0';
    --data_valid <= '0';
    wait for 15 * CLK_PERIOD;

    cnp_flow_id <= std_logic_vector(to_unsigned(5, FLAT_FLOW_ADDRESS_WIDTH));
    cnp_valid <= '1';

    --data_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    --data_sent <= "1";
    --data_valid <= '1';
    wait for CLK_PERIOD;
    cnp_valid <= '0';
    --data_valid <= '0';
    wait for CLK_PERIOD;

    --wait for CLK_PERIOD;
    data_flow_id <= std_logic_vector(to_unsigned(16, FLAT_FLOW_ADDRESS_WIDTH));
    data_sent <= "1";
    data_valid <= '1';
    wait for CLK_PERIOD;
    data_valid <= '0';

    wait for 3 * CLK_PERIOD; -- Allow some time for reset to propagate

    -- Send a CNP notification for flow 1
    cnp_flow_id <= std_logic_vector(to_unsigned(5, FLAT_FLOW_ADDRESS_WIDTH));
    cnp_valid <= '1';

    --data_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    --data_sent <= "1";
    --data_valid <= '1';
    wait for CLK_PERIOD;
    cnp_valid <= '0';

    wait for 5 * CLK_PERIOD; -- Allow some time for reset to propagate

    -- Send a CNP notification for flow 1
    cnp_flow_id <= std_logic_vector(to_unsigned(5, FLAT_FLOW_ADDRESS_WIDTH));
    cnp_valid <= '1';

    --data_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    --data_sent <= "1";
    --data_valid <= '1';
    wait for CLK_PERIOD;
    cnp_valid <= '0';

    wait for 5 * CLK_PERIOD; -- Allow some time for reset to propagate

    -- Send a CNP notification for flow 1
    cnp_flow_id <= std_logic_vector(to_unsigned(16, FLAT_FLOW_ADDRESS_WIDTH));
    cnp_valid <= '1';

    --data_flow_id <= std_logic_vector(to_unsigned(1, FLAT_FLOW_ADDRESS_WIDTH));
    --data_sent <= "1";
    --data_valid <= '1';
    wait for CLK_PERIOD;
    cnp_valid <= '0';

    -- End simulation
    wait;
  end process;

end architecture;
