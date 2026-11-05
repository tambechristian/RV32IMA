# Zulu A7 RV32IMA Platform

This directory defines the Zulu A7 Linux platform contract for the RV32IMA
core and starts the external SDR SDRAM and OpenSBI support.

The fitted device marking is `XC7A35T-2CPG236I`. Select the installed Vivado
part `xc7a35tcpg236-2`; Vivado does not expose a `xc7a35tcpg236-2I` part name.

## Hardware contract

| Region | Base | Size |
|---|---:|---:|
| Boot ROM | `0x00000000` | 64 KiB |
| ACLINT/CLINT | `0x02000000` | 64 KiB |
| PLIC | `0x0C000000` | 4 MiB |
| NS16550A UART | `0x10000000` | 4 KiB |
| SDRAM | `0x80000000` | 64 MiB |

The intended CPU clock is 100 MHz. The ACLINT `mtime` clock contract is
1 MHz. UART registers are 32-bit accesses spaced four bytes apart
(`reg-shift = 2`), and UART interrupt source 1 is routed through the PLIC.

The SDRAM controller implements a 32-bit Wishbone slave over the board's
`AS4C32M16SB-7TCN` x16 SDR SDRAM. Each Wishbone access uses two SDRAM
halfword operations. The current XDC contains the routed SDRAM pins only.

## OpenSBI layout

- OpenSBI `fw_jump`: `0x80000000`
- Linux entry address: `0x80400000`
- Device tree relocation address: `0x83E00000`

Build the generic OpenSBI platform from PowerShell:

```powershell
.\opensbi\build_opensbi.ps1 -OpenSbiRoot C:\path\to\opensbi -UseLlvm
```

The script requires GNU make and `dtc`. Modern OpenSBI requires a linker
that can create PIE executables, so LLVM/LLD with `-UseLlvm` is recommended.
For a compatible GNU toolchain, omit `-UseLlvm` and use `-CrossCompile` to
select its compiler prefix.

This flow was validated with OpenSBI v1.9 commit
`cbf9f6734dd85a982c63e3cb5db7ffe09da839ca` and LLVM 22.1.8. On native
Windows, the build script includes `windows-opensbi.mk` to place archive
inputs in response files and avoid the Windows command-line length limit.
Generated firmware under `opensbi/build/` is intentionally not committed.

## Buildroot

The `buildroot` directory is a `BR2_EXTERNAL` tree for Buildroot 2026.08.1.
It builds an RV32IMA musl/BusyBox system with an initramfs linked into Linux
6.18.7, the Zulu device tree, and an OpenSBI 1.9 payload image.

From Ubuntu WSL:

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export EXTERNAL=/mnt/c/Users/tambe/Documents/Electronics/Cmod_A7-35T/VS_code/RV32IMA/zulu_a7/buildroot
make -C ~/buildroot O=~/build/zulu-a7-rv32ima \
    BR2_EXTERNAL="$EXTERNAL" zulu_a7_rv32ima_defconfig
make -C ~/buildroot O=~/build/zulu-a7-rv32ima
```

Final images are written to `~/build/zulu-a7-rv32ima/images`. The
`fw_payload.bin` image contains OpenSBI at `0x80000000`, Linux at
`0x80400000`, and the Buildroot initramfs. OpenSBI places the embedded FDT at
`0x83E00000` before entering Linux.

The post-image hook rebuilds `fw_payload.bin` after Buildroot links the final
initramfs into `Image`, ensuring OpenSBI embeds the final kernel rather than
the earlier pre-initramfs image.

The Linux-only `PATH` is required because Buildroot rejects the Windows paths
with spaces that WSL normally appends to the environment.

## Current status

Implemented:

- OpenSBI CPU contract (`mhartid`, machine identification CSRs, reset vector)
- Zulu memory-map constants
- RV32IMA device tree
- OpenSBI build script
- Buildroot RV32IMA Linux/initramfs configuration
- Wishbone SDR SDRAM controller, behavioral testbench, and routed SDRAM pins

Still required before Linux can run on hardware:

- 12 MHz input clock pin and MMCM/reset logic
- complete clock, reset, UART, and timing constraints
- boot ROM and firmware-loading path
- Wishbone address decoder/interconnect
- ACLINT/CLINT, PLIC, and NS16550A-compatible UART RTL
- integrated Zulu top-level simulation and Vivado implementation

The DTS describes the final hardware contract. Do not boot this DTS until
the missing memory-mapped peripherals implement that contract.
