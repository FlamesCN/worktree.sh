#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: uninstall-bash.sh [--prefix <dir>] [--help]

Removes the wt binary (installed under --prefix) and deletes the Bash shell integration snippet.
USAGE
}

prefix="${WT_INSTALL_PREFIX:-$HOME/.local/bin}"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)
      shift || { usage; exit 1; }
      prefix="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 1
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift || true
done

wt_bin="$prefix/wt"
if [ -e "$wt_bin" ]; then
  rm -f "$wt_bin"
  printf 'Removed wt binary at %s\n' "$wt_bin"
else
  printf 'wt binary not found at %s (skipping).\n' "$wt_bin"
fi

hook_file="$HOME/.bashrc"
if [ -f "$hook_file" ]; then
  tmp_file=$(mktemp "wt-uninstall-bash.XXXXXX")
  awk '
    BEGIN { skip = 0 }
    /^# wt shell integration: auto-cd after wt add\/path\/main\/remove\/clean$/ {
      skip = 1
      next
    }
    skip {
      if ($0 ~ /^}$/) {
        skip = 0
        next
      }
      next
    }
    { print }
  ' "$hook_file" > "$tmp_file"
  mv "$tmp_file" "$hook_file"
  printf 'Removed wt shell hook from %s\n' "$hook_file"
else
  printf 'Bash rc file %s not found (skipping hook removal).\n' "$hook_file"
fi

printf 'Uninstall complete. You may remove ~/.wt-cli manually if it is no longer needed.\n'
