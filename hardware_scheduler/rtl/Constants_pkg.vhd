-- file: constants_pkg.vhd
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package constants_pkg is

  constant MTU_BITS             : integer := 12000; -- Number of bits for MTU
  constant QP_WIDTH                : integer := 24;                          -- Number of bits for QP
  constant SEQ_NR_WIDTH            : integer := 24;                          -- Number of bits for sequence number
  constant TOTAL_MAX_RATE : real := 1.0E11;     -- 100 Gbps
  constant CLK_PERIOD : time := 10 ns; -- Clock period for simulation

  constant NUM_GROUPS              : integer := 16;                          -- Number of groups
  constant NUM_FLOWS               : integer := 16;                          -- Number of flows per group
  constant NUM_FLOWS_TOTAL         : integer := NUM_GROUPS * NUM_FLOWS;      -- Total number of flows
  constant FLAT_FLOW_ADDRESS_WIDTH : integer := 8;                           -- log2(NUM_FLOWS_TOTAL); just based on the number of flows
  constant FLOW_ADDRESS_WIDTH      : integer := FLAT_FLOW_ADDRESS_WIDTH + 1; -- Including additional bit to include the null address

  constant CALENDAR_INTERVAL       : integer := 100;
  constant CALENDAR_INTERVAL_WIDTH : integer := 7; -- log2(CALENDAR_INTERVAL); -- Number of bits for interval counter

  constant FLOW_LOADER_INTERVAL       : integer := 100; -- Clock interval for FlowLoader 
  constant FLOW_LOADER_INTERVAL_WIDTH : integer := 7;   -- log2(FLOW_LOADER_INTERVAL); -- Number of bits for interval counter 

  constant RATE_BIT_RESOLUTION       : integer := 1024;
  constant RATE_BIT_RESOLUTION_WIDTH : integer := 10; -- log2(RATE_BIT_RESOLUTION); -- Number of bits for rate resolution

  constant CALENDAR_SLOTS       : integer := 128;
  constant CALENDAR_SLOTS_WIDTH : integer := 7;    -- log2(CALENDAR_SLOTS); -- Number of bits for slot index

  constant IPG_DIVIDEND   : real := 2.34375E10; -- division numerator


end package;

package body constants_pkg is
end package body;
