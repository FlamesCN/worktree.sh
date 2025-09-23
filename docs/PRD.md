# wt 命令功能总结

## 基本命令

### wt list — 列出所有 worktrees

- 底层执行 `git worktree list`，展示主仓库与全部挂载目录，名称遵循 `../franxx.store.<name>` 模式。
- 搭配 `wt shell-hook` 注入的包装函数，可在结果上直接选择并自动 `cd`。

### wt add <name> — 创建新 worktree

- 默认从 `feat/<name>` 分支切出；若配置了 `repo.branch` 则以该分支为基线。
- 目标目录固定为 `../franxx.store.<name>`，存在同名目录或分支会中止以保持幂等。
- 根据 `add.copy-env.*` 设置复制 `.env`、`.env.local` 等文件。
- 自动探测安装命令（pnpm/yarn/bun 优先，其次 `npm ci`）并在新目录执行；命令缺失时给出提示。
- 若名称含 1024-65535 数字，视作端口并启动推断出的 dev server（如 `npm run dev`），`PORT` 环境变量注入该值。
- Dev 日志写入 `./tmp/<命令 slug>-<port>.log`，并保存 `.pid` 方便排查；创建完毕回显目录以便 shell hook 自动进入。

### wt rm [name] — 删除 worktree

- 无参时读取当前目录，依据 `franxx.store.<name>` 反推名称并提示 `Y/n`（回车默认确认）。
- 指定 `name` 时无需确认，直接 `git worktree remove --force` 并清除 `feat/<name>` 分支。
- 一旦删除当前 worktree，会输出主仓库路径供 shell hook 自动跳回 main。

### wt clean — 清理所有数字命名的 worktrees

- 遍历 `git worktree list --porcelain`，匹配 `franxx.store.<数字>` 后批量移除并删除对应分支。
- 自定义命名（如 `hero`、`login`）不会受影响。
- 若当前 worktree 被清理，命令结束会输出主仓库路径，确保上下文回到 main。

### wt main — 切换到主分支目录

- 打印 `wt init` 记录的仓库根路径（通常为 `/Users/.../franxx.store`）。
- 配合 shell hook，命令结束后自动切回主仓库目录。

### wt <name> — 切换到指定 worktree

- 将 `<name>` 解析为 `../franxx.store.<name>`，校验目录存在后输出路径。
- 若目录缺失则报错提示，成功时 shell hook 会立即 `cd`。

## 扩展命令

### wt merge <name> — 合并 feat/<name> 回主分支

- 仅在当前分支等于配置的基线（默认主分支）且工作目录干净时执行。
- 校验目标 worktree 无未提交更改后，统计差异 commit；若为 0 会提示无需合并。
- 合并使用 `git merge --no-edit`，成功后提醒运行 `wt rm` 清理 worktree。

### wt path <name> — 输出 worktree 绝对路径

- 解析结果同 `wt <name>`，但不会触发自动切换；适合脚本或管道场景。

### wt init [branch <name>] — 记录默认仓库信息

- 必须在目标仓库根目录执行，写入 `~/.worktree.sh/config.kv` 的 `repo.path`。
- 可选 `branch <name>` 覆盖默认基线分支，否则读取当前分支。
- 禁止在 `$HOME` 直接初始化，以防误写配置。

### wt config [list|get|set|unset] — 管理 CLI 配置

- `wt config list` 展示默认值与已持久化值；`--stored` 仅显示文件内容。
- `wt config set add.copy-env.enabled false` 等命令可覆盖行为选项，布尔值接受 true/false/1/0。
- `wt config unset <key>` 恢复默认，支持的键包括 `repo.path`、`add.branch-prefix`、`add.install-deps.command` 等。

### wt shell-hook <zsh|bash> — 输出自动 cd 包装函数

- 将输出追加到对应 rc 文件（如 `wt shell-hook zsh >> ~/.zshrc`）即可在 `wt add`、`wt main`、`wt rm` 等命令后自动切换目录。
- Wrapper 会向真实可执行文件传入 `WT_SHELL_WRAPPED=1`，避免重复提示集成指引。

### wt update — 从官方仓库刷新脚本

- 依赖 `curl`，下载最新 `bin/wt` 与 `messages.sh` 到 `WT_INSTALL_PREFIX`（默认 `~/.local/bin`）。
- 若目标文件内容相同会提示“已是最新”，否则在安装后回显成功信息。

### wt uninstall [--shell <type>] [--prefix <dir>] — 卸载 wt

- 删除安装目录中的 `wt` 与 `messages.sh`，`--prefix` 可指定自定义位置。
- 自动检测 shell（可强制传入 `zsh|bash|none`）并移除 rc 中的 hook 片段。
- 将 `~/.worktree.sh` 目录或配置文件备份到带时间戳的 `.backup.*`，确保可回滚。

### wt help / wt --help — 查看命令速览

- 输出内置帮助与当前 `repo.path` 状态；未运行 `wt init` 时会提示先初始化。

### wt version / wt --version — 显示版本号

- 直接打印当前脚本头部的 `VERSION`（例如 `0.1.0`），便于排查升级问题。
