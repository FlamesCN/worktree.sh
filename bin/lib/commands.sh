# shellcheck shell=bash

cmd_config() {
  local scope="$CURRENT_SCOPE"
  if [ $# -eq 0 ]; then
    config_usage
    return
  fi

  if [ "$1" = "--stored" ]; then
    shift || die "$(msg config_get_requires_key)"
    set -- get --stored "$@"
  fi

  case "$1" in
  list | --list)
    if [ $# -ne 1 ]; then
      die "$(msg config_list_no_args)"
    fi
    if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -ne 1 ] && [ "$scope" != "project" ]; then
      die "$(msg command_requires_project)"
    fi
    init_settings
    config_print_effective
    ;;
  get | --get)
    shift || die "$(msg config_get_requires_key)"

    local stored_only=0
    while [ $# -gt 0 ]; do
      case "$1" in
      --stored)
        stored_only=1
        shift || true
        ;;
      --*)
        die "$(msg config_unknown_option "$1")"
        ;;
      *)
        break
        ;;
      esac
    done

    if [ $# -ne 1 ]; then
      die "$(msg config_get_requires_exactly_one)"
    fi

    local key="$1"
    local value
    if [ "$stored_only" -eq 1 ]; then
      if value=$(config_get "$key" 2> /dev/null); then
        printf '%s\n' "$value"
      else
        die "$(msg config_key_not_found "$key")"
      fi
    else
      if value=$(config_get_or_default "$key" 2> /dev/null); then
        printf '%s\n' "$value"
      else
        die "$(msg config_key_not_found "$key")"
      fi
    fi
    ;;
  set | --set)
    shift || die "$(msg config_set_requires)"
    if [ $# -ne 2 ]; then
      die "$(msg config_set_requires)"
    fi
    if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -ne 1 ] && [ "$scope" != "project" ]; then
      die "$(msg command_requires_project)"
    fi
    local key="$1"
    shift
    local value="$1"
    if [ "$key" = "language" ]; then
      if normalized=$(normalize_language "$value" 2> /dev/null); then
        value=$(language_code_to_config_value "$normalized")
      else
        die "$(msg invalid_language "$value")"
      fi
    fi
    config_set "$key" "$value"
    ;;
  unset | --unset)
    shift || die "$(msg config_unset_requires_key)"
    if [ $# -ne 1 ]; then
      die "$(msg config_unset_requires_exactly_one)"
    fi
    if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -ne 1 ] && [ "$scope" != "project" ]; then
      die "$(msg command_requires_project)"
    fi
    local key="$1"
    config_unset "$key"
    ;;
  -h | --help | help)
    config_usage
    ;;
  --*)
    die "$(msg config_unknown_option "$1")"
    ;;
  *)
    local stored_only=0
    if [ $# -gt 0 ] && [ "$1" = "--stored" ]; then
      stored_only=1
      shift || true
    fi

    if [ $# -eq 1 ]; then
      local key="$1"
      local value
      if [ "$stored_only" -eq 1 ]; then
        if value=$(config_get "$key" 2> /dev/null); then
          printf '%s\n' "$value"
        else
          die "$(msg config_key_not_found "$key")"
        fi
      else
        if value=$(config_get_or_default "$key" 2> /dev/null); then
          printf '%s\n' "$value"
        else
          die "$(msg config_key_not_found "$key")"
        fi
      fi
    elif [ $# -eq 2 ]; then
      local key="$1"
      local value="$2"
      if [ "$key" = "language" ]; then
        if normalized=$(normalize_language "$value" 2> /dev/null); then
          value=$(language_code_to_config_value "$normalized")
        else
          die "$(msg invalid_language "$value")"
        fi
      fi
      config_set "$key" "$value"
    elif [ "$stored_only" -eq 1 ]; then
      die "$(msg config_get_requires_key)"
    else
      die "$(msg config_expect_key_or_value)"
    fi
    ;;
  esac
}

cmd_shell_hook() {
  if [ $# -eq 0 ]; then
    die "$(msg shell_hook_requires_shell)"
  fi

  case "$1" in
  -h | --help | help)
    case "$LANGUAGE" in
    zh)
      cat << 'HOOK_USAGE_ZH'
wt shell-hook 用法:
  wt shell-hook zsh
  wt shell-hook bash

将输出通过 eval/source 加载以安装包装函数，例如：
  eval "$(wt shell-hook zsh)"
HOOK_USAGE_ZH
      ;;
    *)
      cat << 'HOOK_USAGE_EN'
wt shell-hook usage:
  wt shell-hook zsh
  wt shell-hook bash

Pipe the output into eval/source to install the wrapper, e.g.
  eval "$(wt shell-hook zsh)"
HOOK_USAGE_EN
      ;;
    esac
    return
    ;;
  esac

  local shell="$1"
  local wt_exec_path
  local wt_exec_path_escaped
  wt_exec_path="$SCRIPT_DIR/wt"
  wt_exec_path_escaped=$(printf '%s\n' "$wt_exec_path" | sed 's/[\\/&]/\\&/g')
  case "$shell" in
  zsh | bash)
    sed "s/__WT_BIN_PATH__/$wt_exec_path_escaped/g" << 'WT_HOOK'
# wt shell integration: auto-cd after wt add/path/main/remove/clean
wt() {
  local __wt_out __wt_status __wt_cmd __wt_should_cd=0
  local __wt_bin="__WT_BIN_PATH__"

  if [ ! -x "$__wt_bin" ]; then
    local __wt_resolved=""
    if __wt_resolved="$(type -P wt 2>/dev/null)" && [ -x "$__wt_resolved" ]; then
      __wt_bin="$__wt_resolved"
    elif __wt_resolved="$(command -v wt 2>/dev/null)" && [ -n "$__wt_resolved" ] && [ -x "$__wt_resolved" ]; then
      __wt_bin="$__wt_resolved"
    else
      printf 'zsh: command not found: wt\n' >&2
      return 127
    fi
  fi

  __wt_out="$(WT_SHELL_WRAPPED=1 "$__wt_bin" "$@")"
  __wt_status=$?

  if [ $__wt_status -ne 0 ]; then
    if [ -n "$__wt_out" ]; then
      printf '%s\n' "$__wt_out"
    fi
    return $__wt_status
  fi

  if [ $# -eq 0 ]; then
    __wt_cmd="list"
  else
    __wt_cmd="$1"
  fi

  case "$__wt_cmd" in
    add|main|path)
      __wt_should_cd=1
      ;;
    remove|rm|clean)
      __wt_should_cd=1
      ;;
    config|list|help|-h|--help|--version|version)
      __wt_should_cd=0
      ;;
    -*)
      __wt_should_cd=0
      ;;
    *)
      __wt_should_cd=1
      ;;
  esac

  if [ $__wt_should_cd -eq 1 ] && [ -n "$__wt_out" ] && [ -d "$__wt_out" ]; then
    cd "$__wt_out" || return $?
    return 0
  fi

  if [ -n "$__wt_out" ]; then
    printf '%s\n' "$__wt_out"
  fi
}
# wt shell integration: end
WT_HOOK
    ;;
  *)
    die "$(msg shell_hook_unsupported_shell "$shell")"
    ;;
  esac
}

uninstall_remove_shell_hook() {
  local shell_type="$1"
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
    info "$(msg uninstall_unknown_shell_type "$shell_type")"
    return 0
    ;;
  esac

  if [ ! -f "$hook_file" ]; then
    info "$(msg uninstall_shell_config_missing "$hook_file")"
    return 0
  fi

  if ! grep -Fq "$hook_marker" "$hook_file"; then
    info "$(msg uninstall_shell_hook_missing "$hook_file")"
    return 0
  fi

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  cp "$hook_file" "${hook_file}.backup.${timestamp}"
  info "$(msg uninstall_backup_created "$hook_file" "$timestamp")"

  local tmpfile
  tmpfile=$(mktemp) || die "$(msg temp_file_failed)"

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
  info "$(msg uninstall_shell_hook_removed "$hook_file")"
}

uninstall_backup_config() {
  local config_path="$CONFIG_FILE"
  local default_dir="$CONFIG_DIR_DEFAULT"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)

  if [ "$config_path" = "$CONFIG_FILE_DEFAULT" ] && [ -d "$default_dir" ]; then
    local backup_path="${default_dir}.backup.${timestamp}"
    local candidate="$backup_path"
    local idx=1
    while [ -e "$candidate" ]; do
      candidate="${backup_path}.${idx}"
      idx=$((idx + 1))
    done
    mv "$default_dir" "$candidate"
    info "$(msg uninstall_config_backup_created "$default_dir" "$candidate")"
    return
  fi

  if [ -f "$config_path" ]; then
    local backup_path="${config_path}.backup.${timestamp}"
    local candidate="$backup_path"
    local idx=1
    while [ -e "$candidate" ]; do
      candidate="${backup_path}.${idx}"
      idx=$((idx + 1))
    done
    mv "$config_path" "$candidate"
    info "$(msg uninstall_config_backup_created "$config_path" "$candidate")"
  fi
}

cmd_uninstall() {
  local prefix="${WT_INSTALL_PREFIX:-$HOME/.local/bin}"
  local shell_type=""

  while [ $# -gt 0 ]; do
    case "$1" in
    --shell)
      shift || die "$(msg uninstall_requires_shell_value)"
      shell_type="$1"
      ;;
    --prefix)
      shift || die "$(msg uninstall_requires_prefix_value)"
      prefix="$1"
      ;;
    -h | --help | help)
      case "$LANGUAGE" in
      zh)
        cat << 'UNINSTALL_USAGE_ZH'
wt uninstall 用法:
  wt uninstall [--shell <shell>] [--prefix <dir>]

选项:
  --shell <shell>   指定要清理的 shell（zsh|bash|none；默认自动检测）
  --prefix <dir>    wt 安装目录（默认 $HOME/.local/bin）
  --help            查看帮助
UNINSTALL_USAGE_ZH
        ;;
      *)
        cat << 'UNINSTALL_USAGE_EN'
wt uninstall usage:
  wt uninstall [--shell <shell>] [--prefix <dir>]

Options:
  --shell <shell>   Shell to clean hooks for (zsh|bash|none; default: auto-detect)
  --prefix <dir>    Directory where wt is installed (default: $HOME/.local/bin)
  --help            Show this help
UNINSTALL_USAGE_EN
        ;;
      esac
      return
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "$(msg uninstall_unknown_option "$1")"
      ;;
    *)
      die "$(msg uninstall_no_positional)"
      ;;
    esac
    shift || true
  done

  if [ $# -gt 0 ]; then
    die "$(msg uninstall_no_positional)"
  fi

  if [ -z "$shell_type" ]; then
    shell_type=$(detect_shell_type)
    info "$(msg uninstall_auto_detected_shell "$shell_type")"
  fi

  case "$shell_type" in
  zsh | bash | none) ;;
  *)
    die "$(msg uninstall_invalid_shell "$shell_type")"
    ;;
  esac

  local wt_bin="$prefix/wt"
  if [ -f "$wt_bin" ]; then
    rm -f "$wt_bin"
    info "$(msg uninstall_removed_binary "$wt_bin")"
  else
    info "$(msg uninstall_binary_missing "$wt_bin")"
  fi

  local messages_file="$prefix/messages.sh"
  if [ -f "$messages_file" ]; then
    rm -f "$messages_file"
    info "$(msg uninstall_removed_messages "$messages_file")"
  fi

  if [ "$shell_type" != "none" ]; then
    uninstall_remove_shell_hook "$shell_type"
  else
    info "$(msg uninstall_skip_shell_cleanup)"
  fi

  uninstall_backup_config

  info "$(msg uninstall_complete)"
  info "$(msg uninstall_worktrees_preserved)"
}

cmd_reinstall() {
  local prefix="${WT_INSTALL_PREFIX:-$HOME/.local/bin}"
  local shell_type=""

  while [ $# -gt 0 ]; do
    case "$1" in
    --shell)
      shift || die "$(msg reinstall_requires_shell_value)"
      shell_type="$1"
      ;;
    --prefix)
      shift || die "$(msg reinstall_requires_prefix_value)"
      prefix="$1"
      ;;
    -h | --help | help)
      case "$LANGUAGE" in
      zh)
        cat << 'REINSTALL_USAGE_ZH'
wt reinstall 用法:
  wt reinstall [--shell <shell>] [--prefix <dir>]

说明:
  - 先运行 uninstall.sh，再运行 install.sh
  - 默认目标目录为 ~/.local/bin（可通过 WT_INSTALL_PREFIX 或 --prefix 覆盖）
  - 需在包含 install.sh 与 uninstall.sh 的仓库目录中运行
REINSTALL_USAGE_ZH
        ;;
      *)
        cat << 'REINSTALL_USAGE_EN'
wt reinstall usage:
  wt reinstall [--shell <shell>] [--prefix <dir>]

Notes:
  - Executes uninstall.sh followed by install.sh from this checkout
  - Targets ~/.local/bin by default (override via WT_INSTALL_PREFIX or --prefix)
  - Must be invoked from a checkout that contains install.sh and uninstall.sh
REINSTALL_USAGE_EN
        ;;
      esac
      return
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "$(msg reinstall_unknown_option "$1")"
      ;;
    *)
      die "$(msg reinstall_no_positional)"
      ;;
    esac
    shift || true
  done

  if [ $# -gt 0 ]; then
    die "$(msg reinstall_no_positional)"
  fi

  local uninstall_script=""
  local install_script=""
  local cleanup_dir=""

  cleanup_reinstall_tmp() {
    if [ -n "$cleanup_dir" ] && [ -d "$cleanup_dir" ]; then
      rm -rf "$cleanup_dir"
    fi
    cleanup_dir=""
  }

  local remote_base="${WT_REINSTALL_REMOTE_BASE:-https://raw.githubusercontent.com/notdp/worktree.sh/main}"
  command -v curl > /dev/null 2>&1 || die "$(msg reinstall_curl_required)"

  cleanup_dir=$(mktemp -d)
  if [ -z "$cleanup_dir" ] || [ ! -d "$cleanup_dir" ]; then
    die "$(msg reinstall_fetch_failed "$remote_base")"
  fi

  uninstall_script="$cleanup_dir/uninstall.sh"
  install_script="$cleanup_dir/install.sh"
  local uninstall_url="$remote_base/uninstall.sh"
  local install_url="$remote_base/install.sh"

  info "$(msg reinstall_fetch_remote_uninstall "$uninstall_url")"
  if ! curl -fsSL "$uninstall_url" -o "$uninstall_script"; then
    cleanup_reinstall_tmp
    die "$(msg reinstall_fetch_failed "$uninstall_url")"
  fi
  info "$(msg reinstall_fetch_remote_install "$install_url")"
  if ! curl -fsSL "$install_url" -o "$install_script"; then
    cleanup_reinstall_tmp
    die "$(msg reinstall_fetch_failed "$install_url")"
  fi
  chmod +x "$uninstall_script" "$install_script" 2> /dev/null || true

  local -a uninstall_cmd=("$uninstall_script")
  local -a install_cmd=("$install_script")

  if [ -n "$shell_type" ]; then
    uninstall_cmd+=('--shell' "$shell_type")
    install_cmd+=('--shell' "$shell_type")
  fi

  uninstall_cmd+=('--prefix' "$prefix")
  install_cmd+=('--prefix' "$prefix")

  local uninstall_display=""
  local install_display=""

  printf -v uninstall_display '%q ' "${uninstall_cmd[@]}"
  uninstall_display=${uninstall_display%% }
  printf -v install_display '%q ' "${install_cmd[@]}"
  install_display=${install_display%% }

  info "$(msg reinstall_running "$uninstall_display")"
  if ! "${uninstall_cmd[@]}"; then
    cleanup_reinstall_tmp
    die "$(msg reinstall_uninstall_failed "$uninstall_script")"
  fi

  info "$(msg reinstall_running "$install_display")"
  if ! "${install_cmd[@]}"; then
    cleanup_reinstall_tmp
    die "$(msg reinstall_install_failed "$install_script")"
  fi

  cleanup_reinstall_tmp

  info "$(msg reinstall_complete)"
}

cmd_init() {
  local branch=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --branch | branch)
      shift || die "$(msg branch_requires_value)"
      branch="$1"
      ;;
    --help | help)
      case "$LANGUAGE" in
      zh)
        cat << 'INIT_USAGE_ZH'
wt init 用法:
  wt init [branch <name>]

请在目标仓库运行：
- 创建 ~/.worktree.sh/projects/<slug>/config.kv（如不存在）。
- 设置 repo.path 为仓库根目录（根据 git common dir 推导）。
- 提供 branch <name> 时设置 repo.branch（默认使用当前分支）。
INIT_USAGE_ZH
        ;;
      *)
        cat << 'INIT_USAGE_EN'
wt init usage:
  wt init [branch <name>]

Run inside the target repository:
- Create ~/.worktree.sh/projects/<slug>/config.kv when missing.
- Set repo.path to the repository root (derived from git common dir).
- Optionally set repo.branch (defaults to current branch).
INIT_USAGE_EN
        ;;
      esac
      return
      ;;
    -*)
      die "$(msg init_unknown_option "$1")"
      ;;
    *)
      die "$(msg init_no_positional)"
      ;;
    esac
    shift || true
  done

  local git_common
  git_common=$(git rev-parse --git-common-dir --path-format=absolute 2> /dev/null) || die "$(msg init_run_inside_git)"

  local repo_root
  repo_root=$(dirname "$git_common")
  local repo_root_abs
  if ! repo_root_abs=$(cd "$repo_root" 2> /dev/null && pwd -P); then
    repo_root_abs="$repo_root"
  fi

  local home_dir_abs
  if ! home_dir_abs=$(cd "$HOME" 2> /dev/null && pwd -P); then
    home_dir_abs="$HOME"
  fi

  if [ "$repo_root_abs" = "$home_dir_abs" ]; then
    die "$(msg init_forbid_home "$repo_root_abs")"
  fi

  local slug
  slug=$(project_slug_for_path "$repo_root_abs") || die "$(msg init_slug_failed)"
  local target_file
  target_file=$(project_config_file_for_slug "$slug")

  config_ensure_parent_dir "$target_file" || die "$(msg config_update_failed)"

  local template_file="$SCRIPT_DIR/../config-example.kv"
  local created=0
  if [ ! -f "$target_file" ]; then
    if [ -f "$template_file" ]; then
      cp "$template_file" "$target_file" || die "$(msg config_update_failed)"
    else
      : > "$target_file" || die "$(msg config_update_failed)"
    fi
    chmod 600 "$target_file" 2> /dev/null || true
    created=1
  else
    local existing_path
    existing_path=$(config_file_get_value "$target_file" "repo.path" 2> /dev/null || true)
    if [ -n "$existing_path" ] && [ "$existing_path" != "$repo_root_abs" ]; then
      die "$(msg init_slug_mismatch "$slug" "$existing_path" "$repo_root_abs")"
    fi
  fi

  config_set_in_file "$target_file" "repo.path" "$repo_root_abs"
  info "$(msg init_set_project "$repo_root_abs")"

  if [ -z "$branch" ]; then
    local repo_current_branch=""
    repo_current_branch=$(git -C "$repo_root_abs" symbolic-ref --quiet --short HEAD 2> /dev/null || true)
    if [ -n "$repo_current_branch" ]; then
      branch="$repo_current_branch"
    else
      branch=$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)
    fi
  fi

  if [ -n "$branch" ]; then
    config_set_in_file "$target_file" "repo.branch" "$branch"
    info "$(msg init_set_branch "$branch")"
  fi

  if [ "$created" -eq 1 ]; then
    info "$(msg init_created_project "$slug" "$target_file")"
  fi

  info "$(msg init_done)"

  project_context_reset
  project_context_detect_from_cwd || true
  config_context_apply_scope
  config_cache_reset
}

remove_worktree_by_name() {
  if [ $# -ne 2 ]; then
    return 1
  fi

  local name="$1"
  local current_abs="$2"
  local target_path
  local removing_current=0

  target_path=$(worktree_path_for "$name")
  if [ ! -d "$target_path" ] && ! worktree_ref_exists "$target_path"; then
    die "$(msg worktree_not_found "$name")"
  fi

  if [ "$current_abs" = "$target_path" ]; then
    removing_current=1
  fi

  info "$(msg removing_worktree "$target_path")"
  local removal_succeeded=0
  if git_project worktree remove "$target_path" --force >&2; then
    removal_succeeded=1
  else
    if [ ! -d "$target_path" ]; then
      git_project worktree prune --expire now >&2 || true
      if ! worktree_ref_exists "$target_path"; then
        removal_succeeded=1
      fi
    fi
  fi

  if [ "$removal_succeeded" -eq 0 ]; then
    die "$(msg remove_failed)"
  fi

  local branch
  branch=$(branch_for "$name")
  if git_project show-ref --verify --quiet "refs/heads/$branch"; then
    git_project branch -D "$branch" >&2 || true
    info "$(msg removed_branch "$branch")"
  fi

  info "$(msg worktree_removed "$name")"

  if [ "$removing_current" -eq 1 ]; then
    info "$(msg current_worktree_removed)"
    maybe_warn_shell_integration "$PROJECT_DIR_ABS"
    printf '%s\n' "$PROJECT_DIR_ABS"
  fi
}

cmd_merge() {
  if [ $# -ne 1 ]; then
    die "$(msg merge_requires_name)"
  fi

  local name="$1"
  local branch
  branch=$(branch_for "$name")

  local current_branch
  current_branch=$(git_project symbolic-ref --quiet --short HEAD 2> /dev/null || true)

  local base_branch="$WORKING_REPO_BRANCH"
  if [ -z "$base_branch" ]; then
    base_branch=$(detect_repo_default_branch "$current_branch")
  fi

  local current_display="$current_branch"
  if [ -z "$current_display" ]; then
    current_display='(detached)'
  fi

  if [ -z "$base_branch" ]; then
    die "$(msg merge_main_only main "$current_display")"
  fi

  if [ "$current_display" = '(detached)' ]; then
    die "$(msg merge_main_only "$base_branch" "$current_display")"
  fi

  if [ "$current_branch" != "$base_branch" ]; then
    die "$(msg merge_main_only "$base_branch" "$current_branch")"
  fi

  if [ -n "$(git_project status --porcelain)" ]; then
    die "$(msg merge_base_dirty)"
  fi

  if [ "$branch" = "$base_branch" ]; then
    die "$(msg merge_main_only "$base_branch" "$current_branch")"
  fi

  if ! git_project show-ref --verify --quiet "refs/heads/$branch"; then
    die "$(msg merge_branch_not_found "$branch")"
  fi

  local worktree_path
  worktree_path=$(worktree_path_for "$name")
  if [ -d "$worktree_path" ]; then
    local worktree_status
    worktree_status=$(git -C "$worktree_path" status --porcelain 2> /dev/null || true)
    if [ -n "$worktree_status" ]; then
      die "$(msg merge_feat_dirty "$worktree_path")"
    fi
  fi

  local ahead_count
  ahead_count=$(git_project rev-list --count "$base_branch..$branch" 2> /dev/null || true)
  if [ -z "$ahead_count" ]; then
    ahead_count=0
  fi

  if [ "$ahead_count" -eq 0 ]; then
    info "$(msg merge_no_commits "$branch" "$base_branch")"
    return
  fi

  info "$(msg merge_start "$branch" "$base_branch")"
  if git_project merge --no-edit "$branch" >&2; then
    info "$(msg merge_done "$branch" "$base_branch")"
    info "$(msg merge_cleanup_hint "$name")"
  else
    git_project merge --abort >&2 || true
    die "$(msg merge_conflict_abort)"
  fi
}

sync_exclude_pathspec() {
  local dir="$SERVE_DEV_LOGGING_PATH"

  if [ -z "$dir" ]; then
    return 0
  fi

  dir="${dir%/}"
  dir="${dir#/}"

  if [ -z "$dir" ]; then
    return 0
  fi

  printf ':(exclude)%s/**\n' "$dir"
}

cmd_sync() {
  if [ $# -eq 0 ]; then
    die "$(msg sync_requires_target)"
  fi

  local base_branch="$WORKING_REPO_BRANCH"
  local current_branch=""
  current_branch=$(git_project symbolic-ref --quiet --short HEAD 2> /dev/null || true)

  if [ -z "$base_branch" ]; then
    base_branch=$(detect_repo_default_branch "$current_branch")
  fi

  if [ -z "$base_branch" ]; then
    die "$(msg merge_main_only main "${current_branch:-'(detached)'}")"
  fi

  if [ -z "$current_branch" ]; then
    die "$(msg merge_main_only "$base_branch" "(detached)")"
  fi

  if [ "$current_branch" != "$base_branch" ]; then
    die "$(msg merge_main_only "$base_branch" "$current_branch")"
  fi

  if ! git_project diff --quiet; then
    die "$(msg sync_base_dirty)"
  fi

  local sync_exclude
  sync_exclude=$(sync_exclude_pathspec)

  local base_untracked=""
  if [ -n "$sync_exclude" ]; then
    base_untracked=$(git_project ls-files --others --exclude-standard -- "$sync_exclude")
  else
    base_untracked=$(git_project ls-files --others --exclude-standard)
  fi

  if [ -n "$base_untracked" ]; then
    die "$(msg sync_base_dirty)"
  fi

  local mode_all=0
  local -a target_names=()
  local -a target_paths=()

  if [ "$1" = "all" ]; then
    if [ $# -gt 1 ]; then
      die "$(msg sync_invalid_all)"
    fi
    mode_all=1
  else
    local name
    for name in "$@"; do
      if [ "$name" = "$base_branch" ]; then
        info "$(msg sync_skip_base "$base_branch")"
        continue
      fi

      local path
      path=$(worktree_path_for "$name")
      if [ ! -d "$path" ]; then
        die "$(msg worktree_not_found "$name")"
      fi

      if [ "$path" = "$PROJECT_DIR_ABS" ]; then
        info "$(msg sync_skip_base "$base_branch")"
        continue
      fi

      target_names+=("$name")
      target_paths+=("$path")
    done
  fi

  if [ "$mode_all" -eq 1 ]; then
    local current_path=""
    while IFS= read -r line || [ -n "$line" ]; do
      if [ -z "$line" ]; then
        if [ -n "$current_path" ] && [ "$current_path" != "$PROJECT_DIR_ABS" ]; then
          local base
          base=$(basename "$current_path")
          if [[ "$base" == "$WORKTREE_NAME_PREFIX"* ]]; then
            local suffix="${base#"$WORKTREE_NAME_PREFIX"}"
            if [ -n "$suffix" ]; then
              target_names+=("$suffix")
              target_paths+=("$current_path")
            fi
          fi
        fi
        current_path=""
        continue
      fi
      case "$line" in
      worktree\ *)
        current_path="${line#worktree }"
        ;;
      esac
    done < <(git_project worktree list --porcelain)

    if [ -n "$current_path" ] && [ "$current_path" != "$PROJECT_DIR_ABS" ]; then
      local base
      base=$(basename "$current_path")
      if [[ "$base" == "$WORKTREE_NAME_PREFIX"* ]]; then
        local suffix="${base#"$WORKTREE_NAME_PREFIX"}"
        if [ -n "$suffix" ]; then
          target_names+=("$suffix")
          target_paths+=("$current_path")
        fi
      fi
    fi
  fi

  local target_count=${#target_paths[@]}
  if [ "$target_count" -eq 0 ]; then
    info "$(msg sync_no_targets)"
    return
  fi

  if git_project diff --cached --quiet; then
    info "$(msg sync_no_staged)"
    return
  fi

  local patch_file
  patch_file=$(mktemp "${TMPDIR:-/tmp}/wt-sync-XXXXXX.patch") || die "$(msg temp_file_failed)"
  trap 'rm -f "$patch_file"' RETURN EXIT

  if ! git_project diff --cached --binary > "$patch_file"; then
    rm -f "$patch_file"
    trap - RETURN EXIT
    die "$(msg sync_patch_failed)"
  fi

  local idx=0
  while [ "$idx" -lt "$target_count" ]; do
    local path="${target_paths[$idx]}"
    local name="${target_names[$idx]}"
    local status
    if [ -n "$sync_exclude" ]; then
      status=$(git -C "$path" status --porcelain -- "$sync_exclude" 2> /dev/null || true)
    else
      status=$(git -C "$path" status --porcelain 2> /dev/null || true)
    fi
    if [ -n "$status" ]; then
      rm -f "$patch_file"
      trap - RETURN EXIT
      die "$(msg sync_target_dirty "$name" "$path")"
    fi

    if ! git -C "$path" apply --check --index --3way --binary "$patch_file"; then
      rm -f "$patch_file"
      trap - RETURN EXIT
      die "$(msg sync_apply_failed "$name")"
    fi
    idx=$((idx + 1))
  done

  idx=0
  local success=0
  while [ "$idx" -lt "$target_count" ]; do
    local path="${target_paths[$idx]}"
    local name="${target_names[$idx]}"
    info "$(msg sync_apply_start "$name")"
    if git -C "$path" apply --index --3way --binary "$patch_file"; then
      success=$((success + 1))
      info "$(msg sync_apply_done "$name")"
    else
      rm -f "$patch_file"
      trap - RETURN EXIT
      die "$(msg sync_apply_failed "$name")"
    fi
    idx=$((idx + 1))
  done

  rm -f "$patch_file"
  trap - RETURN EXIT

  info "$(msg sync_done "$success")"
}

cmd_remove() {
  local assume_yes=0
  local -a names=()

  while [ $# -gt 0 ]; do
    case "$1" in
    -y | --yes | yes)
      assume_yes=1
      ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    -*)
      die "$(msg remove_unknown_option "$1")"
      ;;
    *)
      names+=("$1")
      ;;
    esac
    shift || true
  done

  local current_abs
  current_abs=$(pwd -P)

  if [ ${#names[@]} -eq 0 ]; then
    if [ "$current_abs" = "$PROJECT_DIR_ABS" ]; then
      die "$(msg cannot_remove_main)"
    fi

    local current_base
    current_base=$(basename "$current_abs")
    if [[ "$current_base" != "$WORKTREE_NAME_PREFIX"* ]]; then
      die "$(msg specify_worktree_or_inside)"
    fi

    local derived_name
    derived_name="${current_base#"$WORKTREE_NAME_PREFIX"}"

    if [ "$assume_yes" -eq 0 ]; then
      printf '%s ' "$(msg remove_confirm_prompt "$derived_name")" >&2
      read -r reply
      if [ -n "$reply" ] && [[ ! "$reply" =~ ^[Yy]$ ]]; then
        info "$(msg aborted)"
        return 1
      fi
    fi

    remove_worktree_by_name "$derived_name" "$current_abs"
    return
  fi

  local name
  for name in "${names[@]}"; do
    remove_worktree_by_name "$name" "$current_abs"
  done
}

cmd_remove_global() {
  local assume_yes=0
  local -a names=()

  while [ $# -gt 0 ]; do
    case "$1" in
    -y | --yes | yes)
      assume_yes=1
      ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    -*)
      die "$(msg remove_unknown_option "$1")"
      ;;
    *)
      names+=("$1")
      ;;
    esac
    shift || true
  done

  if [ ${#names[@]} -eq 0 ]; then
    die "$(msg command_requires_project)"
  fi

  local current_abs
  current_abs=$(pwd -P)

  local name
  for name in "${names[@]}"; do
    collect_global_worktree_matches "$name"
    local matches=${#MATCH_WORKTREE_NAMES[@]}

    if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
      die "$(msg no_projects_configured)"
    fi

    if [ "$matches" -eq 0 ]; then
      info "$(msg worktree_not_found "$name")"
      continue
    fi

    local idx=0
    while [ "$idx" -lt "$matches" ]; do
      local project_index="${MATCH_WORKTREE_PROJECTS[$idx]}"
      local repo_path="${PROJECT_REGISTRY_PATHS[$project_index]}"
      local repo_slug="${PROJECT_REGISTRY_SLUGS[$project_index]}"
      local branch_prefix="${PROJECT_REGISTRY_BRANCH_PREFIXES[$project_index]}"
      local dir_prefix="${PROJECT_REGISTRY_DIR_PREFIXES[$project_index]}"
      local target_path="${MATCH_WORKTREE_PATHS[$idx]}"

      if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
        info "$(msg project_path_missing "$repo_slug")"
        idx=$((idx + 1))
        continue
      fi

      if [ "$assume_yes" -eq 0 ]; then
        printf '%s ' "$(msg remove_confirm_prompt_global "$name" "$repo_slug" "$target_path")" >&2
        local reply=""
        read -r reply
        if [ -n "$reply" ] && [[ ! "$reply" =~ ^[Yy]$ ]]; then
          info "$(msg aborted)"
          idx=$((idx + 1))
          continue
        fi
      fi

      if [ -z "$branch_prefix" ]; then
        branch_prefix="$CONFIG_DEFAULT_WORKTREE_ADD_BRANCH_PREFIX"
      fi
      local branch_name=""
      if [ -n "$branch_prefix" ]; then
        branch_name="${branch_prefix}${name}"
      fi

      info "$(msg removing_worktree "$target_path")"
      if git_at_path "$repo_path" worktree remove "$target_path" --force >&2; then
        if [ -n "$branch_name" ]; then
          git_at_path "$repo_path" branch -D "$branch_name" > /dev/null 2>&1 || true
        fi
        git_at_path "$repo_path" worktree prune --expire now >&2 || true
        info "$(msg worktree_removed "$target_path")"

        if [ "$current_abs" = "$target_path" ]; then
          info "$(msg clean_switch_back)"
          maybe_warn_shell_integration "$repo_path"
          printf '%s\n' "$repo_path"
        fi
      else
        info "$(msg remove_failed "$target_path")"
      fi

      idx=$((idx + 1))
    done
  done
}

cmd_detach() {
  local force=0
  local slug=""

  while [ $# -gt 0 ]; do
    case "$1" in
    -y | --yes | --force)
      force=1
      ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    --*)
      die "$(msg detach_unknown_option "$1")"
      ;;
    *)
      if [ -n "$slug" ]; then
        die "$(msg unexpected_extra_argument "$1")"
      fi
      slug="$1"
      ;;
    esac
    shift || true
  done

  case "$CURRENT_SCOPE" in
  project)
    if [ -z "$slug" ]; then
      if [ -n "$PROJECT_SLUG" ]; then
        slug="$PROJECT_SLUG"
      elif [ -n "$PROJECT_DIR_ABS" ]; then
        slug=$(project_slug_for_path "$PROJECT_DIR_ABS" 2> /dev/null || true)
      fi
    fi
    if [ -z "$slug" ]; then
      die "$(msg detach_project_missing "unknown")"
    fi
    ;;
  global)
    project_registry_collect
    if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
      die "$(msg detach_no_projects)"
    fi

    if [ -z "$slug" ]; then
      if ! project_prompt_select; then
        if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
          die "$(msg detach_no_projects)"
        fi
        die "$(msg project_selection_cancelled)"
      fi

      local idx="$PROJECT_SELECTION_INDEX"
      if [ "$idx" -lt 0 ]; then
        die "$(msg project_selection_cancelled)"
      fi

      slug="${PROJECT_REGISTRY_SLUGS[$idx]}"
    fi
    ;;
  unconfigured)
    die "$(msg project_dir_unset)"
    ;;
  esac

  if [ -z "$slug" ]; then
    die "$(msg detach_project_missing "unknown")"
  fi

  local rc=0
  project_detach "$slug" "$force"
  rc=$?
  return "$rc"
}

cmd_clean() {
  [ $# -eq 0 ] || die "$(msg clean_no_args)"
  local removed=0
  local current_abs
  current_abs=$(pwd -P)
  local current_removed=0

  while IFS= read -r line; do
    case "$line" in
    worktree\ *)
      local worktree_path base suffix branch_name
      worktree_path="${line#worktree }"
      base=$(basename "$worktree_path")
      if [[ "$base" == "$WORKTREE_NAME_PREFIX"* ]]; then
        suffix="${base#"$WORKTREE_NAME_PREFIX"}"
        if [[ "$suffix" =~ ^[0-9]+$ ]]; then
          info "$(msg cleaning_worktree "$suffix")"
          git_project worktree remove "$worktree_path" --force >&2 || true
          branch_name=$(branch_for "$suffix")
          git_project branch -D "$branch_name" > /dev/null 2>&1 || true
          removed=$((removed + 1))
          if [ "$current_abs" = "$worktree_path" ]; then
            current_removed=1
          fi
        fi
      fi
      ;;
    esac
  done < <(git_project worktree list --porcelain)

  if [ "$removed" -gt 0 ]; then
    info "$(msg cleaned_count "$removed")"
  else
    info "$(msg cleaned_none)"
  fi

  if [ "$current_removed" -eq 1 ]; then
    info "$(msg clean_switch_back)"
    maybe_warn_shell_integration "$PROJECT_DIR_ABS"
    printf '%s\n' "$PROJECT_DIR_ABS"
  fi
}

cmd_clean_global() {
  [ $# -eq 0 ] || die "$(msg clean_no_args)"

  project_registry_collect
  if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
    die "$(msg no_projects_configured)"
  fi

  local -a candidate_paths=()
  local -a candidate_suffix=()
  local -a candidate_projects=()

  local idx=0
  while [ "$idx" -lt "$PROJECT_REGISTRY_COUNT" ]; do
    local repo_path="${PROJECT_REGISTRY_PATHS[$idx]}"
    local dir_prefix="${PROJECT_REGISTRY_DIR_PREFIXES[$idx]}"
    local branch_prefix="${PROJECT_REGISTRY_BRANCH_PREFIXES[$idx]}"
    if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
      idx=$((idx + 1))
      continue
    fi

    if [ -z "$dir_prefix" ]; then
      local base
      base=$(basename "$repo_path")
      if [ -n "$base" ] && [ "$base" != "." ]; then
        dir_prefix="$base."
      fi
    fi

    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
      worktree\ *)
        local wt_path="${line#worktree }"
        local base
        base=$(basename "$wt_path")
        if [ -n "$dir_prefix" ] && [[ "$base" == "$dir_prefix"* ]]; then
          local suffix="${base#"$dir_prefix"}"
          if [[ "$suffix" =~ ^[0-9]+$ ]]; then
            candidate_paths+=("$wt_path")
            candidate_suffix+=("$suffix")
            candidate_projects+=("$idx")
          fi
        fi
        ;;
      esac
    done < <(git_at_path "$repo_path" worktree list --porcelain 2> /dev/null || true)

    idx=$((idx + 1))
  done

  local total=${#candidate_paths[@]}
  if [ "$total" -eq 0 ]; then
    info "$(msg cleaned_none)"
    return
  fi

  local removed=0
  local current_abs
  current_abs=$(pwd -P)
  local switch_back_path=""

  idx=0
  while [ "$idx" -lt "$total" ]; do
    local repo_index="${candidate_projects[$idx]}"
    local repo_path="${PROJECT_REGISTRY_PATHS[$repo_index]}"
    local repo_slug="${PROJECT_REGISTRY_SLUGS[$repo_index]}"
    local dir_prefix="${PROJECT_REGISTRY_DIR_PREFIXES[$repo_index]}"
    local branch_prefix="${PROJECT_REGISTRY_BRANCH_PREFIXES[$repo_index]}"
    local wt_path="${candidate_paths[$idx]}"
    local suffix="${candidate_suffix[$idx]}"

    if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
      idx=$((idx + 1))
      continue
    fi

    printf '%s ' "$(msg clean_confirm_prompt "$suffix" "$repo_slug" "$wt_path")" >&2
    local reply=""
    read -r reply
    if [ -z "$reply" ]; then
      reply="y"
    fi
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      idx=$((idx + 1))
      continue
    fi

    info "$(msg cleaning_worktree "$suffix")"
    if git_at_path "$repo_path" worktree remove "$wt_path" --force >&2; then
      local branch_name=""
      if [ -z "$branch_prefix" ]; then
        branch_prefix="$CONFIG_DEFAULT_WORKTREE_ADD_BRANCH_PREFIX"
      fi
      if [ -n "$branch_prefix" ]; then
        branch_name="${branch_prefix}${suffix}"
        git_at_path "$repo_path" branch -D "$branch_name" > /dev/null 2>&1 || true
      fi
      git_at_path "$repo_path" worktree prune --expire now >&2 || true
      removed=$((removed + 1))
      if [ "$current_abs" = "$wt_path" ]; then
        switch_back_path="$repo_path"
      fi
    else
      info "$(msg remove_failed "$wt_path")"
    fi

    idx=$((idx + 1))
  done

  if [ "$removed" -gt 0 ]; then
    info "$(msg cleaned_count "$removed")"
  else
    info "$(msg cleaned_none)"
  fi

  if [ -n "$switch_back_path" ]; then
    maybe_warn_shell_integration "$switch_back_path"
    printf '%s\n' "$switch_back_path"
  fi
}

wt_main() {
  init_settings
  ensure_messages_loaded

  local command=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --)
      shift
      break
      ;;
    -*)
      usage_exit 1
      ;;
    *)
      break
      ;;
    esac
    shift || true
  done

  if [ $# -eq 0 ]; then
    command="help"
  else
    command="$1"
    shift || true
  fi

  local scope
  scope=$(current_scope)
  CURRENT_SCOPE="$scope"

  case "$command" in
  config)
    cmd_config "$@"
    return
    ;;
  shell-hook)
    cmd_shell_hook "$@"
    return
    ;;
  uninstall)
    cmd_uninstall "$@"
    return
    ;;
  reinstall)
    cmd_reinstall "$@"
    return
    ;;
  init)
    cmd_init "$@"
    return
    ;;
  help)
    usage
    return
    ;;
  version)
    printf '%s\n' "$VERSION"
    return
    ;;
  esac

  case "$command" in
  list)
    case "$scope" in
    project)
      resolve_project
      cmd_list "$@"
      ;;
    global)
      cmd_list_global "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  add)
    if [ "$scope" != "project" ]; then
      die "$(msg command_requires_project)"
    fi
    [ $# -ge 1 ] || die "$(msg add_requires_name)"
    resolve_project
    cmd_add "$@"
    ;;
  merge)
    if [ "$scope" != "project" ]; then
      die "$(msg command_requires_project)"
    fi
    resolve_project
    cmd_merge "$@"
    ;;
  sync)
    if [ "$scope" != "project" ]; then
      die "$(msg command_requires_project)"
    fi
    resolve_project
    cmd_sync "$@"
    ;;
  rm | remove)
    case "$scope" in
    project)
      resolve_project
      cmd_remove "$@"
      ;;
    global)
      cmd_remove_global "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  detach)
    case "$scope" in
    project)
      resolve_project
      cmd_detach "$@"
      ;;
    global)
      cmd_detach "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  clean)
    case "$scope" in
    project)
      resolve_project
      cmd_clean "$@"
      ;;
    global)
      cmd_clean_global "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  main)
    case "$scope" in
    project)
      resolve_project
      cmd_main "$@"
      ;;
    global)
      cmd_main_global "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  path)
    case "$scope" in
    project)
      resolve_project
      cmd_path "$@"
      ;;
    global)
      cmd_path_global "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  *)
    case "$scope" in
    project)
      resolve_project
      cmd_path "$command" "$@"
      ;;
    global)
      cmd_path_global "$command" "$@"
      ;;
    unconfigured)
      die "$(msg project_dir_unset)"
      ;;
    esac
    ;;
  esac
}
