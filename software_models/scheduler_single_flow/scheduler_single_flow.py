"""
Module tries to model specific target rate enforcement inside the RP, by calculating IPG and scheduling packets accordingly
"""

import matplotlib.pyplot as plt
from collections import deque
from scheduler_single_flow_constants import *
from RoCE_packet import RoCEPacket


def load_Rc_timestamps(file_path):
    with open(file_path, "r") as f:
        return [
            (int(line.strip().split()[0]), float(line.strip().split()[1]))
            for line in f
            if line.strip()
        ]


Rc_changes = load_Rc_timestamps(RC_TIMESTAPMS_PATH)
packets = RoCEPacket.from_csv(INPUT_PACKETS_PATH)


def compute_transmission_time(packet_size):
    """Computes the time required to transmit the packet on the link."""
    total_bits = packet_size * 8  # Convert to bits
    transmission_time = total_bits / LINK_SPEED_BPNS  # Transmission time in ns
    return int(round(transmission_time))  # Ensure proper rounding and integer return


def compute_ipg(packet_size, Rc):
    """Computes the Inter-Packet Gap (IPG) required for rate enforcement."""
    total_bits = packet_size * 8  # + PACKET_OVERHEAD_BITS
    ideal_departure_time = total_bits / Rc  # Rc in bpns = Gbps
    # transmission_time = compute_transmission_time(packet_size)
    # return max(1, ideal_departure_time - transmission_time)  # No negative gaps

    return int(round(ideal_departure_time))


def get_input_buffer_size(input_buffer):
    input_buffer_size = 0
    for packet in input_buffer:
        input_buffer_size += packet.size
    return input_buffer_size / 8 / 1000  # Convert to KB


def compute_average_rate(scheduled_packets, num_packets):
    """
    Computes the average rate based on a fixed number of past packets.
    Includes the IPG from one packet before the oldest packet in the window.
    - num_packets: Number of past packets to consider
    """
    if len(scheduled_packets) < num_packets + 1:
        return 0.0

    recent_packets = list(scheduled_packets)[-(num_packets + 1) :]
    total_bits = sum(packet.size * 8 for _, packet in recent_packets[1:])
    time_span = recent_packets[-1][0] - recent_packets[0][0]

    return total_bits / time_span if time_span > 0 else 0.0


input_buffer = deque()
scheduled_packets = deque()
ipg_end = 0

rate_history = []
time_history = []
input_buffer_occupancy = []


window_avg_rate = 0
real_rate_history = []

Rc = Rc_changes[0][1]
Rc_next = 1

for t in range(0, END_OF_TIME, 1):  # Simulate time in nanoseconds
    # Update app layer rate if needed
    if Rc_next < len(Rc_changes) and t == Rc_changes[Rc_next][0]:
        Rc = Rc_changes[Rc_next][1]
        Rc_next += 1

    # Fill input buffer with incoming app data, drain it at RP rate
    while packets and packets[0].timestamp == t:
        input_buffer.append(packets.popleft())
        # in here algorithm for scheduling for many flows

    # Drain input buffer at Rc rate
    if input_buffer and t > ipg_end:
        packet = input_buffer.popleft()
        ipg = compute_ipg(packet.size, Rc)
        scheduled_packets.append((t, packet))
        ipg_end += ipg

    # Log data for visualization
    time_history.append(t)
    # rate_history.append(Rc)
    input_buffer_occupancy.append(get_input_buffer_size(input_buffer))
    rate_history.append(Rc)

    real_rate_history.append(compute_average_rate(scheduled_packets, AVG_RATE_WINDOW))

# Extract scheduled packet timestamps and sizes
sent_times = [ts for ts, _ in scheduled_packets]
packet_sizes = [pkt.size for _, pkt in scheduled_packets]

# Plot results
plt.figure(figsize=(10, 7))

# First plot: Rate Adjustment & App Layer Rate
plt.subplot(2, 1, 1)
plt.plot(time_history, rate_history, label="Target rate (Rc)", color="b")
plt.plot(
    time_history,
    real_rate_history,
    label="Avg real rate",
    color="r",
    linestyle="dashed",
)

plt.xlabel("Time (ns)")
plt.ylabel("Rate (b/ns)")
plt.title("Rate control comparison")
plt.legend()
plt.grid()

# Third plot: Input & Output Buffer Occupancy with Threshold
plt.subplot(2, 1, 2)

plt.plot(
    time_history, input_buffer_occupancy, label="Input Buffer Occupancy", color="b"
)  # New input buffer plot
# Plot packet send events as vertical lines
plt.vlines(
    sent_times,
    ymin=min(real_rate_history),
    ymax=max(real_rate_history),
    colors="r",
    linestyles="dotted",
    label="Packet Sent",
)

plt.xlabel("Time (ns)")
plt.ylabel("Buffer Size (KB)")
plt.title("Buffer Occupancy Over Time")
plt.legend()
plt.grid()

plt.tight_layout()
plt.show()
