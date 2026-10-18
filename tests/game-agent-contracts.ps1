[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures = [System.Collections.Generic.List[string]]::new()

function Add-ContractFailure {
    param([Parameter(Mandatory)][string]$Message)

    $failures.Add($Message)
}

function Get-RepositoryText {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-ContractFailure -Message "Missing required profile: $RelativePath"
        return ''
    }

    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Test-ContractPatterns {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][hashtable]$Contracts
    )

    $content = Get-RepositoryText -RelativePath $RelativePath
    if ([string]::IsNullOrWhiteSpace($content)) {
        return
    }

    $roleName = [IO.Path]::GetFileNameWithoutExtension($RelativePath)
    $referenceMap = @{
        'uxui-expert' = @('ux-ui')
        'game-architect' = @('architecture')
        'unity-expert' = @('architecture', 'unity-runtime')
        'network-expert' = @('networking')
        'system-tester' = @('testing')
    }
    if ($referenceMap.ContainsKey($roleName)) {
        if ($content -notmatch 'game-workflow') { Add-ContractFailure -Message "$RelativePath must route to shared game-workflow guidance." }
        foreach ($referenceName in $referenceMap[$roleName]) {
            $content += "`n" + (Get-RepositoryText -RelativePath "skills/game-workflow/references/$referenceName.md")
        }
    }
    foreach ($contractName in $Contracts.Keys) {
        foreach ($pattern in @($Contracts[$contractName])) {
            if ($content -notmatch $pattern) {
                Add-ContractFailure -Message "$RelativePath is missing the '$contractName' contract (expected concept matching: $pattern)."
            }
        }
    }
}

$pairedAgentNames = @(
    'uxui-expert',
    'game-architect',
    'unity-expert',
    'network-expert',
    'system-tester',
    'system-planner'
)

foreach ($agentName in $pairedAgentNames) {
    Get-RepositoryText -RelativePath "agents/$agentName.md" | Out-Null
    Get-RepositoryText -RelativePath "codex/agents/$agentName.toml" | Out-Null
}

$codexAgentFiles = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'codex/agents') -Filter '*.toml' -File)
$modelPolicy = Get-Content -LiteralPath (Join-Path $repositoryRoot 'skills/agent-coordination/model-policy.json') -Raw | ConvertFrom-Json
if ($modelPolicy.schemaVersion -ne 1) { Add-ContractFailure -Message 'Unsupported shared model policy schema.' }
foreach ($phase in @('routine', 'triage', 'plan', 'implement', 'review', 'analysis', 'hard', 'creative', 'network')) {
    foreach ($runtimeName in @('codex', 'claude')) {
        if (-not $modelPolicy.runtimes.$runtimeName.PSObject.Properties[$phase]) {
            Add-ContractFailure -Message "Missing $runtimeName/$phase model policy."
        }
    }
}
foreach ($codexAgentFile in $codexAgentFiles) {
    $content = [System.IO.File]::ReadAllText($codexAgentFile.FullName, [System.Text.Encoding]::UTF8)
    if ($content -notmatch '(?im)^\s*model\s*=\s*"gpt-6(?:\.1)?-(?:luna|sol|astra)"') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) must select a supported GPT-6 model tier."
    }
    if ($content -notmatch '(?im)^\s*model_reasoning_effort\s*=\s*"(?:low|medium|high|xhigh|max|ultra)"') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) must select a supported reasoning effort."
    }
    $role = $modelPolicy.profileRoles.PSObject.Properties[$codexAgentFile.BaseName].Value
    $expectedTier = if ($role) { $modelPolicy.runtimes.codex.$role } else { $null }
    $expectedModelPattern = if ($null -eq $expectedTier) { '' } else { '(?im)^\s*model\s*=\s*"' + [regex]::Escape($expectedTier.model) + '"' }
    $expectedEffortPattern = if ($null -eq $expectedTier) { '' } else { '(?im)^\s*model_reasoning_effort\s*=\s*"' + [regex]::Escape($expectedTier.effort) + '"' }
    if ($null -eq $expectedTier -or $content -notmatch $expectedModelPattern -or $content -notmatch $expectedEffortPattern) {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) does not match the approved model/effort tier."
    }
    if ($content -match '(?i)(?<![a-z0-9_-])(fable|opus|sonnet)(?![a-z0-9_-])') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) contains a Claude-only model alias: $($Matches[1])."
    }
    if ($content -match '(?i)(?:~[/\\]\.claude|\.claude[/\\]|CLAUDE_(?:HOME|CONFIG_DIR)|<claude-home>)') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) contains a Claude-only path or environment reference."
    }
}

$claudeAgentFiles = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'agents') -Filter '*.md' -File | Where-Object Name -ne 'README.md')
foreach ($claudeAgentFile in $claudeAgentFiles) {
    $content = [System.IO.File]::ReadAllText($claudeAgentFile.FullName, [System.Text.Encoding]::UTF8)
    $frontmatterMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---')
    if (-not $frontmatterMatch.Success) {
        Add-ContractFailure -Message "agents/$($claudeAgentFile.Name) is missing YAML frontmatter."
        continue
    }
    $frontmatter = $frontmatterMatch.Groups[1].Value
    $modelMatch = [regex]::Match($frontmatter, '(?m)^model:\s*(\S+)\s*$')
    $effortMatch = [regex]::Match($frontmatter, '(?m)^effort:\s*(\S+)\s*$')
    $actualModel = if ($modelMatch.Success) { $modelMatch.Groups[1].Value } else { '' }
    $actualEffort = if ($effortMatch.Success) { $effortMatch.Groups[1].Value } else { '' }
    $role = $modelPolicy.profileRoles.PSObject.Properties[$claudeAgentFile.BaseName].Value
    $expectedTier = if ($role) { $modelPolicy.runtimes.claude.$role } else { $null }
    $expectedEffort = if ($null -eq $expectedTier -or $null -eq $expectedTier.effort) { '' } else { [string]$expectedTier.effort }
    if ($null -eq $expectedTier -or $actualModel -ne $expectedTier.model -or $actualEffort -ne $expectedEffort) {
        Add-ContractFailure -Message "agents/$($claudeAgentFile.Name) does not match the approved Claude model/effort tier (found '$actualModel'/'$actualEffort')."
    }
    if ($content -match '(?i)gpt-\d') {
        Add-ContractFailure -Message "agents/$($claudeAgentFile.Name) contains a Codex-only model name."
    }
}

$uxContracts = @{
    'spec traceability' = @(
        '(?i)(traceab|requirement.{0,80}decision)',
        '(?i)requirement',
        '(?i)acceptance'
    )
    'rendered visual QA' = @(
        '(?i)(visual[ -]?qa|rendered)',
        '(?i)render',
        '(?i)aspect ratio',
        '(?i)safe area'
    )
}
foreach ($path in @('agents/uxui-expert.md', 'codex/agents/uxui-expert.toml')) {
    Test-ContractPatterns -RelativePath $path -Contracts $uxContracts
}

$gameCodeContracts = @{
    'Clean Code naming and small methods' = @(
        '(?i)(clean code|readable event-based|intention-revealing)',
        '(?i)method',
        '(?i)abstraction',
        '(?i)DRY',
        '(?i)exception'
    )
    'proportionate events and direct calls' = @(
        '(?i)event',
        '(?i)direct call',
        '(?i)(hot path|hot-path)',
        '(?i)(idempotency|idempotent)'
    )
    'reusable governed configuration' = @(
        '(?i)(hardcod|tunable|configuration reuse)',
        '(?i)(typed access|typed Try)',
        '(?i)override precedence',
        '(?i)(schema/API|versioned save/network)'
    )
    'evidence-based pattern decisions' = @(
        '(?i)(pattern)',
        '(?i)rationale|pattern decision record|real problem',
        '(?i)complexity',
        '(?i)(removal|extension points|event-vs-direct-call)'
    )
    'code-analysis evidence discipline' = @(
        '(?i)fact',
        '(?i)inference',
        '(?i)(assumption|speculative)'
    )
}
foreach ($path in @(
    'agents/game-architect.md',
    'codex/agents/game-architect.toml',
    'agents/unity-expert.md',
    'codex/agents/unity-expert.toml'
)) {
    Test-ContractPatterns -RelativePath $path -Contracts $gameCodeContracts
}

$networkContracts = @{
    'version-verified supported netcode mapping' = @(
        '(?i)Photon Fusion',
        '(?i)FishNet',
        '(?i)Mirror',
        '(?is)(package|product).{0,40}version'
    )
    'authority and synchronization foundation' = @(
        '(?i)authority',
        '(?i)prediction',
        '(?i)reconciliation',
        '(?i)late join'
    )
    'quantified bandwidth and memory budgets' = @(
        '(?i)bandwidth',
        '(?i)memory',
        '(?i)average',
        '(?i)p95',
        '(?i)peak',
        '(?i)(budget|threshold)'
    )
}
foreach ($path in @('agents/network-expert.md', 'codex/agents/network-expert.toml')) {
    Test-ContractPatterns -RelativePath $path -Contracts $networkContracts
}

$testContracts = @{
    'explainable risk traceability' = @(
        '(?i)(traceability|requirement/risk)',
        '(?i)why',
        '(?i)evidence'
    )
    'observable result table' = @(
        '(?i)requirement/risk',
        '(?i)setup/action',
        '(?i)expected observable',
        '(?i)evidence/result',
        '(?i)NOT RUN',
        '(?i)PASS',
        '(?i)FAIL',
        '(?i)BLOCKED'
    )
    'coverage limits' = @(
        '(?i)remaining (risk|coverage)',
        '(?i)(coverage|limits?|environment)'
    )
}
foreach ($path in @('agents/system-tester.md', 'codex/agents/system-tester.toml')) {
    Test-ContractPatterns -RelativePath $path -Contracts $testContracts
}

$plannerContracts = @{
    'latency and subagent budget' = @(
        '(?i)(shortest|execution budget)',
        '(?i)agent',
        '(?i)handoff',
        '(?i)(parallel|dependency)',
        '(?i)(stop condition|stop/escalation condition)'
    )
    'risk-based fast path' = @(
        '(?i)(small measurable|lead 1|one stack lead)',
        '(?i)(verifier|verification)',
        '(?i)risk'
    )
}
foreach ($path in @('agents/system-planner.md', 'codex/agents/system-planner.toml')) {
    Test-ContractPatterns -RelativePath $path -Contracts $plannerContracts
}

if ($failures.Count -gt 0) {
    Write-Host 'Game-agent contract tests failed:' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Game-agent contract tests passed for $($pairedAgentNames.Count) Claude/Codex profile pairs and $($codexAgentFiles.Count) Codex profiles."
