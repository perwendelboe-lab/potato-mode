# Proposal: potato-mode runs on Hypoland, on every GPU

Status: proposal (2026-11-11). Nothing here is implemented. It describes the problem, the facts we have, and the
questions to settle. The design and the code are left to whoever picks it up.

## Summary
potato-mode should install [Hypoland](https://github.com/hegjon/hypoland) in place of the `hyprland` package on every
machine it is enabled on, whatever the GPU. Hypoland is a fork of Hyprland that renders with OpenGL ES 2.0 and runs
Omarchy's own session, greeter and shell. Someone who turns on potato-mode wants the lightest Omarchy desktop that
works, and Hypoland is that on both kinds of GPU:
- **Without OpenGL ES 3.0** it replaces the sway session potato-mode sets up today, with its own bar, menu, lock screen,
  notification daemon, polkit agent and login screen. The user keeps Omarchy's own desktop, not a lookalike of it.
- **With OpenGL ES 3.0** it replaces stock Hyprland. Hypoland's lab measures its compositor at about 70–75 MiB less memory
  and less CPU than stock Hyprland on GLES 3 GPUs too (see "Measured" below).

That leaves potato-mode with one desktop path instead of two.

## Why
- **The sway path is a second desktop to maintain.** It mirrors Omarchy's keybindings by hand (`share/potato-mode/sway/config`),
  renders the Omarchy menu in a terminal (`omarchy-potato-menu`) and brings its own swaylock/swayidle/mako/polkit-gnome,
  because Omarchy 4 moved all of those into Quickshell (see `docs/release-channels.md`). Every Omarchy change to
  bindings, menus or the shell needs work in potato-mode to follow it, or the two paths drift apart.
- **Users on old GPUs get a different Omarchy.** The theme, the bar, the menus, the lock screen, the titlebars, the
  Omarchy skill's Hyprland advice and `hyprctl`-based scripts don't apply on sway (`docs/agent-t3-code.md` and
  `docs/listing.md` note what the sway path can't run).
- **The login screen needs its own workaround.** Omarchy's SDDM greeter runs on Hyprland, so on the sway path potato-mode
  swaps it to weston and changes SDDM's last session.
- **Hypoland targets exactly this hardware.** It is developed on a ThinkPad X200 (Core 2 Duo, GMA 4500MHD, GLES 2 only,
  where stock Hyprland does not start) and runs Omarchy 4 there. That is the kind of machine potato-mode is for.
- **It is lighter on the GLES 3 machines as well.** potato-mode's Hyprland path currently keeps stock Hyprland and only
  turns its effects off (`share/potato-mode/hypr/potato.lua`). Hypoland is lighter with the same config.
- **One path is less to keep working.** Detection, packages, the greeter, the Firefox settings, the tunings, the agent
  texts and the tests each have a sway case and a Hyprland case today.

## What Hypoland is (facts, checked 2026-11-11)
- Fork of Hyprland, BSD-3-Clause. Source and releases: https://github.com/hegjon/hypoland, site: hypoland.org.
  Its README lists what differs from Hyprland (no plugins/hyprpm, no colour management/HDR, screen shaders must be
  GLSL ES 1.00, blur/shadows/animations off by default, Xwayland started on first use).
- Latest release **0.3.0** (2026-11-03), based on Hyprland 0.57.0. Release assets include Arch packages:
  - `hypoland-0.3.0-1-x86_64.pkg.tar.zst`, about 5 MB,
    sha256 `08275db30bb64fb44f159b952b6e42623a10168228e7d6ed501c347989cb634d` (downloaded and checked)
  - `hypoland-0.3.0-1-aarch64.pkg.tar.xz`,
    sha256 `3deaccb3cde85da6f292c094d8f876add3c01d711311948899a52e6cd138a65b` (from the release's digest, not downloaded)
  - It is not in the Arch repos or the AUR.
- From the x86_64 package's `.PKGINFO`: `provides = hyprland=0.57.0`, `wayland-compositor`, `omarchy-hyprland-titlebars`
  and `conflicts = hyprland`, `omarchy-hyprland-titlebars`. Hypoland draws Omarchy's titlebars itself. Its dependencies
  are the usual Hyprland libraries (`hyprutils>=0.14.3`, `hyprgraphics>=0.6.0`, hyprlang, hyprcursor, hyprwire, …).
- It installs `start-hyprland` as a link to its own launcher. Omarchy's greeter config
  (`/etc/sddm.conf.d/10-wayland.conf`: `CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.lua`)
  and Omarchy's session use that name. Hypoland's README says it reads the same config, IPC sockets and
  `XDG_CURRENT_DESKTOP=Hyprland`, and its own test machines log in through SDDM on it.
- Screen recording: gpu-screen-recorder can't start on GLES 2. Hypoland's README recommends `wf-recorder` (extra repo),
  which Omarchy falls back to. potato-mode already removes gpu-screen-recorder.
- On an Omarchy 4.0.x install (an omarchy-dev machine here), the only installed package with a versioned dependency on
  Hyprland was `omarchy-hyprland-titlebars` (`hyprland=0.57.1`), which Hypoland provides and replaces. Others
  (`omarchy-dev`, `omasnap`, `hyprland-preview-share-picker`) depend on plain `hyprland`.

## Measured: Hypoland against stock Hyprland, also on GLES 3 GPUs
From the lab page, https://hypoland.org/lab (checked 2026-11-11). Each machine runs Omarchy with its full session.
The numbers are medians of 8 to 10 fresh sessions per compositor, alternating through the night of 2026-11-10/11:
Hypoland master r957, which is **after the 0.3.0 release** and so not exactly the release package, against Hyprland
0.57.1-2. Memory is the compositor's PSS 60 s after the start (it includes the shell's shared pages). CPU is the
compositor's share of one core. On the X200, stock Hyprland only started with Omarchy's GLES 3 override (omarchy#14764).

| Machine (GPU, Mesa driver, GLES) | Memory, Hypoland / Hyprland | CPU, foot scrolling fast | CPU, workspace switching |
|---|---|---|---|
| ThinkPad X200 (GMA 4500MHD, crocus, GLES 2.0) | 42 / 116 MiB | 9.0% / 14.1% | 4.1% / 7.9% |
| A8-6600K desktop (HD 8570D, r600, GLES 3.1) | 42 / 115 MiB | 2.6% / 14.4% | 3.2% / 7.7% |
| Samsung Series 7 Ultra (HD 4000, crocus, GLES 3.0) | 42 / 117 MiB | 4.3% / 15.9% | 4.0% / 7.8% |
| Chromebook 11 3120 (Bay Trail, crocus, GLES 3.0) | 43 / 115 MiB | 5.2% / 15.1% | 5.6% / 10.9% |
| ThinkPad T550 (HD 5500, iris, GLES 3.2) | 43 / 118 MiB | 3.7% / 13.4% | 3.7% / 7.1% |
| Dell XPS 13 9343 (HD 5500, iris, GLES 3.2) | 43 / 118 MiB | 3.9% / 22.8% | 4.0% / 8.3% |
| ThinkPad T460s (HD 520, iris, GLES 3.2) | 43 / 119 MiB | 3.2% / 9.2% | 3.2% / 6.4% |
| ThinkPad T490 (UHD 620, iris, GLES 3.2) | 43 / 119 MiB | 4.2% / 15.1% | 3.0% / 5.2% |
| Mac mini M1 (G13, asahi, GLES 3.2) | 49 / 124 MiB | 4.5% / 5.5% | 1.0% / 2.2% |
| Galaxy Book4 Edge (Adreno X1-85, freedreno, GLES 3.2) | 43 / 146 MiB | 6.6% / 7.3% | 3.6% / 3.8% |

What this means for potato-mode:
- The compositor uses about **70–75 MiB less** on every GPU in the lab, not only on GLES 2. On a 1 GB machine that is
  about 7% of RAM.
- Eight of the ten machines have GLES 3 GPUs, the ones that get stock Hyprland from potato-mode today. They show the same
  memory saving, which is why this proposal puts Hypoland on every GPU.
- No lab machine is as small as potato-mode's target: the smallest has 4 GB (the X200 6 GB), none has an HDD, and the
  oldest is from 2008. The lab measures the compositor alone, not the whole session, so the saving still has to be
  measured as free memory on a 1 GB machine, the way `docs/tuning.md` does.
- The lab page links raw data per session and the scripts (`docs/baseline/` in the Hypoland repository).

## What it touches in potato-mode today
For orientation only. These are the places that know about the two paths:
- GPU detection: `bin/omarchy-potato-detect` (prints `hyprland` or `sway`), with the choice stored in
  `~/.local/state/potato-mode/compositor`. The GPU still matters for the Firefox software-rendering prefs and for what
  `disable` can safely do, but no longer picks the compositor.
- Hyprland settings: `share/potato-mode/hypr/potato.lua`, some of which Hypoland already has as its defaults.
- Packages: `POTATO_ADD_SWAY` in `share/potato-mode/packages.sh`. Installs only use official repos so far.
- Apply: `bin/omarchy-potato-apply` step 5 (sway config, the `potato-sway.desktop` session, the weston greeter drop-in,
  the autologin session and SDDM's `state.conf`), plus the Firefox software-rendering prefs, which depend on the compositor.
- Files: `share/potato-mode/sway/`, `share/potato-mode/sessions/`, `share/potato-mode/sddm/`, `bin/omarchy-potato-menu`.
- `omarchy-potato tune no-xwayland` (writes into the sway config) and `tune_snippet_sway` in `lib/potato-common.sh`.
- Disable/revert in `bin/omarchy-potato-disable`. Status in `bin/omarchy-potato-status`.
- Agent texts: `share/potato-mode/skills/potato-mode/SKILL.md`, `share/potato-mode/ai/mini-skill.md`.
- Tests in `tests/run.sh` (detection fixtures, the sway path, the menu renderer). README, PROPOSAL.md §0 and the docs
  that mention sway: `testing.md`, `tuning.md`, `listing.md`, `release-channels.md`, `agent-t3-code.md`, `office-gaps.md`.

## Questions to settle
1. **Where the package comes from.** The pinned GitHub release package (and checksum), a pacman repository, an AUR
   package, or a local build. Who bumps the pin when Hypoland releases, and how does that relate to Omarchy's tested range
   (`share/potato-mode/compat`)?
2. **Replacing `hyprland`.** Installing Hypoland removes `hyprland` and `omarchy-hyprland-titlebars`, which is a bigger change
   than anything potato-mode does now. How to do that non-interactively and safely, and what happens if an
   `omarchy update` or an Omarchy migration tries to bring `hyprland` back.
3. **What `disable` does.** On a GLES 3 GPU, stock Hyprland can be put back and works. On a GLES 2 GPU it doesn't start,
   so swapping back leaves no working desktop. Keep Hypoland everywhere, ask, or decide by the GPU?
4. **Existing 0.1.0 installs.** Move them over automatically (from `apply` or the post-update hook) or by hand? This
   includes installs on the Hyprland path, which would switch compositor on their next update. On the sway path, the sway
   session must not disappear before Hypoland works, for example when the hook skips package changes on an untested
   Omarchy version or the download fails.
5. **Software rendering (llvmpipe).** With Hypoland on every GPU these machines get it too, but no lab machine runs a
   whole session on llvmpipe. Hypoland's development uses llvmpipe for nested runs, and its own notes say llvmpipe
   isn't a faithful GLES 2 test. Is a session on llvmpipe usable on a Core 2-class CPU?
6. **Memory on the sway machines.** Quickshell is the heavy part of Omarchy's desktop: about 164 MiB PSS plus 329 MiB
   swapped on stock 4.0.4 in the 1 GB VM (`docs/tuning.md`), against about 131 MiB for the whole sway session. Moving
   those machines from sway to Hypoland brings Quickshell back, so Hypoland's saving over Hyprland may not make it lighter
   than sway there. What is the RAM budget, and does it need measuring before switching?
7. **`QT_QUICK_BACKEND=software`.** The sway session sets it, which made Qt Quick apps about 120 MiB smaller on
   llvmpipe. Without a separate session it would apply to Quickshell too. Keep it, scope it, or drop it?
8. **What to remove.** The terminal menu, the sway config and the weston greeter were only for the sway path. Keep any of
   them as a fallback, for example when Hypoland fails to start? The same for parts of `potato.lua` that duplicate
   Hypoland's defaults.
9. **Architecture.** potato-mode's scope is x86_64. Hypoland also ships aarch64 packages, which would be in or out.
10. **Hypoland differences users notice.** No Hyprland plugins or hyprpm, no colour management or HDR, no blur variants
    beyond the default, screen shaders in GLSL ES 1.00, and `wf-recorder` instead of gpu-screen-recorder for screen
    recording, now on GLES 3 machines too. Does potato-mode say so at `enable`, and do these get any handling?

## Testing needed
- The 1 GB TCG VM (`vm/omarchy/`): enable, login through SDDM, idle memory compared with the sway numbers in
  `docs/testing.md`, the post-update hook during a real `omarchy update`, disable.
- Real GLES 2 hardware. A ThinkPad X200 already runs Hypoland on Omarchy, so it would be the obvious first target for
  potato-mode on top.
- A GLES 3 machine, enable and disable, including putting stock Hyprland back.
- The upgrade from a 0.1.0 sway install.
