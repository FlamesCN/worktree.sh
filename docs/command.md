# worktree.sh 命令说明

## 概览

| 命令                    | 位于非项目目录                                                                 | 位于项目目录                                                       |
| ----------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `wt help`               | 显示帮助                                                                       | 显示帮助                                                           |
| `wt init`               | 提示需在项目内执行                                                             | 在当前仓库写项目配置并追踪项目                                     |
| `wt main`               | 列出所有项目供选择，确认后输出所选项目主仓路径（auto-cd）                      | 输出当前项目主仓路径（auto-cd）                                    |
| `wt list`               | 按项目分组列出全部 worktree                                                    | 列出当前项目 worktree                                              |
| `wt <name>`             | 全局搜索匹配，0 命中提示 init，1 命中直接打印，多命中列出选择再打印（auto-cd） | 直接打印当前项目的目标路径（auto-cd）                              |
| `wt clean`              | 逐项确认后按项目输出清理结果                                                   | 批量清理数字 worktree，最终输出主仓路径（auto-cd）                 |
| `wt rm`                 | 提示需在项目内执行                                                             | 删除当前 worktree，最终输出主仓路径（auto-cd）                     |
| `wt rm <name>`          | 全局匹配逐项确认；确认后输出所选项目主仓路径（auto-cd）                        | 删除当前项目同名 worktree；若删除当前目录则返回主仓路径（auto-cd） |
| `wt add`                | 提示需在项目内执行                                                             | 创建新 worktree 并输出新目录路径（auto-cd）                        |
| `wt merge <name>`       | 提示需在项目内执行                                                             | 合并指定 worktree 至主仓                                           |
| `wt config set <k> <v>` | 提示需在项目内执行                                                             | 写入当前项目的配置                                                 |
| `wt config unset`       | 提示需在项目内执行                                                             | 从当前项目移除键                                                   |
| `wt config get <k>`     | 读取默认/全局配置；未识别项目时仅返回默认值                                    | 读取当前项目的生效配置值（含默认叠加）                             |
| `wt config list`        | 提示需在项目内执行                                                             | 列出当前项目的生效配置（包含默认值）                               |
| `wt sync`               | 提示需在项目内执行                                                             | 将主工作区的补丁应用到同项目选定 worktree（需确认目标）            |
| `wt detach`             | 列出所有已配置项目供选择，确认后删除所选项目配置目录                           | 直接移除当前项目的配置目录（可用 --yes 跳过确认）                  |
| `wt shell-hook <shell>` | 输出指定 shell 的集成脚本片段                                                  | 输出指定 shell 的集成脚本片段                                      |
| `wt uninstall`          | 卸载并删除配置文件以及 shell hook                                              | 卸载并删除配置文件以及 shell hook                                  |
| `wt reinstall`          | 重新安装                                                                       | 重新安装                                                           |

## 详细说明

### `wt help`

- **定位**: 全局或项目目录均可调用；无参数时也是默认执行的命令。
- **语法**: `wt help` 或直接运行 `wt`。
- **行为**: 输出核心命令列表，并以框图展示当前默认项目目录；自动根据 `wt config` 中的 `language` 选择中英文。
- **注意**: 未完成 `wt init` 时仍会显示帮助，但会标注项目目录未设置；设置 `NO_COLOR` 可禁用彩色高亮。

### `wt init`

- **定位**: 需在目标 Git 仓库内执行，且仓库必须位于非 `$HOME` 根目录。
- **语法**: `wt init [branch <name>]` 或 `wt init [--branch <name>]`。
- **行为**: 解析仓库根路径，生成项目 slug，在 `~/.worktree.sh/projects/<slug>/config.kv` 写入 `repo.path` 及可选 `repo.branch`，并加载默认模板 `config-example.kv`。
- **注意**: 若 slug 对应的配置已存在且 `repo.path` 不匹配会拒绝覆盖；git 仓库缺失时直接报错；成功后刷新进程内的项目上下文。

### `wt main`

- **定位**: 全局或项目目录均可执行。
- **语法**: `wt main`。
- **行为**: 项目目录内直接打印主仓路径；全局模式列出已登记项目，用户确认后输出选择的仓库路径（供 shell hook 自动 `cd`）。
- **注意**: 没有任何项目配置时会提示先运行 `wt init`；输出路径前会尝试提醒是否安装 shell hook。

### `wt list`

- **定位**: 全局或项目目录均可执行。
- **语法**: `wt list`。
- **行为**: 项目目录内列出当前项目的所有 worktree（含分支、HEAD、状态）；全局模式按项目分组依次打印，无法访问的仓库会提示错误后继续。
- **注意**: 输出采用 `git worktree list --porcelain` 的信息，`NO_COLOR` 同样可禁用加粗高亮。

### `wt <name>` / `wt path <name>`

- **定位**: 全局或项目目录均可执行。
- **语法**: `wt <worktree>` 等价于 `wt path <worktree>`。
- **行为**: 在项目目录中根据 `WORKTREE_NAME_PREFIX` 定位工作树路径并输出；全局模式遍历所有项目匹配名称，0 命中报错，1 命中直接返回，多命中时提供交互选择。
- **注意**: 成功时只打印路径，是否自动进入由 `wt shell-hook` 决定；如果工作树目录缺失会提示重新 `wt clean` 或手动校准。

### `wt add <name>`

- **定位**: 仅在项目目录或其任意工作树中可执行。
- **语法**: `wt add <name>`。
- **行为**: 校验名称合法性 → 创建 `${WORKTREE_NAME_PREFIX}<name>` 目录和对应分支（默认 `add.branch-prefix`，缺省 `feat/`）→ 按配置复制环境文件、安装依赖并尝试启动开发服务。
- **配置项**: `add.copy-env.*` 控制复制文件，`add.install-deps.*` 控制依赖安装，`add.serve-dev.*` 控制 dev server；`wt config` 支持逐项目自定义。
- **注意**: 目标目录存在、名称格式非法或 git 分支冲突时会终止；无法推断可用端口或命令时会跳过并给出提示。
- **结果**: 成功后输出新工作树路径并触发 auto-cd 提示。

### `wt rm` / `wt rm <name>`

- **定位**: 项目目录内可删除当前或指定工作树，全局模式需显式提供名称。
- **语法**: `wt rm [-y|--yes]` 删除当前工作树；`wt rm [-y|--yes] <name> [...]` 删除一个或多个工作树；全局模式同样支持多名称。
- **行为**: 调用 `git worktree remove --force` 并尝试删除 `${branch-prefix}<name>` 分支；当前目录被删除时返回主仓路径。
- **注意**: 禁止删除主仓；默认逐项确认，可用 `-y/--yes` 跳过；全局模式下如果多个项目同名，会逐项目提示并允许跳过某些实例。

### `wt clean`

- **定位**: 项目或全局目录均可执行。
- **语法**: `wt clean`。
- **行为**: 项目模式下批量移除名称匹配 `WORKTREE_NAME_PREFIX + 数字` 的工作树；全局模式收集所有项目的数字工作树，逐条确认后清理，并在当前工作树遭清理时自动回退到主仓路径。
- **注意**: 清理后会调用 `git worktree prune`；未找到候选时输出“无工作树可清理”。

### `wt merge <name>`

- **定位**: 仅在主仓工作目录执行。
- **语法**: `wt merge <worktree>`。
- **前置条件**: 当前分支必须等于配置的基准分支（`repo.branch` 或自动推断），工作树及目标分支需完全干净，无未跟踪文件。
- **行为**: 计算 `branch_for(<name>)`，如果存在可合并提交则运行 `git merge --no-edit` 将其合入基准分支；合并成功后提示可删除对应工作树。
- **注意**: 若 `branch` 与基准分支相同或不存在、合并冲突、主仓脏都会报错并（如有需要）执行 `git merge --abort` 回滚。

### `wt sync`

- **定位**: 仅在主仓工作目录执行。
- **语法**: `wt sync all` 或 `wt sync <name> [更多名称]`。
- **行为**: 验证主仓无未暂存/未跟踪文件后，将索引中的改动导出为补丁并应用到目标工作树；`all` 模式会遍历所有符合命名规则的工作树。
- **注意**: `SERVE_DEV_LOGGING_PATH` 对应的目录会自动加入补丁排除；补丁任一目标应用失败即中止；指定名称时会跳过主仓本身或找不到的工作树并报错。

### `wt config`

- **定位**: `get/list` 任何上下文均可；`set/unset` 需识别到项目并且未通过 `WT_CONFIG_FILE` 强制覆盖。
- **语法**: `wt config list`、`wt config get <key> [--stored]`、`wt config set <key> <value>`、`wt config unset <key>`；也支持 `wt config <key>`（读取）和 `wt config <key> <value>`（写入）。
- **行为**: 读取顺序为内置默认 → 全局模板 `config.kv` → 项目配置；写入仅触及当前项目文件。
- **常用键**: `language`、`repo.branch`、`add.branch-prefix`、`add.copy-env.*`、`add.install-deps.*`、`add.serve-dev.*`、`add.serve-dev.logging-path` 等，详见 `config-example.kv`。
- **注意**: 写入 `language` 时会校验合法值；`--stored` 仅返回配置文件值而不包含默认值；未识别到项目时写操作会直接报错。

### `wt detach`

- **定位**: 项目或全局目录均可。
- **语法**: `wt detach [slug] [--yes|--force]`。
- **行为**: 删除 `~/.worktree.sh/projects/<slug>` 目录，使 wt 忘记该项目但不影响仓库与现有工作树；全局模式未提供 slug 会弹出项目列表。
- **注意**: 当前项目被移除后需重新 `wt init` 才能继续使用；`--yes/--force` 可跳过确认。

### `wt shell-hook <shell>`

- **定位**: 任意目录。
- **语法**: `wt shell-hook zsh` 或 `wt shell-hook bash`。
- **行为**: 输出对应 shell 的包装函数，常配合 `eval "$(wt shell-hook zsh)"` 实现命令输出路径后自动 `cd`。
- **注意**: 命令本身不会修改配置或文件；`--help` 会显示中英文用法示例。

### `wt uninstall`

- **定位**: 任意目录。
- **语法**: `wt uninstall [--shell <zsh|bash|none>] [--prefix <dir>]`。
- **行为**: 删除 `<prefix>` 下的 `wt` 可执行文件与 `messages.sh`，根据 shell 类型清理 hook，并将默认配置目录/文件整体移动到带时间戳的备份。
- **注意**: 未指定 `--shell` 时自动检测当前 shell；若安装文件不存在会打印提示但不会视为失败；不会删除任何项目工作树。

### `wt reinstall`

- **定位**: 任意目录，要求已安装 curl 并具备网络访问。
- **语法**: `wt reinstall [--shell <zsh|bash|none>] [--prefix <dir>]`。
- **行为**: 临时下载 `uninstall.sh` 与 `install.sh`（默认源自 `https://raw.githubusercontent.com/notdp/worktree.sh/main`），依次执行以刷新安装，脚本结束后清理临时目录。
- **注意**: 下载失败会立刻终止并保留备份；可通过环境变量 `WT_INSTALL_PREFIX` 或参数覆盖安装目录和 shell 类型。

### `wt version`

- **定位**: 任意目录。
- **语法**: `wt version`。
- **行为**: 输出当前构建的版本字符串（源自 `bin/lib/runtime.sh` 中的 `VERSION`）。
