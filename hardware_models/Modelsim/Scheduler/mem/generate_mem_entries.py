N = 2**9

with open("init_calendar_mem_16.txt", "w") as f:
    f.write("constant init_calendar_mem_16 : calendar_mem_type := (\n")
    f.write('    0 => "00000",\n')
    for i in range(1, N):
        end = "," if i < N - 1 else ""
        f.write(f'    {i} => "11111"{end}\n')
    f.write(");\n")
