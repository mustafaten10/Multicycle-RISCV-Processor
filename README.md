# Multicycle RISC-V Controller 🧠

This repository contains the hierarchical SystemVerilog implementation of a **Multicycle RISC-V Processor Controller**, based on the microarchitecture detailed in *Harris & Harris: Digital Design and Computer Architecture (RISC-V Edition)*.

## 🏗️ Architecture Overview

The system is designed with a multicycle approach, breaking down instruction execution into discrete micro-operations (Fetch, Decode, Execute, Memory, Writeback). This specific repository focuses on the **Control Unit** which governs the entire processor.

The core is separated into the following components within the `controller.sv` file:

1. **Main FSM (`maindec`)**: A Finite State Machine with 11 states that correctly transitions through the execution phases and drives the primary datapath control signals.
2. **ALU Decoder (`aludec`)**: Processes the `ALUOp` coming from the Main FSM along with the instruction's `funct3`/`funct7` fields to generate the specific `ALUControl` signal for the datapath.
3. **Instruction Decoder (`instrdec`)**: Decodes the immediate format (`ImmSrc`) based on the incoming instruction opcode.

## 🗂️ File Structure

| File | Description |
|---|---|
| `controller.sv` | The main top-level file containing the Main FSM, ALU Decoder, and Instruction Decoder logic. |
| `controller_testbench.sv`| An automated testbench designed to independently test the FSM transitions and verify correct control signal outputs against known test vectors. |

## 🧪 Simulation & Testing

You can run the included `controller_testbench.sv` on any standard SystemVerilog simulator (e.g., QuestaSim, ModelSim, or Vivado) by setting it as the top-level simulation module. The testbench feeds specific opcodes into the controller and verifies if the correct path and signals are generated for various RISC-V instructions (such as `lw`, `sw`, R-type, `beq`, `jal`).
