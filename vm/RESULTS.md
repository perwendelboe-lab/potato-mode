# 1 GB no-GPU VM results (2026-10-16, Paris time)

## Setup
- Host: the agent box (Debian 13, 8 vCPU). `/dev/kvm` exists but guests hung with zero CPU time under `accel=kvm` (nested KVM unusable) → **TCG (software CPU emulation)**. So **memory figures are meaningful, timing/CPU figures are not** (everything is many times slower than real hardware).
- Guest: official Arch cloud image (`Arch-Linux-x86_64-cloudimg.qcow2`), 1024 MB RAM (951 MiB visible), 2 vCPU, 512 MiB swapfile (image default; **no zram** in this run), `virtio-vga` **without virgl** → Mesa `llvmpipe (LLVM 23.1.1, 256 bits)` for GL/GLES (confirmed via `eglinfo -B -p gbm`). Versions: `raw-versions.txt`.
- Fixes needed: `systemd-time-wait-sync` blocked boot (no NTP) → masked; pacman keyring had to be initialised.
- **Not Omarchy**: plain Arch + hyprland, sway, foot, firefox(+uBlock), qutebrowser, openai-codex (`provision.sh`). The full Omarchy install was not attempted: it pulls in Chromium, Docker, LibreOffice, Obsidian etc. and would take hours under TCG on 1 GB, which isn't worth it before potato-mode exists.

## Method (`measure.sh`)
Compositor started from SSH via seatd on the virtual DRM device, idle 60 s; memory = **sum of PSS** (`/proc/<pid>/smaps_rollup`, via sudo because sway/Hyprland are non-dumpable) over the process tree, plus `free -m` system figures. Apps launched inside sway (gles2/llvmpipe). First script version counted threads as processes (inflated to 838 MiB) — discarded.

## Results (`raw-m-all.txt`)
| What | PSS | System after (used / avail / swap used) |
|---|---|---|
| Boot baseline, no GUI | — | 321 MiB / 629 / 0 |
| **Hyprland 0.56.2 on llvmpipe**, idle, minimal potato config | **240 MiB** (2 procs) | 495 / 456 / 0 |
| **sway 1.12, gles2 on llvmpipe**, idle | **120 MiB** (1 proc) | 369 / 582 / 17 |
| **sway, `WLR_RENDERER=pixman`** (no GL), idle | **16 MiB** (1 proc) | 326 / 624 / 0 |
| **Firefox 158**, fresh profile, 3 tabs (Wikipedia Arch_Linux, archlinux.org, github.com/basecamp/omarchy), 180 s | **391 MiB** (10 procs) | 838 / 113 / **296** |
| **qutebrowser 3.7**, 1 tab (Wikipedia), 120 s | **453 MiB** (5 procs) | 675 / 275 / 48 |
| **Codex CLI 0.163** (unauthenticated, TUI start screen), 20 s | **72 MiB RSS** | — |

Caveats:
- Firefox pushed ~296 MiB into swap; PSS doesn't count swapped-out pages, so the 391 MiB is a lower bound of Firefox's real footprint. Under TCG it's not verified that all 3 tabs finished rendering.
- qutebrowser was measured with 1 tab, not 3, and still used more than Firefox with 3.
- Codex was not logged in and ran no task; a real session will be larger. A first attempt was OOM-killed — that was the harness (`script` buffering `/dev/zero`, 738 MB anon in `script` itself), not Codex.
- The sway pixman run's 16 MiB is with no clients; drawing cost moves to the CPU.

## Takeaways
- At 1 GB, Hyprland on llvmpipe costs ~2× sway-gles2 and ~15× sway-pixman before any app is open; with Firefox plus 3 tabs on top, Hyprland would already be in heavy swap (not measured together).
- Firefox with 3 tabs fills 1 GB on its own → zram (on by default per decision) is required, and tab limits / an auto-discard tab setting should be part of the Firefox tuning.
- Firefox beats qutebrowser here, which supports the Firefox decision.
