#!/bin/bash
# Run inside the VM: Arch + both compositors + test apps (not full Omarchy)
set -e
sudo pacman-key --init && sudo pacman-key --populate archlinux
sudo pacman -Syu --noconfirm --needed hyprland sway seatd mesa mesa-utils foot firefox firefox-ublock-origin qutebrowser python-adblock openai-codex xorg-xwayland wlr-randr grim ttf-dejavu
sudo systemctl enable --now seatd
sudo usermod -aG seat,video,input arch
echo PROVISION_DONE
