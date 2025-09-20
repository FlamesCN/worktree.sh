# worktree.sh

As Claude Code's intelligence recovers and gpt5 high in Codex shows high IQ, I'm increasingly inclined to use git worktree for parallel development. However, the repetitive work of creating branches, setting up worktrees, copying environment variables, installing dependencies, and starting services increases the difficulty of using worktrees.

I've also tried claude code command or using files to coordinate communication between multiple claude code and codex instances, but currently these two agents interact with the file system slowly, so this project was born.

If you also want to try parallel development, give this project a try.

- [中文](README.zh-CN.md)

## Complete Usage Flow

```bash
# 1. After installation, navigate to your project repository
cd ~/path/to/your/project

# 2. Initialize wt configuration (record current repository as default project)
wt init

# 3. Create new worktree (automatically completes the following steps)
wt add 3000
# - Creates new worktree in ../project.3000
# - Creates and switches to feat/3000 branch
# - Copies .env.local and .env files
# - Runs npm ci to install dependencies
# - Starts npm run dev (port 3000 — derived from numeric name or trailing digits, e.g. grid3000 ⇒ 3000)
# - Automatically switches to new directory

# 4. Switch between different worktrees
wt 3000        # Switch to 3000 worktree
wt main        # Return to main repository

# 5. Clean up worktrees no longer needed
wt rm          # Delete current worktree
wt rm 3000     # Delete specified worktree
wt clean       # Batch clean all numerically named worktrees
```

## Command Reference

Run `wt help` to quickly view all commands:

```text
$ wt help
wt - franxx.store worktree assistant

Tracked project directory: /path/to/franxx.store

Usage:
  wt <command> [args]
  wt <worktree-name>

Commands:
  help               Display this help (default command with no arguments)
  list               List all worktrees (default command with no arguments)
  add <name>         Create new worktree, copy environment files, install dependencies and start dev server (behavior configurable via wt config)
  rm [name]          Delete worktree (alias: remove; uses current directory when name is omitted)
  clean              Clean numeric worktrees (matching prefix + number)
  main               Output path of main worktree
  path <name>        Output path of specified worktree
  config             View or update worktree.sh configuration
  uninstall          Uninstall wt and clean shell hooks
  init [--branch <name>] Write current repository defaults to ~/.worktree.sh/config.json
  shell-hook <shell> Output shell integration snippet (bash|zsh)

```

## Installation and Usage

### Quick Installation

#### Auto-detect shell (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash
```

#### Zsh Users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell zsh
```

#### Bash Users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/install.sh | bash -s -- --shell bash
```

### Uninstallation

#### Auto-detect shell (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash
```

#### Zsh Users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash -s -- --shell zsh
```

#### Bash Users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/worktree.sh/main/uninstall.sh | bash -s -- --shell bash
```

You can also run `wt uninstall` from your terminal after installation; it removes the installed binary and cleans shell hooks just like the script.

#### What Does the Installation Script Do?

1. **Download and Install wt Command**
   - Downloads the latest `bin/wt` from the official repository via GitHub Raw link
   - Copies script to `~/.local/bin/` (default path)
   - Checks if `~/.local/bin` is in PATH, prompts to add if not

2. **Configure Shell Integration** (auto-detects by default, can specify with --shell parameter)
   - Adds wt shell hook to `~/.zshrc` or `~/.bashrc`
   - Shell hook enables commands like `wt add`, `wt rm`, `wt clean` to auto-switch directories
   - Added code block is marked with `# wt shell integration:` for easy identification

3. **Next Steps After Installation**
   - Reload shell configuration: `source ~/.zshrc` or `source ~/.bashrc`
   - Run `wt init` in your project repository root to initialize configuration
   - Start using `wt add <name>` to create worktrees

#### What Does the Uninstall Script Do?

1. **Remove wt Command**
   - Deletes `wt` executable from `~/.local/bin/`

2. **Clean Shell Configuration**
   - Removes wt-related shell hooks from `~/.zshrc` or `~/.bashrc`
   - Only removes code blocks starting with `# wt shell integration:`

3. **Preserve User Data**
   - Backs up `~/.worktree.sh` to `~/.worktree.sh.backup.<timestamp>` (remove manually if you don't need it)
   - Does not delete created worktree directories

## More Examples

```bash
# View help
wt help

# List all worktrees
wt list

# Create multiple worktrees for different features
wt add feature-login     # Create feature branch
wt add 3001             # Create development server (port 3001)
wt add bugfix-header    # Create fix branch

# Quick switching
wt feature-login        # Switch to feature-login worktree
wt 3001                # Switch to 3001 worktree
wt main                # Return to main repository

# Configuration options
wt config set worktreeAdd.serveDev.enabled false      # Disable auto-run dev command
wt config set worktreeAdd.installDeps.enabled true  # Enable auto-install dependencies
wt config set worktreeAdd.branchPrefix "feature/"     # Customize branch name prefix
wt config set worktreeAdd.branchPrefix '""'           # Remove prefix so branches match worktree names
wt config list                               # View all configuration

# Cleanup work
wt rm                  # Delete current worktree (with confirmation prompt)
wt rm 3001 --yes      # Directly delete specified worktree
wt clean              # Clean all numerically named worktrees
```

Configuration is now sourced exclusively from `~/.worktree.sh/config.json`. Temporary `WT_*` environment overrides are no longer supported.

## Command Reference

| Command         | Behavior                                                                                                                                                                |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wt help`       | Display command help overview.                                                                                                                                          |
| `wt list`       | List all worktrees (`git worktree list`).                                                                                                                               |
| `wt add <name>` | • Create new worktree in `../franxx.store.<name>`<br>• Create branch `feat/<name>`<br>• Auto-copy `.env.local` or `.env`<br>• Run `npm ci`<br>• Start `npm run dev` (port from numeric name or trailing digits)<br> |
| `wt rm [name]`  | Without parameters, delete current worktree (default **Y**, press Enter to confirm);<br> With parameters, directly delete specified worktree.                           |
| `wt clean`      | Batch clean numerically named worktrees (e.g., `3000`, `1122`), and delete corresponding `feat/*` branches; non-numeric names are preserved.                            |
| `wt uninstall`  | Remove the installed wt binary and clean shell hooks (same as uninstall.sh).                                                          |
| `wt main`       | Move to main repository path.                                                                                                                                           |
| `wt <name>`     | Move to target worktree path.                                                                                                                                           |
