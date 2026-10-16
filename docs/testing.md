# Testing status (2026-10-16)

## Automated (box)
- `tests/shellcheck.sh`: clean (ShellCheck 0.11.0).
- `tests/run.sh`: 51/51 pass. Uses a fake HOME and sysroot with stubbed pacman/sudo/omarchy-*. Covers GPU detection (GLES2 / GLES3 / llvmpipe fixtures), channel/version gate, dry-run touches nothing, the sway and Hyprland paths, idempotent re-apply, the post-update hook re-dropping Chromium and re-pointing web apps, the hook skipping packages on an untested Omarchy version, full revert, and the menu renderer against fixtures and the real Omarchy 4 `omarchy-menu.jsonc`.

## In the 1 GB TCG VM (plain Arch, **not Omarchy**; see vm/RESULTS.md)
- `install.sh` → `omarchy-potato enable --yes --force-channel --force-version` installed the real packages through pacman: OK. `tesseract` couldn't be dropped because `zathura-pdf-mupdf` → `libmupdf` needs it. Switched to `zathura-pdf-poppler`.
- Detection reported `gles=3.2 renderer=llvmpipe software=1 -> sway`, as intended.
- Second apply: no file changes (21 files compared).
- `sway -C` on the generated config: valid. The first versions failed on an empty `include` glob and a one-line `colors {}` block; both fixed.
- sway session with the generated config, idle 90 s, PSS: sway 109 MiB, polkit-gnome 14, swaybar 6, mako 2, swayidle 0 (≈131 MiB total). System 425 MiB used of 951.
- Menu renderer on the real Omarchy menu: 11 root rows (Apps … System + Potato mode). The first version showed 0 because the shipped file uses trailing commas; fixed.
- enable → apply → disable: file set identical to before (clean revert). Found and fixed a bug where a re-apply backed up potato's own older file as the "original".

## Not tested
- Anything on a real Omarchy install: `omarchy-channel-current`/`omarchy-version` output, `omarchy-pkg-add`/`-drop`, the post-update hook inside a real `omarchy update`, the menu extension showing up in the Quickshell menu, `potato.lua` loading in Hyprland 0.56 Lua (including whether `o.bind` replaces the stock web app bindings), and SDDM using the weston greeter override.
- Interactive fzf/gum menu navigation (only `--print` was tested), Firefox picking up the user.js and system prefs, uBlock auto-enabling, and xdg defaults.
- Real 2006 hardware, GLES2 GPUs, reboot with zram active.
