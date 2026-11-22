#!/bin/bash
# Report Halium kernel options missing from the defconfig (non-fatal).
cd "$1"
CFG=kernel/samsung/slte/arch/arm/configs/cyanogenmod_a8eltejv_defconfig
[ -x halium/halium-boot/check-kernel-config ] && halium/halium-boot/check-kernel-config "$CFG" || true
