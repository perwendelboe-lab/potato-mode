# shellcheck shell=bash
# shellcheck disable=SC2034
# Package policy. Arrays are read by omarchy-potato-apply / -disable.

# Heavy Omarchy defaults potato-mode removes (only if installed; failures are tolerated
# per package so a dependency of something else just stays).
POTATO_DROP=(
  chromium
  obsidian
  libreoffice-fresh
  ufw-docker docker docker-buildx docker-compose
  dotnet-runtime
  superwhisper-bin
  gpu-screen-recorder
  moonlight-qt
  omacut
  pinta
  aether
  tesseract-data-eng tesseract
  owe-lockfeed owe
  nautilus-python sushi nautilus
  evince
)

# Lightweight replacements (official repos only).
POTATO_ADD=(
  zram-generator
  mesa-utils
  firefox firefox-ublock-origin
  abiword gnumeric
  aerc
  mpv imv
  yazi nnn
  weechat
  zathura zathura-pdf-poppler  # not -mupdf: libmupdf pulls tesseract (seen in VM)
  neovim
  openai-codex
  links
  fzf gum jq
)

# Extra packages for the sway (no GLES 3.0) path. Quattro moved lock/idle/notify/polkit
# into Quickshell, so sway needs its own.
POTATO_ADD_SWAY=(
  sway swaybg swaylock swayidle
  mako
  polkit-gnome
  foot grim slurp wl-clipboard
  weston
)

POTATO_OPTIONAL_LIBREOFFICE=(libreoffice-still)
