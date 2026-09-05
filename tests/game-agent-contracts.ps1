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
foreach ($codexAgentFile in $codexAgentFiles) {
    $content = [System.IO.File]::ReadAllText($codexAgentFile.FullName, [System.Text.Encoding]::UTF8)
    if ($content -match '(?im)^\s*model(?:_reasoning_effort)?\s*=') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) pins a model or reasoning effort instead of inheriting user settings."
    }
    if ($content -match '(?i)(?<![a-z0-9_-])(fable|opus|sonnet)(?![a-z0-9_-])') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) contains a Claude-only model alias: $($Matches[1])."
    }
    if ($content -match '(?i)(?:~[/\\]\.claude|\.claude[/\\]|CLAUDE_(?:HOME|CONFIG_DIR)|<claude-home>)') {
        Add-ContractFailure -Message "codex/agents/$($codexAgentFile.Name) contains a Claude-only path or environment reference."
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
