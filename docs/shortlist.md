# potato-mode app shortlist

> Final picks per user decisions (2026-10-16): Firefox+uBlock, AbiWord+Gnumeric (LibreOffice optional), **imv** (not feh), Codex CLI. See PROPOSAL.md §0.

Target: ~2006 x86_64 PCs (Core 2 Duo / Athlon 64, 1–2 GB RAM, HDD, GMA 950/X3000, Radeon X1x00, GeForce 6/7).

## How numbers were obtained
- **Box measurement** = measured on 2026-10-16 (Paris) on the agent box: Debian 13 x86_64, 8 vCPU, 16 GB RAM, **Xvfb X11 :9 1280x800, no GPU**, Debian package versions (not Arch's). Not a 2006 machine; absolute numbers will differ, relative ordering is the useful part.
- GUI apps: launched, idle 15 s with the stated content loaded, then **sum of RSS over the process tree** (`ps -o rss`). RSS sums over-count shared libraries for multi-process apps (Chrome, Falkon), so they're upper bounds. Content: en.wikipedia.org/wiki/Arch_Linux for browsers; 2000x1500 JPEG for image viewers; 5-page arXiv PDF (1706.03762) for PDF viewers; 720p H.264 10 s loop for mpv; empty documents for office apps.
- CLI browsers: `/usr/bin/time -v <b> -dump <wiki url>` maximum RSS.
- TUIs: started in a pty via `script`, idle 4 s, RSS.
- "n/m" = not measured (couldn't run on the box); no number is invented.
- Availability/licence: archlinux.org packages JSON API and AUR RPC v5, queried 2026-10-16.

## Browser (biggest problem)
| Candidate | Arch | Licence | Box measurement | Notes |
|---|---|---|---|---|
| Google Chrome (baseline for Omarchy's Chromium) | chromium in extra | BSD-ish | **1362 MiB RSS-sum, 11 procs** (Chrome 155) | Omarchy default + all web apps. Unusable at 1–2 GB. |
| Falkon | extra 26.08.2 | GPL-2.0+ | **663 MiB RSS-sum, 5 procs** (private mode) | QtWebEngine = Chromium engine; Wayland native via Qt. |
| qutebrowser | extra 3.7.0 | GPL-3.0 | n/m (same QtWebEngine engine as Falkon, expect similar class) | Keyboard-driven, config in Python — fits Omarchy's CLI/vim feel. |
| Firefox (tuned) | extra 158.0 | MPL-2.0 | n/m | Omarchy already has a Firefox path in `omarchy-install-browser`. Tune: `dom.ipc.processCount`, `browser.sessionstore.interval`, `browser.cache.disk.enable=false`, uBlock Origin (`firefox-ublock-origin`, extra 1.75.0, GPL-3.0+). |
| NetSurf | extra 3.11 | GPL-2.0 / MIT | **109 MiB RSS** (GTK, 1 proc) | Own engine, no real JS → many modern sites break. X11/GTK; runs under XWayland. |
| Midori | **not in Arch or AUR** (only `midori-bin` 11.9.1, 4 votes) | MPL | n/m | Old WebKitGTK Midori is dead (Buildroot dropped it 2024: lists.busybox.net/pipermail/buildroot/2024-August/761385.html); current Midori is a Firefox/Floorp fork (github.com/goastian/midori-desktop) — no lighter than Firefox. Reject. |
| links / w3m / lynx | core 2.30 / extra 0.5.6 / extra 2.9.3 | GPL-2.0+ / w3m / GPL-2.0 | **links 13.9 MB, lynx 14.8 MB, w3m 17.2 MB** max RSS dumping the wiki page | Text-only; ideal for agents, docs, man-like reading. |

**Pick:** two-tier. Default GUI = **Firefox (tuned) + uBlock Origin**, one engine, multi-process count capped; **links/w3m** as the always-installed text browser and the one the agent uses. Offer **Falkon** as the "Qt/Chromium engine, lower than Chrome" option (measured ~half of Chrome here). NetSurf as an emergency browser for simple sites. Web apps (HEY, WhatsApp, etc.) must be removed or repointed — each is a Chromium instance. Reasoning: Firefox measured nothing here, so its RAM edge over Falkon is unverified — **measure on real hardware before locking**.

Mitigations: `zram-generator` (extra 1.2.1, MIT) for compressed swap in RAM — critical on 1–2 GB with an HDD; uBlock Origin cuts page weight; disable Chromium GPU compositing on unsupported GPUs (`--disable-gpu`) since old GPUs are on the driver blocklist anyway.

## Office
| Candidate | Arch | Licence | Box measurement |
|---|---|---|---|
| LibreOffice (Omarchy ships libreoffice-fresh) | extra (still 26.2.6) | LGPL-3.0+/MPL-2.0 | **213 MiB RSS-sum, 2 procs** (Writer, empty, LO 25.2) |
| AbiWord | extra 3.0.8 | GPL-2.0+ | **90 MiB** (empty) |
| Gnumeric | extra 1.12.62 | GPL | **56 MiB** (empty) |
**Pick:** AbiWord + Gnumeric by default; LibreOffice as opt-in for .docx/.pptx fidelity.

## Mail
| Candidate | Arch | Licence | Box measurement |
|---|---|---|---|
| aerc | extra 0.22.0 | GPL-3.0 | **24 MiB** idle (no account) |
| neomutt | extra 20260616 | GPL-2.0 | **15 MiB** idle (no account) |
| Claws Mail (GUI) | extra 4.4.0 | GPL-3.0+ | n/m |
**Pick:** aerc (modern TUI, simpler setup, agent-scriptable). Omarchy's default "mail" is the HEY web app (Chromium) — drop it.

## Media player
mpv (already Omarchy default; extra 0.41.0, GPL-2.0+/LGPL-2.1+): **153 MiB** box (x11 vo, 720p loop), **109 MiB** with `--vo=tct` (terminal). VLC (extra 3.0.24) n/m. **Pick: keep mpv**, ship `hwdec=no`/`profile=fast`, and yt-dlp format cap ≤480p (Core 2 can't software-decode modern 1080p H.264/VP9 reliably — not measured here; verify on hardware).

## Image viewer
imv (Omarchy default, extra 5.0.1, MIT): **146 MiB** (imv-x11, 2000x1500 JPEG). feh (extra 3.13.1, MIT): **22 MiB** same image. **Pick: feh** under XWayland, or keep imv if a native-Wayland viewer matters more than ~120 MiB.

## File manager
| Candidate | Arch | Licence | Box measurement |
|---|---|---|---|
| yazi | extra 26.9.1 | MIT | n/m (Rust TUI) |
| nnn | extra 5.3 | BSD-2 | **3 MiB** idle |
| PCManFM (GUI) | extra 1.4.0 | GPL-2.0+ | n/m (failed to stay up on the box) |
| Thunar (GUI) | extra 4.20.10 | GPL-2.0+ | n/m |
**Pick:** yazi (themable, Omarchy-style TUI) with nnn as the minimal fallback; Thunar if a GUI is required. Replace Nautilus (+sushi, gvfs, tracker deps).

## Chat
weechat (extra 4.10.1, GPL-3.0): **13 MiB** idle. irssi (extra 1.4.5), profanity (XMPP, extra 0.18.2), Dino (extra 0.5.1, GTK XMPP): n/m. **Pick: weechat** (IRC + Matrix via plugin). Slack/Discord/WhatsApp have no light native client — web via Firefox only, accept the cost, or bridge (open decision).

## PDF
zathura (extra 2026.10.4, Zlib): **68 MiB** (5-page PDF). mupdf (extra 1.28.5, AGPL-3.0): n/m (no window stayed). Evince (Omarchy default): n/m. **Pick: zathura** (vim keys, matches Omarchy).

## Notes
Omarchy ships Obsidian (Electron, i.e. a bundled Chromium). Candidates: nvim + markdown folder (already in Omarchy, `omarchy-nvim`), Xournal++ (extra 1.3.8, GPL-2.0+, for handwriting), plain `nano` (core 9.2). Not measured. **Pick: nvim/markdown in `~/notes`** — same files Obsidian would open, zero extra RAM.

## Terminal tools
Keep Omarchy's: foot (extra 1.28.0, MIT; Wayland, CPU-rendered), tmux 3.8, neovim 0.12.6, btop 1.4.7, fzf/rg/fd/eza/bat/zoxide, lazygit. Not measured individually; all native binaries. Drop docker (and its daemon) from defaults.

## AI agent CLI
| Candidate | Arch | Licence | Runtime | Box measurement |
|---|---|---|---|---|
| aichat | extra 0.30.0 | MIT OR Apache-2.0 | Rust single binary | n/m |
| OpenAI Codex CLI | extra `openai-codex` 0.163.0 | Apache-2.0 | native (deps: glibc, ripgrep, sqlite, bubblewrap…, no nodejs) | n/m |
| opencode | AUR `opencode-bin` 1.19.2 | MIT | binary | n/m |
| Claude Code | AUR `claude-code` 2.1.301 | proprietary (LicenseRef) | Omarchy installs via mise | n/m |
| gemini-cli | extra 0.64.0 | Apache-2.0 | Node.js | n/m |
| Local models (ollama, extra 0.40.4, MIT) | — | — | — | impractical: 1–2 GB RAM cannot hold useful models and Core 2/Athlon 64 predate AVX (not benchmarked here); rule out |
**Pick:** keep Omarchy's agent launchers but default to **Codex CLI or aichat (native)** with cloud models; run heavier agents (Claude Code, opencode) **remotely over SSH/tmux** on a bigger machine (Omarchy ships tailscale installer). Must measure RSS of each agent on the box before claiming "lightweight".
