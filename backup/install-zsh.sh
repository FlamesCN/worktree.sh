#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-zsh.sh [--prefix <dir>] [--repo <git-url>] [--help]

This script installs wt and configures the Zsh shell integration automatically.
Options mirror install.sh.
USAGE
}

prefix="${WT_INSTALL_PREFIX:-$HOME/.local/bin}"
repo="${WT_INSTALL_REPO:-}"
forward_args=()

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)
      shift || { usage; exit 1; }
      prefix="$1"
      forward_args+=("--prefix" "$1")
      ;;
    --repo)
      shift || { usage; exit 1; }
      repo="$1"
      forward_args+=("--repo" "$1")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      forward_args+=("--")
      shift
      break
      ;;
    -*)
      usage
      exit 1
      ;;
    *)
      forward_args+=("$1")
      ;;
  esac
  shift || true
done

if [ $# -gt 0 ]; then
  forward_args+=("$@")
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" >/dev/null 2>&1 && pwd)
"$script_dir/install.sh" "${forward_args[@]}"

wt_bin="$prefix/wt"
if [ ! -x "$wt_bin" ]; then
  printf 'install-zsh.sh: unable to find wt at %s\n' "$wt_bin" >&2
  exit 1
fi

hook_file="$HOME/.zshrc"
hook_marker="# wt shell integration: auto-cd after wt add/path/main/remove/clean"

mkdir -p "$(dirname "$hook_file")"
if [ ! -f "$hook_file" ]; then
  touch "$hook_file"
fi

if grep -Fq "$hook_marker" "$hook_file"; then
  printf 'Zsh shell hook already present in %s (skipping append).\n' "$hook_file"
else
  printf '\n%s\n' "$("$wt_bin" shell-hook zsh)" >> "$hook_file"
  printf 'Appended wt shell hook to %s\n' "$hook_file"
fi

printf 'To enable wt auto-cd right away, run `source %s` (or start a new shell).\n' "$hook_file"

printf 'Next: from each project you want wt to manage, run `wt init` to capture the current layout as defaults.\n'
