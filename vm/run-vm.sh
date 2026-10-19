#!/bin/bash
# 1 GB RAM, 2 vCPU, KVM, virtio-gpu WITHOUT virgl (guest Mesa falls back to llvmpipe), ssh on host :2222
set -euo pipefail
cd "$(dirname "$0")"

# Build the cloud-init seed at every launch from the committed templates (no secrets in git).
# Needs cloud-localds, xorriso or genisoimage.
# - injects id_ed25519.pub (key generated if missing, .pub re-derived if only it is missing; both gitignored);
# - the arch user's password stays locked (ssh key only), unless VM_CONSOLE_PASSWORD=1, which sets a random
#   password for serial-console login, kept in .console-password (0600, gitignored, reused on later launches);
# - instance-id = hash of the rendered user-data, so cloud-init re-runs on an existing disk whenever it changes.
umask 077
[[ -f id_ed25519 ]] || ssh-keygen -q -t ed25519 -N '' -f id_ed25519
[[ -f id_ed25519.pub ]] || ssh-keygen -y -f id_ed25519 >id_ed25519.pub
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pubkey=$(<id_ed25519.pub)
bs='\' q='"'
pubkey=${pubkey//"$bs"/"$bs$bs"}; pubkey=${pubkey//"$q"/"$bs$q"}   # YAML double-quoted string escaping
template=$(<user-data)
placeholder=REPLACE_WITH_id_ed25519.pub
repl="\"$pubkey\""
rendered=${template//"$placeholder"/"$repl"}   # quoted: no & or backslash processing (bash 5.2 patsub)
if [[ ${VM_CONSOLE_PASSWORD:-0} == 1 ]]; then
  if [[ -s .console-password ]]; then
    pw=$(<.console-password)
  else
    pw=$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 20)
    printf '%s\n' "$pw" >.console-password
  fi
  chmod 600 .console-password
  rendered=${rendered//lock_passwd: true/lock_passwd: false}
  rendered+=$'\n'"chpasswd:"$'\n'"  expire: false"$'\n'"  users: [{name: arch, password: \"$pw\", type: text}]"
  echo "console password for arch: see $(pwd)/.console-password" >&2
else
  rm -f .console-password
fi
printf '%s\n' "$rendered" >"$tmp/user-data"
{ echo "instance-id: potato2-$(sha256sum "$tmp/user-data" | cut -c1-12)"; grep -v '^instance-id:' meta-data; } >"$tmp/meta-data"
rm -f seed.img
if command -v cloud-localds >/dev/null; then
  cloud-localds seed.img "$tmp/user-data" "$tmp/meta-data"
elif command -v xorriso >/dev/null; then
  xorriso -as mkisofs -quiet -output seed.img -volid cidata -joliet -rock "$tmp/user-data" "$tmp/meta-data"
elif command -v genisoimage >/dev/null; then
  genisoimage -quiet -output seed.img -volid cidata -joliet -rock "$tmp/user-data" "$tmp/meta-data"
else
  echo "need cloud-localds, xorriso or genisoimage to build seed.img" >&2; exit 1
fi
chmod 600 seed.img
ACCEL=${ACCEL:-tcg}  # KVM device exists on this box but guests hang with zero CPU time (nested KVM broken) -> TCG
trap - EXIT; rm -rf "$tmp"
exec qemu-system-x86_64 -machine q35,accel=${ACCEL:-tcg} -cpu max -smp 2 -m 1024 \
  -drive file=base.qcow2,if=virtio -drive file=seed.img,if=virtio,format=raw \
  -device virtio-vga -display none \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 -serial unix:/tmp/potato-serial.sock,server=on,wait=off -device virtio-rng-pci "$@"
