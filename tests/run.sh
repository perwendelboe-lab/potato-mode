#!/bin/bash
# Test harness: runs potato-mode against a fake HOME, fake system root and stubbed
# shellcheck disable=SC2016,SC2001  # stub scripts are written with literal $vars on purpose
# pacman/omarchy/sudo, so nothing on the real machine is touched.
set -uo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
pass=0
fail=0

ok() { pass=$((pass + 1)); echo "ok   - $1"; }
not_ok() { fail=$((fail + 1)); echo "FAIL - $1"; [[ -n ${2:-} ]] && echo "$2" | sed 's/^/       /'; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else not_ok "$name"; fi; }

setup() {
  T=$(mktemp -d)
  export HOME=$T/home XDG_CONFIG_HOME=$T/home/.config XDG_DATA_HOME=$T/home/.local/share XDG_STATE_HOME=$T/home/.local/state
  export POTATO_SYSROOT=$T/root PACDB=$T/pacdb STUBLOG=$T/stub.log
  mkdir -p "$POTATO_SYSROOT/var/lib/pacman/sync" && touch "$POTATO_SYSROOT/var/lib/pacman/sync/core.db"
  mkdir -p "$POTATO_SYSROOT/var/lib/sddm" && printf '[Last]\nSession=/usr/local/share/wayland-sessions/omarchy.desktop\nUser=u\n' >"$POTATO_SYSROOT/var/lib/sddm/state.conf"
  mkdir -p "$POTATO_SYSROOT/etc/systemd"
  mkdir -p "$HOME/.config/hypr" "$XDG_DATA_HOME/applications" "$T/stubs" "$POTATO_SYSROOT/usr/lib/firefox" "$POTATO_SYSROOT/etc/sddm.conf.d"
  printf 'chromium\nobsidian\ndocker\nevince\nfirefox\nhyprland\n' >"$PACDB"
  printf -- '-- user hyprland.lua\nrequire("default.hypr.omarchy")\n' >"$HOME/.config/hypr/hyprland.lua"
  printf '[Desktop Entry]\nName=HEY\nExec=omarchy-launch-webapp https://app.hey.com\n' >"$XDG_DATA_HOME/applications/HEY.desktop"
  mkdir -p "$HOME/.mozilla/firefox/abc.default"
  printf '[Profile0]\nName=default\nIsRelative=1\nPath=abc.default\n' >"$HOME/.mozilla/firefox/profiles.ini"
  printf '[Autologin]\nUser=pwn\nSession=hyprland-uwsm.desktop\n' >"$POTATO_SYSROOT/etc/sddm.conf.d/autologin.conf"
  cat >"$T/stubs/pacman" <<'S'
#!/bin/bash
echo "pacman $*" >>"$STUBLOG"
case $1 in
  -Q) grep -qxF -- "${@: -1}" "$PACDB" ;;
  -S) shift; for p in "$@"; do [[ $p == -* ]] || echo "$p" >>"$PACDB"; done ;;
  -Rns) p=${@: -1}; grep -vxF -- "$p" "$PACDB" >"$PACDB.t"; mv "$PACDB.t" "$PACDB" ;;
esac
S
  cat >"$T/stubs/sudo" <<'S'
#!/bin/bash
echo "sudo $*" >>"$STUBLOG"
exec "$@"
S
  printf '#!/bin/bash\necho stable\n' >"$T/stubs/omarchy-channel-current"
  printf '#!/bin/bash\necho "${FAKE_OMARCHY_VERSION:-4.0.4-1}"\n' >"$T/stubs/omarchy-version"
  for c in xdg-mime xdg-settings omarchy-notification-send gum; do printf '#!/bin/bash\necho "%s $*" >>"$STUBLOG"\n' "$c" >"$T/stubs/$c"; done
  chmod +x "$T/stubs/"*
  export PATH="$T/stubs:$repo/bin:/usr/bin:/bin"
  export POTATO_EGLINFO_OUTPUT=$repo/tests/fixtures/eglinfo-gles2.txt
}
teardown() { rm -rf "$T"; unset POTATO_COMPOSITOR; }

snapshot() { (cd "$T" && find home root pacdb -type f ! -name applied-at -exec md5sum {} + | sort); }

# --- detect
for f in gles2:sway gles3:hyprland llvmpipe:sway; do
  out=$(POTATO_EGLINFO_OUTPUT=$repo/tests/fixtures/eglinfo-${f%%:*}.txt "$repo/bin/omarchy-potato-detect")
  check "detect ${f%%:*} -> ${f##*:}" [ "$out" = "${f##*:}" ]
done
check "detect honours POTATO_COMPOSITOR" [ "$(POTATO_COMPOSITOR=hyprland "$repo/bin/omarchy-potato-detect")" = hyprland ]

# --- check
setup
check "check passes on stable 4.0.4" "$repo/bin/omarchy-potato-check" 
FAKE_OMARCHY_VERSION=4.1.0-1 "$repo/bin/omarchy-potato-check" >/dev/null 2>&1; check "check rejects 4.1.0" [ $? -ne 0 ]
FAKE_OMARCHY_VERSION=4.1.0-1 "$repo/bin/omarchy-potato-check" --force-version >/dev/null 2>&1; check "check --force-version allows 4.1.0" [ $? -eq 0 ]
printf '#!/bin/bash\necho edge\n' >"$T/stubs/omarchy-channel-current"
"$repo/bin/omarchy-potato-check" >/dev/null 2>&1; check "check rejects edge channel" [ $? -ne 0 ]
teardown

# --- dry run changes nothing
setup
before=$(snapshot)
out=$("$repo/bin/omarchy-potato-enable" --dry-run 2>&1)
check "dry-run exits cleanly" [ $? -eq 0 ]
check "dry-run changes no files" [ "$before" = "$(snapshot)" ]
grep -q 'DRY-RUN: .*pacman -Rns\|DRY-RUN: omarchy-pkg-drop\|DRY-RUN: sudo pacman -Rns' <<<"$out"; check "dry-run shows package removal" [ $? -eq 0 ]
teardown

# --- real apply (sway path) + idempotency + revert
setup
before=$(snapshot)
out=$("$repo/bin/omarchy-potato-enable" --yes 2>&1); rc=$?
check "enable (sway) succeeds" [ $rc -eq 0 ] || echo "$out"
check "chromium dropped" bash -c "! grep -qx chromium '$PACDB'"
check "abiword added" grep -qx abiword "$PACDB"
check "greeter preselects sway" grep -qx Session=/usr/local/share/wayland-sessions/potato-sway.desktop "$POTATO_SYSROOT/var/lib/sddm/state.conf"
check "sway extras added" grep -qx swaylock "$PACDB"
check "hyprland kept (Omarchy hard dep)" grep -qx hyprland "$PACDB"
check "hyprland.lua requires hypr.potato" grep -q 'require("hypr.potato")' "$HOME/.config/hypr/hyprland.lua"
check "potato.lua written" test -f "$HOME/.config/hypr/potato.lua"
check "sway config written" test -f "$HOME/.config/sway/config"
check "sddm greeter override" grep -q weston "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato.conf"
check "autologin session -> potato sway" grep -qx 'Session=potato-sway.desktop' "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato-session.conf"
check "potato sway session sets QT_QUICK_BACKEND=software" grep -qx 'Exec=env QT_QUICK_BACKEND=software sway' "$POTATO_SYSROOT/usr/local/share/wayland-sessions/potato-sway.desktop"
check "journald cap drop-in" grep -qx 'SystemMaxUse=50M' "$POTATO_SYSROOT/etc/systemd/journald.conf.d/90-potato.conf"
check "firefox bfcache/prefetch prefs" bash -c "grep -q 'max_total_viewers\", 0' '$HOME/.mozilla/firefox/abc.default/user.js' && grep -q 'prefetch-next\", false' '$HOME/.mozilla/firefox/abc.default/user.js' && grep -q 'prefetch-next' '$POTATO_SYSROOT/usr/lib/firefox/defaults/pref/potato-mode.js'"
check "zram config written (none existed)" test -f "$POTATO_SYSROOT/etc/systemd/zram-generator.conf.d/90-potato.conf"
check "firefox user.js tab unloading" grep -q 'browser.tabs.unloadOnLowMemory' "$HOME/.mozilla/firefox/abc.default/user.js"
check "firefox software render on sway" grep -q 'gfx.webrender.software' "$HOME/.mozilla/firefox/abc.default/user.js"
check "firefox system prefs" grep -q '^pref("dom.ipc.processCount", 2);' "$POTATO_SYSROOT/usr/lib/firefox/defaults/pref/potato-mode.js"
check "web app -> firefox tab" grep -qx 'Exec=omarchy-potato-webapp https://app.hey.com' "$XDG_DATA_HOME/applications/HEY.desktop"
check "menu extension valid JSON with potato entry" bash -c "jq -e '.potato' '$XDG_CONFIG_HOME/omarchy/extensions/omarchy-menu.jsonc' >/dev/null"
check "default browser set via mimeapps (4.0.5-safe)" grep -q "xdg-settings set default-web-browser firefox.desktop" "$STUBLOG"
check "post-update hook installed" test -x "$XDG_CONFIG_HOME/omarchy/hooks/post-update.d/potato-mode"
after1=$(snapshot)
"$repo/bin/omarchy-potato-apply" --yes --quiet >/dev/null 2>&1
check "second apply is a no-op (idempotent)" [ "$after1" = "$(snapshot)" ]
check "marker block appears once" [ "$(grep -c 'potato-mode:begin' "$HOME/.config/hypr/hyprland.lua")" -eq 1 ]
# simulate an Omarchy update restoring chromium and the stock web app
echo chromium >>"$PACDB"
printf '[Desktop Entry]\nName=HEY\nExec=omarchy-launch-webapp https://app.hey.com\n' >"$XDG_DATA_HOME/applications/HEY.desktop"
bash "$XDG_CONFIG_HOME/omarchy/hooks/post-update.d/potato-mode" >"$T/hook.log" 2>&1
check "hook re-drops chromium after update" bash -c "! grep -qx chromium '$PACDB'"
check "hook re-points web app" grep -q omarchy-potato-webapp "$XDG_DATA_HOME/applications/HEY.desktop"
# hook with an untested Omarchy version: configs yes, packages no
echo chromium >>"$PACDB"
FAKE_OMARCHY_VERSION=4.2.0-1 bash "$XDG_CONFIG_HOME/omarchy/hooks/post-update.d/potato-mode" >/dev/null 2>&1
check "hook leaves packages alone on untested version" grep -qx chromium "$PACDB"
"$repo/bin/omarchy-potato-disable" --yes >/dev/null 2>&1; rc=$?
check "disable succeeds" [ $rc -eq 0 ]
check "disable restores hyprland.lua" bash -c "! grep -q potato '$HOME/.config/hypr/hyprland.lua'"
check "disable restores web app" grep -qx 'Exec=omarchy-launch-webapp https://app.hey.com' "$XDG_DATA_HOME/applications/HEY.desktop"
check "disable removes sddm override" test ! -e "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato.conf"
check "disable removes hook" test ! -e "$XDG_CONFIG_HOME/omarchy/hooks/post-update.d/potato-mode"
check "disable removes potato session, journald cap" bash -c "[ ! -e '$POTATO_SYSROOT/usr/local/share/wayland-sessions/potato-sway.desktop' ] && [ ! -e '$POTATO_SYSROOT/etc/systemd/journald.conf.d/90-potato.conf' ]"
check "disable restores sddm last session" grep -qx Session=/usr/local/share/wayland-sessions/omarchy.desktop "$POTATO_SYSROOT/var/lib/sddm/state.conf"
check "disable reinstalls dropped obsidian" grep -qx obsidian "$PACDB"
check "disable strips firefox user.js block" bash -c "! grep -q potato '$HOME/.mozilla/firefox/abc.default/user.js'"
teardown

# --- re-apply after potato's own templates changed must not treat potato's file as the original
setup
"$repo/bin/omarchy-potato-enable" --yes >/dev/null 2>&1
echo "# changed" >>"$HOME/.config/sway/config"
"$repo/bin/omarchy-potato-apply" --yes --quiet >/dev/null 2>&1
"$repo/bin/omarchy-potato-disable" --yes >/dev/null 2>&1
check "disable removes potato-created file even after re-apply rewrote it" test ! -e "$HOME/.config/sway/config"
teardown

# --- hyprland path
setup
export POTATO_EGLINFO_OUTPUT=$repo/tests/fixtures/eglinfo-gles3.txt
"$repo/bin/omarchy-potato-enable" --yes >/dev/null 2>&1
check "hyprland path: no sway config" test ! -e "$HOME/.config/sway/config"
check "hyprland path: no sddm override" test ! -e "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato.conf"
check "hyprland path: user.js written" test -f "$HOME/.mozilla/firefox/abc.default/user.js"
check "hyprland path: no software-render prefs" bash -c "! grep -q gfx.webrender.software '$HOME/.mozilla/firefox/abc.default/user.js'"
check "hyprland path: no potato sway session (Qt env scoped)" test ! -e "$POTATO_SYSROOT/usr/local/share/wayland-sessions/potato-sway.desktop"
check "hyprland path: journald cap too" test -f "$POTATO_SYSROOT/etc/systemd/journald.conf.d/90-potato.conf"
check "hyprland path: compositor recorded" grep -qx hyprland "$XDG_STATE_HOME/potato-mode/compositor"
teardown

# --- tune (opt-in tunings)
setup
UNITS=$T/units; export UNITS
printf 'system cups.path enabled\nsystem cups.socket enabled\nsystem cups.service enabled\nsystem avahi-daemon.socket enabled\nsystem avahi-daemon.service enabled\nsystem bluetooth.service enabled\nuser bt-agent.service enabled\nsystem power-profiles-daemon.service enabled\nuser at-spi-dbus-bus.service static\n' >"$UNITS"
cat >"$T/stubs/systemctl" <<'S'
#!/bin/bash
echo "systemctl $*" >>"$STUBLOG"
scope=system; [[ $1 == --user ]] && { scope=user; shift; }
verb=$1; shift; [[ ${1:-} == --now ]] && shift
u=$1
case $verb in
  is-enabled) st=$(awk -v s=$scope -v u="$u" '$1==s && $2==u {print $3}' "$UNITS"); [[ -n $st ]] || exit 1; echo "$st"; [[ $st == enabled ]] ;;
  enable|disable|mask|unmask)
    case $verb in enable) n=enabled ;; disable) n=disabled ;; mask) n=masked ;; unmask) n=static ;; esac
    awk -v s=$scope -v u="$u" -v n=$n '$1==s && $2==u {$3=n} {print}' "$UNITS" >"$UNITS.t" && mv "$UNITS.t" "$UNITS" ;;
esac
exit 0
S
printf '#!/bin/bash\necho "udevadm $*" >>"$STUBLOG"\n' >"$T/stubs/udevadm"
chmod +x "$T/stubs/systemctl" "$T/stubs/udevadm"
unit_is() { awk -v s="$1" -v u="$2" '$1==s && $2==u {print $3}' "$UNITS" | grep -qx "$3"; }
mkdir -p "$POTATO_SYSROOT/sys/block/sda/queue" "$POTATO_SYSROOT/sys/block/nvme0n1/queue"
echo 1 >"$POTATO_SYSROOT/sys/block/sda/queue/rotational"; echo 'mq-deadline kyber [bfq] none' >/dev/null
echo '[mq-deadline] kyber bfq none' >"$POTATO_SYSROOT/sys/block/sda/queue/scheduler"
echo 0 >"$POTATO_SYSROOT/sys/block/nvme0n1/queue/rotational"
printf 'UUID=1 / btrfs rw,relatime,compress=zstd:3,subvol=/@ 0 0\nUUID=2 /boot vfat rw,relatime 0 2\n# comment relatime\n' >"$POTATO_SYSROOT/etc/fstab"
cp "$POTATO_SYSROOT/etc/fstab" "$T/fstab.orig"

out=$("$repo/bin/omarchy-potato" tune list 2>&1)
check "tune list shows all 7 options off" [ "$(grep -c '^off' <<<"$out")" -eq 7 ]
before=$(cat "$UNITS")
"$repo/bin/omarchy-potato-tune" enable no-printing --dry-run >/dev/null 2>&1
check "tune dry-run changes nothing" bash -c "[ \"\$(cat '$UNITS')\" = '$before' ] && [ ! -e '$XDG_STATE_HOME/potato-mode-tune/no-printing' ]"
"$repo/bin/omarchy-potato-tune" enable no-printing --yes >/dev/null 2>&1
check "no-printing disables cups+avahi" bash -c "! grep -q 'cups.*enabled\|avahi.*enabled' '$UNITS'"
check "no-printing leaves bluetooth alone" unit_is system bluetooth.service enabled
"$repo/bin/omarchy-potato-tune" enable no-printing --yes >/dev/null 2>&1
check "tune enable is idempotent (undo list not duplicated)" [ "$(wc -l <"$XDG_STATE_HOME/potato-mode-tune/no-printing/undo")" -eq 5 ]
"$repo/bin/omarchy-potato-tune" disable no-printing >/dev/null 2>&1
check "no-printing disable re-enables all 5 units" [ "$(cat "$UNITS")" = "$before" ]
"$repo/bin/omarchy-potato-tune" enable no-bluetooth --yes >/dev/null 2>&1
check "no-bluetooth: system + user unit" bash -c "grep -qx 'system bluetooth.service disabled' '$UNITS' && grep -qx 'user bt-agent.service disabled' '$UNITS'"
"$repo/bin/omarchy-potato-tune" enable no-a11y --yes >/dev/null 2>&1
check "no-a11y masks the static at-spi unit" unit_is user at-spi-dbus-bus.service masked
"$repo/bin/omarchy-potato-tune" enable no-power-profiles --yes >/dev/null 2>&1
check "no-power-profiles" unit_is system power-profiles-daemon.service disabled
"$repo/bin/omarchy-potato-tune" enable hdd --yes >/dev/null 2>&1
check "hdd: udev BFQ rule written" grep -q 'ATTR{queue/scheduler}="bfq"' "$POTATO_SYSROOT/etc/udev/rules.d/60-potato-bfq.rules"
check "hdd: previous scheduler of rotational sda recorded, not nvme" bash -c "grep -qx 'sched sda mq-deadline' '$XDG_STATE_HOME/potato-mode-tune/hdd/undo' && ! grep -q nvme '$XDG_STATE_HOME/potato-mode-tune/hdd/undo'"
"$repo/bin/omarchy-potato-tune" enable noatime --yes </dev/null >/dev/null 2>&1; rc=$?
check "noatime refuses without a tty or --confirm-fstab (--yes is not enough)" bash -c "[ $rc -ne 0 ] && cmp -s '$T/fstab.orig' '$POTATO_SYSROOT/etc/fstab'"
out=$("$repo/bin/omarchy-potato-tune" enable noatime --dry-run 2>&1)
check "noatime dry-run shows the diff, writes nothing" bash -c "grep -q '+UUID=1' <<<'$out' && cmp -s '$T/fstab.orig' '$POTATO_SYSROOT/etc/fstab'"
"$repo/bin/omarchy-potato-tune" enable noatime --confirm-fstab >/dev/null 2>&1
check "noatime: btrfs relatime -> noatime, vfat and comments untouched" bash -c "grep -q 'btrfs.*rw,noatime,compress' '$POTATO_SYSROOT/etc/fstab' && grep -q 'vfat.*rw,relatime' '$POTATO_SYSROOT/etc/fstab' && grep -qx '# comment relatime' '$POTATO_SYSROOT/etc/fstab'"
check "noatime: backups kept" bash -c "cmp -s '$T/fstab.orig' '$POTATO_SYSROOT/etc/fstab.potato-bak' && cmp -s '$T/fstab.orig' '$XDG_STATE_HOME/potato-mode-tune/noatime/backups/etc/fstab'"
"$repo/bin/omarchy-potato-tune" disable noatime >/dev/null 2>&1
check "noatime disable restores the original fstab" cmp -s "$T/fstab.orig" "$POTATO_SYSROOT/etc/fstab"
"$repo/bin/omarchy-potato-tune" enable noatime --confirm-fstab >/dev/null 2>&1
echo '# admin edit' >>"$POTATO_SYSROOT/etc/fstab"
"$repo/bin/omarchy-potato-tune" disable noatime >/dev/null 2>&1
check "noatime disable won't clobber a later fstab edit" grep -qx '# admin edit' "$POTATO_SYSROOT/etc/fstab"
cp "$T/fstab.orig" "$POTATO_SYSROOT/etc/fstab"
# no-xwayland on top of an enabled potato (sway path)
"$repo/bin/omarchy-potato-enable" --yes >/dev/null 2>&1
"$repo/bin/omarchy-potato-tune" enable no-xwayland --yes >/dev/null 2>&1
check "no-xwayland adds 'xwayland disable' to sway config" grep -qx 'xwayland disable' "$HOME/.config/sway/config"
check "no-xwayland adds hyprland lua setting" grep -q 'xwayland = { enabled = false }' "$HOME/.config/hypr/potato.lua"
"$repo/bin/omarchy-potato-apply" --yes --quiet >/dev/null 2>&1
check "re-apply keeps the tune snippet" grep -qx 'xwayland disable' "$HOME/.config/sway/config"
"$repo/bin/omarchy-potato-tune" disable no-xwayland >/dev/null 2>&1
check "no-xwayland disable removes it" bash -c "! grep -q xwayland '$HOME/.config/sway/config'"
out=$("$repo/bin/omarchy-potato-tune" status 2>&1)
check "tune status lists enabled options" bash -c "grep -q '^no-bluetooth: enabled' <<<'$out' && grep -q '^hdd: enabled' <<<'$out'"
"$repo/bin/omarchy-potato-disable" --yes >/dev/null 2>&1
check "potato disable reverts all tunings" bash -c "[ \"\$(cat '$UNITS')\" = '$before' ] && [ ! -e '$POTATO_SYSROOT/etc/udev/rules.d/60-potato-bfq.rules' ] && ! compgen -G '$XDG_STATE_HOME/potato-mode-tune/*/enabled' >/dev/null"
check "hdd revert restored sda scheduler" grep -qx 'mq-deadline' "$POTATO_SYSROOT/sys/block/sda/queue/scheduler"
"$repo/bin/omarchy-potato-tune" enable bogus >/dev/null 2>&1; check "unknown tuning rejected" [ $? -ne 0 ]
teardown

# --- menu renderer
setup
out=$(POTATO_MENU_SHIPPED=$repo/tests/fixtures/omarchy-menu.jsonc POTATO_MENU_USER=/nonexistent "$repo/bin/omarchy-potato-menu" --print)
check "menu root lists top-level entries" bash -c "grep -q '^apps' <<<'$out' && grep -q '^setup' <<<'$out' && ! grep -q 'setup.theme' <<<'$out'"
out=$(POTATO_MENU_SHIPPED=$repo/tests/fixtures/omarchy-menu.jsonc POTATO_MENU_USER=/nonexistent "$repo/bin/omarchy-potato-menu" setup --print)
check "menu submenu shows children" grep -q '^setup.theme' <<<"$out"
check "menu hides entries whose 'when' fails" bash -c "! grep -q setup.hidden <<<'$out'"
out=$(POTATO_MENU_SHIPPED=$repo/tests/fixtures/omarchy-menu.jsonc POTATO_MENU_USER=$repo/share/potato-mode/menu/potato-menu.jsonc "$repo/bin/omarchy-potato-menu" --print)
check "menu merges user extension" grep -q '^potato' <<<"$out"
out=$(POTATO_MENU_SHIPPED=/workspace/ref/omarchy/default/omarchy/omarchy-menu.jsonc POTATO_MENU_USER=/nonexistent "$repo/bin/omarchy-potato-menu" --print 2>/dev/null)
[[ -f /workspace/ref/omarchy/default/omarchy/omarchy-menu.jsonc ]] && check "menu parses real Omarchy menu (if ref clone present)" grep -q "^setup" <<<"$out"
teardown

# --- base: Omarchy skill linked for Codex
setup
mkdir -p "$POTATO_SYSROOT/usr/share/omarchy/default/agents/skills/omarchy"
echo "---" >"$POTATO_SYSROOT/usr/share/omarchy/default/agents/skills/omarchy/SKILL.md"
"$repo/bin/omarchy-potato-enable" --yes >/dev/null 2>&1
check "omarchy skill symlinked into ~/.agents/skills" test -L "$HOME/.agents/skills/omarchy"
check "potato-mode skill installed" test -f "$HOME/.agents/skills/potato-mode/SKILL.md"
"$repo/bin/omarchy-potato-disable" --yes >/dev/null 2>&1
check "disable removes skill link and addendum" bash -c "[ ! -e '$HOME/.agents/skills/omarchy' ] && [ ! -e '$HOME/.agents/skills/potato-mode/SKILL.md' ]"
teardown

# --- local AI module
ai_setup() {
  setup
  export POTATO_MEMINFO=$T/meminfo POTATO_CPUINFO=$T/cpuinfo POTATO_AI_MIN_FREE_KB=0 POTATO_AI_SMOKE_TIMEOUT=20
  echo "MemTotal:        2010000 kB" >"$POTATO_MEMINFO"
  echo "flags		: fpu sse sse2 pni ssse3 lm" >"$POTATO_CPUINFO"
  printf 'fake-model' >"$T/model.bin"
  export POTATO_AI_MODEL_SHA256; POTATO_AI_MODEL_SHA256=$(sha256sum "$T/model.bin" | cut -d' ' -f1)
  export FAKE_MODEL=$T/model.bin FAKE_DEFAULT_REPLY=$T/reply-ok.json
  echo '{"choices":[{"message":{"content":"OK"}}]}' >"$FAKE_DEFAULT_REPLY"
  for c in cc c++ make; do printf '#!/bin/bash\nexit 0\n' >"$T/stubs/$c"; done
  cat >"$T/stubs/git" <<'S'
#!/bin/bash
echo "git $*" >>"$STUBLOG"
[[ $1 == ls-remote ]] && exit "${FAKE_GIT_RC:-0}"
[[ $1 == -C ]] && shift 2
case $1 in
  fetch) exit "${FAKE_GIT_RC:-0}" ;;
  rev-parse) echo "${FAKE_REV:-5ae2e169eac202d2f065606539c3ad6ab8b51333}" ;;
esac
exit 0
S
  cat >"$T/stubs/cmake" <<'S'
#!/bin/bash
echo "cmake $*" >>"$STUBLOG"
if [[ $1 == --build ]]; then
  [[ -n ${FAKE_BUILD_RC:-} ]] && exit "$FAKE_BUILD_RC"
  mkdir -p "$2/bin"
  printf '#!/bin/bash\n[[ $1 == --version ]] && { [[ -n ${FAKE_SERVER_BROKEN:-} ]] && exit 132; echo fake; exit 0; }\nexec sleep 30\n' >"$2/bin/llama-server"
  chmod +x "$2/bin/llama-server"
fi
exit "${FAKE_CONF_RC:-0}"
S
  cat >"$T/stubs/curl" <<'S'
#!/bin/bash
echo "curl $*" >>"$STUBLOG"
args="$*"
if [[ $args == *-o* ]]; then
  [[ -n ${FAKE_DL_RC:-} ]] && exit "$FAKE_DL_RC"
  while (( $# )); do [[ $1 == -o ]] && { cp "$FAKE_MODEL" "$2"; break; }; shift; done; exit 0
fi
[[ $args == *-fsIL* ]] && exit "${FAKE_NET_RC:-0}"
[[ $args == */health* ]] && exit 0
if [[ $args == *chat/completions* ]]; then
  [[ -n ${FAKE_CHAT_FAIL:-} ]] && exit 7
  cat "${FAKE_REPLY_FILE:-$FAKE_DEFAULT_REPLY}"; exit 0
fi
exit 0
S
  chmod +x "$T/stubs/"*
  AIST=$XDG_STATE_HOME/potato-mode/ai
}

ai_setup
echo "MemTotal:        1010000 kB" >"$POTATO_MEMINFO"
out=$("$repo/bin/omarchy-potato-ai" enable --yes 2>&1); rc=$?
check "ai refuses < 2 GB RAM" bash -c "[ $rc -ne 0 ] && grep -q '2 GB' <<<'$out'"
check "ai refusal leaves module disabled" test ! -e "$AIST/enabled"
check "ai status shows failed preflight" bash -c "'$repo/bin/omarchy-potato-ai' status | grep -q 'result=failed step=preflight'"
teardown

ai_setup
before=$(snapshot)
out=$("$repo/bin/omarchy-potato-ai" enable --dry-run 2>&1); rc=$?
check "ai dry-run succeeds" [ $rc -eq 0 ]
check "ai dry-run changes no files" [ "$before" = "$(snapshot)" ]
check "ai dry-run: no AVX on a Core 2 cpuinfo" bash -c "grep -q 'GGML_AVX=OFF' <<<'$out' && grep -q 'GGML_AVX2=OFF' <<<'$out' && grep -q 'march=core2' <<<'$out' && ! grep -q 'AVX=ON' <<<'$out'"
check "ai dry-run: low priority and -j1 at 2 GB" bash -c "grep -q 'nice -n 19' <<<'$out' && grep -q -- '-j 1' <<<'$out'"
check "ai dry-run uses pinned commit" grep -q 5ae2e169eac202d2f065606539c3ad6ab8b51333 <<<"$out"
teardown

ai_setup
echo "flags		: fpu sse sse2 pni ssse3 avx avx2 fma f16c" >"$POTATO_CPUINFO"
out=$("$repo/bin/omarchy-potato-ai" enable --dry-run 2>&1)
check "ai enables AVX2 only when cpuinfo has it" grep -q 'GGML_AVX2=ON' <<<"$out"
teardown

ai_setup
out=$("$repo/bin/omarchy-potato-ai" enable --yes 2>&1); rc=$?
check "ai enable succeeds (stubbed build)" [ $rc -eq 0 ] || echo "$out"
check "ai enabled state written" grep -q '^variant=prism-ptq1_0' "$AIST/enabled"
check "ai status shows ok with RSS" bash -c "'$repo/bin/omarchy-potato-ai' status | grep -q 'result=ok.*peak_rss_kb='"
check "ai build log written" bash -c "ls '$AIST'/logs/build-*.log >/dev/null"
"$repo/bin/omarchy-potato-ai" disable >/dev/null 2>&1
check "ai disable removes module files" bash -c "[ ! -e '$AIST/enabled' ] && [ ! -d '$XDG_DATA_HOME/potato-mode/ai' ]"
teardown

ai_fail() { # name env... : expects failure at step, disabled module, message with log path
  local name="$1" stepname="$2"; shift 2
  ai_setup
  out=$(env "$@" "$repo/bin/omarchy-potato-ai" enable --yes 2>&1); rc=$?
  check "ai failure: $name -> exit non-zero" [ $rc -ne 0 ]
  check "ai failure: $name -> step $stepname recorded" grep -q "^step=$stepname" "$AIST/last-build"
  check "ai failure: $name -> module disabled, retry+fallback offered" bash -c "[ ! -e '$AIST/enabled' ] && grep -q 'retry:' <<<'$out' && grep -q -- '--fallback' <<<'$out' && grep -q 'log:' <<<'$out'"
  check "ai failure: $name -> base potato-mode untouched" test ! -e "$XDG_STATE_HOME/potato-mode/applied-at"
}
ai_fail "no network" preflight FAKE_NET_RC=6; teardown
ai_fail "missing toolchain" preflight POTATO_AI_TOOLS=potato-no-such-tool; teardown
ai_fail "low disk" preflight POTATO_AI_MIN_FREE_KB=999999999999; teardown
ai_fail "wrong commit" fetch-source FAKE_REV=deadbeef
check "ai failure: wrong commit -> source removed" test ! -d "$XDG_DATA_HOME/potato-mode/ai/src-prism-ptq1_0"; teardown
ai_fail "build error" build FAKE_BUILD_RC=2; teardown
ai_fail "build timeout" build FAKE_BUILD_RC=124
check "ai failure: timeout message" grep -q 'timed out' <<<"$out"; teardown
ai_fail "checksum mismatch" fetch-model POTATO_AI_MODEL_SHA256=0000
check "ai failure: bad download removed" bash -c "! ls '$XDG_DATA_HOME'/potato-mode/ai/models/* >/dev/null 2>&1"; teardown
ai_fail "download interrupted" fetch-model FAKE_DL_RC=18; teardown
ai_fail "binary crashes (illegal instruction)" smoke-test FAKE_SERVER_BROKEN=1
check "ai failure: broken binary removed" test ! -e "$XDG_DATA_HOME/potato-mode/ai/src-prism-ptq1_0/build/bin/llama-server"; teardown
ai_fail "RSS over limit" smoke-test POTATO_AI_RSS_LIMIT_KB=1; teardown
ai_fail "no generation" smoke-test FAKE_CHAT_FAIL=1 POTATO_AI_SMOKE_TIMEOUT=2; teardown

# retry resumes: after a build failure, source is not re-fetched
ai_setup
FAKE_BUILD_RC=2 "$repo/bin/omarchy-potato-ai" enable --yes >/dev/null 2>&1
: >"$STUBLOG"
"$repo/bin/omarchy-potato-ai" enable --yes >/dev/null 2>&1; rc=$?
check "ai retry succeeds and resumes (no re-fetch)" bash -c "[ $rc -eq 0 ] && ! grep -q 'git -C .* fetch' '$STUBLOG'"
teardown

ai_setup
out=$("$repo/bin/omarchy-potato-ai" enable --fallback --dry-run 2>&1)
check "ai --fallback uses upstream + Q2_0" bash -c "grep -q ggml-org/llama.cpp <<<'$out' && grep -q Q2_0.gguf <<<'$out'"
teardown

# --- potato-ask
ai_setup
mkdir -p "$AIST"
printf 'variant=x\nserver=/bin/true\nmodel=/dev/null\n' >"$AIST/enabled"
export POTATO_AI_NO_SERVER=1
export FAKE_REPLY_FILE=$T/reply-tool.json
jq -n --arg c "touch $T/ran" '{choices:[{message:{content:"",tool_calls:[{function:{name:"run",arguments:({cmd:$c}|tojson)}}]}}]}' >"$FAKE_REPLY_FILE"
out=$(echo n | "$repo/bin/omarchy-potato-ask" "make a file" 2>&1)
check "ask shows proposed command" grep -q "proposed: touch $T/ran" <<<"$out"
check "ask does not run without confirmation" test ! -e "$T/ran"
echo n | "$repo/bin/omarchy-potato-ask" --dry-run "make a file" >/dev/null 2>&1
check "ask --dry-run never runs" test ! -e "$T/ran"
echo y | "$repo/bin/omarchy-potato-ask" "make a file" >/dev/null 2>&1
check "ask runs after confirmation" test -e "$T/ran"
grep -q '"enable_thinking":false' <<<"$(grep chat/completions "$STUBLOG")"; check "ask sends thinking off" [ $? -eq 0 ]
rm -f "$AIST/enabled"
"$repo/bin/omarchy-potato-ask" "hi" >/dev/null 2>&1; check "ask refuses when module disabled" [ $? -ne 0 ]
unset POTATO_AI_NO_SERVER FAKE_REPLY_FILE
teardown

# mini-skill budget: <= 500 tokens (estimate: 1 token ~ 4 chars; also <= 375 words)
chars=$(wc -c <"$repo/share/potato-mode/ai/mini-skill.md"); words=$(wc -w <"$repo/share/potato-mode/ai/mini-skill.md")
check "mini-skill <= 500 tokens (chars/4=$((chars / 4)), words=$words)" bash -c "(( $chars / 4 <= 500 && $words <= 375 ))"

# --version: reads VERSION (repo and installed copy via symlink)
v=$("$repo/bin/omarchy-potato" --version 2>&1); check "--version prints VERSION ($v)" test "$v" = "potato-mode $(tr -d '[:space:]' <"$repo/VERSION")"
check "VERSION is semver" grep -qxE '[0-9]+\.[0-9]+\.[0-9]+' "$repo/VERSION"
vt=$(mktemp -d)
POTATO_INSTALL_DIR=$vt/share POTATO_BIN_DIR=$vt/bin "$repo/install.sh" >/dev/null 2>&1
v2=$("$vt/bin/omarchy-potato" --version 2>&1); check "--version works from installed symlink ($v2)" test "$v2" = "$v"
mv "$vt/share/VERSION" "$vt/share/VERSION.x"
"$vt/bin/omarchy-potato" --version >/dev/null 2>&1; check "--version fails without VERSION file" [ $? -ne 0 ]
rm -rf "$vt"

echo "---"
echo "passed: $pass  failed: $fail"
(( fail == 0 ))
