# wt project-config manual tests (2025-09-24)

## Environment

- Location: macOS shell on /Users/notdp
- Global `wt` binary installed previously via `./install.sh --shell bash`
- Initial state: no `~/.worktree.sh` directory
- All commands executed with non-interactive stdin unless otherwise noted

## Scenario A: 0 projects configured (before running `wt init`)

- `wt`
  - expected: refuse because no project is configured yet
  - observed: `wt: wt is not configured yet; run "wt init" inside your repository first`; exit 1
  - status: PASS
- `wt help`
  - expected: show usage without project context
  - observed: help text plus "Project directory: not set" banner; exit 0
  - status: PASS
- `wt main`
  - expected: tell user to run `wt init`
  - observed: `wt: wt is not configured yet; run "wt init" inside your repository first`; exit 1
  - status: PASS
- `wt list`
  - expected: same error as above
  - observed: `wt: wt is not configured yet; run "wt init" inside your repository first`; exit 1
  - status: PASS
- `wt add test-zero`
  - expected: refuse outside project
  - observed: `wt: This command must be run inside a configured project`; exit 1
  - status: PASS
- `wt path demo`
  - expected: refuse outside project
  - observed: `wt: wt is not configured yet; run "wt init" inside your repository first`; exit 1
  - status: PASS
- `wt config set language zh`
  - expected: refuse outside project scope
  - observed: `wt: This command must be run inside a configured project`; exit 1
  - status: PASS
- `wt merge demo`
  - expected: refuse outside project
  - observed: `wt: This command must be run inside a configured project`; exit 1
  - status: PASS
- `wt clean`
  - expected: refuse outside project
  - observed: `wt: wt is not configured yet; run "wt init" inside your repository first`; exit 1
  - status: PASS

## Scenario B: 1 project configured (`wt init` at `/Users/notdp/Developer/worktree.sh`)

- `wt init`
  - expected: create project config and capture defaults
  - observed: created slug `-Users-notdp-Developer-worktree-sh` under `~/.worktree.sh/projects`; exit 0
  - status: PASS
- `wt main` (run from `$HOME`)
  - expected: jump directly to the lone project
  - observed: printed `/Users/notdp/Developer/worktree.sh`; exit 0
  - status: PASS
- `wt` (run from `$HOME`)
  - expected: list worktrees for this project (alias of `wt list`)
  - observed: printed project header plus existing worktrees; exit 0
  - status: PASS (note: header still shown even in single-project mode)
- `wt add testone` (run inside repo)
  - expected: create worktree and auto-cd path output
  - observed: created directory `.testone`, branch `feat/testone`; exit 0
  - status: PASS
- `wt path testone` (inside repo)
  - expected: print absolute path
  - observed: path printed; exit 0
  - status: PASS
- `wt rm testone` (inside repo)
  - expected: remove worktree and branch
  - observed: removal messages; exit 0
  - status: PASS
- `wt add tempcurrent` followed by `printf 'y\n' | wt rm` from inside that worktree
  - expected: prompt then remove current worktree and print main path
  - observed: prompt consumed, removal succeeded, printed main repo path; exit 0
  - status: PASS
- `wt config set test.foo bar` / `wt config unset test.foo`
  - expected: mutate project config file
  - observed: key added to `~/.worktree.sh/projects/-Users-notdp-Developer-worktree-sh/config.kv` then removed; exit 0
  - status: PASS
- `wt path review` (inside repo)
  - expected: jump to existing review worktree
  - observed: printed `/Users/notdp/Developer/worktree.sh.review`; exit 0
  - status: PASS

## Scenario C: ≥2 projects configured (added temporary git repo under `/private/var/.../tmp.g7V0WOcYkE` and ran `wt init`)

- `wt main` (global, no input)
  - expected: cancel selection when the user submits nothing
  - observed: printed project menu then aborted with `wt: Project selection cancelled`; exit 1
  - status: PASS
- `wt main` (global, piped numeric input)
  - expected: fallback to numeric prompt when stdin is not a TTY
  - observed: menu rendered with two entries; piping `2` returned `/Users/notdp/Developer/worktree.sh`; exit 0
  - status: PASS
- `wt list` (global)
  - expected: group worktrees by project
  - observed: printed headers for `tmp.g7V0WOcYkE` and `worktree.sh` with their worktrees; exit 0
  - status: PASS
- `wt list` (inside second project)
  - expected: single-project style output
  - observed: listed only that repo’s main worktree; exit 0
  - status: PASS
- `wt add demo` + `wt rm demo` (inside second project)
  - expected: create/remove worktree locally
  - observed: dependency install was skipped automatically because no lockfile existed; worktree creation and cleanup both succeeded; exit 0
  - status: PASS
- `wt clean` (global)
  - expected: enumerate numeric worktrees with confirmation
  - observed: prompts surfaced for `1111`, existing `11222`, and `9999`; piped `y` responses removed each and reported totals; exit 0
  - status: PASS
- `wt path review` / `wt review` (global, multi-project)
  - expected: direct path output because only one match exists
  - observed: both commands returned `/Users/notdp/Developer/worktree.sh.review`; exit 0
  - status: PASS
- `printf 'y\n' | wt rm tempglobal` (global) after creating worktree in main repo
  - expected: prompt then remove matching worktree from selected project
  - observed: confirmation accepted from piped stdin and worktree removed successfully; exit 0
  - status: PASS

## Scenario D: Branch prefix fallback when the configured prefix collides

- `wt config set add.branch-prefix feature/`
  - expected: override the default branch prefix for new worktrees
  - observed: configuration updated in the project file; exit 0
  - status: PASS
- `git branch feature` (run inside `/Users/notdp/Developer/worktree.sh` main repo)
  - expected: create a branch that will collide with the configured prefix
  - observed: branch `feature` created; exit 0
  - status: PASS
- `wt add prefix-fallback`
  - expected: CLI reports that `feature` already exists and falls back to `ft/` before creating the worktree and branch
  - observed: warning mentions fallback to `ft/`, worktree `/Users/notdp/Developer/worktree.sh.prefix-fallback` created with branch `ft/prefix-fallback`; exit 0
  - status: PASS
- `wt rm prefix-fallback`
  - expected: remove worktree and delete branch `ft/prefix-fallback`
  - observed: removal succeeded, branch deletion logged; exit 0
  - status: PASS
- `git branch -D feature`
  - expected: clean up the temporary `feature` branch
  - observed: branch deleted; exit 0
  - status: PASS
- `wt config unset add.branch-prefix`
  - expected: restore the default prefix (`feat/`)
  - observed: key removed from the project config; exit 0
  - status: PASS

## Cleanup

- Removed temporary project config directory `~/.worktree.sh/projects/-private-var-folders-pb-76qwb4pn5z1-l3fs1xnk8l000000gn-T-tmp-g7V0WOcYkE`
- Deleted temporary git repo at `/private/var/folders/pb/76qwb4pn5z1_l3fs1xnk8l000000gn/T/tmp.g7V0WOcYkE`
- Restored environment to single-project state

## Outstanding Issues

- `wt add` now skips dependency installation when no Node.js lockfile exists, so scratch repos no longer require toggling `add.install-deps` to avoid `npm ci` failures.
- Non-interactive runs still cannot validate the arrow-key selector path; manual coverage recommended before release candidates.
