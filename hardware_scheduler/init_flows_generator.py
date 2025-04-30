import random

# Parameters
NUM_FLOWS_TOTAL = 256
RATE_BIT_RESOLUTION_WIDTH = 17
OUTPUT_FILENAME = "flow_array_content.txt"

# Generate maximum value for cur_rate (all 1s)
max_rate_bin = "00000000000001010"

entries = []
for i in range(NUM_FLOWS_TOTAL):
    # Flow address: binary of i, padded to required width with a leading 0
    flow_addr_width = len(bin(NUM_FLOWS_TOTAL - 1)[2:]) + 1  # +1 for leading blank bit
    flow_addr_bin = format(i, "0{}b".format(flow_addr_width))

    # Random current rate
    cur_rate_bin = format(
        random.randint(0, (1 << RATE_BIT_RESOLUTION_WIDTH) - 1),
        "0{}b".format(RATE_BIT_RESOLUTION_WIDTH),
    )

    # Add VHDL-style line
    entries.append(
        f'    {i} => ("{flow_addr_bin}", "{max_rate_bin}", "{cur_rate_bin}")'
    )

# Join entries with commas and newlines
vhdl_array_content = ",\n".join(entries)

# Write to text file
with open(OUTPUT_FILENAME, "w") as f:
    f.write(vhdl_array_content)

print(f"FlowArray content written to '{OUTPUT_FILENAME}'")
