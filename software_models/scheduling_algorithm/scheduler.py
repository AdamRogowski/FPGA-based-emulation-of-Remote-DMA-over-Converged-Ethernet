import csv
import random
from collections import deque, defaultdict
from dataclasses import dataclass
import numpy as np  # Import numpy for normal distribution
import matplotlib.pyplot as plt
from scheduler_constants import *


@dataclass
class Flow:
    id: int
    rate: float
    group_id: int


def generate_flow_groups_csv(num_groups, mean_rate, var_rate, output_file):
    # Ensure rates are positive by clipping values
    rates = np.random.normal(loc=mean_rate, scale=np.sqrt(var_rate), size=num_groups)
    rates = np.clip(rates, a_min=MIN_RATE, a_max=None)  # Ensure rates are at least 1

    # Write to CSV file
    with open(output_file, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["group_id", "rate"])
        for group_id, rate in enumerate(rates, start=1):
            writer.writerow([group_id, round(rate, 2)])

    print(f"Flow groups saved to {output_file}")


def load_flow_groups(file_path):
    """
    Load flow group information from a CSV file.
    Returns a dictionary {group_id: rate}.
    """
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
    Generate flows based on the group information.
    Flows are interleaved in a round-robin manner.
    Returns a deque of Flow objects and Rc_memory.
    """
    input_flow_queue = deque()
    Rc_memory = {}

    # Create flows
    flow_list = []
    flow_id = 1  # Unique flow ID

    for group_id, rate in flow_groups.items():
        for i in range(num_flows_per_group):
            flow = Flow(flow_id, rate, group_id)
            flow_list.append(flow)
            Rc_memory[flow_id] = rate  # Store initial rate
            flow_id += 1

    # Interleave flows in round-robin order
    for i in range(num_flows_per_group):
        for flow in flow_list[i::num_flows_per_group]:  # Select one per group in order
            input_flow_queue.append(flow)

    return input_flow_queue, Rc_memory


# Compute Inter-Packet Gap (IPG) based on rate
def compute_ipg(rate):
    return max(
        1, int(round(MTU_SIZE / rate * 1e9))
    )  # Converts rate to time in nanoseconds


def compute_cnp_rate_thresholds(input_flow_settings):
    cnp_rate_thresholds = {}
    for flow in input_flow_settings:
        cnp_rate_thresholds[flow.id] = CONGESTION_THRESHOLD * flow.rate
    return cnp_rate_thresholds


# Scheduler Simulation
class Scheduler:
    def __init__(self, input_flow_settings, Rc_memory, tracked_flow_id=100):
        self.input_flow_queue = input_flow_settings  # Used for initial scheduling
        self.Rc_memory = Rc_memory  # Current rates per flow
        self.input_flow_settings = (
            Rc_memory.copy()
        )  # Used for Rc calculation base on initial rate
        self.cnp_rate_thresholds = compute_cnp_rate_thresholds(input_flow_settings)
        self.calendar_counter = 0

        self.calendar_queue = deque([] for _ in range(CALENDAR_SLOTS))
        self.output_stats = defaultdict(int)  # Track bytes sent per flow
        self.max_calendar_occupancy = 0  # Track max packets in a single slot

        # Tracking statistics for the predefined flow
        self.tracked_flow_id = tracked_flow_id  # Flow ID to track
        self.tracked_timestamps = deque(maxlen=4)  # Store last 4 send times
        self.tracked_real_rates = []  # Store real rate over time
        self.tracked_Rc_memory = []  # Store Rc values over time
        self.tracked_time = []  # Store time points for visualization
        self.tracked_occupancy = [0] * 10000  # Store calendar occupancy
        self.tracked_number_of_packets = 0

        self.progress_bar = deque([i * (END_OF_TIME // 100) for i in range(1, 101)])

    def run_simulation(self):
        for t in range(0, END_OF_TIME, SIMULATION_STEP):

            if t == self.progress_bar[0]:
                self.progress_bar.popleft()
                print(f"Progress: {t * 100 // END_OF_TIME}%")

            # Phase 1: Schedule first packet for each flow

            # Phase 2: Process current time slot
            if self.calendar_counter >= CALENDAR_INTERVAL_LIST:

                if self.input_flow_queue:
                    packet = self.input_flow_queue.popleft()
                    ipg = compute_ipg(packet.rate)
                    scheduled_time_slot = (int)((ipg) / CALENDAR_INTERVAL_LIST)
                    # print(f"{scheduled_time_slot} = {ipg} + {(int)(t / CALENDAR_INTERVAL)}")
                    try:
                        self.calendar_queue[scheduled_time_slot].append(packet)
                    except IndexError:
                        print(
                            f"IndexError: ipg (us): {ipg}\nt: {t}\nscheduled time slot: {scheduled_time_slot}\nflow rate: {packet.rate}\nflow id: {packet.id}\ncalendar_queue length: {len(self.calendar_queue)}"
                        )

                self.process_calendar_slot(t)
                self.calendar_counter = SIMULATION_STEP
            else:
                self.calendar_counter += SIMULATION_STEP
                # print(f"{t},{self.calendar_counter}")

    def process_calendar_slot(self, t):
        # Check if the current slot has flows scheduled
        current_slot_flows = self.calendar_queue.popleft()
        self.calendar_queue.append(deque())
        if not current_slot_flows:
            self.tracked_occupancy[0] += 1
            return
        else:

            self.max_calendar_occupancy = max(
                self.max_calendar_occupancy, len(current_slot_flows)
            )

            self.tracked_occupancy[len(current_slot_flows)] += 1

            for flow in current_slot_flows:
                self.send_flow(flow, t)

    def send_flow(self, flow, t):

        self.tracked_number_of_packets += 1

        # Track only the predefined flow
        if flow.id == self.tracked_flow_id:
            self.tracked_timestamps.append(t)  # Store time
            # print(t / 1e6)

            if len(self.tracked_timestamps) >= 4:
                # Compute the real rate using the first and fourth timestamps
                time_diff = (
                    self.tracked_timestamps[-1] - self.tracked_timestamps[-4]
                ) / 1e9  # Convert ns to s
                # print(time_diff)
                real_rate = (3 * MTU_SIZE) / time_diff  # Bits per second
                # print(real_rate)
                self.tracked_real_rates.append(real_rate)
            else:
                self.tracked_real_rates.append(None)  # Not enough data yet

            # Store Rc memory and time
            self.tracked_Rc_memory.append(self.Rc_memory[flow.id])
            self.tracked_time.append(t)  # Convert ns to ms

        self.output_stats[flow.id] += MTU_SIZE  # Increase sent bytes

        # Update flow rate
        self.update_rate(flow.id)

        # Schedule next packet
        ipg = compute_ipg(self.Rc_memory[flow.id])
        scheduled_time_slot = (int)(ipg / CALENDAR_INTERVAL_LIST)
        self.calendar_queue[scheduled_time_slot].append(
            Flow(flow.id, self.Rc_memory[flow.id], flow.group_id)
        )

        # debugging purposes
        """
        if flow.id == self.tracked_flow_id:
            print(
                # f"ipg: {ipg}, scheduled time slot: {scheduled_time_slot}, Rc: {flow.rate}"
                f"{t},{ipg}"
            )
        """

    def update_rate(self, flow_id):
        # Active increase: Always increase rate by RATE_VARIATION_FACTOR
        rate_change = self.Rc_memory[flow_id] * ACTIVE_INCREASE_FACTOR
        self.Rc_memory[flow_id] += rate_change

        # Get the flow's initial rate
        initial_rate = self.input_flow_settings[flow_id]

        # Define congestion threshold (150% of initial rate)
        congestion_threshold = self.cnp_rate_thresholds[flow_id]

        # Check if current rate exceeds congestion threshold
        if self.Rc_memory[flow_id] > congestion_threshold:
            if random.random() < CNP_OCCURRENCE_PROB:
                decrease_factor = max(
                    0,
                    random.gauss(
                        CNP_MEAN_DECREASE * initial_rate, CNP_STD_DEV * initial_rate
                    ),
                )
                # Apply decrease
                self.Rc_memory[flow_id] -= decrease_factor

        # Ensure minimum rate of 300kbps
        self.Rc_memory[flow_id] = max(MIN_RATE, self.Rc_memory[flow_id])

    def plot_results(self):
        plt.figure(figsize=(10, 5))

        # Remove None values from real rate for plotting
        notnull_real_rates = [r for r in self.tracked_real_rates if r is not None]

        # max_real_rate = max(notnull_real_rates)
        valid_real_rates = [
            # r / max_real_rate for r in self.tracked_real_rates if r is not None
            r
            for r in self.tracked_real_rates
            if r is not None
        ]
        valid_time = self.tracked_time[
            len(self.tracked_real_rates) - len(valid_real_rates) :
        ]

        # max_Rc_memory = max(self.tracked_Rc_memory) if self.tracked_Rc_memory else 0
        # valid_Rc_memory = [r / max_Rc_memory for r in self.tracked_Rc_memory]
        valid_Rc_memory = [r for r in self.tracked_Rc_memory]

        plt.plot(
            valid_time,
            valid_real_rates,
            label="Real Rate (4-timestamp avg)",
            marker="o",
        )
        plt.plot(
            self.tracked_time,
            valid_Rc_memory,
            label="Rc Memory Rate",
            linestyle="dashed",
        )

        plt.xlabel("Time (ns)")
        plt.ylabel("Rate (bps)")
        plt.title(f"Rate Evolution for Flow {self.tracked_flow_id}")
        plt.legend()
        plt.grid()
        plt.show()


if GENERATE_NEW_PACKETS:
    # Generate flow groups and save to CSV file
    generate_flow_groups_csv(
        NUM_GROUPS,
        GROUP_RATE_MEAN,
        GROUP_RATE_VAR,
        OUTPUT_FLOW_GROUPS_PATH,
    )

# Load flows and run simulation
flow_groups = load_flow_groups(OUTPUT_FLOW_GROUPS_PATH)
flow_settings, Rc_memory = generate_flows(flow_groups, NUM_FLOWS_PER_GROUP)


scheduler = Scheduler(flow_settings, Rc_memory, TRACKED_FLOW)
scheduler.run_simulation()
scheduler.plot_results()
tracked_output_stats = scheduler.output_stats.get(TRACKED_FLOW, 0)
# sorted_output_stats = dict(sorted(scheduler.output_stats.items()))

# Print results
print("Total bytes sent per flow:", tracked_output_stats)
print("Max calendar slot occupancy:", scheduler.max_calendar_occupancy)

for i in range(0, len(scheduler.tracked_occupancy)):
    if scheduler.tracked_occupancy[i] > 0:
        print(f"Calendar occupancy {i} packets: {scheduler.tracked_occupancy[i]}")


# Sample data from your print output
x_values = list(range(len(scheduler.tracked_occupancy)))  # Packet index
y_values = scheduler.tracked_occupancy  # Corresponding occupancy values

# Filter out zero values
x_values_filtered = [x for x, y in zip(x_values, y_values) if y > 0]
y_values_filtered = [y for y in y_values if y > 0]

# Create bar plot
plt.figure(figsize=(8, 5))
plt.bar(x_values_filtered, y_values_filtered, color="blue")

# Labels and title
plt.xlabel("Calendar slot (packets)")
plt.ylabel("Occupancy count")
plt.title("Calendar Occupancy Distribution")

# Show grid for better readability
plt.grid(axis="y", linestyle="--", alpha=0.7)

# Show the plot
plt.show()

print(f"Number of packets sent: {scheduler.tracked_number_of_packets}")
