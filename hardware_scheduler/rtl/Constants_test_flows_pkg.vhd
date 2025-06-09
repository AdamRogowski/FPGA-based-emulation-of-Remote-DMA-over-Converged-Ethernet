-- file: constants_pkg.vhd
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package constants_pkg is

  constant MTU_BITS       : integer := 12000;  -- Number of bits for MTU
  constant QP_WIDTH       : integer := 24;     -- Number of bits for QP
  constant SEQ_NR_WIDTH   : integer := 24;     -- Number of bits for sequence number
  constant TOTAL_MAX_RATE : real    := 1.0E11; -- 100 Gbps
  constant CLK_PERIOD     : time    := 10 ns;  -- Clock period for simulation

  constant NUM_GROUPS              : integer                                           := 64;                          -- Number of groups
  constant NUM_FLOWS               : integer                                           := 64;                          -- Number of flows per group
  constant NUM_FLOWS_TOTAL         : integer                                           := NUM_GROUPS * NUM_FLOWS;      -- Total number of flows
  constant FLAT_FLOW_ADDRESS_WIDTH : integer                                           := 12;                          -- log2(NUM_FLOWS_TOTAL); just based on the number of flows
  constant FLOW_ADDRESS_WIDTH      : integer                                           := FLAT_FLOW_ADDRESS_WIDTH + 1; -- Including additional bit to include the null address
  constant FLOW_NULL_ADDRESS       : std_logic_vector(FLOW_ADDRESS_WIDTH - 1 downto 0) := (others => '1');             -- NULL address

  constant CALENDAR_INTERVAL       : integer := 100;
  constant CALENDAR_INTERVAL_WIDTH : integer := 7; -- log2(CALENDAR_INTERVAL); -- Number of bits for interval counter

  constant RATE_BIT_RESOLUTION       : integer := 131072;
  constant RATE_BIT_RESOLUTION_WIDTH : integer := 17; -- log2(RATE_BIT_RESOLUTION); -- Number of bits for rate resolution

  constant CALENDAR_SLOTS       : integer := 131072;
  constant CALENDAR_SLOTS_WIDTH : integer := 17; -- log2(CALENDAR_SLOTS); -- Number of bits for slot index

  constant IPG_DIVIDEND : real := 2.34375E10; -- division numerator

  -- MEM constants

  -- Flow memory data format
  --|active_flag|seq_nr|next_addr|QP |
  --|    1      |  24  |    19   | 24|
  constant FLOW_MEM_DATA_WIDTH      : integer                                            := QP_WIDTH + SEQ_NR_WIDTH + FLOW_ADDRESS_WIDTH + 1;
  constant FLOW_MEM_NULL_ENTRY      : std_logic_vector(FLOW_MEM_DATA_WIDTH - 1 downto 0) := "00000000000000000001111111111111111111000001111111111111111111";
  constant FLOW_MEM_ADDR_WIDTH      : integer                                            := FLAT_FLOW_ADDRESS_WIDTH; -- All addressable addresses in the memory
  constant FLOW_MEM_DEFAULT_ADDRESS : std_logic_vector(FLOW_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');         -- First address in the memory
  constant FLOW_MEM_LATENCY         : integer                                            := 3;                       -- Memory access latency in clock cycles

  --Rate memory data format
  --|cur_rate|
  --|   17   |
  --constant RATE_MEM_DATA_WIDTH      : integer                                            := 2 * RATE_BIT_RESOLUTION_WIDTH; -- Test values for scheduler
  --constant RATE_MEM_NULL_ENTRY      : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0) := "000000"; -- Test values for scheduler
  constant RATE_MEM_DATA_WIDTH      : integer                                            := CALENDAR_SLOTS_WIDTH;
  constant RATE_MEM_NULL_ENTRY      : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0) := "00000000000000000";
  constant RATE_MEM_ADDR_WIDTH      : integer                                            := FLAT_FLOW_ADDRESS_WIDTH; -- All addressable addresses in the memory
  constant RATE_MEM_DEFAULT_ADDRESS : std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');         -- First address in the memory
  constant RATE_MEM_LATENCY         : integer                                            := FLOW_MEM_LATENCY;        -- Has to be the same as FLOW_MEM_LATENCY for the scheduler to work properly

  -- Calendar memory data format
  --|head_addr|
  --|   19    |
  constant CALENDAR_MEM_DATA_WIDTH      : integer                                                := FLOW_ADDRESS_WIDTH;
  constant CALENDAR_MEM_NULL_ENTRY      : std_logic_vector(CALENDAR_MEM_DATA_WIDTH - 1 downto 0) := FLOW_NULL_ADDRESS;
  constant CALENDAR_MEM_ADDR_WIDTH      : integer                                                := CALENDAR_SLOTS_WIDTH;
  constant CALENDAR_MEM_DEFAULT_ADDRESS : std_logic_vector(CALENDAR_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0'); -- First address in the memory
  constant CALENDAR_MEM_LATENCY         : integer                                                := 2;

  -- Scheduler_pipeline constants
  constant SCHEDULER_PIPELINE_SIZE    : integer := FLOW_MEM_LATENCY + CALENDAR_MEM_LATENCY + 6; -- Number of pipeline stages for the scheduler
  constant SCHEDULER_PIPELINE_STAGE_0 : integer := 0;
  constant SCHEDULER_PIPELINE_STAGE_1 : integer := FLOW_MEM_LATENCY + 1;
  constant SCHEDULER_PIPELINE_STAGE_2 : integer := FLOW_MEM_LATENCY + 2;
  constant SCHEDULER_PIPELINE_STAGE_3 : integer := FLOW_MEM_LATENCY + CALENDAR_MEM_LATENCY + 5;

  -- Constant for the Scheduler overlow buffer
  -- The overflow buffer is used to store elements that cannot be processed immediately by the scheduler pipeline
  constant OVERFLOW_BUFFER_SIZE : integer := 2; -- Size of the overflow buffer for the scheduler

  constant PIPE_READY_PATTERNS_SIZE : integer := 6; -- Number of patterns for PIPE_READY
  -- Patterns indicating when the scheduler pipeline (PIPE_VALID) is ready to accept a new element from the FIFO
  type PIPE_READY_PATTERNS_T is array (0 to PIPE_READY_PATTERNS_SIZE - 1) of std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0);

  -- Each constant below represents a specific state of the scheduler pipeline where it is ready for a new FIFO element
  constant PIPE_READY_PATTERN_0 : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := "00000000000"; -- All stages are idle
  constant PIPE_READY_PATTERN_1 : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := "00001000000";
  constant PIPE_READY_PATTERN_2 : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := "00010000000";
  constant PIPE_READY_PATTERN_3 : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := "00100000000";
  constant PIPE_READY_PATTERN_4 : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := "01000000000";
  constant PIPE_READY_PATTERN_5 : std_logic_vector(SCHEDULER_PIPELINE_SIZE - 1 downto 0) := "10000000000";

  constant PIPE_READY_PATTERNS : PIPE_READY_PATTERNS_T := (
    PIPE_READY_PATTERN_0, PIPE_READY_PATTERN_1, PIPE_READY_PATTERN_2, PIPE_READY_PATTERN_3, PIPE_READY_PATTERN_4, PIPE_READY_PATTERN_5
  );

  -- RP_flow_update constants
  constant R_AI  : integer := 50;  -- Additive increase rate increment value
  constant R_HAI : integer := 100; -- Huper Additive increase rate increment value
  constant G     : integer := 1;   -- weight factor

  constant K                 : integer                            := 50; --Reduction factor update threshold, originally around 55us ONLY associated with change of alpha
  constant K_WIDTH           : integer                            := 7;
  constant ALPHA_WIDTH       : integer                            := 16;
  constant ALPHA_DEFAULT     : unsigned(ALPHA_WIDTH - 1 downto 0) := (others => '0');
  constant ALPHA_TIMER_WIDTH : integer                            := K_WIDTH;

  -- The cycle duration of 150 KBytes is chosen to correspond to the transmission of 100 frames, each 1500 Bytes long. [17] IEEE. 802.11Qau. Congestion notification, 2010.
  -- B constant is associated with BC
  constant B       : integer := 6; -- threshold for the ByteCounter incrementation: n times MTU; (default 100 x MTU)
  constant B_WIDTH : integer := 3; -- log2(B)

  -- The Timer functions similarly as the Byte Counter: it is reset when a feedback message arrives, enters FR
  -- and counts out 5 cycles of T ms duration (T is 10 ms long in the baseline). [17] IEEE. 802.11Qau. Congestion notification, 2010.
  constant T       : integer := 20; -- threshold for the Timer incrementation: 1953125clk * 5.12ns/clk ~= 10ms
  constant T_WIDTH : integer := 8;  -- log2(T)

  constant F                                 : integer                        := 5; -- Fast Recovery iterations
  constant F_WIDTH                           : integer                        := 3;
  constant TC_WIDTH, BC_WIDTH                : integer                        := 3;
  constant F_DEFAULT, TC_DEFAULT, BC_DEFAULT : unsigned(F_WIDTH - 1 downto 0) := (others => '0');

  constant GLOBAL_TIMER_WIDTH  : integer                              := 16;                 -- TODO: consider the least sufficient size for the global timer
  constant RP_RATE_WIDTH       : integer                              := 16;
  constant RP_RATE_DEFAULT     : unsigned(RP_RATE_WIDTH - 1 downto 0) := "0000000011111111"; -- Never set to 0!
  constant RP_RATE_MAX_DEFAULT : unsigned(RP_RATE_WIDTH - 1 downto 0) := (others => '1');    -- Maximum rate for the RP
  constant RP_DATA_SENT_WIDTH  : integer                              := 1;                  -- Number of bits for the data sent input, 1 bit = std_logic

  -- RP internal flow mem
  constant RP_MEM_DATA_WIDTH      : integer                                            := 3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH + BC_WIDTH + B_WIDTH;
  constant RP_MEM_NULL_ENTRY      : std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0)   := (others => '0');
  constant RP_MEM_ADDR_WIDTH      : integer                                            := FLAT_FLOW_ADDRESS_WIDTH; -- All addressable addresses in the memory
  constant RP_MEM_DEFAULT_ADDRESS : std_logic_vector(FLOW_MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');         -- First address in the memory
  constant RP_MEM_LATENCY         : integer                                            := 3;                       -- Memory access latency in clock cycles

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
