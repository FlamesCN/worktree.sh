# wt project-config manual tests (2025-09-24)

## Environment

- Location: macOS shell on /Users/notdp
- Global `wt` binary installed previously via `./install.sh --shell bash`
- Initial state: no `~/.worktree.sh` directory
- All commands executed with non-interactive stdin unless otherwise noted

## Scenario A: 0 projects configured (before running `wt init`)

- `wt help`
  - expected: show usage without project context
  - observed: help text plus "Project directory: not set" banner; exit 0
  - status: PASS
- `wt main`
  - expected: tell user to run `wt init`
  - observed: `wt: No projects are configured yet; run wt init inside a repository first`; exit 1
  - status: PASS
- `wt list`
  - expected: same error as above
  - observed: identical message; exit 1
  - status: PASS
- `wt add test-zero`
  - expected: refuse outside project
  - observed: `wt: This command must be run inside a configured project`; exit 1
  - status: PASS
- `wt path demo`
  - expected: refuse outside project
  - observed: `wt: No projects are configured yet; run wt init inside a repository first`; exit 1
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
  - observed: `wt: No projects are configured yet; run wt init inside a repository first`; exit 1
  - status: PASS

## Scenario B: 1 project configured (`wt init` at `/Users/notdp/Developer/worktree.sh`)

- `wt init`
  - expected: create project config and capture defaults
  - observed: created slug `Developer_worktree.sh__5f5ae0` under `~/.worktree.sh/projects`; exit 0
  - status: PASS
- `wt main` (run from `$HOME`)
  - expected: jump directly to the lone project
  - observed: printed `/Users/notdp/Developer/worktree.sh`; exit 0
  - status: PASS
- `wt list` (run from `$HOME`)
  - expected: list worktrees for this project
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
  - observed: key added to `~/.worktree.sh/projects/Developer_worktree.sh__5f5ae0/config.kv` then removed; exit 0
  - status: PASS
- `wt path review` (inside repo)
  - expected: jump to existing review worktree
  - observed: printed `/Users/notdp/Developer/worktree.sh.review`; exit 0
  - status: PASS

## Scenario C: ≥2 projects configured (added temporary git repo under `/private/var/.../tmp.4NI9HKllS9` and ran `wt init`)

- `wt main` (global, interactive TTY)
  - expected: arrow-key navigation with Enter confirmation
  - observed: menu rendered with highlight; ↑/↓ cycled between entries; Enter selected highlighted project and auto-cd via shell hook; exit 0
  - status: PASS
- `wt main` (global, piped numeric input)
  - expected: fallback to numeric prompt when stdin is not a TTY
  - observed: menu skipped straight to numeric prompt; piping `1` or `2` selected correct project; exit 0
  - status: PASS
- `wt list` (global)
  - expected: group worktrees by project
  - observed: two project headers with respective worktree listings; exit 0
  - status: PASS
- `wt list` (inside second project)
  - expected: single-project style output
  - observed: listed only that repo’s main worktree; exit 0
  - status: PASS
- `wt add demo` + `wt rm demo` (inside second project)
  - expected: create/remove worktree locally
  - observed: both succeeded; exit 0
  - status: PASS
- `wt clean` (global)
  - expected: enumerate numeric worktrees with confirmation
  - observed: initial pass reported "No numeric worktrees to clean" because no numeric suffixes existed; after seeding worktrees `1111`/`9999`, running from the global context presented prompts with `[Y/n]` and accepted bare Enter as confirmation, cleaning both entries; exit 0
  - status: PASS (confirmation branch now validated with default-yes behaviour)
- `wt path review` or `wt review` (global, multi-project)
  - expected: direct path output because only one match exists
  - observed: command exited 1 with no stdout/stderr output; prevents jumping to worktree
  - status: FAIL
- `printf 'y\n' | wt rm tempglobal` (global) after creating worktree in main repo
  - expected: prompt then remove matching worktree from selected project
  - observed: command exited 1 with no output; same worktree removed successfully when command run inside project instead
  - status: FAIL (still requires interactive TTY for confirmation; unchanged)

## Cleanup

- Removed temporary project config directory `~/.worktree.sh/projects/private_var_folders_pb_76qwb4pn5z1_l3fs1xnk8l000000gn_T_tmp.4NI9HKllS9__b88d10`
- Deleted temporary git repo at `/private/var/folders/pb/76qwb4pn5z1_l3fs1xnk8l000000gn/T/tmp.4NI9HKllS9`
- Restored environment to single-project state

## Outstanding Issues

- Global `wt path <name>` / bare `wt <name>` returned exit 1 with empty output when exactly one match existed (tested with `review`); behavior contradicts multi-project design doc
- Global `wt rm <name>` ignored piped confirmations (`printf 'y\n' | wt rm tempglobal`) and aborted with exit 1; in-project removal works, suggesting the global confirmation flow requires an interactive TTY
- Numeric worktree clean-up prompt path not exercised because repository lacked numeric-suffixed worktrees
- Need automated coverage for the new interactive selector (arrow navigation + Enter confirmation) to prevent regressions
