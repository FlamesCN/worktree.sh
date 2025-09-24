# wt CLI Manual Test Report — 2025-09-24

## Overview

- Completed end-to-end smoke verification of every wt subcommand after reinstalling the toolchain.
- Focused on real project repos `~/developer/franxx.ai` and `~/developer/franxx.store` as requested, creating and cleaning temporary worktrees.
- Captured full console transcripts in `tests/report-raw.log`; this document summarizes pass/fail status, notable output, and follow-ups.

## Environment

- Host: Darwin rhythm.local 24.6.0 (arm64) • zsh 5.9
- Repository: worktree.sh @ commit b89948b (dirty: bin/lib/runtime.sh, bin/messages.sh, docs/project-config.md, tests/issues.md, tests/test.md)
- wt binary under test: ./bin/wt (reports 0.1.0)
- Execution window: 2025-09-24 (US) / 2025-09-24 15:09 +08 local time
- Prereq reset: ran `./uninstall.sh` then `./install.sh --shell bash` before testing

## Preparation Notes

- `./uninstall.sh` removed the installed binary, messages, zsh hook, and config directory as expected.
- `./install.sh --shell bash` restored the binary/messages under `~/.local/bin` and appended the bash shell hook; no auto-sourcing performed.
- Removed the stray `.DS_Store` from `~/developer/franxx.ai`; preserved the tracked change in `~/developer/franxx.store/app/hooks/useAuth.tsx` to avoid altering user work in progress.

## Command Coverage

### Global scope (outside a configured project)

| Command | Result | Notes |
| --- | --- | --- |
| `wt version` | ✅ | Reported 0.1.0.
| `wt help` | ✅ | Displayed command catalog and "project directory not set" banner.
| `wt shell-hook --help` | ✅ | Printed usage for zsh/bash hook generation.
| `wt shell-hook zsh` | ✅ | Emitted wrapper function pointing at `/Users/notdp/Developer/worktree.sh/bin/wt`.
| `wt config` | ✅ | Printed full usage/keys table.
| `wt config list` | ⚠️ Expected refusal | Exits 1: `wt: This command must be run inside a configured project`.
| `wt config get repo.path` | ✅ | Returned default placeholder `/Users/notdp/Developer/your-project`.
| `wt config set language zh` | ⚠️ Expected refusal | Correctly refused because command requires project scope.
| `wt list` | ⚠️ Expected refusal | Prompted to run `wt init` since scope was unconfigured.
| `wt reinstall` | ✅ | Chained repo `uninstall.sh` and `install.sh`, refreshing `~/.local/bin` in place.
| `wt reinstall --help` | ✅ | Displayed usage text.
| `wt uninstall --help` | ✅ | Verified CLI help path without removing freshly installed binary.

### Project scope`~/developer/franxx.ai`

| Command | Result | Notes |
| --- | --- | --- |
| `wt init` | ✅ | Created project config `-Users-notdp-Developer-franxx-ai`; captured repo.path/main branch.
| `wt config list` | ✅ | Reflected stored defaults (language=en, add.* tuned for npm workflows).
| `wt config get language` | ✅ | Returned `en`.
| `wt config set language zh` → `wt config get language` | ✅ | Stored `zh` then confirmed.
| `wt config unset language` → `wt config get language` | ✅ | Restored effective language to default `en`.
| `wt config set add.install-deps.enabled false` | ✅ | Disabled auto `npm ci` for tests (restored later).
| `wt config set add.serve-dev.enabled false` | ✅ | Disabled dev server launch (restored later).
| `wt add franxx-ai-report` | ✅ | Created branch `feat/franxx-ai-report` at `/Users/notdp/Developer/franxx.ai.franxx-ai-report`; install/dev skipped per config.
| `wt list` | ✅ | Listed main and new worktree with hashes.
| `wt main` | ✅ | Returned main worktree path.
| `wt merge franxx-ai-report` | ⚠️ No-op | Reported no divergent commits to merge (expected for fresh branch).
| `wt rm franxx-ai-report` | ✅ | Deleted worktree and branch.
| `wt add 12345` | ✅ | Created numeric worktree for clean test.
| `wt clean` | ✅ | Removed numeric worktree (reported 1 cleaned).
| `wt add qa` | ✅ | Created another feature worktree `feat/qa`.
| `wt qa` | ✅ | Returned path to the qa worktree.
| `wt rm qa` | ✅ | Removed the qa worktree and branch.
| `wt config set add.install-deps.enabled true` | ✅ | Restored original setting.
| `wt config set add.serve-dev.enabled true` | ✅ | Restored original setting.
| `wt config list` (final) | ✅ | Confirmed config back to defaults; no lingering overrides.

### Project scope`~/developer/franxx.store`

| Command | Result | Notes |
| --- | --- | --- |
| `wt init` | ✅ | Created project config `-Users-notdp-Developer-franxx-store` with repo.path/main.
| `wt config list` | ✅ | Mirrored npm-focused defaults.
| `wt config set add.install-deps.enabled false` | ✅ | Disabled npm install step (restored later).
| `wt config set add.serve-dev.enabled false` | ✅ | Disabled dev server launch (restored later).
| `wt add franxx-store-report` | ✅ | Created branch `feat/franxx-store-report`; `.env.local` copy logged.
| `wt list` | ✅ | Enumerated main + new worktree.
| `wt main` | ✅ | Returned main worktree path.
| `wt franxx-store-report` | ✅ | Resolved direct jump to new worktree path.
| `wt merge franxx-store-report` | ⚠️ Expected refusal | Warned about uncommitted change in main (tracked modification retained); merge skipped with exit 0.
| `wt rm franxx-store-report` | ✅ | Removed worktree and branch cleanup succeeded.
| `wt clean` | ✅ | Reported no numeric worktrees to remove.
| `wt config repo.path` (shortcut) | ✅ | Returned stored path via implicit `get`.
| `wt config --stored repo.branch` | ✅ | Returned `main`.
| `wt config set add.install-deps.enabled true` | ✅ | Restored original setting.
| `wt config set add.serve-dev.enabled true` | ✅ | Restored original setting.
| `wt config list` (final) | ✅ | Confirmed defaults restored; no stray overrides.

## Observations & Follow-ups

- `wt config list` still rejects global use with `wt: This command must be run inside a configured project`; decide whether the CLI should print defaults instead or keep the guardrail.
- Multi-project shortcuts (`wt review`, `wt path review`, and piped `wt rm tempglobal`) now succeed from a non-interactive shell, matching the design doc.
- `wt add` in scratch repos without a lockfile requires disabling `add.install-deps.enabled`; once toggled, worktree lifecycle behaved as expected.
- All temporary worktrees/branches (`feat/franxx-ai-report`, `feat/12345`, `feat/qa`, `feat/franxx-store-report`, numeric 1111/9999) were removed; `git worktree list` returns to the pre-test set.
- Configuration toggles changed during testing were restored to their pre-test values to avoid persisting side effects.

## Artifacts

- `tests/report-raw.log` — full command transcripts with ANSI output preserved.
- `tests/report.md` (this file) — structured summary for reviewers.
