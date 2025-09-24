# shellcheck shell=bash

# shellcheck disable=SC2034  # Exported for commands module (wt version)
readonly VERSION="0.1.0"

readonly CONFIG_DIR_DEFAULT="$HOME/.worktree.sh"
readonly CONFIG_FILE_DEFAULT="$CONFIG_DIR_DEFAULT/config.kv"
readonly CONFIG_PROJECTS_DIR="$CONFIG_DIR_DEFAULT/projects"
readonly CONFIG_PROJECT_FILENAME="config.kv"

CONFIG_FILE="$CONFIG_FILE_DEFAULT"
CONFIG_FILE_IS_ENV_OVERRIDE=0

if [ -n "${WT_CONFIG_FILE:-}" ]; then
  CONFIG_FILE="$WT_CONFIG_FILE"
  CONFIG_FILE_IS_ENV_OVERRIDE=1
fi

CONFIG_CACHE_SOURCES=("$CONFIG_FILE")

readonly CONFIG_DEFAULT_WORKING_REPO_PATH="${HOME}/Developer/your-project"
readonly CONFIG_DEFAULT_WORKTREE_ADD_BRANCH_PREFIX="feat/"
readonly CONFIG_DEFAULT_SERVE_DEV_LOGGING_PATH="tmp"
readonly CONFIG_DEFAULT_SERVE_DEV_ENABLED=1
readonly CONFIG_DEFAULT_INSTALL_DEPS_ENABLED=1
readonly CONFIG_DEFAULT_COPY_ENV_ENABLED=1
readonly CONFIG_DEFAULT_INSTALL_DEPS_COMMAND=""
readonly CONFIG_DEFAULT_SERVE_DEV_COMMAND=""
readonly CONFIG_DEFAULT_LANGUAGE="en"
readonly -a CONFIG_DEFAULT_COPY_ENV_FILES=(".env" ".env.local")

WORKING_REPO_PATH=""
WORKTREE_NAME_PREFIX=""
WORKTREE_BRANCH_PREFIX=""
WORKING_REPO_BRANCH=""
SERVE_DEV_LOGGING_PATH=""
SERVE_DEV_ENABLED=0
INSTALL_DEPS_ENABLED=0
COPY_ENV_ENABLED=0
INSTALL_DEPS_COMMAND=""
SERVE_DEV_COMMAND=""
LANGUAGE="$CONFIG_DEFAULT_LANGUAGE"
WORKING_REPO_PATH_CONFIGURED=0
COPY_ENV_FILE_SELECTION=()

: "${SCRIPT_DIR:?SCRIPT_DIR must be set before sourcing runtime.sh}"
readonly MESSAGES_FILE="$SCRIPT_DIR/messages.sh"
MESSAGES_LOADED=0
AUTO_CD_HINT_SHOWN=0

ensure_messages_loaded() {
  if [ "$MESSAGES_LOADED" = "1" ]; then
    return
  fi

  if [ -f "$MESSAGES_FILE" ]; then
    # shellcheck disable=SC1090
    . "$MESSAGES_FILE"
    MESSAGES_LOADED=1
    return
  fi

  printf 'wt: missing messages file (%s)\n' "$MESSAGES_FILE" >&2
  exit 1
}

normalize_language() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  local raw
  raw=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  raw=${raw%%.*}
  raw=${raw//-/_}

  case "$raw" in
  zh | zh_cn | zh_hans | zh_hant | zh_tw | cn | chinese | 中文)
    printf 'zh\n'
    return 0
    ;;
  en | en_us | en_gb | english | 英语)
    printf 'en\n'
    return 0
    ;;
  esac

  return 1
}

language_code_to_config_value() {
  case "${1:-}" in
  zh)
    printf 'zh\n'
    ;;
  en)
    printf 'en\n'
    ;;
  *)
    printf '%s\n' "${1:-}"
    ;;
  esac
}

init_language() {
  LANGUAGE="$CONFIG_DEFAULT_LANGUAGE"

  local value normalized from_config=0
  if value=$(config_get "language" 2> /dev/null); then
    if normalized=$(normalize_language "$value" 2> /dev/null); then
      LANGUAGE="$normalized"
      from_config=1
    fi
  fi

  value="${LANG:-}"
  if [ "$from_config" -eq 0 ] && [ -n "$value" ]; then
    if normalized=$(normalize_language "$value" 2> /dev/null); then
      LANGUAGE="$normalized"
    fi
  fi
}

detect_shell_type() {
  local shell_name="${SHELL##*/}"
  case "$shell_name" in
  bash)
    printf 'bash\n'
    ;;
  zsh)
    printf 'zsh\n'
    ;;
  *)
    printf 'none\n'
    ;;
  esac
}

msg() {
  ensure_messages_loaded
  local key
  key="${1:-}"
  shift || true
  case "$LANGUAGE" in
  zh)
    msg_zh "$key" "$@"
    ;;
  *)
    msg_en "$key" "$@"
    ;;
  esac
}

parse_bool() {
  if [ $# -ne 1 ]; then
    return 1
  fi
  local lower
  lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
  1 | true | yes | on)
    printf '1\n'
    ;;
  0 | false | no | off)
    printf '0\n'
    ;;
  *)
    return 1
    ;;
  esac
}

CONFIG_CACHE_LOADED=0
CONFIG_CACHE_KEYS=()
CONFIG_CACHE_VALUES=()
CONFIG_CACHE_SOURCES=()

config_cache_reset() {
  CONFIG_CACHE_LOADED=0
  CONFIG_CACHE_KEYS=()
  CONFIG_CACHE_VALUES=()
}

config_cache_sources_set() {
  CONFIG_CACHE_SOURCES=("$@")
  config_cache_reset
}

config_cache_put() {
  if [ $# -ne 2 ]; then
    return 1
  fi

  local key="$1"
  local value="$2"
  local idx

  for idx in "${!CONFIG_CACHE_KEYS[@]}"; do
    if [ "${CONFIG_CACHE_KEYS[$idx]}" = "$key" ]; then
      # shellcheck disable=SC2004
      CONFIG_CACHE_VALUES[$idx]="$value"
      return 0
    fi
  done

  CONFIG_CACHE_KEYS+=("$key")
  CONFIG_CACHE_VALUES+=("$value")
  return 0
}

config_ensure_parent_dir() {
  if [ $# -ne 1 ]; then
    return 1
  fi
  local target="$1"
  local parent
  parent=$(dirname "$target")
  if [ -n "$parent" ] && [ ! -d "$parent" ]; then
    mkdir -p "$parent"
  fi
}

hash_prefix_six() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  local input="$1"
  local hash

  hash=$(printf '%s' "$input" | git hash-object --stdin 2> /dev/null || true)
  if [ -z "$hash" ]; then
    hash=$(printf '%s' "$input" | shasum 2> /dev/null | awk '{print $1}' || true)
  fi
  if [ -z "$hash" ]; then
    hash=$(printf '%s' "$input" | md5sum 2> /dev/null | awk '{print $1}' || true)
  fi
  if [ -z "$hash" ]; then
    hash=$(printf '%s' "$input" | md5 2> /dev/null | awk '{print $4}' || true)
  fi
  if [ -z "$hash" ]; then
    local cksum_out=""
    cksum_out=$(printf '%s' "$input" | cksum 2> /dev/null || true)
    if [ -n "$cksum_out" ]; then
      hash=$(printf '%s' "$cksum_out" | awk '{printf "%08x", $1}' || true)
    fi
  fi

  if [ -z "$hash" ]; then
    hash="000000"
  fi

  printf '%s\n' "${hash:0:6}"
}

sanitize_project_path_fragment() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  local fragment="$1"
  fragment=${fragment#/}
  fragment=$(printf '%s' "$fragment" | tr "/\\" "--")
  fragment=${fragment//./-}
  fragment=$(printf '%s' "$fragment" | tr -c 'A-Za-z0-9-' '-')
  fragment=$(printf '%s' "$fragment" | tr -s '-')
  fragment=${fragment#-}
  fragment=${fragment%-}
  if [ -z "$fragment" ]; then
    fragment="project"
  fi
  printf '%s\n' "-$fragment"
}

project_slug_for_path() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  local input_path="$1"
  local abs_path="$input_path"
  if abs_path=$(cd "$input_path" 2> /dev/null && pwd -P); then
    :
  else
    abs_path="$input_path"
  fi

  local trimmed="$abs_path"
  trimmed="${trimmed#/}"
  local fragment
  fragment=$(sanitize_project_path_fragment "$trimmed") || fragment="-project"

  local slug="$fragment"

  local slug_dir=""
  slug_dir=$(project_config_dir_for_slug "$slug" 2> /dev/null || true)
  if [ -n "$slug_dir" ] && [ -d "$slug_dir" ]; then
    local config_file="$slug_dir/$CONFIG_PROJECT_FILENAME"
    local existing_path=""
    if [ -f "$config_file" ]; then
      existing_path=$(config_file_get_value "$config_file" "repo.path" 2> /dev/null || true)
    fi
    if [ -n "$existing_path" ] && [ "$existing_path" != "$abs_path" ]; then
      local hash
      hash=$(hash_prefix_six "$abs_path") || hash=""
      if [ -n "$hash" ]; then
        slug="${slug}-${hash}"
      fi
    fi
  fi

  printf '%s\n' "$slug"
}

project_config_dir_for_slug() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  printf '%s/%s\n' "$CONFIG_PROJECTS_DIR" "$1"
}

project_config_file_for_slug() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  printf '%s/%s\n' "$(project_config_dir_for_slug "$1")" "$CONFIG_PROJECT_FILENAME"
}

PROJECT_SLUG=""
PROJECT_CONFIG_FILE=""
PROJECT_CONFIG_EXISTS=0
PROJECT_DETECTED_ROOT=""

project_context_reset() {
  PROJECT_SLUG=""
  PROJECT_CONFIG_FILE=""
  PROJECT_CONFIG_EXISTS=0
  PROJECT_DETECTED_ROOT=""
  PROJECT_DIR=""
  PROJECT_DIR_ABS=""
  PROJECT_PARENT=""
}

project_context_detect_from_cwd() {
  local git_common
  git_common=$(git rev-parse --git-common-dir --path-format=absolute 2> /dev/null || true)
  if [ -z "$git_common" ]; then
    return 1
  fi

  local root="$git_common"
  root=$(dirname "$root")
  if root=$(cd "$root" 2> /dev/null && pwd -P); then
    :
  fi

  PROJECT_DETECTED_ROOT="$root"
  PROJECT_SLUG=$(project_slug_for_path "$root" 2> /dev/null || true)
  if [ -n "$PROJECT_SLUG" ]; then
    PROJECT_CONFIG_FILE=$(project_config_file_for_slug "$PROJECT_SLUG" 2> /dev/null || true)
  fi

  if [ -n "$PROJECT_CONFIG_FILE" ] && [ -f "$PROJECT_CONFIG_FILE" ]; then
    PROJECT_CONFIG_EXISTS=1
  else
    PROJECT_CONFIG_EXISTS=0
  fi

  return 0
}

config_context_apply_scope() {
  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 1 ]; then
    config_cache_sources_set "$CONFIG_FILE"
    return
  fi

  local -a sources=()

  sources+=("$CONFIG_FILE_DEFAULT")

  if [ -n "$PROJECT_CONFIG_FILE" ]; then
    sources+=("$PROJECT_CONFIG_FILE")
    CONFIG_FILE="$PROJECT_CONFIG_FILE"
  else
    CONFIG_FILE="$CONFIG_FILE_DEFAULT"
  fi

  config_cache_sources_set "${sources[@]}"
}

PROJECT_REGISTRY_SLUGS=()
PROJECT_REGISTRY_PATHS=()
PROJECT_REGISTRY_BRANCHES=()
PROJECT_REGISTRY_BRANCH_PREFIXES=()
PROJECT_REGISTRY_DIR_PREFIXES=()
PROJECT_REGISTRY_FILES=()
PROJECT_REGISTRY_DISPLAY_NAMES=()
PROJECT_REGISTRY_HEADS=()
PROJECT_REGISTRY_COUNT=0

PROJECT_SELECTION_INDEX=-1
WORKTREE_SELECTION_INDEX=-1
MATCH_WORKTREE_NAMES=()
MATCH_WORKTREE_PATHS=()
MATCH_WORKTREE_PROJECTS=()
MATCH_WORKTREE_COUNT=0

worktree_match_reset() {
  MATCH_WORKTREE_NAMES=()
  MATCH_WORKTREE_PATHS=()
  MATCH_WORKTREE_PROJECTS=()
  WORKTREE_SELECTION_INDEX=-1
  MATCH_WORKTREE_COUNT=0
}

PROJECT_WORKTREE_PATHS=()
PROJECT_WORKTREE_NAMES=()
PROJECT_WORKTREE_BRANCHES=()
PROJECT_WORKTREE_BRANCH_SUFFIXES=()
PROJECT_WORKTREE_COUNT=0
PROJECT_WORKTREE_REPO_PATH=""
PROJECT_WORKTREE_REPO_EXISTS=0
PROJECT_WORKTREE_CONFIG_DIR=""
PROJECT_WORKTREE_CONFIG_FILE=""
PROJECT_WORKTREE_STATUS=""
PROJECT_WORKTREE_LAST_ERROR=""
PROJECT_WORKTREE_SLUG=""
PROJECT_REMOVE_LAST_ERROR=""

project_worktree_reset() {
  PROJECT_WORKTREE_PATHS=()
  PROJECT_WORKTREE_NAMES=()
  PROJECT_WORKTREE_BRANCHES=()
  PROJECT_WORKTREE_BRANCH_SUFFIXES=()
  PROJECT_WORKTREE_COUNT=0
  PROJECT_WORKTREE_REPO_PATH=""
  PROJECT_WORKTREE_REPO_EXISTS=0
  PROJECT_WORKTREE_CONFIG_DIR=""
  PROJECT_WORKTREE_CONFIG_FILE=""
  PROJECT_WORKTREE_STATUS=""
  PROJECT_WORKTREE_LAST_ERROR=""
  PROJECT_WORKTREE_SLUG=""
  PROJECT_REMOVE_LAST_ERROR=""
}

project_worktree_maybe_add() {
  local path="${1:-}"
  local branch="${2:-}"
  local repo_path="${3:-}"
  local dir_prefix="${4:-}"
  local branch_prefix="${5:-}"

  if [ -z "$path" ] || [ "$path" = "$repo_path" ]; then
    return 0
  fi

  local base
  base=$(basename "$path")

  local include=0
  local suffix=""

  if [ -n "$dir_prefix" ] && [[ "$base" == "$dir_prefix"* ]]; then
    suffix="${base#"$dir_prefix"}"
    include=1
  fi

  if [ "$include" -eq 0 ] && [ -n "$branch_prefix" ] && [ -n "$branch" ] && [[ "$branch" == "$branch_prefix"* ]]; then
    suffix="${branch#"$branch_prefix"}"
    include=1
  fi

  if [ "$include" -eq 0 ] && [ -z "$dir_prefix" ] && [ -z "$branch_prefix" ]; then
    suffix="$base"
    include=1
  fi

  if [ "$include" -eq 0 ]; then
    return 0
  fi

  if [ -z "$suffix" ]; then
    suffix="$base"
  fi

  local branch_suffix="$branch"
  if [ -n "$branch" ] && [ -n "$branch_prefix" ] && [[ "$branch" == "$branch_prefix"* ]]; then
    branch_suffix="${branch#"$branch_prefix"}"
  fi

  PROJECT_WORKTREE_PATHS+=("$path")
  PROJECT_WORKTREE_NAMES+=("$suffix")
  PROJECT_WORKTREE_BRANCHES+=("$branch")
  PROJECT_WORKTREE_BRANCH_SUFFIXES+=("$branch_suffix")
  PROJECT_WORKTREE_COUNT=${#PROJECT_WORKTREE_PATHS[@]}
}

tty_menu_select() {
  if [ $# -lt 3 ]; then
    return 1
  fi

  local prompt="$1"
  local invalid_message="$2"
  shift 2

  local -a options=("$@")
  local count=${#options[@]}

  if [ "$count" -eq 0 ]; then
    return 1
  fi

  if [ ! -t 0 ] || [ ! -t 2 ]; then
    return 2
  fi

  local selected=0
  local typed=""
  local error_message=""
  local last_lines=0
  local read_timeout_short=0
  local highlight_start=$'\033[36m'
  local highlight_end=$'\033[0m'
  if [ -n "${BASH_VERSINFO+x}" ]; then
    local bash_major
    bash_major="${BASH_VERSINFO[0]}"
    if [ "$bash_major" -ge 4 ]; then
      read_timeout_short='0.05'
    fi
  fi

  while true; do
    local lines=1
    printf '%s\n' "$prompt" >&2

    local idx=0
    while [ "$idx" -lt "$count" ]; do
      if [ "$idx" -eq "$selected" ]; then
        printf '%s> %s%s\n' "$highlight_start" "${options[$idx]}" "$highlight_end" >&2
      else
        printf '  %s\n' "${options[$idx]}" >&2
      fi
      lines=$((lines + 1))
      idx=$((idx + 1))
    done

    if [ -n "$error_message" ]; then
      printf '%s\n' "$error_message" >&2
      lines=$((lines + 1))
    fi

    last_lines=$lines
    error_message=""

    local key=""
    if ! IFS= read -rsn1 key; then
      printf '\n' >&2
      return 1
    fi

    if [ -z "$key" ]; then
      key=$'\n'
    fi

    case "$key" in
    $'\n' | $'\r')
      if [ -n "$typed" ]; then
        local choice=$((10#$typed))
        if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
          printf '\n' >&2
          printf '%d\n' "$((choice - 1))"
          return 0
        fi
        error_message="$invalid_message"
        typed=""
      else
        printf '\n' >&2
        printf '%d\n' "$selected"
        return 0
      fi
      ;;
    $'\x1b')
      local key2=""
      if ! IFS= read -rsn1 -t "$read_timeout_short" key2; then
        printf '\n' >&2
        return 1
      fi
      if [ "$key2" = "[" ]; then
        local key3=""
        if ! IFS= read -rsn1 -t "$read_timeout_short" key3; then
          continue
        fi
        case "$key3" in
        A)
          selected=$(((selected - 1 + count) % count))
          typed=""
          ;;
        B)
          selected=$(((selected + 1) % count))
          typed=""
          ;;
        esac
      else
        printf '\n' >&2
        return 1
      fi
      ;;
    $'\177')
      if [ -n "$typed" ]; then
        typed="${typed%?}"
      fi
      ;;
    [0-9])
      typed="${typed}${key}"
      local choice=$((10#$typed))
      if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        selected=$((choice - 1))
      else
        if [ "$choice" -gt "$count" ]; then
          typed="$key"
          choice=$((10#$typed))
          if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
            selected=$((choice - 1))
          else
            error_message="$invalid_message"
            typed=""
          fi
        fi
      fi
      ;;
    q | Q)
      printf '\n' >&2
      return 1
      ;;
    k | K)
      selected=$(((selected - 1 + count) % count))
      typed=""
      ;;
    j | J)
      selected=$(((selected + 1) % count))
      typed=""
      ;;
    *) ;;
    esac

    printf '\033[%dA' "$last_lines" >&2
    printf '\033[J' >&2
  done
}

worktree_prompt_select_global() {
  local count=${#MATCH_WORKTREE_NAMES[@]}
  if [ "$count" -eq 0 ]; then
    return 1
  fi

  if [ "$count" -eq 1 ]; then
    WORKTREE_SELECTION_INDEX=0
    return 0
  fi

  local -a option_lines=()
  local idx=0
  while [ "$idx" -lt "$count" ]; do
    local project_index="${MATCH_WORKTREE_PROJECTS[$idx]}"
    local project_name="${PROJECT_REGISTRY_DISPLAY_NAMES[$project_index]}"
    local worktree_name="${MATCH_WORKTREE_NAMES[$idx]}"
    local worktree_path="${MATCH_WORKTREE_PATHS[$idx]}"
    option_lines+=("$(msg select_worktree_option $((idx + 1)) "$worktree_name" "$project_name" "$worktree_path")")
    idx=$((idx + 1))
  done

  local prompt_base
  prompt_base="$(msg select_worktree_prompt)"
  local prompt_tty="$prompt_base"
  local nav_hint
  nav_hint="$(msg select_navigation_hint)"
  if [ -n "$nav_hint" ]; then
    prompt_tty="$prompt_tty $nav_hint"
  fi

  local invalid_message
  invalid_message="$(msg select_worktree_invalid "$count")"

  local selection_output=""
  local tty_rc=0
  if selection_output=$(tty_menu_select "$prompt_tty" "$invalid_message" "${option_lines[@]}"); then
    WORKTREE_SELECTION_INDEX="$selection_output"
    return 0
  else
    tty_rc=$?
    if [ "$tty_rc" -eq 1 ]; then
      return 1
    fi
    if [ "$tty_rc" -ne 2 ]; then
      return "$tty_rc"
    fi
  fi

  info "$prompt_base"

  idx=0
  while [ "$idx" -lt "$count" ]; do
    info "${option_lines[$idx]}"
    idx=$((idx + 1))
  done

  while true; do
    printf '%s ' "$(msg select_worktree_input "$count")" >&2
    local reply
    if ! IFS= read -r reply; then
      return 1
    fi
    if [ -z "$reply" ]; then
      info "$(msg aborted)"
      return 1
    fi
    if [[ "$reply" =~ ^[0-9]+$ ]]; then
      local choice=$((reply))
      if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        WORKTREE_SELECTION_INDEX=$((choice - 1))
        return 0
      fi
    fi
    info "$(msg select_worktree_invalid "$count")"
  done
}

collect_global_worktree_matches() {
  local target_name="${1:-}"
  worktree_match_reset

  project_registry_collect
  if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
    return 0
  fi

  if [ -z "$target_name" ]; then
    return 0
  fi

  local idx=0
  while [ "$idx" -lt "$PROJECT_REGISTRY_COUNT" ]; do
    local repo_path="${PROJECT_REGISTRY_PATHS[$idx]}"
    local prefix="${PROJECT_REGISTRY_DIR_PREFIXES[$idx]}"
    if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
      idx=$((idx + 1))
      continue
    fi

    local current_path=""
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
      worktree\ *)
        current_path="${line#worktree }"
        local base
        base=$(basename "$current_path")
        local candidate=""
        if [ -n "$prefix" ] && [[ "$base" == "$prefix"* ]]; then
          candidate="${base#"$prefix"}"
        elif [ "$base" = "$target_name" ]; then
          candidate="$base"
        fi

        if [ -n "$candidate" ] && [ "$candidate" = "$target_name" ]; then
          MATCH_WORKTREE_NAMES+=("$candidate")
          MATCH_WORKTREE_PATHS+=("$current_path")
          MATCH_WORKTREE_PROJECTS+=("$idx")
        fi
        ;;
      esac
    done < <(git_at_path "$repo_path" worktree list --porcelain 2> /dev/null || true)

    idx=$((idx + 1))
  done

  MATCH_WORKTREE_COUNT=${#MATCH_WORKTREE_NAMES[@]}
  return 0
}

project_worktrees_for_slug() {
  local slug="${1:-}"

  project_worktree_reset

  if [ -z "$slug" ]; then
    PROJECT_WORKTREE_STATUS='missing-slug'
    PROJECT_WORKTREE_LAST_ERROR='slug required'
    return 1
  fi

  PROJECT_WORKTREE_SLUG="$slug"

  local config_dir
  config_dir=$(project_config_dir_for_slug "$slug" 2> /dev/null || true)
  if [ -z "$config_dir" ] || [ ! -d "$config_dir" ]; then
    PROJECT_WORKTREE_STATUS='missing-config'
    PROJECT_WORKTREE_LAST_ERROR='project config missing'
    return 1
  fi

  PROJECT_WORKTREE_CONFIG_DIR="$config_dir"

  local config_file="$config_dir/$CONFIG_PROJECT_FILENAME"
  if [ ! -f "$config_file" ]; then
    PROJECT_WORKTREE_STATUS='missing-config'
    PROJECT_WORKTREE_LAST_ERROR='project config missing'
    return 1
  fi

  PROJECT_WORKTREE_CONFIG_FILE="$config_file"

  local repo_path
  repo_path=$(config_file_get_value "$config_file" "repo.path" 2> /dev/null || true)
  PROJECT_WORKTREE_REPO_PATH="$repo_path"
  if [ -z "$repo_path" ]; then
    PROJECT_WORKTREE_STATUS='repo-missing'
    PROJECT_WORKTREE_LAST_ERROR='repo.path not set'
    PROJECT_WORKTREE_REPO_EXISTS=0
    return 0
  fi

  if [ -d "$repo_path" ]; then
    PROJECT_WORKTREE_REPO_EXISTS=1
  else
    PROJECT_WORKTREE_STATUS='repo-missing'
    PROJECT_WORKTREE_LAST_ERROR='repository path missing'
    PROJECT_WORKTREE_REPO_EXISTS=0
    return 0
  fi

  local branch_prefix
  branch_prefix=$(config_file_get_value "$config_file" "add.branch-prefix" 2> /dev/null || true)
  if [ -z "$branch_prefix" ]; then
    branch_prefix="$CONFIG_DEFAULT_WORKTREE_ADD_BRANCH_PREFIX"
  fi

  local dir_prefix=""
  local repo_base
  repo_base=$(basename "$repo_path")
  if [ -n "$repo_base" ] && [ "$repo_base" != "." ]; then
    dir_prefix="$repo_base."
  fi

  PROJECT_WORKTREE_STATUS='ok'

  local list_output=""
  if ! list_output=$(git_at_path "$repo_path" worktree list --porcelain 2>&1); then
    PROJECT_WORKTREE_STATUS='git-error'
    PROJECT_WORKTREE_LAST_ERROR="$list_output"
    return 1
  fi

  local line="" entry_path="" entry_branch=""
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      if [ -n "$entry_path" ]; then
        project_worktree_maybe_add "$entry_path" "$entry_branch" "$repo_path" "$dir_prefix" "$branch_prefix"
      fi
      entry_path=""
      entry_branch=""
      continue
    fi

    case "$line" in
    worktree\ *)
      if [ -n "$entry_path" ]; then
        project_worktree_maybe_add "$entry_path" "$entry_branch" "$repo_path" "$dir_prefix" "$branch_prefix"
      fi
      entry_path="${line#worktree }"
      entry_branch=""
      ;;
    branch\ *)
      entry_branch="${line#branch }"
      entry_branch="${entry_branch#refs/heads/}"
      ;;
    esac
  done < <(printf '%s\n' "$list_output")

  if [ -n "$entry_path" ]; then
    project_worktree_maybe_add "$entry_path" "$entry_branch" "$repo_path" "$dir_prefix" "$branch_prefix"
  fi

  return 0
}

project_remove_worktree() {
  local path="${1:-}"
  local branch="${2:-}"

  PROJECT_REMOVE_LAST_ERROR=""

  local repo_path="$PROJECT_WORKTREE_REPO_PATH"
  if [ -z "$repo_path" ] || [ "$PROJECT_WORKTREE_REPO_EXISTS" -ne 1 ]; then
    PROJECT_REMOVE_LAST_ERROR='repository unavailable'
    return 1
  fi

  if [ -z "$path" ]; then
    PROJECT_REMOVE_LAST_ERROR='worktree path missing'
    return 1
  fi

  local removal_failure=0
  local removal_output=""

  if removal_output=$(git_at_path "$repo_path" worktree remove "$path" --force 2>&1); then
    :
  else
    removal_failure=1
    PROJECT_REMOVE_LAST_ERROR="$removal_output"
  fi

  if [ "$removal_failure" -eq 1 ] && [ ! -d "$path" ]; then
    git_at_path "$repo_path" worktree prune --expire now > /dev/null 2>&1 || true
    local verify_output
    verify_output=$(git_at_path "$repo_path" worktree list --porcelain 2>&1 || true)
    if ! printf '%s\n' "$verify_output" | grep -Fq "worktree $path"; then
      removal_failure=0
      PROJECT_REMOVE_LAST_ERROR=""
    fi
  fi

  if [ "$removal_failure" -eq 1 ]; then
    if [ -n "$PROJECT_REMOVE_LAST_ERROR" ]; then
      local first_line
      IFS=$'\n' read -r first_line _rest <<< "$PROJECT_REMOVE_LAST_ERROR"
      PROJECT_REMOVE_LAST_ERROR="$first_line"
    else
      PROJECT_REMOVE_LAST_ERROR='worktree remove failed'
    fi
    return 1
  fi

  if [ -n "$branch" ] && git_at_path "$repo_path" show-ref --verify --quiet "refs/heads/$branch"; then
    if git_at_path "$repo_path" branch -D "$branch" > /dev/null 2>&1; then
      info "$(msg removed_branch "$branch")"
    fi
  fi

  return 0
}

project_detach() {
  if [ $# -lt 1 ]; then
    return 1
  fi

  local slug="$1"
  local force="${2:-0}"

  if ! project_worktrees_for_slug "$slug"; then
    case "$PROJECT_WORKTREE_STATUS" in
    missing-config | missing-slug)
      info "$(msg detach_project_missing "$slug")"
      return 1
      ;;
    git-error)
      local err="$PROJECT_WORKTREE_LAST_ERROR"
      if [ -n "$err" ]; then
        info "$(msg git_command_failed "$PROJECT_WORKTREE_REPO_PATH")"
        info "$err"
      fi
      return 1
      ;;
    *)
      info "$(msg detach_project_missing "$slug")"
      return 1
      ;;
    esac
  fi

  if [ -z "$PROJECT_WORKTREE_CONFIG_DIR" ] || [ ! -d "$PROJECT_WORKTREE_CONFIG_DIR" ]; then
    PROJECT_WORKTREE_STATUS='missing-config'
    return 1
  fi

  if [ -z "$PROJECT_WORKTREE_CONFIG_FILE" ] || [ ! -f "$PROJECT_WORKTREE_CONFIG_FILE" ]; then
    PROJECT_WORKTREE_STATUS='missing-config'
    return 1
  fi

  if [ "$PROJECT_WORKTREE_STATUS" = "repo-missing" ]; then
    info "$(msg project_path_missing "$slug")"
  fi

  local removed_count=0
  local failure_count=0
  local skipped_count=0
  local aborted=0
  local current_removed=0
  local current_dir
  current_dir=$(pwd -P 2> /dev/null || pwd)
  local -a failure_paths=()
  local -a failure_reasons=()

  if [ "$PROJECT_WORKTREE_REPO_EXISTS" -eq 1 ] && [ "$PROJECT_WORKTREE_COUNT" -gt 0 ]; then
    local idx=0
    while [ "$idx" -lt "$PROJECT_WORKTREE_COUNT" ]; do
      local path="${PROJECT_WORKTREE_PATHS[$idx]}"
      local branch="${PROJECT_WORKTREE_BRANCHES[$idx]}"

      if [ "$force" -ne 1 ]; then
        printf '%s ' "$(msg detach_prompt_worktree "$path")" >&2
        local reply=""
        if ! IFS= read -r reply; then
          aborted=1
          skipped_count=$((PROJECT_WORKTREE_COUNT - idx))
          break
        fi
        if [ -n "$reply" ] && [[ ! "$reply" =~ ^[Yy]$ ]]; then
          aborted=1
          skipped_count=$((PROJECT_WORKTREE_COUNT - idx))
          break
        fi
      fi

      info "$(msg removing_worktree "$path")"
      if project_remove_worktree "$path" "$branch"; then
        removed_count=$((removed_count + 1))
        info "$(msg worktree_removed "$path")"
        if [ "$current_dir" = "$path" ]; then
          current_removed=1
        fi
      else
        failure_count=$((failure_count + 1))
        local reason="$PROJECT_REMOVE_LAST_ERROR"
        if [ -z "$reason" ]; then
          reason='unknown error'
        fi
        failure_paths+=("$path")
        failure_reasons+=("$reason")
        info "$(msg detach_remove_failed "$path" "$reason")"
      fi

      idx=$((idx + 1))
    done
  fi

  if [ "$aborted" -eq 1 ]; then
    info "$(msg detach_abort_user)"
    info "$(msg detach_summary_removed "$removed_count")"
    if [ "$failure_count" -gt 0 ]; then
      local failure_idx
      for failure_idx in "${!failure_paths[@]}"; do
        info "$(msg detach_summary_failed "${failure_paths[$failure_idx]}" "${failure_reasons[$failure_idx]}")"
      done
    fi
    if [ "$skipped_count" -gt 0 ]; then
      info "$(msg detach_summary_skipped "$skipped_count")"
    fi
    return 1
  fi

  if [ -d "$PROJECT_WORKTREE_CONFIG_DIR" ]; then
    if [ "$force" -ne 1 ]; then
      printf '%s ' "$(msg detach_prompt_project "$slug")" >&2
      local reply=""
      if ! IFS= read -r reply; then
        info "$(msg detach_abort_user)"
        return 1
      fi
      if [ -n "$reply" ] && [[ ! "$reply" =~ ^[Yy]$ ]]; then
        info "$(msg detach_abort_user)"
        info "$(msg detach_summary_removed "$removed_count")"
        if [ "$failure_count" -gt 0 ]; then
          local failure_idx
          for failure_idx in "${!failure_paths[@]}"; do
            info "$(msg detach_summary_failed "${failure_paths[$failure_idx]}" "${failure_reasons[$failure_idx]}")"
          done
        fi
        return 1
      fi
    fi

    if ! rm -rf "$PROJECT_WORKTREE_CONFIG_DIR"; then
      info "$(msg detach_remove_failed "$PROJECT_WORKTREE_CONFIG_DIR" "rm -rf failed")"
      return 1
    fi
  fi

  config_cache_reset
  project_context_reset
  project_context_detect_from_cwd || true
  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 0 ]; then
    config_context_apply_scope
  fi

  info "$(msg detach_summary_removed "$removed_count")"

  if [ "$failure_count" -gt 0 ]; then
    local failure_idx
    for failure_idx in "${!failure_paths[@]}"; do
      info "$(msg detach_summary_failed "${failure_paths[$failure_idx]}" "${failure_reasons[$failure_idx]}")"
    done
  fi

  info "$(msg detach_done "$slug")"

  if [ "$current_removed" -eq 1 ] && [ -n "$PROJECT_WORKTREE_REPO_PATH" ]; then
    info "$(msg clean_switch_back)"
    maybe_warn_shell_integration "$PROJECT_WORKTREE_REPO_PATH"
    printf '%s\n' "$PROJECT_WORKTREE_REPO_PATH"
  fi

  if [ "$failure_count" -gt 0 ]; then
    return 2
  fi

  return 0
}

project_registry_reset() {
  PROJECT_REGISTRY_SLUGS=()
  PROJECT_REGISTRY_PATHS=()
  PROJECT_REGISTRY_BRANCHES=()
  PROJECT_REGISTRY_BRANCH_PREFIXES=()
  PROJECT_REGISTRY_DIR_PREFIXES=()
  PROJECT_REGISTRY_FILES=()
  PROJECT_REGISTRY_DISPLAY_NAMES=()
  PROJECT_REGISTRY_HEADS=()
  PROJECT_REGISTRY_COUNT=0
}

project_registry_collect() {
  project_registry_reset

  [ -d "$CONFIG_PROJECTS_DIR" ] || return 0

  local slug_dir=""
  local slug=""
  local config_file=""
  local repo_path=""
  local branch=""

  for slug_dir in "$CONFIG_PROJECTS_DIR"/*; do
    [ -d "$slug_dir" ] || continue
    slug=$(basename "$slug_dir")
    config_file="$slug_dir/$CONFIG_PROJECT_FILENAME"
    [ -f "$config_file" ] || continue

    repo_path=$(config_file_get_value "$config_file" "repo.path" 2> /dev/null || true)
    branch=$(config_file_get_value "$config_file" "repo.branch" 2> /dev/null || true)
    local branch_prefix
    branch_prefix=$(config_file_get_value "$config_file" "add.branch-prefix" 2> /dev/null || true)

    local dir_prefix=""
    if [ -n "$repo_path" ]; then
      local base
      base=$(basename "$repo_path")
      if [ -n "$base" ] && [ "$base" != "." ]; then
        dir_prefix="$base."
      fi
    fi

    local display_branch="$branch"
    local head_short=""
    if [ -n "$repo_path" ] && [ -d "$repo_path" ]; then
      head_short=$(git_at_path "$repo_path" rev-parse --short HEAD 2> /dev/null || true)
      local branch_current
      branch_current=$(git_at_path "$repo_path" rev-parse --abbrev-ref HEAD 2> /dev/null || true)
      if [ -n "$branch_current" ] && [ "$branch_current" != "HEAD" ]; then
        display_branch="$branch_current"
      fi
    fi
    PROJECT_REGISTRY_SLUGS+=("$slug")
    PROJECT_REGISTRY_PATHS+=("$repo_path")
    PROJECT_REGISTRY_BRANCHES+=("$display_branch")
    PROJECT_REGISTRY_BRANCH_PREFIXES+=("$branch_prefix")
    PROJECT_REGISTRY_DIR_PREFIXES+=("$dir_prefix")
    PROJECT_REGISTRY_FILES+=("$config_file")
    local display_name=""
    if [ -n "$repo_path" ]; then
      display_name=$(basename "$repo_path")
      if [ -z "$display_name" ] || [ "$display_name" = "." ]; then
        display_name=""
      fi
    fi
    if [ -z "$display_name" ]; then
      display_name="$slug"
    fi
    PROJECT_REGISTRY_DISPLAY_NAMES+=("$display_name")
    PROJECT_REGISTRY_HEADS+=("$head_short")
  done

  PROJECT_REGISTRY_COUNT=${#PROJECT_REGISTRY_SLUGS[@]}
  return 0
}

project_prompt_select() {
  PROJECT_SELECTION_INDEX=-1
  project_registry_collect

  local count=$PROJECT_REGISTRY_COUNT
  if [ "$count" -eq 0 ]; then
    return 1
  fi

  if [ "$count" -eq 1 ]; then
    PROJECT_SELECTION_INDEX=0
    return 0
  fi

  local -a option_lines=()
  local idx=0
  while [ "$idx" -lt "$count" ]; do
    local display_path="${PROJECT_REGISTRY_PATHS[$idx]}"
    local display_name="${PROJECT_REGISTRY_DISPLAY_NAMES[$idx]}"
    local branch_meta="${PROJECT_REGISTRY_BRANCHES[$idx]}"
    local head_meta="${PROJECT_REGISTRY_HEADS[$idx]}"
    local meta=""
    if [ -n "$branch_meta" ]; then
      meta="$branch_meta"
    fi
    if [ -n "$head_meta" ]; then
      if [ -n "$meta" ]; then
        meta="$meta @ $head_meta"
      else
        meta="$head_meta"
      fi
    fi
    option_lines+=("$(msg select_project_option $((idx + 1)) "$display_name" "$meta" "$display_path")")
    idx=$((idx + 1))
  done

  local prompt_base
  prompt_base="$(msg select_project_prompt)"
  local prompt_tty="$prompt_base"
  local nav_hint
  nav_hint="$(msg select_navigation_hint)"
  if [ -n "$nav_hint" ]; then
    prompt_tty="$prompt_tty $nav_hint"
  fi

  local invalid_message
  invalid_message="$(msg select_project_invalid "$count")"

  local selection_output=""
  local tty_rc=0
  if selection_output=$(tty_menu_select "$prompt_tty" "$invalid_message" "${option_lines[@]}"); then
    PROJECT_SELECTION_INDEX="$selection_output"
    return 0
  else
    tty_rc=$?
    if [ "$tty_rc" -eq 1 ]; then
      return 1
    fi
    if [ "$tty_rc" -ne 2 ]; then
      return "$tty_rc"
    fi
  fi

  info "$prompt_base"

  idx=0
  while [ "$idx" -lt "$count" ]; do
    info "${option_lines[$idx]}"
    idx=$((idx + 1))
  done

  while true; do
    printf '%s ' "$(msg select_project_input "$count")" >&2
    local reply
    if ! IFS= read -r reply; then
      return 1
    fi
    if [ -z "$reply" ]; then
      info "$(msg aborted)"
      return 1
    fi
    if [[ "$reply" =~ ^[0-9]+$ ]]; then
      local choice=$((reply))
      if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        PROJECT_SELECTION_INDEX=$((choice - 1))
        return 0
      fi
    fi
    info "$(msg select_project_invalid "$count")"
  done
}

current_scope() {
  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 1 ]; then
    printf 'project\n'
    return 0
  fi

  if [ "$PROJECT_CONFIG_EXISTS" -eq 1 ]; then
    printf 'project\n'
    return 0
  fi

  if [ -n "$PROJECT_DETECTED_ROOT" ]; then
    printf 'unconfigured\n'
    return 0
  fi

  printf 'global\n'
  return 0
}

config_cache_load() {
  if [ "$CONFIG_CACHE_LOADED" = "1" ]; then
    return 0
  fi

  CONFIG_CACHE_KEYS=()
  CONFIG_CACHE_VALUES=()

  if [ ${#CONFIG_CACHE_SOURCES[@]} -eq 0 ]; then
    if [ -n "$CONFIG_FILE" ]; then
      CONFIG_CACHE_SOURCES=("$CONFIG_FILE")
    fi
  fi

  local source
  for source in "${CONFIG_CACHE_SOURCES[@]}"; do
    [ -n "$source" ] || continue

    if [ ! -f "$source" ]; then
      if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 1 ] && [ "$source" = "$CONFIG_FILE" ]; then
        die "$(msg config_file_missing "$CONFIG_FILE")"
      fi
      continue
    fi

    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
      '' | '#'*)
        continue
        ;;
      esac
      if [[ "$line" != *"="* ]]; then
        continue
      fi
      key="${line%%=*}"
      value="${line#*=}"
      [ -n "$key" ] || continue
      config_cache_put "$key" "$value"
    done < "$source"
  done

  CONFIG_CACHE_LOADED=1
  return 0
}

config_file_get_value() {
  if [ $# -ne 2 ]; then
    return 1
  fi

  local file="$1"
  local key="$2"

  [ -f "$file" ] || return 1

  local line current
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    '' | '#'*)
      continue
      ;;
    esac
    if [[ "$line" != *"="* ]]; then
      continue
    fi
    current="${line%%=*}"
    if [ "$current" = "$key" ]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  done < "$file"

  return 1
}

config_get() {
  local key="${1:-}"
  [ -n "$key" ] || return 1

  if ! config_cache_load; then
    return 1
  fi

  local idx
  for idx in "${!CONFIG_CACHE_KEYS[@]}"; do
    if [ "${CONFIG_CACHE_KEYS[$idx]}" = "$key" ]; then
      printf '%s\n' "${CONFIG_CACHE_VALUES[$idx]}"
      return 0
    fi
  done

  return 1
}

config_default_value() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  local key="$1"
  case "$key" in
  language)
    printf '%s\n' "$CONFIG_DEFAULT_LANGUAGE"
    ;;
  repo.path)
    printf '%s\n' "$CONFIG_DEFAULT_WORKING_REPO_PATH"
    ;;
  repo.branch)
    printf '\n'
    ;;
  add.branch-prefix)
    printf '%s\n' "$CONFIG_DEFAULT_WORKTREE_ADD_BRANCH_PREFIX"
    ;;
  add.copy-env.enabled)
    config_bool_to_string "$CONFIG_DEFAULT_COPY_ENV_ENABLED"
    ;;
  add.copy-env.files)
    json_array_from_list "${CONFIG_DEFAULT_COPY_ENV_FILES[@]}"
    ;;
  add.install-deps.enabled)
    config_bool_to_string "$CONFIG_DEFAULT_INSTALL_DEPS_ENABLED"
    ;;
  add.install-deps.command)
    printf '%s\n' "$CONFIG_DEFAULT_INSTALL_DEPS_COMMAND"
    ;;
  add.serve-dev.enabled)
    config_bool_to_string "$CONFIG_DEFAULT_SERVE_DEV_ENABLED"
    ;;
  add.serve-dev.command)
    printf '%s\n' "$CONFIG_DEFAULT_SERVE_DEV_COMMAND"
    ;;
  add.serve-dev.logging-path)
    printf '%s\n' "$CONFIG_DEFAULT_SERVE_DEV_LOGGING_PATH"
    ;;
  *)
    return 1
    ;;
  esac
}

config_get_or_default() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  local key="$1"
  local value

  if value=$(config_get "$key" 2> /dev/null); then
    printf '%s\n' "$value"
    return 0
  fi

  if value=$(config_default_value "$key" 2> /dev/null); then
    printf '%s\n' "$value"
    return 0
  fi

  return 1
}

config_set() {
  if [ $# -ne 2 ]; then
    die "$(msg config_set_requires)"
  fi

  local key="$1"
  local value="$2"

  if [ -z "$CONFIG_FILE" ]; then
    die "$(msg config_update_failed)"
  fi

  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/wt-config.XXXXXX") || die "$(msg config_update_failed)"

  local updated=0
  local line current_key
  if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" != *"="* ]]; then
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi

      current_key="${line%%=*}"
      if [ -z "$current_key" ]; then
        continue
      fi

      if [ "$current_key" = "$key" ]; then
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        updated=1
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$CONFIG_FILE"
  fi

  if [ "$updated" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi

  if config_ensure_parent_dir "$CONFIG_FILE" && mv "$tmp" "$CONFIG_FILE" 2> /dev/null; then
    chmod 600 "$CONFIG_FILE" 2> /dev/null || true
    config_cache_reset
    return 0
  fi

  rm -f "$tmp"
  die "$(msg config_update_failed)"
}

config_set_in_file() {
  if [ $# -ne 3 ]; then
    return 1
  fi

  local target_file="$1"
  local key="$2"
  local value="$3"

  local original_file="$CONFIG_FILE"
  local original_override="$CONFIG_FILE_IS_ENV_OVERRIDE"
  local -a original_sources=("${CONFIG_CACHE_SOURCES[@]}")

  CONFIG_FILE_IS_ENV_OVERRIDE=0
  CONFIG_FILE="$target_file"
  config_cache_sources_set "$target_file"

  config_set "$key" "$value"

  CONFIG_FILE="$original_file"
  CONFIG_FILE_IS_ENV_OVERRIDE="$original_override"
  config_cache_sources_set "${original_sources[@]}"
  return 0
}

config_unset() {
  if [ $# -ne 1 ]; then
    die "$(msg config_unset_requires)"
  fi

  local key="$1"

  if [ -z "$CONFIG_FILE" ]; then
    die "$(msg config_file_missing "$CONFIG_FILE")"
  fi

  local default_value=""
  local has_default=0
  if default_value=$(config_default_value "$key" 2> /dev/null); then
    has_default=1
  fi

  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/wt-config.XXXXXX") || die "$(msg config_update_failed)"

  local found=0
  local line current_key
  if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" != *"="* ]]; then
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi

      current_key="${line%%=*}"
      if [ -z "$current_key" ]; then
        continue
      fi

      if [ "$current_key" = "$key" ]; then
        found=1
        if [ "$has_default" -eq 1 ]; then
          printf '%s=%s\n' "$key" "$default_value" >> "$tmp"
        fi
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$CONFIG_FILE"
  fi

  if [ "$found" -eq 0 ]; then
    if [ "$has_default" -eq 1 ]; then
      printf '%s=%s\n' "$key" "$default_value" >> "$tmp"
    else
      rm -f "$tmp"
      die "$(msg config_key_not_set "$key")"
    fi
  fi

  if config_ensure_parent_dir "$CONFIG_FILE" && mv "$tmp" "$CONFIG_FILE" 2> /dev/null; then
    chmod 600 "$CONFIG_FILE" 2> /dev/null || true
    config_cache_reset
    return 0
  fi

  rm -f "$tmp"
  die "$(msg config_update_failed)"
}

json_escape_string() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "$input"
}

json_array_from_list() {
  if [ $# -eq 0 ]; then
    printf '[]\n'
    return
  fi

  local json="["
  local first=1
  local item escaped
  for item in "$@"; do
    escaped=$(json_escape_string "$item")
    if [ $first -eq 0 ]; then
      json+=", "
    fi
    json+="\"$escaped\""
    first=0
  done
  json+=']'
  printf '%s\n' "$json"
}

init_settings() {
  init_settings_defaults

  project_context_reset
  project_context_detect_from_cwd || true

  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 0 ]; then
    if [ "$PROJECT_CONFIG_EXISTS" -ne 1 ] && [ -n "$PROJECT_CONFIG_FILE" ] && [ -f "$PROJECT_CONFIG_FILE" ]; then
      PROJECT_CONFIG_EXISTS=1
    fi
  fi

  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 1 ]; then
    config_cache_sources_set "$CONFIG_FILE"
  else
    config_context_apply_scope
  fi

  init_settings_apply_from_sources
  init_language
}

init_settings_apply_from_sources() {
  if ! config_cache_load; then
    return 1
  fi

  local value
  local bool_val

  if value=$(config_get "language" 2> /dev/null); then
    [ -n "$value" ] && LANGUAGE="$value"
  fi

  if value=$(config_get "repo.path" 2> /dev/null); then
    if [ -n "$value" ]; then
      WORKING_REPO_PATH="$value"
      WORKING_REPO_PATH_CONFIGURED=1
    fi
  elif [ -n "$PROJECT_DETECTED_ROOT" ]; then
    WORKING_REPO_PATH="$PROJECT_DETECTED_ROOT"
  fi

  if [ -n "$WORKING_REPO_PATH" ]; then
    local prefix_base
    prefix_base=$(basename "$WORKING_REPO_PATH")
    if [ -n "$prefix_base" ] && [ "$prefix_base" != "." ]; then
      WORKTREE_NAME_PREFIX="$prefix_base."
    fi
  fi

  if value=$(config_get "repo.branch" 2> /dev/null); then
    WORKING_REPO_BRANCH="$value"
  fi

  if value=$(config_get "add.branch-prefix" 2> /dev/null); then
    [ -n "$value" ] && WORKTREE_BRANCH_PREFIX="$value"
  fi

  if value=$(config_get "add.serve-dev.logging-path" 2> /dev/null); then
    [ -n "$value" ] && SERVE_DEV_LOGGING_PATH="$value"
  fi

  if value=$(config_get "add.serve-dev.enabled" 2> /dev/null); then
    if bool_val=$(parse_bool "$value" 2> /dev/null); then
      SERVE_DEV_ENABLED="$bool_val"
    fi
  fi

  if value=$(config_get "add.serve-dev.command" 2> /dev/null); then
    SERVE_DEV_COMMAND="$value"
  fi

  if value=$(config_get "add.install-deps.enabled" 2> /dev/null); then
    if bool_val=$(parse_bool "$value" 2> /dev/null); then
      INSTALL_DEPS_ENABLED="$bool_val"
    fi
  fi

  if value=$(config_get "add.install-deps.command" 2> /dev/null); then
    INSTALL_DEPS_COMMAND="$value"
  fi

  if value=$(config_get "add.copy-env.enabled" 2> /dev/null); then
    if bool_val=$(parse_bool "$value" 2> /dev/null); then
      COPY_ENV_ENABLED="$bool_val"
    fi
  fi

  if value=$(config_get "add.copy-env.files" 2> /dev/null); then
    if [ -n "$value" ] && [[ "$value" =~ ^\[.*\]$ ]]; then
      local trimmed="${value#[}"
      trimmed="${trimmed%]}"
      local -a files=()
      if [ -n "$trimmed" ]; then
        local -a raw_items=()
        IFS=',' read -r -a raw_items <<< "$trimmed"
        local item=""
        for item in "${raw_items[@]}"; do
          item="${item#"${item%%[![:space:]]*}"}"
          item="${item%"${item##*[![:space:]]}"}"
          item="${item#\"}"
          item="${item%\"}"
          [ -n "$item" ] && files+=("$item")
        done
      fi
      if [ ${#files[@]} -gt 0 ]; then
        COPY_ENV_FILE_SELECTION=("${files[@]}")
      fi
    fi
  fi

  return 0
}

init_settings_defaults() {
  WORKING_REPO_PATH="$CONFIG_DEFAULT_WORKING_REPO_PATH"
  SERVE_DEV_LOGGING_PATH="$CONFIG_DEFAULT_SERVE_DEV_LOGGING_PATH"
  SERVE_DEV_ENABLED="$CONFIG_DEFAULT_SERVE_DEV_ENABLED"
  INSTALL_DEPS_ENABLED="$CONFIG_DEFAULT_INSTALL_DEPS_ENABLED"
  COPY_ENV_ENABLED="$CONFIG_DEFAULT_COPY_ENV_ENABLED"
  WORKTREE_BRANCH_PREFIX="$CONFIG_DEFAULT_WORKTREE_ADD_BRANCH_PREFIX"
  WORKING_REPO_BRANCH=""
  COPY_ENV_FILE_SELECTION=("${CONFIG_DEFAULT_COPY_ENV_FILES[@]}")
  INSTALL_DEPS_COMMAND="$CONFIG_DEFAULT_INSTALL_DEPS_COMMAND"
  SERVE_DEV_COMMAND="$CONFIG_DEFAULT_SERVE_DEV_COMMAND"
  WORKING_REPO_PATH_CONFIGURED=0
  LANGUAGE="$CONFIG_DEFAULT_LANGUAGE"

  WORKTREE_NAME_PREFIX="$(basename "$CONFIG_DEFAULT_WORKING_REPO_PATH")."

  init_language
}

config_bool_to_string() {
  if [ "$1" -eq 1 ]; then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

info() {
  printf '%s\n' "$*" >&2
}

die() {
  printf 'wt: %s\n' "$*" >&2
  exit 1
}

usage() {
  local project_dir_box_display="$WORKING_REPO_PATH"
  local dir_text_en
  local dir_text_zh
  local should_highlight=0

  if [ "$WORKING_REPO_PATH_CONFIGURED" -eq 1 ]; then
    dir_text_en="Project directory: ${project_dir_box_display}"
    dir_text_zh="${dir_text_en}"
    should_highlight=1
  else
    dir_text_en="Project directory: not set; run wt init inside your repo"
    dir_text_zh="${dir_text_en}"
  fi

  local banner_width_en=${#dir_text_en}
  local banner_width_zh=${#dir_text_zh}

  if [ "$banner_width_en" -lt 40 ]; then
    banner_width_en=40
  fi
  if [ "$banner_width_zh" -lt 40 ]; then
    banner_width_zh=40
  fi

  local fill_en fill_zh
  fill_en=$(printf '%*s' "$banner_width_en" '')
  fill_en=${fill_en// /─}
  fill_zh=$(printf '%*s' "$banner_width_zh" '')
  fill_zh=${fill_zh// /─}

  local dir_top_en dir_mid_en dir_bottom_en dir_top_zh dir_mid_zh dir_bottom_zh
  dir_top_en="${fill_en}╮"
  dir_mid_en=$(printf '%-*s│' "$banner_width_en" "$dir_text_en")
  dir_bottom_en="${fill_en}╯"

  dir_top_zh="${fill_zh}╮"
  dir_mid_zh=$(printf '%-*s│' "$banner_width_zh" "$dir_text_zh")
  dir_bottom_zh="${fill_zh}╯"

  local dir_mid_en_line="$dir_mid_en"
  local dir_mid_zh_line="$dir_mid_zh"
  if [ "$should_highlight" -eq 1 ] && [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
    dir_mid_en_line="$(format_cyan_bold_line "$dir_mid_en")"
    dir_mid_zh_line="$(format_cyan_bold_line "$dir_mid_zh")"
  fi

  local dir_mid_en_line="$dir_mid_en"
  local dir_mid_zh_line="$dir_mid_zh"
  if [ "$should_highlight" -eq 1 ] && [ -z "${NO_COLOR:-}" ] && { [ -t 1 ] || [ -t 2 ]; }; then
    local path_highlight
    path_highlight=$(format_cyan_bold_line "$project_dir_box_display")
    dir_mid_en_line=${dir_mid_en_line//Project directory: $project_dir_box_display/Project directory: $path_highlight}
    dir_mid_zh_line=${dir_mid_zh_line//Project directory: $project_dir_box_display/Project directory: $path_highlight}
  fi

  local dir_banner_en dir_banner_zh
  dir_banner_en=$(printf '%s\n%s\n%s' "$dir_top_en" "$dir_mid_en_line" "$dir_bottom_en")
  dir_banner_zh=$(printf '%s\n%s\n%s' "$dir_top_zh" "$dir_mid_zh_line" "$dir_bottom_zh")

  case "$LANGUAGE" in
  zh)
    cat << USAGE_ZH

用法:
  wt <command> [参数]        执行 wt 子命令
  wt <worktree-name>         直接跳转到对应 worktree

核心命令:
  init               将当前仓库设为 wt 的默认项目
  add <name>         创建新 worktree，复制环境文件、安装依赖并启动 dev server（可通过 wt config 调整）
  main               跳转到主 worktree
  merge <name>       将指定 worktree 的分支（feat/<name>）合并到主分支
  sync [all|name ...] 将主工作区的暂存改动同步到其他 worktree
  list               列出所有 worktree
  rm [name ...]      删除一个或多个 worktree（省略 name 时使用当前目录）
  clean              清理数字 worktree（匹配前缀 + 数字）
  config             查看或更新 worktree.sh 配置
  uninstall          卸载 wt 并清理 shell 集成
  reinstall          运行 uninstall.sh + install.sh 重新部署 wt
  help               显示此帮助

${dir_banner_zh}

USAGE_ZH
    ;;
  *)
    cat << USAGE_EN

Usage:
  wt <command> [args]        Run a wt subcommand
  wt <worktree-name>         Jump straight to a worktree

Core commands:
  init               Remember this repository as wt's default project
  add <name>         Create a new worktree, copy env files, install deps, start dev server (tunable via wt config)
  main               Jump to the main worktree
  merge <name>       Merge the feature branch (feat/<name>) back into the base branch
  sync [all|name ...] Sync staged changes from the main workspace into other worktrees
  list               List all worktrees
  rm [name ...]      Remove one or more worktrees (current directory if name omitted)
  clean              Remove numeric worktrees (matching prefix + digits)
  config             Inspect or update worktree.sh configuration
  uninstall          Uninstall wt and clean shell hooks
  reinstall          Run uninstall.sh + install.sh to refresh wt
  help               Show this guide

${dir_banner_en}

USAGE_EN
    ;;
  esac
}

usage_exit() {
  local status="${1:-0}"
  usage
  exit "$status"
}

PROJECT_DIR=""
PROJECT_DIR_ABS=""
PROJECT_PARENT=""

resolve_project() {
  command -v git > /dev/null 2>&1 || die "$(msg git_required)"

  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -ne 1 ] && [ "$PROJECT_CONFIG_EXISTS" -ne 1 ]; then
    die "$(msg project_dir_unset)"
  fi

  if [ -z "$WORKING_REPO_PATH" ]; then
    die "$(msg project_dir_unset)"
  fi

  PROJECT_DIR="$WORKING_REPO_PATH"

  if ! PROJECT_DIR_ABS=$(cd "$PROJECT_DIR" 2> /dev/null && pwd -P); then
    if [ -n "$PROJECT_DETECTED_ROOT" ]; then
      PROJECT_DIR_ABS="$PROJECT_DETECTED_ROOT"
      PROJECT_DIR="$PROJECT_DIR_ABS"
    else
      die "$(msg project_not_found "$PROJECT_DIR")"
    fi
  fi

  PROJECT_PARENT=$(dirname "$PROJECT_DIR_ABS")
}

worktree_path_for() {
  local name="$1"
  printf '%s/%s%s\n' "$PROJECT_PARENT" "$WORKTREE_NAME_PREFIX" "$name"
}

worktree_ref_exists() {
  local target="$1"
  local line

  while IFS= read -r line; do
    case "$line" in
    worktree\ *)
      local candidate="${line#worktree }"
      if [ "$candidate" = "$target" ]; then
        return 0
      fi
      ;;
    esac
  done < <(git_project worktree list --porcelain)

  return 1
}

branch_for() {
  local name="$1"
  printf '%s%s\n' "$WORKTREE_BRANCH_PREFIX" "$name"
}

detect_repo_default_branch() {
  local remote_head
  remote_head=$(git_project symbolic-ref --quiet --short refs/remotes/origin/HEAD 2> /dev/null || true)
  if [ -n "$remote_head" ]; then
    remote_head=${remote_head#origin/}
    if [ -n "$remote_head" ]; then
      printf '%s\n' "$remote_head"
      return 0
    fi
  fi

  local candidate
  for candidate in main master; do
    if git_project show-ref --verify --quiet "refs/heads/$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
  fi
}

validate_worktree_name() {
  local candidate="${1:-}"

  if [ -z "$candidate" ]; then
    return 1
  fi

  if [[ "$candidate" =~ [[:space:]] ]]; then
    return 1
  fi

  case "$candidate" in
  . | '..' | */* | *\\* | *~*)
    return 1
    ;;
  esac

  return 0
}

port_from_name() {
  local name="$1"
  local digits=""

  if [[ "$name" =~ ^([0-9]+)$ ]]; then
    digits="${BASH_REMATCH[1]}"
  elif [[ "$name" =~ ([0-9]+)$ ]]; then
    digits="${BASH_REMATCH[1]}"
  fi

  if [ -n "$digits" ]; then
    if [ "$digits" -ge 1024 ] && [ "$digits" -le 65535 ]; then
      printf '%s\n' "$digits"
      return 0
    fi
  fi

  printf ''
}

git_project() {
  git -C "$PROJECT_DIR_ABS" "$@"
}

git_at_path() {
  if [ $# -lt 2 ]; then
    return 1
  fi

  local repo_path="$1"
  shift
  git -C "$repo_path" "$@"
}

copy_env_file() {
  local file_name="$1"
  local target_dir="$2"
  if [ -f "$PROJECT_DIR_ABS/$file_name" ]; then
    cp "$PROJECT_DIR_ABS/$file_name" "$target_dir/"
    info "$(msg copy_env_file "$file_name")"
  fi
}

command_exists_for_line() {
  local line="$1"
  if [ -z "$line" ]; then
    return 1
  fi

  local -a tokens
  IFS=' ' read -r -a tokens <<< "$line"
  if [ ${#tokens[@]} -eq 0 ]; then
    return 1
  fi

  local token
  for token in "${tokens[@]}"; do
    if [[ "$token" == *=* ]]; then
      continue
    fi
    if command -v "$token" > /dev/null 2>&1; then
      return 0
    fi
    return 1
  done

  return 1
}

node_lockfile_present() {
  local worktree_path="${1:?worktree path is required}"
  if [ -f "$worktree_path/package-lock.json" ] || [ -f "$worktree_path/npm-shrinkwrap.json" ]; then
    return 0
  fi
  return 1
}

run_install_command() {
  local worktree_path="${1:?worktree path is required}"
  local command_line="${2:-}"

  if [ -z "$command_line" ]; then
    info "$(msg install_skipped_no_command)"
    return
  fi

  if ! command_exists_for_line "$command_line"; then
    info "$(msg command_not_found "$command_line")"
    return
  fi

  local complex_command=0
  case "$command_line" in
  *'&&'* | *'||'* | *';'* | *'|'*)
    complex_command=1
    ;;
  esac

  if [ "$complex_command" -eq 0 ]; then
    local -a tokens=()
    local token=""
    IFS=' ' read -r -a tokens <<< "$command_line"
    local -a filtered=()
    for token in "${tokens[@]}"; do
      if [[ "$token" == *=* ]]; then
        continue
      fi
      filtered+=("$token")
    done

    if [ ${#filtered[@]} -gt 0 ]; then
      local primary="${filtered[0]}"
      local subcommand=""
      if [ ${#filtered[@]} -ge 2 ]; then
        subcommand="${filtered[1]}"
      fi

      if [ "$primary" = "npm" ]; then
        case "$subcommand" in
        ci | install)
          if ! node_lockfile_present "$worktree_path"; then
            info "$(msg install_skipped_missing_lock "$command_line")"
            return
          fi
          ;;
        esac
      fi
    fi
  fi

  info "$(msg installing_dependencies "$command_line")"
  (
    cd "$worktree_path" || exit
    sh -c "$command_line" >&2
  )
}

command_slug_from_line() {
  local line="$1"
  if [ -z "$line" ]; then
    printf 'dev'
    return
  fi

  local slug
  slug=$(printf '%s' "$line" | tr "[:space:]/\\" '_')
  slug=${slug//[^A-Za-z0-9._-]/_}
  slug=${slug#_}
  slug=${slug%%_}
  if [ -z "$slug" ]; then
    slug='dev'
  fi
  slug=${slug:0:40}
  printf '%s' "$slug"
}

infer_install_command() {
  local worktree_path="${1:?worktree path is required}"

  if [ -f "$worktree_path/pnpm-lock.yaml" ]; then
    printf 'pnpm install --frozen-lockfile\n'
    return 0
  fi

  if [ -f "$worktree_path/yarn.lock" ]; then
    printf 'yarn install --frozen-lockfile\n'
    return 0
  fi

  if [ -f "$worktree_path/bun.lockb" ]; then
    printf 'bun install\n'
    return 0
  fi

  if [ -f "$worktree_path/package.json" ]; then
    if [ -f "$worktree_path/package-lock.json" ] || [ -f "$worktree_path/npm-shrinkwrap.json" ]; then
      printf 'npm ci\n'
      return 0
    fi
    printf 'npm install\n'
    return 0
  fi

  if [ -f "$worktree_path/poetry.lock" ]; then
    printf 'poetry install\n'
    return 0
  fi

  if [ -f "$worktree_path/Pipfile" ]; then
    printf 'pipenv install\n'
    return 0
  fi

  if [ -f "$worktree_path/requirements.txt" ]; then
    printf 'pip install -r requirements.txt\n'
    return 0
  fi

  if [ -f "$worktree_path/pyproject.toml" ]; then
    printf 'pip install -e .\n'
    return 0
  fi

  return 1
}

infer_serve_command() {
  local worktree_path="${1:?worktree path is required}"

  if [ -f "$worktree_path/pnpm-lock.yaml" ] && has_package_json_script "$worktree_path" "dev"; then
    printf 'pnpm dev\n'
    return 0
  fi

  if [ -f "$worktree_path/yarn.lock" ] && has_package_json_script "$worktree_path" "dev"; then
    printf 'yarn dev\n'
    return 0
  fi

  if [ -f "$worktree_path/bun.lockb" ] && has_package_json_script "$worktree_path" "dev"; then
    printf 'bun dev\n'
    return 0
  fi

  if [ -f "$worktree_path/package.json" ]; then
    if has_package_json_script "$worktree_path" "dev"; then
      printf 'npm run dev\n'
      return 0
    fi
    if has_package_json_script "$worktree_path" "start"; then
      printf 'npm run start\n'
      return 0
    fi
  fi

  if [ -f "$worktree_path/manage.py" ]; then
    printf 'python manage.py runserver\n'
    return 0
  fi

  if [ -f "$worktree_path/pyproject.toml" ] && [ -f "$worktree_path/app.py" ]; then
    printf 'python app.py\n'
    return 0
  fi

  if [ -f "$worktree_path/app.py" ]; then
    printf 'python app.py\n'
    return 0
  fi

  return 1
}

has_package_json_script() {
  local project_dir="${1:?project directory is required}"
  local script_name="${2:?script name is required}"
  local package_json="$project_dir/package.json"

  [ -f "$package_json" ] || return 1

  if command -v node > /dev/null 2>&1; then
    if node - "$package_json" "$script_name" > /dev/null 2>&1 << 'NODE'; then
const fs = require('fs');
const [pkgPath, scriptName] = process.argv.slice(2);
try {
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8')) || {};
  if (pkg.scripts && pkg.scripts[scriptName]) {
    process.exit(0);
  }
} catch (err) {}
process.exit(1);
NODE
      return 0
    fi
  fi

  local python=""
  for candidate in python3 python; do
    if command -v "$candidate" > /dev/null 2>&1; then
      python="$candidate"
      break
    fi
  done

  if [ -n "$python" ]; then
    if "$python" - "$package_json" "$script_name" > /dev/null 2>&1 << 'PY'; then
import json
import sys

pkg_path = sys.argv[1]
script_name = sys.argv[2]

try:
    with open(pkg_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    scripts = data.get('scripts') or {}
    if scripts.get(script_name):
        sys.exit(0)
except Exception:
    pass

sys.exit(1)
PY
      return 0
    fi
  fi

  return 1
}

start_dev_server() {
  local worktree_path="${1:?worktree path is required}"
  local command_line="${2:-}"
  local port="${3:-}"

  if [ -z "$command_line" ]; then
    info "$(msg dev_skipped_no_command)"
    return
  fi

  if ! command_exists_for_line "$command_line"; then
    info "$(msg command_not_found "$command_line")"
    return
  fi

  mkdir -p "$worktree_path/$SERVE_DEV_LOGGING_PATH"
  local slug
  slug=$(command_slug_from_line "$command_line")

  local log_file
  if [ -n "$port" ]; then
    log_file="$worktree_path/$SERVE_DEV_LOGGING_PATH/${slug}-${port}.log"
  else
    log_file="$worktree_path/$SERVE_DEV_LOGGING_PATH/${slug}.log"
  fi
  local pid_file="${log_file}.pid"

  info "$(msg dev_command "$command_line")"
  if [ -n "$port" ]; then
    info "$(msg start_dev_port "$port")"
  else
    info "$(msg start_dev_generic)"
  fi

  (
    cd "$worktree_path" || exit
    if [ -n "$port" ]; then
      nohup env PORT="$port" sh -c "$command_line" > "$log_file" 2>&1 &
    else
      nohup sh -c "$command_line" > "$log_file" 2>&1 &
    fi
    printf '%s\n' "$!" > "$pid_file"
  )

  local pid=""
  if [ -f "$pid_file" ]; then
    pid=$(cat "$pid_file" 2> /dev/null || true)
  fi

  sleep 1

  if [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; then
    if [ -n "$port" ]; then
      info "$(msg dev_started_port "$port")"
    else
      info "$(msg dev_started_default)"
    fi
  else
    local pid_display="${pid:-unknown}"
    info "$(msg dev_failed "$pid_display" "$log_file")"
  fi

  info "$(msg dev_log_hint "$log_file")"
}

maybe_warn_shell_integration() {
  local target_path="${1:-}"

  if [ -n "${WT_SHELL_WRAPPED:-}" ]; then
    return
  fi

  if [ ! -t 1 ]; then
    return
  fi

  if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
    return
  fi

  if [ "$AUTO_CD_HINT_SHOWN" = "1" ]; then
    return
  fi

  AUTO_CD_HINT_SHOWN=1

  local shell_name
  shell_name="${SHELL##*/}"
  if [ -z "$shell_name" ]; then
    shell_name="zsh"
  fi

  local hook_cmd="" rc_hint="reload your shell configuration" rc_file="" hook_present=0
  local hook_marker="# wt shell integration: auto-cd after wt add/path/main/remove/clean"

  case "$shell_name" in
  zsh)
    hook_cmd='wt shell-hook zsh >> ~/.zshrc'
    rc_hint='source ~/.zshrc'
    rc_file="$HOME/.zshrc"
    ;;
  bash)
    hook_cmd='wt shell-hook bash >> ~/.bashrc'
    rc_hint='source ~/.bashrc'
    rc_file="$HOME/.bashrc"
    ;;
  *)
    hook_cmd='wt shell-hook zsh >> ~/.zshrc'
    ;;
  esac

  if [ -n "$rc_file" ] && [ -f "$rc_file" ] && grep -Fq "$hook_marker" "$rc_file"; then
    hook_present=1
  fi

  if [ "$hook_present" -eq 1 ]; then
    info "$(msg auto_cd_pending "$rc_hint")"
    info "$(msg auto_cd_retry)"
    return
  fi

  info "$(msg auto_cd_disabled "$hook_cmd")"
  if [ "$rc_hint" = "reload your shell configuration" ]; then
    info "$(msg auto_cd_reload)"
  else
    info "$(msg auto_cd_execute "$rc_hint")"
  fi
}

format_bold_line() {
  local text="$1"

  if [ -z "$text" ]; then
    printf '%s' "$text"
    return
  fi

  if [ -n "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
    printf '%s' "$text"
    return
  fi

  local start="" end=""
  if command -v tput > /dev/null 2>&1; then
    local ansi_bold ansi_reset
    ansi_bold=$(tput bold 2> /dev/null || true)
    ansi_reset=$(tput sgr0 2> /dev/null || true)
    if [ -n "$ansi_bold$ansi_reset" ]; then
      start="$ansi_bold"
      end="$ansi_reset"
    fi
  fi

  if [ -z "$start" ]; then
    start=$'\033[1m'
    end=$'\033[0m'
  fi

  printf '%s%s%s' "$start" "$text" "$end"
}

format_cyan_bold_line() {
  local text="$1"

  if [ -z "$text" ]; then
    printf '%s' "$text"
    return
  fi

  if [ -n "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
    printf '%s' "$text"
    return
  fi

  local start="" end=""
  if command -v tput > /dev/null 2>&1; then
    local ansi_cyan ansi_bold ansi_reset
    ansi_cyan=$(tput setaf 6 2> /dev/null || true)
    ansi_bold=$(tput bold 2> /dev/null || true)
    ansi_reset=$(tput sgr0 2> /dev/null || true)
    if [ -n "$ansi_cyan$ansi_bold$ansi_reset" ]; then
      start="${ansi_bold}${ansi_cyan}"
      end="$ansi_reset"
    fi
  fi

  if [ -z "$start" ]; then
    start=$'\033[1;36m'
    end=$'\033[0m'
  fi

  printf '%s%s%s' "$start" "$text" "$end"
}

cmd_list() {
  [ $# -eq 0 ] || die "$(msg list_no_args)"

  local repo_path="$PROJECT_DIR_ABS"
  if [ -z "$repo_path" ]; then
    die "$(msg project_not_found "$WORKING_REPO_PATH")"
  fi

  local display_name
  display_name=$(basename "$repo_path")
  if [ -z "$display_name" ] || [ "$display_name" = "." ]; then
    if [ -n "$PROJECT_SLUG" ]; then
      display_name="$PROJECT_SLUG"
    else
      display_name="$repo_path"
    fi
  fi

  local branch
  branch=$(git_project rev-parse --abbrev-ref HEAD 2> /dev/null || true)
  if [ "$branch" = "HEAD" ]; then
    branch=""
  fi

  local head_short
  head_short=$(git_project rev-parse --short HEAD 2> /dev/null || true)

  local header_line
  header_line=$(msg list_global_project_header "$display_name" "$repo_path" "$branch" "$head_short")
  info "$(format_bold_line "$header_line")"

  if ! project_print_worktrees "$repo_path"; then
    info "$(msg git_command_failed "$repo_path")"
  fi
}

project_emit_worktree_entry() {
  local path="$1"
  local head="$2"
  local branch_raw="$3"
  local flags="$4"

  [ -n "$path" ] || return 0

  local branch_display="$branch_raw"
  if [[ "$branch_display" =~ ^refs/heads/ ]]; then
    branch_display="${branch_display#refs/heads/}"
  elif [[ "$branch_display" =~ ^refs/remotes/ ]]; then
    branch_display="${branch_display#refs/remotes/}"
  fi

  if [ -z "$branch_display" ]; then
    branch_display='-'
  fi

  local status=""
  if [[ " $flags " == *" detached "* ]]; then
    if [ "$branch_display" = '-' ]; then
      branch_display='(detached)'
    else
      status='[detached]'
    fi
  fi
  if [[ " $flags " == *" bare "* ]]; then
    if [ "$branch_display" = '-' ]; then
      branch_display='(bare)'
    else
      if [ -n "$status" ]; then
        status="$status [bare]"
      else
        status='[bare]'
      fi
    fi
  fi
  if [[ " $flags " == *" locked "* ]]; then
    if [ -n "$status" ]; then
      status="$status [locked]"
    else
      status='[locked]'
    fi
  fi
  if [[ " $flags " == *" prunable "* ]]; then
    if [ -n "$status" ]; then
      status="$status [prunable]"
    else
      status='[prunable]'
    fi
  fi

  local head_short='-------'
  if [ -n "$head" ]; then
    head_short="${head:0:7}"
  fi

  local entry_line
  if [ -n "$status" ]; then
    entry_line=$(msg list_global_worktree_entry "$branch_display" "$head_short" "$path" "$status")
  else
    entry_line=$(msg list_global_worktree_entry "$branch_display" "$head_short" "$path")
  fi

  if [ "$branch_display" = "main" ]; then
    info "$(format_cyan_bold_line "$entry_line")"
  else
    info "$entry_line"
  fi
}

project_print_worktrees() {
  local repo_path="$1"
  local path=""
  local head=""
  local branch=""
  local flags=""
  local rc=0

  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$line" ]; then
      project_emit_worktree_entry "$path" "$head" "$branch" "$flags"
      path=""
      head=""
      branch=""
      flags=""
      continue
    fi
    case "$line" in
    worktree\ *)
      path="${line#worktree }"
      ;;
    HEAD\ *)
      head="${line#HEAD }"
      ;;
    branch\ *)
      branch="${line#branch }"
      ;;
    bare)
      flags="$flags bare"
      ;;
    detached)
      flags="$flags detached"
      ;;
    locked*)
      flags="$flags locked"
      ;;
    prunable*)
      flags="$flags prunable"
      ;;
    esac
  done < <(git_at_path "$repo_path" worktree list --porcelain 2> /dev/null) || rc=$?

  if [ -n "$path" ] || [ -n "$head" ] || [ -n "$branch" ]; then
    project_emit_worktree_entry "$path" "$head" "$branch" "$flags"
  fi

  return $rc
}

cmd_list_global() {
  [ $# -eq 0 ] || die "$(msg list_no_args)"

  project_registry_collect
  if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
    die "$(msg no_projects_configured)"
  fi

  local idx=0
  while [ "$idx" -lt "$PROJECT_REGISTRY_COUNT" ]; do
    local slug="${PROJECT_REGISTRY_SLUGS[$idx]}"
    local repo_path="${PROJECT_REGISTRY_PATHS[$idx]}"
    local display_name="${PROJECT_REGISTRY_DISPLAY_NAMES[$idx]}"
    local branch="${PROJECT_REGISTRY_BRANCHES[$idx]}"
    local head_short="${PROJECT_REGISTRY_HEADS[$idx]}"
    if [ "$idx" -gt 0 ]; then
      info ''
    fi
    local header_line
    header_line=$(msg list_global_project_header "$display_name" "$repo_path" "$branch" "$head_short")
    info "$(format_bold_line "$header_line")"

    if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
      info "$(msg project_path_missing "$display_name")"
    else
      if ! project_print_worktrees "$repo_path"; then
        info "$(msg git_command_failed "$repo_path")"
      fi
    fi

    idx=$((idx + 1))
  done
}

cmd_main() {
  [ $# -eq 0 ] || die "$(msg main_no_args)"
  maybe_warn_shell_integration "$PROJECT_DIR_ABS"
  printf '%s\n' "$PROJECT_DIR_ABS"
}

cmd_main_global() {
  [ $# -eq 0 ] || die "$(msg main_no_args)"

  if ! project_prompt_select; then
    if [ "$PROJECT_REGISTRY_COUNT" -eq 0 ]; then
      die "$(msg no_projects_configured)"
    fi
    die "$(msg project_selection_cancelled)"
  fi

  local idx="$PROJECT_SELECTION_INDEX"
  if [ "$idx" -lt 0 ]; then
    die "$(msg project_selection_cancelled)"
  fi

  local target_path="${PROJECT_REGISTRY_PATHS[$idx]}"
  if [ -z "$target_path" ]; then
    die "$(msg project_path_missing "${PROJECT_REGISTRY_SLUGS[$idx]}")"
  fi

  maybe_warn_shell_integration "$target_path"
  printf '%s\n' "$target_path"
}

cmd_path() {
  if [ $# -ne 1 ]; then
    die "$(msg path_requires_name)"
  fi
  local name="$1"
  local target_path
  target_path=$(worktree_path_for "$name")
  if [ ! -d "$target_path" ]; then
    die "$(msg worktree_not_found "$name")"
  fi
  maybe_warn_shell_integration "$target_path"
  printf '%s\n' "$target_path"
}

cmd_path_global() {
  if [ $# -ne 1 ]; then
    die "$(msg path_requires_name)"
  fi

  local name="$1"

  collect_global_worktree_matches "$name"
  local project_count=$PROJECT_REGISTRY_COUNT
  if [ "$project_count" -eq 0 ]; then
    die "$(msg no_projects_configured)"
  fi

  local matches=${#MATCH_WORKTREE_NAMES[@]}
  if [ "$matches" -eq 0 ]; then
    die "$(msg worktree_not_found "$name")"
  fi

  if [ "$matches" -eq 1 ]; then
    WORKTREE_SELECTION_INDEX=0
  else
    if ! worktree_prompt_select_global; then
      die "$(msg project_selection_cancelled)"
    fi
  fi

  local selected="$WORKTREE_SELECTION_INDEX"
  if [ "$selected" -lt 0 ]; then
    die "$(msg project_selection_cancelled)"
  fi

  local target_path="${MATCH_WORKTREE_PATHS[$selected]}"
  maybe_warn_shell_integration "$target_path"
  printf '%s\n' "$target_path"
}

cmd_add() {
  local name="$1"
  shift || true

  [ -n "$name" ] || die "$(msg add_requires_name)"
  if ! validate_worktree_name "$name"; then
    die "$(msg invalid_worktree_name "$name")"
  fi

  local run_install="$INSTALL_DEPS_ENABLED"
  local run_dev="$SERVE_DEV_ENABLED"
  local copy_env="$COPY_ENV_ENABLED"
  local branch=""
  local numeric_name=""
  local port_candidate=""
  local effective_port=""
  local skip_dev=0
  local skip_dev_port=""
  local base_branch="$WORKING_REPO_BRANCH"

  if [[ "$name" =~ ^[0-9]+$ ]]; then
    numeric_name="$name"
    port_candidate="$name"
    if [ "$numeric_name" -ge 1 ] && [ "$numeric_name" -lt 1024 ]; then
      info "$(msg reserved_port "$numeric_name")"
    elif [ "$numeric_name" -gt 65535 ]; then
      info "$(msg port_out_of_range "$numeric_name")"
    fi
  fi

  if [ -z "$port_candidate" ] && [[ "$name" =~ ([0-9]+)$ ]]; then
    port_candidate="${BASH_REMATCH[1]}"
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help | help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "$(msg add_unknown_option "$1")"
      ;;
    *)
      die "$(msg unexpected_extra_argument "$1")"
      ;;
    esac
    shift || true
  done

  if [ $# -gt 0 ]; then
    die "$(msg unexpected_extra_argument "$1")"
  fi

  if [ "$run_dev" -eq 1 ]; then
    effective_port=$(port_from_name "$name")

    if [ -z "$effective_port" ]; then
      if [ -n "$port_candidate" ] && [ "$port_candidate" -lt 1024 ]; then
        skip_dev=1
        skip_dev_port="$port_candidate"
      elif [ -n "$port_candidate" ] && [ "$port_candidate" -gt 65535 ]; then
        info "$(msg fallback_default_port)"
      fi
    fi
  fi

  local worktree_path
  worktree_path=$(worktree_path_for "$name")

  if [ -e "$worktree_path" ]; then
    die "$(msg worktree_exists "$worktree_path")"
  fi

  if [ -z "$branch" ]; then
    branch=$(branch_for "$name")
  fi

  info "$(msg creating_worktree "$worktree_path" "$branch")"
  if [ -n "$base_branch" ]; then
    git_project worktree add -b "$branch" "$worktree_path" "$base_branch" >&2
  else
    git_project worktree add -b "$branch" "$worktree_path" >&2
  fi
  info "$(msg worktree_created)"

  if [ "$copy_env" -eq 1 ]; then
    if [ ${#COPY_ENV_FILE_SELECTION[@]} -gt 0 ]; then
      local env_file
      for env_file in "${COPY_ENV_FILE_SELECTION[@]}"; do
        [ -n "$env_file" ] || continue
        copy_env_file "$env_file" "$worktree_path"
      done
    fi
  fi

  local install_command="$INSTALL_DEPS_COMMAND"
  local serve_command="$SERVE_DEV_COMMAND"
  local install_detected=0
  local serve_detected=0

  if [ "$run_install" -eq 1 ] && [ -z "$install_command" ]; then
    if install_command=$(infer_install_command "$worktree_path"); then
      info "$(msg install_detected "$install_command")"
      install_detected=1
    fi
  fi

  if [ "$run_dev" -eq 1 ] && [ -z "$serve_command" ]; then
    if serve_command=$(infer_serve_command "$worktree_path"); then
      info "$(msg serve_detected "$serve_command")"
      serve_detected=1
    fi
  fi

  if [ "$install_detected" -eq 1 ]; then
    config_set "add.install-deps.command" "$install_command"
  fi

  if [ "$serve_detected" -eq 1 ]; then
    config_set "add.serve-dev.command" "$serve_command"
  fi

  if [ "$run_install" -eq 1 ]; then
    run_install_command "$worktree_path" "$install_command"
  fi

  if [ "$run_dev" -eq 1 ]; then
    if [ "$skip_dev" -eq 1 ]; then
      info "$(msg dev_skipped_reserved_port "$skip_dev_port")"
    else
      start_dev_server "$worktree_path" "$serve_command" "$effective_port"
    fi
  else
    info "$(msg dev_skipped_config)"
  fi

  info "$(msg worktree_ready "$worktree_path")"
  maybe_warn_shell_integration "$worktree_path"
  printf '%s\n' "$worktree_path"
}

config_print_effective() {
  if [ -f "$CONFIG_FILE" ]; then
    if [ -s "$CONFIG_FILE" ]; then
      cat "$CONFIG_FILE"
    else
      info "$(msg config_list_empty "$CONFIG_FILE")"
    fi
    return 0
  fi

  if [ "$CONFIG_FILE_IS_ENV_OVERRIDE" -eq 1 ]; then
    die "$(msg config_file_missing "$CONFIG_FILE")"
  fi

  info "$(msg config_list_empty "$CONFIG_FILE")"
  return 0
}

config_usage() {
  case "$LANGUAGE" in
  zh)
    cat << 'CONFIG_USAGE_ZH'
wt config - 查看或更新 worktree.sh 配置

子命令:
  wt config list                 显示生效配置（包含默认值）
  wt config get <key> [--stored] 默认输出生效配置项；使用 --stored 仅读取配置文件
  wt config set <key> <value>    将配置写入 ~/.worktree.sh
  wt config unset <key>          从 ~/.worktree.sh 移除配置

快捷方式:
  wt config <key>                等同于 get（生效值）
  wt config --stored <key>       等同于 get --stored
  wt config <key> <value>        等同于 set

支持的键:
  language                        CLI 显示语言（en|zh，默认 en）
  repo.path                       默认维护的仓库根目录（由 wt init 设置）
  repo.branch                     新 worktree 的默认分支（可选）
  add.branch-prefix               新 worktree 分支名前缀（默认 feat/）
  add.copy-env.enabled            是否在 wt add 时复制环境文件
  add.copy-env.files              被复制的环境文件列表（JSON 数组）
  add.install-deps.enabled        是否在 wt add 时安装依赖
  add.install-deps.command        安装依赖使用的命令（留空则自动推断）
  add.serve-dev.enabled           是否在 wt add 后启动开发服务
  add.serve-dev.command           启动开发服务的命令（留空则自动推断）
  add.serve-dev.logging-path      Dev 服务日志所在子目录（默认: tmp）

说明:
  配置以 ~/.worktree.sh/config.kv 为准，采用 key=value 文本格式，不再支持通过环境变量临时覆盖。
  布尔值接受 true/false/1/0/yes/no/on/off。
CONFIG_USAGE_ZH
    ;;
  *)
    cat << 'CONFIG_USAGE_EN'
wt config - Inspect or update worktree.sh configuration

Subcommands:
  wt config list                 Show effective configuration (includes defaults)
  wt config get <key> [--stored] Print effective value; add --stored to read the raw file only
  wt config set <key> <value>    Persist value in ~/.worktree.sh
  wt config unset <key>          Remove key from ~/.worktree.sh

Shortcuts:
  wt config <key>                Shortcut for effective get
  wt config --stored <key>       Shortcut for get --stored
  wt config <key> <value>        Shortcut for set

Supported keys:
  language                        CLI language (en or zh; default: en)
  repo.path                       Root directory of the tracked repository (set by wt init)
  repo.branch                     Default branch for new worktrees (optional)
  add.branch-prefix               Branch name prefix used for new worktrees (default: feat/)
  add.copy-env.enabled            Whether wt add copies environment files
  add.copy-env.files              Environment files to copy (JSON array)
  add.install-deps.enabled        Whether wt add installs dependencies
  add.install-deps.command        Command used to install dependencies (empty = auto-detect)
  add.serve-dev.enabled           Whether wt add starts the dev service
  add.serve-dev.command           Command used to start the dev service (empty = auto-detect)
  add.serve-dev.logging-path      Subdirectory for dev logs (default: tmp)

Notes:
  Runtime settings come solely from ~/.worktree.sh/config.kv (key=value text); environment overrides are ignored.
  Boolean values accept true/false/1/0/yes/no/on/off.
CONFIG_USAGE_EN
    ;;
  esac
}
