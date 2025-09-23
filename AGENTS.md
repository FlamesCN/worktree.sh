# Repository Guidelines

## Project Structure & Module Organization

This repository centers on the Bash CLI stored in `bin/wt`. Keep supporting strings in `bin/messages.sh`. Use `asset/` for documentation imagery referenced in `README.md`. `config-example.kv` illustrates the key-value config file that `wt` reads; copy it when you need fixtures. `scripts/` is reserved for future automation helpers—leave it empty unless you are wiring new tooling. Installation and removal entry points live at `install.sh` and `uninstall.sh`.

## Build, Test, and Development Commands

- `./install.sh --shell bash` installs the current checkout to your local machine; run it from a clean git state to verify install paths.
- `./bin/wt help` exercises the CLI without modifying your git tree and should succeed before submitting a change.
- `shellcheck bin/wt bin/messages.sh` validates static analysis; treat warnings as blockers.
- `shfmt -i 2 -sr -bn -w bin/wt bin/messages.sh` enforces formatting; run it before committing.

## Coding Style & Naming Conventions

Scripts target Bash 5 with `set -euo pipefail`. Indent with two spaces, place closing `fi` / `done` on their own lines, and keep functions small and composable. Name new feature branches `feat/<ticket-or-port>` to match the worktree naming logic; helper scripts should use kebab-case filenames (e.g., `scripts/bootstrap-worktree.sh`). Localized strings belong in `bin/messages.sh`; use snake_case keys and keep English and Chinese entries in sync.

## Testing Guidelines

There is no automated test harness yet, so rely on scripted smoke checks. Add temporary worktrees in a disposable repo and confirm flows such as `wt add <port>`, `wt merge <port>`, and `wt rm <port>`. When touching install paths, run both `./install.sh` and `./uninstall.sh` in a sandbox shell. Document manual steps in your PR so reviewers can replay them.

## Commit & Pull Request Guidelines

Follow conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`) as shown in `git log`. Limit commits to one logical change and describe user-facing impact in the body. Pull requests should link to tracking issues, enumerate manual test steps, and attach screenshots or terminal transcripts when CLI output changes. Request reviews from another agent when modifying upgrade or uninstall logic.

## Security & Configuration Tips

Never commit real configuration files; use `config-example.kv` for fixtures and note new keys there. Avoid writing secrets into shell history—prefer passing flags or temporary files and document the approach in the PR. If you introduce commands that touch remote repositories, gate them behind explicit prompts or `--yes` flags so agents running in automation stay safe.
