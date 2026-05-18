# Git Worktree Helper Script

> A comprehensive, secure toolkit for managing Git worktrees with safety and ease.

[![Shell Support](https://img.shields.io/badge/shell-bash%204.0%2B%20%7C%20zsh%205.0%2B-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
  - [cwt - Create Worktree](#cwt---create-worktree)
  - [dwt - Delete Worktree](#dwt---delete-worktree)
  - [lwt - List Worktrees](#lwt---list-worktrees)
  - [swt - Switch Worktrees](#swt---switch-worktrees)
  - [uwt - Update Worktrees](#uwt---update-worktrees)
- [Security Features](#security-features)
- [Shell Compatibility](#shell-compatibility)
- [Real-World Examples](#real-world-examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

The Git Worktree Helper Script provides a suite of powerful commands (`cwt`, `dwt`, `lwt`, `swt`, `uwt`) that simplify the creation, deletion, listing, switching, and updating of Git worktrees. It's designed with security, cross-shell compatibility, and user experience in mind.

**What are Git Worktrees?**
Git worktrees allow you to have multiple working directories (worktrees) attached to a single repository. This enables you to work on different branches simultaneously without constantly switching contexts or maintaining multiple repository clones.

**Why use this script?**
- 🚀 Simplified worktree management with intuitive commands
- 🔒 Built-in security with input validation and sanitization
- 🔄 Automatic configuration file copying (.env, .claude, etc.)
- 🎯 Interactive and scriptable modes
- 🛡️ Safe deletion with uncommitted change detection
- 📊 Rich status information and tracking
- 🔀 Cross-shell compatibility (bash/zsh)

---

## Features

✨ **Core Functionality**
- Create worktrees with new or existing branches
- Delete worktrees with safety checks and cleanup
- List all worktrees with detailed status information
- Switch between worktrees interactively or directly
- Update/pull multiple worktrees efficiently

📦 **Automation**
- Automatic editor opening (configurable)
- Configuration file copying (`.env`, `.claude`, `.instrumental`, etc.)
- Remote tracking and sync status checking
- Uncommitted change detection

⚙️ **Configuration**
- Project-level configuration via `.git-worktree-config`
- Environment variable support
- Customizable editor, file copying, and directory copying

🛡️ **Security**
- Comprehensive input validation
- Command injection prevention
- Path traversal protection
- Safe cleanup on failures

---

## Requirements

### Prerequisites

- **Git**: Version 2.5+ (for worktree support)
- **Shell**: bash 4.0+ or zsh 5.0+
- **Optional**: `fzf` for enhanced interactive selection in `swt` command

### System Requirements

- macOS, Linux, or Unix-like system
- Basic command-line utilities: `git`, `mkdir`, `cp`, `rm`, `find`

---

## Installation

### Method 1: Source in Shell Configuration

1. **Download or clone the script:**
   ```bash
   cd ~/scripts  # or your preferred location
   curl -O https://raw.githubusercontent.com/yourusername/git-worktree-helper/main/git-worktrees.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x git-worktrees.sh
   ```

3. **Source it in your shell configuration:**

   **For bash** (`~/.bashrc` or `~/.bash_profile`):
   ```bash
   source ~/scripts/git-worktrees.sh
   ```

   **For zsh** (`~/.zshrc`):
   ```bash
   source ~/scripts/git-worktrees.sh
   ```

4. **Reload your shell:**
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

### Method 2: Add to PATH

1. **Move the script to a directory in your PATH:**
   ```bash
   sudo cp git-worktrees.sh /usr/local/bin/git-worktrees
   sudo chmod +x /usr/local/bin/git-worktrees
   ```

2. **Source it in your shell configuration:**
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   source /usr/local/bin/git-worktrees
   ```

### Verify Installation

Test that the commands are available:
```bash
cwt --help
lwt --help
```

---

## Configuration

### Configuration File: `.git-worktree-config`

Create a `.git-worktree-config` file in your repository root to customize the script's behavior for that specific project.

#### Configuration File Location

```
your-repo/
├── .git/
├── .git-worktree-config    ← Place config here
└── ... (other files)
```

#### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `EDITOR` | string | `nvimf` | Editor command to open worktrees |
| `COPY_FILES` | comma-separated | `.env` | Files to copy into new worktrees |
| `COPY_DIRS` | comma-separated | `.instrumental,.claude` | Directories to copy into new worktrees |
| `AUTO_OPEN` | boolean | `true` | Automatically open worktrees in editor |
| `WORKTREE_PATH` | string | `(empty)` | Custom worktree directory pattern |

#### Configuration File Example

Create `.git-worktree-config` in your repository root:

```bash
# Git Worktree Configuration

# Editor to use (e.g., code, vim, nvim, nvimf)
EDITOR=nvimf

# Comma-separated list of files to copy into new worktrees
# Common examples: .env, .env.local, config.json
COPY_FILES=.env,.env.local,.npmrc

# Comma-separated list of directories to copy into new worktrees
# Common examples: .claude, .instrumental, .vscode, .idea
COPY_DIRS=.instrumental,.claude

# Automatically open worktree in editor after creation (true/false)
AUTO_OPEN=true

# Custom worktree path pattern (leave empty for default)
# Default pattern: <parent-dir>/<project-name>-worktrees/<branch-name>
WORKTREE_PATH=
```

#### Configuration Validation

The script validates all configuration values to prevent security issues:
- **EDITOR**: Checked for shell metacharacters and command injection patterns
- **COPY_FILES/COPY_DIRS**: Validated for safe characters only
- **AUTO_OPEN**: Must be `true`, `false`, `yes`, `no`, `1`, or `0`
- **WORKTREE_PATH**: Checked for path traversal and injection attempts

**Security Note:** If invalid characters are detected, the script falls back to safe defaults and displays a warning.

---

## Commands

### `cwt` - Create Worktree

Create a new git worktree with a new or existing branch.

#### Synopsis

```bash
cwt [OPTIONS] <feature-name>
```

#### Options

| Option | Description |
|--------|-------------|
| `-e, --existing` | Checkout an existing branch instead of creating a new one |
| `-n, --no-open` | Skip opening the worktree in editor |
| `--embed` | Open editor inline (same terminal) instead of new kitty tab |
| `-h, --help` | Show help message |

#### Behavior

1. **Validates** the feature/branch name for safety
2. **Creates** worktree directory at `<parent>/<project>-worktrees/<feature-name>`
3. **Creates or checks out** the specified branch
4. **Copies** configured files and directories (`.env`, `.claude`, etc.)
5. **Opens** the worktree in your configured editor (unless `-n` is used)

##### Editor launch behavior (Neovim + Kitty)

The default editor is `nvimf` (a Neovim wrapper). Because launching a TUI editor
inside another terminal-embedded editor would nest Neovim-in-Neovim, `cwt` detects
when it's running inside [Kitty](https://sw.kovidgoyal.net/kitty/) (via
`$KITTY_WINDOW_ID`) and opens the editor in a **new Kitty tab** by default. This
keeps your current shell free and gives each worktree its own tab titled after
the feature name.

- Outside Kitty: editor launches inline in the current terminal (same as upstream).
- Inside Kitty: a new tab is opened via `kitten @ launch --type=tab --cwd <worktree> <editor> .`.
- Pass `--embed` to force inline launch regardless of terminal.
- If the Kitty remote-control call fails, `cwt` falls back to inline launch.

**Requirement:** for Kitty tab spawning, your `kitty.conf` must include:
```conf
allow_remote_control yes
listen_on unix:/tmp/kitty
```

#### Examples

**Create a new branch and worktree:**
```bash
cwt feature-123
# Creates branch "feature-123" and worktree at:
# ../my-project-worktrees/feature-123/
```

**Checkout an existing local branch:**
```bash
cwt -e main
# Checks out existing "main" branch in a new worktree
```

**Checkout a remote branch:**
```bash
cwt -e origin/hotfix-456
# Checks out remote branch "origin/hotfix-456"
# Creates local tracking branch "hotfix-456"
```

**Create worktree without opening editor:**
```bash
cwt -n testing
# Creates worktree but doesn't launch editor
# Useful for scripting or batch operations
```

**Open editor inline instead of new kitty tab:**
```bash
cwt --embed feature-123
# Launches nvimf in the current terminal instead of spawning a new kitty tab
```

**Complex feature branch:**
```bash
cwt feature/user-authentication
# Branch name: feature/user-authentication
# Worktree: ../my-project-worktrees/feature/user-authentication/
```

#### Input Validation

The script validates branch names to prevent issues:
- ❌ No spaces
- ❌ No shell metacharacters (`$`, `` ` ``, `|`, `&`, `;`, `<`, `>`)
- ❌ No git ref special characters (`~`, `^`, `:`, `?`, `*`, `[`)
- ❌ No path traversal (`../`)
- ❌ Cannot start with `.` or end with `.lock`
- ❌ Cannot end with `.` or `/`
- ❌ No double slashes (`//`) or `@{` sequences

#### Error Handling

The script includes robust error handling:
- **Cleanup on failure**: Removes partial worktrees and branches if creation fails
- **Branch conflict detection**: Warns if branch already exists (local or remote)
- **Path conflict detection**: Prevents overwriting existing worktrees

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GWT_EDITOR` | `nvimf` | Editor to launch |
| `GWT_COPY_FILES` | `.env` | Files to copy |
| `GWT_COPY_DIRS` | `.instrumental,.claude` | Directories to copy |
| `GWT_AUTO_OPEN` | `true` | Auto-open in editor |

---

### `dwt` - Delete Worktree

Delete the current git worktree and optionally its associated branch.

#### Synopsis

```bash
dwt [OPTIONS]
```

#### Options

| Option | Description |
|--------|-------------|
| `-f, --force` | Skip all confirmations (for scripting) |
| `-h, --help` | Show help message |

#### Behavior

1. **Verifies** you're inside a worktree (not the main repository)
2. **Displays** worktree information (path, branch, file count, uncommitted changes)
3. **Prompts** for confirmation (unless `-f` is used)
4. **Removes** the worktree
5. **Optionally deletes** the associated branch
6. **Prevents** deletion of branches checked out in other worktrees

#### Examples

**Interactive deletion:**
```bash
cd ../my-project-worktrees/feature-123
dwt
# Shows worktree details
# Prompts: "Delete this worktree? [y/N]:"
# If yes, prompts: "Delete branch 'feature-123' too? [y/N]:"
```

**Force deletion (no prompts):**
```bash
dwt -f
# Immediately deletes worktree
# Automatically deletes associated branch
# Useful for automation/scripts
```

#### Safety Features

**Uncommitted Changes Detection:**
The script detects and displays:
- Modified files
- Staged files
- Untracked files

**Branch Protection:**
- Refuses to delete branches that are checked out in other worktrees
- Shows clear warnings when uncommitted changes exist

**Example Output:**
```
Worktree: feature-login
Path:     /Users/user/projects/app-worktrees/feature-login
Main repo: /Users/user/projects/app
Branch:   feature-login
Files:    47

UNCOMMITTED CHANGES DETECTED:
   Modified files: 3
   Staged files: 1
   Untracked files: 2

Delete this worktree? [y/N]:
```

#### Lock File Handling

If a `index.lock` file is detected after deletion, the script:
- Reports the lock file location
- Attempts to list processes holding the lock (using `lsof`)
- Provides instructions for manual removal if it's stale

---

### `lwt` - List Worktrees

List all git worktrees with detailed information.

#### Synopsis

```bash
lwt [OPTIONS]
```

#### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |

#### Output Information

For each worktree, displays:
- 📁 **Name** (with `[CURRENT]` marker)
- 📍 **Path** (absolute path to worktree)
- 🌿 **Branch** (or detached HEAD info)
- ✅ **Status** (`[CLEAN]` or `[DIRTY]`)
- 💬 **Last commit** (message, author, relative time)

#### Examples

**Basic listing:**
```bash
lwt
```

**Example Output:**
```
==========================================================================
  GIT WORKTREES
==========================================================================

[CURRENT] feature-login
   Path:   /Users/user/projects/app-worktrees/feature-login
   Branch: feature-login
   Status: [DIRTY] dirty
   Commit: Add login form validation
           by John Doe, 2 hours ago

  main
   Path:   /Users/user/projects/app
   Branch: main
   Status: [CLEAN] clean
   Commit: Merge pull request #42
           by Jane Smith, 1 day ago

  hotfix-security
   Path:   /Users/user/projects/app-worktrees/hotfix-security
   Branch: hotfix-security
   Status: [CLEAN] clean
   Commit: Fix XSS vulnerability in search
           by Security Team, 3 hours ago

==========================================================================
```

#### Status Indicators

| Indicator | Meaning |
|-----------|---------|
| `[CURRENT]` | You are currently in this worktree |
| `[CLEAN]` | No uncommitted changes |
| `[DIRTY]` | Has uncommitted changes (modified, staged, or untracked files) |

#### Use Cases

- Quick overview of all active worktrees
- Check which branches are checked out
- Identify worktrees with uncommitted changes
- Find the path to a specific worktree

---

### `swt` - Switch Worktrees

Switch between git worktrees interactively or directly.

#### Synopsis

```bash
swt [OPTIONS] [worktree-name]
```

#### Options

| Option | Description |
|--------|-------------|
| `-p, --print` | Print the worktree path instead of opening editor |
| `-h, --help` | Show help message |

#### Behavior

**Interactive Mode** (no worktree-name provided):
- Uses `fzf` for fuzzy searching (if available)
- Falls back to numbered menu selection
- Displays all worktrees with branch names

**Direct Mode** (worktree-name provided):
- Matches against worktree names and branch names
- Opens the first match in your editor

**Print Mode** (`-p` flag):
- Prints the selected worktree path to stdout
- Useful for shell integration: `cd $(swt -p)`

#### Examples

**Interactive selection with fzf:**
```bash
swt
# Opens fzf interface
# Type to filter worktrees
# Press Enter to select
```

**Interactive selection without fzf:**
```bash
swt
# Output:
# Available worktrees:
#
#   1) main [main] (current)
#   2) feature-login [feature-login]
#   3) hotfix-bug [hotfix/bug-fix]
#
# Select worktree (1-3): 2
# Opening feature-login in nvimf...
```

**Direct selection:**
```bash
swt feature-login
# Directly opens the "feature-login" worktree
```

**Partial matching:**
```bash
swt login
# Matches "feature-login" worktree and opens it
```

**Print path for cd:**
```bash
cd $(swt -p)
# Interactive selection, then changes directory
```

**Combined with other commands:**
```bash
# Open in specific editor
code $(swt -p feature)

# Run command in worktree
git -C $(swt -p main) log --oneline -5
```

#### Interactive Selection with fzf

If `fzf` is installed, `swt` provides an enhanced selection experience:
- Fuzzy search through worktree names and branches
- Real-time filtering as you type
- Navigation with arrow keys
- Press `Enter` to select, `Esc` to cancel

**Installing fzf:**
```bash
# macOS
brew install fzf

# Linux
sudo apt-get install fzf  # Debian/Ubuntu
sudo dnf install fzf      # Fedora
```

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GWT_EDITOR` | `nvimf` | Editor to open worktree in |

---

### `uwt` - Update Worktrees

Update/pull git worktrees with remote tracking status.

#### Synopsis

```bash
uwt [OPTIONS]
```

#### Options

| Option | Description |
|--------|-------------|
| `-a, --all` | Update all worktrees without prompting |
| `-f, --force` | Update worktrees even with uncommitted changes |
| `-h, --help` | Show help message |

#### Behavior

1. **Fetches** latest changes from remote
2. **Analyzes** all worktrees for:
   - Remote tracking status (behind, ahead, up-to-date, diverged)
   - Uncommitted changes
3. **Displays** status summary for each worktree
4. **Prompts** which worktrees to update (unless `-a` is used)
5. **Updates** eligible worktrees using `git pull --ff-only`
6. **Displays** update summary (updated, failed, skipped)

#### Examples

**Interactive mode (default):**
```bash
uwt
# Output:
# Fetching latest from remote...
#
# Worktree Status:
# =================================================================
# 1. [OK] main [main] - up-to-date
# 2. [BEHIND] feature-login [feature-login] - behind
# 3. [AHEAD] feature-api [feature-api] - ahead
# 4. [BEHIND] hotfix [hotfix-123] - behind [DIRTY]
# 5. [NO-REMOTE] experiment [experiment] - no-remote
# =================================================================
#
# 2 worktree(s) can be updated.
# Update all updateable worktrees? [y/N]: y
```

**Update all worktrees automatically:**
```bash
uwt -a
# Updates all worktrees that are behind their remote
# without prompting
```

**Force update (including dirty worktrees):**
```bash
uwt -a -f
# Updates all worktrees, even those with uncommitted changes
# ⚠️ Use with caution!
```

#### Status Indicators

| Status | Description |
|--------|-------------|
| `[OK]` | Up-to-date with remote |
| `[BEHIND]` | Local branch is behind remote (can be updated) |
| `[AHEAD]` | Local branch has commits not pushed to remote |
| `[DIVERGED]` | Local and remote have different commits |
| `[NO-REMOTE]` | No remote tracking branch configured |
| `[DIRTY]` | Has uncommitted changes |

#### Update Logic

**When a worktree is updated:**
- Status is `behind` (local is behind remote)
- Either clean OR `-f, --force` flag is used
- Uses `git pull --ff-only` to prevent accidental merges

**When a worktree is skipped:**
- Has uncommitted changes and `-f` flag is NOT used
- Is already up-to-date
- Is ahead, diverged, or has no remote

#### Example Output

```
Fetching latest from remote...

Worktree Status:
=================================================================
1. [OK] main [main] - up-to-date
2. [BEHIND] feature-login [feature-login] - behind
3. [BEHIND] hotfix [hotfix-bug] - behind
4. [AHEAD] feature-new [feature-new] - ahead
=================================================================

2 worktree(s) can be updated.
Update all updateable worktrees? [y/N]: y

Pulling feature-login...
   Updated feature-login
Pulling hotfix...
   Updated hotfix

=================================================================
Update Summary:
   Updated: 2
      - feature-login
      - hotfix
=================================================================
Done.
```

#### Safety Features

- **Fast-forward only**: Uses `--ff-only` to prevent merge commits
- **Uncommitted change protection**: Skips dirty worktrees unless `-f` is used
- **Fetch first**: Updates remote tracking info before analyzing
- **Detailed summary**: Shows exactly what was updated, failed, or skipped

---

## Security Features

The script includes comprehensive security measures to protect against common vulnerabilities:

### Input Validation

**Branch/Feature Name Validation:**
- Enforces git ref name rules
- Blocks shell metacharacters: `$`, `` ` ``, `|`, `&`, `;`, `<`, `>`
- Prevents git special characters: `~`, `^`, `:`, `?`, `*`, `[`, `@{`
- Blocks path traversal: `../`, `..`, double slashes `//`
- Enforces naming conventions (no leading `.`, trailing `.lock`)

**Configuration Value Sanitization:**
- Validates `EDITOR` for command injection patterns
- Sanitizes `COPY_FILES` and `COPY_DIRS` for unsafe characters
- Validates `WORKTREE_PATH` for path traversal and injection
- Falls back to safe defaults when invalid input is detected

### Command Injection Prevention

All user input is validated before being used in commands:
```bash
# Example: Prevents command injection in branch names
if [[ "$name" =~ [\$\`\(\)\|\&\;\<\>] ]]; then
  _gwt_print "Error: Feature name contains invalid characters"
  return 1
fi
```

### Path Traversal Protection

Prevents directory traversal attacks:
```bash
# Blocks attempts like: ../../../etc/passwd
if [[ "$name" == ../* ]] || [[ "$name" == */../* ]]; then
  _gwt_print "Error: Feature name cannot contain path traversal (../)"
  return 1
fi
```

### Safe Defaults

When configuration values fail validation:
- `EDITOR`: Falls back to `nvimf`
- `COPY_FILES`: Falls back to `.env`
- `COPY_DIRS`: Falls back to empty (no directories)
- `AUTO_OPEN`: Falls back to `true`
- `WORKTREE_PATH`: Falls back to default pattern

### Cleanup on Failure

Partial worktree creations are cleaned up automatically:
```bash
trap _cleanup INT TERM EXIT

_cleanup() {
  if [[ $cleanup_needed -eq 1 ]]; then
    # Remove worktree directory
    git worktree remove "$cleanup_worktree_path" --force
    # Remove branch if it was created
    git branch -D "$cleanup_branch_name"
  fi
}
```

### Safe File Operations

- Uses absolute paths to prevent path confusion
- Validates directories exist before operations
- Uses `--force` flag carefully in git operations
- Checks for uncommitted changes before destructive operations

---

## Shell Compatibility

The script is designed to work seamlessly in both **bash** and **zsh** environments.

### Supported Shells

| Shell | Minimum Version | Status |
|-------|----------------|--------|
| bash | 4.0+ | ✅ Fully Supported |
| zsh | 5.0+ | ✅ Fully Supported |

### Compatibility Layer

The script includes a cross-shell compatibility layer that abstracts shell-specific features:

#### Shell Detection
```bash
_gwt_detect_shell()
# Automatically detects bash or zsh
# Sets GWT_SHELL environment variable
```

#### Cross-Shell Print Function
```bash
_gwt_print()
# Unified print function for both shells
# Uses printf for maximum compatibility
```

#### Cross-Shell Read Prompt
```bash
_gwt_read_prompt "prompt text" variable_name
# Handles different read syntax between bash and zsh
# bash: read -r -p "prompt" varname
# zsh:  read -r "?prompt" varname
```

#### Cross-Shell Array Operations
```bash
_gwt_array_append array_name values...
# Abstracts array append operations
# Works identically in bash and zsh
```

#### Shell-Specific Options

**Zsh:**
```bash
emulate -L zsh
setopt local_options local_traps
setopt err_return pipe_fail no_unset
```

**Bash:**
```bash
set -euo pipefail
```

### Testing Your Shell

Check which shell you're using:
```bash
echo $SHELL
# /bin/bash or /bin/zsh

# Or check the version
bash --version
zsh --version
```

### Known Limitations

- Requires bash 4.0+ for associative arrays and modern features
- Requires zsh 5.0+ for proper array handling
- The script will error if run in unsupported shells (sh, dash, etc.)

---

## Real-World Examples

### Example 1: Feature Development Workflow

**Scenario:** Working on a new feature while maintaining the ability to quickly fix bugs in production.

```bash
# Start in main repo
cd ~/projects/my-app

# Create worktree for new feature
cwt feature/user-dashboard
# Opens in editor automatically
# Files (.env, .claude, etc.) copied automatically

# Work on feature, make commits
cd ../my-app-worktrees/feature/user-dashboard
git add .
git commit -m "Add user dashboard component"

# Bug report comes in - need to hotfix!
# Switch back to main without losing work
swt main
# Or create a hotfix worktree
cwt -e main hotfix-login-bug

# Fix the bug in hotfix worktree
cd ../my-app-worktrees/hotfix-login-bug
# ... make fixes ...
git add .
git commit -m "Fix login validation bug"
git push

# Back to feature work
swt feature/user-dashboard
# Continue working with all uncommitted changes intact

# Feature complete - cleanup
cd ../my-app-worktrees/feature/user-dashboard
dwt
# Prompts to delete worktree and branch
```

### Example 2: Code Review Workflow

**Scenario:** Reviewing a pull request without affecting your current work.

```bash
# Currently working on feature-api
cd ~/projects/app-worktrees/feature-api

# PR comes in for review
# Create worktree from the remote branch
cwt -e origin/feature-authentication

# Review the code in a separate worktree
cd ../app-worktrees/feature-authentication
# ... review code ...
# Run tests, check functionality

# Leave comments, done with review
# Clean up the review worktree
dwt -f
# Force delete without prompts

# Back to your work immediately
swt feature-api
```

### Example 3: Multi-Version Testing

**Scenario:** Testing your app against multiple branches simultaneously.

```bash
# Main development branch
cd ~/projects/my-app

# Create worktrees for different versions
cwt -e main             # Production
cwt -e develop          # Staging
cwt feature-new-ui      # Your work

# List all worktrees to see status
lwt
# Shows all three worktrees with their status

# Start dev server in each (different ports)
cd ../my-app-worktrees/main
npm run dev -- --port 3000 &

cd ../my-app-worktrees/develop
npm run dev -- --port 3001 &

cd ../my-app-worktrees/feature-new-ui
npm run dev -- --port 3002 &

# Test all three versions simultaneously in browser
# localhost:3000 (production)
# localhost:3001 (staging)
# localhost:3002 (your feature)
```

### Example 4: Automated Release Process

**Scenario:** Script to update all worktrees before a release.

```bash
#!/bin/bash
# release-prep.sh

echo "Preparing for release..."

# Update all worktrees
uwt -a

# Check status
lwt

# Switch to main for release
cd $(swt -p main)

# Run release script
npm run release
```

### Example 5: Emergency Hotfix with Dirty Worktree

**Scenario:** Need to make a hotfix but have uncommitted changes.

```bash
# Working on feature with uncommitted changes
cd ~/projects/app-worktrees/feature-complex

# Critical bug reported!
# Create hotfix worktree from production branch
cwt -e origin/production hotfix-critical

# Make fix
cd ../app-worktrees/hotfix-critical
# ... make urgent fix ...
git add .
git commit -m "HOTFIX: Fix critical security issue"
git push origin hotfix-critical

# Create PR, wait for merge

# Clean up hotfix worktree
dwt -f

# Return to feature work (uncommitted changes intact!)
swt feature-complex
# All your uncommitted work is still there
```

### Example 6: Team Collaboration

**Scenario:** Multiple team members' branches to test.

```bash
# Fetch latest from remote
git fetch --all

# Create worktrees for team members' branches
cwt -e origin/alice/feature-search
cwt -e origin/bob/feature-analytics
cwt -e origin/carol/feature-export

# Test each feature
swt alice
# Test Alice's feature

swt bob
# Test Bob's feature

swt carol
# Test Carol's feature

# Update all worktrees as team makes changes
uwt -a

# Clean up after testing
cd ../app-worktrees/alice/feature-search
dwt -f
cd ../app-worktrees/bob/feature-analytics
dwt -f
cd ../app-worktrees/carol/feature-export
dwt -f
```

---

## Troubleshooting

### Common Issues

#### 1. "Not inside a git repository"

**Problem:** Running commands outside a git repository.

**Solution:**
```bash
# Navigate to your git repository first
cd ~/projects/my-app
git status  # Verify you're in a git repo

# Then run the command
cwt feature-test
```

---

#### 2. "Editor 'nvimf' not found in PATH"

**Problem:** Configured editor is not installed or not in PATH.

**Solutions:**

**Option A - Install the editor:**
```bash
# For VS Code
# macOS
brew install --cask visual-studio-code

# Add to PATH (add to ~/.zshrc or ~/.bashrc)
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
```

**Option B - Change the editor:**
```bash
# Create/edit .git-worktree-config in repo root
echo "EDITOR=code" > .git-worktree-config
# or
echo "EDITOR=vim" > .git-worktree-config
```

**Option C - Set environment variable:**
```bash
# Add to ~/.zshrc or ~/.bashrc
export GWT_EDITOR=vim
```

---

#### 3. "Branch 'feature-x' already exists"

**Problem:** Trying to create a new branch that already exists.

**Solution:**
```bash
# Use -e flag to checkout existing branch
cwt -e feature-x

# Or choose a different name
cwt feature-x-v2
```

---

#### 4. "Worktree already exists at: ..."

**Problem:** Directory already exists at the worktree location.

**Solutions:**

**Option A - Use existing worktree:**
```bash
# Switch to it instead
swt feature-x
```

**Option B - Remove old worktree:**
```bash
cd path/to/existing/worktree
dwt -f
```

**Option C - Clean up git worktree registry:**
```bash
# If directory was manually deleted
git worktree prune
```

---

#### 5. File copying fails

**Problem:** "Warning: Failed to copy .env file"

**Possible Causes:**
- File doesn't exist in main repository
- Permission issues
- Invalid file name in config

**Solution:**
```bash
# Check if file exists in main repo
ls -la .env

# Check permissions
ls -la .env
# If permission denied:
chmod 644 .env

# Verify config file
cat .git-worktree-config
# Ensure COPY_FILES is correctly formatted:
# COPY_FILES=.env,.env.local
```

---

#### 6. "You don't appear to be in a git worktree"

**Problem:** Running `dwt` from main repository or outside worktree.

**Solution:**
```bash
# Check where you are
git rev-parse --git-dir
# If output is ".git", you're in main repo
# If output is ".git/worktrees/...", you're in a worktree

# Navigate to a worktree first
cd ../my-app-worktrees/feature-x
dwt
```

---

#### 7. fzf not found (swt command)

**Problem:** `swt` works but without fuzzy finder.

**Solution:**
```bash
# Install fzf for better experience
# macOS
brew install fzf

# Ubuntu/Debian
sudo apt-get install fzf

# Fedora
sudo dnf install fzf

# Or use numbered selection (fallback works fine)
```

---

#### 8. Uncommitted changes preventing update

**Problem:** `uwt` skips worktrees with uncommitted changes.

**Solutions:**

**Option A - Commit changes:**
```bash
cd ../my-app-worktrees/feature-x
git add .
git commit -m "WIP: Save progress"
# Then run uwt again
```

**Option B - Stash changes:**
```bash
cd ../my-app-worktrees/feature-x
git stash
cd ~/projects/my-app
uwt -a
cd ../my-app-worktrees/feature-x
git stash pop
```

**Option C - Force update (⚠️ use carefully):**
```bash
uwt -a -f
# Updates even worktrees with uncommitted changes
```

---

#### 9. Invalid characters in branch name

**Problem:** "Error: Feature name contains invalid characters"

**Solution:**
```bash
# Avoid these characters: $ ` | & ; < > ~ ^ : ? * [ @{ .. //
# BAD:
cwt feature$123    # Contains $
cwt ../feature     # Path traversal
cwt feature..test  # Double dots

# GOOD:
cwt feature-123
cwt feature/login
cwt bugfix_auth
```

---

#### 10. Configuration not being loaded

**Problem:** Config file changes not taking effect.

**Solution:**
```bash
# Verify config file location
ls -la .git-worktree-config
# Must be in repository root (same level as .git/)

# Check file format
cat .git-worktree-config
# Format: KEY=value (no spaces around =)
# CORRECT:
# EDITOR=code
# WRONG:
# EDITOR = code

# Verify no hidden characters
cat -A .git-worktree-config
# Should show clean lines with $ at end

# Re-source your shell (if sourcing in shell config)
source ~/.zshrc  # or ~/.bashrc
```

---

#### 11. Cleanup lock files

**Problem:** Stale `index.lock` files.

**Solution:**
```bash
# Find lock files
find ~/projects/my-app-worktrees -name "index.lock"

# Check if any process is using it
lsof /path/to/worktree/.git/index.lock

# If no process, remove it
rm /path/to/worktree/.git/index.lock
```

---

#### 12. Detached HEAD state in worktree

**Problem:** Worktree is in detached HEAD state.

**Solution:**
```bash
# Check current state
git status

# Create a branch from current state
git checkout -b new-branch-name

# Or checkout an existing branch
git checkout existing-branch

# Or if you want to delete the worktree:
dwt -f
# (dwt handles detached HEAD properly)
```

---

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Add to script temporarily for debugging
set -x  # Enable trace
cwt feature-test
set +x  # Disable trace
```

---

### Getting Help

For each command, use the `-h` or `--help` flag:

```bash
cwt --help
dwt --help
lwt --help
swt --help
uwt --help
```

---

## Contributing

Contributions are welcome! Here's how you can help:

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Provide clear description of the problem
3. Include:
   - Shell version (`bash --version` or `zsh --version`)
   - Git version (`git --version`)
   - Operating system
   - Steps to reproduce
   - Expected vs. actual behavior

### Suggesting Features

Open an issue with:
- Clear description of the feature
- Use cases and benefits
- Example usage (if applicable)

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test in both bash and zsh
5. Commit with clear messages
6. Push and create a pull request

### Development Guidelines

- Maintain cross-shell compatibility (bash/zsh)
- Follow existing code style and structure
- Add comments for complex logic
- Update documentation for new features
- Validate all user input for security
- Include error handling

---

## License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Quick Reference Card

```bash
# CREATE WORKTREE
cwt feature-name              # New branch
cwt -e main                   # Existing branch
cwt -e origin/feature-remote  # Remote branch
cwt -n feature-name           # Don't open editor

# DELETE WORKTREE
dwt                           # Interactive
dwt -f                        # Force (no prompts)

# LIST WORKTREES
lwt                           # Show all with status

# SWITCH WORKTREES
swt                           # Interactive selection
swt feature-name              # Direct switch
swt -p                        # Print path only
cd $(swt -p)                  # CD to selected

# UPDATE WORKTREES
uwt                           # Interactive update
uwt -a                        # Update all
uwt -a -f                     # Update all (force)

# HELP
cwt --help                    # Show command help
```

---

**Made for developers who use AI agents across multiple branches**

For questions, issues, or suggestions, please open an issue on GitHub.
