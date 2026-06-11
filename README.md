# ML-KEM Hash Modules (DSD Project)

## Overview

This repository contains the hardware implementation and verification of cryptographic hash modules used in the ML-KEM (Module-Lattice Key Encapsulation Mechanism) framework, a post-quantum cryptographic standard designed to remain secure against quantum computer attacks.

The project was developed as part of the Digital System Design (DSD) course and focuses on implementing and analyzing the following cryptographic primitives:

* Keccak
* SHA-256
* SHA-512
* SHAKE128

These algorithms form essential building blocks in modern cryptographic systems and are heavily used in post-quantum cryptography, including ML-KEM.

---

## Background

### ML-KEM

ML-KEM (Module-Lattice Key Encapsulation Mechanism) is a NIST-standardized post-quantum cryptographic algorithm derived from Kyber. It enables secure key exchange mechanisms that remain resistant to attacks from both classical and quantum computers.

### Keccak

Keccak is a cryptographic permutation function and serves as the foundation of SHA-3 and SHAKE. It uses a sponge construction consisting of:

1. Absorb Phase
2. Squeeze Phase

The sponge operates on a 1600-bit internal state and repeatedly applies the Keccak-f permutation.

### SHA-256

SHA-256 is a member of the SHA-2 family and generates a fixed 256-bit digest. It is widely used for integrity verification, digital signatures, and blockchain applications.

### SHA-512

SHA-512 is another SHA-2 family member that produces a 512-bit hash output, offering increased security and collision resistance.

### SHAKE128

SHAKE128 is an Extendable Output Function (XOF) based on Keccak. Unlike conventional hash functions, it can generate outputs of arbitrary length, making it suitable for randomness generation and post-quantum cryptographic protocols.

---

## Project Architecture

The project includes:

* RTL design of SHA-256
* RTL design of SHA-512
* RTL design of SHAKE128
* Keccak core implementation
* Functional verification using testbenches
* Synthesis reports
* Timing analysis
* Power analysis

---

## Repository Structure

```text
├── keccak/
│   ├── rtl/
│   ├── testbench/
│
├── sha256/
│   ├── rtl/
│   ├── testbench/
│
├── sha512/
│   ├── rtl/
│   ├── testbench/
│
├── shake128/
│   ├── rtl/
│   ├── testbench/
│
├── reports/
│   ├── area/
│   ├── timing/
│   ├── power/
│
└── docs/
```

---

## Results

The following metrics were evaluated for each implemented module:

### Area Analysis

* Gate count
* Cell utilization
* Resource consumption

### Timing Analysis

* Critical path delay
* Setup and hold timing
* Maximum operating frequency

### Power Analysis

* Dynamic power consumption
* Leakage power
* Total power usage

Waveform simulations were also generated to verify functional correctness.

---

## Tools Used

* Verilog HDL
* Digital System Design Methodology
* RTL Simulation Tools
* Logic Synthesis Tools
* Timing Analysis Tools
* Power Estimation Tools

---

## References

* https://github.com/abendezu10/SHA3-256-Verilog
* https://github.com/kiernandez/SHA3-512
* https://github.com/zBlxst/SHAKE128

---

## Future Work

* Complete ML-KEM hardware integration
* FPGA deployment and benchmarking
* Performance optimization for area and power
* Support for additional SHA-3 variants
* Hardware acceleration for post-quantum cryptographic systems
