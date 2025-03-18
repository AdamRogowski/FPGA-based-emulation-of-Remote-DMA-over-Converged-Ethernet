"""
Model of the RP and DCQCN rate adjustment mechanism
Tries to model app layer traffic as a stream of incoming packets
Reads packets from the csv as an input
Rather use dcqcn_series_model
"""

import matplotlib.pyplot as plt
from collections import deque
from dcqcn_constants import *
from RoCE_packet import RoCEPacket

"""
# --- Utility function to load app layer rate changes ---
def load_app_rate_timestamps(file_path):
    with open(file_path, "r") as f:
        return [tuple(map(int, line.strip().split())) for line in f if line.strip()]
"""


# --- Reaction Point (RP) Class ---
class ReactionPoint:
    def __init__(self, RC_INIT, ALPHA_INIT):
        self.Rc = RC_INIT
        self.Rt = RC_INIT
        self.alpha = ALPHA_INIT

        self.FR_timer = 1
        self.F_cnt = 1
        self.alpha_timer = 1
        self.ipg_timestamp = 1
        self.next_input_timestamp = 1

        self.input_buffer = deque()

        self.time_history = []
        self.rate_history = []
        self.alpha_history = []
        self.input_buffer_history = []
        self.app_rate_history = []

    def get_input_buffer_size(self):
        input_buffer_size = 0
        for packet in self.input_buffer:
            input_buffer_size += packet.size
        return input_buffer_size

    def process_input(self, t, packets):
        self.time_history.append(t)
        # self.app_rate_history.append(app_rate)
        app_rate = 0

        if self.next_input_timestamp == t:
            current_packet = packets.popleft()
            self.input_buffer.append(current_packet)
            self.next_input_timestamp = packets[0].timestamp
            app_rate += current_packet.size

        """
        # Append all packets with timestamp == t to the input buffer
        for packet in packets:
            if packet.timestamp == t:
                self.input_buffer.append(packet)
                app_rate += packet.size
        """
        # self.app_rate_history.append(app_rate)

    def compute_transmission_time(self, packet_size):
        """Computes the time required to transmit the packet on the link."""
        total_bits = packet_size * 8  # + PACKET_OVERHEAD_BITS  # Convert to bits
        # print(total_bits / LINK_SPEED_BPS)
        return total_bits / LINK_SPEED_BPS  # Transmission time in ns

    def compute_ipg(self, packet_size):
        """Computes the Inter-Packet Gap (IPG) required for rate enforcement."""
        total_bits = packet_size * 8  # + PACKET_OVERHEAD_BITS
        ideal_departure_time = total_bits / self.Rc  # TODO: adjust units
        transmission_time = self.compute_transmission_time(packet_size)
        return max(1, ideal_departure_time - transmission_time)  # No negative gaps

    def transfer_packet(self, t, cn_np):
        if self.input_buffer and self.ipg_timestamp == t:
            packet = self.input_buffer.popleft()
            # ipg_test = self.compute_ipg(packet.size)
            self.ipg_timestamp = (int)(t + self.compute_ipg(packet.size))
            print(self.ipg_timestamp)
            cn_np.add_data(packet.size, t + TX_DELAY)

        """
        self.input_buffer += app_rate
        data_to_transfer = min(self.Rc, self.input_buffer)
        self.input_buffer -= data_to_transfer
        cn_np.add_data(data_to_transfer, t + TX_DELAY)
        """

    def update_rate(self, event_flag):
        if event_flag:
            self.alpha = (1 - G) * self.alpha + G
            self.Rt = self.Rc
            self.Rc = self.Rc * (1 - self.alpha / 2)
            self.FR_timer = 1
            self.F_cnt = 1
            self.alpha_timer = 1

        if self.alpha_timer % K == 0:
            self.alpha = (1 - G) * self.alpha

        if self.FR_timer % K == 0:
            if self.F_cnt <= F:
                self.Rc = (self.Rt + self.Rc) / 2
                self.F_cnt += 1
            else:
                self.Rt += R_AI
                self.Rc = (self.Rt + self.Rc) / 2

        self.FR_timer += 1000
        self.alpha_timer += 1000

        self.rate_history.append(self.Rc)
        self.alpha_history.append(self.alpha)
        self.input_buffer_history.append(self.get_input_buffer_size())


# --- Congestion Notification/Notification Point (CN/NP) Class ---
class CongestionNotification:
    def __init__(self):

        self.output_buffer = 0
        self.cnp_timer = 1
        self.cnp_timer_ena = False
        self.cnp_queue = deque()
        self.transmission_queue = deque()

        self.output_buffer_history = []
        self.cnp_events = []

    def add_data(self, data, t):
        self.transmission_queue.append((t, data))

    def tick(self, t):
        while self.transmission_queue and self.transmission_queue[0][0] <= t:
            _, data = self.transmission_queue.popleft()
            self.output_buffer += data

        self.output_buffer = max(0, self.output_buffer - OUTPUT_RATE)

        if self.output_buffer > CNP_THRESHOLD:
            if not self.cnp_timer_ena and self.cnp_timer == 1:
                self.cnp_timer_ena = True
                self.cnp_events.append((t, self.output_buffer))
                self.cnp_queue.append(t + CNP_DELAY + 1)

        event_occurred = False
        if self.cnp_queue and self.cnp_queue[0] == t:
            self.cnp_queue.popleft()
            event_occurred = True

        if self.cnp_timer_ena:
            self.cnp_timer += 1
            if self.cnp_timer == N:
                self.cnp_timer = 1
                self.cnp_timer_ena = False

        self.output_buffer_history.append(self.output_buffer)
        return event_occurred


# --- Simulation Function ---
def run_simulation(packets, sim_time):
    rp = ReactionPoint(RC_INIT, ALPHA_INIT)
    cn_np = CongestionNotification()

    # current_app_rate = app_rate_changes[0][1]
    # next_app_index = 1

    for t in range(sim_time):
        # if (
        #    next_app_index < len(app_rate_changes)
        #    and t == app_rate_changes[next_app_index][0]
        # ):
        #    current_app_rate = app_rate_changes[next_app_index][1]
        #    next_app_index += 1

        rp.process_input(t, packets)
        rp.transfer_packet(t, cn_np)
        event_flag = cn_np.tick(t)
        rp.update_rate(event_flag)

    return rp, cn_np


# --- Example Usage and Plotting ---
if __name__ == "__main__":
    # app_rate_changes = load_app_rate_timestamps(input_path)

    packets = RoCEPacket.from_csv(INPUT_PACKETS_PATH)

    rp, cn_np = run_simulation(packets, END_OF_TIME)

    plt.figure(figsize=(10, 7))

    plt.subplot(3, 1, 1)
    plt.plot(rp.time_history, rp.rate_history, label="RP Rate (Rc)", color="b")
    if cn_np.cnp_events:
        times = [t for t, _ in cn_np.cnp_events]
        rates = [rp.rate_history[t] for t in times]
        plt.scatter(times, rates, color="r", marker="x", label="CNP Arrival")

    """
    plt.plot(
        rp.time_history,
        rp.app_rate_history,
        label="App Layer Rate",
        color="c",
        linestyle="--",
    )
    """
    plt.axhline(OUTPUT_RATE, color="y", linestyle="dotted", label="Output Rate")
    plt.xlabel("Time (us)")
    plt.ylabel("Rate (B/us)")
    plt.title("RP Rate & Application Layer Rate")
    plt.legend()
    plt.grid()

    plt.subplot(3, 1, 2)
    plt.plot(
        rp.time_history,
        cn_np.output_buffer_history,
        label="Output Buffer Occupancy",
        color="m",
    )
    plt.plot(
        rp.time_history,
        rp.input_buffer_history,
        label="Input Buffer Occupancy",
        color="b",
    )
    plt.axhline(CNP_THRESHOLD, color="r", linestyle="--", label="CNP Threshold")
    plt.xlabel("Time (us)")
    plt.ylabel("Buffer Size (B)")
    plt.title("Buffer Occupancy Over Time")
    plt.legend()
    plt.grid()

    # Second plot: Alpha Adjustment
    plt.subplot(3, 1, 3)
    plt.plot(rp.time_history, rp.alpha_history, label="Alpha History", color="g")
    plt.xlabel("Time (us)")
    plt.ylabel("Alpha Value")
    plt.title("Alpha Adjustment Over Time")
    plt.legend()
    plt.grid()

    plt.tight_layout()
    plt.show()
