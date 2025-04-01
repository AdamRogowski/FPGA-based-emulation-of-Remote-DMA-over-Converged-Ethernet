END_OF_TIME = 500_000_000  # Total simulation time in ns
SIMULATION_STEP = 200
CALENDAR_WINDOW = 60_000_000  # MTU_SIZE / MIN_RATE * 1e9 (ns)
CALENDAR_INTERVAL_LIST = 500
CALENDAR_SLOTS = CALENDAR_WINDOW // CALENDAR_INTERVAL_LIST  # 60k slots
MTU_SIZE = 12_000  # Fixed packet size in bits

# Rate Control Constants
# For deterministic simulation modify: CNP_OCCURRENCE_PROB = 1.0; CNP_STD_DEV = 0.0
ACTIVE_INCREASE_FACTOR = 0.03  # Rate change factor per packet sent
CNP_OCCURRENCE_PROB = 0.7  # Probability of CNP occurrence
CNP_MEAN_DECREASE = 0.3  # Mean decrease = 30% of initial rate
CNP_STD_DEV = 0.1  # Standard deviation = 10% of initial rate
CONGESTION_THRESHOLD = 1.3  # 130% of initial rate
MIN_RATE = 220_000  # Minimum rate in bps

# Flow Generation Constants
# target number of flows: 256k
# target total speed: 100Gbps
# Therefore, target max rate per flow: 100Gbps / 256k = 390625bps
GENERATE_NEW_PACKETS = False
NUM_GROUPS = 256
NUM_FLOWS_PER_GROUP = 1000
GROUP_RATE_MEAN = 320_000
GROUP_RATE_VAR = 500_000_000  # mind the sqrt
TRACKED_FLOW = 100
OUTPUT_FLOW_GROUPS_PATH = "software_models/scheduling_algorithm/flow_groups.csv"
