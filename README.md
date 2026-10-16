# potato-mode

Omarchy add-on for ~2006 x86_64 hardware (Core 2 / Athlon 64, 1 GB+ RAM, old GPU, HDD). See `PROPOSAL.md` (decisions §0), `docs/`.

## Install
```
./install.sh                       # copies to ~/.local/share/potato-mode, links ~/.local/bin/omarchy-potato*
omarchy-potato enable --dry-run    # show every change, touch nothing
omarchy-potato enable              # check channel/version, then apply
omarchy-potato status
omarchy-potato disable             # revert (restores files, reinstalls dropped packages)
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
- `post-update` hook re-applies after `omarchy update`; skips package changes if Omarchy left the tested range (`share/potato-mode/compat`).

## Tests
`tests/shellcheck.sh` and `tests/run.sh` (fake HOME/sysroot, stubbed pacman/sudo/omarchy; nothing real is touched).
