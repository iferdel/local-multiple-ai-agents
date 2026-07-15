#!/usr/bin/env bash
# copilot-worktree — launcher used by cwt as $GWT_EDITOR (via --copilot-workflow / -ghc).
#
# Homologous to claude-worktree.sh, but starts GitHub Copilot CLI instead of
# Claude Code. Same convention: the worktree directory name IS the ticket key
# (e.g. PROJ-123). `cwt -ghc PROJ-123` creates ./PROJ-123 as branch + worktree
# name, and this launcher passes that basename to the workflow orchestrator.
#
# Copilot has no plugin slash-commands, so the prompt drives the workflow
# skills by name. If the target repo commits the backend-neutral skills at
# .github/skills/ (orchestrator + the skills it routes to), the prompt points
# Copilot at those files; otherwise it falls back to the globally-installed
# spec-workflow skills (see claude-code-skills install). The tracker backend
# (jira / local) is resolved by the skills themselves from
# .spec-workflow/config.json — with `backend: "local"` the whole run needs no MCP.
#
# Uses the `copilot` binary if on PATH, else falls back to `gh copilot --`
# (which downloads/runs it). Extra CLI flags via $GWT_COPILOT_FLAGS
# (default: --allow-all-tools, needed for an unattended drive-to-PR run).
#
# Usage (called by git-worktrees.sh):
#   copilot-worktree <path>

set -euo pipefail

target="${1:-.}"

if [[ -d "$target" ]]; then
  target="$(cd "$target" && pwd)"
else
  printf 'copilot-worktree: not a directory: %s\n' "$target" >&2
  exit 1
fi

ticket="$(basename "$target")"

cd "$target"

skill=".github/skills/orchestrator/SKILL.md"
if [[ -f "$skill" ]]; then
  prompt="Read $skill and execute it as your instructions for ticket $ticket — drive the full workflow end-to-end until a PR is opened. FIRST, before any planning or implementation, run 'git pull origin main' to sync this branch with the latest origin main, and resolve any merge conflicts. THEN proceed through the full lifecycle: create-plan, create-implementation-plan, create-testing-plan, plan-implementation, development, testing, reviewing (each is a sibling skill under .github/skills/ — read each SKILL.md before executing it). FINALLY, before pushing and opening the PR, run 'git pull origin main' again and resolve any merge conflicts that arose while you worked. Do not stop after planning."
else
  prompt="Use your installed spec-workflow skills to drive ticket $ticket end-to-end until a PR is opened. Start with the 'orchestrator' skill, then run each lifecycle skill in sequence: create-plan, create-implementation-plan, create-testing-plan, plan-implementation, development, testing, reviewing. FIRST, before any planning or implementation, run 'git pull origin main' to sync this branch with the latest origin main, and resolve any merge conflicts. FINALLY, before pushing and opening the PR, run 'git pull origin main' again and resolve any merge conflicts that arose while you worked. Do not stop after planning."
fi

flags="${GWT_COPILOT_FLAGS:---allow-all-tools}"

if command -v copilot >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  exec copilot $flags -p "$prompt"
else
  # shellcheck disable=SC2086
  exec gh copilot -- $flags -p "$prompt"
fi
