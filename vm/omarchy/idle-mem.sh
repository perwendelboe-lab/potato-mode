#!/bin/bash
# Run in the guest: system memory + top PSS processes (sudo for non-dumpable ones).
free -m
zramctl 2>/dev/null
echo "--- top PSS (MiB) / swap (MiB)"
for p in /proc/[0-9]*; do
  n=$(cat $p/comm 2>/dev/null) || continue
  sudo awk -v n="$n" '/^Pss:/{pss=$2} /^Swap:/{sw=$2} END{if (pss>0) printf "%6d %6d %s\n", pss/1024, sw/1024, n}' $p/smaps_rollup 2>/dev/null
done | sort -rn | head -${1:-15}
echo "--- totals"
for p in /proc/[0-9]*; do sudo awk '/^Pss:/{pss=$2} /^Swap:/{sw=$2} END{print pss, sw}' $p/smaps_rollup 2>/dev/null; done | awk '{p+=$1; s+=$2} END{printf "sum PSS %d MiB, sum swapped %d MiB\n", p/1024, s/1024}'
