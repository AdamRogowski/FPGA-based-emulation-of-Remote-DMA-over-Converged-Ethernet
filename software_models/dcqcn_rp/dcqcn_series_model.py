"""
(Latest) Model of the RP and DCQCN rate adjustment mechanism
Allows for running a series of simulations for different RP params
Reads app layer rates from the csv as an input
"""

import numpy as np
import matplotlib.pyplot as plt
from collections import deque
from dcqcn_constants import *


# --- Utility function to load app layer rate changes ---
def load_app_rate_timestamps(file_path):
    with open(file_path, "r") as f:
        return [tuple(map(int, line.strip().split())) for line in f if line.strip()]


# --- Reaction Point (RP) Class ---
class ReactionPoint:
    def __init__(self, Rc_init, K, F, Rai, g, alpha_init):
        self.Rc = Rc_init
        self.Rt = Rc_init
        self.K = K
        self.F = F
        self.Rai = Rai
        self.g = g
        self.alpha = alpha_init

        self.FR_timer = 1
        self.F_cnt = 1
        self.alpha_timer = 1
        self.input_buffer = 0

        self.time_history = []
        self.rate_history = []
        self.alpha_history = []
        self.input_buffer_history = []
        self.app_rate_history = []

    def process_input(self, t, app_rate, cn_np):
        self.time_history.append(t)
        self.app_rate_history.append(app_rate)
        self.input_buffer += app_rate
        data_to_transfer = min(self.Rc, self.input_buffer)
        self.input_buffer -= data_to_transfer
        cn_np.add_data(data_to_transfer, t)

    def update(self, event_flag):
        if event_flag:
            self.alpha = (1 - self.g) * self.alpha + self.g
            self.Rt = self.Rc
            self.Rc = self.Rc * (1 - self.alpha / 2)
            self.FR_timer = 1
            self.F_cnt = 1
            self.alpha_timer = 1

        if self.alpha_timer % self.K == 0:
            self.alpha = (1 - self.g) * self.alpha

        if self.FR_timer % self.K == 0:
            if self.F_cnt <= self.F:
                self.Rc = (self.Rt + self.Rc) / 2
                self.F_cnt += 1
            else:
                self.Rt += self.Rai
                self.Rc = (self.Rt + self.Rc) / 2

        self.FR_timer += 1
        self.alpha_timer += 1

        self.rate_history.append(self.Rc)
        self.alpha_history.append(self.alpha)
        self.input_buffer_history.append(self.input_buffer)


# --- Congestion Notification/Notification Point (CN/NP) Class ---
class CongestionNotification:
    def __init__(self, Output_rate, CNP_THRESHOLD, CNP_DELAY, N):
        self.Output_rate = Output_rate
        self.CNP_THRESHOLD = CNP_THRESHOLD
        self.CNP_DELAY = CNP_DELAY
        self.N = N

        self.output_buffer = 0
        self.cnp_timer = 1
        self.cnp_timer_ena = False
        self.cnp_queue = deque()
        self.transmission_queue = deque()

        self.output_buffer_history = []
        self.cnp_events = []

    def add_data(self, data, t):
        self.transmission_queue.append((t + self.CNP_DELAY, data))

    def tick(self, t):
        while self.transmission_queue and self.transmission_queue[0][0] <= t:
            _, data = self.transmission_queue.popleft()
            self.output_buffer += data

        self.output_buffer = max(0, self.output_buffer - self.Output_rate)

        if self.output_buffer > self.CNP_THRESHOLD:
            if not self.cnp_timer_ena and self.cnp_timer == 1:
                self.cnp_timer_ena = True
                self.cnp_events.append((t, self.output_buffer))
                self.cnp_queue.append(t + self.CNP_DELAY + 1)

        event_occurred = False
        if self.cnp_queue and self.cnp_queue[0] == t:
            self.cnp_queue.popleft()
            event_occurred = True

        if self.cnp_timer_ena:
            self.cnp_timer += 1
            if self.cnp_timer == self.N:
                self.cnp_timer = 1
                self.cnp_timer_ena = False

        self.output_buffer_history.append(self.output_buffer)
        return event_occurred


# --- Simulation Function ---
def run_simulation(
    app_rate_changes,
    sim_time,
    RC_INIT,
    K,
    F,
    R_AI,
    G,
    ALPHA_INIT,
    OUTPUT_RATE,
    CNP_THRESHOLD,
    CNP_DELAY,
    N,
):
    rp = ReactionPoint(RC_INIT, K, F, R_AI, G, ALPHA_INIT)
    cn_np = CongestionNotification(OUTPUT_RATE, CNP_THRESHOLD, CNP_DELAY, N)

    current_app_rate = app_rate_changes[0][1]
    next_app_index = 1

    for t in range(sim_time):
        if (
            next_app_index < len(app_rate_changes)
            and t == app_rate_changes[next_app_index][0]
        ):
            current_app_rate = app_rate_changes[next_app_index][1]
            next_app_index += 1

        rp.process_input(t, current_app_rate, cn_np)
        event_flag = cn_np.tick(t)
        rp.update(event_flag)

    return rp, cn_np


if __name__ == "__main__":
    app_rate_changes = load_app_rate_timestamps(APP_RATE_INPUT_PATH)

    """
    To run series of simulations uncomment RUN SERIES section, choose series parameter(s);
    Otherwise run simulation once for default params defined in dcqcn_constants
    """
    # """
    # RUN ONCE
    rp, cn_np = run_simulation(
        app_rate_changes,
        END_OF_TIME,
        RC_INIT,
        K,
        F,
        R_AI,
        G,
        ALPHA_INIT,
        OUTPUT_RATE,
        CNP_THRESHOLD,
        CNP_DELAY,
        N,
    )

    plt.figure(figsize=(10, 7))

    plt.subplot(2, 1, 1)
    plt.plot(rp.time_history, rp.rate_history, label="RP Rate (Rc)", color="b")
    if cn_np.cnp_events:
        times = [t for t, _ in cn_np.cnp_events]
        rates = [rp.rate_history[t] for t in times]
        plt.scatter(times, rates, color="r", marker="x", label="CNP Arrival")

    plt.plot(
        rp.time_history,
        rp.app_rate_history,
        label="App Layer Rate",
        color="c",
        linestyle="--",
    )
    plt.axhline(OUTPUT_RATE, color="y", linestyle="dotted", label="Output Rate")
    plt.xlabel("Time (us)")
    plt.ylabel("Rate (B/us)")
    plt.title(f"RP Rate, g={G:.1f}")
    plt.legend()
    plt.grid()

    plt.subplot(2, 1, 2)
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
    plt.tight_layout()
    plt.show()
    # """

    # RUN SERIES
    """
    # run series for different g
    G_series = np.linspace(0.1, 0.9, 3)

    for i, G in enumerate(G_series):

        rp, cn_np = run_simulation(
            app_rate_changes,
            END_OF_TIME,
            RC_INIT,
            K,
            F,
            R_AI,
            G,
            ALPHA_INIT,
            OUTPUT_RATE,
            CNP_THRESHOLD,
            CNP_DELAY,
            N,
        )

        plt.figure(figsize=(10, 7))

        plt.subplot(2, 1, 1)
        plt.plot(rp.time_history, rp.rate_history, label="RP Rate (Rc)", color="b")
        if cn_np.cnp_events:
            times = [t for t, _ in cn_np.cnp_events]
            rates = [rp.rate_history[t] for t in times]
            plt.scatter(times, rates, color="r", marker="x", label="CNP Arrival")

        plt.plot(
            rp.time_history,
            rp.app_rate_history,
            label="App Layer Rate",
            color="c",
            linestyle="--",
        )
        plt.axhline(OUTPUT_RATE, color="y", linestyle="dotted", label="Output Rate")
        plt.xlabel("Time (us)")
        plt.ylabel("Rate (B/us)")
        plt.title(f"RP Rate, g={G:.1f}")
        plt.legend()
        plt.grid()

        plt.subplot(2, 1, 2)
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

        output_path = f"{FIG_OUT_PATH}/dcqcn_simulation_1_{i}.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=300)
    """
