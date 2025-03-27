# APB-Protocol
This project implements an APB (Advanced Peripheral Bus) Slave interface in Verilog, designed with a state machine-based control logic for efficient communication with an APB Master. The interface ensures proper sequencing of read and write transactions, adhering to the AMBA APB protocol. To validate its functionality, a comprehensive testbench was developed, incorporating key verification components.

Key Features:
State Machine-Based Control: Ensures correct sequencing of APB transactions.

PREADY & PSLVERR Signals: Implemented for managing transfer readiness and error handling.

Testbench for Verification: Includes a structured testbench with:

Generator: Stimulus generation for various test scenarios.

Driver: Drives transactions to the APB interface.

Monitor: Captures and checks APB transactions.

Scoreboard: Compares expected and actual results for validation.

This project showcases a structured approach to APB protocol implementation and functional verification, making it suitable for SoC design applications.
