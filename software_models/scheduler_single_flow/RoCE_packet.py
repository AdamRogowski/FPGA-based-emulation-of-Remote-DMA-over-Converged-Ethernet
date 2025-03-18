import csv
from collections import deque


class RoCEPacket:
    def __init__(self, timestamp, size, seq_number):
        """
        Initialize a RoCE packet with essential fields.

        :param timestamp: The timestamp of when the packet is generated.
        :param src_mac: The source MAC address (as a string or bytes).
        :param dst_mac: The destination MAC address (as a string or bytes).
        :param size: The size of the packet in bytes.
        :param rdma_op_code: The RDMA operation code (e.g., Read, Write, etc.).
        :param rdma_length: The RDMA data length, typically the size of the data being transferred in the RDMA operation.
        """
        self.timestamp = timestamp  # Time when the packet was generated
        # self.src_mac = src_mac  # Source MAC address
        # self.dst_mac = dst_mac  # Destination MAC address
        self.size = size  # Size of the packet in bytes
        # self.rdma_op_code = rdma_op_code  # RDMA Operation Code
        # self.rdma_length = rdma_length  # RDMA length (size of data in RDMA operation)
        self.seq_number = seq_number

    def __str__(self):
        return f"RoCE Packet (Time: {self.timestamp} us, Size: {self.size} bytes, Sequence number: {self.seq_number})"

    def __repr__(self):
        return self.__str__()

    @classmethod
    def from_csv(cls, csv_file):
        """
        Read packet data from a CSV file and return a list of RoCEPacket objects.

        :param csv_file: Path to the CSV file containing packet data.
        :return: A list of RoCEPacket objects created from the CSV file.
        """
        packets = deque()
        with open(csv_file, newline="") as f:
            reader = csv.reader(f)
            next(reader)  # Skip header row
            for row in reader:
                timestamp, size, seq_number = int(row[0]), int(row[1]), int(row[2])
                packets.append(cls(timestamp, size, seq_number))
        return packets


# --- Example Usage ---
if __name__ == "__main__":
    # Read packets from a CSV file
    csv_file = "packets.csv"
    packets = RoCEPacket.from_csv(csv_file)

    # Print out the loaded packets
    for packet in packets:
        print(packet)
