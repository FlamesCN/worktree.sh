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

- A worktree hard-isolates each agent’s context—filesystem, git history, env—so runs never cross-contaminate, the primary agent keeps its context window free, and you can hop in at any moment instead of being locked out by a non-interactive Claude Code subagent.
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
  - Runs `npm ci` (skips automatically if no Node.js lockfile is present)
   - Starts `npm run dev` on port `3000`
4. Jump between worktrees anytime:

   ```bash
   wt 3000    # go to the new sandbox
   wt main    # return to the primary repository
   ```

5. Merge back once the feature branch is committed:

   ```bash
   wt merge 3000
   ```

   - Run from the main worktree with a clean status on both sides.
   - Fails fast if either worktree has uncommitted changes or the feature branch has nothing new to merge.

6. Clean up when done:

   ```bash
   wt rm 3000
   ```

## Everyday Commands

| Command         | What it does                                                                                              |
| --------------- | --------------------------------------------------------------------------------------------------------- |
| `wt list`       | Show tracked worktrees (wrapper over `git worktree list`).                                                |
| `wt add <name>` | Create worktree, branch, copy env files, install deps, launch dev server (behavior controlled by config). |
| `wt merge <name>` | Merge the feature branch (`feat/<name>`) into the base branch once both worktrees are clean and committed. |
| `wt sync all` / `wt sync <name ...>` | Copy the main workspace's staged changes into one or more clean worktrees, leaving them staged for commit. |
| `wt <name>`     | Jump straight into an existing worktree directory.                                                        |
| `wt rm [name ...]`  | Delete current worktree or any named ones (prompts for current unless `--yes`).                           |
| `wt clean`      | Batch-remove numerically named worktrees and matching `feat/*` branches.                                  |
| `wt detach [slug]` | Remove wt-managed worktrees for a project and delete its registry entry (add `-y` to skip prompts).         |
| `wt main`       | Output the main repository path.                                                                          |
| `wt config`     | Inspect or tweak CLI behavior.                                                                            |
| `wt reinstall`  | Run the bundled `uninstall.sh` followed by `install.sh` to refresh wt in place.                          |
| `wt uninstall`  | Remove the binary and shell hooks.                                                                        |
| `wt help`       | Show built-in reference for all commands.                                                                 |

### Syncing staged changes

1. Stage the files you want to distribute from the main workspace (`git add ...`).
2. Run `wt sync all` to update every managed worktree, or target a subset with `wt sync feat1 feat2`.
3. Each target worktree must be clean; the staged changes will appear as staged edits ready to commit on that branch.

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

Need a newer build later? Run `wt reinstall`—it chains `./uninstall.sh` and `./install.sh` so you end up with a fresh install without manual steps.

Reinstalls are idempotent. If we ever ship a breaking change, you can still fall back to `wt uninstall` followed by rerunning the install script.

## Configuration Essentials

Settings live in `~/.worktree.sh/config.kv`. Update them with `wt config set`:

```bash
wt config set add.serve-dev.enabled false    # Disable auto dev server
wt config set add.install-deps.enabled true  # Ensure dependencies are installed
wt config set add.branch-prefix "feature/"   # Customize branch prefixes
wt config set language zh                    # Switch CLI prompts to Simplified Chinese
wt config list                               # Inspect current values
```

Set the `WT_CONFIG_FILE` environment variable if you prefer a custom config path. The CLI reads the key/value file directly—no extra caches or daemons.

## Clean Removal

When a worktree is obsolete, prune the directory and branch in one go:

```bash
wt rm              # Removes current worktree with confirmation
wt rm feat3001 feat3002    # Removes multiple named worktrees without prompting
wt clean           # Clears all numerically named worktrees
wt detach -y       # Removes all wt-managed worktrees for this project and unregisters it
```

To uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash
```

You can also run `wt uninstall`, which deletes the executable, removes shell hooks tagged `# wt shell integration:`, and backs up `~/.worktree.sh` to `~/.worktree.sh.backup.<timestamp>`.

---

Give worktree.sh a try if you iterate on multiple features in parallel; it keeps your terminals synchronized and your focus on shipping, not setup.
