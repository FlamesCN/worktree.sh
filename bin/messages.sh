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
      printf 'wt init completed successfully.\n\nCaptured defaults:\n  repo.path   → \033[1m%s\033[0m\n' "$1"
      ;;
    init_set_branch)
      printf '  repo.branch → \033[1m%s\033[0m\n' "$1"
      ;;
    init_done)
      printf ''
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
    merge_requires_name)
      printf 'merge requires a worktree name (e.g. wt merge 123)'
      ;;
    merge_main_only)
      printf 'merge only runs on %s (current: %s); checkout the base branch first' "$1" "$2"
      ;;
    merge_base_dirty)
      printf 'main workspace has uncommitted changes; commit or stash before merging'
      ;;
    merge_branch_not_found)
      printf 'feature branch not found: %s' "$1"
      ;;
    merge_feat_dirty)
      printf 'worktree %s has uncommitted changes; commit or stash before merging' "$1"
      ;;
    merge_no_commits)
      printf 'no new commits on %s relative to %s; nothing to merge' "$1" "$2"
      ;;
    merge_start)
      printf '🔀 Merging %s into %s' "$1" "$2"
      ;;
    merge_conflict_abort)
      printf '⚠️ Merge conflict; merge manually or enlist an LLM to resolve/conflict-fix/port changes, then rerun'
      ;;
    merge_done)
      printf '✅ Merge complete: %s → %s' "$1" "$2"
      ;;
    merge_cleanup_hint)
      printf '🧹 Consider cleaning up the worktree with: wt rm %s' "$1"
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
    project_dir_unset)
      printf 'wt is not configured yet; run "wt init" inside your repository first'
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
    invalid_worktree_name)
      printf 'invalid worktree name: %s (no /, \\, ~, dot segments, or whitespace)' "$1"
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
    init_forbid_home)
      printf 'wt init cannot target your home directory (%s)' "$1"
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
    uninstall_auto_detected_shell)
      printf 'Auto-detected shell: %s' "$1"
      ;;
    uninstall_requires_shell_value)
      printf '--shell requires a value'
      ;;
    uninstall_requires_prefix_value)
      printf '--prefix requires a value'
      ;;
    uninstall_invalid_shell)
      printf 'Invalid shell type: %s (use zsh, bash, or none)' "$1"
      ;;
    uninstall_unknown_option)
      printf 'unknown option for uninstall: %s' "$1"
      ;;
    uninstall_no_positional)
      printf 'uninstall takes no positional arguments'
      ;;
    uninstall_removed_binary)
      printf 'Removed wt from %s' "$1"
      ;;
    uninstall_binary_missing)
      printf 'wt not found at %s (already removed?)' "$1"
      ;;
    uninstall_removed_messages)
      printf 'Removed wt messages from %s' "$1"
      ;;
    uninstall_shell_config_missing)
      printf 'Shell config file %s does not exist, skipping.' "$1"
      ;;
    uninstall_shell_hook_missing)
      printf 'No wt shell hook found in %s, skipping.' "$1"
      ;;
    uninstall_backup_created)
      printf 'Created backup: %s.backup.%s' "$1" "$2"
      ;;
    uninstall_shell_hook_removed)
      printf 'Removed wt shell hook from %s' "$1"
      ;;
    uninstall_unknown_shell_type)
      printf 'Warning: Unknown shell type %s, skipping shell cleanup' "$1"
      ;;
    uninstall_skip_shell_cleanup)
      printf 'Skipping shell configuration cleanup (use --shell zsh or --shell bash to clean)'
      ;;
    uninstall_complete)
      printf 'Uninstallation complete.'
      ;;
    uninstall_config_backup_created)
      printf 'Backed up wt config from %s to %s' "$1" "$2"
      ;;
    uninstall_worktrees_preserved)
      printf 'Note: Any existing worktrees were preserved'
      ;;
    update_unknown_option)
      printf 'unknown option for update: %s' "$1"
      ;;
    update_no_positional)
      printf 'update takes no positional arguments'
      ;;
    curl_required)
      printf 'curl is required'
      ;;
    temp_dir_failed)
      printf 'failed to allocate temp directory'
      ;;
    update_fetch)
      printf 'Downloading %s' "$1"
      ;;
    update_download_failed)
      printf 'failed to download %s' "$1"
      ;;
    update_create_prefix_failed)
      printf 'failed to prepare install directory %s' "$1"
      ;;
    update_binary_unchanged)
      printf 'wt already up to date at %s' "$1"
      ;;
    update_binary_installed)
      printf 'Updated wt at %s' "$1"
      ;;
    update_messages_unchanged)
      printf 'messages already up to date at %s' "$1"
      ;;
    update_messages_installed)
      printf 'Updated messages at %s' "$1"
      ;;
    update_install_failed)
      printf 'failed to write %s' "$1"
      ;;
    update_already_latest)
      printf 'You already have the latest wt release'
      ;;
    update_complete)
      printf '✅ Update complete. Restart your shell if wt was running in another session.'
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
      printf 'wt init 已完成。\n\n捕获的默认值：\n  repo.path   → \033[1m%s\033[0m\n' "$1"
      ;;
    init_set_branch)
      printf '  repo.branch → \033[1m%s\033[0m\n' "$1"
      ;;
    init_done)
      printf ''
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
    merge_requires_name)
      printf 'merge 需要指定 worktree 名称（例如 wt merge 123）'
      ;;
    merge_main_only)
      printf 'merge 仅支持在 %s 分支执行（当前：%s），请先切换到基线分支' "$1" "$2"
      ;;
    merge_base_dirty)
      printf '主仓存在未提交修改，合并前请提交或暂存'
      ;;
    merge_branch_not_found)
      printf '未找到特性分支：%s' "$1"
      ;;
    merge_feat_dirty)
      printf 'worktree %s 存在未提交修改，合并前请提交或暂存' "$1"
      ;;
    merge_no_commits)
      printf '%s 相对于 %s 没有新的提交，已跳过合并' "$1" "$2"
      ;;
    merge_start)
      printf '🔀 正在将 %s 合并到 %s' "$1" "$2"
      ;;
    merge_conflict_abort)
      printf '⚠️ 合并冲突，请手动合并后自行/使用LLM解决冲突/使用LLM移植变更。'
      ;;
    merge_done)
      printf '✅ 合并完成: %s → %s' "$1" "$2"
      ;;
    merge_cleanup_hint)
      printf '🧹 如需清理请运行：wt rm %s' "$1"
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
    project_dir_unset)
      printf 'wt 尚未初始化，请在仓库目录下运行 wt init'
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
    invalid_worktree_name)
      printf '非法的 worktree 名称：%s（禁止包含 /、\\、~、路径点段或空白）' "$1"
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
    init_forbid_home)
      printf '禁止在家目录运行 wt init（%s）' "$1"
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
    uninstall_auto_detected_shell)
      printf '自动检测到 shell: %s' "$1"
      ;;
    uninstall_requires_shell_value)
      printf '--shell 需要一个值'
      ;;
    uninstall_requires_prefix_value)
      printf '--prefix 需要一个值'
      ;;
    uninstall_invalid_shell)
      printf '无效的 shell 类型: %s（可选 zsh、bash 或 none）' "$1"
      ;;
    uninstall_unknown_option)
      printf 'uninstall 未知选项: %s' "$1"
      ;;
    uninstall_no_positional)
      printf 'uninstall 不接受额外位置参数'
      ;;
    uninstall_removed_binary)
      printf '已从 %s 删除 wt' "$1"
      ;;
    uninstall_binary_missing)
      printf '在 %s 未找到 wt（可能已删除）' "$1"
      ;;
    uninstall_removed_messages)
      printf '已从 %s 删除 wt 消息文件' "$1"
      ;;
    uninstall_shell_config_missing)
      printf '未找到 shell 配置文件 %s，跳过。' "$1"
      ;;
    uninstall_shell_hook_missing)
      printf '未在 %s 找到 wt shell hook，跳过。' "$1"
      ;;
    uninstall_backup_created)
      printf '已创建备份: %s.backup.%s' "$1" "$2"
      ;;
    uninstall_shell_hook_removed)
      printf '已从 %s 移除 wt shell hook' "$1"
      ;;
    uninstall_unknown_shell_type)
      printf '警告: 未知 shell 类型 %s，跳过 shell 清理' "$1"
      ;;
    uninstall_skip_shell_cleanup)
      printf '跳过 shell 配置清理（使用 --shell zsh 或 --shell bash 可执行清理）'
      ;;
    uninstall_complete)
      printf '卸载完成。'
      ;;
    uninstall_config_backup_created)
      printf '已将 wt 配置从 %s 备份到 %s' "$1" "$2"
      ;;
    uninstall_worktrees_preserved)
      printf '注意: 已创建的 worktree 不会删除'
      ;;
    update_unknown_option)
      printf 'update 未知选项: %s' "$1"
      ;;
    update_no_positional)
      printf 'update 不接受位置参数'
      ;;
    curl_required)
      printf '需要安装 curl'
      ;;
    temp_dir_failed)
      printf '无法创建临时目录'
      ;;
    update_fetch)
      printf '正在下载 %s' "$1"
      ;;
    update_download_failed)
      printf '下载失败: %s' "$1"
      ;;
    update_create_prefix_failed)
      printf '无法准备安装目录 %s' "$1"
      ;;
    update_binary_unchanged)
      printf 'wt 在 %s 已是最新版本' "$1"
      ;;
    update_binary_installed)
      printf '已更新 wt 到 %s' "$1"
      ;;
    update_messages_unchanged)
      printf 'messages 在 %s 已是最新版本' "$1"
      ;;
    update_messages_installed)
      printf '已更新 messages 到 %s' "$1"
      ;;
    update_install_failed)
      printf '写入 %s 失败' "$1"
      ;;
    update_already_latest)
      printf '当前 wt 已是最新版本'
      ;;
    update_complete)
      printf '✅ 更新完成。如在其它终端运行 wt，请重启终端。'
      ;;
    *)
      printf '%s' "$key"
      ;;
  esac
}
