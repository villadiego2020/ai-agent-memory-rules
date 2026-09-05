[CmdletBinding()]
param(
    [string]$RepositoryRoot = '',
    [switch]$Installed,
    [ValidateSet('Codex', 'Claude')]
    [string]$Platform = 'Codex',
    [string]$CodexHome = '',
    [string]$CodexSkillsHome = '',
    [string]$ClaudeHome = '',
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/MemoryRules.Common.ps1')

$resolvedRepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    Get-MemoryRulesRepositoryRoot -CallingScriptRoot $PSScriptRoot
} else {
    [System.IO.Path]::GetFullPath($RepositoryRoot)
}
$failures = [System.Collections.Generic.List[string]]::new()

function Add-ValidationFailure {
    param([Parameter(Mandatory)][string]$Message)
    $failures.Add($Message)
}

function Test-RequiredPath {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [ValidateSet('Leaf', 'Container')]
        [string]$PathType = 'Leaf'
    )

    $path = Join-Path $resolvedRepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType $PathType)) {
        Add-ValidationFailure -Message "Missing required $PathType path: $RelativePath"
    }
}

function Test-MemoryIndexMapping {
    param(
        [Parameter(Mandatory)][string[]]$IndexPaths,
        [Parameter(Mandatory)][string]$IndexDisplayName,
        [Parameter(Mandatory)][string]$DetailDirectory,
        [Parameter(Mandatory)][string]$RelativeDirectory
    )

    $existingIndexPaths = @($IndexPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($existingIndexPaths.Count -eq 0) {
        return
    }
    if (-not (Test-Path -LiteralPath $DetailDirectory -PathType Container)) {
        return
    }

    $escapedDirectory = [regex]::Escape($RelativeDirectory)
    $indexLinks = @(
        foreach ($indexPath in $existingIndexPaths) {
            $indexItem = Get-Item -LiteralPath $indexPath -Force
            if (($indexItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                continue
            }

            $indexContent = Get-Content -LiteralPath $indexPath -Raw
            [regex]::Matches($indexContent, "(?i)\[([^\]]+)\]\((?:\./)?$escapedDirectory/([^)]+\.md)\)") |
                ForEach-Object {
                    [pscustomobject]@{
                        Label = $_.Groups[1].Value.Trim()
                        FileName = $_.Groups[2].Value
                    }
                }
        }
    )
    $detailFileNames = @(
        Get-ChildItem -LiteralPath $DetailDirectory -Filter '*.md' -File |
            ForEach-Object Name
    )
    foreach ($detailFileName in $detailFileNames) {
        $matchingLinks = @($indexLinks | Where-Object { $_.FileName -eq $detailFileName })
        if ($matchingLinks.Count -eq 0) {
            Add-ValidationFailure -Message "$IndexDisplayName does not index $RelativeDirectory/$detailFileName. Add one [detail] link."
            continue
        }

        $primaryLinks = @($matchingLinks | Where-Object { $_.Label -eq 'detail' })
        if ($primaryLinks.Count -gt 1) {
            Add-ValidationFailure -Message "$IndexDisplayName contains $($primaryLinks.Count) primary [detail] links to $RelativeDirectory/$detailFileName; keep exactly one."
        }
    }
    foreach ($linkedFileName in @($indexLinks | ForEach-Object FileName | Sort-Object -Unique)) {
        if ($linkedFileName -notin $detailFileNames) {
            Add-ValidationFailure -Message "$IndexDisplayName links to a missing file: $RelativeDirectory/$linkedFileName"
        }
    }
}

foreach ($requiredFile in @(
    'README.md',
    'RULES.md',
    'codex/AGENTS.md',
    'codex/hooks.fragment.json',
    'codex/hooks/load-project-memory.ps1',
    'templates/memory/MEMORY.md',
    'templates/memory/user_and_feedback.md',
    'templates/memory/project_open_work.md',
    'templates/memory/project_archive.md',
    'scripts/install.ps1',
    'scripts/initialize-memory.ps1',
    'scripts/migrate-memory.ps1',
    'scripts/validate.ps1',
    'scripts/uninstall.ps1',
    'scripts/lib/MemoryRules.Common.ps1',
    'skills/game-workflow/SKILL.md',
    'tests/integration.ps1'
)) {
    Test-RequiredPath -RelativePath $requiredFile
}
foreach ($requiredDirectory in @(
    'templates/memory/work',
    'templates/memory/archive',
    'templates/memory/analysis',
    'codex/agents'
)) {
    Test-RequiredPath -RelativePath $requiredDirectory -PathType Container
}

$skillRoot = Join-Path $resolvedRepositoryRoot 'skills/game-workflow'
$skillPath = Join-Path $skillRoot 'SKILL.md'
if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skillContent = Get-Content -LiteralPath $skillPath -Raw
    if ($skillContent -notmatch '(?s)\A---\r?\n.*?\r?\n---') {
        Add-ValidationFailure -Message 'game-workflow requires YAML frontmatter.'
    }
    foreach ($fieldPattern in @('(?m)^name:\s*game-workflow\s*$', '(?m)^description:\s*\S.+$')) {
        if ($skillContent -notmatch $fieldPattern) { Add-ValidationFailure -Message "Invalid game-workflow skill field: $fieldPattern" }
    }
    foreach ($reference in [regex]::Matches($skillContent, 'references/[A-Za-z0-9._/-]+\.md')) {
        $referencePath = Join-Path $skillRoot $reference.Value
        if (-not (Test-MemoryPathInsideRoot -Path $referencePath -Root $skillRoot) -or -not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
            Add-ValidationFailure -Message "Invalid skill reference: $($reference.Value)"
        }
    }
}

$agentsPath = Join-Path $resolvedRepositoryRoot 'codex/AGENTS.md'
if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
    $agentsBytes = ([System.Text.Encoding]::UTF8).GetByteCount([System.IO.File]::ReadAllText($agentsPath))
    if ($agentsBytes -ge 24576) {
        Add-ValidationFailure -Message "codex/AGENTS.md is $agentsBytes bytes; it must stay below 24576 bytes."
    }
}

$expectedAgentNames = @(
    '3d-animator', '3d-modeller', '3d-rigger', '3d-sculptor',
    'backend-architect', 'game-architect', 'network-expert', 'project-manager',
    'system-planner', 'system-tester', 'unity-expert', 'uxui-expert', 'web-expert'
)
$readOnlyAgentNames = @(
    'backend-architect',
    'game-architect',
    'network-expert',
    'project-manager',
    'system-planner',
    'uxui-expert'
)
$agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $resolvedRepositoryRoot 'codex/agents') -Filter '*.toml' -File -ErrorAction SilentlyContinue)
if ($agentFiles.Count -ne $expectedAgentNames.Count) {
    Add-ValidationFailure -Message "Expected $($expectedAgentNames.Count) Codex agent files, found $($agentFiles.Count)."
}
foreach ($agentName in $expectedAgentNames) {
    $agentPath = Join-Path $resolvedRepositoryRoot "codex/agents/$agentName.toml"
    if (-not (Test-Path -LiteralPath $agentPath -PathType Leaf)) {
        Add-ValidationFailure -Message "Missing Codex agent: $agentName"
        continue
    }

    $agentContent = Get-Content -LiteralPath $agentPath -Raw
    foreach ($requiredField in @('name', 'description', 'developer_instructions')) {
        if ($agentContent -notmatch "(?m)^$requiredField\s*=") {
            Add-ValidationFailure -Message "$agentName.toml is missing required field '$requiredField'."
        }
    }
    if ($agentContent -notmatch "(?m)^name\s*=\s*`"$([regex]::Escape($agentName))`"\s*$") {
        Add-ValidationFailure -Message "$agentName.toml has a name that does not match its filename."
    }
    if ($agentContent -match '(?m)^model(_reasoning_effort)?\s*=') {
        Add-ValidationFailure -Message "$agentName.toml pins a model or reasoning effort; public defaults must inherit user settings."
    }
    if ($agentName -in $readOnlyAgentNames -and $agentContent -notmatch '(?m)^sandbox_mode\s*=\s*"read-only"\s*$') {
        Add-ValidationFailure -Message "$agentName.toml must enforce a read-only sandbox."
    }
    if ($agentContent -notmatch '<project-root>/\.agent-memory' -or $agentContent -notmatch 'read-only') {
        Add-ValidationFailure -Message "$agentName.toml must use project-local .agent-memory as read-only context."
    }
}

$claudeAgentFiles = @(Get-ChildItem -LiteralPath (Join-Path $resolvedRepositoryRoot 'agents') -Filter '*.md' -File -ErrorAction SilentlyContinue | Where-Object Name -ne 'README.md')
if ($claudeAgentFiles.Count -ne $expectedAgentNames.Count) {
    Add-ValidationFailure -Message "Expected $($expectedAgentNames.Count) Claude agent files, found $($claudeAgentFiles.Count)."
}
foreach ($agentName in $expectedAgentNames) {
    $claudeAgentPath = Join-Path $resolvedRepositoryRoot "agents/$agentName.md"
    if (-not (Test-Path -LiteralPath $claudeAgentPath -PathType Leaf)) {
        Add-ValidationFailure -Message "Missing Claude agent: $agentName"
        continue
    }
    $claudeAgentContent = Get-Content -LiteralPath $claudeAgentPath -Raw
    if ($claudeAgentContent -notmatch '<project-root>/\.agent-memory/' -or $claudeAgentContent -notmatch 'อ่านอย่างเดียว') {
        Add-ValidationFailure -Message "$agentName.md must use project-local .agent-memory as read-only context."
    }
}

$commitConventionLines = @(
    'Work files and Memory must be separate commits by default.',
    'Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.',
    'All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.',
    'A commit containing only `.agent-memory/**` uses `[Memory] <message>`.',
    'Never mix unrelated Bug and Feature work; split them into separate commits.',
    'Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.',
    'Commit Memory to the current project repository and branch.',
    'Push follows the current project''s normal authorization and policy. Never auto-push merely because Memory changed.'
)
foreach ($rulesRelativePath in @('README.md', 'RULES.md', 'codex/AGENTS.md')) {
    $rulesContent = Get-Content -LiteralPath (Join-Path $resolvedRepositoryRoot $rulesRelativePath) -Raw
    foreach ($commitConventionLine in $commitConventionLines) {
        if (-not $rulesContent.Contains($commitConventionLine)) {
            Add-ValidationFailure -Message "$rulesRelativePath is missing a required commit convention line: $commitConventionLine"
        }
    }
}

$fragmentPath = Join-Path $resolvedRepositoryRoot 'codex/hooks.fragment.json'
if (Test-Path -LiteralPath $fragmentPath -PathType Leaf) {
    try {
        $fragment = Get-Content -LiteralPath $fragmentPath -Raw | ConvertFrom-Json
        if (-not $fragment.hooks.SessionStart -or -not $fragment.hooks.SubagentStart) {
            Add-ValidationFailure -Message 'Hook fragment must define SessionStart and SubagentStart.'
        }
        if ([string]@($fragment.hooks.SessionStart)[0].matcher -ne 'startup|resume|clear|compact') {
            Add-ValidationFailure -Message 'SessionStart matcher must cover startup, resume, clear, and compact.'
        }
    } catch {
        Add-ValidationFailure -Message "codex/hooks.fragment.json is invalid JSON: $($_.Exception.Message)"
    }
}

$parser = [System.Management.Automation.Language.Parser]
$forbiddenInvokeCommand = 'Invoke' + '-Expression'
$recursiveRemovalPattern = '(?i)Remove' + '-Item[^\r\n]*-Recurse'
$powershellFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $resolvedRepositoryRoot 'scripts') -Filter '*.ps1' -File -Recurse
) + @(
    Get-ChildItem -LiteralPath (Join-Path $resolvedRepositoryRoot 'tests') -Filter '*.ps1' -File -Recurse
)
$powershellFiles |
    ForEach-Object {
        $tokens = $parseErrors = $null
        $parser::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        foreach ($parseError in $parseErrors) {
            Add-ValidationFailure -Message "$($_.FullName): $($parseError.Message)"
        }
        $scriptContent = Get-Content -LiteralPath $_.FullName -Raw
        if ($scriptContent -match [regex]::Escape($forbiddenInvokeCommand)) {
            Add-ValidationFailure -Message "$($_.FullName) uses forbidden dynamic command evaluation."
        }
        if ($scriptContent -match $recursiveRemovalPattern) {
            Add-ValidationFailure -Message "$($_.FullName) uses recursive deletion."
        }
    }

$legacyRuntimePatterns = @(
    ('\.codex' + '[/\\]projects'),
    ('\.claude' + '[/\\]projects'),
    ('CODEX_HOME' + '[/\\]projects'),
    ('CLAUDE_HOME' + '[/\\]projects'),
    ('ConvertTo-Memory' + 'ProjectKey'),
    ('claude-' + 'memory'),
    ('claude-' + 'agents'),
    ('C:\\Users\\' + '[^<\\\s]+')
)
$legacyScanFiles = @(Get-ChildItem -LiteralPath $resolvedRepositoryRoot -Recurse -File) |
    Where-Object {
        $relativePath = $_.FullName.Substring($resolvedRepositoryRoot.Length).TrimStart('\', '/')
        $relativePath -notmatch '^(?i:tests)[/\\]' -and
        $relativePath -ne 'scripts\migrate-memory.ps1' -and
        $relativePath -ne 'scripts/migrate-memory.ps1' -and
        $relativePath -notmatch '^(?i:\.git)[/\\]'
    }
foreach ($scanFile in $legacyScanFiles) {
    $scanContent = Get-Content -LiteralPath $scanFile.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($legacyPattern in $legacyRuntimePatterns) {
        if ($scanContent -match $legacyPattern) {
            $relativePath = $scanFile.FullName.Substring($resolvedRepositoryRoot.Length).TrimStart('\', '/')
            Add-ValidationFailure -Message "Legacy or personal runtime path found outside migration/tests: $relativePath"
            break
        }
    }
}

$archiveTemplatePath = Join-Path $resolvedRepositoryRoot 'templates/memory/project_archive.md'
if (Test-Path -LiteralPath $archiveTemplatePath -PathType Leaf) {
    $archiveTemplate = Get-Content -LiteralPath $archiveTemplatePath -Raw
    foreach ($heading in @('BUGS', 'IMPROVE / OPTIMIZE', 'REFACTOR', 'FEATURE', 'ANALYSIS')) {
        if ($archiveTemplate -notmatch "(?m)^# $([regex]::Escape($heading))\s*$") {
            Add-ValidationFailure -Message "Archive template is missing exact heading '$heading'."
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
    $requestedProjectPath = Get-MemoryCanonicalPath -Path $ProjectPath
    if (-not (Test-Path -LiteralPath $requestedProjectPath -PathType Container)) {
        Add-ValidationFailure -Message "Project path does not exist or is not a directory: $requestedProjectPath"
    } else {
        $projectRoot = Get-MemoryProjectRoot -WorkingDirectory $requestedProjectPath
        $memoryRoot = Join-Path $projectRoot '.agent-memory'
        if (-not (Test-Path -LiteralPath $memoryRoot -PathType Container)) {
            Add-ValidationFailure -Message "Project Memory is not initialized: $memoryRoot"
        } else {
            try {
                Assert-MemoryPathIsNotReparsePoint -Path $memoryRoot -Purpose 'Project Memory directory'
            } catch {
                Add-ValidationFailure -Message $_.Exception.Message
            }

            foreach ($requiredIndex in @('MEMORY.md', 'user_and_feedback.md', 'project_open_work.md', 'project_archive.md')) {
                $indexPath = Join-Path $memoryRoot $requiredIndex
                if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
                    Add-ValidationFailure -Message "Project Memory is missing required index: $indexPath"
                    continue
                }
                try {
                    Assert-MemoryPathIsNotReparsePoint -Path $indexPath -Purpose 'Project Memory index'
                } catch {
                    Add-ValidationFailure -Message $_.Exception.Message
                }
            }
            foreach ($requiredDetailDirectory in @('work', 'archive', 'analysis')) {
                $detailPath = Join-Path $memoryRoot $requiredDetailDirectory
                if (-not (Test-Path -LiteralPath $detailPath -PathType Container)) {
                    Add-ValidationFailure -Message "Project Memory is missing required directory: $detailPath"
                }
            }

            $openIndexPath = Join-Path $memoryRoot 'project_open_work.md'
            $archiveIndexPath = Join-Path $memoryRoot 'project_archive.md'
            $workDirectory = Join-Path $memoryRoot 'work'
            $archiveIndexPaths = @()
            $currentArchiveIndexItem = Get-Item -LiteralPath $archiveIndexPath -Force -ErrorAction SilentlyContinue
            if ($currentArchiveIndexItem -and -not (($currentArchiveIndexItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                $archiveIndexPaths += $currentArchiveIndexItem.FullName
            }
            foreach ($annualIndexItem in @(Get-ChildItem -LiteralPath $memoryRoot -Filter 'project_archive_*.md' -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
                if ($annualIndexItem.PSIsContainer) {
                    Add-ValidationFailure -Message "Annual project archive index is not a file: $($annualIndexItem.FullName)"
                    continue
                }
                if (($annualIndexItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    Add-ValidationFailure -Message "Annual project archive index cannot be a symbolic link or reparse point: $($annualIndexItem.FullName)"
                    continue
                }
                if (-not (Test-MemoryPathInsideRoot -Path $annualIndexItem.FullName -Root $memoryRoot)) {
                    Add-ValidationFailure -Message "Annual project archive index escaped the project Memory directory: $($annualIndexItem.FullName)"
                    continue
                }
                $archiveIndexPaths += $annualIndexItem.FullName
            }

            if ($currentArchiveIndexItem -and $currentArchiveIndexItem.FullName -in $archiveIndexPaths) {
                $projectArchiveContent = Get-Content -LiteralPath $archiveIndexPath -Raw
                foreach ($heading in @('BUGS', 'IMPROVE / OPTIMIZE', 'REFACTOR', 'FEATURE', 'ANALYSIS')) {
                    if ($projectArchiveContent -notmatch "(?m)^#{1,2} $([regex]::Escape($heading))\s*$") {
                        Add-ValidationFailure -Message "Project archive is missing exact heading '$heading': $archiveIndexPath"
                    }
                }
            }
            Test-MemoryIndexMapping -IndexPaths @($openIndexPath) -IndexDisplayName 'project_open_work.md' -DetailDirectory $workDirectory -RelativeDirectory 'work'
            Test-MemoryIndexMapping -IndexPaths $archiveIndexPaths -IndexDisplayName 'project_archive.md and annual indexes' -DetailDirectory (Join-Path $memoryRoot 'archive') -RelativeDirectory 'archive'
            Test-MemoryIndexMapping -IndexPaths $archiveIndexPaths -IndexDisplayName 'project_archive.md and annual indexes' -DetailDirectory (Join-Path $memoryRoot 'analysis') -RelativeDirectory 'analysis'

            if (Test-Path -LiteralPath $workDirectory -PathType Container) {
                foreach ($workFile in @(Get-ChildItem -LiteralPath $workDirectory -Filter '*.md' -File)) {
                    $workContent = Get-Content -LiteralPath $workFile.FullName -Raw
                    if ($workContent -notmatch '(?m)^\*\*Ready status:\*\* (?:Ready|BLOCKED - waiting for .+)$') {
                        Add-ValidationFailure -Message "Open work file is missing a valid Ready status line: $($workFile.FullName)"
                    }
                }
            }
        }
    }
}

if ($Installed) {
    $configurationHome = if ($Platform -eq 'Codex') {
        Get-CodexConfigurationHome -OverridePath $CodexHome
    } else {
        Get-ClaudeConfigurationHome -OverridePath $ClaudeHome
    }
    $manifestPath = Join-Path $configurationHome '.ai-agent-memory-rules/install-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        Add-ValidationFailure -Message "Installation manifest not found: $manifestPath"
    } else {
        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $skillsHome = if ($Platform -eq 'Codex') { Get-CodexSkillsHome -OverridePath $CodexSkillsHome } else { Join-Path $configurationHome 'skills' }
            foreach ($expectedSkill in @(Get-SharedSkillManagedFiles -RepositoryRoot $resolvedRepositoryRoot -ConfigurationHome $configurationHome -SkillsHome $skillsHome)) {
                if ($expectedSkill.Target -notin @($manifest.managedFiles.target)) {
                    Add-ValidationFailure -Message "Installed skill is not managed: $($expectedSkill.Target)"
                }
            }
            foreach ($managedFile in @($manifest.managedFiles)) {
                if (-not (Test-Path -LiteralPath $managedFile.target -PathType Leaf)) {
                    Add-ValidationFailure -Message "Installed managed file is missing: $($managedFile.target)"
                    continue
                }

                $managedFileIsCurrent = if ($manifest.mode -eq 'Link') {
                    Test-SymbolicLinkTargetsPath -LinkPath $managedFile.target -ExpectedTarget $managedFile.source
                } else {
                    (Get-FileSha256 -Path $managedFile.target) -eq [string]$managedFile.installedHash
                }
                if (-not $managedFileIsCurrent) {
                    Add-ValidationFailure -Message "Installed managed file changed or points to the wrong source: $($managedFile.target)"
                }
            }

            if ($Platform -eq 'Codex') {
                $installedHooksPath = Join-Path $configurationHome 'hooks.json'
                if (-not (Test-Path -LiteralPath $installedHooksPath -PathType Leaf)) {
                    Add-ValidationFailure -Message "Installed Codex hooks file is missing: $installedHooksPath"
                } else {
                    $installedHooks = Get-Content -LiteralPath $installedHooksPath -Raw | ConvertFrom-Json
                    foreach ($eventName in @('SessionStart', 'SubagentStart')) {
                        $managedHandlerCount = @(
                            @($installedHooks.hooks.$eventName).hooks |
                                Where-Object { [string]$_.statusMessage -like '*(ai-agent-memory-rules)*' }
                        ).Count
                        if ($managedHandlerCount -ne 1) {
                            Add-ValidationFailure -Message "Installed hooks must contain one managed $eventName handler; found $managedHandlerCount."
                        }
                    }
                }
            }
        } catch {
            Add-ValidationFailure -Message "Installation manifest is invalid: $($_.Exception.Message)"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Error ("Validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Host "Validation passed for '$resolvedRepositoryRoot'."
if ($Installed) {
    Write-Host "$Platform installation validation passed."
}
