# Could omarchy-t3-code replace Codex CLI as the default agent? (2026-10-16)

**Verdict: no.** Keep Codex CLI. omarchy-t3-code is a *front end* for T3 Code, which in turn *drives* Codex or another agent CLI. It adds hundreds of MiB on top of Codex and replaces none of it. It also needs Omarchy's Quickshell shell and Qt6 WebEngine, which potato-mode's sway path does not run.

## What it is
- **avillagran/omarchy-t3-code** (ref clone `/workspace/ref/omarchy-t3-code` @ 97bdbbd), MIT licence, a community project.
  - A Quickshell/QML bar panel with a Rust backend (`crates/t3-protocol`). It is a client for a **T3 Code server**.
  - Its installer refuses to run unless T3 Code is already installed and opened once (`~/.t3/bin/t3`, install.sh:11).
  - The installer pulls in `rust base-devel qt6-declarative qt6-webengine …` and compiles the plugin on the machine.
  - It binds Super+Shift+A, and restarts the Omarchy shell when done.
- **pingdotgg/t3code** (MIT) calls itself an "agent harness control surface", with web, Electron desktop and mobile apps.
  - Its README says a provider must already be installed and logged in: Codex CLI (`codex login`), Claude Code, Cursor, Grok Build, OpenCode or Antigravity.
  - **So Codex CLI is still required underneath.**
- **Arch packages:** none in the official repos. The AUR has `t3code-bin` 0.1.0 (Electron app; depends on gtk3, nss, mesa, …) and `t3code-nightly-bin`. The CLI server comes from `t3.codes/install.sh` or `npx t3`.

## Runtime needs vs potato-mode
| Need | omarchy-t3-code | potato-mode fit |
|---|---|---|
| Desktop shell | Omarchy Quickshell (Qt6/QML) bar plugin; Hyprland bindings | **No** on the sway path (no GLES3). On Hyprland it works, but Quickshell is the heavy part we try to minimise. |
| GPU/GL | QML `MultiEffect`/`ShaderEffect` in the UI; HTML preview through **QtWebEngine (Chromium)**, which it runs offscreen with `--disable-gpu` and a software Quick backend | Shader effects want GL. QtWebEngine is a full Chromium engine, the thing potato-mode removes. |
| Server | `t3` server: a Node single-executable binary (~159 MiB file), plus the agent CLI | Extra resident process; nothing is replaced. |
| Agent | Codex CLI / Claude Code / … | Codex stays. |
| Omarchy skill | Not provided. The agent (Codex) reads `~/.agents/skills` itself; T3 lists "skills and commands" from the provider. | Same skill as today, through Codex. No gain. |

## RAM (box measurement, Debian box, 16 GB, 2026-10-16)
`npx t3@latest --no-browser` (t3 v0.1.0), idle, no session, no client connected:
- `t3` server binary: **392 MiB RSS**
- npm/node launcher wrappers (only when started through npx): 79 + 50 MiB
- resource monitor: 3 MiB
- total via npx: ~525 MiB; installed `t3` alone: ~395 MiB

The QML panel and its QtWebEngine helper were not measured, because they need Quickshell and a Wayland session. Expect the panel (Qt6 + QML) to add well over 100 MiB more. That figure is an estimate, not a measurement.

Compare Codex CLI at **72 MiB RSS**, measured earlier in the 1 GB VM. T3 would mean roughly **72 + ~395 MiB (server) + the panel**, at least about 6× the agent footprint, on a machine with 1 GB.

## Not verified
- Whether the Node SEA `t3` binary runs on pre-SSE4.2 CPUs (Merom Core 2). Not tested.
- The panel's real RSS, and whether it works on llvmpipe at all.

## Recommendation
- Keep **Codex CLI** (TUI in foot) as the default, with the Omarchy and potato-mode skills in `~/.agents/skills`.
- Do not ship omarchy-t3-code.
- At most, document T3 as "use it from *another* machine": the T3 web or mobile app can drive a remote T3 server over Tailscale. That moves the cost off the potato. It still requires the `t3` server (~395 MiB) on whichever machine runs the agent, so it only helps when the agent runs elsewhere.
