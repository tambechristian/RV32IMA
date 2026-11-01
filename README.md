# RV32IMA Linux-Oriented Processor Core

This directory contains a standalone RV32IMA processor implementation for the
Cmod A7-35T. It preserves the M, A, supervisor-mode, and Sv32 features of the
RV32IMAC design but deliberately does not implement the C compressed extension.
It does not replace the established RV32I or RV32IMAC source trees.

## Implemented architecture

- RV32I base integer instruction set
- RV32M iterative multiply and divide
- RV32A word atomics:
  - `LR.W` and `SC.W`
  - `AMOSWAP.W`, `AMOADD.W`, `AMOXOR.W`, `AMOAND.W`, and `AMOOR.W`
  - signed and unsigned `AMOMIN.W` and `AMOMAX.W`
- Machine, supervisor, and user privilege modes
- Machine and supervisor trap entry and return
- Exception and interrupt delegation
- Machine and supervisor CSRs
- RV32 low/high `cycle`, `time`, and `instret` counter CSRs
- Zicsr CSR-instruction behavior and `FENCE.I`
- Sv32 virtual memory with:
  - two-level page-table walks
  - 4 KiB pages and 4 MiB superpages
  - an eight-entry TLB
  - U/S, SUM, MXR, and R/W/X permission checks
  - hardware accessed/dirty PTE updates
  - full TLB flush on `SFENCE.VMA`
- A unified physical-memory interface and Wishbone Classic wrapper
- Halt, resume, single-step, PC, and integer-register debug access

The instruction alignment is 32 bits (`IALIGN=32`). Taken branches, `JAL`, and
`JALR` trap if their target is not four-byte aligned. MISA.C is clear and
compressed encodings trap as illegal instructions.

The core traps naturally aligned violations rather than implementing
misaligned load, store, or atomic emulation. Atomic acquire/release bits are
accepted; the current single-core, uncached memory path serializes accesses.

## Main modules

- `rv32ima_core.sv`: processor, CSRs, privilege modes, traps, and virtual-memory
  request path
- `sv32_mmu.sv`: TLB and Sv32 page-table walker
- `rv32_muldiv.sv`: iterative RV32M execution unit
- `rv32ima_wb.sv`: Wishbone-facing core wrapper
- `rv32ima_pkg.sv`: architectural constants

The native physical-memory request remains asserted until `memory_ready`.
`memory_error` is sampled with `memory_ready`. The Wishbone wrapper maps this
handshake to `CYC`, `STB`, `ACK`, and `ERR`.

## Software compilation

Compile software without the C extension:

```text
-march=rv32ima_zicsr_zifencei -mabi=ilp32
```

Do not use `-march=rv32imac`; this core does not fetch or execute 16-bit
instructions.

## Run the regressions

Place the OSS CAD Suite `bin` directory on `PATH`, then run:

```powershell
.\RV32IMA\run_tests.ps1
```

The regressions cover:

- all eight RV32M operations, signed corner cases, divide by zero, and overflow
- all standard RV32A word operations, including successful and failed `SC.W`
- MISA without the C bit and the RV32 high-half time CSR
- rejection of a compressed instruction encoding
- four-byte control-flow target alignment
- Sv32 bypass, 4 KiB translation, superpages, TLB hits, execute permissions,
  and accessed/dirty updates
- interrupt eligibility and delegation priority
- M-mode to S-mode entry, delegated S-mode `ECALL`, trap CSRs, and `SRET`

## Current validation status

- All eight directed RTL regressions pass.
- All 72 applicable tests from `riscv-arch-test` release 3.9.1 pass:
  39 I, 8 M, 9 A, 1 Zifencei, and 15 privilege tests.
- A 200-seed random differential campaign passed 200/200 programs, comparing
  the RTL against an independent architectural model across 92,354 executed
  operations and all implemented base I/M/A instruction families.

The architecture-test result is a legacy release 3.9.1 execution, not current
ACT4 certification. The random campaign covers M-mode integer execution;
directed tests provide the S-mode, interrupt, and Sv32 coverage.

To synthesize the standalone Wishbone core for the Cmod A7-35T:

```powershell
vivado -mode batch -source RV32IMA\synth_core.tcl
```

## Linux platform requirements

This is a Linux-oriented processor core, not yet a complete Linux-bootable
Cmod A7 system. A practical Linux platform still needs:

- substantially more RAM than the onboard 512 KiB SRAM
- a CLINT-compatible machine timer and software-interrupt block
- a PLIC-compatible external interrupt controller
- boot firmware such as OpenSBI and a matching device tree
- a UART console and a Linux-accessible storage or network device
- physical memory protection (PMP) if required by the selected OpenSBI build

The existing Cmod SoC peripherals can be reused behind the Wishbone wrapper,
but their addresses and interrupt topology must be described consistently to
firmware and the device tree. The established RV32I build flow should remain
unchanged until those platform components and adequate external memory are
integrated.
