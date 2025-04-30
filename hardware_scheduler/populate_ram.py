from math import ceil, log2

# === Configuration parameters ===
FLOW_ADDRESS_WIDTH = 9
SEQ_NR_WIDTH = 24
RATE_BIT_RESOLUTION_WIDTH = 17
QP_WIDTH = 24  # includes padding
BRAM_DEPTH = 512  # total memory size
ACTIVE_FLAG_WIDTH = 1

ENTRY_WIDTH = (
    ACTIVE_FLAG_WIDTH
    + SEQ_NR_WIDTH
    + 2 * RATE_BIT_RESOLUTION_WIDTH
    + 2 * FLOW_ADDRESS_WIDTH  # next_addr + cur_addr
    + (QP_WIDTH - FLOW_ADDRESS_WIDTH)  # padding
)


# === Utility functions ===
def to_slv(value: int, width: int) -> str:
    return f"{value:0{width}b}"


# === Generate entries ===
entries = []
base_addr = 1

for i in range(4):  # Four linked entries
    cur_addr = base_addr + i
    next_addr = base_addr + i + 1 if i < 3 else 0  # Last one points to NULL

    cur_addr_bits = to_slv(cur_addr, FLOW_ADDRESS_WIDTH)
    next_addr_bits = to_slv(next_addr, FLOW_ADDRESS_WIDTH)
    qp_padding_bits = "0" * (QP_WIDTH - FLOW_ADDRESS_WIDTH)
    max_rate_bits = to_slv(200, RATE_BIT_RESOLUTION_WIDTH)
    cur_rate_bits = to_slv(100, RATE_BIT_RESOLUTION_WIDTH)
    seq_nr_bits = to_slv(i * 10, SEQ_NR_WIDTH)
    active_flag_bit = "1"

    data = (
        active_flag_bit
        + seq_nr_bits
        + cur_rate_bits
        + max_rate_bits
        + next_addr_bits
        + qp_padding_bits
        + cur_addr_bits
    )
    entries.append(f'"{data}"')

# === Fill remaining BRAM with zero entries ===
default_entry = (
    "0"  # active_flag
    + "0" * SEQ_NR_WIDTH
    + "0" * RATE_BIT_RESOLUTION_WIDTH
    + "0" * RATE_BIT_RESOLUTION_WIDTH
    + "1" * FLOW_ADDRESS_WIDTH
    + "0" * (QP_WIDTH - FLOW_ADDRESS_WIDTH)
    + "1" * FLOW_ADDRESS_WIDTH
)

while len(entries) < BRAM_DEPTH:
    entries.append(f'"{default_entry}"')

# === Output VHDL array ===
print("constant INIT_BRAM : ram_type := (")
for i, entry in enumerate(entries):
    sep = "," if i < BRAM_DEPTH - 1 else ""
    print(f"  {i} => {entry}{sep}")
print(");")
