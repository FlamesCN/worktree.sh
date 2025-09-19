#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh [--prefix <dir>] [--repo <git-url>] [--help]

Options:
  --prefix <dir>   Install wt into the specified directory (default: $HOME/.local/bin)
  --repo <url>     Git repository to clone when running via curl (default: WT_INSTALL_REPO env)
  -h, --help       Show this help message

The script installs the wt CLI without touching shell rc files. Ensure the
chosen prefix is on your PATH (for example, add $HOME/.local/bin to PATH if needed).
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

main() {
  local prefix="${WT_INSTALL_PREFIX:-$HOME/.local/bin}"
  local repo="${WT_INSTALL_REPO:-}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --prefix)
        shift || die "--prefix requires a value"
        prefix="$1"
        ;;
      --repo)
        shift || die "--repo requires a value"
        repo="$1"
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

  local script_path
  script_path=$(dirname "${BASH_SOURCE[0]:-${0}}")
  local script_dir
  script_dir=$(cd "$script_path" 2>/dev/null && pwd || true)

  local source_file=""
  local tmpdir=""

  if [ -n "$script_dir" ] && [ -f "$script_dir/bin/wt" ]; then
    source_file="$script_dir/bin/wt"
  else
    [ -n "$repo" ] || die "no repo specified; run from the repo or pass --repo/WT_INSTALL_REPO"
    command -v git >/dev/null 2>&1 || die "git is required to clone $repo"
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    git clone --depth 1 "$repo" "$tmpdir/repo" >&2
    source_file="$tmpdir/repo/bin/wt"
    [ -f "$source_file" ] || die "wt script not found in cloned repo"
  fi

  install -d "$prefix"
  install -m 0755 "$source_file" "$prefix/wt"
  printf 'Installed wt to %s\n' "$prefix/wt"

  if ! path_has "$prefix"; then
    printf 'Warning: %s is not on your PATH. Add it manually to use wt.\n' "$prefix" >&2
  fi

  local shell_name
  shell_name="${SHELL##*/}"
  local rc_file=".zshrc"
  case "$shell_name" in
    bash)
      rc_file=".bashrc"
      ;;
    zsh)
      rc_file=".zshrc"
      ;;
    *)
      shell_name="zsh"
      rc_file=".zshrc"
      ;;
  esac

  printf 'Next steps:\n'
  printf '  1) In each project you want wt to manage, run `wt init` to capture the current layout as defaults.\n'
  printf '  2) Add the shell hook for your shell to enable auto-cd (for example: `wt shell-hook %s >> ~/%s`).\n' "$shell_name" "$rc_file"
  printf '     If you used install-zsh.sh, this hook is already in place.\n'
  printf 'Configuration is stored in %s (TOML).\n' "${WT_CONFIG_FILE:-$HOME/.wt-cli}"
}

main "$@"
