RC_TIMESTAPMS_PATH = "software_models/scheduler_single_flow/Rc_timestamps.txt"
INPUT_PACKETS_PATH = (
    "software_models/packet_inputs/packets.csv"  # can be changed to random_packets.csv
)

TX_DELAY = 100  # Transmission delay (ns)

END_OF_TIME = 500000  # Simulation time in ns
LINK_SPEED_BPNS = 40  # 100 bpns = Gbps link speed
AVG_RATE_WINDOW = 3  # how many past packets included in calculating avg
