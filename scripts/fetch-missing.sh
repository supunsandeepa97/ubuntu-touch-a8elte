#!/bin/bash
# Usage: fetch-missing.sh <kernel dir> <make args...>
# The Samsung kernel repo has many stock Linux 3.10 files deleted. Re-fetch any missing file from mainline v3.10 and retry.
K="$1"; shift
cd "$K"
export ARCH=arm ANDROID_MAJOR_VERSION=n
for i in $(seq 1 200); do
  out=$(make "$@" 2>&1) && { echo "make OK after $((i-1)) fetches"; exit 0; }
  p=$(echo "$out" | grep -oE "No rule to make target [\`']([^'\`]*)['\`]" | head -1 | sed -E "s/.*[\`']([^'\`]*)['\`]/\1/")
  [ -z "$p" ] && p=$(echo "$out" | grep -oE "[^ :]+: No such file or directory" | head -1 | sed 's/: No such.*//')
  p=${p#$PWD/}; p=${p#$K/}
  if [ -z "$p" ]; then echo "$out" | tail -25; exit 1; fi
  mkdir -p "$(dirname "$p")"
  if curl -sfL "https://raw.githubusercontent.com/torvalds/linux/v3.10/$p" -o "$p"; then echo "fetched $p"
  else rm -f "$p"; echo "cannot fetch $p"; echo "$out" | tail -15; exit 1; fi
done
exit 1
