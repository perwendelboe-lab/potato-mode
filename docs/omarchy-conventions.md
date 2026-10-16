# Omarchy conventions (as relevant to potato-mode)

Source: read-only clone of `basecamp/omarchy` at commit `51bfd1d` (2026-10-15 22:06 -0400 = 2026-10-16 04:06 Paris) in `/workspace/ref/omarchy`. File paths below are relative to that repo.

## Commands
- Everything is a `bin/omarchy-*` bash script (530 at this commit) with metadata headers (`# omarchy:summary=`, `# omarchy:group=`, `# omarchy:args=`, `# omarchy:requires-sudo=`). `bin/omarchy` routes `omarchy <group> <name>`; groups listed in `GROUP_DESCRIPTIONS`. Style rules in `AGENTS.md` (`#!/bin/bash`, `[[ ]]`/`(( ))`, two-space indent).
- Contributor guides for agents: `AGENTS.md`, `CLAUDE.md`, `agents/skills/*.md` (install-scripts, command-metadata, migrations…). Omarchy is itself built agent-first.

## Packages
- `install/omarchy-base.packages` (core list pacstrapped by the ISO), plus per-arch lists (`omarchy-x86_64-only.packages`, aarch64 variants, `omarchy-other.packages`).
- Helpers: `omarchy-pkg-add` (`pacman -S --needed` if missing, verifies install), `omarchy-pkg-aur-add`/`-aur-install` (via `yay`), `omarchy-pkg-drop`/`-remove`, `omarchy-pkg-missing`/`-present`, `omarchy-pkg-defaults`.
- App installers: `omarchy-install-<thing>` (browser, editor-*, ai-*, service-*, gaming-*, terminal, dev-env…). `omarchy-install-browser` handles Chromium policy dir/flags and has a Firefox Wayland path.
- Preinstalls: `omarchy-remove-preinstalls` / `omarchy-install-preinstalls` toggle a curated heavy set: aether, cliamp, libreoffice-fresh, pinta, obsidian, moonlight-qt, omacut, monologue, omacalc, omawrite, hype, signed (+ web apps and TUI launchers via `omarchy-refresh-applications`).
- Web apps: `omarchy-webapp-install`, `omarchy-launch-webapp` → Chromium `--app` windows. Shipped `.desktop` web apps in `applications/`: Basecamp, Discord, Google Contacts/Maps/Messages/Photos, HEY, WhatsApp, X, YouTube, Zoom. TUIs via `omarchy-tui-install`.
- Migrations under `migrations/` run on `omarchy update`.

## Heavy defaults (from `omarchy-base.packages`)
chromium (default browser + every web app), obsidian (Electron), libreoffice-fresh, docker/docker-buildx/docker-compose, dotnet-runtime, postgresql-libs/mariadb-libs, full fcitx5 CJK input stack, noto-fonts-cjk, tesseract, superwhisper-bin (dictation), gpu-screen-recorder, moonlight-qt, qemu-user-static-binfmt, quickshell + qt6-* (desktop shell), plymouth, owe/owe-lockfeed (video backgrounds/lock-screen frames), nautilus (+sushi, gvfs).
Already-light defaults worth keeping: foot, imv, mpv, evince→(zathura lighter), btop, nvim, tmux, lazygit, fzf/rg/fd/eza/bat/zoxide, yazi-style TUIs, herdr.

## Desktop shell, menu, keybindings
- The desktop is now **Quickshell** (Qt6/QML) — "Omarchy Quattro". The menu is the `omarchy.menu` shell plugin; content is data in `default/omarchy/omarchy-menu.jsonc`, overlaid by user `~/.config/omarchy/extensions/omarchy-menu.jsonc` (see `docs/menu.md`). Entries: dotted id = tree position; fields `icon,label,action,target,provider,when,checked,disabled,description`. Live-reloaded. Pickers use `omarchy-menu-select`; terminal prompts use `gum`.
- Hyprland config is Lua (`default/hypr/*.lua`, user overrides `config/hypr/*.lua` → `~/.config/hypr/`). `default/hypr/looknfeel.lua` ships shadow off, blur off, animations ON. `default/hypr/toggles/no-animations.lua` already exists "for machines that render on the CPU, like a VM": animations, blur, shadow all off.
- Bindings: `default/hypr/bindings*.lua`; keybinding menus `omarchy-menu-keybindings`.

## Themes
`omarchy-theme-*` (set/install/list/switcher/bg-*); `omarchy-theme-set-<app>` templates per app (browser, foot, tmux, vscode, obsidian, claude, pi, hermes…). Doc: `docs/theming.md`. Video backgrounds (owe) and glass toggles exist — both to be avoided on potato hardware.

## Extension points (how to ship potato-mode)
1. **Shell plugins** — `omarchy-plugin-add <git-url> [--enable]` clones into `~/.config/omarchy/plugins/<id>/` with a `manifest.json` (`kinds` like `bar`, `bar-widget`); managed by `omarchy-plugin-{list,enable,disable,update,remove,validate,catalog}` and `omarchy-menu-plugin`. Community registries: omarchyplugins.com (github.com/omacom/omarchy-plugin-marketplace), omahub.dev, Okomart (brianblakely/omarchy-plugins), list at github.com/aorumbayev/awesome-omarchy. Marketplace README warns plugins are unsandboxed and install commands clone mutable HEAD.
2. **Hooks** — `omarchy-hook-install <type> <file>` → `~/.config/omarchy/hooks/<type>.d/`; types shipped: `post-boot`, `post-update`, `pre-refresh-pacman`, `theme-set`, `font-set`, `battery-low`. A `post-update` hook can re-apply potato settings after Omarchy updates.
3. **Menu extension** — `~/.config/omarchy/extensions/omarchy-menu.jsonc` (note: only whole-line `//` comments; a parse error silently drops all user entries).
4. **User config overrides** — `~/.config/hypr/*.lua`, `~/.config/omarchy/defaults`.
