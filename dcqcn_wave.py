import numpy as np
import matplotlib.pyplot as plt
from constants import *


# Load App Layer Timestamps
def load_app_rate_timestamps(file_path):
    with open(file_path, "r") as f:
        return [tuple(map(int, line.strip().split())) for line in f if line.strip()]


app_rate_changes = load_app_rate_timestamps(input_path)

# Initialize variables
Rc = Rc_INIT  # Initial rate (arbitrary unit)
Rt = Rc  # Target rate for recovery

input_buffer = 0  # Bytes
output_buffer = 0  # Bytes

rate_history = []
time_history = []
alpha_history = [alpha]
input_buffer_occupancy = []
output_buffer_occupancy = []
app_rate_history = []
cmp_events = []
cmp_queue = []

current_app_rate = app_rate_changes[0][1]
next_app_index = 1
FR_timer = 1  # Timer for rate increase (in terms of K)
F_cnt = 0  # Fast recovery iterations counter
alpha_timer = 1
cnp_timer = 0
cnp_timer_ena = False

for t in range(0, END_OF_TIME, 1):  # Simulate time in microseconds
    # Update app layer rate if needed
    if (
        next_app_index < len(app_rate_changes)
        and t == app_rate_changes[next_app_index][0]
    ):
        current_app_rate = app_rate_changes[next_app_index][1]
        next_app_index += 1

    # Fill input buffer with incoming app data, drain it at RP rate
    input_buffer += current_app_rate  # Fill at app rate
    data_to_transfer = min(Rc, input_buffer)  # Ensure we don't take more than available
    input_buffer = max(0, input_buffer - data_to_transfer)  # Drain at RP rate

    # Fill output buffer with RP rate, drain it at constant rate
    output_buffer += data_to_transfer  # Fill at max RP rate
    output_buffer = max(0, output_buffer - Output_rate)  # Drain at constant rate

    # Check congestion and generate CNP
    if output_buffer > CNP_THRESHOLD:
        if not cnp_timer_ena and cnp_timer == 0:
            cnp_timer_ena = True
            cmp_events.append((t, Rc))
            cmp_queue.append(t + CNP_DELAY)

    # Process CNP queue
    if cmp_queue and cmp_queue[0] == t:
        cmp_queue.pop(0)
        alpha = (1 - g) * alpha + g
        Rt = Rc
        Rc = Rc * (1 - alpha / 2)
        FR_timer = 1
        alpha_timer = 1
        F_cnt = 1

    # Timer-based reduction factor adjustment
    if alpha_timer % K == 0:
        alpha = (1 - g) * alpha

    # Timer Rate increase Event
    if FR_timer % K == 0:
        if F_cnt <= F:
            Rc = (Rt + Rc) / 2  # Fast Recovery
            F_cnt += 1
        else:
            Rt += Rai
            Rc = (Rt + Rc) / 2

    FR_timer += 1
    alpha_timer += 1

    if cnp_timer_ena:
        cnp_timer += 1
        if cnp_timer == N - 1:
            cnp_timer = 0
            cnp_timer_ena = False

    # Log data for visualization
    time_history.append(t)
    rate_history.append(Rc)
    alpha_history.append(alpha)
    input_buffer_occupancy.append(input_buffer)
    output_buffer_occupancy.append(output_buffer)
    app_rate_history.append(current_app_rate)


# Plot results
plt.figure(figsize=(10, 7))

# First plot: Rate Adjustment & App Layer Rate
plt.subplot(2, 1, 1)
plt.plot(time_history, rate_history, label="Rate Adjustment (Rc)", color="b")
if cmp_events:
    plt.scatter(*zip(*cmp_events), color="r", marker="x", label="CNP Arrival")
plt.plot(
    time_history, app_rate_history, label="App Layer Rate", color="c", linestyle="--"
)
plt.axhline(
    Output_rate, color="y", linestyle="dotted", label="Output Rate"
)  # Threshold line
plt.xlabel("Time (us)")
plt.ylabel("Rate (B/us)")
plt.title("DCQCN Reaction Point Rate & App Layer Rate")
plt.legend()
plt.grid()

# Third plot: Input & Output Buffer Occupancy with Threshold
plt.subplot(2, 1, 2)
plt.plot(
    time_history, output_buffer_occupancy, label="Output Buffer Occupancy", color="m"
)
plt.plot(
    time_history, input_buffer_occupancy, label="Input Buffer Occupancy", color="b"
)  # New input buffer plot
plt.axhline(
    CNP_THRESHOLD, color="r", linestyle="--", label="CNP Threshold"
)  # Threshold line
plt.xlabel("Time (us)")
plt.ylabel("Buffer Size (B)")
plt.title("Buffer Occupancy Over Time")
plt.legend()
plt.grid()

"""
# Second plot: Alpha Adjustment
plt.subplot(3, 1, 3)
plt.plot(time_history, alpha_history[:-1], label="Alpha History", color="g")
plt.xlabel("Time (us)")
plt.ylabel("Alpha Value")
plt.title("Alpha Adjustment Over Time")
plt.legend()
plt.grid()
"""

plt.tight_layout()
plt.show()
