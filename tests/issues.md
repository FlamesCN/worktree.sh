> Test Results

- Replayed tests/test.md scenarios on 2025-09-24: zero-project guard rails still behave, single-project flows (wt add/rm, piped confirmation, config mutate) all pass, and multi-
  project coverage confirms numeric clean works when piping newlines; persistent regressions remain for global wt path review and non-TTY wt rm tempglobal (both exit 1 with no
  output). Interactive arrow navigation couldn’t be exercised in this non-TTY shell.
- Followed tests/report.md after reinstalling via ./uninstall.sh and ./install.sh --shell bash; global smoke checks succeed except wt config list now exits 1 with no message when
  no project is configured, and invoking the installed wt reinstall still fails to locate ~/.local/uninstall.sh (running ./bin/wt reinstall succeeds).
- Project flows for ~/Developer/franxx.ai and ~/Developer/franxx.store match the report: init, config toggles, worktree CRUD, merge guardrails, and numeric clean all pass; no stray
  worktrees left behind and project configs restored to defaults (language left at en for franxx.ai as before). Re-added Developer_worktree.sh__5f5ae0 so the ~/.worktree.sh/projects
  set matches the pre-test state.

  Notable Findings

- wt config list outside any project now exits 1 silently; the report expected a graceful “no stored values” success.
- Installed wt reinstall still searches $prefix for scripts and aborts; only ./bin/wt reinstall currently works.
- Global wt path <name>/wt <name> and non-TTY wt rm <name> remain broken in multi-project mode, consistent with the previous outstanding issues.

  Next Steps

  1. Decide whether to patch wt reinstall so the installed binary can locate checkout scripts (or adjust docs accordingly).
  2. Investigate the regression in wt config list when no projects exist.
  3. Prioritize fixes for the multi-project shortcuts (wt path/bare name jump and piped confirmations) before the next manual test cycle.
