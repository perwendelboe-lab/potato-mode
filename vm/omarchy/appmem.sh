#!/bin/bash
# usage: appmem.sh <name-pattern> <cmd...>; PSS of matching processes after 25 s (MiB)
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
pat=$1; shift
"$@" >/dev/null 2>&1 &
sleep 25
tot=0; for p in $(pgrep -f "$pat"); do k=$(sudo awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null); tot=$((tot+${k:-0})); done
echo "$pat: $((tot/1024)) MiB PSS ($(pgrep -fc "$pat") procs); free used $(free -m | awk '/Mem:/{print $3}') MiB"
pkill -f "$pat"; sleep 3
