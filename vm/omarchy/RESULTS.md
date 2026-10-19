# Omarchy 4.0.4 VM results (box measurements)

VM: QEMU TCG (no KVM, no GPU, llvmpipe), 1 GB RAM (944 MiB visible), 4 vCPU, OVMF.
Kernel 7.2.5-3-omarchy. Official omarchy-4.0.4 ISO (sha256 checked), unencrypted install, 21m14s.

## Verified
- SDDM greeter (Hyprland, llvmpipe) and the stock Quickshell desktop come up.
- `omarchy-version` 4.0.4-1, `omarchy-version-channel` stable, `omarchy-potato check` OK
  (after defaulting OMARCHY_PATH, which is unset over ssh).
- `omarchy-potato-detect`: stock Omarchy has no `eglinfo`, so it falls back to sway.
- dry-run of `enable` on real Omarchy.

## Findings
- A fresh install has only `offline.db` in /var/lib/pacman/sync, so every
  `omarchy-pkg-add` fails with "target not found". `apply` now stops early and
  tells you to run `omarchy update` first. That run synced core/extra/multilib/omarchy.
- `omarchy update` over ssh needs `OMARCHY_PATH=/usr/share/omarchy` (omarchy-update-dev
  hits an unbound variable otherwise). It calls `sudo -v`, so NOPASSWD testing also
  needs `Defaults verifypw=any`. It ended with "Omarchy shell did not become ready after restart"
  (headless ssh, no session env).
- Omarchy installs Codex via mise (aqua:openai/codex), not only via pacman.
- Merging the menu through jq drops comments in the user's existing omarchy-menu.jsonc
  (the original is backed up).

## Stock idle memory
See raw-stock-idle.txt: 630 MiB used / 313 MiB available, 451 MiB swap (zram).
PSS: quickshell 164 MiB (+229 swapped), Hyprland 83 (+100), foot 12.

## potato-mode enable (after `omarchy update` synced DBs)
- The `apply` run completed ("potato: applied"). With mesa-utils installed, detect read
  `gles=3.2 renderer=llvmpipe software=1 -> sway`, so the software-render rule picked sway.
- Dropped: chromium obsidian libreoffice-fresh docker-buildx docker-compose
  gpu-screen-recorder moonlight-qt omacut pinta aether nautilus-python sushi nautilus evince dotnet-runtime.
- Not removable, so it was left alone with a warning: docker (needed by ufw-docker), tesseract and
  tesseract-data-eng (they depend on each other, so dropping them one at a time fails).
- Added: mesa-utils firefox firefox-ublock-origin abiword gnumeric aerc yazi nnn weechat
  zathura zathura-pdf-poppler openai-codex links sway swaybg swaylock swayidle mako polkit-gnome weston.
- Verified files: the post-update hook is in hooks/post-update.d/potato-mode, the menu entries
  are in extensions/omarchy-menu.jsonc, /etc/sddm.conf.d/zz-potato.conf, and the
  Firefox system prefs are in /usr/lib/firefox/defaults/pref/potato-mode.js (25 prefs). xdg default
  browser is firefox.desktop.
- Firefox 1st run (headless) created a profile at ~/.config/mozilla/firefox (XDG path, which
  firefox_profile_dirs covers). uBlock Origin shows active=true, location app-global.
- Post-update hook: running `omarchy update -y` ran hooks/post-update.d/potato-mode, and the potato
  apply warnings show up inside /tmp/omarchy-update.log. That run wrote the marked block in
  the new Firefox profile's user.js (27 lines). So the hook re-applies the settings, and it also
  catches profiles created after enable.

## SDDM greeter and session
- After reboot, SDDM runs its greeter on `weston --shell=kiosk --renderer=pixman` (zz-potato.conf).
  The Omarchy greeter theme renders on it (screenshot checked).
- Bug found: with no autologin (unencrypted install), SDDM preselects the last session
  `/usr/local/share/wayland-sessions/omarchy.desktop` (Hyprland via uwsm), so logging in started Hyprland.
  First attempt: a copy of the theme matching "Sway" instead of "uwsm". It did not help (still
  Hyprland), so it was dropped. Fix: on the sway path, `apply` sets `[Last] Session=` in
  /var/lib/sddm/state.conf to sway.desktop. It reads the file via sudo because /var/lib/sddm isn't user-readable,
  and it backs the file up for revert. After that, logging in at the greeter started sway (sway, swaybar, swaybg, swayidle; no Hyprland or
  quickshell running). Screenshot checked.

## Idle memory: stock vs potato-mode (same VM, PSS via smaps_rollup, one foot open)
| | stock Omarchy 4.0.4 (Hyprland+Quickshell) | potato-mode (sway) |
|---|---|---|
| time after login | ~10 min | ~11 min |
| `free` used / available | 630 / 313 MiB | 413 / 530 MiB |
| swap (zram) used | 451 MiB | 32 MiB |
| zram data / compressed total | 430.8 / 94.7 MiB | 32.2 / 13.4 MiB |
| compositor + shell PSS (swapped) | Hyprland 83 (100) + quickshell 164 (229) | sway 127 (4) + swaybar 6 |
| sum PSS / sum swapped (all processes) | 357 / 443 MiB | 272 / 27 MiB |

Caveats: there was only one sample of each. The stock run was after a fresh boot, before `omarchy update`. The potato run
was after the update, with sddm restarted rather than a fresh boot. sway alone reaches 127 MiB PSS on llvmpipe in this VM.
Raw output: raw-stock-idle.txt and raw-potato-idle.txt.

## Not verified on real Omarchy
- Hyprland path: potato.lua loading and `o.bind` replacing the web-app binds (this VM picks sway; we did not log into Hyprland).
- The potato entry showing in the Quickshell menu (the entry was merged into omarchy-menu.jsonc and parses, but Quickshell
  isn't running on the sway path). The interactive fzf/gum menu.
- Real 2006 hardware / GLES2 GPUs.

## Update to Omarchy 4.0.5 (2026-10-19)
- `omarchy update -y` (over ssh with OMARCHY_PATH set) took this VM from 4.0.4-1 to 4.0.5-1, kernel 7.2.5-3 to 7.2.8-9-omarchy, with 313 packages,
  roughly 50 min under TCG. Even with `-y` it stopped twice at a `gum confirm`: "Remove 1 orphaned package(s)?"
  (hyprwayland-scanner) and "Linux kernel has been updated. Reboot?". Both were answered by killing gum, then a manual reboot.
- The potato post-update hook ran during the update on 4.0.5. `omarchy-potato check` reports
  "Omarchy 4.0.5 on channel stable: OK", which is inside the 4.0.0 to <4.1.0 compat range, so no change was needed.
- With the new drop logic, apply removed ufw-docker, then docker (with containerd/runc/libpathrs), then
  tesseract + tesseract-data-eng in one transaction (with leptonica and tesseract-data-osd), freeing about 262 MiB of disk.
- After reboot the greeter is still on weston, and the SDDM last session is still sway.desktop. Login started sway.
