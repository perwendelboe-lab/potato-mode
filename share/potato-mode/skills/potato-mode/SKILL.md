---
name: potato-mode
description: >
  Use together with the omarchy skill on machines running potato-mode (old, 1-2 GB RAM, no AVX,
  often no GLES3 GPU). Triggers: potato, low memory, sway fallback, omarchy-potato commands.
---

# potato-mode addendum

- This machine runs potato-mode. Check with `omarchy-potato status`. The compositor is in
  `~/.local/state/potato-mode/compositor` (`sway` on GPUs without GLES3, else `hyprland`).
- On sway, Hyprland-specific advice does not apply. Edit `~/.config/sway/config` instead.
- RAM is 1-2 GB with zram and an HDD. Never suggest Chromium, Electron apps, Docker or other heavy
  software. Prefer Firefox (tuned), links/w3m, foot, imv, zathura, AbiWord/Gnumeric.
- Re-apply potato settings after edits that Omarchy overwrote: `omarchy-potato apply`.
- Optional local model: `omarchy-potato ai status`. Quick local questions: `omarchy-potato-ask "<q>"`.
