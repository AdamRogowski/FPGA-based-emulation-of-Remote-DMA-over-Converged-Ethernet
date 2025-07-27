import csv
import random
from collections import deque, defaultdict
import numpy as np
import matplotlib.pyplot as plt
from scheduler_constants import *

"""
# Constants
END_OF_TIME = 1_000_000_000  # Total simulation time in ns
# CALENDAR_INTERVAL = 50  # Calendar slot interval in ns
CALENDAR_WINDOW = 60_000_000  # Window length in ns (60 million)
# CALENDAR_SLOTS = CALENDAR_WINDOW // CALENDAR_INTERVAL  # Number of calendar slots
MTU_SIZE = 12000  # Packet size in bits

# Rate Control Constants
ACTIVE_INCREASE_FACTOR = 0.03  # Increase factor per packet sent
CNP_OCCURRENCE_PROB = 0.7  # CNP probability
CNP_MEAN_DECREASE = 0.3  # Mean decrease: 30% of initial rate
CNP_STD_DEV = 0.1  # Standard deviation: 10% of initial rate
CONGESTION_THRESHOLD = 1.3  # 130% of initial rate
MIN_RATE = 220000  # Minimum rate in bps

# Flow Generation Constants
NUM_GROUPS = 256
NUM_FLOWS_PER_GROUP = 1000
"""


# ---------------------------------------------------
# Flow generation functions (work with flow IDs only)
# ---------------------------------------------------
def generate_flow_groups_csv(num_groups, mean_rate, var_rate, output_file):
    # Generate group rates from a normal distribution and clip to MIN_RATE
    rates = np.random.normal(loc=mean_rate, scale=np.sqrt(var_rate), size=num_groups)
    rates = np.clip(rates, a_min=MIN_RATE, a_max=None)
    with open(output_file, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["group_id", "rate"])
        for group_id, rate in enumerate(rates, start=1):
            writer.writerow([group_id, round(rate, 2)])
    print(f"Flow groups saved to {output_file}")


def load_flow_groups(file_path):
    """Load flow group information from CSV. Returns a dict {group_id: rate}."""
    flow_groups = {}
    with open(file_path, "r") as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        for row in reader:
            group_id = int(row[0])
            rate = float(row[1])
            flow_groups[group_id] = rate
    return flow_groups


def generate_flows(flow_groups, num_flows_per_group):
    """
    Create flows in round-robin order.
    Instead of full Flow objects, we store flow IDs.
    Also returns two dictionaries:
      - Rc_memory: current rate per flow (initially the group rate)
      - init_rates: initial rate per flow (for use in rate update)
    """
    input_flow_queue = deque()
    Rc_memory = {}
    init_rates = {}
    flow_list = []
    flow_id = 1

    # For each group, create flows with the group's rate
    for group_id, rate in flow_groups.items():
        for _ in range(num_flows_per_group):
            flow_list.append(flow_id)
            Rc_memory[flow_id] = rate
            init_rates[flow_id] = rate
            flow_id += 1

    # Round-robin interleaving: take one flow from each group in order
    for i in range(num_flows_per_group):
        for fid in flow_list[i::num_flows_per_group]:
            input_flow_queue.append(fid)

    return input_flow_queue, Rc_memory, init_rates


def compute_cnp_rate_thresholds(init_rates):
    """Precompute the congestion thresholds for each flow."""
    return {fid: CONGESTION_THRESHOLD * rate for fid, rate in init_rates.items()}


# ---------------------------------------------------
# Optimized Scheduler (for calendar occupancy stats only)
# ---------------------------------------------------
class OptimizedScheduler:
    def __init__(
        self, input_flow_queue, Rc_memory, init_rates, CALENDAR_INTERVAL, CALENDAR_SLOTS
    ):
        self.input_flow_queue = input_flow_queue  # Deque of flow IDs (first scheduling)
        self.Rc_memory = Rc_memory  # Current rate per flow (dict)
        self.init_rates = init_rates  # Initial rate per flow (dict)
        self.cnp_rate_thresholds = compute_cnp_rate_thresholds(init_rates)
        # Use a list of lists as a circular buffer for calendar slots
        self.calendar_queue = [[] for _ in range(CALENDAR_SLOTS)]
        self.output_stats = defaultdict(int)  # Total bytes sent per flow
        # For calendar occupancy stats: index = number of flows in slot, value = count of slots
        self.tracked_occupancy = [0] * 10000
        self.max_calendar_occupancy = 0
        self.CALENDAR_INTERVAL = CALENDAR_INTERVAL
        self.CALENDAR_SLOTS = CALENDAR_SLOTS

    def run_simulation(self):
        num_slots = self.CALENDAR_SLOTS
        current_slot = 0
        t = 0

        # Advance time slot by slot (each step = CALENDAR_INTERVAL ns)
        while t < END_OF_TIME:
            # Phase 1: If any flows have not yet been scheduled, schedule one packet from the input queue.
            if self.input_flow_queue:
                fid = self.input_flow_queue.popleft()
                ipg = max(1, int(round(MTU_SIZE * 1e9 / self.Rc_memory[fid])))
                offset = ipg // self.CALENDAR_INTERVAL
                scheduled_slot = (current_slot + offset) % num_slots
                self.calendar_queue[scheduled_slot].append(fid)

            # Phase 2: Process flows in the current calendar slot.
            flows = self.calendar_queue[current_slot]
            n_flows = len(flows)
            # Ensure our occupancy list is long enough:
            if n_flows >= len(self.tracked_occupancy):
                self.tracked_occupancy.extend(
                    [0] * (n_flows - len(self.tracked_occupancy) + 1)
                )
            self.tracked_occupancy[n_flows] += 1
            if n_flows > self.max_calendar_occupancy:
                self.max_calendar_occupancy = n_flows

            # Process each flow scheduled in the current slot.
            for fid in flows:
                # Update total bytes sent
                self.output_stats[fid] += MTU_SIZE

                # Update the flow's rate (active increase, then possible congestion decrease)
                rate = self.Rc_memory[fid]
                new_rate = rate + rate * ACTIVE_INCREASE_FACTOR
                initial_rate = self.init_rates[fid]
                threshold = self.cnp_rate_thresholds[fid]
                if new_rate > threshold and random.random() < CNP_OCCURRENCE_PROB:
                    # Use random.gauss (faster than np.random.normal for a single value)
                    decrease = random.gauss(
                        CNP_MEAN_DECREASE * initial_rate, CNP_STD_DEV * initial_rate
                    )
                    if decrease < 0:
                        decrease = 0
                    new_rate -= decrease
                new_rate = max(MIN_RATE, new_rate)
                self.Rc_memory[fid] = new_rate

                # Schedule the next packet for this flow.
                ipg = max(1, int(round(MTU_SIZE * 1e9 / new_rate)))
                offset = ipg // self.CALENDAR_INTERVAL
                scheduled_slot = (current_slot + offset) % num_slots
                self.calendar_queue[scheduled_slot].append(fid)

            # Clear the current slot once processed.
            self.calendar_queue[current_slot].clear()
            # Advance time and calendar pointer.
            t += self.CALENDAR_INTERVAL
            current_slot = (current_slot + 1) % num_slots

    def print_calendar_occupancy_stats(self):
        print("Calendar occupancy statistics:")
        for occupancy, count in enumerate(self.tracked_occupancy):
            if count:
                print(f"Calendar occupancy {occupancy} packets: {count}")
        empty_non_empty_ratio = self.tracked_occupancy[0] / sum(self.tracked_occupancy)
        print(f"Empty/non_empty ratio: {empty_non_empty_ratio:.3f}")

        print("Max calendar slot occupancy:", self.max_calendar_occupancy)
        total_pkts = sum(self.output_stats.values()) // MTU_SIZE
        print(f"Number of packets sent: {total_pkts}")

        return empty_non_empty_ratio, self.max_calendar_occupancy


# ---------------------------------------------------
# Main simulation execution
# ---------------------------------------------------
if __name__ == "__main__":
    if GENERATE_NEW_PACKETS:
        # Generate flow groups and save to CSV file
        generate_flow_groups_csv(
            NUM_GROUPS,
            GROUP_RATE_MEAN,
            GROUP_RATE_VAR,
            OUTPUT_FLOW_GROUPS_PATH,
        )

    CALENDAR_INTERVAL_LIST = list(range(500, 550, 50))  # Calendar slot interval in ns

    results_ratio = []
    results_max_occupancy = []

    for calendar_interval in CALENDAR_INTERVAL_LIST:
        CALENDAR_SLOTS_TEMP = CALENDAR_WINDOW // calendar_interval
        print(f"Calendar interval: {calendar_interval} ns")
        flow_groups = load_flow_groups(OUTPUT_FLOW_GROUPS_PATH)
        input_flow_queue, Rc_memory, init_rates = generate_flows(
            flow_groups, NUM_FLOWS_PER_GROUP
        )
        scheduler = OptimizedScheduler(
            input_flow_queue,
            Rc_memory,
            init_rates,
            calendar_interval,
            CALENDAR_SLOTS_TEMP,
        )
        scheduler.run_simulation()
        ratio, max_occupancy = scheduler.print_calendar_occupancy_stats()
        results_ratio.append(ratio)
        results_max_occupancy.append(max_occupancy)

    plt.figure(figsize=(10, 10))

    # First subplot: Empty/non-empty ratio vs. Calendar Interval
    plt.subplot(3, 1, 1)
    plt.plot(CALENDAR_INTERVAL_LIST, results_ratio, marker="o", linestyle="-")
    plt.xlabel("Calendar Interval (ns)")
    plt.ylabel("Empty/Non-Empty Ratio")
    plt.title("Empty/Non-Empty Ratio vs. Calendar Interval")

    # Second subplot: Max Occupancy vs. Calendar Interval (integer y-axis)
    plt.subplot(3, 1, 2)
    plt.plot(
        CALENDAR_INTERVAL_LIST,
        results_max_occupancy,
        marker="s",
        linestyle="-",
        color="r",
    )
    plt.xlabel("Calendar Interval (ns)")
    plt.ylabel("Max Occupancy")
    plt.title("Max Occupancy vs. Calendar Interval")
    plt.yticks(
        range(min(results_max_occupancy), max(results_max_occupancy) + 1, 2)
    )  # Integer y-axis

    # Third subplot: (Empty/Non-Empty Ratio * Max Occupancy) vs. Calendar Interval
    ratio_times_occupancy = [
        r * m for r, m in zip(results_ratio, results_max_occupancy)
    ]
    plt.subplot(3, 1, 3)
    plt.plot(
        CALENDAR_INTERVAL_LIST,
        ratio_times_occupancy,
        marker="^",
        linestyle="-",
        color="g",
    )
    plt.xlabel("Calendar Interval (ns)")
    plt.ylabel("Ratio * Max Occupancy")
    plt.title("Empty/Non-Empty Ratio * Max Occupancy vs. Calendar Interval")

    plt.tight_layout()
    plt.show()

    # check notepad 24 for single rate over time plot
