def to_bin(value, width):
    return format(value, f"0{width}b")


def generate_vhdl_flow_mem(depth=1024):
    total_width = 47
    seq_width = 24
    addr_width = 11
    qp_width = 11

    vhdl = []
    vhdl.append(
        f"type flow_mem_type is array (0 to {depth - 1}) of std_logic_vector({total_width - 1} downto 0);"
    )
    vhdl.append("")
    vhdl.append("  -- Flow memory data format")
    vhdl.append("  --|active_flag|seq_nr|next_addr|QP|")
    vhdl.append(f"  --|    1      |  {seq_width:<4}|  {addr_width:<4} |{qp_width}|")
    vhdl.append(f"  constant init_flow_mem_1024 : flow_mem_type := (")

    for i in range(depth):
        active_flag = "1"
        seq_nr_bin = to_bin(0, seq_width)  # or just `i` if you want
        next_addr_bin = to_bin((i + 1) if i + 1 < depth else 0, addr_width)
        qp_bin = to_bin(i, qp_width)

        full_bin = active_flag + seq_nr_bin + next_addr_bin + qp_bin
        comment = f"-- {i + 1 if i + 1 < depth else 'null'}, {i}"
        line = f'    {i:<4} => "{full_bin}", {comment}'
        vhdl.append(line)

    vhdl[-1] = vhdl[-1].rstrip(",")  # remove trailing comma from the last entry
    vhdl.append("  );")
    return "\n".join(vhdl)


# Output to file or print
if __name__ == "__main__":
    vhdl_code = generate_vhdl_flow_mem()
    with open("generated_flow_mem.vhdl", "w") as f:
        f.write(vhdl_code)
    print("VHDL constant generated in 'generated_flow_mem.vhdl'")
