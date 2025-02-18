input_path = "app_rate_timestamps.txt"
fig_out_dir = "Figures/generated"

N = 50  # Max CNP arrival frequency (us)
K = 55  # Reduction factor update timer (us)
F = 5  # Fast Recovery iterations
ALPHA_INIT = 0.5  # Initial reduction factor
G = 0.2  # Weight factor
R_AI = 2  # Rate increase for active mode (B/us)
CNP_DELAY = 6  # CNP delay (us)
TX_DELAY = 7  # Transmission delay (us)
CNP_THRESHOLD = 2000  # Output buffer threshold (Bytes)
RC_INIT = 135  # Initial rate (B/us)
OUTPUT_RATE = 129  # (B/us)
END_OF_TIME = 3000  # Simulation time in microseconds
