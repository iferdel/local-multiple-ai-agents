#!/usr/bin/env bash

# ============================================================================
# Git Worktree Helper Script
# ============================================================================
# A comprehensive toolkit for managing git worktrees with safety and ease.
#
# Available Functions:
#   cwt - Create a new git worktree
#   dwt - Delete a git worktree
#   lwt - List all git worktrees
#   swt - Switch between git worktrees
#   uwt - Update/pull git worktrees
#
# For help: run any function with -h or --help flag
# Or run: _gwt_help
#
# Requires: bash 4.0+ or zsh 5.0+
# ============================================================================

# ============================================================================
# SHELL COMPATIBILITY LAYER
# ============================================================================

# Detect shell and set compatibility flags
_gwt_detect_shell() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    GWT_SHELL="zsh"
  elif [ -n "${BASH_VERSION:-}" ]; then
    GWT_SHELL="bash"
  else
    printf '%s\n' "Error: This script requires bash 4.0+ or zsh 5.0+" >&2
    printf '%s\n' "Current shell: $SHELL" >&2
    return 1
  fi
  export GWT_SHELL
}

# Cross-shell print function (replaces zsh's print -r --)
_gwt_print() {
  printf '%s\n' "$@"
}

# Cross-shell read with prompt
# Usage: _gwt_read_prompt "prompt text" variable_name
_gwt_read_prompt() {
  local prompt="$1"
  local var_name="$2"

  # Lazy shell detection
  if [ -z "${GWT_SHELL:-}" ]; then
    _gwt_detect_shell
  fi

  if [ "$GWT_SHELL" = "zsh" ]; then
    # zsh syntax: read -r "?prompt" varname
    eval "read -r \"?${prompt}\" ${var_name}"
  else
    # bash syntax: read -r -p "prompt" varname
    read -r -p "${prompt}" "$var_name"
  fi
}

# Cross-shell array append (works for both bash and zsh)
_gwt_array_append() {
  local array_name="$1"
  shift

  # Lazy shell detection
  if [ -z "${GWT_SHELL:-}" ]; then
    _gwt_detect_shell
  fi

  if [ "$GWT_SHELL" = "zsh" ]; then
    eval "${array_name}+=(\"\$@\")"
  else
    # bash
    eval "${array_name}+=(\"\$@\")"
  fi
}

# Returns 0 if `$1` (an editor command) is a known TUI / terminal editor
# that would deadlock if backgrounded with `&`. The list is checked by the
# *basename* of the command so paths like /usr/local/bin/nvim still match.
_gwt_is_tui_editor() {
  case "$(basename -- "$1")" in
    nvim|vim|vi|nano|emacs|micro|helix|hx|kak|joe|ne) return 0 ;;
    *) return 1 ;;
  esac
}

# Launches `$1` on `$2` (path), honoring GWT_EDITOR_BACKGROUND:
#   auto  -> background for GUI, foreground for known TUI editors
#   true  -> always background (`cmd path &`)
#   false -> always foreground (blocks until editor exits)
_gwt_launch_editor() {
  local editor="$1"
  local target="$2"
  local mode="${GWT_EDITOR_BACKGROUND:-auto}"

  case "$mode" in
    true)  "$editor" "$target" & ;;
    false) "$editor" "$target" ;;
    auto|*)
      if _gwt_is_tui_editor "$editor"; then
        "$editor" "$target"
      else
        "$editor" "$target" &
      fi
      ;;
  esac
}

# Cross-shell CSV split into a named array.
# `read -ra` (bash) and `read -A` (zsh) have incompatible flags, and under
# `emulate -L zsh` the bash form errors out. This split avoids both.
# Usage: _gwt_split_csv arr_name "a,b,c"
_gwt_split_csv() {
  local _arr_name="$1"
  local _input="$2"
  local _item

  eval "${_arr_name}=()"
  while [[ "$_input" == *,* ]]; do
    _item="${_input%%,*}"
    eval "${_arr_name}+=(\"\$_item\")"
    _input="${_input#*,}"
  done
  if [[ -n "$_input" ]]; then
    eval "${_arr_name}+=(\"\$_input\")"
  fi
}

# Cross-shell function setup (replaces emulate -L zsh + setopt)
#
# Sets GWT_ARR_OFF: the array index offset for the current shell.
#   zsh arrays are 1-indexed; bash arrays are 0-indexed. Code that needs
#   to iterate parallel arrays uses `${arr[$((i + GWT_ARR_OFF))]}`.
#
# Note: We deliberately do NOT enable `set -e` / `set -o pipefail` in bash
# here. Bash has no function-local `set` — those options would leak into
# the caller's interactive shell and break it. zsh's `emulate -L zsh` and
# `setopt local_options` ARE function-scoped, so they're safe.
_gwt_function_setup() {
  # Lazy initialization - detect shell on first use
  if [ -z "${GWT_SHELL:-}" ]; then
    _gwt_detect_shell
  fi

  if [ "$GWT_SHELL" = "zsh" ]; then
    # `emulate -L zsh` is function-scoped (`-L` = local). We deliberately
    # do NOT enable err_return / pipe_fail / no_unset: every git call in
    # this script already has explicit error handling, and strict mode
    # bails on unset locals (e.g. `upstream` after a failing `@{u}` lookup)
    # producing confusing failures asymmetric to bash.
    emulate -L zsh
    setopt local_options local_traps 2>/dev/null || true
    GWT_ARR_OFF=1
  else
    GWT_ARR_OFF=0
  fi
}

# Note: Shell detection is now lazy - happens on first function call
# This prevents interference with .zshrc/.bashrc sourcing

# ============================================================================
# CONFIGURATION SYSTEM
# ============================================================================

_load_gwt_config() {
  # Lazy shell detection
  if [ -z "${GWT_SHELL:-}" ]; then
    _gwt_detect_shell
  fi

  # Shell-specific setup
  if [ "$GWT_SHELL" = "zsh" ]; then
    emulate -L zsh
    setopt local_options no_unset
  fi
  # Note: Bash doesn't need special setup here

  # Get the git repo root
  local project_dir
  if ! project_dir=$(git rev-parse --show-toplevel 2>/dev/null); then
    return 1
  fi

  local config_file="$project_dir/.git-worktree-config"

  # Set sensible defaults
  export GWT_EDITOR="${GWT_EDITOR:-cursor}"
  export GWT_COPY_FILES="${GWT_COPY_FILES:-.env}"
  export GWT_COPY_DIRS="${GWT_COPY_DIRS:-.instrumental,.claude,.cursor}"
  export GWT_AUTO_OPEN="${GWT_AUTO_OPEN:-true}"
  export GWT_WORKTREE_PATH="${GWT_WORKTREE_PATH:-}"
  # auto | true | false. `auto` (default) backgrounds GUI editors and
  # foregrounds TUI editors (nvim, vim, emacs -nw, ...).
  export GWT_EDITOR_BACKGROUND="${GWT_EDITOR_BACKGROUND:-auto}"

  # Load config file if it exists
  if [[ -f "$config_file" ]]; then
    while IFS='=' read -r key value; do
      # Skip empty lines and comments
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

      # Strip trailing CR (handles CRLF line endings)
      key="${key%$'\r'}"
      value="${value%$'\r'}"

      # Trim whitespace
      key="${key##[[:space:]]}"
      key="${key%%[[:space:]]}"
      value="${value##[[:space:]]}"
      value="${value%%[[:space:]]}"

      # Skip if no value
      [[ -z "$value" ]] && continue

      # Set configuration based on key
      case "$key" in
        EDITOR)
          # Sanitize EDITOR value to prevent command injection
          if [[ "$value" =~ [\$\`\(\)\|\&\;\<\>] ]] || \
             [[ "$value" == *'$('* ]] || \
             [[ "$value" == *'`'* ]]; then
            _gwt_print "Error: EDITOR contains unsafe characters" >&2
            GWT_EDITOR="cursor"  # Use safe default
          else
            GWT_EDITOR="$value"
          fi
          ;;
        COPY_FILES)
          # Sanitize COPY_FILES to prevent command injection
          if [[ "$value" =~ [\$\`\(\)\|\&\;\<\>] ]] || \
             [[ "$value" == *'$('* ]] || \
             [[ "$value" == *'`'* ]]; then
            _gwt_print "Error: COPY_FILES contains unsafe characters" >&2
            GWT_COPY_FILES=".env"  # Use safe default
          else
            GWT_COPY_FILES="$value"
          fi
          ;;
        COPY_DIRS)
          # Sanitize COPY_DIRS to prevent command injection
          if [[ "$value" =~ [\$\`\(\)\|\&\;\<\>] ]] || \
             [[ "$value" == *'$('* ]] || \
             [[ "$value" == *'`'* ]]; then
            _gwt_print "Error: COPY_DIRS contains unsafe characters" >&2
            GWT_COPY_DIRS=""  # Use safe default (no dirs)
          else
            GWT_COPY_DIRS="$value"
          fi
          ;;
        AUTO_OPEN) GWT_AUTO_OPEN="$value" ;;
        WORKTREE_PATH) GWT_WORKTREE_PATH="$value" ;;
        EDITOR_BACKGROUND) GWT_EDITOR_BACKGROUND="$value" ;;
        *) _gwt_print "Warning: Unknown config key '$key' in $config_file" >&2 ;;
      esac
    done < "$config_file"
  fi

  # Validate AUTO_OPEN
  if [[ ! "$GWT_AUTO_OPEN" =~ ^(true|false|yes|no|1|0)$ ]]; then
    _gwt_print "Warning: Invalid AUTO_OPEN value '$GWT_AUTO_OPEN'. Using 'true'" >&2
    GWT_AUTO_OPEN="true"
  fi

  # Normalize AUTO_OPEN to true/false
  case "$GWT_AUTO_OPEN" in
    yes|1) GWT_AUTO_OPEN="true" ;;
    no|0) GWT_AUTO_OPEN="false" ;;
  esac

  # Validate / normalize EDITOR_BACKGROUND
  case "$GWT_EDITOR_BACKGROUND" in
    auto|true|false) ;;
    yes|1) GWT_EDITOR_BACKGROUND="true" ;;
    no|0)  GWT_EDITOR_BACKGROUND="false" ;;
    *)
      _gwt_print "Warning: Invalid EDITOR_BACKGROUND value '$GWT_EDITOR_BACKGROUND'. Using 'auto'." >&2
      GWT_EDITOR_BACKGROUND="auto"
      ;;
  esac

  # Validate WORKTREE_PATH pattern (basic check for unsafe characters)
  if [[ -n "$GWT_WORKTREE_PATH" ]]; then
    if [[ "$GWT_WORKTREE_PATH" == *";"* ]] || \
       [[ "$GWT_WORKTREE_PATH" == *"&"* ]] || \
       [[ "$GWT_WORKTREE_PATH" == *'$('* ]] || \
       [[ "$GWT_WORKTREE_PATH" == *'`'* ]] || \
       [[ "$GWT_WORKTREE_PATH" == *'<'* ]] || \
       [[ "$GWT_WORKTREE_PATH" == *'>'* ]]; then
      _gwt_print "Error: WORKTREE_PATH contains unsafe characters" >&2
      _gwt_print "Falling back to default pattern" >&2
      GWT_WORKTREE_PATH=""
    fi
  fi

  return 0
}

# ============================================================================
# CREATE WORKTREE (cwt)
# ============================================================================

cwt() {
  _gwt_function_setup

  # --- Helper Functions ---

  # Show usage information
  _show_usage() {
    cat <<'EOF'
Usage: cwt [OPTIONS] <feature-name>

Create a new git worktree with a new or existing branch.

OPTIONS:
    -e, --existing      Checkout existing branch instead of creating new one
    -n, --no-open       Skip opening the worktree in editor
    -h, --help          Show this help message

ENVIRONMENT VARIABLES:
    GWT_EDITOR          Editor to open worktree in (default: cursor)

EXAMPLES:
    cwt feature-123                 # Create new branch and worktree
    cwt -e main                     # Checkout existing 'main' branch
    cwt -e origin/feature-456       # Checkout remote branch
    cwt -n hotfix                   # Create worktree without opening editor
EOF
  }

  # Validate feature/branch name
  _validate_name() {
    local name="$1"

    # Check for empty name
    if [[ -z "$name" ]]; then
      _gwt_print "Error: Feature name cannot be empty."
      return 1
    fi

    # Check for spaces
    if [[ "$name" =~ [[:space:]] ]]; then
      _gwt_print "Error: Feature name cannot contain spaces."
      return 1
    fi

    # Check for invalid git ref characters and shell metacharacters
    if [[ "$name" =~ [\~\^:\?\*\[\$\|\&] ]] || \
       [[ "$name" =~ '@{' ]] || \
       [[ "$name" =~ [.][.] ]] || \
       [[ "$name" =~ '//' ]] || \
       [[ "$name" == *\\* ]] || \
       [[ "$name" == *'`'* ]] || \
       [[ "$name" == *'<'* ]] || \
       [[ "$name" == *'>'* ]] || \
       [[ "$name" == *';'* ]]; then
      _gwt_print "Error: Feature name contains invalid characters for git branch names."
      _gwt_print "Avoid: \\ ~ ^ : ? * [ @{ .. // \$ | & ; < > \`"
      return 1
    fi

    # Check for path traversal attempts
    if [[ "$name" == ../* ]] || [[ "$name" == */../* ]]; then
      _gwt_print "Error: Feature name cannot contain path traversal (../)."
      return 1
    fi

    # Cannot start with . or end with .lock
    if [[ "$name" == .* ]] || [[ "$name" == *.lock ]]; then
      _gwt_print "Error: Feature name cannot start with '.' or end with '.lock'."
      return 1
    fi

    # Cannot end with . or /
    if [[ "$name" == *. ]] || [[ "$name" == */ ]]; then
      _gwt_print "Error: Feature name cannot end with '.' or '/'."
      return 1
    fi

    return 0
  }

  # Check if editor is available
  _check_editor() {
    local editor="$1"

    if ! command -v "$editor" >/dev/null 2>&1; then
      _gwt_print "Warning: Editor '$editor' not found in PATH."
      _gwt_print "Skipping editor launch."
      return 1
    fi

    return 0
  }

  # Cleanup helper for partial failures.
  # Called explicitly on error paths after the worktree has been created.
  # We deliberately do NOT install a shell trap here: traps in bash are
  # shell-scoped, not function-scoped, so `trap _cleanup INT TERM EXIT`
  # would leak into the caller's interactive shell.
  local cleanup_worktree_path=""
  local cleanup_branch_name=""

  _cleanup() {
    if [[ -z "$cleanup_worktree_path" ]]; then
      return 0
    fi
    _gwt_print ""
    _gwt_print "Cleaning up partial worktree creation..."

    if [[ -d "$cleanup_worktree_path" ]]; then
      git -C "$project_dir" worktree remove "$cleanup_worktree_path" --force 2>/dev/null || {
        rm -rf "$cleanup_worktree_path" 2>/dev/null || true
      }
      _gwt_print "Removed worktree: $cleanup_worktree_path"
    fi

    if [[ -n "$cleanup_branch_name" ]]; then
      git -C "$project_dir" branch -D "$cleanup_branch_name" 2>/dev/null && \
        _gwt_print "Removed branch: $cleanup_branch_name" || true
    fi
  }

  # --- Load Configuration ---

  _load_gwt_config || true

  # --- Argument Parsing ---

  local flag_existing=0
  local flag_no_open=0
  local feature_name=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _show_usage
        return 0
        ;;
      -e|--existing)
        flag_existing=1
        shift
        ;;
      -n|--no-open)
        flag_no_open=1
        shift
        ;;
      -*)
        _gwt_print "Error: Unknown option: $1"
        _gwt_print ""
        _show_usage
        return 1
        ;;
      *)
        if [[ -z "$feature_name" ]]; then
          feature_name="$1"
          shift
        else
          _gwt_print "Error: Too many arguments."
          _gwt_print ""
          _show_usage
            return 1
        fi
        ;;
    esac
  done

  # --- Validation ---

  # Check if feature name was provided
  if [[ -z "$feature_name" ]]; then
    _gwt_print "Error: Feature name is required."
    _gwt_print ""
    _show_usage
    return 1
  fi

  # Validate we're in a git repo
  local project_dir
  if ! project_dir=$(git rev-parse --show-toplevel 2>/dev/null); then
    _gwt_print "Error: Not inside a git repository."
    return 1
  fi

  # Validate feature name
  if ! _validate_name "$feature_name"; then
    return 1
  fi

  # Get project name
  local project_name=$(basename "$project_dir")

  # Define paths. If GWT_WORKTREE_PATH is set, use its pattern (with
  # {PROJECT_NAME} / {FEATURE_NAME} substitution and ~ expansion);
  # otherwise fall back to the default <parent>/<project>-worktrees layout.
  local worktree_path worktree_parent
  if [[ -n "$GWT_WORKTREE_PATH" ]]; then
    worktree_path="$GWT_WORKTREE_PATH"
    worktree_path="${worktree_path//\{PROJECT_NAME\}/$project_name}"
    worktree_path="${worktree_path//\{FEATURE_NAME\}/$feature_name}"
    # Expand leading ~ and ~/... to $HOME
    case "$worktree_path" in
      "~")  worktree_path="$HOME" ;;
      "~/"*) worktree_path="$HOME/${worktree_path#~/}" ;;
    esac
    worktree_parent="$(dirname "$worktree_path")"
  else
    worktree_parent="$(dirname "$project_dir")/${project_name}-worktrees"
    worktree_path="${worktree_parent}/${feature_name}"
  fi

  # Check if worktree already exists
  if [[ -d "$worktree_path" ]]; then
    _gwt_print "Error: Worktree already exists at: $worktree_path"
    return 1
  fi

  # Check if worktree is already registered with git
  if git -C "$project_dir" worktree list | grep -q "$worktree_path"; then
    _gwt_print "Error: Worktree path already registered with git: $worktree_path"
    return 1
  fi

  # --- Branch Handling ---

  local branch_ref="$feature_name"
  local branch_name="$feature_name"
  local create_branch=1

  if [[ $flag_existing -eq 1 ]]; then
    # User wants to checkout existing branch
    create_branch=0

    # Check if it's a remote branch
    if [[ "$feature_name" == origin/* ]] || [[ "$feature_name" == */* ]]; then
      # Remote branch reference
      if ! git -C "$project_dir" show-ref --verify "refs/remotes/$feature_name" >/dev/null 2>&1; then
        _gwt_print "Error: Remote branch '$feature_name' does not exist."
        _gwt_print "Try: git fetch origin"
        return 1
      fi
      branch_ref="$feature_name"
      branch_name="${feature_name#origin/}"
      branch_name="${branch_name##*/}"
    else
      # Local branch
      if ! git -C "$project_dir" show-ref --verify "refs/heads/$feature_name" >/dev/null 2>&1; then
        _gwt_print "Error: Local branch '$feature_name' does not exist."
        _gwt_print "Use 'cwt $feature_name' without -e flag to create a new branch."
        return 1
      fi
    fi
  else
    # Creating new branch - check if it already exists
    if git -C "$project_dir" show-ref --verify "refs/heads/$feature_name" >/dev/null 2>&1; then
      _gwt_print "Error: Branch '$feature_name' already exists."
      _gwt_print "Use 'cwt -e $feature_name' to checkout the existing branch."
        return 1
    fi

    # Check if remote branch exists
    if git -C "$project_dir" show-ref --verify "refs/remotes/origin/$feature_name" >/dev/null 2>&1; then
      _gwt_print "Error: Remote branch 'origin/$feature_name' already exists."
      _gwt_print "Use 'cwt -e origin/$feature_name' to checkout the remote branch."
        return 1
    fi
  fi

  # --- Create Worktree ---

  # Create parent directory
  if ! mkdir -p "$worktree_parent"; then
    _gwt_print "Error: Failed to create worktree parent directory: $worktree_parent"
    return 1
  fi

  # Arm cleanup in case a later step fails.
  cleanup_worktree_path="$worktree_path"
  if [[ $create_branch -eq 1 ]]; then
    cleanup_branch_name="$feature_name"
  fi

  # Create the worktree
  if [[ $create_branch -eq 1 ]]; then
    if ! git -C "$project_dir" worktree add -b "$feature_name" "$worktree_path"; then
      _gwt_print "Error: Failed to create worktree with new branch."
      _cleanup
      return 1
    fi
    _gwt_print "Created new branch: $feature_name"
  else
    if ! git -C "$project_dir" worktree add "$worktree_path" "$branch_ref"; then
      _gwt_print "Error: Failed to create worktree for existing branch."
      _cleanup
      return 1
    fi
    _gwt_print "Checked out existing branch: $branch_name"
  fi

  # --- Copy Configuration Files ---

  # Copy files from config
  local -a files_to_copy
  _gwt_split_csv files_to_copy "$GWT_COPY_FILES"
  for file in "${files_to_copy[@]}"; do
    file="${file##[[:space:]]}"
    file="${file%%[[:space:]]}"
    if [[ -f "$project_dir/$file" ]]; then
      if cp "$project_dir/$file" "$worktree_path/$file" 2>/dev/null; then
        _gwt_print "Copied $file into worktree."
      else
        _gwt_print "Warning: Failed to copy $file file."
      fi
    fi
  done

  # Copy directories from config
  local -a dirs_to_copy
  _gwt_split_csv dirs_to_copy "$GWT_COPY_DIRS"
  for dir in "${dirs_to_copy[@]}"; do
    dir="${dir##[[:space:]]}"
    dir="${dir%%[[:space:]]}"
    if [[ -d "$project_dir/$dir" ]]; then
      if cp -R "$project_dir/$dir" "$worktree_path/$dir" 2>/dev/null; then
        _gwt_print "Copied $dir into worktree."
      else
        _gwt_print "Warning: Failed to copy $dir directory."
      fi
    fi
  done

  # --- Initialize Submodules ---
  # Git worktrees share .git/modules/ with the main repo, so submodule
  # core.worktree can only point to one working tree at a time.
  # Fix: clone from the local submodule (hardlinked objects, near-zero disk
  # cost) so each worktree gets its own independent .git directory.
  if [[ -f "$worktree_path/.gitmodules" ]]; then
    _gwt_print "Initializing submodules in worktree..."
    local sub_key sub_name sub_path sub_url sub_commit sub_source
    # Use process substitution so the loop body runs in the current shell
    # (not a subshell from a pipeline), letting future state changes
    # propagate out.
    while read -r sub_key sub_path; do
      sub_name="${sub_key#submodule.}"
      sub_name="${sub_name%.path}"
      sub_url="$(git -C "$worktree_path" config --file .gitmodules "submodule.${sub_name}.url" 2>/dev/null)"
      sub_commit="$(git -C "$worktree_path" ls-tree HEAD -- "$sub_path" 2>/dev/null | awk '{print $3}')"

      if [[ -z "$sub_commit" ]]; then
        _gwt_print "Warning: Could not resolve submodule '$sub_name', skipping."
        continue
      fi

      # Submodule must be initialized in the main repo before we can clone
      # from it. A submodule gitdir lives at either .git/ (legacy) or .git
      # (a gitfile pointing into .git/modules/...).
      sub_source="${project_dir}/${sub_path}"
      if [[ ! -e "${sub_source}/.git" ]]; then
        _gwt_print "Warning: Submodule '$sub_name' is not initialized in main repo."
        _gwt_print "         Run in the main repo: git submodule update --init --recursive"
        continue
      fi

      # Replace the broken shared-gitdir submodule with a local clone
      rm -rf "${worktree_path:?}/${sub_path}"
      if git clone --quiet "$sub_source" "${worktree_path}/${sub_path}" 2>/dev/null && \
         git -C "${worktree_path}/${sub_path}" checkout --quiet "$sub_commit" 2>/dev/null; then
        # Point origin to the real remote so push/pull work. Resolve
        # relative URLs (e.g. ../foo.git) against the main repo's origin
        # so they remain valid from the worktree location.
        if [[ -n "$sub_url" ]]; then
          case "$sub_url" in
            ./*|../*)
              local main_origin
              main_origin="$(git -C "$project_dir" remote get-url origin 2>/dev/null || true)"
              if [[ -n "$main_origin" ]]; then
                sub_url="${main_origin%/}/${sub_url}"
              fi
              ;;
          esac
          git -C "${worktree_path}/${sub_path}" remote set-url origin "$sub_url" 2>/dev/null
        fi
        _gwt_print "Submodule '$sub_name' initialized at ${sub_commit:0:7}."
      else
        _gwt_print "Warning: Failed to initialize submodule '$sub_name'."
      fi
    done < <(git -C "$worktree_path" config --file .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null)
  fi

  # --- Open in Editor ---

  if [[ $flag_no_open -eq 0 ]] && [[ "$GWT_AUTO_OPEN" == "true" ]]; then
    # Determine editor
    local editor="$GWT_EDITOR"

    if _check_editor "$editor"; then
      _gwt_print "Opening in $editor..."
      _gwt_launch_editor "$editor" "$worktree_path"
    fi
  fi

  # Success - disarm cleanup (no-op now, kept for clarity).
  cleanup_worktree_path=""
  cleanup_branch_name=""

  _gwt_print "Created worktree at: $worktree_path"
}

# ============================================================================
# DELETE WORKTREE (dwt)
# ============================================================================

dwt() {
  _gwt_function_setup

  # Parse flags
  local force_mode=0
  local show_help=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force)
        force_mode=1
        shift
        ;;
      -h|--help)
        show_help=1
        shift
        ;;
      *)
        _gwt_print "Error: Unknown option: $1"
        _gwt_print "Use -h or --help for usage information."
        return 1
        ;;
    esac
  done

  # Show help if requested
  if [[ $show_help -eq 1 ]]; then
    _gwt_print "Usage: dwt [OPTIONS]"
    _gwt_print ""
    _gwt_print "Delete the current git worktree and optionally its associated branch."
    _gwt_print ""
    _gwt_print "Options:"
    _gwt_print "  -f, --force    Skip all confirmations (for scripting)"
    _gwt_print "  -h, --help     Show this help message"
    _gwt_print ""
    _gwt_print "This command must be run from within a git worktree directory."
    return 0
  fi

  # must be inside a worktree
  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null || true)
  if [[ -z "$git_dir" || "$git_dir" != *.git/worktrees/* ]]; then
    _gwt_print "You don't appear to be in a git worktree."
    _gwt_print "Run this from within a worktree directory."
    return 1
  fi

  local worktree_path git_common_dir main_repo worktree_name branch_name
  worktree_path=$(git rev-parse --show-toplevel)
  git_common_dir=$(git rev-parse --git-common-dir)
  main_repo=$(dirname "$git_common_dir")
  worktree_name=$(basename "$worktree_path")
  branch_name=$(git branch --show-current 2>/dev/null || true)

  # Check for uncommitted changes
  local has_uncommitted=0
  local uncommitted_msg=""
  local files_count=0

  if [[ -d "$worktree_path" ]]; then
    # Use git's view of the tree so we don't count .git/ internals or
    # ignored build artifacts (which made the previous find-based count
    # wildly inflated on large repos).
    local _tracked _untracked
    _tracked=$(git -C "$worktree_path" ls-files 2>/dev/null | wc -l | tr -d ' ')
    _untracked=$(git -C "$worktree_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    files_count=$((_tracked + _untracked))
  fi

  if git -C "$worktree_path" diff-index --quiet HEAD -- 2>/dev/null; then
    :  # no uncommitted changes
  else
    has_uncommitted=1
    local modified_count=$(git -C "$worktree_path" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    local staged_count=$(git -C "$worktree_path" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    local untracked_count=$(git -C "$worktree_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

    uncommitted_msg="UNCOMMITTED CHANGES DETECTED:"
    [[ $modified_count -gt 0 ]] && uncommitted_msg="$uncommitted_msg\n   Modified files: $modified_count"
    [[ $staged_count -gt 0 ]] && uncommitted_msg="$uncommitted_msg\n   Staged files: $staged_count"
    [[ $untracked_count -gt 0 ]] && uncommitted_msg="$uncommitted_msg\n   Untracked files: $untracked_count"
  fi

  # Display summary
  _gwt_print "Worktree: $worktree_name"
  _gwt_print "Path:     $worktree_path"
  _gwt_print "Main repo: $main_repo"

  if [[ -n "$branch_name" ]]; then
    _gwt_print "Branch:   $branch_name"
  else
    _gwt_print "State:    Detached HEAD (no branch)"
  fi

  _gwt_print "Files:    $files_count"

  if [[ $has_uncommitted -eq 1 ]]; then
    _gwt_print ""
    _gwt_print "$uncommitted_msg"
  fi

  _gwt_print ""

  # Confirmation (skip if force mode)
  if [[ $force_mode -eq 0 ]]; then
    local confirmation
    _gwt_read_prompt "Delete this worktree? [y/N]: " confirmation
    [[ "$confirmation" =~ ^[Yy]$ ]] || { _gwt_print "Cancelled."; return 0; }
  fi

  # Clean up cloned submodules before removing the worktree.
  # Submodules are standalone clones (not shared-gitdir), so git worktree
  # remove would fail on directories containing .git subdirectories.
  if [[ -f "$worktree_path/.gitmodules" ]]; then
    local _sub_key sub_path
    while read -r _sub_key sub_path; do
      if [[ -d "${worktree_path}/${sub_path}/.git" ]]; then
        rm -rf "${worktree_path:?}/${sub_path}"
      fi
    done < <(git -C "$worktree_path" config --file .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null)
  fi

  # Do operations without changing the caller's directory
  if ! git -C "$main_repo" worktree remove "$worktree_path" --force; then
    _gwt_print "Failed to remove worktree."
    return 1
  fi
  _gwt_print "Removed worktree: $worktree_path"

  git -C "$main_repo" worktree prune >/dev/null 2>&1 || true

  if [[ -n "$branch_name" ]]; then
    local bc
    if [[ $force_mode -eq 1 ]]; then
      bc="y"
    else
      _gwt_read_prompt "Delete branch '$branch_name' too? [y/N]: " bc
    fi

    if [[ "$bc" =~ ^[Yy]$ ]]; then
      # don't delete if checked out elsewhere
      if git -C "$main_repo" worktree list | awk '{print $3}' | grep -qx "$branch_name"; then
        _gwt_print "Branch '$branch_name' is checked out in another worktree. Not deleting."
      else
        git -C "$main_repo" branch -D "$branch_name" || {
          _gwt_print "Could not delete branch '$branch_name'."
        }
        _gwt_print "Deleted branch: $branch_name"
      fi
    else
      _gwt_print "Kept branch: $branch_name"
    fi
  else
    _gwt_print "Detached HEAD - no branch associated with this worktree."
  fi

  _gwt_print "Done."
}

# ============================================================================
# LIST WORKTREES (lwt)
# ============================================================================

lwt() {
  _gwt_function_setup

  # Handle help flag
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    _gwt_print "Usage: lwt"
    _gwt_print ""
    _gwt_print "List all git worktrees with detailed information:"
    _gwt_print "  - Worktree path"
    _gwt_print "  - Branch name"
    _gwt_print "  - Git status (clean/dirty)"
    _gwt_print "  - Last commit info"
    _gwt_print ""
    _gwt_print "The current worktree is highlighted with [CURRENT]"
    return 0
  fi

  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    _gwt_print "Not in a git repository."
    return 1
  fi

  local current_path git_common_dir worktrees_output
  current_path=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

  # Get worktree list
  worktrees_output=$(git worktree list --porcelain 2>/dev/null)

  if [[ -z "$worktrees_output" ]]; then
    _gwt_print "No worktrees found."
    return 0
  fi

  # Header
  _gwt_print ""
  _gwt_print "=========================================================================="
  _gwt_print "  GIT WORKTREES"
  _gwt_print "=========================================================================="
  _gwt_print ""

  # Parse worktree list
  local worktree_path="" branch="" head="" is_current=0
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      # New worktree entry - process previous one if exists
      if [[ -n "$worktree_path" ]]; then
        _lwt_display_worktree "$worktree_path" "$branch" "$head" "$is_current"
      fi

      # Start new entry
      worktree_path="${line#worktree }"
      branch=""
      head=""
      is_current=0
      [[ "$worktree_path" == "$current_path" ]] && is_current=1

    elif [[ "$line" == branch\ * ]]; then
      branch="${line#branch refs/heads/}"
    elif [[ "$line" == HEAD\ * ]]; then
      head="${line#HEAD }"
    elif [[ "$line" == detached ]]; then
      branch="(detached)"
    fi
  done <<< "$worktrees_output"

  # Display last worktree
  if [[ -n "$worktree_path" ]]; then
    _lwt_display_worktree "$worktree_path" "$branch" "$head" "$is_current"
  fi

  _gwt_print ""
  _gwt_print "=========================================================================="
  _gwt_print ""
}

_lwt_display_worktree() {
  local wt_path="$1" wt_branch="$2" wt_head="$3" is_current="$4"
  local marker status_icon status_text commit_msg commit_author commit_date

  # Marker for current worktree
  marker="  "
  [[ "$is_current" == "1" ]] && marker="[CURRENT] "

  # Get git status
  local status_output
  status_output=$(git -C "$wt_path" status --porcelain 2>/dev/null || echo "")

  if [[ -z "$status_output" ]]; then
    status_icon="[CLEAN]"
    status_text="clean"
  else
    status_icon="[DIRTY]"
    status_text="dirty"
  fi

  # Get last commit info
  if [[ -n "$wt_head" ]]; then
    commit_msg=$(git -C "$wt_path" log -1 --format="%s" 2>/dev/null || echo "No commits")
    commit_author=$(git -C "$wt_path" log -1 --format="%an" 2>/dev/null || echo "Unknown")
    commit_date=$(git -C "$wt_path" log -1 --format="%ar" 2>/dev/null || echo "Unknown")
  else
    commit_msg="No commits yet"
    commit_author="Unknown"
    commit_date="Unknown"
  fi

  # Branch display
  local branch_display
  if [[ -z "$wt_branch" ]]; then
    if [[ -n "$wt_head" ]]; then
      branch_display="(detached @ ${wt_head:0:7})"
    else
      branch_display="(no branch)"
    fi
  else
    branch_display="$wt_branch"
  fi

  # Display worktree info
  _gwt_print "${marker}$(basename "$wt_path")"
  _gwt_print "   Path:   $wt_path"
  _gwt_print "   Branch: $branch_display"
  _gwt_print "   Status: $status_icon $status_text"
  _gwt_print "   Commit: $commit_msg"
  _gwt_print "           by $commit_author, $commit_date"
  _gwt_print ""
}

# ============================================================================
# SWITCH WORKTREE (swt)
# ============================================================================

swt() {
  _gwt_function_setup

  # Parse flags
  local print_only=0
  local show_help=0
  local direct_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--print)
        print_only=1
        shift
        ;;
      -h|--help)
        show_help=1
        shift
        ;;
      -*)
        _gwt_print "Unknown option: $1"
        return 1
        ;;
      *)
        direct_arg="$1"
        shift
        ;;
    esac
  done

  # Show help
  if [[ $show_help -eq 1 ]]; then
    cat <<'EOF'
swt - Switch Git Worktree

USAGE:
  swt [OPTIONS] [worktree-name]

OPTIONS:
  -p, --print    Print the worktree path instead of opening editor
  -h, --help     Show this help message

EXAMPLES:
  swt                    # Interactive selection with fzf (or numbered menu)
  swt feature-name       # Switch directly to worktree matching 'feature-name'
  swt -p                 # Print path for use with: cd $(swt -p)

ENVIRONMENT:
  GWT_EDITOR            Editor command (default: cursor)
EOF
    return 0
  fi

  # Load config
  _load_gwt_config || true

  # Must be inside a git repo
  local main_repo
  if ! main_repo=$(git rev-parse --show-toplevel 2>/dev/null); then
    _gwt_print "Not inside a git repository."
    return 1
  fi

  # Get common git dir to handle both main repo and worktrees
  local git_common_dir
  git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
  if [[ "$git_common_dir" == *.git/worktrees/* ]]; then
    main_repo=$(dirname "$git_common_dir")
  fi

  # Get list of worktrees
  local worktree_list
  worktree_list=$(git -C "$main_repo" worktree list --porcelain 2>/dev/null)

  if [[ -z "$worktree_list" ]]; then
    _gwt_print "No worktrees found."
    return 1
  fi

  # Parse worktrees into arrays.
  # Loops below use C-style `for ((i=0; i<n; i++))` plus GWT_ARR_OFF so they
  # work in both bash (0-indexed arrays) and zsh (1-indexed arrays).
  local -a worktree_paths
  local -a worktree_branches
  local -a worktree_info
  local current_path current_branch

  # Caller's actual current toplevel (handles being inside any worktree,
  # not just the main repo). Used to mark the right entry as (current).
  local caller_toplevel
  caller_toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)

  _swt_finalize_entry() {
    local wt_name status_icon=""
    wt_name=$(basename "$current_path")
    if [[ -n "$caller_toplevel" && "$current_path" == "$caller_toplevel" ]]; then
      status_icon=" (current)"
    fi
    worktree_paths+=("$current_path")
    worktree_branches+=("${current_branch:-main}")
    worktree_info+=("$wt_name [$current_branch]$status_icon")
    current_path=""
    current_branch=""
  }

  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      current_path="${line#worktree }"
    elif [[ "$line" == branch\ * ]]; then
      current_branch="${line#branch refs/heads/}"
    elif [[ "$line" == HEAD\ * ]]; then
      current_branch="(detached)"
    elif [[ "$line" == detached ]]; then
      current_branch="(detached)"
    elif [[ -z "$line" && -n "$current_path" ]]; then
      _swt_finalize_entry
    fi
  done <<<"$worktree_list"

  # Handle last entry if file doesn't end with blank line
  if [[ -n "$current_path" ]]; then
    _swt_finalize_entry
  fi

  if [[ ${#worktree_paths[@]} -eq 0 ]]; then
    _gwt_print "No worktrees found."
    return 1
  fi

  local selected_path=""
  local n=${#worktree_paths[@]}
  local i idx

  # Direct argument provided
  if [[ -n "$direct_arg" ]]; then
    local matched=0
    for ((i=0; i<n; i++)); do
      idx=$((i + GWT_ARR_OFF))
      local wt_name=$(basename "${worktree_paths[$idx]}")
      if [[ "$wt_name" == *"$direct_arg"* || "${worktree_branches[$idx]}" == *"$direct_arg"* ]]; then
        selected_path="${worktree_paths[$idx]}"
        matched=1
        break
      fi
    done

    if [[ $matched -eq 0 ]]; then
      _gwt_print "No worktree matching '$direct_arg' found."
      return 1
    fi
  else
    # Interactive selection
    if command -v fzf >/dev/null 2>&1; then
      local selected_info
      selected_info=$(printf '%s\n' "${worktree_info[@]}" | fzf --height=40% --border --prompt="Select worktree: ")

      if [[ -z "$selected_info" ]]; then
        _gwt_print "No worktree selected."
        return 1
      fi

      # Find matching path
      for ((i=0; i<n; i++)); do
        idx=$((i + GWT_ARR_OFF))
        if [[ "${worktree_info[$idx]}" == "$selected_info" ]]; then
          selected_path="${worktree_paths[$idx]}"
          break
        fi
      done
    else
      # Fallback to numbered selection
      _gwt_print "Available worktrees:"
      _gwt_print ""
      for ((i=0; i<n; i++)); do
        idx=$((i + GWT_ARR_OFF))
        _gwt_print "  $((i + 1))) ${worktree_info[$idx]}"
      done
      _gwt_print ""

      local selection
      _gwt_read_prompt "Select worktree (1-${n}): " selection

      if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt $n ]]; then
        _gwt_print "Invalid selection."
        return 1
      fi

      idx=$((selection - 1 + GWT_ARR_OFF))
      selected_path="${worktree_paths[$idx]}"
    fi
  fi

  if [[ -z "$selected_path" ]]; then
    _gwt_print "Failed to select worktree."
    return 1
  fi

  # Print mode
  if [[ $print_only -eq 1 ]]; then
    _gwt_print "$selected_path"
    return 0
  fi

  # Open in editor
  local editor="$GWT_EDITOR"

  if ! command -v "$editor" >/dev/null 2>&1; then
    _gwt_print "Editor '$editor' not found. Path: $selected_path"
    return 1
  fi

  _gwt_print "Opening $(basename "$selected_path") in $editor..."
  _gwt_launch_editor "$editor" "$selected_path"
}

# ============================================================================
# UPDATE WORKTREES (uwt)
# ============================================================================

uwt() {
  _gwt_function_setup

  # Parse flags
  local force=0
  local all=0
  local show_help=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force)
        force=1
        shift
        ;;
      -a|--all)
        all=1
        shift
        ;;
      -h|--help)
        show_help=1
        shift
        ;;
      *)
        _gwt_print "Unknown option: $1"
        _gwt_print "Use -h or --help for usage information."
        return 1
        ;;
    esac
  done

  # Show help
  if [[ $show_help -eq 1 ]]; then
    _gwt_print "Usage: uwt [OPTIONS]"
    _gwt_print ""
    _gwt_print "Update/pull git worktrees with remote tracking status."
    _gwt_print ""
    _gwt_print "Options:"
    _gwt_print "  -a, --all     Update all worktrees without prompting"
    _gwt_print "  -f, --force   Update worktrees even with uncommitted changes"
    _gwt_print "  -h, --help    Show this help message"
    _gwt_print ""
    _gwt_print "Examples:"
    _gwt_print "  uwt           # Interactive mode - choose which worktrees to update"
    _gwt_print "  uwt -a        # Update all worktrees automatically"
    _gwt_print "  uwt -a -f     # Update all worktrees, even with uncommitted changes"
    return 0
  fi

  # Must be inside a git repo
  local main_repo
  if ! main_repo=$(git rev-parse --show-toplevel 2>/dev/null); then
    _gwt_print "Not inside a git repository."
    return 1
  fi

  _gwt_print "Fetching latest from remote..."
  git -C "$main_repo" fetch --all --prune 2>/dev/null || {
    _gwt_print "Failed to fetch from remote. Continuing with local data..."
  }
  _gwt_print ""

  # Get list of all worktrees using proper porcelain parsing
  local -a worktree_paths
  local -a worktree_branches
  local -a worktree_status
  local -a worktree_dirty

  # Parse porcelain format properly (like lwt does)
  local worktrees_output
  worktrees_output=$(git -C "$main_repo" worktree list --porcelain)

  local wt_path="" wt_branch="" wt_head=""
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      # New worktree entry - process previous one if exists
      if [[ -n "$wt_path" ]]; then
        # Process the previous worktree
        worktree_paths+=("$wt_path")
        worktree_branches+=("$wt_branch")

        # Check for uncommitted changes
        local dirty=0
        if ! git -C "$wt_path" diff --quiet 2>/dev/null || \
           ! git -C "$wt_path" diff --cached --quiet 2>/dev/null || \
           [[ -n $(git -C "$wt_path" ls-files --others --exclude-standard 2>/dev/null) ]]; then
          dirty=1
        fi
        worktree_dirty+=($dirty)

        # Check tracking status. Named `track_status` because zsh treats
        # `$status` as a read-only special variable (alias for $?).
        local track_status="no-remote"
        local upstream
        if upstream=$(git -C "$wt_path" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null); then
          local local_commit=$(git -C "$wt_path" rev-parse @ 2>/dev/null)
          local remote_commit=$(git -C "$wt_path" rev-parse @{u} 2>/dev/null)
          local base_commit=$(git -C "$wt_path" merge-base @ @{u} 2>/dev/null)

          if [[ "$local_commit" == "$remote_commit" ]]; then
            track_status="up-to-date"
          elif [[ "$local_commit" == "$base_commit" ]]; then
            track_status="behind"
          elif [[ "$remote_commit" == "$base_commit" ]]; then
            track_status="ahead"
          else
            track_status="diverged"
          fi
        fi
        worktree_status+=("$track_status")
      fi

      # Start new entry
      wt_path="${line#worktree }"
      wt_branch=""
      wt_head=""

    elif [[ "$line" == branch\ * ]]; then
      wt_branch="${line#branch refs/heads/}"
    elif [[ "$line" == HEAD\ * ]]; then
      wt_head="${line#HEAD }"
    elif [[ "$line" == detached ]]; then
      wt_branch="(detached)"
    fi
  done <<< "$worktrees_output"

  # Process the last worktree
  if [[ -n "$wt_path" ]]; then
    worktree_paths+=("$wt_path")
    worktree_branches+=("$wt_branch")

    local dirty=0
    if ! git -C "$wt_path" diff --quiet 2>/dev/null || \
       ! git -C "$wt_path" diff --cached --quiet 2>/dev/null || \
       [[ -n $(git -C "$wt_path" ls-files --others --exclude-standard 2>/dev/null) ]]; then
      dirty=1
    fi
    worktree_dirty+=($dirty)

    local track_status="no-remote"
    local upstream
    if upstream=$(git -C "$wt_path" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null); then
      local local_commit=$(git -C "$wt_path" rev-parse @ 2>/dev/null)
      local remote_commit=$(git -C "$wt_path" rev-parse @{u} 2>/dev/null)
      local base_commit=$(git -C "$wt_path" merge-base @ @{u} 2>/dev/null)

      if [[ "$local_commit" == "$remote_commit" ]]; then
        track_status="up-to-date"
      elif [[ "$local_commit" == "$base_commit" ]]; then
        track_status="behind"
      elif [[ "$remote_commit" == "$base_commit" ]]; then
        track_status="ahead"
      else
        track_status="diverged"
      fi
    fi
    worktree_status+=("$track_status")
  fi

  # Display worktree status.
  # We iterate with a C-style loop and `GWT_ARR_OFF` so this works in both
  # bash (0-indexed) and zsh (1-indexed). `updateable` stores the 0-based
  # loop counter so its values stay shell-agnostic.
  _gwt_print "Worktree Status:"
  _gwt_print "================================================================="

  local -a updateable
  local n=${#worktree_paths[@]}
  local i idx
  for ((i=0; i<n; i++)); do
    idx=$((i + GWT_ARR_OFF))
    # NB: zsh treats `path` as a tied special array (alias for $PATH).
    # Use `wt_p` instead so `local path=...` doesn't blow up PATH.
    local wt_p="${worktree_paths[$idx]}"
    local branch="${worktree_branches[$idx]}"
    local track_status="${worktree_status[$idx]}"
    local dirty=${worktree_dirty[$idx]}
    local name=$(basename "$wt_p")

    # Status symbol
    local status_symbol
    case "$track_status" in
      up-to-date) status_symbol="[OK]" ;;
      behind)     status_symbol="[BEHIND]" ;;
      ahead)      status_symbol="[AHEAD]" ;;
      diverged)   status_symbol="[DIVERGED]" ;;
      no-remote)  status_symbol="[NO-REMOTE]" ;;
    esac

    # Dirty indicator
    local dirty_indicator=""
    if [[ $dirty -eq 1 ]]; then
      dirty_indicator=" [DIRTY]"
    fi

    _gwt_print "$((i + 1)). ${status_symbol} ${name} [${branch}] - ${track_status}${dirty_indicator}"

    # Add to updateable list if behind and (clean or force)
    if [[ "$track_status" == "behind" && ($dirty -eq 0 || $force -eq 1) ]]; then
      updateable+=("$i")
    fi
  done
  _gwt_print "================================================================="
  _gwt_print ""

  # Check if there's anything to update
  if [[ ${#updateable[@]} -eq 0 ]]; then
    _gwt_print "No worktrees need updating."
    return 0
  fi

  # Determine which worktrees to update
  local -a to_update
  if [[ $all -eq 1 ]]; then
    to_update=("${updateable[@]}")
    _gwt_print "Updating ${#to_update[@]} worktree(s)..."
  else
    _gwt_print "${#updateable[@]} worktree(s) can be updated."
    local confirmation
    _gwt_read_prompt "Update all updateable worktrees? [y/N]: " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
      to_update=("${updateable[@]}")
    else
      _gwt_print "Update cancelled."
      return 0
    fi
  fi

  # Update worktrees
  _gwt_print ""
  local -a updated
  local -a failed
  local -a skipped

  # `to_update` holds 0-based loop counters; convert to a shell-appropriate
  # array index when accessing the parallel arrays.
  for i in "${to_update[@]}"; do
    idx=$((i + GWT_ARR_OFF))
    local wt_p="${worktree_paths[$idx]}"
    local branch="${worktree_branches[$idx]}"
    local name=$(basename "$wt_p")
    local dirty=${worktree_dirty[$idx]}

    if [[ $dirty -eq 1 && $force -eq 0 ]]; then
      _gwt_print "Skipping $name (uncommitted changes)"
      skipped+=("$name")
      continue
    fi

    _gwt_print "Pulling $name..."
    if git -C "$wt_p" pull --ff-only 2>/dev/null; then
      updated+=("$name")
      _gwt_print "   Updated $name"
    else
      failed+=("$name")
      _gwt_print "   Failed to update $name"
    fi
  done

  # Summary
  _gwt_print ""
  _gwt_print "================================================================="
  _gwt_print "Update Summary:"
  _gwt_print "   Updated: ${#updated[@]}"
  if [[ ${#updated[@]} -gt 0 ]]; then
    for name in "${updated[@]}"; do
      _gwt_print "      - $name"
    done
  fi

  if [[ ${#failed[@]} -gt 0 ]]; then
    _gwt_print "   Failed: ${#failed[@]}"
    for name in "${failed[@]}"; do
      _gwt_print "      - $name"
    done
  fi

  if [[ ${#skipped[@]} -gt 0 ]]; then
    _gwt_print "   Skipped: ${#skipped[@]}"
    for name in "${skipped[@]}"; do
      _gwt_print "      - $name"
    done
  fi
  _gwt_print "================================================================="

  if [[ ${#failed[@]} -gt 0 ]]; then
    return 1
  fi

  _gwt_print "Done."
}

# ============================================================================
# HELP SYSTEM
# ============================================================================

_gwt_help() {
  cat << 'EOF'
======================================================================
                   Git Worktree Helper Commands
======================================================================

Available Commands:

  cwt  - Create a new git worktree with a new branch
  dwt  - Delete a git worktree (and optionally its branch)
  lwt  - List all git worktrees
  swt  - Switch between git worktrees
  uwt  - Update all git worktrees

Usage:
  Run any command with -h or --help for detailed help

Examples:
  cwt feature-login          # Create worktree for feature-login branch
  dwt                        # Delete current worktree (interactive)
  lwt                        # List all worktrees
  swt                        # Switch worktrees (interactive)
  uwt -a                     # Update all worktrees

Configuration:
  Create .git-worktree-config in your repo root to customize behavior
  See .git-worktree-config.example for template

EOF
}
