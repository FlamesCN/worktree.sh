# worktree.sh
>
> Zero-friction git worktree manager for parallel feature development.

[中文文档 »](README.zh-CN.md)

worktree.sh packages the repetitive setup required to spin up extra git worktrees: it creates branches, copies environment files, installs dependencies, and even starts your dev server so you can jump straight into coding.

## Highlights

- Launch ready-to-code worktrees with one command; automatic branch naming and directory placement keep everything tidy.
- Reuse the same CLI to jump between the main repo and feature sandboxes without thinking about paths.
- Configurable shell hooks keep `wt` available everywhere and let commands cd into the right folder automatically.
- Safe cleanup helpers remove stale worktrees and their branches while preserving your project data.

## Why Local Worktrees Matter for Agents

- Until agents can truly self-dispatch, they still need a “local PR” checkpoint; a worktree is the sandbox where you polish changes before anything hits a hosted platform.
- Instead of handing the entire flow to a Claude Code subagent, keeping a local worktree lets you intervene at will and keeps the primary agent’s context lightweight.
- Spin up separate worktrees for high-variance explorations—think Claude Code “gacha” pulls on front-end UI—while Codex runs deterministic backend tasks that don’t contend for the same resources.
- As models stretch into long-running sessions (minutes, hours, or more), parallel worktrees are a practical way to keep multiple agents or tasks moving without stepping on each other.
- Solo developers can stay entirely local: agent-to-agent collaboration happens inside these worktrees, and pushing to a remote only matters if you need Codex Web, Codex PR Review, Claude Code PR Review, or another external service.

## Quick Look

![CLI overview](asset/worktree.sh.screenshot-1.png)
![Worktree switching](asset/worktree.sh.screenshot-2.png)

## Quick Start

1. Install the CLI (auto-detects shell):

   ```bash
   curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash
   ```

2. In the repository you want to parallelize, record it as the default project:

   ```bash
   wt init
   ```

3. Spin up a new worktree:

   ```bash
   wt add 3000
   ```

   - Creates the worktree in `../project.3000`
   - Creates and checks out `feat/3000`
   - Copies `.env.local` / `.env`
   - Runs `npm ci`
   - Starts `npm run dev` on port `3000`
4. Jump between worktrees anytime:

   ```bash
   wt 3000    # go to the new sandbox
   wt main    # return to the primary repository
   ```

5. Clean up when done:

   ```bash
   wt rm 3000
   ```

## Everyday Commands

| Command          | What it does                                                                                              |
| ---------------- | --------------------------------------------------------------------------------------------------------- |
| `wt` / `wt list` | Show tracked worktrees (wrapper over `git worktree list`).                                                |
| `wt add <name>`  | Create worktree, branch, copy env files, install deps, launch dev server (behavior controlled by config). |
| `wt <name>`      | Jump straight into an existing worktree directory.                                                        |
| `wt rm [name]`   | Delete current worktree or the one you name (prompts unless `--yes`).                                     |
| `wt clean`       | Batch-remove numerically named worktrees and matching `feat/*` branches.                                  |
| `wt main`        | Output the main repository path.                                                                          |
| `wt config`      | Inspect or tweak CLI behavior.                                                                            |
| `wt uninstall`   | Remove the binary and shell hooks.                                                                        |
| `wt help`        | Show built-in reference for all commands.                                                                 |

## Installation Options

The install script copies the latest `bin/wt` to `~/.local/bin/`, registers shell integration, and prompts if the path is missing from `PATH`.

- Auto-detect (recommended):

  ```bash
  curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash
  ```

- Force zsh:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell zsh
  ```

- Force bash:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell bash
  ```

After installation reload your shell (`source ~/.zshrc` or `source ~/.bashrc`) and run `wt init` inside the repository you want as the default project.

## Configuration Essentials

Settings live in `~/.worktree.sh/config.kv`. Update them with `wt config set`:

```bash
wt config set add.serve-dev.enabled false    # Disable auto dev server
wt config set add.install-deps.enabled true  # Ensure dependencies are installed
wt config set add.branch-prefix "feature/"   # Customize branch prefixes
wt config set add.branch-prefix '""'         # Allow branches to match worktree names
wt config list                               # Inspect current values
```

Set the `WT_CONFIG_FILE` environment variable if you prefer a custom config path. The CLI reads the key/value file directly—no extra caches or daemons.

## Clean Removal

When a worktree is obsolete, prune the directory and branch in one go:

```bash
wt rm            # Removes current worktree with confirmation
wt rm 3001 --yes # Removes named worktree without prompting
wt clean         # Clears all numerically named worktrees
```

To uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash
```

You can also run `wt uninstall`, which deletes the executable, removes shell hooks tagged `# wt shell integration:`, and backs up `~/.worktree.sh` to `~/.worktree.sh.backup.<timestamp>`.

---

Give worktree.sh a try if you iterate on multiple features in parallel; it keeps your terminals synchronized and your focus on shipping, not setup.
