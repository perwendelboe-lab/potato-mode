# Testing status (2026-10-16)

## Automated (box)
- `tests/shellcheck.sh`: clean (ShellCheck 0.11.0).
- `tests/run.sh`: 127/127 pass. Uses a fake HOME and sysroot with stubbed pacman/sudo/omarchy-*. Covers GPU detection (GLES2 / GLES3 / llvmpipe fixtures), channel/version gate, dry-run touches nothing, the sway and Hyprland paths, idempotent re-apply, the post-update hook re-dropping Chromium and re-pointing web apps, the hook skipping packages on an untested Omarchy version, full revert, and the menu renderer against fixtures and the real Omarchy 4 `omarchy-menu.jsonc`.

## In the 1 GB TCG VM (plain Arch, **not Omarchy**; see vm/RESULTS.md)
- `install.sh` → `omarchy-potato enable --yes --force-channel --force-version` installed the real packages through pacman: OK. `tesseract` couldn't be dropped because `zathura-pdf-mupdf` → `libmupdf` needs it. Switched to `zathura-pdf-poppler`.
- Detection reported `gles=3.2 renderer=llvmpipe software=1 -> sway`, as intended.
- Second apply: no file changes (21 files compared).
- `sway -C` on the generated config: valid. The first versions failed on an empty `include` glob and a one-line `colors {}` block; both fixed.
- sway session with the generated config, idle 90 s, PSS: sway 109 MiB, polkit-gnome 14, swaybar 6, mako 2, swayidle 0 (≈131 MiB total). System 425 MiB used of 951.
- Menu renderer on the real Omarchy menu: 11 root rows (Apps … System + Potato mode). The first version showed 0 because the shipped file uses trailing commas; fixed.
- enable → apply → disable: file set identical to before (clean revert). Found and fixed a bug where a re-apply backed up potato's own older file as the "original".

## On real Omarchy 4.0.4 (1 GB TCG VM; see vm/omarchy/RESULTS.md)
- Verified: `omarchy-version`/channel and `omarchy-potato check`; `omarchy-pkg-add`/`-drop` via enable (after
  `omarchy update` synced the DBs; a fresh install only has offline.db, so `apply` now stops with a hint); the post-update hook inside a
  real `omarchy update`; menu entries merged into omarchy-menu.jsonc (comments in that file are lost; the original is backed up);
  Firefox system prefs, user.js in the XDG profile dir, and uBlock active; xdg default browser; SDDM greeter on weston;
  login into sway (needed the new SDDM last-session fix).
- Idle: stock 630 MiB used / 451 MiB zram swap vs potato (sway) 413 MiB used / 32 MiB swap.

## Omarchy 4.0.5 (same VM, updated 2026-10-19)
- `omarchy update -y` to 4.0.5: the post-update hook ran; `check` OK; re-apply with the new grouped drop removed ufw-docker,
  docker and the tesseract pair; greeter on weston and sway login still work. Idle: 434 MiB used, 14 MiB zram.
- `omarchy update -y` still waits at two `gum confirm` prompts (orphan removal, reboot after a kernel update).

## Not tested
- Hyprland path on real Omarchy: `potato.lua` loading in Hyprland Lua and whether `o.bind` replaces the stock web-app bindings.
- The potato entry rendering inside the Quickshell menu, and interactive fzf/gum menu navigation (only `--print`).
- Real 2006 hardware, GLES2 GPUs.
