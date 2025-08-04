import numpy as np
import matplotlib.pyplot as plt

NUM_SLOTS = 131072
MAX_RATE = 23437500000

slots = np.arange(1, NUM_SLOTS + 1)

# Floor mapping: range of rates that map to slot n
range_floor = MAX_RATE / slots - MAX_RATE / (slots + 1)

# Ceil mapping: range of rates that map to slot n
range_ceil = np.zeros_like(slots, dtype=float)
range_ceil[1:] = MAX_RATE / (slots[1:] - 1) - MAX_RATE / slots[1:]
range_ceil[0] = np.nan  # slot 1 has no lower slot

# Convert to kbps
range_floor /= 1e3
range_ceil /= 1e3

# Find boundaries of acceptable precision region (1 kbps < range < 1000 kbps)
# Find where range_floor crosses 1000 kbps (upper boundary)
upper_boundary_idx = np.where(range_floor <= 1000)[0]
if len(upper_boundary_idx) > 0:
    upper_boundary_slot = slots[upper_boundary_idx[0]]
else:
    upper_boundary_slot = None

# Find where range_floor crosses 1 kbps (lower boundary)
lower_boundary_idx = np.where(range_floor >= 1)[0]
if len(lower_boundary_idx) > 0:
    lower_boundary_slot = slots[lower_boundary_idx[-1]]
else:
    lower_boundary_slot = None

plt.figure(figsize=(10, 6))
plt.step(
    slots,
    range_floor,
    label="Floor: rate range per slot (kbps)",
    color="blue",
    where="post",
)
plt.step(
    slots,
    range_ceil,
    label="Ceil: rate range per slot (kbps)",
    color="green",
    where="post",
)

# Add boundary lines for acceptable precision region
if upper_boundary_slot:
    plt.axvline(
        upper_boundary_slot,
        color="red",
        linestyle="--",
        alpha=0.7,
        label=f"Upper boundary (slot {upper_boundary_slot}): 1 Mbps precision",
    )
if lower_boundary_slot:
    plt.axvline(
        lower_boundary_slot,
        color="orange",
        linestyle="--",
        alpha=0.7,
        label=f"Lower boundary (slot {lower_boundary_slot}): 1 kbps precision",
    )

# Highlight acceptable precision region
if upper_boundary_slot and lower_boundary_slot:
    plt.axvspan(
        upper_boundary_slot,
        lower_boundary_slot,
        alpha=0.1,
        color="green",
        label="Acceptable precision region",
    )

plt.xlabel("Calendar Slot")
plt.ylabel("Rate Range per Slot (kbps)")
plt.title(
    "Exclusive Rate Range Mapped to Each Calendar Slot\n(Acceptable Precision: 1 kbps - 1 Mbps)"
)
plt.xscale("log")
plt.yscale("log")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.show()

# Simple plot: Rate to slot translation (linear scale)
rates = np.linspace(178e3, MAX_RATE, 1000)  # 1 kbps to MAX_RATE
slots_floor = np.floor(MAX_RATE / rates)
slots_ceil = np.ceil(MAX_RATE / rates)

plt.figure(figsize=(4, 3))
plt.plot(slots_floor, rates / 1e6, color="blue")
# plt.plot(rates / 1e6, slots_ceil, label="Ceil rounding", color="green", linestyle="--")
plt.xlabel("Calendar Slot", fontsize=14)
plt.ylabel("Flow Rate (Mbps)", fontsize=14)
plt.title("Rate to Slot mapping", fontsize=15)
plt.grid(True, linestyle="--", alpha=0.5)
plt.xticks(rotation=30)
plt.tight_layout()
plt.show()

# Second plot: Precision loss margin as percentage
slot_rates_kbps = (MAX_RATE / slots) / 1e3  # Rate corresponding to each slot in kbps
precision_loss_floor = (range_floor / slot_rates_kbps) * 100  # Percentage loss
# precision_loss_ceil = (range_ceil / slot_rates_kbps) * 100  # Percentage loss

plt.figure(figsize=(8, 5))
plt.step(
    slots,
    precision_loss_floor,
    label="Worst-case precision loss (%)",
    color="blue",
    where="post",
)
"""
plt.step(
    slots,
    precision_loss_ceil,
    label="Ceil: precision loss (%)",
    color="green",
    where="post",
)
"""

# Add boundary lines for acceptable precision region (same slots as before)
if upper_boundary_slot:
    upper_loss = (1000 / (MAX_RATE / upper_boundary_slot / 1e3)) * 100
    plt.axvline(
        100,
        color="red",
        linestyle="--",
        alpha=0.7,
        label=f"Upper boundary (slot 100): 1% loss",
    )
    """
if lower_boundary_slot:
    lower_loss = (1 / (MAX_RATE / lower_boundary_slot / 1e3)) * 100
    plt.axvline(
        lower_boundary_slot,
        color="orange",
        linestyle="--",
        alpha=0.7,
        label=f"Lower boundary (slot {lower_boundary_slot}): {lower_loss:.4f}% loss",
    )
    """
# Highlight acceptable precision region
if upper_boundary_slot and lower_boundary_slot:
    plt.axvspan(
        100,
        131072,
        alpha=0.1,
        color="green",
        label="Acceptable precision region",
    )

plt.xlabel("Calendar Slot", fontsize=16)
plt.ylabel("Precision Loss (%)", fontsize=16)
plt.title(
    "Precision Loss Margin per Calendar Slot\n(Rate Range as % of Slot Rate)",
    fontsize=16,
)
plt.xscale("log")
plt.yscale("log")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.show()
