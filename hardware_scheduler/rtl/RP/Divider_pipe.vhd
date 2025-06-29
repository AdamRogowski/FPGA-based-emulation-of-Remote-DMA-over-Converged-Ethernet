library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.recip_lut_pkg.all; -- Import LUT package
  use work.constants_pkg.all; -- Import constants

entity divider_pipe is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    x_in       : in  std_logic_vector(15 downto 0);
    result_out : out std_logic_vector(16 downto 0) -- Integer output, 17 bits
  );
end entity;

architecture rtl of divider_pipe is

  -- The constant to be divided by x_in. From constants_pkg, IPG_DIVIDEND.
  -- Value = 23437500000
  constant C : unsigned(35 downto 0) := x"574FBDE60";

  constant PIPELINE_DEPTH : integer := 14;

  -- A single record to hold all data for a given stage in the pipeline
  type divider_stage is record
    valid      : std_logic;
    -- Normalization pipeline values
    x_p1       : unsigned(15 downto 0);
    shift_p1   : unsigned(3 downto 0);
    x_p2       : unsigned(15 downto 0);
    shift_p2   : unsigned(3 downto 0);
    x_p3       : unsigned(15 downto 0);
    shift_p3   : unsigned(3 downto 0);
    norm_x     : unsigned(15 downto 0);
    shift_amt  : unsigned(3 downto 0);
    -- Reciprocal and Newton-Raphson pipeline values
    r0         : unsigned(31 downto 0); -- U2.30 from LUT
    p_mult_1   : unsigned(47 downto 0); -- norm_x * r0 (U1.15 * U2.30 -> U3.45)
    error_1    : signed(32 downto 0);   -- 2.0 - p_scaled_1 (S2.30)
    r1         : unsigned(31 downto 0); -- U2.30
    p_mult_2   : unsigned(47 downto 0); -- norm_x * r1
    error_2    : signed(32 downto 0);   -- 2.0 - p_scaled_2
    r2         : unsigned(31 downto 0); -- U2.30
    -- Final result calculation values
    res_scaled : unsigned(67 downto 0); -- C(U36.0) * r2(U2.30) -> U38.30 (68 bits)
    result     : unsigned(36 downto 0); -- Final integer result
  end record;

  -- Default values for initializing the pipeline stages
  constant EMPTY_STAGE : divider_stage := (
    valid      => '0',
    x_p1       => (others => '0'),
    shift_p1   => (others => '0'),
    x_p2       => (others => '0'),
    shift_p2   => (others => '0'),
    x_p3       => (others => '0'),
    shift_p3   => (others => '0'),
    norm_x     => (others => '0'),
    shift_amt  => (others => '0'),
    r0         => (others => '0'),
    p_mult_1   => (others => '0'),
    error_1    => (others => '0'),
    r1         => (others => '0'),
    p_mult_2   => (others => '0'),
    error_2    => (others => '0'),
    r2         => (others => '0'),
    res_scaled => (others => '0'),
    result     => (others => '0')
  );

  type pipeline_array is array (0 to PIPELINE_DEPTH - 1) of divider_stage;
  signal pipe : pipeline_array := (others => EMPTY_STAGE);

begin

  divider_process: process (clk)
    -- Variables for combinational calculations within a stage
    variable p_scaled     : unsigned(31 downto 0); -- U2.30
    variable error        : signed(32 downto 0);   -- S2.30
    variable r_mult       : signed(65 downto 0);   -- S3.60
    variable r_next       : unsigned(31 downto 0); -- U2.30
    variable lut_index    : integer;
    variable denorm_shift : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pipe <= (others => EMPTY_STAGE);
      else
        -- This process describes a pipeline where the output of stage N-1
        -- becomes the input for the calculation of stage N in the next clock cycle.

        -- Stage 0: Latch input
        pipe(0).valid <= '1';
        if unsigned(x_in) = 0 then
          pipe(0).x_p1 <= (others => '0');
        else
          pipe(0).x_p1 <= unsigned(x_in);
        end if;
        pipe(0).shift_p1 <= (others => '0');

        -- Stage 1: Normalization - Step 1 (Shift by 8 if needed)
        pipe(1).valid <= pipe(0).valid;
        if pipe(0).x_p1(15 downto 8) = x"00" then
          pipe(1).x_p2 <= pipe(0).x_p1 sll 8;
          pipe(1).shift_p2 <= to_unsigned(8, 4);
        else
          pipe(1).x_p2 <= pipe(0).x_p1;
          pipe(1).shift_p2 <= to_unsigned(0, 4);
        end if;

        -- Stage 2: Normalization - Step 2 (Shift by 4 if needed)
        pipe(2).valid <= pipe(1).valid;
        pipe(2).shift_p2 <= pipe(1).shift_p2; -- Propagate shift amount
        if pipe(1).x_p2(15 downto 12) = x"0" then
          pipe(2).x_p3 <= pipe(1).x_p2 sll 4;
          pipe(2).shift_p3 <= pipe(1).shift_p2 + 4;
        else
          pipe(2).x_p3 <= pipe(1).x_p2;
          pipe(2).shift_p3 <= pipe(1).shift_p2;
        end if;

        -- Stage 3: Normalization - Step 3 (Shift by 2 if needed)
        pipe(3).valid <= pipe(2).valid;
        pipe(3).shift_p3 <= pipe(2).shift_p3; -- Propagate shift amount
        if pipe(2).x_p3(15 downto 14) = "00" then
          pipe(3).norm_x <= pipe(2).x_p3 sll 2;
          pipe(3).shift_amt <= pipe(2).shift_p3 + 2;
        else
          pipe(3).norm_x <= pipe(2).x_p3;
          pipe(3).shift_amt <= pipe(2).shift_p3;
        end if;

        -- Stage 4: Normalization - Step 4 (Shift by 1 if needed)
        pipe(4).valid <= pipe(3).valid;
        if pipe(3).norm_x(15) = '0' then
          pipe(4).norm_x <= pipe(3).norm_x sll 1;
          pipe(4).shift_amt <= pipe(3).shift_amt + 1;
        else
          pipe(4).norm_x <= pipe(3).norm_x;
          pipe(4).shift_amt <= pipe(3).shift_amt;
        end if;

        -- Stage 5: Reciprocal LUT lookup
        pipe(5).valid <= pipe(4).valid;
        pipe(5).norm_x <= pipe(4).norm_x;
        pipe(5).shift_amt <= pipe(4).shift_amt;
        lut_index := to_integer(pipe(4).norm_x(14 downto 15 - LUT_WIDTH));
        pipe(5).r0 <= recip_lut(lut_index);

        -- Stage 6: Newton-Raphson Iteration 1 - Multiplication
        pipe(6).valid <= pipe(5).valid;
        pipe(6).norm_x <= pipe(5).norm_x;
        pipe(6).shift_amt <= pipe(5).shift_amt;
        pipe(6).r0 <= pipe(5).r0;
        -- norm_x (U1.15) * r0 (U2.30) = U3.45, extract U2.30 from bits [44:15]
        pipe(6).p_mult_1 <= resize(pipe(5).norm_x * pipe(5).r0, 48);

        -- Stage 7: Newton-Raphson Iteration 1 - Error Calculation
        pipe(7).valid <= pipe(6).valid;
        pipe(7).norm_x <= pipe(6).norm_x;
        pipe(7).shift_amt <= pipe(6).shift_amt;
        pipe(7).r0 <= pipe(6).r0;
        -- Extract U2.30 from U3.45 multiplication result
        p_scaled := resize(pipe(6).p_mult_1(44 downto 15), 32); -- U3.45 -> U2.30
        -- Calculate 2.0 - p_scaled in U2.30 format
        error := signed(to_unsigned(2, 3) & to_unsigned(0, 30)) - signed(resize(p_scaled, 33)); -- 2.0 - p_scaled
        pipe(7).error_1 <= error;

        -- Stage 8: Newton-Raphson Iteration 1 - Finalize r1
        pipe(8).valid <= pipe(7).valid;
        pipe(8).norm_x <= pipe(7).norm_x;
        pipe(8).shift_amt <= pipe(7).shift_amt;
        -- r0 (U2.30) * error (S2.30) = S4.60, extract S2.30 from bits [59:30]
        r_mult := resize(signed(pipe(7).r0) * pipe(7).error_1, 66);
        r_next := pipe(7).r0 + unsigned(r_mult(59 downto 30)); -- r0 + r0*error (U2.30)
        pipe(8).r1 <= r_next;

        -- Stage 9: Newton-Raphson Iteration 2 - Multiplication
        pipe(9).valid <= pipe(8).valid;
        pipe(9).norm_x <= pipe(8).norm_x;
        pipe(9).shift_amt <= pipe(8).shift_amt;
        pipe(9).r1 <= pipe(8).r1;
        -- norm_x (U1.15) * r1 (U2.30) = U3.45
        pipe(9).p_mult_2 <= resize(pipe(8).norm_x * pipe(8).r1, 48);

        -- Stage 10: Newton-Raphson Iteration 2 - Error Calculation
        pipe(10).valid <= pipe(9).valid;
        pipe(10).shift_amt <= pipe(9).shift_amt;
        pipe(10).r1 <= pipe(9).r1;
        -- Extract U2.30 from U3.45 multiplication result
        p_scaled := resize(pipe(9).p_mult_2(44 downto 15), 32); -- U3.45 -> U2.30
        -- Calculate 2.0 - p_scaled in U2.30 format
        error := signed(to_unsigned(2, 3) & to_unsigned(0, 30)) - signed(resize(p_scaled, 33)); -- 2.0 - p_scaled
        pipe(10).error_2 <= error;

        -- Stage 11: Newton-Raphson Iteration 2 - Finalize r2
        pipe(11).valid <= pipe(10).valid;
        pipe(11).shift_amt <= pipe(10).shift_amt;
        -- r1 (U2.30) * error (S2.30) = S4.60, extract S2.30 from bits [59:30]
        r_mult := resize(signed(pipe(10).r1) * pipe(10).error_2, 66);
        r_next := pipe(10).r1 + unsigned(r_mult(59 downto 30)); -- r1 + r1*error (U2.30)
        pipe(11).r2 <= r_next;

        -- Stage 12: Final Calculation - Scale by C
        pipe(12).valid <= pipe(11).valid;
        pipe(12).shift_amt <= pipe(11).shift_amt;
        -- C (U36.0) * r2 (U2.30) = U38.30 (68 bits)
        pipe(12).res_scaled <= C * pipe(11).r2;

        -- Stage 13: Final Calculation - Denormalization
        pipe(13).valid <= pipe(12).valid;
        -- To get integer result: shift right by (30 - shift_amt) to remove fractional bits and denormalize
        denorm_shift := 30 - to_integer(pipe(12).shift_amt);
        if denorm_shift >= 0 then
          pipe(13).result <= resize(pipe(12).res_scaled srl denorm_shift, 37);
        else
          pipe(13).result <= resize(pipe(12).res_scaled sll (- denorm_shift), 37);
        end if;

      end if;
    end if;
  end process;

  -- Output the final result from the last pipeline stage, if valid
  result_out <= std_logic_vector(resize(pipe(PIPELINE_DEPTH - 1).result, 17)) when pipe(PIPELINE_DEPTH - 1).valid = '1' else (others => '0');

end architecture;
