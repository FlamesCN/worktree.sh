# wt detach Command Design

## Goals
- Let users unregister a repository from wt without manual file surgery.
- Provide an interactive workflow to clean up wt-created worktrees before detaching.
- Keep behaviour consistent between in-repo (project scope) and global usage scenarios.

## Command Synopsis
```
wt detach [<slug>] [--force]
```
- In a repository that wt currently manages: `wt detach` resolves the slug automatically.
- Outside a managed repo: users pick a project from the registry list (same selector as `wt main`).
- `--force` (alias `-y`) skips *all* prompts and proceeds as if the user answered `Y` to each question.

## High-Level Flow
1. **Project Resolution**
   - Project scope: derive slug via `project_slug_for_path()` and verify the config directory exists.
   - Global scope: collect registry entries; if multiple projects, show selector; cancelling aborts the command.
2. **Worktree Enumeration**
   - Compute the set of wt-created worktrees for the project via `git worktree list --porcelain`.
   - Sort by creation order (list order) and exclude the main repository path.
3. **Iterative Cleanup**
   - For each worktree:
     - Prompt: `Remove worktree <path>? [Y/n]` (default `Y`).
     - `n/N`: stop immediately, mark command as aborted (`exit 1`). Already removed worktrees stay removed.
     - `Y` or empty input: attempt removal (`git worktree remove --force` + branch deletion).
       - Failure (e.g. dirty tree) → log `remove_failed` message, continue to next. Record in failure summary.
   - Keep track of the current directory; if it matches a removed worktree, remember to print the main repo path at exit.
4. **Detach Confirmation**
   - If the config directory still exists, prompt `Detach project <slug>? [Y/n]` unless `--force` was passed.
   - `n/N`: abort detach, leave config untouched; do not restore any previously removed worktrees.
   - `Y`/empty or `--force`: delete `~/.worktree.sh/projects/<slug>` recursively.
5. **Exit & Reporting**
   - Summaries:
     - Removed worktrees count.
     - Failed removals (with reasons).
     - Early abort notice when user answered `n` mid-way.
   - On success, print confirmation that the project is detached.
   - If we deleted the current worktree, emit the main repo path to trigger auto-cd.

## Options & Flags
- `--force`, `-y`: skip all prompts, assume `Y`. Continue even if worktree removals fail; still report failures.
- Future flags (not planned now) should use long-form `--foo` aliases to stay aligned with existing commands.

## Messages (bin/messages.sh)
New keys (with en/zh pairs):
- `detach_prompt_worktree`
- `detach_abort_user`
- `detach_remove_failed`
- `detach_summary_removed`
- `detach_summary_failed`
- `detach_prompt_project`
- `detach_done`
- `detach_project_missing`
- `detach_no_projects`
- `detach_summary_skipped` (for refused worktrees, if we want explicit logging)

Reuse existing `clean_switch_back` message for auto-cd hint if appropriate.

## Runtime Helpers (bin/lib/runtime.sh)
- `project_worktrees_for_slug slug array_name`: return arrays of worktree paths & branch suffixes.
- `project_remove_worktree path branch_suffix`: encapsulate removal + branch deletion.
- `project_detach slug force_flag`: orchestrate enumeration, prompting, deletion. Return codes:
  - `0` success;
  - `1` user aborted;
  - `2` failures occurred but detach completed (surface as success with warnings).

These helpers allow `commands.sh` to stay lean.

## Command Dispatch (bin/lib/commands.sh)
- Add `detach` to top-level routing alongside `add`, `rm`, etc.
- `cmd_detach()` handles argument parsing:
  - Validates `--force`/`-y`.
  - Accepts optional slug when in global scope.
  - Resolves project (auto or prompt) and invokes runtime helper.

## Documentation Updates
- README / README.zh-CN: add a short section under “Core commands” explaining `wt detach` and warning that dirty worktrees must be cleaned manually if removal fails.

## Manual Test Matrix
1. Project scope, clean state → detach removes config and worktrees.
2. Project scope, user answers `n` on second worktree → command aborts with partial removals.
3. Project scope, dirty worktree causes removal failure → detach continues, summary reports failure, config removal still occurs upon confirmation.
4. Global scope selection with multiple projects → correct project gets detached.
5. `--force` run: no prompts, best-effort removal, summary lists failures.
6. Current directory inside a detached worktree → tool prints main repo path for auto-cd.
7. Re-run `wt init` after detach → creates new config and warns about leftover worktrees if any remain.

## Open Questions / Future Enhancements
- Should we add `--dry-run` to preview removals? (Out of scope for now.)
- Consider logging detach operations to a history file for auditability.
