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
