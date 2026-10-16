#!/bin/bash
# Omarchy 4.0.4 in a 1 GB, no-3D VM. TCG (KVM hangs on this host). UEFI (limine needs it).
# Control: QEMU monitor at /tmp/omarchy-mon.sock (sendkey, screendump); ssh on 127.0.0.1:2223 once enabled.
cd "$(dirname "$0")"
iso=()
[[ ${1:-} == "--iso" ]] && iso=(-cdrom omarchy-4.0.4.iso -boot d)
exec qemu-system-x86_64 -machine q35 -accel tcg,thread=multi -cpu max -smp 4 -m 1024 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive file=omarchy.qcow2,if=virtio "${iso[@]}" \
  -device virtio-vga -display none -device virtio-rng-pci \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 \
  -monitor unix:/tmp/omarchy-mon.sock,server=on,wait=off -daemonize
