-- file: constants_pkg.vhd
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package constants_pkg is

  constant MTU_BITS       : integer := 12000;   -- Number of bits for MTU
  constant QP_WIDTH       : integer := 6;       -- Number of bits for QP
  constant SEQ_NR_WIDTH   : integer := 6;       -- Number of bits for sequence number
  constant TOTAL_MAX_RATE : real    := 1.0E11;  -- 100 Gbps
  constant CLK_PERIOD     : time    := 5.12 ns; -- Clock period for simulation

  constant NUM_GROUPS              : integer                                           := 4;                           -- Number of groups
  constant NUM_FLOWS               : integer                                           := 16;                          -- Number of flows per group
  constant NUM_FLOWS_TOTAL         : integer                                           := NUM_GROUPS * NUM_FLOWS;      -- Total number of flows
  constant FLAT_FLOW_ADDRESS_WIDTH : integer                                           := 6;                           -- log2(NUM_FLOWS_TOTAL); just based on the number of flows
  constant FLOW_ADDRESS_WIDTH      : integer                                           := FLAT_FLOW_ADDRESS_WIDTH + 1; -- Including additional bit to include the null address
  constant FLOW_NULL_ADDRESS       : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '1');             -- NULL address

  constant CALENDAR_INTERVAL       : integer := 100;
  constant CALENDAR_INTERVAL_WIDTH : integer := 7; -- log2(CALENDAR_INTERVAL); -- Number of bits for interval counter

  --constant RATE_BIT_RESOLUTION       : integer := 8;
  --constant RATE_BIT_RESOLUTION_WIDTH : integer := 3; -- log2(RATE_BIT_RESOLUTION); -- Number of bits for rate resolution
  constant CALENDAR_SLOTS       : integer := 131072;
  constant CALENDAR_SLOTS_WIDTH : integer := 17; -- log2(CALENDAR_SLOTS); -- Number of bits for slot index

  constant IPG_DIVIDEND : real := 2.34375E10; -- division numerator

  -- MEM constants
  constant QP_PADDING : std_logic_vector(QP_WIDTH - FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '0'); -- Padding for QP to match FLOW_ADDRESS_WIDTH

  --Rate memory data format
  --|cur_rate|
  --|    3   |
  constant RATE_MEM_DATA_WIDTH      : integer                                            := CALENDAR_SLOTS_WIDTH;
  constant RATE_MEM_NULL_ENTRY      : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0) := (others => '1');
  constant RATE_MEM_ADDR_WIDTH      : integer                                            := FLAT_FLOW_ADDRESS_WIDTH; -- All addressable addresses in the memory
  constant RATE_MEM_DEFAULT_ADDRESS : std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');         -- First address in the memory
  constant RATE_MEM_LATENCY         : integer                                            := 3;                       -- Has to be the same as FLOW_MEM_LATENCY for the scheduler to work properly

  -- RP_flow_update constants
  constant GLOBAL_TIMER_WIDTH  : integer                              := 16;                   -- TODO: consider the least sufficient size for the global timer
  constant RP_RATE_WIDTH       : integer                              := 18;
  constant RP_RATE_DEFAULT     : unsigned(RP_RATE_WIDTH - 1 downto 0) := "000000000111111111"; -- Never set to 0!
  constant RP_RATE_MAX_DEFAULT : unsigned(RP_RATE_WIDTH - 1 downto 0) := (others => '1');      -- Maximum rate for the RP
  constant RP_DATA_SENT_WIDTH  : integer                              := 1;                    -- Number of bits for the data sent input, 1 bit = std_logic

  constant FLOATING_POINT_WIDTH : integer                                     := 16;                              -- Width of the floating point representation for the rate update
  constant ONE                  : unsigned(FLOATING_POINT_WIDTH - 1 downto 0) := (others => '1');                 -- to_unsigned(65536, 16); Q16 fixed point 1.0
  constant G                    : unsigned(FLOATING_POINT_WIDTH - 1 downto 0) := "0011111111111111";              -- weight factor, to_unsigned(16384, 16); Q16 fixed point 0.25
  constant R_AI                 : unsigned(RP_RATE_WIDTH - 1 downto 0)        := to_unsigned(10, RP_RATE_WIDTH);  -- Additive increase rate increment value
  constant R_HAI                : unsigned(RP_RATE_WIDTH - 1 downto 0)        := to_unsigned(100, RP_RATE_WIDTH); -- Huper Additive increase rate increment value

  constant K                 : integer                            := 50; --Reduction factor update threshold, originally around 55us ONLY associated with change of alpha
  constant K_WIDTH           : integer                            := 7;
  constant ALPHA_WIDTH       : integer                            := 16;
  constant ALPHA_DEFAULT     : unsigned(ALPHA_WIDTH - 1 downto 0) := (others => '0');
  constant ALPHA_TIMER_WIDTH : integer                            := K_WIDTH;

  -- The cycle duration of 150 KBytes is chosen to correspond to the transmission of 100 frames, each 1500 Bytes long. [17] IEEE. 802.11Qau. Congestion notification, 2010.
  -- B constant is associated with BC
  constant B       : integer := 3; -- threshold for the ByteCounter incrementation: n times MTU; (default 100 x MTU)
  constant B_WIDTH : integer := 3; -- log2(B)

  -- The Timer functions similarly as the Byte Counter: it is reset when a feedback message arrives, enters FR
  -- and counts out 5 cycles of T ms duration (T is 10 ms long in the baseline). [17] IEEE. 802.11Qau. Congestion notification, 2010.
  constant T       : integer := 70; -- threshold for the Timer incrementation: 1953125clk * 5.12ns/clk ~= 10ms
  constant T_WIDTH : integer := 8;  -- log2(T)

  constant F                                 : integer                        := 5; -- Fast Recovery iterations
  constant F_WIDTH                           : integer                        := 3;
  constant TC_WIDTH, BC_WIDTH                : integer                        := 3;
  constant F_DEFAULT, TC_DEFAULT, BC_DEFAULT : unsigned(F_WIDTH - 1 downto 0) := (others => '0');

  -- RP internal flow mem
  constant RP_MEM_DATA_WIDTH      : integer                                          := 3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH + BC_WIDTH + B_WIDTH;
  constant RP_MEM_NULL_ENTRY      : std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');
  constant RP_MEM_ADDR_WIDTH      : integer                                          := FLOW_ADDRESS_WIDTH; -- All addressable addresses in the memory
  constant RP_MEM_DEFAULT_ADDRESS : std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');    -- First address in the memory
  constant RP_MEM_LATENCY         : integer                                          := 3;                  -- Memory access latency in clock cycles

  constant RP_PIPELINE_SIZE    : integer := RP_MEM_LATENCY + 6; -- Number of pipeline stages for the RP
  constant RP_PIPELINE_STAGE_0 : integer := 0;
  constant RP_PIPELINE_STAGE_1 : integer := RP_MEM_LATENCY + 1;
  constant RP_PIPELINE_STAGE_2 : integer := RP_MEM_LATENCY + 2;
  constant RP_PIPELINE_STAGE_3 : integer := RP_MEM_LATENCY + 3;
  constant RP_PIPELINE_STAGE_4 : integer := RP_MEM_LATENCY + 4;
  constant RP_PIPELINE_STAGE_5 : integer := RP_MEM_LATENCY + 5;

end package;

package body constants_pkg is
end package body;
