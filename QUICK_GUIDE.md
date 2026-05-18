# Git Worktree Helper - Quick Reference

**Fast setup and daily-use cheat sheet** | Full details: [README.md](README.md)

---

## Quick Setup (3 Steps)

```bash
# 1. Source the script in your shell config (~/.bashrc or ~/.zshrc)
echo 'source ~/path/to/git-worktrees.sh' >> ~/.zshrc

# 2. Reload your shell
source ~/.zshrc

# 3. Configure per-project (optional)
cat > .git-worktree-config <<EOF
EDITOR=nvimf
COPY_FILES=.env,.env.local
COPY_DIRS=.claude,.instrumental
AUTO_OPEN=true
EOF
```

**Requirements:** Git 2.5+ | Bash 4.0+ or Zsh 5.0+ | Optional: fzf

---

## Command Cheat Sheet

| Command | What It Does | Most Common Usage |
|---------|--------------|-------------------|
| **cwt** | Create worktree | `cwt feature-name` |
| **dwt** | Delete worktree | `dwt` (run from inside worktree) |
| **lwt** | List worktrees | `lwt` |
| **swt** | Switch worktree | `swt` (interactive) or `swt name` |
| **uwt** | Update worktrees | `uwt -a` (update all) |

---

## Essential Command Patterns

### cwt - Create Worktree
```bash
cwt feature-login              # Create new branch + worktree (opens in new kitty tab)
cwt -e main                    # Checkout existing branch
cwt -e origin/hotfix-123       # Checkout remote branch
cwt -n experiment              # Create without opening editor
cwt --embed feature-login      # Open editor inline in current terminal
```

**Auto-copies:** .env, .claude, .instrumental directories to new worktree

**Editor launch:** when running inside kitty (detected via `$KITTY_WINDOW_ID`), `cwt`
opens `nvimf` in a new kitty tab so you don't end up with Neovim-inside-Neovim.
Use `--embed` to force inline launch in the current terminal. Outside kitty,
the editor launches inline by default. Requires `allow_remote_control yes` in
`kitty.conf`.

### dwt - Delete Worktree
```bash
cd ../project-worktrees/feature-name
dwt                            # Interactive (shows changes)
dwt -f                         # Force delete (no prompts)
```

**Safety:** Detects uncommitted changes, prevents deleting branches in other worktrees

### lwt - List Worktrees
```bash
lwt                            # Shows: path, branch, status, last commit
```

**Output:** `[CURRENT]` marker, `[CLEAN]`/`[DIRTY]` status

### swt - Switch Worktrees
```bash
swt                            # Interactive (fzf or numbered menu)
swt feature                    # Direct switch (partial match)
swt -p                         # Print path only
cd $(swt -p)                   # Change directory to selection
```

**Uses fzf** if installed for fuzzy search

### uwt - Update Worktrees
```bash
uwt                            # Interactive (choose which to update)
uwt -a                         # Update all (skip dirty)
uwt -a -f                      # Update all (even dirty - careful!)
```

**Shows:** Behind/ahead status, only updates fast-forward-safe branches

---

## Common Workflows

### 1. Feature Development
```bash
cwt feature-dashboard          # Create + open in editor
# ... work, commit ...
swt main                       # Quick switch to main
cwt -e main hotfix-bug         # Emergency hotfix
dwt                            # Clean up when done
```

### 2. Code Review
```bash
cwt -e origin/pr-branch        # Review PR in isolation
# ... test, review ...
dwt -f                         # Quick cleanup
swt feature-mine               # Back to your work
```

### 3. Multi-Version Testing
```bash
cwt -e main                    # Production
cwt -e develop                 # Staging
cwt my-feature                 # Your work
lwt                            # See all at once
```

### 4. Daily Sync
```bash
uwt -a                         # Update all worktrees
lwt                            # Check status
```

---

## Key Config Options

**File:** `.git-worktree-config` (in repo root)

```bash
EDITOR=nvimf                               # code, vim, nvim, nvimf
COPY_FILES=.env,.env.local                 # Comma-separated
COPY_DIRS=.claude,.instrumental            # Comma-separated
AUTO_OPEN=true                             # false to disable
```

**No config?** Defaults work fine (nvimf editor, copies .env)

---

## Quick Troubleshooting

| Problem | One-Line Fix |
|---------|-------------|
| "Editor not found" | Set `EDITOR=vim` in `.git-worktree-config` |
| "Branch already exists" | Use `cwt -e branch-name` instead |
| "Not in worktree" (dwt) | Must run `dwt` from inside a worktree directory |
| Stale worktree registry | `git worktree prune` |
| Config not loading | Check file is in repo root, format is `KEY=value` (no spaces) |
| Can't update (dirty) | Commit/stash changes or use `uwt -f` |

---

## Flags Quick Reference

### cwt
- `-e, --existing` - Use existing branch
- `-n, --no-open` - Don't open editor
- `--embed` - Open editor inline (same terminal) instead of new kitty tab
- `-h, --help` - Show help

### dwt
- `-f, --force` - Skip confirmations
- `-h, --help` - Show help

### swt
- `-p, --print` - Print path only
- `-h, --help` - Show help

### uwt
- `-a, --all` - Update all without prompting
- `-f, --force` - Update even with uncommitted changes
- `-h, --help` - Show help

---

## Tips & Tricks

**Shell Integration:**
```bash
alias wt='swt'                             # Quick switch
alias wtl='lwt'                            # Quick list
alias wtcd='cd $(swt -p)'                  # CD to worktree
```

**Clean Up All:**
```bash
# List all, then delete unwanted
lwt
cd ../project-worktrees/old-feature && dwt -f
```

**Batch Operations:**
```bash
for wt in feature-*; do
  cd ../project-worktrees/$wt && git pull
done
```

**Use with fzf:**
```bash
brew install fzf                           # Better swt experience
```

---

## When Things Go Wrong

```bash
# Verify you're in a git repo
git status

# Check worktree list
git worktree list

# Prune dead worktrees
git worktree prune

# Force remove stuck worktree
git worktree remove path/to/worktree --force

# Manual cleanup
rm -rf path/to/worktree
git worktree prune
```

---

## Performance Note

All commands are **instant** for typical repos. Large repos (1000+ files):
- `cwt`: ~2-5 seconds (includes file copying)
- `dwt`: ~1 second
- `lwt`: <1 second
- `swt`: <1 second
- `uwt`: Depends on network (fetch operation)

---

**Need more details?** See [README.md](README.md) for comprehensive documentation, security features, examples, and advanced usage.

**Get help anytime:** Run any command with `--help` flag
