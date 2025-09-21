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

REMOVAL_SUMMARY=()
SHELL_REMOVAL_MESSAGE=""
CONFIG_BACKUP_MESSAGE=""

remove_shell_hook() {
  local shell_type="$1"

  SHELL_REMOVAL_MESSAGE=""

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
      SHELL_REMOVAL_MESSAGE=$(printf 'Unknown shell type %s; skipped shell cleanup.' "$shell_type")
      return 0
      ;;
  esac

  if [ ! -f "$hook_file" ]; then
    SHELL_REMOVAL_MESSAGE=$(printf 'Shell config file %s does not exist (already removed).' "$hook_file")
    return 0
  fi

  if ! grep -Fq "$hook_marker" "$hook_file"; then
    SHELL_REMOVAL_MESSAGE=$(printf 'wt shell hook not found in %s (already removed).' "$hook_file")
    return 0
  fi

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_path="${hook_file}.backup.${timestamp}"
  cp "$hook_file" "$backup_path"

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
  SHELL_REMOVAL_MESSAGE=$(printf 'Removed wt shell hook from %s (backup: %s).' "$hook_file" "$backup_path")
}

backup_config_dir() {
  local default_dir="$HOME/.worktree.sh"
  local default_file="$default_dir/config.kv"
  local config_file="${WT_CONFIG_FILE:-$default_file}"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)

  CONFIG_BACKUP_MESSAGE=""

  if [ "$config_file" = "$default_file" ] && [ -d "$default_dir" ]; then
    local backup_path="${default_dir}.backup.${timestamp}"
    local candidate="$backup_path"
    local idx=1
    while [ -e "$candidate" ]; do
      candidate="${backup_path}.${idx}"
      idx=$((idx + 1))
    done
    mv "$default_dir" "$candidate"
    CONFIG_BACKUP_MESSAGE=$(printf 'Backed up wt config from %s to %s.' "$default_dir" "$candidate")
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
    CONFIG_BACKUP_MESSAGE=$(printf 'Backed up wt config from %s to %s.' "$config_file" "$candidate")
  else
    CONFIG_BACKUP_MESSAGE=$(printf 'wt config not found at %s (already removed).' "$config_file")
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

  REMOVAL_SUMMARY=()

  # Remove wt binary
  local wt_bin="$prefix/wt"
  if [ -f "$wt_bin" ]; then
    rm -f "$wt_bin"
    REMOVAL_SUMMARY+=("Removed wt from $wt_bin.")
  else
    REMOVAL_SUMMARY+=("wt not found at $wt_bin (already removed).")
  fi

  local wt_messages="$prefix/messages.sh"
  if [ -f "$wt_messages" ]; then
    rm -f "$wt_messages"
    REMOVAL_SUMMARY+=("Removed wt messages from $wt_messages.")
  else
    REMOVAL_SUMMARY+=("wt messages not found at $wt_messages (already removed).")
  fi

  # Remove shell hook if requested
  if [ "$shell_type" != "none" ]; then
    remove_shell_hook "$shell_type"
    if [ -n "$SHELL_REMOVAL_MESSAGE" ]; then
      REMOVAL_SUMMARY+=("$SHELL_REMOVAL_MESSAGE")
    else
      REMOVAL_SUMMARY+=("Shell cleanup completed.")
    fi
  else
    REMOVAL_SUMMARY+=("Skipped shell configuration cleanup (use --shell zsh or --shell bash to clean).")
  fi

  backup_config_dir
  if [ -n "$CONFIG_BACKUP_MESSAGE" ]; then
    REMOVAL_SUMMARY+=("$CONFIG_BACKUP_MESSAGE")
  else
    REMOVAL_SUMMARY+=("wt config not found (already removed).")
  fi

  printf '\nUninstallation summary:\n'
  local i
  for i in "${!REMOVAL_SUMMARY[@]}"; do
    local index=$((i + 1))
    printf '  %d. %s\n' "$index" "${REMOVAL_SUMMARY[$i]}"
  done

  printf '\nNotes:\n'
  printf '  - Existing worktrees were preserved.\n'
}

main "$@"
