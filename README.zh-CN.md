# worktree.sh

随着 Claude Code 的智力恢复以及 Codex 中 gpt5 high 的高智商，我越来越倾向于使用 git worktree 来并行开发。但是创建分支、建立 worktree、复制环境变量、安装依赖、启动服务这种重复性工作，增加了使用 worktree 的难度。

我也尝试过 claude code command 或者利用文件来协同多个 claude code 和 codex 通信，但目前这两个 agent 和文件系统交互必然慢，所以本项目应运而生。

如果你也想尝试并行开发，可以试试本项目。

## 完整使用流程

```bash
# 1. 安装完成后，进入你的项目仓库
cd ~/path/to/your/project

# 2. 初始化 wt 配置（记录当前仓库为默认项目）
wt init

# 3. 创建新的 worktree（自动完成以下步骤）
wt add 3000
# - 在 ../project.3000 创建新 worktree
# - 创建并切换到 feat/3000 分支
# - 复制 .env.local 和 .env 文件
# - 运行 npm ci 安装依赖
# - 启动 npm run dev（端口 3000——来自数字名称或末尾数字，例如 grid3000 ⇒ 3000）
# - 自动切换到新目录

# 4. 在不同 worktree 间切换
wt 3000        # 切换到 3000 worktree
wt main        # 回到主仓库

# 5. 清理不再需要的 worktree
wt rm          # 删除当前 worktree
wt rm 3000     # 删除指定 worktree
wt clean       # 批量清理所有数字命名的 worktree
```

## 功能对照表

运行 `wt help` 可快速查看全部命令：

```text
$ wt help
wt - franxx.store worktree 助手

跟踪的项目目录: /path/to/franxx.store

用法:
  wt <command> [args]
  wt <worktree-name>

命令:
  help               显示此帮助（无参数时的默认命令）
  list               列出所有 worktree（无参数时的默认命令）
  add <name>         创建新 worktree，复制环境文件、安装依赖并启动 dev server（行为可通过 wt config 配置）
  rm [name]          删除 worktree（别名: remove；省略 name 时使用当前目录）
  clean              清理数字 worktree（匹配前缀 + 数字）
  main               输出主 worktree 的路径
  path <name>        输出指定 worktree 的路径
  config             查看或更新 worktree.sh 配置
  uninstall          卸载 wt 并清理 shell 集成
  init [--branch <name>] 将当前仓库默认值写入 ~/.worktree.sh/config.kv
  shell-hook <shell> 输出 shell 集成片段 (bash|zsh)

```

## 安装和使用流程

### 快速安装

#### 自动检测 shell（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash
```

#### Zsh 用户

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell zsh
```

#### Bash 用户

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell bash
```

### 卸载

#### 自动检测 shell（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash
```

#### Zsh 用户

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash -s -- --shell zsh
```

#### Bash 用户

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash -s -- --shell bash
```

安装后也可以直接运行 `wt uninstall`，它会卸载 wt 可执行文件并清理 shell 集成，与单独的脚本作用一致。

#### 安装脚本做了什么？

1. **下载并安装 wt 命令**
   - 通过 GitHub Raw 链接下载官方仓库中的最新 `bin/wt`
   - 将脚本复制到 `~/.local/bin/`（默认路径）
   - 检查 `~/.local/bin` 是否在 PATH 中，如果不在会提示添加

2. **配置 Shell 集成**（默认自动检测，可用 --shell 参数指定）
   - 在 `~/.zshrc` 或 `~/.bashrc` 中添加 wt 的 shell hook
   - Shell hook 让 `wt add`、`wt rm`、`wt clean` 等命令能自动切换目录
   - 添加的代码块以 `# wt shell integration:` 标记，方便识别

3. **安装后的下一步**
   - 重新加载 shell 配置：`source ~/.zshrc` 或 `source ~/.bashrc`
   - 在你的项目仓库根目录运行 `wt init` 初始化配置
   - 开始使用 `wt add <name>` 创建 worktree

#### 卸载脚本做了什么？

1. **删除 wt 命令**
   - 从 `~/.local/bin/` 删除 `wt` 可执行文件

2. **清理 Shell 配置**
   - 从 `~/.zshrc` 或 `~/.bashrc` 中删除 wt 相关的 shell hook
   - 只删除以 `# wt shell integration:` 开头的代码块

3. **保留用户数据**
   - 会将 `~/.worktree.sh` 备份为 `~/.worktree.sh.backup.<timestamp>`（如不需要可手动删除）
   - 不会删除已创建的 worktree 目录

## 更多示例

```bash
# 查看帮助
wt help

# 列出所有 worktree
wt list

# 创建多个 worktree 用于不同功能
wt add feature-login     # 创建功能分支
wt add 3001             # 创建开发服务器（端口 3001）
wt add bugfix-header    # 创建修复分支

# 快速切换
wt feature-login        # 切换到 feature-login worktree
wt 3001                # 切换到 3001 worktree
wt main                # 回到主仓库

# 配置选项
wt config set add.serve-dev.enabled false      # 关闭自动启动开发命令
wt config set add.install-deps.enabled true  # 开启自动安装依赖
wt config set add.branch-prefix "feature/"     # 自定义新建分支的前缀
wt config set add.branch-prefix '""'           # 取消前缀，使分支名与 worktree 一致
wt config list                               # 查看所有配置

# 清理工作
wt rm                  # 删除当前 worktree（有确认提示）
wt rm 3001 --yes      # 直接删除指定 worktree
wt clean              # 清理所有数字命名的 worktree
```

配置默认写入 `~/.worktree.sh/config.kv`（key=value 文本格式），你也可以通过环境变量 `WT_CONFIG_FILE` 指定其他路径。该文件同时包含默认值与用户覆写，wt 直接读取它，无需额外 JSON 缓存或 Python 解析。

## 命令参考

| 命令            | 行为                                                                                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wt help`       | 显示命令帮助概览。                                                                                                                                            |
| `wt list`       | 列出所有 worktree（`git worktree list`）。                                                                                                                    |
| `wt add <name>` | • 在 `../franxx.store.<name>` 创建新 worktree<br>• 新建分支 `feat/<name>`<br>• 自动复制 `.env.local` 或 `.env`<br>• 执行 `npm ci`<br>• 启动 `npm run dev`（端口取整型名称或末尾数字）<br> |
| `wt rm [name]`  | 不带参数时删除当前 worktree（默认 **Y**，可回车确认）；<br> 带参数时直接删除指定 worktree。                                                                   |
| `wt clean`      | 批量清理数字命名的 worktree（如 `3000`、`1122`），并删除对应 `feat/*` 分支；非数字名称保留。                                                                  |
| `wt uninstall`  | 卸载 wt 命令并清理 shell 集成（等同于 uninstall.sh）。                                                                             |
| `wt main`       | 移动到主仓库路径。                                                                                                                                            |
| `wt <name>`     | 移动到目标 worktree 路径）。                                                                                                                                  |
