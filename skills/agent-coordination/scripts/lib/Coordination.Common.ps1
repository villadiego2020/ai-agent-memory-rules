Set-StrictMode -Version Latest
$script:CoordinationEncoding = [Text.UTF8Encoding]::new($false)

function Assert-CoordinationPath {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Coordination path cannot traverse a reparse point: $current" }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Invoke-CoordinationGit {
    param([string]$Root, [string[]]$Arguments, [switch]$AllowFailure)
    $result = Invoke-CoordinationProcess -Executable 'git' -Arguments (@('-C',$Root)+@($Arguments)) -WorkingDirectory $Root -TimeoutSeconds 60
    if ($AllowFailure) { return [pscustomobject]@{ output=$result.stdout; exitCode=$result.exitCode; timedOut=$result.timedOut } }
    if ($result.timedOut -or $result.exitCode -ne 0) { throw "Git failed ($($result.exitCode)): $($result.stderr)" }
    return $result.stdout.TrimEnd("`r","`n")
}

function Get-CoordinationContext {
    param([string]$ProjectPath)
    $requested = [IO.Path]::GetFullPath($ProjectPath)
    if (-not (Test-Path -LiteralPath $requested -PathType Container)) { throw "Project directory does not exist: $requested" }
    Assert-CoordinationPath $requested
    $probe = Invoke-CoordinationGit $requested @('rev-parse','--show-toplevel') -AllowFailure
    $isGit = $probe.exitCode -eq 0
    $root = if ($isGit) { [IO.Path]::GetFullPath($probe.output.Trim()) } else { $requested }
    $primary = $root
    if ($isGit) {
        $worktrees = Invoke-CoordinationGit $root @('-c','core.quotepath=false','worktree', 'list', '--porcelain')
        $first = @($worktrees -split "`n" | Where-Object { $_ -like 'worktree *' })[0]
        if (-not $first) { throw 'Cannot resolve the primary Git worktree.' }
        $primary = [IO.Path]::GetFullPath($first.Substring(9).TrimEnd("`r"))
    }
    $board = Join-Path $primary '.agent-coordination'
    if ($root -ne $primary -and (Test-Path -LiteralPath (Join-Path $root '.agent-coordination'))) {
        throw "Ambiguous per-worktree board at '$root/.agent-coordination'. Preserve it and migrate its records explicitly before using the shared board '$board'."
    }
    Assert-CoordinationPath $board
    [pscustomobject]@{ root = $root; primary = $primary; board = $board; tasks = (Join-Path $board 'tasks'); isGit = $isGit }
}

function Invoke-CoordinationLock {
    param($Context, [scriptblock]$Operation)
    if (-not (Test-Path -LiteralPath $Context.tasks -PathType Container)) { throw "Board is not initialized: $($Context.board). Run init first." }
    Assert-CoordinationPath $Context.tasks
    $lockPath = Join-Path $Context.board '.lock'
    Assert-CoordinationPath $lockPath
    $handle = $null
    try {
        try { $handle = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
        catch [IO.IOException] { throw 'Board is busy. Retry this command after the current update finishes; no state was changed.' }
        & $Operation
    } finally { if ($handle) { $handle.Dispose() } }
}

function Get-CoordinationTaskPath {
    param($Context, [string]$Id)
    if ($Id -cnotmatch '^T-[0-9]{6,12}$') { throw "Invalid task ID: $Id" }
    $path = Join-Path $Context.tasks "$Id.json"
    Assert-CoordinationPath $path
    return $path
}

function Write-CoordinationJson {
    param([string]$Path, $Value)
    Assert-CoordinationPath $Path
    $temp = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    $backup = "$Path.$([Guid]::NewGuid().ToString('N')).bak"
    try {
        [IO.File]::WriteAllText($temp, (($Value | ConvertTo-Json -Depth 40) + "`n"), $script:CoordinationEncoding)
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp, $Path, $backup) }
        else { [IO.File]::Move($temp, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) }
        if (Test-Path -LiteralPath $backup) { [IO.File]::Delete($backup) }
    }
}

function Set-CoordinationProperty {
    param($Value, [string]$Name, $Content)
    $Value | Add-Member -MemberType NoteProperty -Name $Name -Value $Content -Force
}

function Assert-CoordinationIdentity {
    param([string]$Identity)
    if ([string]::IsNullOrWhiteSpace($Identity) -or $Identity -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$') { throw 'Actor identity must be 1-80 letters/digits/dots/colons/hyphens. Prefer runtime:session, such as codex:lead-01.' }
}

function ConvertTo-CoordinationScope {
    param([string]$Path)
    $value = $Path.Replace('\', '/').TrimEnd('/')
    if ($value -eq '.') { return '.' }
    if ([string]::IsNullOrWhiteSpace($value) -or [IO.Path]::IsPathRooted($value) -or $value -match '[:*?\[\]\x00-\x1f]' -or @($value -split '/' | Where-Object { $_ -in @('', '.', '..', '.git', '.agent-coordination') }).Count -gt 0) { throw "Ownership must be a relative file/directory path without traversal or wildcards: $Path" }
    foreach ($segment in @($value -split '/')) { if ($segment -match '[. ]$' -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)') { throw "Ownership contains an ambiguous Windows path segment: $Path" } }
    return $value
}

function Test-CoordinationScopeOverlap {
    param([string]$First, [string]$Second)
    return $First -eq '.' -or $Second -eq '.' -or $First -ieq $Second -or $First.StartsWith($Second + '/', [StringComparison]::OrdinalIgnoreCase) -or $Second.StartsWith($First + '/', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-CoordinationOwnership {
    param($Context, $Task)
    if (-not $Task.owner -and -not $Task.pendingOwner) { return }
    foreach ($file in @(Get-ChildItem -LiteralPath $Context.tasks -Filter 'T-*.json' -File)) {
        if ($file.BaseName -eq $Task.id) { continue }
        Assert-CoordinationPath $file.FullName
        $other = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
        if ($other.status -eq 'complete' -or (-not $other.owner -and -not $other.pendingOwner)) { continue }
        foreach ($scope in @($Task.ownedFiles)) {
            foreach ($otherScope in @($other.ownedFiles)) {
                if (Test-CoordinationScopeOverlap $scope $otherScope) { throw "Ownership overlap with $($other.id): '$scope' conflicts with '$otherScope'. Split ownership or release the other task first." }
            }
        }
    }
}

function Read-CoordinationTask {
    param($Context, [string]$Id, [switch]$AllowLegacy)
    $path = Get-CoordinationTaskPath $Context $Id
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Task not found: $Id" }
    if ((Get-Item -LiteralPath $path).Length -gt 2097152) { throw 'Task record exceeds the 2 MiB bound. Preserve it and split follow-up work into another task.' }
    $task = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    if ($task.id -cne $Id -or $task.schemaVersion -notin @(1, 2)) { throw "Invalid task document: $path" }
    if ($task.schemaVersion -eq 1 -and -not $AllowLegacy) { throw 'Legacy task is read-only. Run migrate explicitly; old review/QA is preserved as history but cannot pass the new gates.' }
    if ($task.schemaVersion -eq 2) { Assert-CoordinationTask $task }
    return $task
}

function Assert-CoordinationTask {
    param($Task)
    foreach ($name in @('id','title','goal','acceptance','status','stage','risk','kind','playbook','stack','runtime','worktree','owner','pendingOwner','ownedFiles','implementationParticipants','handoffs','artifacts','runs','plan','review','qa','execution','createdAt','updatedAt')) {
        if (-not $Task.PSObject.Properties[$name]) { throw "Task is missing required property '$name'." }
    }
    if ($Task.schemaVersion -ne 2 -or $Task.id -cnotmatch '^T-[0-9]{6,12}$') { throw 'Unsupported task schema or ID.' }
    if ($Task.PSObject.Properties['hardProblem'] -and $Task.hardProblem -isnot [string]) { throw 'hardProblem must describe the difficult problem as a string.' }
    if ($Task.status -notin @('open','claimed','review','blocked','complete') -or $Task.stage -notin @('plan','implement','analysis','review','qa','complete') -or $Task.risk -notin @('low','medium','high') -or $Task.kind -notin @('feature','bugfix','refactor','analysis','performance','prototype') -or $Task.runtime -notin @('codex','claude')) { throw 'Invalid task state, risk, kind, or runtime.' }
    if ([string]::IsNullOrWhiteSpace($Task.title) -or [string]::IsNullOrWhiteSpace($Task.goal) -or @($Task.acceptance).Count -eq 0) { throw 'Task requires title, goal and acceptance criteria.' }
    foreach ($item in @($Task.acceptance)) { if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { throw 'Acceptance criteria must be non-empty strings.' } }
    foreach ($name in @('acceptance','ownedFiles','implementationParticipants','handoffs','artifacts','runs')) { if ($Task.$name -isnot [array]) { throw "Task.$name must be an array." } }
    if ($Task.owner) { Assert-CoordinationIdentity $Task.owner }
    if ($Task.pendingOwner) { Assert-CoordinationIdentity $Task.pendingOwner }
    if ($Task.owner -and $Task.pendingOwner) { throw 'A task cannot be owned and pending handoff simultaneously.' }
    foreach ($scope in @($Task.ownedFiles)) { $null = ConvertTo-CoordinationScope $scope }
    if ($Task.plan) {
        foreach ($name in @('summary','evidence','checks','noChecksReason','requireRuntimeEvidence','recordedAt')) { if (-not $Task.plan.PSObject.Properties[$name]) { throw "Task plan is missing '$name'." } }
        if ($Task.plan.checks -isnot [array] -or $Task.plan.evidence -isnot [array] -or $Task.plan.requireRuntimeEvidence -isnot [bool] -or (-not $Task.plan.checks.Count -and -not $Task.plan.noChecksReason)) { throw 'Malformed plan checks/manual acceptance contract.' }
        $checkNames=@{}
        foreach ($check in @($Task.plan.checks)) {
            Assert-CoordinationCheck $check
            if ($checkNames.ContainsKey($check.name)) { throw 'Plan has duplicate QA check names.' }
            $checkNames[$check.name]=$true
        }
    }
    if ($Task.review) {
        foreach ($name in @('actor','runtime','verdict','summary','evidence','snapshot','verification','recordedAt')) { if (-not $Task.review.PSObject.Properties[$name]) { throw "Task review is missing '$name'." } }
        Assert-CoordinationIdentity $Task.review.actor
        if ($Task.review.verdict -notin @('pass','fail') -or $Task.review.snapshot -notmatch '^[0-9a-f]{64}$' -or $Task.review.evidence -isnot [array] -or -not $Task.review.evidence.Count -or $Task.review.actor -in @($Task.implementationParticipants)) { throw 'Malformed or non-independent review.' }
    }
    if ($Task.qa) {
        foreach ($name in @('snapshot','passed','checks','manualSummary','manualEvidence','failure','recordedAt')) { if (-not $Task.qa.PSObject.Properties[$name]) { throw "Task QA is missing '$name'." } }
        if ($Task.qa.passed -isnot [bool] -or $Task.qa.snapshot -notmatch '^[0-9a-f]{64}$' -or $Task.qa.checks -isnot [array] -or $Task.qa.manualEvidence -isnot [array]) { throw 'Malformed QA receipt.' }
        if ($Task.qa.passed -and $Task.plan) {
            if ($Task.qa.checks.Count -ne $Task.plan.checks.Count -or @($Task.qa.checks | Where-Object { $_.exitCode -ne 0 -or $_.timedOut }).Count -gt 0) { throw 'Successful QA must contain a passing receipt for every planned check.' }
            if (($Task.plan.requireRuntimeEvidence -or -not $Task.plan.checks.Count) -and (-not $Task.qa.manualSummary -or -not $Task.qa.manualEvidence.Count)) { throw 'Successful QA is missing required manual/runtime acceptance evidence.' }
        }
    }
    if ($Task.status -eq 'complete' -and ($Task.stage -ne 'complete' -or -not $Task.qa -or -not $Task.qa.passed)) { throw 'Completed task is missing successful QA evidence.' }
}

function Save-CoordinationTask {
    param($Context, $Task)
    $Task.updatedAt = [DateTime]::UtcNow.ToString('o')
    Assert-CoordinationTask $Task
    Write-CoordinationJson (Get-CoordinationTaskPath $Context $Task.id) $Task
}

function Assert-CoordinationOwner {
    param($Task, [string]$Actor)
    Assert-CoordinationIdentity $Actor
    if ($Task.owner -ine $Actor) { throw "Task is owned by '$($Task.owner)'; '$Actor' cannot perform this operation." }
    if ($Task.status -eq 'complete') { throw 'Completed tasks are immutable. Create a follow-up task.' }
    if ($Task.execution) { throw "Task has an active execution lease: $($Task.execution.id). Inspect its process before recovery." }
}

function Get-CoordinationSnapshot {
    param($Context, [switch]$WithFiles)
    $root = $Context.root
    Assert-CoordinationPath $root
    $head = 'no-git'
    $index = ''
    if ($Context.isGit) {
        $headProbe = Invoke-CoordinationGit $root @('rev-parse','--verify','HEAD') -AllowFailure
        $head = if ($headProbe.exitCode -eq 0) { $headProbe.output.Trim() } else { 'unborn' }
        $index = Invoke-CoordinationGit $root @('ls-files', '--stage', '-z')
        $index = (@($index -split [char]0 | Where-Object { $_ -and $_ -notmatch '\t\.agent-coordination/' }) -join "`n")
        $listing = Invoke-CoordinationGit $root @('ls-files', '--cached', '--others', '--exclude-standard', '-z')
        $names = @($listing -split [char]0 | Where-Object { $_ -and $_ -notmatch '^\.agent-coordination/' } | Sort-Object -Unique)
    } else {
        $names = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($root.TrimEnd('\','/').Length + 1).Replace('\','/') } | Where-Object { $_ -notmatch '^(\.agent-coordination|\.git)/' } | Sort-Object)
    }
    if ($names.Count -gt 100000) { throw 'Source snapshot exceeds 100,000 files. Add generated artifacts to the project ignore policy before proceeding.' }
    $lines = [Collections.Generic.List[string]]::new()
    $fileMap = @{}
    $lines.Add("HEAD=$head"); $lines.Add("INDEX=$index")
    foreach ($name in $names) {
        $path = Join-Path $root $name
        Assert-CoordinationPath $path
        if (Test-Path -LiteralPath $path -PathType Leaf) { $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
        elseif (Test-Path -LiteralPath $path -PathType Container) { throw "Submodule/directory '$name' needs its own task board; source snapshot cannot certify its contents." }
        else { $hash = 'DELETED' }
        $lines.Add("$name=$hash")
        $fileMap[$name] = $hash
    }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $algorithm.ComputeHash($script:CoordinationEncoding.GetBytes(($lines -join "`n")))
        $snapshot = ([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
        if ($WithFiles) { return [pscustomobject]@{ snapshot=$snapshot; files=$fileMap } }
        return $snapshot
    }
    finally { $algorithm.Dispose() }
}

function Resolve-CoordinationDirectory {
    param($Context, [string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath -eq '.') { return $Context.root }
    $safe = ConvertTo-CoordinationScope $RelativePath
    $path = [IO.Path]::GetFullPath((Join-Path $Context.root $safe))
    Assert-CoordinationPath $path
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Check working directory does not exist: $path" }
    return $path
}

function Read-CoordinationChecks {
    param($Context, [string]$CheckFile)
    if (-not $CheckFile) { return @() }
    $safe = ConvertTo-CoordinationScope $CheckFile
    $path = Join-Path $Context.root $safe
    Assert-CoordinationPath $path
    if ((Get-Item -LiteralPath $path).Length -gt 131072) { throw 'QA configuration exceeds the 128 KiB bound.' }
    $parsedChecks = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    $checks = @($parsedChecks)
    if ($checks.Count -gt 64) { throw 'At most 64 acceptance checks may be configured per task.' }
    $names = @{}
    foreach ($check in $checks) {
        Assert-CoordinationCheck $check
        if ($names.ContainsKey($check.name)) { throw 'Check names must be unique, safe identifiers.' }
        $names[$check.name] = $true
        $null = Resolve-CoordinationDirectory $Context $check.workingDirectory
    }
    return $checks
}

function Assert-CoordinationCheck {
    param($Check)
    foreach ($field in @('name','executable','arguments','workingDirectory','timeoutSeconds')) { if (-not $Check.PSObject.Properties[$field]) { throw "QA check is missing '$field'." } }
    if ($Check.name -isnot [string] -or $Check.name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') { throw 'Check names must be safe identifiers.' }
    if ($Check.executable -isnot [string] -or [string]::IsNullOrWhiteSpace($Check.executable) -or $Check.arguments -isnot [array] -or ($Check.timeoutSeconds -isnot [int] -and $Check.timeoutSeconds -isnot [long]) -or $Check.timeoutSeconds -lt 1 -or $Check.timeoutSeconds -gt 3600) { throw 'Each check requires an executable, string-array arguments, and a 1-3600 second integer timeout.' }
    foreach ($arg in $Check.arguments) { if ($arg -isnot [string]) { throw 'QA arguments must be strings; shell expression evaluation is not supported.' } }
    $null=ConvertTo-CoordinationScope $Check.workingDirectory
}

function Test-CoordinationIndependentReviewRequired {
    param($Task)
    return $Task.kind -ne 'analysis' -and $Task.risk -ne 'low'
}

function Assert-CoordinationCurrentReview {
    param($Task, [string]$Snapshot)
    if (-not (Test-CoordinationIndependentReviewRequired $Task)) { return }
    if (-not $Task.review -or $Task.review.verdict -ne 'pass' -or $Task.review.snapshot -ne $Snapshot -or $Task.review.actor -in @($Task.implementationParticipants)) { throw 'A passing independent review of the current source snapshot is required.' }
}

function Get-CoordinationTaskContext {
    param($Context, $Task)
    $target = Get-CoordinationContext $Task.worktree
    if ($target.board -ine $Context.board) { throw 'Task worktree does not belong to this shared repository board.' }
    return $target
}

function Get-CoordinationActorRuntime {
    param([string]$Actor, [string]$Fallback = 'codex')
    if ($Actor -match '^(codex|claude)(:|$)') { return $Matches[1] }
    return $Fallback
}

function Clear-CoordinationGates {
    param($Task)
    $Task.review = $null; $Task.qa = $null
}

function New-CoordinationLease {
    param([string]$Actor, [string]$Phase, [string]$Id)
    [pscustomobject]@{ id=$Id; actor=$Actor; phase=$Phase; pid=$PID; processStartedAt=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o'); startedAt=[DateTime]::UtcNow.ToString('o') }
}
