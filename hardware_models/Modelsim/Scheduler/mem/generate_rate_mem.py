import random


def to_bin(value, width=9):
    return format(value, f"0{width}b")


def generate_vhdl_rate_mem(depth=1024, min_val=11, max_val=511):
    bit_width = 9
    vhdl = []
    vhdl.append(
        f"type rate_mem_type is array (0 to {depth - 1}) of std_logic_vector({bit_width - 1} downto 0);"
    )
    vhdl.append("")
    vhdl.append(f"constant init_rate_mem_{depth} : rate_mem_type := (")

    for i in range(depth):
        val = random.randint(min_val, max_val)
        bin_val = to_bin(val, bit_width)
        line = f'    {i:<4} => "{bin_val}",'
        vhdl.append(line)

    vhdl[-1] = vhdl[-1].rstrip(",")  # Remove comma from last line
    vhdl.append("  );")
    return "\n".join(vhdl)


# Write to file or print
if __name__ == "__main__":
    vhdl_code = generate_vhdl_rate_mem()
    with open("generated_rate_mem.vhdl", "w") as f:
        f.write(vhdl_code)
    print("VHDL rate memory constant written to 'generated_rate_mem.vhdl'")
