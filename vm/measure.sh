#!/bin/bash
# Run inside the VM as user arch (over ssh). Measures RSS (sum over process tree, MiB) after idle.
export XDG_RUNTIME_DIR=/run/user/$(id -u) LIBSEAT_BACKEND=seatd
mkdir -p ~/.config/hypr ~/.config/sway
cat > ~/.config/hypr/hyprland.conf <<'H'
animations { enabled = false }
decoration { blur { enabled = false }
  shadow { enabled = false }
  rounding = 0 }
general { gaps_in = 0
  gaps_out = 0 }
misc { vfr = true
  disable_hyprland_logo = true }
H
printf 'output * bg #222222 solid_color\n' > ~/.config/sway/config
treerss(){ local all=$(pstree -T -p $1 | grep -oE "\([0-9]+\)" | tr -d "()"); local s=0 n=0; for p in $all; do v=$(sudo awk "/^Pss:/{print \$2}" /proc/$p/smaps_rollup 2>/dev/null); [[ -n $v ]] && { s=$((s+v)); n=$((n+1)); }; done; echo "$((s/1024)) MiB PSS ($n procs)"; }
mem(){ free -m | awk '/Mem/{print "used="$3"MiB avail="$7"MiB"} /Swap/{print "swap_used="$3"MiB"}' | paste -sd' '; }
WAIT=${WAIT:-60}
comp(){ name=$1; shift
  echo "== $name"; echo "baseline: $(mem)"
  "$@" > /tmp/$name.log 2>&1 & cp=$!; sleep $WAIT
  pgrep -x Hyprland >/dev/null || pgrep -x sway >/dev/null || { echo "compositor not running"; tail -5 /tmp/$name.log; return; }
  export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -m1 -E '^wayland-[0-9]+$')
  echo "renderer: $(grep -ioE 'llvmpipe[^,]*|softpipe|pixman|GL_RENDERER.*' /tmp/$name.log | head -1)"
  echo "compositor idle: $(treerss $cp) | $(mem)"
  if [[ ${APPS:-0} == 1 ]]; then
    MOZ_ENABLE_WAYLAND=1 firefox --new-instance --profile $(mktemp -d) https://en.wikipedia.org/wiki/Arch_Linux https://archlinux.org https://github.com/basecamp/omarchy >/dev/null 2>&1 & fp=$!
    sleep $((WAIT*3)); echo "firefox fresh profile, 3 tabs: $(treerss $fp) | $(mem)"; kill $fp; sleep 10; pkill -9 firefox
    qutebrowser --temp-basedir https://en.wikipedia.org/wiki/Arch_Linux >/dev/null 2>&1 & qp=$!
    sleep $((WAIT*2)); echo "qutebrowser 1 tab: $(treerss $qp) | $(mem)"; kill $qp; sleep 10; pkill -9 -f qutebrowser
  fi
  echo "compositor after apps: $(treerss $cp)"
  kill $cp; sleep 5; kill -9 $cp 2>/dev/null; sleep 3
}
case ${1:-all} in
  hypr) comp hyprland Hyprland ;;
  sway) comp sway sway ;;
  sway-pixman) WLR_RENDERER=pixman comp sway-pixman sway ;;
  codex) script -qfc "timeout 30 codex" /dev/null </dev/zero >/dev/null & sleep 20; echo "codex (unauthenticated TUI start): $(ps -C codex -o rss= | awk '{s+=$1}END{printf "%.0f MiB",s/1024}')"; wait ;;
esac
