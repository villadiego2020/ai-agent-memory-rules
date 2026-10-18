[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hostExecutable = (Get-Process -Id $PID).Path
$command = Join-Path $repo 'scripts/coordination.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) "agent-coordination-acceptance-$([guid]::NewGuid().ToString('N'))"
$project = Join-Path $temp 'Project with spaces'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Board {
    param([string[]]$Arguments, [switch]$Fails)
    $ErrorActionPreference = 'Continue'
    $output = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $command @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    if ($Fails -and $exitCode -eq 0) { throw "Expected rejection: $($Arguments -join ' ')`n$output" }
    if (-not $Fails -and $exitCode -ne 0) { throw "Command failed ($exitCode): $($Arguments -join ' ')`n$output" }
    return ($output -join "`n")
}

function Read-Task([string]$Id) {
    $path = Join-Path $project ".agent-coordination/tasks/$Id.json"
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

function Set-Checks([string]$Name, [string[]]$Arguments, [int]$TimeoutSeconds = 5) {
    $checks = @([ordered]@{ name = $Name; executable = $hostExecutable; arguments = @($Arguments); workingDirectory = '.'; timeoutSeconds = $TimeoutSeconds })
    [IO.File]::WriteAllText((Join-Path $project 'checks.json'), ((ConvertTo-Json -InputObject $checks -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    New-Item -ItemType Directory -Path (Join-Path $project 'src') -Force | Out-Null
    & git init --quiet $project
    Assert-True ($LASTEXITCODE -eq 0) 'Temporary Git repository initialized.'
    & git -C $project config user.name 'Coordination Test'
    & git -C $project config user.email 'coordination-test@example.invalid'
    [IO.File]::WriteAllText((Join-Path $project 'src/example.txt'), 'initial')
    & git -C $project add src/example.txt
    & git -C $project commit --quiet -m 'fixture'
    Assert-True ($LASTEXITCODE -eq 0) 'Temporary fixture committed.'

    Invoke-Board @('init', '-ProjectPath', $project) | Out-Null
    Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'bugfix', '-Risk', 'high', '-Runtime', 'codex', '-Title', 'Thai ภาษาไทย and spaces', '-Goal', 'Verify shared handoff and QA', '-Acceptance', 'Reproduction passes', '-Owner', 'codex:lead', '-OwnedFile', 'src/example.txt') | Out-Null
    $task = Read-Task 'T-000001'
    Assert-True ($task.schemaVersion -eq 2 -and $task.owner -eq 'codex:lead') 'New task has v2 schema and the requested owner.'
    $lockPath = Join-Path $project '.agent-coordination/.lock'
    $locked = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Title', 'Competing writer', '-Goal', 'Do not lose records', '-Acceptance', 'Lock rejects second process', '-Owner', 'claude:other', '-OwnedFile', 'other') -Fails | Out-Null
        Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $project '.agent-coordination/tasks') -Filter 'T-*.json' -File).Count -eq 1) 'Rejected concurrent writer created no record.'
    } finally { $locked.Dispose() }
    Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Title', 'Overlapping work', '-Goal', 'Reject overlap', '-Acceptance', 'No duplicate owner', '-Owner', 'claude:worker', '-OwnedFile', 'src') -Fails | Out-Null
    Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Title', 'Traversal', '-Goal', 'Reject traversal', '-Acceptance', 'Safe scope', '-Owner', 'claude:worker', '-OwnedFile', '../outside') -Fails | Out-Null
    Invoke-Board @('claim', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'claude:worker') -Fails | Out-Null
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead', '-QaSummary', 'premature', '-Evidence', 'none') -Fails | Out-Null

    Set-Checks 'passing' @('-NoProfile', '-Command', 'exit 0')
    Invoke-Board @('plan', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead', '-Summary', 'Reproduce and fix', '-Evidence', 'fixture', '-CheckFile', 'checks.json') | Out-Null
    Invoke-Board @('review', '-ProjectPath', $project, '-Id', 'T-000001', '-Reviewer', 'codex:lead', '-Verdict', 'pass', '-Summary', 'self review', '-Evidence', 'none') -Fails | Out-Null
    Invoke-Board @('review', '-ProjectPath', $project, '-Id', 'T-000001', '-Reviewer', 'claude:reviewer', '-Verdict', 'fail', '-Summary', 'unresolved issue', '-Evidence', 'review note') | Out-Null
    Invoke-Board @('qa', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead') -Fails | Out-Null
    Invoke-Board @('review', '-ProjectPath', $project, '-Id', 'T-000001', '-Reviewer', 'claude:reviewer', '-Verdict', 'pass', '-Summary', 'diff reviewed', '-Evidence', 'review note') | Out-Null
    [IO.File]::WriteAllText((Join-Path $project 'src/example.txt'), 'changed after review')
    Invoke-Board @('qa', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead') -Fails | Out-Null
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead', '-QaSummary', 'pass', '-Evidence', 'QA log') -Fails | Out-Null
    Invoke-Board @('review', '-ProjectPath', $project, '-Id', 'T-000001', '-Reviewer', 'claude:reviewer', '-Verdict', 'pass', '-Summary', 'current diff reviewed', '-Evidence', 'review note') | Out-Null
    Invoke-Board @('qa', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead') | Out-Null
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead', '-QaSummary', 'pass', '-Evidence', 'QA log') | Out-Null
    $task = Read-Task 'T-000001'
    Assert-True ($task.status -eq 'complete' -and $task.qa.passed -and $task.review.verdict -eq 'pass') 'Completion retained current review and passing QA evidence.'

    Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Risk', 'low', '-Title', 'Handoff', '-Goal', 'Coordinate runtime change', '-Acceptance', 'Receiver claims', '-Owner', 'claude:worker', '-OwnedFile', 'docs') | Out-Null
    Invoke-Board @('handoff', '-ProjectPath', $project, '-Id', 'T-000002', '-Owner', 'claude:worker', '-NextOwner', 'codex:worker', '-Summary', 'Please implement', '-Evidence', 'plan note') | Out-Null
    Invoke-Board @('claim', '-ProjectPath', $project, '-Id', 'T-000002', '-Owner', 'claude:other') -Fails | Out-Null
    Invoke-Board @('claim', '-ProjectPath', $project, '-Id', 'T-000002', '-Owner', 'codex:worker') | Out-Null
    Assert-True ((Read-Task 'T-000002').owner -eq 'codex:worker') 'Only intended handoff recipient claimed the task.'

    Invoke-Board @('worktree', '-ProjectPath', $project, '-Id', 'T-000002', '-Owner', 'codex:worker') -Fails | Out-Null
    [IO.File]::Delete((Join-Path $project 'checks.json'))
    & git -C $project restore -- src/example.txt
    Assert-True ($LASTEXITCODE -eq 0) 'Temporary fixture restored before creating a worktree.'
    Invoke-Board @('worktree', '-ProjectPath', $project, '-Id', 'T-000002', '-Owner', 'codex:worker') | Out-Null
    $worktree = Join-Path $project '.agent-coordination/worktrees/T-000002'
    Assert-True (Test-Path -LiteralPath (Join-Path $worktree '.git')) 'Git worktree exists.'
    $fromWorktree = Invoke-Board @('show', '-ProjectPath', $worktree, '-Id', 'T-000001') | ConvertFrom-Json
    Assert-True ($fromWorktree.id -eq 'T-000001') 'Second worktree reads the common board.'
    $null = New-Item -ItemType Directory -Path (Join-Path $worktree '.agent-coordination') -Force
    Invoke-Board @('show', '-ProjectPath', $worktree, '-Id', 'T-000001') -Fails | Out-Null
    $ambiguousBoard = [IO.Path]::GetFullPath((Join-Path $worktree '.agent-coordination'))
    Assert-True ($ambiguousBoard.StartsWith([IO.Path]::GetFullPath($temp), [StringComparison]::OrdinalIgnoreCase)) 'Ambiguous board fixture stays in temporary root.'
    [IO.Directory]::Delete($ambiguousBoard, $true)

    $twoChecks = @(
        [ordered]@{ name = 'first'; executable = $hostExecutable; arguments = @('-NoProfile', '-Command', 'exit 0'); workingDirectory = '.'; timeoutSeconds = 5 },
        [ordered]@{ name = 'failing'; executable = $hostExecutable; arguments = @('-NoProfile', '-Command', 'exit 7'); workingDirectory = '.'; timeoutSeconds = 5 }
    )
    [IO.File]::WriteAllText((Join-Path $project 'checks.json'), ((ConvertTo-Json -InputObject $twoChecks -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
    Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Risk', 'low', '-Title', 'QA failure', '-Goal', 'Fail closed', '-Acceptance', 'No completion on failed checks', '-Owner', 'codex:qa', '-OwnedFile', 'qa') | Out-Null
    Invoke-Board @('plan', '-ProjectPath', $project, '-Id', 'T-000003', '-Owner', 'codex:qa', '-Summary', 'Run acceptance', '-Evidence', 'fixture', '-CheckFile', 'checks.json') | Out-Null
    Invoke-Board @('qa', '-ProjectPath', $project, '-Id', 'T-000003', '-Owner', 'codex:qa') -Fails | Out-Null
    Assert-True (@((Read-Task 'T-000003').qa.checks).Count -eq 2) 'QA receipt records both the passing check and later failed check.'
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000003', '-Owner', 'codex:qa', '-QaSummary', 'incorrect', '-Evidence', 'none') -Fails | Out-Null
    Set-Checks 'timeout' @('-NoProfile', '-Command', 'Start-Sleep -Seconds 5') 1
    Invoke-Board @('plan', '-ProjectPath', $project, '-Id', 'T-000003', '-Owner', 'codex:qa', '-Summary', 'Check timeout bound', '-Evidence', 'fixture', '-CheckFile', 'checks.json') | Out-Null
    Invoke-Board @('qa', '-ProjectPath', $project, '-Id', 'T-000003', '-Owner', 'codex:qa') -Fails | Out-Null
    Assert-True (-not (Read-Task 'T-000003').qa.passed) 'Timed out QA did not pass.'

    $now = [DateTime]::UtcNow.ToString('o')
    $legacy = [ordered]@{ schemaVersion = 1; id = 'T-000004'; title = 'Pilot history'; goal = 'Preserve old evidence'; acceptance = @('New gates required'); risk = 'high'; status = 'complete'; owner = 'codex:legacy'; pendingOwner = $null; ownedFiles = @('archive'); artifacts = @(); createdAt = $now; updatedAt = $now; handoffs = @(); review = @{ reviewer = 'claude:peer'; summary = 'old review' }; qa = @{ summary = 'old QA' } }
    $legacyPath = Join-Path $project '.agent-coordination/tasks/T-000004.json'
    [IO.File]::WriteAllText($legacyPath, (($legacy | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
    $shownLegacy = Invoke-Board @('show', '-ProjectPath', $project, '-Id', 'T-000004') | ConvertFrom-Json
    Assert-True ($shownLegacy.schemaVersion -eq 1) 'Legacy task remains readable.'
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000004', '-Owner', 'codex:legacy', '-QaSummary', 'old', '-Evidence', 'old') -Fails | Out-Null
    Invoke-Board @('migrate', '-ProjectPath', $project, '-Id', 'T-000004') | Out-Null
    $migrated = Read-Task 'T-000004'
    Assert-True ($migrated.schemaVersion -eq 2 -and -not $migrated.plan -and -not $migrated.review -and -not $migrated.qa -and $migrated.legacy.qa.summary -eq 'old QA') 'Migration preserves old evidence without trusting old gates.'
    Assert-True (Test-Path -LiteralPath "$legacyPath.v1.json.backup") 'Migration saved the original v1 record.'

    Invoke-Board @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Risk', 'low', '-Title', 'Snapshot', '-Goal', 'Reject stale QA', '-Acceptance', 'Untracked source invalidates QA', '-Owner', 'codex:snapshot', '-OwnedFile', 'notes') | Out-Null
    Invoke-Board @('plan', '-ProjectPath', $project, '-Id', 'T-000005', '-Owner', 'codex:snapshot', '-Summary', 'Manual fixture acceptance', '-Evidence', 'fixture', '-NoChecksReason', 'Static fixture with no application runner') | Out-Null
    Invoke-Board @('qa', '-ProjectPath', $project, '-Id', 'T-000005', '-Owner', 'codex:snapshot', '-Summary', 'Accepted fixture', '-Evidence', 'manual inspection') | Out-Null
    $newFile = Join-Path $project 'src/untracked.txt'
    [IO.File]::WriteAllText($newFile, 'new source after QA')
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000005', '-Owner', 'codex:snapshot', '-QaSummary', 'stale', '-Evidence', 'none') -Fails | Out-Null
    [IO.File]::Delete($newFile)
    $indexBefore = (& git -C $project ls-files --stage -- src/example.txt) -join ''
    & git -C $project update-index --chmod=+x -- src/example.txt
    Assert-True ($LASTEXITCODE -eq 0) 'Git index mode changed for snapshot test.'
    $indexAfter = (& git -C $project ls-files --stage -- src/example.txt) -join ''
    Assert-True ($indexBefore -ne $indexAfter) 'Index-only change is observable.'
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000005', '-Owner', 'codex:snapshot', '-QaSummary', 'stale index', '-Evidence', 'none') -Fails | Out-Null
    & git -C $project update-index --chmod=-x -- src/example.txt
    Assert-True ($LASTEXITCODE -eq 0) 'Git index mode restored.'
    Invoke-Board @('complete', '-ProjectPath', $project, '-Id', 'T-000005', '-Owner', 'codex:snapshot', '-QaSummary', 'accepted', '-Evidence', 'manual inspection') | Out-Null

    Invoke-Board @('validate', '-ProjectPath', $project) | Out-Null
    Write-Host 'Coordination acceptance checks passed.'
} finally {
    $base = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolved = [IO.Path]::GetFullPath($temp)
    if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -and $resolved -ne $base -and (Test-Path -LiteralPath $resolved)) {
        Get-ChildItem -LiteralPath $resolved -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
        [IO.Directory]::Delete($resolved, $true)
    }
}
