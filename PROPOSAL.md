# potato-mode — proposal

An add-on for Omarchy (basecamp/omarchy) that keeps Omarchy's CLI/agent-first workflow, `omarchy-*` commands and keybinding menus, but makes it usable on ~2006 x86_64 hardware (Core 2 Duo / Athlon 64, 1–2 GB RAM, HDD, old GPU). Details: `docs/omarchy-conventions.md`, `docs/shortlist.md`.

## 0. Decisions (user, 2026-10-16)
| Topic | Decision |
|---|---|
| Compositor | Auto-detect: Hyprland if GLES ≥ 3.0, else sway |
| Bar/menu | Quickshell where the GPU allows; otherwise a terminal (fzf/gum) renderer of `omarchy-menu.jsonc` |
| Browser | Firefox, tuned, + uBlock Origin (`firefox-ublock-origin`) |
| Web apps | Kept, re-pointed to Firefox tabs/windows instead of Chromium `--app` |
| Office | AbiWord + Gnumeric default; LibreOffice optional |
| Agent | OpenAI Codex CLI (`openai-codex`, Arch extra). User asked about a Vercel agent: none found as a standalone agent CLI; the Vercel CLI only plugs into Codex / Claude Code |
| Image viewer | imv (keep Omarchy default, native Wayland) |
| Shipping | Repo + installer (`omarchy-potato-*` commands, hook, menu extension) |
| Min RAM | 1 GB; zram on by default |
| Testing | 1 GB no-GPU VM (see `vm/`) now, real 2006 hardware later |
| Arch scope | x86_64 only; no 32-bit pre-check — the installer failing is the gate |

Section 6 below is kept as the original option list; the table above supersedes it.

## 1. The hard blocker: Hyprland on 2006 GPUs
- Hyprland 0.50 dropped its legacy renderer and "now requires at least GLES 3.0" (hypr.land/news/update50/; Phoronix: phoronix.com/news/Hyprland-0.50-Released). Before that, a "very, very old PC" needed a `LEGACY_RENDERER` build (wiki.hypr.land/0.42.0/FAQ/); in hyprwm/Hyprland#6973 a GLES 3.0 laptop only worked after the context requirement was rolled back from 3.2 to 3.0.
- Mesa `docs/features.txt` (main, fetched 2026-10-16): **GLES 3.0 DONE only for** freedreno, nv50, nvc0, r600, radeonsi, llvmpipe, softpipe, virgl, zink, d3d12, panfrost, asahi, iris, crocus/gen6+, v3d, etnaviv/HALTI5. That **excludes** the drivers for typical 2006 GPUs: `i915` (Intel GMA 900/950), `crocus` gen4/4.5 (GMA X3000/X3100, G965/GM965), `r300` (Radeon 9500–X1950), `nv30` (GeForce FX/6/7).
- 2006-era GPUs that *do* pass: GeForce 8800 (G80, late 2006 → nv50) and anything newer (Radeon HD 2000+ → r600, Intel Gen6/Sandy Bridge+). These are the exception, not the rule.
- Software fallback: llvmpipe implements GLES 3.x, so Hyprland *can* start without GPU acceleration (Omarchy even ships `default/hypr/toggles/no-animations.lua` "for machines that render on the CPU, like a VM"). On a Core 2 Duo, compositing every frame on the CPU will compete with apps for both cores — **not measured**; must be tested on real hardware.
- Omarchy's own desktop shell (Quickshell, Qt6 Quick) also wants GL; whether it is usable on llvmpipe on such a CPU is untested — open risk.

### Fallback compositor (when GLES < 3.0)
| Option | Arch | Renderer | Fit |
|---|---|---|---|
| **sway** | extra 1.12, MIT | wlroots: GLES2 renderer, or `WLR_RENDERER=pixman` (pure CPU) | i3-style tiling + Wayland: closest to Hyprland keybind muscle memory; works with foot, grim/slurp, wl-clipboard that Omarchy already uses. |
| labwc | extra 0.20.2, GPL-2.0 | wlroots (same as above) | Openbox-style stacking; not tiling — further from Omarchy. |
| i3 (X11) | extra 4.25.1, BSD | none needed (X11, no compositor) | Lowest GPU needs; breaks Wayland-only bits (foot, wl-clipboard, hyprpicker, xdg-desktop-portal-hyprland). |
Recommendation: **detect at install** (`eglinfo`/`glxinfo` GLES version). GLES ≥ 3.0 → stay on Hyprland with potato settings. Otherwise → **sway** with a generated config that mirrors Omarchy's bindings, and replace the Quickshell bar/menu with `waybar`-free minimal pieces (e.g. `swaybar` + a `fzf`/`gum`/`tofi`-based launcher calling the same `omarchy-*` scripts). The menu data (`omarchy-menu.jsonc`) is JSON, so a small script can render it in `fzf`/`gum` in a terminal — that keeps "the menu" independent of Quickshell.

### Potato Hyprland settings (GLES ≥ 3.0 path)
Start from Omarchy's own `toggles/no-animations.lua` (animations, blur, shadow off) and add: gaps 0, rounding 0, opacity 1 (window-opaque toggle), `misc.vfr = true`, no video wallpapers (owe), no glass toggles, no hyprsunset by default. All expressed as a `~/.config/hypr/potato.lua` override so Omarchy updates don't clobber it.

## 2. Memory budget (1–2 GB, HDD)
- `zram-generator` (extra, MIT) with zram ≈ 50–100% of RAM, zstd; swappiness tuned up. HDD swap as last resort.
- Remove from defaults: chromium + all web apps, obsidian, libreoffice-fresh, docker stack, dotnet-runtime, superwhisper, gpu-screen-recorder, moonlight-qt, fcitx5 CJK stack and noto-fonts-cjk (opt-in), tesseract, owe, plymouth, nautilus/sushi. Reuse Omarchy's own `omarchy-remove-preinstalls` for the curated set, then `omarchy-pkg-drop` for the rest.
- Measured gap (box, see shortlist methodology): Chrome 1362 MiB RSS-sum vs Falkon 663 vs NetSurf 109 vs links 14 MB on the same Wikipedia page; LibreOffice Writer 213 vs AbiWord 90 vs Gnumeric 56 MiB; imv 146 vs feh 22 MiB.

## 3. Browser plan
Default **Firefox + uBlock Origin**, tuned (`dom.ipc.processCount` low, disk cache off/ram, session-store interval up, hardware acceleration off on non-GLES3 GPUs); **links/w3m** always installed for agents and quick lookups; **Falkon** offered as alternative (QtWebEngine, measured ~½ Chrome on the box); NetSurf as emergency. qutebrowser shares Falkon's engine (similar cost, keyboard UX). Midori rejected (no Arch package; now a Firefox fork). Firefox's RSS was **not** measured — compare Firefox vs Falkon on target hardware before finalizing.

## 4. Agent-first
- Keep: `omarchy-install-ai-*` / mise-installed agents (claude, codex, copilot, gh, opencode, pi), the `AGENTS.md` conventions, tmux, herdr, nvim, gum menus. The terminal-centric workflow is already the lightest part of Omarchy.
- Default local agent: a **native-binary CLI** (OpenAI Codex `openai-codex` in extra, or `aichat` in extra) against cloud models. Node-based agents (gemini-cli, and Claude Code installs) cost a Node runtime — RAM unmeasured; flag rather than claim.
- Remote mode: `potato agent remote <host>` = `ssh -t host tmux new -A -s agent` (via Tailscale, which Omarchy already installs with `omarchy-install-service-tailscale`) so the heavy agent, its browser tools (Playwright) and builds run on another machine; the potato box is a thin terminal. No local LLMs.

## 5. How to ship
Omarchy's plugin system (`omarchy-plugin-add <git-url>`, `manifest.json`) is for **Quickshell shell plugins** (bar widgets, panels); it does not cover package swaps or compositor changes, and it depends on Quickshell — which may be the thing we have to remove. So:
1. **Primary: a git repo + installer** following Omarchy conventions: `bin/omarchy-potato-*` scripts with `# omarchy:` metadata (`potato enable|disable|status|detect`), using `omarchy-pkg-add` / `omarchy-pkg-drop` / `omarchy-remove-preinstalls`; Hyprland override in `~/.config/hypr/`; menu entries in `~/.config/omarchy/extensions/omarchy-menu.jsonc` (Potato submenu: toggle, swap apps, remote agent).
2. **A `post-update` hook** (`omarchy-hook-install post-update`) to re-apply drops/overrides after `omarchy update` re-adds defaults.
3. **Optional thin shell plugin** (bar widget: RAM/zram/swap meter + toggle) for users who stay on Hyprland+Quickshell, listed on omarchyplugins.com / omahub.dev.
4. Later: an Arch package (`potato-mode` in AUR) or an upstream PR proposing a "low-spec" profile reusing `toggles/no-animations.lua`.
Also needed but out of scope here: whether Omarchy's ISO/installer (limine, btrfs+snapper, LUKS, plymouth) completes on 1 GB RAM/old BIOS (non-UEFI) machines — **not checked**.

## 6. Decisions for the user
1. **Compositor policy:** (a) Hyprland only, require GLES 3.0 GPUs (excludes most 2006 iGPUs); (b) auto-detect, Hyprland if GLES ≥ 3.0 else sway; (c) sway everywhere for predictability.
2. **Keep Quickshell bar/menu**, or replace with a terminal (`fzf`/`gum`) renderer of the same `omarchy-menu.jsonc`?
3. **Default browser:** Firefox+uBlock (compat) vs Falkon (Qt) vs text-first (links) with GUI opt-in.
4. **Web apps (HEY, WhatsApp, Discord, YouTube…):** drop, or keep as Firefox tabs/profiles?
5. **Office default:** AbiWord+Gnumeric vs LibreOffice opt-in-only vs none.
6. **Agent default:** Codex CLI vs aichat vs keep Claude Code; and whether remote-over-SSH is the default mode.
7. **Image viewer:** feh (22 MiB, X11/XWayland) vs keep imv (146 MiB, native Wayland).
8. **Distribution form:** standalone repo+installer (recommended) vs Omarchy plugin vs AUR package vs upstream PR.
9. **Minimum RAM target:** 1 GB or 2 GB (changes whether a GUI browser is default at all).
10. Get real hardware (or a QEMU VM with 1–2 GB and a GLES2-only/llvmpipe config) for the measurements marked n/m.
