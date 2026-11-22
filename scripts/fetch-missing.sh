#!/bin/bash
# Usage: fetch-missing.sh <kernel dir> <make args...>
# The Samsung kernel repo has many stock Linux 3.10 files deleted. Copy any missing file from mainline v3.10 and retry.
K="$1"; shift
MAIN="${MAINLINE_DIR:-/tmp/linux-3.10}"
if [ ! -d "$MAIN/arch" ]; then
  for try in 1 2 3 4 5; do
    rm -rf "$MAIN"; mkdir -p "$MAIN"
    if curl -fL --retry 5 --retry-delay 3 -o /tmp/linux-3.10.tar.gz https://codeload.github.com/torvalds/linux/tar.gz/refs/tags/v3.10        && tar xzf /tmp/linux-3.10.tar.gz -C "$MAIN" --strip-components=1 && [ -d "$MAIN/arch" ]; then break; fi
    echo "mainline download failed (try $try)"; sleep 5
  done
  rm -f /tmp/linux-3.10.tar.gz
fi
cd "$K"
export ARCH=arm ANDROID_MAJOR_VERSION=n KCFLAGS="${KCFLAGS--Wno-error -fno-pie}"
last=""
for i in $(seq 1 400); do
  out=$(make "$@" 2>&1) && { echo "make OK after $((i-1)) fetches"; exit 0; }
  p=$(echo "$out" | grep -oE "No rule to make target [\`']([^'\`]*)['\`]" | head -1 | sed -E "s/.*[\`']([^'\`]*)['\`]/\1/")
  [ -z "$p" ] && p=$(echo "$out" | grep -oE "[^ :]+: No such file or directory" | head -1 | sed 's/: No such.*//')
  p=$(echo "$p" | tr -d "'\`")
  p=${p#$PWD/}; p=${p#$K/}
  if [ -z "$p" ]; then echo "$out" | tail -25; exit 1; fi
  if [[ "$p" != */* ]]; then
    # bare header name: prefer the folder of the file that includes it
    inc=$(echo "$out" | grep -E "fatal error: $p: No such" | head -1 | cut -d: -f1)
    inc=${inc#$PWD/}; inc=${inc#$K/}
    if [ -n "$inc" ] && [ -f "$MAIN/$(dirname "$inc")/$p" ]; then
      p="$(dirname "$inc")/$p"
    else
      f=$(cd "$MAIN" && find arch include -name "$p" | head -1); [ -n "$f" ] && p="$f"
    fi
  fi
  if [ "$p" = "$last" ]; then echo "loop on $p"; echo "$out" | tail -15; exit 1; fi
  last="$p"
  got=0
  for cand in "$p" "${p%.o}.c" "${p%.o}.S"; do
    if [ -f "$MAIN/$cand" ]; then mkdir -p "$(dirname "$cand")"; cp "$MAIN/$cand" "$cand"; echo "fetched $cand"; got=1; break; fi
  done
  if [ $got = 0 ] && [[ "$(basename "$p")" != *.* ]]; then mkdir -p "$p"; echo "made dir $p"; got=1; fi
  [ $got = 1 ] || { echo "cannot fetch $p"; echo "$out" | tail -15; exit 1; }
done
exit 1
