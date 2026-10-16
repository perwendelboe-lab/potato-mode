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

snapshot() { (cd "$T" && find home root pacdb -type f -exec md5sum {} + | sort); }

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
check "sway extras added" grep -qx swaylock "$PACDB"
check "hyprland kept (Omarchy hard dep)" grep -qx hyprland "$PACDB"
check "hyprland.lua requires hypr.potato" grep -q 'require("hypr.potato")' "$HOME/.config/hypr/hyprland.lua"
check "potato.lua written" test -f "$HOME/.config/hypr/potato.lua"
check "sway config written" test -f "$HOME/.config/sway/config"
check "sddm greeter override" grep -q weston "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato.conf"
check "autologin session -> sway" grep -q 'Session=sway.desktop' "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato-session.conf"
check "zram config written (none existed)" test -f "$POTATO_SYSROOT/etc/systemd/zram-generator.conf.d/90-potato.conf"
check "firefox user.js tab unloading" grep -q 'browser.tabs.unloadOnLowMemory' "$HOME/.mozilla/firefox/abc.default/user.js"
check "firefox software render on sway" grep -q 'gfx.webrender.software' "$HOME/.mozilla/firefox/abc.default/user.js"
check "firefox system prefs" grep -q '^pref("dom.ipc.processCount", 2);' "$POTATO_SYSROOT/usr/lib/firefox/defaults/pref/potato-mode.js"
check "web app -> firefox tab" grep -qx 'Exec=omarchy-potato-webapp https://app.hey.com' "$XDG_DATA_HOME/applications/HEY.desktop"
check "menu extension valid JSON with potato entry" bash -c "jq -e '.potato' '$XDG_CONFIG_HOME/omarchy/extensions/omarchy-menu.jsonc' >/dev/null"
check "post-update hook installed" test -x "$XDG_CONFIG_HOME/omarchy/hooks/post-update.d/potato-mode"
after1=$(snapshot)
"$repo/bin/omarchy-potato-apply" --yes --quiet >/dev/null 2>&1
check "second apply is a no-op (idempotent)" [ "$after1" = "$(snapshot)" ]
check "marker block appears once" [ "$(grep -c 'potato-mode:begin' "$HOME/.config/hypr/hyprland.lua")" -eq 1 ]
# simulate an Omarchy update restoring chromium and the stock web app
echo chromium >>"$PACDB"
printf '[Desktop Entry]\nName=HEY\nExec=omarchy-launch-webapp https://app.hey.com\n' >"$XDG_DATA_HOME/applications/HEY.desktop"
bash "$XDG_CONFIG_HOME/omarchy/hooks/post-update.d/potato-mode" >/dev/null 2>&1
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
check "disable reinstalls dropped obsidian" grep -qx obsidian "$PACDB"
check "disable strips firefox user.js block" bash -c "! grep -q potato '$HOME/.mozilla/firefox/abc.default/user.js'"
teardown

# --- hyprland path
setup
export POTATO_EGLINFO_OUTPUT=$repo/tests/fixtures/eglinfo-gles3.txt
"$repo/bin/omarchy-potato-enable" --yes >/dev/null 2>&1
check "hyprland path: no sway config" test ! -e "$HOME/.config/sway/config"
check "hyprland path: no sddm override" test ! -e "$POTATO_SYSROOT/etc/sddm.conf.d/zz-potato.conf"
check "hyprland path: user.js written" test -f "$HOME/.mozilla/firefox/abc.default/user.js"
check "hyprland path: no software-render prefs" bash -c "! grep -q gfx.webrender.software '$HOME/.mozilla/firefox/abc.default/user.js'"
check "hyprland path: compositor recorded" grep -qx hyprland "$XDG_STATE_HOME/potato-mode/compositor"
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
teardown

echo "---"
echo "passed: $pass  failed: $fail"
(( fail == 0 ))
