input_path = "app_rate_timestamps.txt"

N = 50  # Max CNP arrival frequency (us)
K = 55  # Reduction factor update timer (us)
F = 5  # Fast Recovery iterations
alpha = 0.5  # Initial reduction factor
g = 0.2  # Weight factor
Rai = 2  # Rate increase for active mode (B/us)
CNP_DELAY = 10  # CNP delay (us)
CNP_THRESHOLD = 2000  # Output buffer threshold (Bytes)
Rc_INIT = 135  # Initial rate (B/us)
Output_rate = 129  # (B/us)
END_OF_TIME = 3000  # Simulation time in microseconds
