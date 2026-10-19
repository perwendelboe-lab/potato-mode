# shellcheck shell=bash
# Shared helpers for omarchy-potato-* commands. Sourced, not executed.

POTATO_ROOT=${POTATO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
POTATO_SHARE=${POTATO_SHARE:-$POTATO_ROOT/share/potato-mode}
POTATO_STATE=${POTATO_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/potato-mode}
POTATO_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
# Opt-in tunings (omarchy-potato tune) keep their own state so `disable` can revert them separately.
POTATO_TUNE_STATE=${POTATO_TUNE_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/potato-mode-tune}
export POTATO_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
POTATO_DRY_RUN=${POTATO_DRY_RUN:-0}
POTATO_QUIET=${POTATO_QUIET:-0}
# Prefix for system paths (tests point this at a temp dir).
POTATO_SYSROOT=${POTATO_SYSROOT:-}
POTATO_MARK_BEGIN="potato-mode:begin"
POTATO_MARK_END="potato-mode:end"

# shellcheck source=/dev/null
source "$POTATO_SHARE/packages.sh"
# shellcheck source=/dev/null
source "$POTATO_SHARE/compat"

say() {
  (( POTATO_QUIET )) && return 0
  if (( POTATO_DRY_RUN )) && [[ $1 != would* ]]; then
    echo "potato: (dry-run) $*"
  else
    echo "potato: $*"
  fi
}

warn() {
  echo "potato: warning: $*" >&2
}

die() {
  echo "potato: error: $*" >&2
  exit 1
}

# Run a command, or print it in dry-run mode.
run() {
  if (( POTATO_DRY_RUN )); then
    printf 'DRY-RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# Run as root (sudo unless already root).
run_root() {
  if (( EUID == 0 )); then
    run "$@"
  else
    run sudo "$@"
  fi
}

have() {
  command -v "$1" >/dev/null 2>&1
}

pkg_installed() {
  pacman -Q -- "$1" >/dev/null 2>&1
}

state_init() {
  run mkdir -p "$POTATO_STATE/backups"
}

# Append a line to a state list once.
state_add() {
  local file="$POTATO_STATE/$1" line="$2"
  (( POTATO_DRY_RUN )) && return 0
  mkdir -p "$POTATO_STATE"
  touch "$file"
  grep -qxF -- "$line" "$file" || echo "$line" >>"$file"
}

state_list() {
  local file="$POTATO_STATE/$1"
  [[ -f $file ]] && cat "$file"
  return 0
}

# Back up a file once (first backup wins, so re-applies never overwrite the original).
backup_file() {
  local src="$1" dest
  [[ -e $src ]] || return 0
  dest="$POTATO_STATE/backups${src}"
  [[ -e $dest ]] && return 0
  if (( POTATO_DRY_RUN )); then
    say "would back up $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a -- "$src" "$dest"
  state_add backups.list "$src"
}

restore_file() {
  local src="$1" dest="$POTATO_STATE/backups$1"
  if [[ -e $dest ]]; then
    run cp -a -- "$dest" "$src"
  fi
}

# Write content (stdin) to a file only if it differs. Returns 0 if changed.
write_if_changed() {
  local target="$1" tmp
  tmp=$(mktemp)
  cat >"$tmp"
  if [[ -f $target ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    return 1
  fi
  if (( POTATO_DRY_RUN )); then
    say "would write $target"
    rm -f "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  # Only back up files potato-mode didn't create/own already; otherwise a later
  # re-apply would "back up" potato's own older version as the original.
  if ! grep -qxF -- "$target" "$POTATO_STATE/written.list" 2>/dev/null; then
    backup_file "$target"
  fi
  if [[ -e $target ]]; then
    chmod --reference="$target" "$tmp"
  else
    chmod 644 "$tmp"
  fi
  mv -- "$tmp" "$target"
  state_add written.list "$target"
  return 0
}

# Replace (or append) a marked block in a file. Block content on stdin.
# $1 file, $2 comment prefix (e.g. "--" or "//" or "#")
set_marked_block() {
  local file="$1" c="$2" block tmp
  block=$(cat)
  tmp=$(mktemp)
  if [[ -f $file ]]; then
    awk -v b="$c $POTATO_MARK_BEGIN" -v e="$c $POTATO_MARK_END" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip { print }' "$file" >"$tmp"
  fi
  printf '%s\n%s\n%s\n' "$c $POTATO_MARK_BEGIN" "$block" "$c $POTATO_MARK_END" >>"$tmp"
  write_if_changed "$file" <"$tmp" || true
  rm -f "$tmp"
}

remove_marked_block() {
  local file="$1" c="$2" tmp
  [[ -f $file ]] || return 0
  grep -qF -- "$c $POTATO_MARK_BEGIN" "$file" || return 0
  tmp=$(mktemp)
  awk -v b="$c $POTATO_MARK_BEGIN" -v e="$c $POTATO_MARK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }' "$file" >"$tmp"
  if (( POTATO_DRY_RUN )); then
    say "would remove potato block from $file"
    rm -f "$tmp"
  else
    mv -- "$tmp" "$file"
  fi
}

# Compare dotted versions: version_ge A B -> true if A >= B
version_ge() {
  if have vercmp; then
    (( $(vercmp "$1" "$2") >= 0 ))
  else
    [[ $(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1) == "$2" ]]
  fi
}

version_lt() {
  ! version_ge "$1" "$2"
}

# Strip whole-line // comments (Omarchy's JSONC dialect) for jq.
# Also drops trailing commas, which Omarchy's shipped menu uses.
jsonc_to_json() {
  sed -E '/^[[:space:]]*\/\//d' "$1" | sed -zE 's/,([[:space:]]*[]}])/\1/g'
}

# Install stdin as a root-owned file if it differs. Records it for revert.
root_write_if_changed() {
  local target="$1" tmp
  tmp=$(mktemp)
  cat >"$tmp"
  if [[ -f $target ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    return 1
  fi
  if [[ -e $target ]] && ! grep -qxF -- "$target" "$POTATO_STATE/root-written.list" 2>/dev/null; then
    backup_root_file "$target"
  fi
  run_root install -Dm644 "$tmp" "$target"
  rm -f "$tmp"
  state_add root-written.list "$target"
  return 0
}

backup_root_file() {
  local src="$1" dest="$POTATO_STATE/backups$1"
  [[ -e $dest ]] && return 0
  (( POTATO_DRY_RUN )) && return 0
  mkdir -p "$(dirname "$dest")"
  cp -- "$src" "$dest"
  state_add root-backups.list "$src"
}

pkg_add() {
  if have omarchy-pkg-add; then
    run omarchy-pkg-add "$@"
  else
    run_root pacman -S --noconfirm --needed -- "$@"
  fi
}

pkg_drop() {
  if have omarchy-pkg-drop; then
    run omarchy-pkg-drop "$@"
  else
    run_root pacman -Rns --noconfirm -- "$@"
  fi
}
pkg_drop_one() { pkg_drop "$1"; }

# Firefox profile directories from profiles.ini (legacy and XDG locations).
firefox_profile_dirs() {
  local base ini path rel
  for base in "$HOME/.mozilla/firefox" "$POTATO_CONFIG_HOME/mozilla/firefox"; do
    ini="$base/profiles.ini"
    [[ -f $ini ]] || continue
    while IFS= read -r line; do
      case $line in
        IsRelative=*) rel=${line#IsRelative=} ;;
        Path=*)
          path=${line#Path=}
          if [[ ${rel:-1} == 1 ]]; then
            echo "$base/$path"
          else
            echo "$path"
          fi
          ;;
        \[*) rel=1 ;;
      esac
    done <"$ini"
  done
}

tune_enabled() { [[ -f $POTATO_TUNE_STATE/$1/enabled ]]; }

# Config lines that enabled tunings add to the generated compositor configs.
tune_snippet_sway() {
  if tune_enabled no-xwayland; then
    echo "# omarchy-potato tune: no-xwayland"
    echo "xwayland disable"
  fi
  return 0
}
tune_snippet_hypr() {
  if tune_enabled no-xwayland; then
    echo "-- omarchy-potato tune: no-xwayland"
    echo "hl.config({ xwayland = { enabled = false } })"
  fi
  return 0
}
