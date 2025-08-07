import random

# Define the parameters for the VHDL constant generation
CONSTANT_NAME = "init_RP_mem_1024"
TYPE_NAME = "RP_mem_type"
NUM_ENTRIES = 1024  # 2**10
OUTPUT_FILENAME = "rp_mem_init.txt"

# Define the fixed parts of the binary string
PART1_ZEROS = "0" * 41 + "1" * 16
PART4_FIXED = "111111111111111111"
FIXED_PART = "000000000000000000000000000000000000000001111111111111111011111111110000111010001001110000111111111111111111111"

# Use a list to build the lines of the VHDL code
vhdl_code_lines = []
vhdl_code_lines.append(f"constant {CONSTANT_NAME} : {TYPE_NAME} := (")

# Generate each line of the array initialization
for i in range(NUM_ENTRIES):
    # Generate an 18-bit random value greater than 1
    random_int = random.randint(2, 2**18 - 1)
    part2_random = format(random_int, "018b")

    # Construct the full value according to the specified format:
    # "00...00[18 bits random][18 bits random (same)]011...11"
    value = PART1_ZEROS + part2_random + part2_random + PART4_FIXED
    # value = FIXED_PART

    # Format the VHDL line with index and the generated value
    line = f'    {i} => "{value}"'

    # Add a comma to all lines except the last one
    if i < NUM_ENTRIES - 1:
        line += ","

    vhdl_code_lines.append(line)

# Add the closing parenthesis and semicolon
vhdl_code_lines.append(");")

# Join all lines into a single string
final_vhdl_code = "\n".join(vhdl_code_lines)

# Write the generated VHDL code to the output file
try:
    with open(OUTPUT_FILENAME, "w") as f:
        f.write(final_vhdl_code)
    print(f"Successfully generated VHDL code in '{OUTPUT_FILENAME}'")
except IOError as e:
    print(f"Error writing to file: {e}")
