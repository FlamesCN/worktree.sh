#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: uninstall.sh [options]

Options:
  --shell <shell>  Shell to unconfigure (zsh, bash, or none). Default: auto-detect
  --prefix <dir>   Remove wt from the specified directory (default: $HOME/.local/bin)
  --help           Show this help message

Examples:
  # Auto-detect shell and unconfigure
  ./uninstall.sh

  # Uninstall for specific shell
  ./uninstall.sh --shell zsh
  ./uninstall.sh --shell bash

  # Uninstall without shell configuration cleanup
  ./uninstall.sh --shell none

  # Uninstall via curl for zsh
  curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash -s -- --shell zsh

  # Uninstall via curl for bash
  curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash -s -- --shell bash

The script removes the wt CLI. If a shell is specified (or auto-detected),
it will also remove the shell integration from your shell configuration file.
USAGE
}

die() {
  printf 'uninstall.sh: %s\n' "$*" >&2
  exit 1
}

detect_shell() {
  local shell_name="${SHELL##*/}"
  case "$shell_name" in
    bash) echo "bash" ;;
    zsh) echo "zsh" ;;
    *) echo "none" ;;
  esac
}

remove_shell_hook() {
  local shell_type="$1"

  if [ "$shell_type" = "none" ]; then
    return 0
  fi

  local hook_file=""
  local hook_marker="# wt shell integration: auto-cd after wt add/path/main/remove/clean"
  local marker_end="# wt shell integration: end"

  case "$shell_type" in
    zsh)
      hook_file="$HOME/.zshrc"
      ;;
    bash)
      hook_file="$HOME/.bashrc"
      ;;
    *)
      printf 'Warning: Unknown shell type %s, skipping shell cleanup
' "$shell_type" >&2
      return 0
      ;;
  esac

  if [ ! -f "$hook_file" ]; then
    printf 'Shell config file %s does not exist, skipping.
' "$hook_file"
    return 0
  fi

  if ! grep -Fq "$hook_marker" "$hook_file"; then
    printf 'No wt shell hook found in %s, skipping.
' "$hook_file"
    return 0
  fi

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  cp "$hook_file" "${hook_file}.backup.${timestamp}"
  printf 'Created backup: %s.backup.%s
' "$hook_file" "$timestamp"

  local tmpfile
  tmpfile=$(mktemp)

  awk -v start="$hook_marker" -v finish="$marker_end" '
    BEGIN { mode=0 }
    {
      if (mode==0) {
        if ($0 == start) { mode=1; next }
        print
        next
      }

      if (mode==1) {
        if ($0 == finish) { mode=2; next }
        next
      }

      if (mode==2) {
        if ($0 ~ /^[[:space:]]*$/) { mode=0; next }
        mode=0
        print
        next
      }
    }
  ' "$hook_file" > "$tmpfile"

  mv "$tmpfile" "$hook_file"
  printf 'Removed wt shell hook from %s\n' "$hook_file"
}

backup_config_dir() {
  local default_dir="$HOME/.worktree.sh"
  local default_file="$default_dir/config.json"
  local config_file="${WT_CONFIG_FILE:-$default_file}"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)

  if [ "$config_file" = "$default_file" ] && [ -d "$default_dir" ]; then
    local backup_path="${default_dir}.backup.${timestamp}"
    local candidate="$backup_path"
    local idx=1
    while [ -e "$candidate" ]; do
      candidate="${backup_path}.${idx}"
      idx=$((idx + 1))
    done
    mv "$default_dir" "$candidate"
    printf 'Backed up wt config from %s to %s\n' "$default_dir" "$candidate"
    return
  fi

  if [ -f "$config_file" ]; then
    local backup_path="${config_file}.backup.${timestamp}"
    local candidate="$backup_path"
    local idx=1
    while [ -e "$candidate" ]; do
      candidate="${backup_path}.${idx}"
      idx=$((idx + 1))
    done
    mv "$config_file" "$candidate"
    printf 'Backed up wt config from %s to %s\n' "$config_file" "$candidate"
  fi
}


main() {
  local prefix="${WT_INSTALL_PREFIX:-$HOME/.local/bin}"
  local shell_type=""

  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --shell)
        shift || die "--shell requires a value"
        shell_type="$1"
        ;;
      --prefix)
        shift || die "--prefix requires a value"
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
        die "unknown option: $1"
        ;;
      *)
        break
        ;;
    esac
    shift || true
  done

  # Auto-detect shell if not specified
  if [ -z "$shell_type" ]; then
    shell_type=$(detect_shell)
    printf 'Auto-detected shell: %s\n' "$shell_type"
  fi

  # Validate shell type
  case "$shell_type" in
    zsh|bash|none) ;;
    *) die "Invalid shell type: $shell_type (use zsh, bash, or none)" ;;
  esac

  # Remove wt binary
  local wt_bin="$prefix/wt"
  if [ -f "$wt_bin" ]; then
    rm -f "$wt_bin"
    printf 'Removed wt from %s\n' "$wt_bin"
  else
    printf 'wt not found at %s (already removed?)\n' "$wt_bin"
  fi

  local wt_messages="$prefix/messages.sh"
  if [ -f "$wt_messages" ]; then
    rm -f "$wt_messages"
    printf 'Removed wt messages from %s\n' "$wt_messages"
  fi

  # Remove shell hook if requested
  if [ "$shell_type" != "none" ]; then
    remove_shell_hook "$shell_type"
  else
    printf 'Skipping shell configuration cleanup (use --shell zsh or --shell bash to clean)\n'
  fi

  backup_config_dir

  # Final notes
  printf '\nUninstallation complete.\n'
  printf 'Note: Any existing worktrees were preserved\n'
}

main "$@"
