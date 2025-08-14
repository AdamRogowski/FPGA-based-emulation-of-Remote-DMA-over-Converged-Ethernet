# DCQCN Hardware Model

## Overview

This repository contains software and hardware models for a DCQCN (Data Center Quantized Congestion Notification) congestion control system designed for large-scale RoCEv2 network testing. The implementation supports emulation of up to 262,144 concurrent RDMA flows with individual rate control and congestion management.

## Repository Structure

### Software Models

The repository includes several Python-based simulation models:

- **DCQCN Reaction Point (RP)**

  - Implementation of the core DCQCN algorithm
  - Processing of congestion notifications
  - Rate adjustment calculations

- **Packet Inputs**

  - Generation tools for test traffic patterns

- **Scheduler Single Flow**

  - Simplified scheduler model for testing single flow behavior
  - Verification of basic rate control mechanisms

- **Scheduling Algorithm**
  - Implementation of calendar-based scheduling
  - Optimization models for slot calculations
  - Rate control algorithm verification

### Hardware Models

The repository contains VHDL implementations for FPGA deployment:

- **ModelSim Implementation**

  - **RP Module**: Reaction Point implementation in VHDL
  - **Scheduler**: Calendar-based rate control scheduler
  - **Wrapper**: Integration components
  - Memory models and testbenches

- **Quartus Implementation**
  - FPGA synthesis files for Intel/Altera platforms
  - Memory component definitions
  - Timing constraints
  - Project files for Quartus Prime

## Key Components

1. **Reaction Point (RP) Module**

   - Processes congestion notifications
   - Implements DCQCN rate adjustment algorithm
   - Maintains flow state information

2. **Calendar-Based Scheduler**

   - Enforces per-flow transmission rates
   - Implements an efficient calendar queue data structure
   - Provides deterministic packet scheduling

3. **Memory Organization**
   - Flow state storage
   - Rate information
   - Calendar queue implementation

## Implementation Details

- **Target Scale**: 262,144 concurrent flows
- **Hardware Target**: Intel/Altera FPGA (Stratix series)
- **Implementation Language**: VHDL for hardware, Python for models
- **Simulation**: ModelSim testbenches provided
- **Synthesis**: Quartus project files included

## Purpose

This implementation provides a hardware-based solution for testing RoCEv2 networks under realistic conditions with accurate congestion control behavior. It is particularly relevant for validating network equipment used in AI and HPC infrastructure that relies on high-performance RDMA networks.

## Usage

The repository contains both software models for algorithm verification and hardware models for FPGA implementation. The software models can be used to understand the behavior of the DCQCN algorithm and calendar-based scheduling, while the hardware models provide a path to physical implementation on FPGA platforms.
