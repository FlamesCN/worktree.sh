# wt-cli

[中文版](./README.zh-CN.md)

With Claude Code's intelligence recovery and Codex's GPT5-high capabilities, I increasingly favor using git worktree for parallel development. However, the repetitive tasks of creating branches, setting up worktrees, copying environment variables, installing dependencies, and starting services add friction to using worktrees.

I've also tried claude code commands or using files to coordinate multiple claude code and codex instances, but the interaction between these agents and the file system is inevitably slow. Hence this project was born.

If you'd also like to try parallel development, give this project a shot.

## Feature Checklist

| Command          | Behaviour                                                                                                                                                                                                                                                                                                                                           |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wt` / `wt help` | Show CLI usage summary.                                                                                                                                                                                                                                                                                                                             |
| `wt list`        | List all worktrees (`git worktree list`).                                                                                                                                                                                                                                                                                                           |
| `wt add <name>`  | Creates `../franxx.store.<name>` with branch `feat/<name>`, copies `.env.local`/`.env`, runs `npm ci`, and launches `npm run dev`. Numeric names in `1024-65535` become the dev-server port; names in `1-1023` emit a warning. The command prints the target path so you can `cd "$(wt add 12345)"`. Dev logs land in `tmp/npm-run-dev-<port>.log`. |
| `wt rm [name]`   | Removes the current worktree (prompts `[Y/n]`, default **Y**) or a named worktree (no prompt). Removing the current dir prints the main repo path, so `cd "$(wt rm)"` takes you home.                                                                                                                                                               |
| `wt clean`       | Cleans every numeric worktree (e.g. `3000`, `1122`) and drops their `feat/*` branches. If the current worktree is removed, stdout includes the main repo path.                                                                                                                                                                                      |
| `wt main`        | Prints the primary repo path; pair with `cd "$(wt main)"`.                                                                                                                                                                                                                                                                                          |
| `wt <name>`      | Prints the target worktree path (use `cd "$(wt 3000)"`).                                                                                                                                                                                                                                                                                            |

-### User Experience niceties

- Chinese copy by default; switch to English (or back) with `wt config set core.language english|chinese` or the `WT_LANGUAGE` environment variable.
- Progress hints with emojis: 🔧 create → 📦 install → 🚀 launch → ✅ done.
- Port validation: only 1024-65535 numeric names become ports; 1-1023 trigger a
  warning but still start on the default port.
- Background dev server logging under `tmp/npm-run-dev-<port>.log` with PID files
  for quick lookup.
- `PATH` variable never shadowed (uses `target_path`), so tools like `autojump`
  keep working.

> When you need to change directories, wrap the command with
> `cd "$(wt …)"` or use your favourite shell helper. The CLI itself never edits
> `.zshrc` or other rc files.

## Installation and Usage

### Quick Installation

#### Auto-detect shell (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/wt-cli/main/install.sh | bash
```

#### For Zsh users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/wt-cli/main/install.sh | bash -s -- --shell zsh
```

#### For Bash users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/wt-cli/main/install.sh | bash -s -- --shell bash
```

#### What the installation script does

1. **Downloads and installs the wt command**
   - Downloads the latest `bin/wt` executable from the official GitHub repository
   - Copies the script to `~/.local/bin/` (default path)
   - Checks if `~/.local/bin` is in PATH and warns if not

2. **Configures shell integration** (auto-detected by default, can be specified with --shell parameter)
   - Adds the wt shell hook to `~/.zshrc` or `~/.bashrc`
   - The shell hook enables automatic directory switching for commands like `wt add`, `wt rm`, `wt clean`
   - The added code block is marked with `# wt shell integration:` for easy identification

3. **Next steps after installation**
   - Reload your shell config: `source ~/.zshrc` or `source ~/.bashrc`
   - Navigate to your project repository and run `wt init` to initialize configuration
   - Start using `wt add <name>` to create worktrees

### Complete Usage Flow

```bash
# 1. After installation, navigate to your project repository
cd ~/path/to/your/project

# 2. Initialize wt configuration (records current repo as default project)
wt init

# 3. Create a new worktree (automatically does the following):
wt add 3000
# - Creates new worktree at ../project.3000
# - Creates and switches to feat/3000 branch
# - Copies .env.local and .env files
# - Runs npm ci to install dependencies
# - Starts npm run dev on port 3000
# - Automatically changes to the new directory

# 4. Switch between worktrees
wt 3000        # Switch to 3000 worktree
wt main        # Go back to main repository

# 5. Clean up worktrees when done
wt rm          # Remove current worktree
wt rm 3000     # Remove specific worktree
wt clean       # Batch clean all numeric worktrees
```

### Uninstall

#### Auto-detect shell (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/wt-cli/main/uninstall.sh | bash
```

#### For Zsh users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/wt-cli/main/uninstall.sh | bash -s -- --shell zsh
```

#### For Bash users

```bash
curl -fsSL https://raw.githubusercontent.com/notdp/wt-cli/main/uninstall.sh | bash -s -- --shell bash
```

#### What the uninstallation script does

1. **Removes the wt command**
   - Deletes the `wt` executable from `~/.local/bin/`

2. **Cleans up shell configuration**
   - Removes the wt shell hook from `~/.zshrc` or `~/.bashrc`
   - Only removes code blocks starting with `# wt shell integration:`

3. **Preserves user data**
   - Does NOT delete `~/.wt-cli` config file (remove manually if needed)
   - Does NOT delete any created worktree directories

## More Examples

```bash
# Show help
wt help

# List all worktrees
wt list

# Create multiple worktrees for different features
wt add feature-login     # Create feature branch
wt add 3001             # Create dev server (port 3001)
wt add bugfix-header    # Create bugfix branch

# Quick switching
wt feature-login        # Switch to feature-login worktree
wt 3001                # Switch to 3001 worktree
wt main                # Go back to main repository

# Configuration options
wt config set add.auto_start_dev false      # Disable auto-start dev server
wt config set add.install_dependencies true  # Enable auto-install deps
wt config list                               # View all configuration

# Clean up work
wt rm                  # Remove current worktree (with prompt)
wt rm 3001 --yes      # Remove specific worktree directly
wt clean              # Clean all numeric worktrees
```

### Helpful options & env vars

- `WT_PROJECT_DIR`, `WT_WORKTREE_PREFIX`, `WT_BRANCH_PREFIX`, `WT_LOG_SUBDIR`,
  `WT_NPM_BIN`: customise directories, naming, or the npm binary.
- `WT_ADD_AUTO_START_DEV`: override the configured dev-server automation for one run (`true`/`false`).
- `WT_ADD_INSTALL_DEPS`, `WT_ADD_COPY_ENV`: override dependency installation and env file copy for a single run (`true`/`false`).
- `WT_SUPPRESS_AUTO_CD_HINT`: set to `1` if you don't want the CLI to remind you about installing the shell hook.
- `WT_LANGUAGE` / `WT_LANG`: override the interface language for a single command (`english` or `chinese`, default is Chinese). Falls back to the `LANG` locale if config is unset.
- `wt config`: inspect or update persistent defaults (see below).

### Configuration

- Tip: right after installation, run `wt init` at the franxx.store repo root to
  store the default project path (and optionally the current branch) inside `~/.wt-cli`.
- `wt config` mirrors `git config` semantics. Supported operations:
  - `wt config list`
  - `wt config get <key>`
  - `wt config set <key> <value>`
  - `wt config unset <key>`
- Canonical examples:
  - `wt config list`
  - `wt config get core.default_project_dir`
  - `wt config set add.auto_start_dev false`
  - `wt config set core.language english`
  - `wt config unset logging.subdir`
- Values live in `~/.wt-cli` (TOML).
- Recognised keys:
  - `core.default_project_dir`: base repository path for worktrees.
  - `core.default_branch`: saved by `wt init` when a branch is available/requested.
  - `core.language`: interface language (`english`/`chinese`, defaults to `chinese`).
  - `logging.subdir`: directory created under each worktree to hold dev logs.
  - `add.auto_start_dev`: `true`/`false`, controls whether `wt add` launches `npm run dev` automatically.
  - `add.install_dependencies`: `true`/`false`, controls whether `npm ci` runs.
  - `add.copy_env_files`: `true`/`false`, controls whether `.env*` files are copied.
- Environment variables still take precedence for one-off overrides, so you can run `WT_LOG_SUBDIR=out bin/wt ...` without touching the config file.

## Development

- Main script: `bin/wt`
- Installer: `install.sh`

Feel free to publish the repo and accept issues/PRs once you're ready.
