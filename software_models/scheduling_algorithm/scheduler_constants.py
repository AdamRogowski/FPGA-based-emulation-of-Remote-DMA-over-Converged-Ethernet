END_OF_TIME = 2_000_000_000  # Total simulation time in ns
SIMULATION_STEP = 200
CALENDAR_WINDOW = 67_108_864  # MTU_SIZE / MIN_RATE * 1e9 (ns)
CALENDAR_INTERVAL_LIST = 500
CALENDAR_SLOTS = CALENDAR_WINDOW // CALENDAR_INTERVAL_LIST  # 60k slots
MTU_SIZE = 12_000  # Fixed packet size in bits

# Rate Control Constants
# For deterministic simulation modify: CNP_OCCURRENCE_PROB = 1.0; CNP_STD_DEV = 0.0
FAST_RECOVERY_FACTOR = 0.5  # Proportional factor for recovery
PROBING_INCREASE_BPS = 5000  # Small constant increase for probing
ACTIVE_INCREASE_FACTOR = 0.03  # Rate change factor per packet sent
CNP_OCCURRENCE_PROB = 0.7  # Probability of CNP occurrence
CNP_MEAN_DECREASE = 0.4  # Mean decrease = 40% of initial rate
CNP_STD_DEV = 0.1  # Standard deviation = 10% of initial rate
CONGESTION_THRESHOLD = 1.5  # 150% of initial rate
MIN_RATE = 220_000  # Minimum rate in bps

# Flow Generation Constants
# target number of flows: 256k
# target total speed: 100Gbps
# Therefore, target max rate per flow: 100Gbps / 256k = 390625bps
GENERATE_NEW_PACKETS = False
NUM_GROUPS = 256
NUM_FLOWS_PER_GROUP = 1024
GROUP_RATE_MEAN = 320_000
GROUP_RATE_VAR = 500_000_000  # mind the sqrt
TRACKED_FLOW = 100
OUTPUT_FLOW_GROUPS_PATH = "software_models/scheduling_algorithm/flow_groups.csv"

import matplotlib.pyplot as plt
import numpy as np

# Data from your simulation
occupancy_data = {
    0: 119776,
    1: 115827,
    2: 155246,
    3: 172302,
    4: 163886,
    5: 124386,
    6: 77728,
    7: 40268,
    8: 19252,
    9: 7757,
    10: 2682,
    11: 685,
    12: 158,
    13: 40,
    14: 5,
    15: 1,
    17: 1,
}

# Prepare data for plotting
packets_per_slot = list(occupancy_data.keys())
slot_counts = list(occupancy_data.values())

# Create the bar chart
plt.figure(figsize=(8, 5))
bars = plt.bar(packets_per_slot, slot_counts, color="skyblue", edgecolor="black")

# --- Applying the descriptive titles ---
plt.xlabel("Slot Occupancy", fontsize=16)
plt.ylabel("Frequency (Number of Slots)", fontsize=16)
plt.title(
    "Distribution of Calendar Slot Occupancy (500ns Interval)",
    fontsize=16,
    fontweight="bold",
)

# Make the y-axis more readable (e.g., 150k instead of 150000)
plt.ticklabel_format(style="sci", axis="y", scilimits=(0, 0))
plt.gca().yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: format(int(x), ",")))


# Set x-axis ticks to be integers, showing all values
plt.xticks(np.arange(0, max(packets_per_slot) + 1, 1))

# Add a grid for better readability
plt.grid(axis="y", linestyle="--", alpha=0.7)

# Add data labels on top of bars (optional, can be crowded)
# for bar in bars:
#     yval = bar.get_height()
#     plt.text(bar.get_x() + bar.get_width()/2.0, yval, int(yval), va='bottom', ha='center')

plt.tight_layout()
plt.show()
