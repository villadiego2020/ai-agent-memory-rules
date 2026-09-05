[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$powershellExecutable = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-$([Guid]::NewGuid().ToString('N'))"
$codexHome = Join-Path $temporaryRoot 'codex-home'
$claudeHome = Join-Path $temporaryRoot 'claude-home'
$projectRoot = Join-Path $temporaryRoot 'Example Project'
$projectSubdirectory = Join-Path $projectRoot 'src'
$reparseMemoryLink = ''
$originalCodexHome = if (Test-Path Env:CODEX_HOME) { [string]$env:CODEX_HOME } else { '' }
$originalClaudeConfigDir = if (Test-Path Env:CLAUDE_CONFIG_DIR) { [string]$env:CLAUDE_CONFIG_DIR } else { '' }

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-RepositoryScript {
    param([Parameter(Mandatory)][string]$RelativePath, [string[]]$Arguments = @())
    $scriptPath = Join-Path $repositoryRoot $RelativePath
    & $powershellExecutable -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$RelativePath exited with code $LASTEXITCODE." }
}

function Invoke-MemoryLoader {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$EventName,
        [int]$MaximumContextBytes = 20000
    )
    $payload = [ordered]@{
        session_id = 'integration-test'
        cwd = $WorkingDirectory
        hook_event_name = $EventName
        source = 'startup'
    } | ConvertTo-Json -Compress
    $loaderPath = Join-Path $codexHome 'hooks/load-project-memory.ps1'
    $invocationId = [Guid]::NewGuid().ToString('N')
    $inputPath = Join-Path $temporaryRoot "loader-$invocationId.stdin.json"
    $outputPath = Join-Path $temporaryRoot "loader-$invocationId.stdout.json"
    $errorPath = Join-Path $temporaryRoot "loader-$invocationId.stderr.txt"
    [System.IO.File]::WriteAllText($inputPath, $payload, [System.Text.UTF8Encoding]::new($false))
    $process = Start-Process -FilePath $powershellExecutable -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $loaderPath,
        '-MaximumContextBytes', $MaximumContextBytes
    ) -RedirectStandardInput $inputPath -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Memory loader exited with code $($process.ExitCode): $([System.IO.File]::ReadAllText($errorPath, [System.Text.Encoding]::UTF8))"
    }
    return [System.IO.File]::ReadAllText($outputPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

try {
    $env:CODEX_HOME = $codexHome
    $env:CLAUDE_CONFIG_DIR = $claudeHome
    New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $codexHome 'agents') -Force | Out-Null
    New-Item -ItemType Directory -Path $projectSubdirectory -Force | Out-Null
    & git init --quiet $projectRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the temporary Git repository.' }

    $unrelatedAgentPath = Join-Path $codexHome 'agents/custom-local.toml'
    [System.IO.File]::WriteAllText($unrelatedAgentPath, "name = `"custom-local`"")
    $hooksPath = Join-Path $codexHome 'hooks.json'
    $originalHooks = [ordered]@{
        hooks = [ordered]@{
            SessionStart = @([ordered]@{
                matcher = 'startup'
                hooks = @([ordered]@{ type = 'command'; command = 'echo existing'; statusMessage = 'Existing session hook' })
            })
            Stop = @([ordered]@{
                hooks = @([ordered]@{ type = 'command'; command = 'echo stop'; statusMessage = 'Existing stop hook' })
            })
        }
    }
    [System.IO.File]::WriteAllText($hooksPath, (($originalHooks | ConvertTo-Json -Depth 12) + [Environment]::NewLine))

    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.agent-memory'))) -Message 'Fixture starts without project Memory.'
    Invoke-RepositoryScript -RelativePath 'scripts/install.ps1' -Arguments @('-Platform', 'Codex', '-Mode', 'Copy', '-CodexSkillsHome', (Join-Path $temporaryRoot 'codex-skills'), '-CodexHome', $codexHome)
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $codexHome 'AGENTS.md') -PathType Leaf) -Message 'Codex AGENTS.md was installed.'
    Assert-True -Condition (Test-Path -LiteralPath $unrelatedAgentPath -PathType Leaf) -Message 'Unrelated agent was preserved.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.agent-memory'))) -Message 'Installer did not initialize project Memory.'

    $installedHooks = Get-Content -LiteralPath $hooksPath -Raw | ConvertFrom-Json
    Assert-True -Condition (@($installedHooks.hooks.SessionStart).Count -eq 2) -Message 'Existing SessionStart hook was preserved.'
    Assert-True -Condition (@($installedHooks.hooks.SubagentStart).Count -eq 1) -Message 'SubagentStart Memory hook was installed.'
    Assert-True -Condition (@($installedHooks.hooks.Stop).Count -eq 1) -Message 'Unrelated Stop hook was preserved.'

    $backupManifestCountBefore = @(Get-ChildItem -LiteralPath (Join-Path $codexHome '.ai-agent-memory-rules/backups') -Filter 'manifest.json' -File -Recurse).Count
    Invoke-RepositoryScript -RelativePath 'scripts/install.ps1' -Arguments @('-Platform', 'Codex', '-Mode', 'Copy', '-CodexSkillsHome', (Join-Path $temporaryRoot 'codex-skills'), '-CodexHome', $codexHome)
    $backupManifestCountAfter = @(Get-ChildItem -LiteralPath (Join-Path $codexHome '.ai-agent-memory-rules/backups') -Filter 'manifest.json' -File -Recurse).Count
    Assert-True -Condition ($backupManifestCountBefore -eq $backupManifestCountAfter) -Message 'Idempotent reinstall created no backup.'

    Invoke-RepositoryScript -RelativePath 'scripts/initialize-memory.ps1' -Arguments @('-ProjectPath', $projectSubdirectory)
    $memoryDirectory = Join-Path $projectRoot '.agent-memory'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $memoryDirectory 'MEMORY.md') -PathType Leaf) -Message 'Memory initialized at the Git root.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $projectSubdirectory '.agent-memory'))) -Message 'Initializer did not use the Git subdirectory.'

    $memoryIndexPath = Join-Path $memoryDirectory 'MEMORY.md'
    [System.IO.File]::WriteAllText($memoryIndexPath, 'preserve-existing-memory')
    Invoke-RepositoryScript -RelativePath 'scripts/initialize-memory.ps1' -Arguments @('-ProjectPath', $projectRoot)
    Assert-True -Condition ((Get-Content -LiteralPath $memoryIndexPath -Raw) -eq 'preserve-existing-memory') -Message 'Idempotent initialization preserved existing Memory.'

    [System.IO.File]::WriteAllText($memoryIndexPath, ('Verified project context. ' * 500))
    $sessionOutput = Invoke-MemoryLoader -WorkingDirectory $projectSubdirectory -EventName 'SessionStart' -MaximumContextBytes 4096
    Assert-True -Condition ($sessionOutput.hookSpecificOutput.hookEventName -eq 'SessionStart') -Message 'SessionStart shape is correct.'
    Assert-True -Condition ([string]$sessionOutput.hookSpecificOutput.additionalContext -like "*$projectRoot*") -Message 'Loader resolved the Git root.'
    Assert-True -Condition ([string]$sessionOutput.hookSpecificOutput.additionalContext -like '*Project Memory truncated*') -Message 'Loader marked truncation.'
    Assert-True -Condition (([System.Text.Encoding]::UTF8.GetByteCount([string]$sessionOutput.hookSpecificOutput.additionalContext)) -le 4096) -Message 'Loader honored the UTF-8 cap.'

    $subagentOutput = Invoke-MemoryLoader -WorkingDirectory $projectRoot -EventName 'SubagentStart'
    Assert-True -Condition ($subagentOutput.hookSpecificOutput.hookEventName -eq 'SubagentStart') -Message 'SubagentStart shape is correct.'

    [System.IO.File]::WriteAllText((Join-Path $memoryDirectory 'MEMORY.md'), 'memory-index-marker')
    [System.IO.File]::WriteAllText((Join-Path $memoryDirectory 'user_and_feedback.md'), 'feedback-index-marker')
    [System.IO.File]::WriteAllText((Join-Path $memoryDirectory 'project_open_work.md'), 'open-work-index-marker')
    [System.IO.File]::WriteAllText((Join-Path $memoryDirectory 'project_archive.md'), 'archive-index-marker')
    [System.IO.File]::WriteAllText((Join-Path $memoryDirectory 'work/private-detail.md'), 'private-detail-must-not-load')
    $allowlistContext = [string](Invoke-MemoryLoader -WorkingDirectory $projectRoot -EventName 'SessionStart').hookSpecificOutput.additionalContext
    foreach ($indexMarker in @('memory-index-marker', 'feedback-index-marker', 'open-work-index-marker', 'archive-index-marker')) {
        Assert-True -Condition ($allowlistContext -like "*$indexMarker*") -Message "Loader included '$indexMarker'."
    }
    Assert-True -Condition ($allowlistContext -notlike '*private-detail-must-not-load*') -Message 'Loader did not read detail files.'
    [System.IO.File]::Delete((Join-Path $memoryDirectory 'work/private-detail.md'))
    foreach ($indexName in @('MEMORY.md', 'user_and_feedback.md', 'project_open_work.md', 'project_archive.md')) {
        Copy-Item -LiteralPath (Join-Path $repositoryRoot "templates/memory/$indexName") -Destination (Join-Path $memoryDirectory $indexName) -Force
    }

    $missingProject = Join-Path $temporaryRoot 'No Memory Project'
    New-Item -ItemType Directory -Path $missingProject -Force | Out-Null
    $legacyMemory = Join-Path $codexHome 'projects/legacy-key/memory'
    New-Item -ItemType Directory -Path $legacyMemory -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $legacyMemory 'MEMORY.md'), 'legacy-home-memory-must-not-load')
    $legacyClaudeMemory = Join-Path $claudeHome 'projects/legacy-key/memory'
    New-Item -ItemType Directory -Path $legacyClaudeMemory -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $legacyClaudeMemory 'MEMORY.md'), 'legacy-claude-memory-must-not-load')
    $missingContext = [string](Invoke-MemoryLoader -WorkingDirectory $missingProject -EventName 'SessionStart').hookSpecificOutput.additionalContext
    Assert-True -Condition ($missingContext -like '*has not been initialized*') -Message 'Missing local Memory is non-fatal.'
    Assert-True -Condition ($missingContext -notlike '*legacy-home-memory-must-not-load*') -Message 'Loader did not use legacy user-home Memory.'
    Assert-True -Condition ($missingContext -notlike '*legacy-claude-memory-must-not-load*') -Message 'Loader did not use legacy Claude-home Memory.'
    Assert-True -Condition ($missingContext -like "*$(Join-Path $missingProject '.agent-memory')*") -Message 'Guidance points to project-local Memory.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $missingProject '.agent-memory'))) -Message 'Loader did not create missing project Memory.'

    $outsideMemory = Join-Path $temporaryRoot 'Outside Memory Index'
    $reparseProject = Join-Path $temporaryRoot 'Reparse Project'
    New-Item -ItemType Directory -Path $outsideMemory -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $reparseProject '.git') -Force | Out-Null
    $reparseMemoryRoot = Join-Path $reparseProject '.agent-memory'
    New-Item -ItemType Directory -Path $reparseMemoryRoot -Force | Out-Null
    foreach ($indexName in @('user_and_feedback.md', 'project_open_work.md', 'project_archive.md')) {
        [System.IO.File]::WriteAllText((Join-Path $reparseMemoryRoot $indexName), 'safe-index')
    }
    [System.IO.File]::WriteAllText((Join-Path $outsideMemory 'private.txt'), 'reparse-target-must-not-load')
    $reparseMemoryLink = Join-Path $reparseMemoryRoot 'MEMORY.md'
    New-Item -ItemType Junction -Path $reparseMemoryLink -Target $outsideMemory | Out-Null
    $reparseContext = [string](Invoke-MemoryLoader -WorkingDirectory $reparseProject -EventName 'SessionStart').hookSpecificOutput.additionalContext
    $reparseRejected = $reparseContext -like '*cannot be a symbolic link or reparse point*' -or $reparseContext -like '*Memory index is not a file*'
    Assert-True -Condition $reparseRejected -Message 'Loader rejected a reparse-point index.'
    Assert-True -Condition ($reparseContext -notlike '*reparse-target-must-not-load*') -Message 'Loader did not read through a reparse-point index.'

    Invoke-RepositoryScript -RelativePath 'scripts/validate.ps1' -Arguments @('-Installed', '-Platform', 'Codex', '-CodexSkillsHome', (Join-Path $temporaryRoot 'codex-skills'), '-CodexHome', $codexHome, '-ProjectPath', $projectRoot)

    $installedAgentsPath = Join-Path $codexHome 'AGENTS.md'
    [System.IO.File]::AppendAllText($installedAgentsPath, "`nlocal modification")
    $failureOut = Join-Path $temporaryRoot 'expected-failure.stdout.txt'
    $failureErr = Join-Path $temporaryRoot 'expected-failure.stderr.txt'
    $failureProcess = Start-Process -FilePath $powershellExecutable -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $repositoryRoot 'scripts/install.ps1'),
        '-Platform', 'Codex', '-Mode', 'Copy', '-CodexSkillsHome', (Join-Path $temporaryRoot 'codex-skills'), '-CodexHome', $codexHome
    ) -RedirectStandardOutput $failureOut -RedirectStandardError $failureErr -WindowStyle Hidden -Wait -PassThru
    Assert-True -Condition ($failureProcess.ExitCode -ne 0) -Message 'Installer rejected a conflict without Force.'

    Invoke-RepositoryScript -RelativePath 'scripts/install.ps1' -Arguments @('-Platform', 'Codex', '-Mode', 'Copy', '-CodexSkillsHome', (Join-Path $temporaryRoot 'codex-skills'), '-CodexHome', $codexHome, '-Force')
    $forcedBackups = @(Get-ChildItem -LiteralPath (Join-Path $codexHome '.ai-agent-memory-rules/backups') -Filter 'manifest.json' -File -Recurse)
    Assert-True -Condition ($forcedBackups.Count -gt $backupManifestCountAfter) -Message 'Force created a backup manifest.'

    $memoryHashBeforeUninstall = (Get-FileHash -LiteralPath $memoryIndexPath -Algorithm SHA256).Hash
    Invoke-RepositoryScript -RelativePath 'scripts/uninstall.ps1' -Arguments @('-Platform', 'Codex', '-CodexSkillsHome', (Join-Path $temporaryRoot 'codex-skills'), '-CodexHome', $codexHome)
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $codexHome 'AGENTS.md'))) -Message 'Managed AGENTS.md was removed.'
    Assert-True -Condition (Test-Path -LiteralPath $unrelatedAgentPath -PathType Leaf) -Message 'Unrelated agent remained.'
    Assert-True -Condition ((Get-FileHash -LiteralPath $memoryIndexPath -Algorithm SHA256).Hash -eq $memoryHashBeforeUninstall) -Message 'Uninstall did not change project Memory.'
    $remainingHooks = Get-Content -LiteralPath $hooksPath -Raw | ConvertFrom-Json
    Assert-True -Condition (@($remainingHooks.hooks.SessionStart).Count -eq 1) -Message 'Existing SessionStart hook remained.'
    Assert-True -Condition (@($remainingHooks.hooks.Stop).Count -eq 1) -Message 'Existing Stop hook remained.'
    Assert-True -Condition (@($remainingHooks.hooks.SubagentStart).Count -eq 0) -Message 'Managed SubagentStart hook was removed.'

    $previewHome = Join-Path $temporaryRoot 'preview-home'
    Invoke-RepositoryScript -RelativePath 'scripts/install.ps1' -Arguments @('-Platform', 'Codex', '-Mode', 'Link', '-CodexSkillsHome', (Join-Path $temporaryRoot 'preview-skills'), '-CodexHome', $previewHome, '-WhatIf')
    Assert-True -Condition (-not (Test-Path -LiteralPath $previewHome)) -Message 'Install WhatIf changed no destination.'

    $memoryHashBeforeClaude = (Get-FileHash -LiteralPath $memoryIndexPath -Algorithm SHA256).Hash
    Invoke-RepositoryScript -RelativePath 'scripts/install.ps1' -Arguments @('-Platform', 'Claude', '-Mode', 'Copy', '-ClaudeHome', $claudeHome)
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $claudeHome 'CLAUDE.md') -PathType Leaf) -Message 'Claude rules installed.'
    Assert-True -Condition (@(Get-ChildItem -LiteralPath (Join-Path $claudeHome 'agents') -Filter '*.md' -File).Count -eq 13) -Message 'Claude agents installed.'
    Invoke-RepositoryScript -RelativePath 'scripts/validate.ps1' -Arguments @('-Installed', '-Platform', 'Claude', '-ClaudeHome', $claudeHome, '-ProjectPath', $projectRoot)
    Invoke-RepositoryScript -RelativePath 'scripts/uninstall.ps1' -Arguments @('-Platform', 'Claude', '-ClaudeHome', $claudeHome)
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $claudeHome 'CLAUDE.md'))) -Message 'Claude rules uninstalled.'
    Assert-True -Condition ((Get-FileHash -LiteralPath $memoryIndexPath -Algorithm SHA256).Hash -eq $memoryHashBeforeClaude) -Message 'Claude lifecycle did not change Memory.'

    Write-Host 'Integration tests passed.'
} finally {
    if ([string]::IsNullOrWhiteSpace($originalCodexHome)) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $originalCodexHome }
    if ([string]::IsNullOrWhiteSpace($originalClaudeConfigDir)) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_CONFIG_DIR = $originalClaudeConfigDir }
    if (-not [string]::IsNullOrWhiteSpace($reparseMemoryLink) -and (Test-Path -LiteralPath $reparseMemoryLink)) {
        [System.IO.Directory]::Delete($reparseMemoryLink)
    }
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
