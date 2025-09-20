#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Options:
  --shell <shell>  Shell to configure (zsh, bash, or none). Default: auto-detect
  --prefix <dir>   Install wt into the specified directory (default: $HOME/.local/bin)
  -h, --help       Show this help message

Examples:
  # Auto-detect shell and configure
  ./install.sh

  # Install for specific shell
  ./install.sh --shell zsh
  ./install.sh --shell bash

  # Install without shell configuration
  ./install.sh --shell none

  # Install via curl for zsh
  curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell zsh

The script installs the wt CLI. If a shell is specified (or auto-detected),
it will also configure the shell integration for automatic directory switching.
USAGE
}

path_has() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

die() {
  printf 'install.sh: %s\n' "$*" >&2
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

install_shell_hook() {
  local shell_type="$1"
  local wt_bin="$2"

  if [ "$shell_type" = "none" ]; then
    return 0
  fi

  local hook_file=""
  local hook_marker="# wt shell integration: auto-cd after wt add/path/main/remove/clean"

  case "$shell_type" in
    zsh)
      hook_file="$HOME/.zshrc"
      ;;
    bash)
      hook_file="$HOME/.bashrc"
      ;;
    *)
      printf 'Warning: Unknown shell type %s, skipping shell integration\n' "$shell_type" >&2
      return 0
      ;;
  esac

  # Create rc file if it doesn't exist
  mkdir -p "$(dirname "$hook_file")"
  if [ ! -f "$hook_file" ]; then
    touch "$hook_file"
  fi

  # Check if hook already exists
  if grep -Fq "$hook_marker" "$hook_file"; then
    printf '%s shell hook already present in %s (skipping append).\n' "$shell_type" "$hook_file"
  else
    printf '\n%s\n' "$("$wt_bin" shell-hook "$shell_type")" >> "$hook_file"
    printf 'Appended wt shell hook to %s\n' "$hook_file"
  fi

  printf 'To enable wt auto-cd right away, run `source %s` (or start a new shell).\n' "$hook_file"
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

  # Find the wt script
  local script_path
  script_path=$(dirname "${BASH_SOURCE[0]:-${0}}")
  local script_dir
  script_dir=$(cd "$script_path" 2>/dev/null && pwd || true)

  local source_file=""
  local messages_source=""
  local tmpdir=""

  if [ -n "$script_dir" ] && [ -f "$script_dir/bin/wt" ]; then
    source_file="$script_dir/bin/wt"
    if [ -f "$script_dir/bin/messages.sh" ]; then
      messages_source="$script_dir/bin/messages.sh"
    fi
  else
    command -v curl >/dev/null 2>&1 || die "curl is required"
    tmpdir=$(mktemp -d)
    trap 'rm -rf "${tmpdir:-}"' EXIT

    local source_url="https://raw.githubusercontent.com/notdp/worktree.sh/main/bin/wt"
    printf 'Downloading wt from %s...\n' "$source_url"
    curl -fsSL "$source_url" -o "$tmpdir/wt" || die "failed to download wt from $source_url"
    source_file="$tmpdir/wt"

    local messages_url="https://raw.githubusercontent.com/notdp/worktree.sh/main/bin/messages.sh"
    printf 'Downloading wt messages from %s...\n' "$messages_url"
    if curl -fsSL "$messages_url" -o "$tmpdir/messages.sh"; then
      messages_source="$tmpdir/messages.sh"
    else
      printf 'Warning: failed to download messages file from %s\n' "$messages_url" >&2
    fi
  fi

  # Install wt binary
  install -d "$prefix"
  install -m 0755 "$source_file" "$prefix/wt"
  printf 'Installed wt to %s\n' "$prefix/wt"

  if [ -n "$messages_source" ] && [ -f "$messages_source" ]; then
    install -m 0644 "$messages_source" "$prefix/messages.sh"
    printf 'Installed messages to %s\n' "$prefix/messages.sh"
  fi

  # Check PATH
  if ! path_has "$prefix"; then
    printf 'Warning: %s is not on your PATH. Add it manually to use wt.\n' "$prefix" >&2
  fi

  # Install shell hook if requested
  if [ "$shell_type" != "none" ]; then
    install_shell_hook "$shell_type" "$prefix/wt"
  else
    printf 'Skipping shell integration (use --shell zsh or --shell bash to enable)\n'
  fi

  # Print next steps
  printf '\nNext steps:\n'
  printf '  1) In each project you want wt to manage, run `wt init` to capture the current layout as defaults.\n'
  if [ "$shell_type" = "none" ]; then
    printf '  2) Optionally add shell hook manually: `wt shell-hook zsh >> ~/.zshrc` or `wt shell-hook bash >> ~/.bashrc`\n'
  fi
  printf 'Configuration is stored in %s (JSON).\n' "${WT_CONFIG_FILE:-$HOME/.worktree.sh/config.json}"
}

main "$@"
