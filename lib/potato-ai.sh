# shellcheck shell=bash
# Shared helpers for the optional local-AI module: context presets and
# process ownership. Sourced, not executed. State files are data, never sourced.

# Supported context sizes for llama-server.
potato_ai_valid_ctx() {
  case ${1:-} in
    2048|4096|8192) return 0 ;;
    *) return 1 ;;
  esac
}

# Print ctx from an enabled file. Legacy state (no ctx= line) prints 2048.
# Returns 1 when malformed: missing file or duplicate ctx= lines (never
# tail-choose between them).
potato_ai_enabled_ctx() {
  local file=${1:-} n
  [[ -f $file ]] || return 1
  n=$(grep -c '^ctx=' "$file" 2>/dev/null) || n=0
  case $n in
    0) printf '2048\n' ;;
    1) sed -n 's/^ctx=//p' "$file" ;;
    *) return 1 ;;
  esac
}

# Resolve the effective context: POTATO_AI_CTX (even empty) > enabled ctx= >
# legacy default 2048. Returns 1 only when the persisted state is malformed
# (e.g. duplicate ctx=); env precedence means a set POTATO_AI_CTX never reads
# it. The caller validates the printed value.
potato_ai_resolve_ctx() {
  local file=${1:-}
  if [[ -v POTATO_AI_CTX ]]; then
    printf '%s\n' "$POTATO_AI_CTX"
    return 0
  fi
  if [[ -n $file && -f $file ]]; then
    potato_ai_enabled_ctx "$file"
    return
  fi
  printf '2048\n'
}

# Field 22 of /proc/PID/stat, after stripping the command name in parentheses.
potato_ai_proc_starttime() {
  local pid=${1:-} line
  local -a fields
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  IFS= read -r line <"/proc/$pid/stat" 2>/dev/null || return 1
  line=${line##*) }
  IFS=' ' read -r -a fields <<<"$line"
  (( ${#fields[@]} >= 20 )) || return 1
  [[ ${fields[0]} != Z && ${fields[0]} != X ]] || return 1
  printf '%s\n' "${fields[19]}"
}

potato_ai_proc_cmdline_hash() {
  local pid=${1:-}
  [[ $pid =~ ^[0-9]+$ && -r /proc/$pid/cmdline ]] || return 1
  sha256sum <"/proc/$pid/cmdline" | awk '{ print $1 }'
}

potato_ai_model_id() {
  local model=${1:-}
  [[ -f $model ]] || { printf 'missing\n'; return 0; }
  stat -c '%s:%Y' -- "$model" 2>/dev/null || printf 'unknown\n'
}

potato_ai_meta_get() {
  local file=${1:-} key=${2:-}
  [[ -f $file ]] || return 1
  sed -n "s/^${key}=//p" "$file" | tail -n1
}

# A metadata file is trusted only if it carries a complete process identity.
potato_ai_meta_trusted() {
  local file=${1:-} pid start hash
  [[ -f $file ]] || return 1
  [[ $(potato_ai_meta_get "$file" format) == 1 ]] || return 1
  pid=$(potato_ai_meta_get "$file" pid)
  start=$(potato_ai_meta_get "$file" starttime)
  hash=$(potato_ai_meta_get "$file" cmdline_sha256)
  [[ $pid =~ ^[0-9]+$ && $start =~ ^[0-9]+$ && $hash =~ ^[0-9a-f]{64}$ ]] || return 1
}

potato_ai_meta_matches() {
  local file=$1 ctx=$2 port=$3 server=$4 model=$5
  [[ $(potato_ai_meta_get "$file" ctx) == "$ctx" ]] || return 1
  [[ $(potato_ai_meta_get "$file" port) == "$port" ]] || return 1
  [[ $(potato_ai_meta_get "$file" server) == "$server" ]] || return 1
  [[ $(potato_ai_meta_get "$file" model) == "$model" ]] || return 1
  [[ $(potato_ai_meta_get "$file" model_id) == "$(potato_ai_model_id "$model")" ]] || return 1
  [[ $(potato_ai_meta_get "$file" cache) == 'q8_0/q8_0' ]] || return 1
  [[ $(potato_ai_meta_get "$file" fa) == on ]] || return 1
}

# True only when the metadata's PID still has the same start time and exact
# command line. This rejects PID reuse and unrelated processes.
potato_ai_owned_alive() {
  local file=${1:-} pid start hash
  potato_ai_meta_trusted "$file" || return 1
  pid=$(potato_ai_meta_get "$file" pid)
  start=$(potato_ai_meta_get "$file" starttime)
  hash=$(potato_ai_meta_get "$file" cmdline_sha256)
  kill -0 "$pid" 2>/dev/null || return 1
  [[ $(potato_ai_proc_starttime "$pid" 2>/dev/null) == "$start" ]] || return 1
  [[ $(potato_ai_proc_cmdline_hash "$pid" 2>/dev/null) == "$hash" ]]
}

# Stop only an explicitly identified owned process. Returns 3 for any mismatch.
potato_ai_stop_identity() {
  local pid=${1:-} start=${2:-} hash=${3:-}
  [[ $pid =~ ^[0-9]+$ && $start =~ ^[0-9]+$ && -n $hash ]] || return 3
  kill -0 "$pid" 2>/dev/null || return 3
  [[ $(potato_ai_proc_starttime "$pid" 2>/dev/null) == "$start" ]] || return 3
  [[ $(potato_ai_proc_cmdline_hash "$pid" 2>/dev/null) == "$hash" ]] || return 3
  kill "$pid" 2>/dev/null || return 1
  return 0
}

potato_ai_meta_describes() {
  local file=${1:-} pid=${2:-} start=${3:-} hash=${4:-}
  [[ -f $file ]] || return 1
  [[ $(potato_ai_meta_get "$file" pid) == "$pid" ]] || return 1
  [[ $(potato_ai_meta_get "$file" starttime) == "$start" ]] || return 1
  [[ $(potato_ai_meta_get "$file" cmdline_sha256) == "$hash" ]]
}

potato_ai_write_enabled() {
  local file=$1 variant=$2 server=$3 model=$4 ctx=$5 tmp
  potato_ai_valid_ctx "$ctx" || return 1
  tmp=$(mktemp "${file}.XXXXXX") || return 1
  printf 'variant=%s\nserver=%s\nmodel=%s\nctx=%s\n' "$variant" "$server" "$model" "$ctx" >"$tmp"
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$file"
}

potato_ai_write_meta() {
  local file=$1 pid=$2 start=$3 hash=$4 ctx=$5 port=$6 server=$7 model=$8 tmp
  tmp=$(mktemp "${file}.XXXXXX") || return 1
  printf 'format=1\npid=%s\nstarttime=%s\ncmdline_sha256=%s\nctx=%s\nport=%s\nserver=%s\nmodel=%s\nmodel_id=%s\ncache=q8_0/q8_0\nfa=on\n' \
    "$pid" "$start" "$hash" "$ctx" "$port" "$server" "$model" "$(potato_ai_model_id "$model")" >"$tmp"
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$file"
}

potato_ai_write_pid() {
  local file=$1 pid=$2 tmp
  tmp=$(mktemp "${file}.XXXXXX") || return 1
  printf '%s\n' "$pid" >"$tmp"
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$file"
}
