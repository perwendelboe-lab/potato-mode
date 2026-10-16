# Omarchy release channels, updates and roadmap — impact on potato-mode

Sources: the `basecamp/omarchy` clone, which now redirects to **`omacom/omarchy`** (default branch `quattro`, HEAD `51bfd1d`, 2026-10-16 04:06 Paris); the GitHub API for releases and milestones (queried 2026-10-16); `omacom/omarchy-pkgs` `pkgbuilds/omarchy/PKGBUILD` (pkgver 4.0.4).

## Channels
Omarchy 4 ("Quattro") is **package-backed**: code ships as pacman packages `omarchy` and `omarchy-settings`, installed to `/usr/share/omarchy`. It's no longer a git checkout in `~/.local/share/omarchy`.

| Channel | How it is identified (from `bin/`) |
|---|---|
| `stable` | `omarchy` + `omarchy-settings` are installed, `/etc/pacman.d/mirrorlist` has `https://stable-mirror.omarchy.org/`, and `/etc/pacman.conf` has `https://pkgs.omarchy.org/stable/` |
| `rc` | same packages; `rc-mirror.omarchy.org` and `pkgs.omarchy.org/rc/` |
| `edge` | `omarchy-dev` + `omarchy-settings-dev` installed (edge repo only); `mirror.omarchy.org` and `pkgs.omarchy.org/edge/` |
| `dev` | `OMARCHY_PATH` ≠ `/usr/share/omarchy` (linked `~/omarchy` source checkout) |

- Detect: `omarchy-channel-current` → `stable|rc|edge|dev|unknown`. Version: `omarchy-version` (the pacman version of `omarchy` or `omarchy-dev`; `dev (<hash>)` for dev). `omarchy-version-channel` prints mirror/pkgs, and prints `X / Y` if they disagree.
- Switch: `omarchy-channel-set <stable|rc|edge|dev>` (sudo, hardened `#!/bin/bash -p` entrypoint).
- Pre-release versions use the attached form `4.0.0rc1`, so pacman `vercmp` orders rc < final (comment in the PKGBUILD).

## Cadence (GitHub releases, all non-prerelease)
v3.1.4 2025-10-28 … v3.2.0 2025-11-21, v3.3.0 2026-01-07, v3.4.0 2026-02-26, v3.5.0 2026-04-03, v3.6.0 2026-04-23, v3.7.0 2026-05-04, v3.8.0 2026-05-09, v3.8.4 2026-07-21, **v4.0.0 2026-08-14**, v4.0.1 08-25, v4.0.2 08-31, v4.0.3 09-08, **v4.0.4 2026-09-15** (latest). That's roughly one minor release every 3–6 weeks and patch releases about weekly after a major. Open milestones: 4.1 (6 open issues: bar widget picker, captive portal, dictation, HP hardware…).

## Update pipeline (`docs/update-process.md`)
`omarchy update` runs: package transaction (with guard and snapshot) → per-user **migrations** (`migrations/*.sh`, markers in `~/.local/state/omarchy/migrations/`, must be idempotent) → **`post-update` hook** → mise update → restart checks. **The Quickshell shell is restarted after every update.** A raw `pacman -Syu` is aborted by an ALPM guard hook unless it is bypassed. ALPM hooks also pause and resume Hyprland config reloads and force one `hyprctl reload`.

Hooks: `omarchy-hook <name>` runs `~/.config/omarchy/hooks/<name>` and every file in `<name>.d/` (skipping `*.sample`); a failing hook only prints "Hook failed". Install with `omarchy-hook-install <type> <file>`.

## Roadmap / direction relevant to potato-mode
- **Quattro (v4.0.0) release notes:** the whole desktop shell (bar, launcher, menus, **notifications, OSDs, lock screen, polkit agent**) now lives in one Quickshell process. Waybar, Walker, Mako, SwayOSD, hyprlock, hypridle, swaybg and polkit-gnome are gone. **Consequence:** the sway path can't just drop Quickshell. It must supply its own lock screen (swaylock), idle daemon (swayidle), notification daemon (mako) and polkit agent.
- Hyprland configs moved to **Lua** (Hyprland 0.56). User overrides: `~/.config/hypr/hyprland.lua` `require`s `hypr.monitors|input|bindings|looknfeel|autostart`, and anything appended after that.
- The **`omarchy` package hard-depends on** `hyprland`, `quickshell`, `uwsm`, `sddm`, `xdg-desktop-portal-hyprland`, limine, snapper and networkmanager (PKGBUILD). **Chromium is not a dependency**, so it can be dropped. Hyprland and Quickshell can't be uninstalled, only left unused.
- **SDDM's greeter runs on Hyprland** (`etc/sddm.conf.d/10-wayland.conf`: `CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.lua`). On a GPU without GLES 3.0 the *login screen itself* can fail. potato-mode must override it (drop-in `zz-potato.conf` using weston kiosk-shell, or X11 greeter).
- **Web apps:** `omarchy-launch-webapp` only honours Chromium-family browsers and falls back to `chromium.desktop` for anything else (Firefox included). Web-apps-as-Firefox-tabs therefore needs potato-mode's own launcher plus rewritten `.desktop` files, which `omarchy-refresh-applications` can regenerate, so they must be re-applied after updates.
- **zram is already an Omarchy default** (`default/systemd/zram-generator.conf.d/90-omarchy.conf`: `zram-size = ram`; sysctl tuned for swap-on-zram; zswap disabled). potato-mode only needs to make sure `zram-generator` is installed and check it's active.
- Plugin system (`omarchy plugin add`), menu extension file and hooks are all new in 4.0 and still moving: the marketplace (omacom/omarchy-plugin-marketplace) has 341 open issues, and the 4.1 milestone has bar-widget work.
- Old hardware: no stated support policy found. Open hardware issues are case-by-case, e.g. #13760 (2011 iMac, legacy radeon: Chromium artifacts, fixed by `--disable-gpu-compositing`), #14619 (linux-omarchy freezes on iMac12,2), #14472 (virtio GPU). There is no i686 build (packages are x86_64/aarch64 only).

## Is "require the stable channel" sound?
**Yes, as the supported default, enforced by a warning rather than a hard block:**
- stable is the only channel with a release cadence and version numbers we can test against. edge (`omarchy-dev`) moves daily, and dev is a mutable checkout.
- `omarchy-potato-enable` runs `omarchy-channel-current`. On `stable` it proceeds. On `rc`/`edge`/`dev`/`unknown` it refuses unless `--force-channel` is passed. It also refuses if `omarchy-version` major ≠ 4.

## Pinning compatibility
- `share/potato-mode/compat` declares `OMARCHY_MIN=4.0.0` and `OMARCHY_MAX_EXCLUSIVE=4.1.0` (tested range). The check compares with `vercmp` when it's available and falls back to `sort -V`. Outside the range: warn and require `--force-version`.
- The post-update hook re-checks the range. If Omarchy jumped to an untested minor, it notifies the user and skips re-applying anything risky (package drops) but still re-applies configs.

## Surviving updates and migrations
1. **All changes go through user-owned override points**, never through files in `/usr/share/omarchy`: `~/.config/hypr/potato.lua` (required from `hyprland.lua` via one marked line), `~/.config/omarchy/extensions/omarchy-menu.jsonc` (a marked block), `~/.local/share/applications/*.desktop` (web apps), `/etc/sddm.conf.d/zz-potato.conf`, and the Firefox profile `user.js`.
2. **Idempotent `omarchy-potato-apply`** re-asserts every override and the drop list, and is safe to run any number of times.
3. **`post-update` hook** (`~/.config/omarchy/hooks/post-update.d/potato-mode`) calls `omarchy-potato-apply --quiet`. Omarchy migrations or `omarchy-reinstall-pkgs` may re-add dropped packages. Re-applying drops them again (state recorded in `~/.local/state/potato-mode/`).
4. **Revert** (`omarchy-potato-disable`) restores backups, removes marker blocks and the hook, re-adds the packages potato-mode dropped, and returns the session to Hyprland.

## Risks
- **Hard dependencies:** Hyprland and Quickshell stay installed. Their disk and package-update cost remains even on sway.
- **Upstream assumes Hyprland:** Omarchy's update pipeline forces `hyprctl reload` and restarts the shell. On sway those calls fail harmlessly (not verified on a real install).
- **Re-added packages:** future migrations may re-add packages or regenerate `.desktop` files. That's mitigated by the hook, but there's a window until the hook runs.
- **Moving extension points:** the menu-extension schema, plugin system and hook names are young (4.0). A parse error in `omarchy-menu.jsonc` silently drops *all* user menu entries (`docs/menu.md`). potato-mode validates its block with `jq` after stripping comments.
- **Greeter:** the SDDM-on-Hyprland greeter on GLES2 hardware is the most likely "black screen at login" failure (cf. open issue #13317 "blank black screen", cause unknown). It's untested.
