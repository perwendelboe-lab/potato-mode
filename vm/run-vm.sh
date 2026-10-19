#!/bin/bash
# 1 GB RAM, 2 vCPU, KVM, virtio-gpu WITHOUT virgl (guest Mesa falls back to llvmpipe), ssh on host :2222
cd "$(dirname "$0")"
set -euo pipefail

# Build the cloud-init seed at launch from the committed template (no secrets in git):
# - injects id_ed25519.pub (generated here if missing; gitignored),
# - the arch user's password stays locked (ssh key only), unless VM_CONSOLE_PASSWORD=1, which
#   sets a random password for serial-console login and stores it in .console-password (0600, gitignored).
[[ -f id_ed25519 ]] || ssh-keygen -q -t ed25519 -N '' -f id_ed25519
umask 077
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pubkey=$(<id_ed25519.pub)
sed "s|REPLACE_WITH_id_ed25519.pub|\"$pubkey\"|" user-data >"$tmp/user-data"
if [[ ${VM_CONSOLE_PASSWORD:-0} == 1 ]]; then
  pw=$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 20)
  printf '%s\n' "$pw" >.console-password
  sed -i 's/lock_passwd: true/lock_passwd: false/' "$tmp/user-data"
  printf 'chpasswd:\n  expire: false\n  users: [{name: arch, password: "%s", type: text}]\n' "$pw" >>"$tmp/user-data"
  echo "console password for arch: see $(pwd)/.console-password" >&2
else
  rm -f .console-password
fi
cp meta-data "$tmp/meta-data"
if command -v cloud-localds >/dev/null; then
  cloud-localds seed.img "$tmp/user-data" "$tmp/meta-data"
elif command -v xorriso >/dev/null; then
  xorriso -as mkisofs -quiet -output seed.img -volid cidata -joliet -rock "$tmp/user-data" "$tmp/meta-data"
elif command -v genisoimage >/dev/null; then
  genisoimage -quiet -output seed.img -volid cidata -joliet -rock "$tmp/user-data" "$tmp/meta-data"
else
  echo "need cloud-localds, xorriso or genisoimage to build seed.img" >&2; exit 1
fi
ACCEL=${ACCEL:-tcg}  # KVM device exists on this box but guests hang with zero CPU time (nested KVM broken) -> TCG
trap - EXIT; rm -rf "$tmp"
exec qemu-system-x86_64 -machine q35,accel=${ACCEL:-tcg} -cpu max -smp 2 -m 1024 \
  -drive file=base.qcow2,if=virtio -drive file=seed.img,if=virtio,format=raw \
  -device virtio-vga -display none \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 -serial unix:/tmp/potato-serial.sock,server=on,wait=off -device virtio-rng-pci "$@"
