#!/bin/bash
# 1 GB RAM, 2 vCPU, KVM, virtio-gpu WITHOUT virgl (guest Mesa falls back to llvmpipe), ssh on host :2222
cd "$(dirname "$0")"
ACCEL=${ACCEL:-tcg}  # KVM device exists on this box but guests hang with zero CPU time (nested KVM broken) -> TCG
exec qemu-system-x86_64 -machine q35,accel=${ACCEL:-tcg} -cpu max -smp 2 -m 1024 \
  -drive file=base.qcow2,if=virtio -drive file=seed.img,if=virtio,format=raw \
  -device virtio-vga -display none \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 -serial unix:/tmp/potato-serial.sock,server=on,wait=off -device virtio-rng-pci "$@"
