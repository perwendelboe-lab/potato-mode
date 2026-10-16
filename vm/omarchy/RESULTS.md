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
