library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity fifo is
  generic (
    DATA_WIDTH : integer := 8; -- Width of each FIFO element
    ADDR_WIDTH : integer := 2  -- Address width (DEPTH = 2**ADDR_WIDTH)
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
end entity;

architecture rtl of fifo is

  constant DEPTH : integer := 2 ** ADDR_WIDTH;

  type fifo_array_t is array (0 to DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal fifo_mem : fifo_array_t := (others => (others => '0'));

  signal wr_ptr     : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal rd_ptr     : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal fifo_count : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- Can count up to DEPTH

  signal popped_element_reg : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr <= (others => '0');
        rd_ptr <= (others => '0');
        fifo_count <= (others => '0');
        popped_element_reg <= (others => '0');
      else
        -- Simultaneous append and pop
        if append_enable = '1' and pop_enable = '1' then
          if fifo_count = 0 then
            -- FIFO empty: pass-through, do not store, do not increment count
            popped_element_reg <= new_element;
            -- pointers and count unchanged
          elsif fifo_count = DEPTH then
            -- FIFO full: overwrite oldest, pointers move, count unchanged
            fifo_mem(to_integer(wr_ptr)) <= new_element;
            wr_ptr <= (wr_ptr + 1) and to_unsigned(DEPTH - 1, ADDR_WIDTH);
            popped_element_reg <= fifo_mem(to_integer(rd_ptr));
            rd_ptr <= (rd_ptr + 1) and to_unsigned(DEPTH - 1, ADDR_WIDTH);
            -- count unchanged
          else
            -- Normal case: push and pop, pointers move, count unchanged
            fifo_mem(to_integer(wr_ptr)) <= new_element;
            wr_ptr <= (wr_ptr + 1) and to_unsigned(DEPTH - 1, ADDR_WIDTH);
            popped_element_reg <= fifo_mem(to_integer(rd_ptr));
            rd_ptr <= (rd_ptr + 1) and to_unsigned(DEPTH - 1, ADDR_WIDTH);
            -- count unchanged
          end if;
        elsif append_enable = '1' and fifo_count < DEPTH then
          -- Only append
          fifo_mem(to_integer(wr_ptr)) <= new_element;
          wr_ptr <= (wr_ptr + 1) and to_unsigned(DEPTH - 1, ADDR_WIDTH);
          fifo_count <= fifo_count + 1;
        elsif pop_enable = '1' and fifo_count > 0 then
          -- Only pop
          popped_element_reg <= fifo_mem(to_integer(rd_ptr));
          rd_ptr <= (rd_ptr + 1) and to_unsigned(DEPTH - 1, ADDR_WIDTH);
          fifo_count <= fifo_count - 1;
        end if;
      end if;
    end if;
  end process;

  popped_element <= popped_element_reg;
  empty          <= '1' when fifo_count = 0 else '0';
  full           <= '1' when fifo_count = DEPTH else '0';

end architecture;
