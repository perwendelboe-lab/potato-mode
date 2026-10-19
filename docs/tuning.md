# Lightness tuning: measured savings and proposed defaults (2026-10-19)

Status: research + measurements. **Nothing here has been made a default yet.** The proposals at the end need
the user's OK. All figures are **box measurements** in the 1 GB TCG VM (Omarchy 4.0.5 + potato-mode, sway on
llvmpipe, 940 MiB visible). They are single samples of PSS via /proc/PID/smaps_rollup (sudo), unless noted otherwise.

## Baseline: where the memory goes now
Idle, one foot terminal open (raw output: vm/omarchy/raw-*-idle*.txt):

| | stock 4.0.4 (Hyprland + Quickshell) | potato 4.0.4 (sway) | potato 4.0.5 (sway) |
|---|---|---|---|
| `free` used / available | 630 / 313 MiB | 413 / 530 MiB | 434 / 506 MiB |
| zram swap used | 451 MiB | 32 MiB | 14 MiB |
| compositor/shell PSS | Hyprland 83 + quickshell 164 (+329 swapped) | sway 127 + swaybar 6 | sway 119 + swaybar 6 |

Switching compositor and shell was the big win, and potato-mode already does it. Everything below is a much smaller adjustment on top.

## What Omarchy already does (no potato change needed)
Read from the 4.0.5 VM:
- **zram**: zstd, size = RAM. There is also a 944 MiB disk swapfile at priority 0, behind zram (priority 100).
- **sysctl** (`/etc/sysctl.d/99-omarchy-sysctl.conf`): `vm.swappiness=150`, `vm.vfs_cache_pressure=50`,
  `vm.page-cluster=0`, `watermark_boost_factor=0`, `watermark_scale_factor=125`, dirty caps of 64M/256M, writeback every 15 s.
  These are already tuned for zram. **Recommendation: leave them alone.** We have no measurement that beats them.
- zswap is off at runtime (zram is used instead). The Omarchy kernel has BFQ and mq-deadline built in.
- Btrfs mounts use `relatime,compress=zstd:3`. systemd-oomd is enabled. `NetworkManager-wait-online` is masked.

## Services (measured PSS on potato 4.0.5, sway session)
On the sway path, Omarchy's user units **don't start**: omarchy-fcitx5, bt-agent, omarchy-crash-watch,
omarchy-sleep-lock and omarchy-recover-internal-monitor are all inactive. udiskie, fcitx5 and Xwayland aren't running either
(sway starts Xwayland lazily), and docker was removed by potato-mode. So disabling services saves little:

| Service | PSS | Note |
|---|---|---|
| cupsd (cups.service + socket/path) | 0.7 MiB | printing; socket activation would make it ~0 when idle |
| avahi-daemon | 0.7 MiB | mDNS / printer discovery |
| power-profiles-daemon | 0.8 MiB | laptops: keep |
| systemd-oomd | 0.8 MiB | **keep** (protects the session at 1 GB) |
| bluetooth | 0 (inactive, no adapter in VM) | |
| systemd-journald | 15.1 MiB (of which 14.4 file-backed journal mmap, reclaimable) | with `SystemMaxUse=50M, SystemMaxFileSize=8M` + restart: 9.1 MiB |
| sddm + sddm-helper (stay after login) | 7.2 + 9.3 MiB | Removing them means dropping the greeter (TTY login); not proposed |
| polkit-gnome agent | 9.4 MiB | needed for GUI auth prompts |
| xdg-desktop-portal (+document/permission) | 5.5 + 1.3 + 0.8 MiB | needed by Firefox file pickers and the Oma apps |
| gvfsd + metadata, gnome-keyring, at-spi | 2.6 + 1.0, 2.0, 2.2 MiB | at-spi can be turned off (`NO_AT_BRIDGE=1`) if no screen reader is needed |
| wireplumber + pipewire + pulse | 8.1 + 3.4 + 1.7 MiB | audio: keep |
| sway extras: swaybar / mako / swayidle / swaybg | 3.3 / 0.7 / 0.2 / 0.4 MiB | already minimal |

Disabling cups + avahi + ppd together saves about 2–3 MiB. ufw is a oneshot service (no resident process), so there is nothing to gain by disabling it.

## Measured app-level wins
| Setting | Measured | Proposed |
|---|---|---|
| `QT_QUICK_BACKEND=software` (sway/no-GPU path) | Omawrite 175 → 55 MiB, Omacalc 150 → 42 MiB | **default on the sway path**. It only affects Qt Quick apps. Low risk on llvmpipe, which is software anyway; visual effects may look simpler |
| journald caps (`SystemMaxUse=50M`, `SystemMaxFileSize=8M`) | 15.1 → 9.1 MiB PSS (mostly reclaimable cache); also limits disk writes | default (low risk) |
| Drop ufw-docker/docker/tesseract (done in 4.0.5 work) | about 262 MiB disk freed; docker.socket gone | already default |

## Not measured here (no data in this VM; listed with rationale only)
- **I/O scheduler BFQ for rotational disks** (udev rule `ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"`).
  It may improve desktop responsiveness on a 2006 HDD while there is background I/O. The VM disk is virtio (`none`),
  so this can't be measured meaningfully here. **Opt-in.**
- **noatime** instead of relatime. relatime already avoids most atime writes, so the gain is marginal. It means editing fstab. **Opt-in** (or skip).
- **Disable Xwayland** (`xwayland disable` in sway). It saves 0 at idle because Xwayland is lazy. It saves memory only when an X11 app
  would otherwise start, and it breaks X11 apps. **Opt-in.**
- **Firefox further prefs**: `browser.sessionhistory.max_total_viewers=0` (no bfcache of whole pages),
  `image.mem.decode_bytes_at_a_time` and lower `image.mem.surfacecache.max_size_kb`, `network.prefetch-next=false`,
  `browser.urlbar.speculativeConnect.enabled=false`, `media.ffmpeg.vaapi.enabled=false` (already in effect via HW decode off).
  We have no TCG measurement (Firefox runs take too long under TCG). The bfcache and prefetch prefs are low-risk **defaults** to try.
  Measure them with the 3-tab script in vm/ before adding.
- **Fonts/caching**: Omarchy 4 already switched to the lighter JetBrains Mono Nerd font (it saves about 200 MB of disk per the 4.0 notes).
  We found no RAM lever in fontconfig worth taking.
- **Omarchy Hyprland settings** (GPU path): potato.lua already turns off animations, blur, shadows, rounding and gaps, and sets vfr. Static-colour
  wallpaper and theme choice are cosmetic, with no measurement on sway (sway uses a solid colour already).
- **at-spi off** (`NO_AT_BRIDGE=1`, mask at-spi-dbus-bus): about 2 MiB. Opt-in, because it breaks screen readers.

## Proposal: defaults vs `omarchy-potato tune` (opt-in)
**Default (low risk, needs user OK before implementing):**
1. On the sway path, `QT_QUICK_BACKEND=software` in the sway session environment (measured −110…−120 MiB per Qt Quick app).
2. A journald size cap drop-in (measured −6 MiB PSS, plus less disk churn).
3. Firefox: `browser.sessionhistory.max_total_viewers=0`, `network.prefetch-next=false` (unmeasured, low risk).

**`omarchy-potato tune` (new opt-in command, each item listed and revertible):**
- `--no-printing`: disable cups.service/socket/path and avahi (−1.4 MiB measured; turns printing off).
- `--no-bluetooth`: disable bluetooth.service (0 MiB here; saves on machines with an adapter).
- `--hdd`: BFQ udev rule for rotational disks; optionally noatime.
- `--no-xwayland`, `--no-a11y` (at-spi), `--no-power-profiles` (desktops only).

**Never by default:** disabling systemd-oomd, NetworkManager, pipewire, polkit agent or the portals;
changing Omarchy's sysctl/zram values; removing SDDM.
