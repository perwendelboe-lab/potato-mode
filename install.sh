#!/bin/bash
# Install potato-mode for the current user: copies the repo to ~/.local/share/potato-mode
# and links omarchy-potato* into ~/.local/bin. Then run: omarchy-potato enable --dry-run
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
dest=${POTATO_INSTALL_DIR:-$HOME/.local/share/potato-mode}
bindir=${POTATO_BIN_DIR:-$HOME/.local/bin}
if [[ ${1:-} == "--uninstall" ]]; then
  rm -f "$bindir"/omarchy-potato*
  rm -rf "$dest"
  echo "potato-mode files removed (run 'omarchy-potato disable' first to revert changes)"
  exit 0
fi
mkdir -p "$dest" "$bindir"
cp -a "$src"/bin "$src"/lib "$src"/share "$src"/hooks "$src"/VERSION "$src"/LICENSE "$dest"/
for f in "$dest"/bin/omarchy-potato*; do
  ln -sf "$f" "$bindir/$(basename "$f")"
done
echo "installed to $dest; commands linked in $bindir"
case ":$PATH:" in *":$bindir:"*) ;; *) echo "note: add $bindir to PATH" ;; esac
echo "next: omarchy-potato enable --dry-run"
