#!/bin/bash
# Usage: stub-kconfig.sh <kernel dir> <defconfig>. Creates empty Kconfig stubs for files the stripped Samsung tree references but lacks.
cd "$1"; mkdir -p /tmp/kout-stub
export ARCH=arm ANDROID_MAJOR_VERSION=n
for i in $(seq 1 300); do
  out=$(make O=/tmp/kout-stub "$2" 2>&1) && { echo "defconfig OK after $((i-1)) stubs"; exit 0; }
  f=$(echo "$out" | grep -o "can.t open file \"[^\"]*\"" | head -1 | cut -d\" -f2)
  [ -z "$f" ] && { echo "$out" | tail -15; exit 1; }
  echo "stub $f"; mkdir -p "$(dirname "$f")"; touch "$f"
done
exit 1
