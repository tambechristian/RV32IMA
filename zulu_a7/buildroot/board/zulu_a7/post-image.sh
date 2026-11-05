#!/bin/sh
set -eu

images_dir="$1"
output_dir="${O:?Buildroot output directory is not set}"
opensbi_dir="${BUILD_DIR:?Buildroot build directory is not set}/opensbi-1.9"
opensbi_output_dir="${opensbi_dir}/build"
cross_compile="${output_dir}/host/bin/riscv32-buildroot-linux-musl-"

make -C "${opensbi_dir}" O="${opensbi_output_dir}" clean
make -C "${opensbi_dir}" -j"${PARALLEL_JOBS:-1}" \
	O="${opensbi_output_dir}" \
	CROSS_COMPILE="${cross_compile}" \
	PLATFORM=generic \
	PLATFORM_RISCV_XLEN=32 \
	PLATFORM_RISCV_ISA=rv32ima_zicsr_zifencei \
	PLATFORM_RISCV_ABI=ilp32 \
	FW_TEXT_START=0x80000000 \
	FW_PAYLOAD_PATH="${images_dir}/Image" \
	FW_PAYLOAD_OFFSET=0x00400000 \
	FW_PAYLOAD_FDT_ADDR=0x83e00000 \
	FW_FDT_PATH="${images_dir}/zulu_a7_rv32ima.dtb"

for firmware in dynamic jump payload; do
	for format in bin elf; do
		install -m 0644 \
			"${opensbi_output_dir}/platform/generic/firmware/fw_${firmware}.${format}" \
			"${images_dir}/fw_${firmware}.${format}"
	done
done
