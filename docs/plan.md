# wt add / wt merge 基线行为与执行范围调整方案

## 背景

- 目前 `wt add` / `wt merge` 依赖项目配置中的 `repo.branch`。当首次在某个分支上 `wt init` 时，该字段就被写死，后续命令会无视主仓当前分支。
- 用户期望：命令应当跟随主仓的实时分支，且只要处于项目仓库或其子目录即可执行。
- `repo.branch` 的固定基线带来了配置维护成本，也容易与实际使用习惯冲突。

## 目标

1. `wt add` / `wt merge` 默认使用主仓库当前检出的分支作为基线。
2. 在主仓库根目录及其任意子目录执行时生效；在其他工作树或无关目录执行时给出明确错误提示。
3. 当主仓处于 detached HEAD 时，命令直接报错提示切换到具名分支，避免使用过期配置值。
4. 清理 `repo.branch` 配置项，对旧接口提供友好的忽略提示。

## 行为调整

### 1. 实时分支探测

- 新增 `project_current_branch()`（名称待定）辅助函数，通过 `git_project symbolic-ref --quiet --short HEAD` 获取主仓当前分支名。
- `cmd_add`、`cmd_merge` 在执行前调用该函数；若返回非空值，直接作为 `base_branch`。
- 若返回空值（detached 或错误），抛出新错误信息 `wt: 主仓未处于任何分支，请先切换到具名分支`。
- `detect_repo_default_branch` 仍保留，但仅在需要辅助显示或后续逻辑时使用；不再覆盖实时分支。

### 2. `repo.branch` 清理策略

- 完全移除 `WORKING_REPO_BRANCH` 变量，`cmd_add` / `cmd_merge` / `cmd_sync` 一律依赖实时分支或远端默认分支探测。
- `wt init` 保留对 `branch <name>` 参数的解析，仅输出“该配置已移除”的提示，不再写入配置文件。
- `config-example.kv`、`wt config` 帮助文案与命令文档同步删去 `repo.branch` 条目；旧配置中的该键允许读取但不会影响逻辑。
- 发布说明中提醒用户删除脚本里的旧参数，必要时可在后续版本评估是否提供新的显式开关。

### 3. 执行目录限制

- 增强 `resolve_project` 或新增检查：
  - 通过 `git rev-parse --show-toplevel` 获取当前目录所属仓库根；若不存在，报错“请在项目仓库内执行”。
  - 对比该根路径与 `WORKING_REPO_PATH`。若不一致：
    - 若当前仓库属于某个 worktree（路径带 `.something`），提示“请在主仓 `<repo.path>` 或其子目录执行”。
    - 阻止命令继续。
- 更新 `current_scope()` / `cmd_add` / `cmd_merge`：在 scope 判定为 project 后仍需通过上述检查，从而防止在其他项目工作树中误用。

### 4. 提示与国际化

- 在 `bin/messages.sh` 增加：
  - `project_branch_detached`：提示主仓处于 detached HEAD。
  - `project_wrong_directory`：提示命令必须在配置仓库或其子目录执行。
- 确保中英文翻译同步。

### 5. 文档更新

- `docs/command.md`：
  - `wt add` / `wt merge` 行为描述更新为“基于主仓当前分支”。
  - 新增“必须在主仓根目录或其子目录执行”提醒。
  - 记录 `repo.branch` 已移除并补充迁移提示。
- `README.md` / `README.zh-CN.md` 如提到 `repo.branch`，同步调整。

## 测试计划

1. **主仓 main 分支**：在 `main` 上执行 `wt add foo`，确认新分支基于 `main`。
2. **切换到 feat**：在主仓检出 `feat`，执行 `wt add bar`，应基于 `feat`。
3. **detached HEAD**：`git checkout <commit>` 后运行 `wt add baz`，应报错提醒切回分支。
4. **工作树目录**：在 `repo.some` 工作树内执行 `wt add qux`，应提示必须在主仓内执行。
5. **非 git 目录**：在任意非 git 目录执行命令，确认报错准确。
6. **wt merge**：重复上述 1-4，对 `wt merge <name>` 验证同样逻辑。
7. **`wt list` 兼容**：确认列表展示仍按实时分支显示。

## 风险与回滚

- 改动集中在 Bash 脚本核心逻辑，需要谨慎测试，尤其是跨语言提示。
- 若用户大量依赖 `repo.branch` 固定基线，行为会改变；需在文档和错误提示中明确说明。
- 回滚策略：保留旧 `repo.branch` 流程的备份分支，必要时恢复。

## 里程碑

1. 方案评审通过。
2. 实现与本地验证。
3. 文档同步与 shellcheck/shfmt。
4. 用户验收后根据反馈评估是否需要额外重构。
