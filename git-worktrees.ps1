# git-worktrees.ps1 — Windows/PowerShell homolog of git-worktrees.sh (lean).
#
# Dot-source from your PowerShell profile:
#   . C:\path\to\local-multiple-ai-agents\git-worktrees.ps1
#
# Provides `cwt` with the same core behavior as the bash version:
#   cwt PROJ-123          create branch+worktree ../<repo>-worktrees/PROJ-123
#   cwt -e main           checkout existing branch into a worktree
#   cwt -n hotfix         create worktree, do not launch anything
#   cwt -jw PROJ-123      launch Claude Code with /spec-workflow:orchestrator
#   cwt -ghc PROJ-123     launch GitHub Copilot CLI on the orchestrator skill
#                         (repo-committed .github/skills/orchestrator/SKILL.md if
#                          present, else the globally-installed 'orchestrator' skill)
#
# The worktree directory name IS the ticket key; the tracker backend
# (jira / local) is resolved by the repo's .spec-workflow/config.json,
# so with `backend: "local"` neither agent needs any MCP.
#
# Env overrides:
#   $env:GWT_COPILOT_FLAGS  extra flags for the copilot CLI (default: --allow-all-tools)

function cwt {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Alias('e')][switch]$Existing,
        [Alias('n')][switch]$NoOpen,
        [Alias('jw')][switch]$JiraWorkflow,
        [Alias('ghc')][switch]$CopilotWorkflow
    )

    if ($JiraWorkflow -and $CopilotWorkflow) {
        Write-Error "-jw and -ghc are mutually exclusive."
        return
    }

    $projectDir = git rev-parse --show-toplevel 2>$null
    if (-not $projectDir) {
        Write-Error "Not inside a git repository."
        return
    }
    $projectDir = $projectDir.Trim()

    $projectName = Split-Path $projectDir -Leaf
    $worktreeParent = Join-Path (Split-Path $projectDir -Parent) "$projectName-worktrees"
    $worktreePath = Join-Path $worktreeParent $Name

    if (Test-Path $worktreePath) {
        Write-Error "Worktree path already exists: $worktreePath"
        return
    }
    New-Item -ItemType Directory -Force -Path $worktreeParent | Out-Null

    if ($Existing) {
        git -C $projectDir worktree add $worktreePath $Name
    }
    else {
        git -C $projectDir worktree add -b $Name $worktreePath
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git worktree add failed."
        return
    }
    Write-Host "Worktree ready: $worktreePath"

    if ($NoOpen) { return }

    Set-Location $worktreePath

    $syncNote = "FIRST, before any planning or implementation, run 'git pull origin main' to sync this branch with the latest origin main, and resolve any merge conflicts. THEN proceed through the full lifecycle: create-plan, create-implementation-plan, create-testing-plan, plan-implementation, development, testing, reviewing. FINALLY, before pushing and opening the PR, run 'git pull origin main' again and resolve any merge conflicts that arose while you worked. Do not stop after planning."

    if ($JiraWorkflow) {
        & claude "/spec-workflow:orchestrator $Name — drive the full workflow end-to-end until a PR is opened. $syncNote"
    }
    elseif ($CopilotWorkflow) {
        $skill = ".github/skills/orchestrator/SKILL.md"
        if (Test-Path $skill) {
            $prompt = "Read $skill and execute it as your instructions for ticket $Name — drive the full workflow end-to-end until a PR is opened. $syncNote Each workflow step is a sibling skill under .github/skills/ — read each SKILL.md before executing it."
        }
        else {
            $prompt = "Use your installed spec-workflow skills to drive ticket $Name end-to-end until a PR is opened. Start with the 'orchestrator' skill, then run each lifecycle skill in sequence. $syncNote"
        }
        $flags = if ($env:GWT_COPILOT_FLAGS) { $env:GWT_COPILOT_FLAGS -split ' ' } else { @('--allow-all-tools') }

        if (Get-Command copilot -ErrorAction SilentlyContinue) {
            & copilot @flags -p $prompt
        }
        elseif (Get-Command gh -ErrorAction SilentlyContinue) {
            & gh copilot -- @flags -p $prompt
        }
        else {
            Write-Error "Neither 'copilot' nor 'gh' found on PATH."
        }
    }
    else {
        Write-Host "Worktree created and cwd changed. Launch your editor/agent manually."
    }
}
