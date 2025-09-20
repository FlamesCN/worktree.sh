# shellcheck shell=bash

msg_en() {
  local key="${1:-}"
  shift || true
  case "$key" in
    copy_env_file)
      printf '📄 Copy %s' "$1"
      ;;
    command_not_found)
      printf '⚠️  Command not available: %s; skipping' "$1"
      ;;
    start_dev_port)
      printf '🚀 Starting dev command (port %s)' "$1"
      ;;
    start_dev_default)
      printf '🚀 Starting dev command'
      ;;
    start_dev_generic)
      printf '🚀 Starting dev command'
      ;;
    dev_started_port)
      printf '✅ Dev command running on port %s' "$1"
      ;;
    dev_started_default)
      printf '✅ Dev command running'
      ;;
    dev_failed)
      printf '⚠️ Dev command may not have started correctly (PID: %s); check %s' "$1" "$2"
      ;;
    dev_log_hint)
      printf '📝 Dev command log: tail -f %s' "$1"
      ;;
    install_skipped_no_command)
      printf '⚙️  Dependencies skipped (no command configured)'
      ;;
    install_detected)
      printf '🔍 Auto-detected install command: %s' "$1"
      ;;
    serve_detected)
      printf '🔍 Auto-detected dev command: %s' "$1"
      ;;
    dev_command)
      printf '🚀 Dev command: %s' "$1"
      ;;
    dev_skipped_no_command)
      printf '⚙️  Dev command skipped (no command configured)'
      ;;
    auto_cd_pending)
      printf '💡 wt auto-cd appears inactive. Try running: %s' "$1"
      ;;
    auto_cd_retry)
      printf '   If that command fails, reopen your terminal.'
      ;;
    auto_cd_disabled)
      printf '💡 wt auto-cd is not enabled. To jump automatically, run: %s' "$1"
      ;;
    auto_cd_reload)
      printf '   Then reload your shell (e.g. open a new terminal).'
      ;;
    auto_cd_execute)
      printf '   Then run: %s (or reopen the terminal).' "$1"
      ;;
    reserved_port)
      printf '⚠️  %s is a reserved port (1-1023); the dev command will not use it.' "$1"
      ;;
    port_out_of_range)
      printf '⚠️  %s is outside the valid port range (65535); falling back to default port.' "$1"
      ;;
    fallback_default_port)
      printf '⚠️  Using default port 3000 for the dev command.'
      ;;
    creating_worktree)
      printf '🔧 Creating worktree: %s (branch %s)' "$1" "$2"
      ;;
    worktree_created)
      printf '✅ Worktree created'
      ;;
    installing_dependencies)
      printf '📦 Installing dependencies (%s)' "$1"
      ;;
    dev_skipped_config)
      printf '⚙️  Dev command skipped per configuration'
      ;;
    worktree_ready)
      printf '✅ Worktree ready: %s' "$1"
      ;;
    init_set_project)
      printf '✅ Set workingRepo.path = %s' "$1"
      ;;
    init_set_branch)
      printf '✅ Set workingRepo.branch = %s' "$1"
      ;;
    init_done)
      printf '🎉 wt init complete; future commands will use these defaults'
      ;;
    aborted)
      printf 'Aborted'
      ;;
    removing_worktree)
      printf '🗑️  Removing worktree: %s' "$1"
      ;;
    removed_branch)
      printf '🗂️  Deleted branch %s' "$1"
      ;;
    worktree_removed)
      printf '✅ Removed worktree %s' "$1"
      ;;
    current_worktree_removed)
      printf '📁 Current worktree removed; switching back to the main directory'
      ;;
    cleaning_worktree)
      printf '🧹 Cleaning worktree: %s' "$1"
      ;;
    cleaned_count)
      printf '✅ Cleaned %s worktree(s)' "$1"
      ;;
    cleaned_none)
      printf '✅ No numeric worktrees to clean'
      ;;
    clean_switch_back)
      printf '📁 Current worktree was cleaned; switching back to the main directory'
      ;;
    remove_confirm_prompt)
      printf 'Remove worktree %s? [Y/n]' "$1"
      ;;
    config_set_requires)
      printf 'config set requires <key> <value>'
      ;;
    temp_file_failed)
      printf 'failed to allocate temp file'
      ;;
    config_unset_requires)
      printf 'config unset requires <key>'
      ;;
    config_file_missing)
      printf 'config file not found: %s' "$1"
      ;;
    config_key_not_set)
      printf 'config key not set: %s' "$1"
      ;;
    config_update_failed)
      printf 'failed to update config'
      ;;
    git_required)
      printf 'git is required'
      ;;
    project_not_found)
      printf 'project directory not found: %s' "$1"
      ;;
    list_no_args)
      printf 'list takes no arguments'
      ;;
    main_no_args)
      printf 'main takes no arguments'
      ;;
    path_requires_name)
      printf 'path requires exactly one worktree name'
      ;;
    worktree_not_found)
      printf 'worktree not found: %s' "$1"
      ;;
    add_requires_name)
      printf 'add requires a worktree name'
      ;;
    add_unknown_option)
      printf 'unknown option for add: %s' "$1"
      ;;
    unexpected_extra_argument)
      printf 'unexpected extra argument: %s' "$1"
      ;;
    port_requires_numeric)
      printf 'port requires a numeric value between 1024 and 65535'
      ;;
    worktree_exists)
      printf 'worktree path already exists: %s' "$1"
      ;;
    config_list_no_args)
      printf 'config list takes no additional arguments'
      ;;
    config_get_requires_key)
      printf 'config get requires a key'
      ;;
    config_get_requires_exactly_one)
      printf 'config get requires exactly one key'
      ;;
    config_key_not_found)
      printf 'config key not found: %s' "$1"
      ;;
    config_unset_requires_key)
      printf 'config unset requires a key'
      ;;
    config_unset_requires_exactly_one)
      printf 'config unset requires exactly one key'
      ;;
    config_unknown_option)
      printf 'unknown config option: %s' "$1"
      ;;
    config_expect_key_or_value)
      printf 'config expects <key> or <key> <value>'
      ;;
    shell_hook_requires_shell)
      printf 'shell-hook requires a shell (bash or zsh)'
      ;;
    shell_hook_unsupported_shell)
      printf 'unsupported shell for shell-hook: %s (supported: bash, zsh)' "$1"
      ;;
    branch_requires_value)
      printf 'branch requires a value'
      ;;
    init_unknown_option)
      printf 'unknown option for init: %s' "$1"
      ;;
    init_no_positional)
      printf 'init takes no positional arguments'
      ;;
    init_run_inside_git)
      printf 'run wt init inside a git repository'
      ;;
    remove_unknown_option)
      printf 'unknown option for remove: %s' "$1"
      ;;
    remove_accepts_at_most_one)
      printf 'remove accepts at most one worktree name'
      ;;
    cannot_remove_main)
      printf 'cannot remove the main worktree'
      ;;
    specify_worktree_or_inside)
      printf 'specify a worktree name or run from inside a worktree'
      ;;
    remove_failed)
      printf 'failed to remove worktree'
      ;;
    clean_no_args)
      printf 'clean takes no arguments'
      ;;
    invalid_language)
      printf 'unsupported language: %s (supported: en, zh)' "$1"
      ;;
    *)
      printf '%s' "$key"
      ;;
  esac
}

msg_zh() {
  local key="${1:-}"
  shift || true
  case "$key" in
    copy_env_file)
      printf '📄 复制 %s' "$1"
      ;;
    command_not_found)
      printf '⚠️  未找到命令：%s，已跳过' "$1"
      ;;
    start_dev_port)
      printf '🚀 正在启动开发命令（端口 %s）' "$1"
      ;;
    start_dev_default)
      printf '🚀 正在启动开发命令'
      ;;
    start_dev_generic)
      printf '🚀 正在启动开发命令'
      ;;
    dev_started_port)
      printf '✅ 开发命令已在端口 %s 运行' "$1"
      ;;
    dev_started_default)
      printf '✅ 开发命令已启动'
      ;;
    dev_failed)
      printf '⚠️ 开发命令进程可能未正确启动 (PID: %s)，请检查 %s' "$1" "$2"
      ;;
    dev_log_hint)
      printf '📝 开发命令日志：tail -f %s' "$1"
      ;;
    install_skipped_no_command)
      printf '⚙️  未配置安装命令，跳过依赖安装'
      ;;
    install_detected)
      printf '🔍 自动检测到安装命令：%s' "$1"
      ;;
    serve_detected)
      printf '🔍 自动检测到开发命令：%s' "$1"
      ;;
    dev_command)
      printf '🚀 开发命令：%s' "$1"
      ;;
    dev_skipped_no_command)
      printf '⚙️  未配置开发命令，已跳过'
      ;;
    auto_cd_pending)
      printf '💡 检测到 wt 自动切换目录尚未生效。尝试运行：%s' "$1"
      ;;
    auto_cd_retry)
      printf '   如果命令无效，请重新打开一个终端。'
      ;;
    auto_cd_disabled)
      printf '💡 检测到 wt 自动切换目录未启用。若希望直接跳转，可运行：%s' "$1"
      ;;
    auto_cd_reload)
      printf '   然后重新加载当前 shell（例如重新打开一个终端）。'
      ;;
    auto_cd_execute)
      printf '   然后执行：%s（或重新打开终端）。' "$1"
      ;;
    reserved_port)
      printf '⚠️  %s 是保留端口 (1-1023)，不会用于开发命令' "$1"
      ;;
    port_out_of_range)
      printf '⚠️  %s 超出有效端口范围 (65535)，将使用默认端口' "$1"
      ;;
    fallback_default_port)
      printf '⚠️  将使用默认端口 3000 启动开发命令'
      ;;
    creating_worktree)
      printf '🔧 创建 worktree: %s (分支 %s)' "$1" "$2"
      ;;
    worktree_created)
      printf '✅ worktree 创建完成'
      ;;
    installing_dependencies)
      printf '📦 安装依赖 (%s)' "$1"
      ;;
    dev_skipped_config)
      printf '⚙️  根据配置已跳过开发命令'
      ;;
    worktree_ready)
      printf '✅ 新 worktree 就绪: %s' "$1"
      ;;
    init_set_project)
      printf '✅ 已设置 workingRepo.path = %s' "$1"
      ;;
    init_set_branch)
      printf '✅ 已设置 workingRepo.branch = %s' "$1"
      ;;
    init_done)
      printf '🎉 wt init 完成，后续命令将默认使用以上配置'
      ;;
    aborted)
      printf '已取消'
      ;;
    removing_worktree)
      printf '🗑️  删除 worktree: %s' "$1"
      ;;
    removed_branch)
      printf '🗂️  已删除分支 %s' "$1"
      ;;
    worktree_removed)
      printf '✅ 已移除 worktree %s' "$1"
      ;;
    current_worktree_removed)
      printf '📁 当前 worktree 已移除，切换回主目录'
      ;;
    cleaning_worktree)
      printf '🧹 清理 worktree: %s' "$1"
      ;;
    cleaned_count)
      printf '✅ 已清理 %s 个 worktree' "$1"
      ;;
    cleaned_none)
      printf '✅ 没有符合条件的数字 worktree'
      ;;
    clean_switch_back)
      printf '📁 当前 worktree 已清理，切换回主目录'
      ;;
    remove_confirm_prompt)
      printf '删除 worktree %s？[Y/n]' "$1"
      ;;
    config_set_requires)
      printf 'config set 需要 <key> <value>'
      ;;
    temp_file_failed)
      printf '无法创建临时文件'
      ;;
    config_unset_requires)
      printf 'config unset 需要 <key>'
      ;;
    config_file_missing)
      printf '未找到配置文件: %s' "$1"
      ;;
    config_key_not_set)
      printf '配置项未设置: %s' "$1"
      ;;
    config_update_failed)
      printf '更新配置失败'
      ;;
    git_required)
      printf '需要安装 git'
      ;;
    project_not_found)
      printf '未找到项目目录: %s' "$1"
      ;;
    list_no_args)
      printf 'list 不接受参数'
      ;;
    main_no_args)
      printf 'main 不接受参数'
      ;;
    path_requires_name)
      printf 'path 需要指定 worktree 名称'
      ;;
    worktree_not_found)
      printf '未找到 worktree: %s' "$1"
      ;;
    add_requires_name)
      printf 'add 需要指定 worktree 名称'
      ;;
    add_unknown_option)
      printf 'add 的未知选项: %s' "$1"
      ;;
    unexpected_extra_argument)
      printf '出现未预期的额外参数: %s' "$1"
      ;;
    port_requires_numeric)
      printf 'port 需要 1024-65535 之间的数值'
      ;;
    worktree_exists)
      printf 'worktree 路径已存在: %s' "$1"
      ;;
    config_list_no_args)
      printf 'config list 不接受额外参数'
      ;;
    config_get_requires_key)
      printf 'config get 需要提供 key'
      ;;
    config_get_requires_exactly_one)
      printf 'config get 需要且仅需要一个 key'
      ;;
    config_key_not_found)
      printf '未找到配置项: %s' "$1"
      ;;
    config_unset_requires_key)
      printf 'config unset 需要提供 key'
      ;;
    config_unset_requires_exactly_one)
      printf 'config unset 需要且仅需要一个 key'
      ;;
    config_unknown_option)
      printf '未知的 config 选项: %s' "$1"
      ;;
    config_expect_key_or_value)
      printf 'config 需要 <key> 或 <key> <value>'
      ;;
    shell_hook_requires_shell)
      printf 'shell-hook 需要指定 shell（bash 或 zsh）'
      ;;
    shell_hook_unsupported_shell)
      printf 'shell-hook 不支持的 shell: %s（仅支持 bash、zsh）' "$1"
      ;;
    branch_requires_value)
      printf 'branch 需要指定值'
      ;;
    init_unknown_option)
      printf 'init 的未知选项: %s' "$1"
      ;;
    init_no_positional)
      printf 'init 不接受位置参数'
      ;;
    init_run_inside_git)
      printf '请在 git 仓库中运行 wt init'
      ;;
    remove_unknown_option)
      printf 'remove 的未知选项: %s' "$1"
      ;;
    remove_accepts_at_most_one)
      printf 'remove 最多只接受一个 worktree 名称'
      ;;
    cannot_remove_main)
      printf '不能移除主 worktree'
      ;;
    specify_worktree_or_inside)
      printf '指定 worktree 名称或在 worktree 目录中运行'
      ;;
    remove_failed)
      printf '移除 worktree 失败'
      ;;
    clean_no_args)
      printf 'clean 不接受参数'
      ;;
    invalid_language)
      printf '不支持的语言: %s（支持 en、zh）' "$1"
      ;;
    *)
      printf '%s' "$key"
      ;;
  esac
}
