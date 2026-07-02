#!/usr/bin/env bash
# claude-worktree — launcher used by cwt as $GWT_EDITOR (via --jira-workflow / -jw).
#
# Convention (the only coupling between this script and the jira-workflow
# skills): the worktree directory name IS the Jira ticket key (e.g. PROJ-123).
# `cwt PROJ-123` creates ./PROJ-123 as branch + worktree name, and this
# launcher passes that basename to /jira-workflow:orchestrator as the ticket.
# If you create a worktree with a non-ticket name, the orchestrator will
# receive a bogus key — use the default editor instead in that case.
#
# Starts Claude Code with the jira-workflow orchestrator pre-invoked on the
# ticket inferred from the worktree directory name.
#
# Usage (called by git-worktrees.sh):
#   claude-worktree <path>
# When launched in a kitty tab, the script invokes "$editor ." with cwd
# already set to the worktree, so "." is the expected arg there.

set -euo pipefail

target="${1:-.}"

# Resolve to an absolute path so basename gives the worktree name even
# when invoked as `claude-worktree .` from inside the worktree.
if [[ -d "$target" ]]; then
  target="$(cd "$target" && pwd)"
else
  printf 'claude-worktree: not a directory: %s\n' "$target" >&2
  exit 1
fi

ticket="$(basename "$target")"

cd "$target"
exec claude "/jira-workflow:orchestrator $ticket — drive the full workflow end-to-end until a PR is opened. FIRST, before any planning or implementation, run 'git pull origin main' to sync this branch with the latest origin main, and resolve any merge conflicts. THEN proceed: create-plan, create-implementation-plan, create-testing-plan, then implementation, testing, review. FINALLY, before pushing and opening the PR, run 'git pull origin main' again and resolve any merge conflicts that arose while you worked. Do not stop after planning."
