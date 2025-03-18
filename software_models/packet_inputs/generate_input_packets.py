import csv
import numpy as np


def generate_packet_csv(
    filename,
    num_packets=1000,
    mean_interarrival=1000,
    var_interarrival=100,
    mean_size=1500,
    var_size=100,
):
    """
    Generates a CSV file with randomized packet arrivals and sizes.
    - mean_interarrival: Mean inter-arrival time (us)
    - var_interarrival: Variance for inter-arrival time
    - mean_size: Mean packet size (bytes)
    - var_size: Variance for packet size
    """
    with open(filename, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["timestamp", "size", "seq_number"])

        timestamp = 0
        for seq_number in range(1, num_packets + 1):
            interarrival_time = max(
                1, int(np.random.normal(mean_interarrival, var_interarrival))
            )
            packet_size = max(
                64, int(np.random.normal(mean_size, var_size))
            )  # Min packet size 64B
            timestamp += interarrival_time
            writer.writerow([timestamp, packet_size, seq_number])


# Example usage
generate_packet_csv(
    "software_models/packet_inputs/random_packets.csv",
    num_packets=1000,
    mean_interarrival=1000,
    var_interarrival=200,
    mean_size=1500,
    var_size=100,
)
