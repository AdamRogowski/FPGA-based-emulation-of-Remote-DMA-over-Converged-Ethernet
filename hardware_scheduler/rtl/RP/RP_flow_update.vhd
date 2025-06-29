library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use work.constants_pkg.all; -- Import constants

  -- ============================================================================
  --  Entity: RP_Flow_Update
  --  Description:
  --    Implements the DCQCN Rate-based Congestion Control update logic for a
  --    single flow. Handles CNP (Congestion Notification Packets) and data
  --    notifications, updating flow state in memory and applying DCQCN rules.
  --    The pipeline is designed for high-throughput, pipelined operation.
  -- ============================================================================

entity RP_Flow_Update is
  port (
    clk         : in std_logic;
    rst         : in std_logic;

    flow_rdy_i  : in std_logic;                                        -- Indicates a new flow update is ready
    is_cnp_i    : in std_logic;                                        -- 1 if CNP notification, 0 if data notification
    flow_id_i   : in std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0); -- Flow ID
    data_sent_i : in unsigned(RP_DATA_SENT_WIDTH - 1 downto 0)         -- Data sent (usually 1 MTU)
  );
end entity;

architecture rtl of RP_Flow_Update is

  -- ==========================================================================
  --  Component Declarations
  -- ==========================================================================

  -- RP memory: stores per-flow state (Rc, Rt, alpha, counters, etc.)
  component RP_mem
    generic (
      LATENCY : integer
    );
    port (
      clk          : in  std_logic;
      ena, enb     : in  std_logic;
      wea, web     : in  std_logic;
      addra, addrb : in  std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0);
      dia, dib     : in  std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0);
      doa, dob     : out std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0)
    );
  end component;

  -- Rate memory: stores current rate for each flow (for scheduler)
  component Rate_mem is
    generic (
      LATENCY : integer
    );
    port (
      clk          : in  std_logic;
      ena, enb     : in  std_logic;
      wea, web     : in  std_logic;
      addra, addrb : in  std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0);
      dia, dib     : in  std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0);
      doa, dob     : out std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0)
    );
  end component;

  -- Global timer: provides a global time reference for all flows
  component Global_timer is
    generic (
      GLOBAL_TIMER_WIDTH : integer
    );
    port (
      clk          : in  std_logic;
      reset        : in  std_logic;
      global_timer : out unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0)
    );
  end component;

  -- ==========================================================================
  --  Internal Signals
  -- ==========================================================================

  -- RP memory interface signals
  signal RP_mem_ena, RP_mem_enb     : std_logic                                        := '0';
  signal RP_mem_wea, RP_mem_web     : std_logic                                        := '0';
  signal RP_mem_addra, RP_mem_addrb : std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0) := RP_MEM_DEFAULT_ADDRESS;
  signal RP_mem_dia, RP_mem_dib     : std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0) := RP_MEM_NULL_ENTRY;
  signal RP_mem_doa, RP_mem_dob     : std_logic_vector(RP_MEM_DATA_WIDTH - 1 downto 0) := RP_MEM_NULL_ENTRY;

  -- Rate memory interface signals
  signal rate_mem_enb   : std_logic                                          := '0';
  signal rate_mem_web   : std_logic                                          := '0';
  signal rate_mem_addrb : std_logic_vector(RATE_MEM_ADDR_WIDTH - 1 downto 0) := RATE_MEM_DEFAULT_ADDRESS;
  signal rate_mem_dib   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal rate_mem_dob   : std_logic_vector(RATE_MEM_DATA_WIDTH - 1 downto 0) := (others => '0');

  -- Global timer signal
  signal RP_global_timer : unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0);

  -- ==========================================================================
  --  Pipeline Registers and Types
  -- ==========================================================================

  -- Per-stage update state (values read from RP_mem, plus working registers)
  type RP_update_stage is record
    R_max             : unsigned(RP_RATE_WIDTH - 1 downto 0);
    Rc                : unsigned(RP_RATE_WIDTH - 1 downto 0);
    Rt                : unsigned(RP_RATE_WIDTH - 1 downto 0);
    alpha             : unsigned(ALPHA_WIDTH - 1 downto 0);
    last_alpha_update : unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0);
    TC                : unsigned(TC_WIDTH - 1 downto 0);
    last_T_update     : unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0);
    BC                : unsigned(BC_WIDTH - 1 downto 0);
    ByteCnt           : unsigned(B_WIDTH - 1 downto 0);
    elapsed_alpha     : unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0);
    TC_update         : std_logic;
    elapsed_T         : unsigned(GLOBAL_TIMER_WIDTH - 1 downto 0);
    BC_update         : std_logic;
  end record;

  -- Per-stage input state (flow id, data sent, CNP flag)
  type RP_input_stage is record
    flow_id   : std_logic_vector(RP_MEM_ADDR_WIDTH - 1 downto 0);
    data_sent : unsigned(RP_DATA_SENT_WIDTH - 1 downto 0);
    is_cnp    : std_logic;
  end record;

  -- Pipeline arrays
  type RP_update_pipe_type is array (0 to RP_PIPELINE_SIZE - 1) of RP_update_stage;
  type RP_input_pipe_type is array (0 to RP_PIPELINE_SIZE - 1) of RP_input_stage;

  signal RP_upgrade_pipe : RP_update_pipe_type := (others => (
                                                     R_max             => RP_RATE_MAX_DEFAULT,
                                                     Rc                => RP_RATE_DEFAULT,
                                                     Rt                => RP_RATE_DEFAULT,
                                                     alpha             => ALPHA_DEFAULT,
                                                     last_alpha_update => (others => '0'),
                                                     TC                => TC_DEFAULT,
                                                     last_T_update     => (others => '0'),
                                                     BC                => BC_DEFAULT,
                                                     ByteCnt           => (others => '0'),
                                                     elapsed_alpha     => (others => '0'),
                                                     TC_update         => '0',
                                                     elapsed_T         => (others => '0'),
                                                     BC_update         => '0'
                                                   ));
  signal RP_input_pipe : RP_input_pipe_type := (others => (
                                                  flow_id   => (others => '0'),
                                                  data_sent => "0",
                                                  is_cnp    => '0'
                                                ));
  signal RP_pipe_valid : std_logic_vector(RP_PIPELINE_SIZE - 1 downto 0) := (others => '0');

begin

  -- ==========================================================================
  --  Memory and Timer Instantiations
  -- ==========================================================================

  -- RP memory (per-flow state)
  RP_mem_inst: RP_mem
    generic map (
      LATENCY => RP_MEM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => RP_mem_ena,
      enb   => RP_mem_enb,
      wea   => RP_mem_wea,
      web   => RP_mem_web,
      addra => RP_mem_addra,
      addrb => RP_mem_addrb,
      dia   => RP_mem_dia,
      dib   => RP_mem_dib,
      doa   => RP_mem_doa,
      dob   => RP_mem_dob
    );

  -- Rate memory (for scheduler)
  rate_mem_inst: Rate_mem
    generic map (
      LATENCY => RATE_MEM_LATENCY
    )
    port map (
      clk   => clk,
      ena   => '0',
      wea   => '0',
      addra => RATE_MEM_DEFAULT_ADDRESS,
      dia   => (others => '0'),
      doa   => open,
      enb   => rate_mem_enb,
      web   => rate_mem_web,
      addrb => rate_mem_addrb,
      dib   => rate_mem_dib,
      dob   => rate_mem_dob
    );

  -- Global timer
  global_timer_inst: Global_timer
    generic map (
      GLOBAL_TIMER_WIDTH => GLOBAL_TIMER_WIDTH
    )
    port map (
      clk          => clk,
      reset        => rst,
      global_timer => RP_global_timer
    );

  -- ==========================================================================
  --  Main Pipeline Logic

  -- ==========================================================================
  process (clk)
    -- Temporary variables for fixed-point math
    variable Rc_temp    : unsigned(FLOATING_POINT_WIDTH + RP_RATE_WIDTH - 1 downto 0);
    variable alpha_temp : unsigned(FLOATING_POINT_WIDTH + ALPHA_WIDTH - 1 downto 0);
  begin
    if rising_edge(clk) then

      -- ----------------------------------------------------------------------
      -- Pipeline Shift: advance all pipeline stages
      -- ----------------------------------------------------------------------
      for i in RP_PIPELINE_SIZE - 1 downto 1 loop
        RP_upgrade_pipe(i) <= RP_upgrade_pipe(i - 1);
        RP_input_pipe(i) <= RP_input_pipe(i - 1);
        RP_pipe_valid(i) <= RP_pipe_valid(i - 1);
      end loop;

      -- ----------------------------------------------------------------------
      -- Stage -1: Accept new input if ready
      -- ----------------------------------------------------------------------
      if flow_rdy_i = '1' then
        RP_input_pipe(RP_PIPELINE_STAGE_0).flow_id <= flow_id_i;
        RP_input_pipe(RP_PIPELINE_STAGE_0).data_sent <= data_sent_i;
        RP_input_pipe(RP_PIPELINE_STAGE_0).is_cnp <= is_cnp_i;
        RP_pipe_valid(RP_PIPELINE_STAGE_0) <= '1';
      else
        RP_pipe_valid(RP_PIPELINE_STAGE_0) <= '0';
      end if;

      -- ----------------------------------------------------------------------
      -- Stage 0: Initiate memory read for this flow
      -- ----------------------------------------------------------------------
      if RP_pipe_valid(RP_PIPELINE_STAGE_0) = '1' then
        RP_mem_ena <= '1';
        RP_mem_wea <= '0';
        RP_mem_addra <= RP_input_pipe(RP_PIPELINE_STAGE_0).flow_id;
      else
        RP_mem_ena <= '0';
      end if;

      -- ----------------------------------------------------------------------
      -- Stage 1: Latch memory output into pipeline
      -- ----------------------------------------------------------------------
      if RP_pipe_valid(RP_PIPELINE_STAGE_1) = '1' then
        -- Unpack RP_mem_doa into pipeline registers
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).R_max <= unsigned(RP_mem_doa(RP_RATE_WIDTH - 1 downto 0));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).Rc <= unsigned(RP_mem_doa(2 * RP_RATE_WIDTH - 1 downto RP_RATE_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).Rt <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH - 1 downto 2 * RP_RATE_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).alpha <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH + ALPHA_WIDTH - 1 downto 3 * RP_RATE_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).last_alpha_update <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH - 1 downto 3 * RP_RATE_WIDTH + ALPHA_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).TC <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH - 1 downto 3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).last_T_update <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH - 1 downto 3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).BC <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH + BC_WIDTH - 1 downto 3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH));
        RP_upgrade_pipe(RP_PIPELINE_STAGE_2).ByteCnt <= unsigned(RP_mem_doa(3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH + BC_WIDTH + B_WIDTH - 1 downto 3 * RP_RATE_WIDTH + ALPHA_WIDTH + GLOBAL_TIMER_WIDTH + TC_WIDTH + GLOBAL_TIMER_WIDTH + BC_WIDTH));
      end if;

      -- ----------------------------------------------------------------------
      -- Stage 2: Handle CNP or data notification
      -- ----------------------------------------------------------------------
      if RP_pipe_valid(RP_PIPELINE_STAGE_2) = '1' then
        if RP_input_pipe(RP_PIPELINE_STAGE_2).is_cnp = '1' then
          -- CNP: update alpha and timers, set Rt = Rc
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).Rt <= RP_upgrade_pipe(RP_PIPELINE_STAGE_2).Rc;
          alpha_temp := RP_upgrade_pipe(RP_PIPELINE_STAGE_2).alpha * (ONE - G); -- alpha = alpha * (1 - G) + G
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).alpha <= alpha_temp(FLOATING_POINT_WIDTH + ALPHA_WIDTH - 1 downto FLOATING_POINT_WIDTH) + G;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).last_alpha_update <= RP_global_timer;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).elapsed_alpha <= (others => '0');
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).TC <= TC_DEFAULT;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).last_T_update <= RP_global_timer;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).elapsed_T <= (others => '0');
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).BC <= BC_DEFAULT;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).ByteCnt <= (others => '0');
        else
          -- Data: update timers and counters
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).elapsed_alpha <= RP_global_timer - RP_upgrade_pipe(RP_PIPELINE_STAGE_2).last_alpha_update;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).elapsed_T <= RP_global_timer - RP_upgrade_pipe(RP_PIPELINE_STAGE_2).last_T_update;
          RP_upgrade_pipe(RP_PIPELINE_STAGE_3).ByteCnt <= RP_upgrade_pipe(RP_PIPELINE_STAGE_2).ByteCnt + RP_input_pipe(RP_PIPELINE_STAGE_2).data_sent;
        end if;
      end if;

      -- ----------------------------------------------------------------------
      -- Stage 3: Apply DCQCN update rules
      -- ----------------------------------------------------------------------
      if RP_pipe_valid(RP_PIPELINE_STAGE_3) = '1' then
        if RP_input_pipe(RP_PIPELINE_STAGE_3).is_cnp = '1' then
          -- CNP: update Rc using new alpha
          Rc_temp := RP_upgrade_pipe(RP_PIPELINE_STAGE_3).Rc * (ONE - shift_right(RP_upgrade_pipe(RP_PIPELINE_STAGE_3).alpha, 1)); -- Rc = Rc * (1 - new_alpha/2)
          RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rc <= Rc_temp(FLOATING_POINT_WIDTH + RP_RATE_WIDTH - 1 downto FLOATING_POINT_WIDTH);
        else
          -- Data: update alpha, timers, counters if thresholds reached
          if RP_upgrade_pipe(RP_PIPELINE_STAGE_3).elapsed_alpha >= K then
            alpha_temp := RP_upgrade_pipe(RP_PIPELINE_STAGE_3).alpha * (ONE - G);
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).alpha <= alpha_temp(FLOATING_POINT_WIDTH + ALPHA_WIDTH - 1 downto FLOATING_POINT_WIDTH);
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).last_alpha_update <= RP_global_timer;
          end if;

          if RP_upgrade_pipe(RP_PIPELINE_STAGE_3).elapsed_T >= T then
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).last_T_update <= RP_global_timer;
            if RP_upgrade_pipe(RP_PIPELINE_STAGE_3).TC < F then
              RP_upgrade_pipe(RP_PIPELINE_STAGE_4).TC <= RP_upgrade_pipe(RP_PIPELINE_STAGE_3).TC + 1;
            end if;
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).TC_update <= '1';
          else
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).TC_update <= '0';
          end if;

          if RP_upgrade_pipe(RP_PIPELINE_STAGE_3).ByteCnt >= B then
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).ByteCnt <= (others => '0');
            if RP_upgrade_pipe(RP_PIPELINE_STAGE_3).BC < F then
              RP_upgrade_pipe(RP_PIPELINE_STAGE_4).BC <= RP_upgrade_pipe(RP_PIPELINE_STAGE_3).BC + 1;
            end if;
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).BC_update <= '1';
          else
            RP_upgrade_pipe(RP_PIPELINE_STAGE_4).BC_update <= '0';
          end if;
        end if;
      end if;

      -- ----------------------------------------------------------------------
      -- Stage 4: Rate Increase Event (FR, AI, HAI)
      -- ----------------------------------------------------------------------
      if RP_pipe_valid(RP_PIPELINE_STAGE_4) = '1' then
        if RP_upgrade_pipe(RP_PIPELINE_STAGE_4).TC_update = '1' or RP_upgrade_pipe(RP_PIPELINE_STAGE_4).BC_update = '1' then
          -- Always update Rc to average of Rc and Rt
          RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rc <= shift_right((RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rc + RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rt), 1);

          -- Fast Recovery
          if RP_upgrade_pipe(RP_PIPELINE_STAGE_4).TC < F and RP_upgrade_pipe(RP_PIPELINE_STAGE_4).BC < F then
            -- No Rt update in FR
            -- Hyper Additive Increase
          elsif RP_upgrade_pipe(RP_PIPELINE_STAGE_4).TC >= F and RP_upgrade_pipe(RP_PIPELINE_STAGE_4).BC >= F then
            if RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rt + R_HAI > RP_upgrade_pipe(RP_PIPELINE_STAGE_4).R_max then
              RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rt <= RP_upgrade_pipe(RP_PIPELINE_STAGE_4).R_max;
            else
              RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rt <= RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rt + R_HAI;
            end if;
            -- Additive Increase
          else
            if RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rt + R_AI > RP_upgrade_pipe(RP_PIPELINE_STAGE_4).R_max then
              RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rt <= RP_upgrade_pipe(RP_PIPELINE_STAGE_4).R_max;
            else
              RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rt <= RP_upgrade_pipe(RP_PIPELINE_STAGE_4).Rt + R_AI;
            end if;
          end if;
        end if;
      end if;

      -- ----------------------------------------------------------------------
      -- Stage 5: Write-back updated state to memories
      -- ----------------------------------------------------------------------
      if RP_pipe_valid(RP_PIPELINE_STAGE_5) = '1' then
        RP_mem_enb <= '1';
        RP_mem_web <= '1';
        RP_mem_addrb <= RP_input_pipe(RP_PIPELINE_STAGE_5).flow_id;
        RP_mem_dib <= std_logic_vector(
          RP_upgrade_pipe(RP_PIPELINE_STAGE_5).ByteCnt & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).BC & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).last_T_update & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).TC & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).last_alpha_update & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).alpha & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rt & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rc & RP_upgrade_pipe(RP_PIPELINE_STAGE_5).R_max
        );
        -- Write Rc to rate memory (for scheduler); slicing for test only
        rate_mem_enb <= '1';
        rate_mem_web <= '1';
        rate_mem_addrb <= RP_input_pipe(RP_PIPELINE_STAGE_5).flow_id;
        rate_mem_dib <= std_logic_vector(RP_upgrade_pipe(RP_PIPELINE_STAGE_5).Rc(2 downto 0)); -- TODO: Remove slicing for production
      else
        RP_mem_enb <= '0';
        RP_mem_web <= '0';
        rate_mem_enb <= '0';
        rate_mem_web <= '0';
      end if;

      -- ----------------------------------------------------------------------
      -- Reset logic: clear all state
      -- ----------------------------------------------------------------------
      if rst = '1' then
        RP_mem_ena <= '0';
        RP_mem_enb <= '0';
        RP_mem_wea <= '0';
        RP_mem_web <= '0';
        RP_mem_addra <= RP_MEM_DEFAULT_ADDRESS;
        RP_mem_addrb <= RP_MEM_DEFAULT_ADDRESS;
        RP_mem_dia <= (others => '0');
        RP_mem_dib <= (others => '0');
        rate_mem_enb <= '0';
        rate_mem_web <= '0';
        rate_mem_addrb <= RATE_MEM_DEFAULT_ADDRESS;
        rate_mem_dib <= (others => '0');
        RP_upgrade_pipe <= (others => (
                              R_max             => RP_RATE_MAX_DEFAULT,
                              Rc                => RP_RATE_DEFAULT,
                              Rt                => RP_RATE_DEFAULT,
                              alpha             => ALPHA_DEFAULT,
                              last_alpha_update => (others => '0'),
                              TC                => TC_DEFAULT,
                              last_T_update     => (others => '0'),
                              BC                => BC_DEFAULT,
                              ByteCnt           => (others => '0'),
                              elapsed_alpha     => (others => '0'),
                              TC_update         => '0',
                              elapsed_T         => (others => '0'),
                              BC_update         => '0'
                            ));
        RP_input_pipe <= (others => (
                            flow_id   => (others => '0'),
                            data_sent => "0",
                            is_cnp    => '0'
                          ));
        RP_pipe_valid <= (others => '0');
      end if;
    end if;
  end process;

end architecture;
