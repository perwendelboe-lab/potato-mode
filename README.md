# potato-mode

Omarchy add-on for ~2006 x86_64 hardware (Core 2 / Athlon 64, 1 GB+ RAM, old GPU, HDD). See `PROPOSAL.md` (decisions §0), `docs/`.

## Install
```
./install.sh                       # copies to ~/.local/share/potato-mode, links ~/.local/bin/omarchy-potato*
omarchy-potato enable --dry-run    # show every change, touch nothing
omarchy-potato enable              # check channel/version, then apply
omarchy-potato status
omarchy-potato disable             # revert (restores files, reinstalls dropped packages, undoes tunings)
omarchy-potato tune list           # opt-in: no-printing no-bluetooth hdd noatime no-xwayland no-a11y no-power-profiles
```
Options: `--with-libreoffice`, `--redetect` (re-run GPU detection), `--force-channel`, `--force-version`, `--keep-packages` (disable).

## What it does (`bin/omarchy-potato-apply`, idempotent)
- GPU: `eglinfo -B -p gbm` → GLES ≥ 3.0 on real hardware → Hyprland (+Quickshell); otherwise (GLES 2 or llvmpipe) → sway session, terminal fzf/gum menu (`omarchy-potato-menu`, renders Omarchy's own `omarchy-menu.jsonc`), mako/swaylock/swayidle/polkit-gnome, SDDM greeter on weston-pixman.
- Packages: drops Chromium, Obsidian, LibreOffice, Docker, dotnet, superwhisper, gpu-screen-recorder, moonlight, omacut, pinta, aether, tesseract, owe, Nautilus, Evince; adds Firefox + uBlock Origin, AbiWord, Gnumeric, aerc, mpv, imv, yazi, nnn, weechat, zathura, neovim, Codex CLI, links, zram-generator.
- Hyprland: `~/.config/hypr/potato.lua` (no animations/blur/shadows/gaps), required from `hyprland.lua` in a marked block.
- Firefox: tab unloading, 2 content processes, no disk cache, software WebRender on the sway path; system default prefs + per-profile `user.js`.
- Web apps: rewrites `~/.local/share/applications` web-app launchers to `omarchy-potato-webapp` (Firefox tab).
- zram: Omarchy already ships `zram-size = ram`; potato-mode only fills in a config if none exists.
- Omarchy menu: "Potato mode" submenu via `~/.config/omarchy/extensions/omarchy-menu.jsonc`.
- Sway path: own "Sway (potato)" session with `QT_QUICK_BACKEND=software` (Qt Quick apps ~120 MiB lighter on llvmpipe); journald capped at 50M; Firefox bfcache/prefetch off.
- Opt-in `omarchy-potato tune` (docs/tuning.md); unattended updates: docs/updates.md.
- `post-update` hook re-applies after `omarchy update`; skips package changes if Omarchy left the tested range (`share/potato-mode/compat`).

## Tests
`tests/shellcheck.sh` and `tests/run.sh` (fake HOME/sysroot, stubbed pacman/sudo/omarchy; nothing real is touched).

## Test VMs (`vm/`)
- `vm/run-vm.sh` (plain Arch cloud image) rebuilds `seed.img` from `vm/user-data` + `vm/meta-data` at **every launch**, so it needs
  `cloud-localds`, `xorriso` or `genisoimage` installed each time. It injects `id_ed25519.pub`. The `arch` password stays locked (ssh key only).
  `VM_CONSOLE_PASSWORD=1` sets a random console password, kept in the gitignored `vm/.console-password`.
  The instance-id is a hash of the rendered user-data, so cloud-init re-runs on an existing disk whenever it changes.
- `vm/omarchy/` drives an Omarchy ISO install in a 1 GB TCG VM (see vm/omarchy/RESULTS.md).
