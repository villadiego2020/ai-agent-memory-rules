[CmdletBinding()]
param()

$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hostExecutable=(Get-Process -Id $PID).Path
$board=Join-Path $repo 'scripts/coordination.ps1'
$dispatch=Join-Path $repo 'scripts/orchestrate.ps1'
$project=Join-Path ([IO.Path]::GetTempPath()) "coordination-readiness-$([guid]::NewGuid().ToString('N'))"

function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw "Assertion failed: $Message" } }
function Invoke-Tool([string]$Script,[string[]]$Arguments,[switch]$Fails) {
    $output=@(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1)
    if ($Fails -and $LASTEXITCODE -eq 0) { throw "Expected rejection: $($Arguments -join ' ')" }
    if (-not $Fails -and $LASTEXITCODE -ne 0) { throw "Unexpected failure: $($Arguments -join ' ')`n$output" }
    return ($output -join "`n")
}
function Task([string]$Id) { Get-Content -LiteralPath (Join-Path $project ".agent-coordination/tasks/$Id.json") -Raw | ConvertFrom-Json }
function Write-Ready($Value) { [IO.File]::WriteAllText((Join-Path $project '.agent-coordination/readiness.json'),($Value | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false)) }

try {
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    & git init --quiet $project
    & git -C $project config user.name 'Coordination Test'
    & git -C $project config user.email 'coordination-test@example.invalid'
    [IO.File]::WriteAllText((Join-Path $project 'source.txt'),'baseline')
    & git -C $project add source.txt
    & git -C $project commit --quiet -m fixture
    Invoke-Tool $board @('init','-ProjectPath',$project) | Out-Null
    Invoke-Tool $board @('new','-ProjectPath',$project,'-Kind','bugfix','-Risk','medium','-Title','Bug','-Goal','Repair behavior','-Acceptance','Observed behavior fixed','-Owner','codex:lead','-OwnedFile','source.txt') | Out-Null
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Unconfirmed theory','-Evidence','guess','-NoChecksReason','Manual fixture') -Fails | Out-Null
    $ready=[ordered]@{ schemaVersion=1; kind='bugfix'; expected='Value retained'; actual='Value lost'; reproductionEvidence=@('Reproduced with fixture'); causeStatus='confirmed'; confirmedCause='Wrong branch'; causeEvidence=@('Trace hits wrong branch'); minimalChange='Correct branch'; impact='Fixture only'; regressionChecks=@(@{scenario='Reload';verification='Inspect retained value'}); acceptanceMapping=@(@{acceptance='Observed behavior fixed';verification='Reproduce and inspect result'}) }
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad.causeStatus='hypothesis'
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Unconfirmed','-Evidence','theory','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad.Remove('causeEvidence')
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad.acceptanceMapping=@(@{acceptance='Different acceptance';verification='Claimed check'})
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad['unknown']='extra'
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad.schemaVersion='1'
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad.Remove('causeStatus'); $bad['CauseStatus']='confirmed'
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $bad=$ready | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable; $bad.kind=@('bugfix')
    Write-Ready $bad
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    Write-Ready $ready
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') | Out-Null
    Assert-True ((Task 'T-000001').plan.readiness.confirmedCause -eq 'Wrong branch') 'Validated readiness stored in plan.'
    Invoke-Tool $board @('review','-ProjectPath',$project,'-Id','T-000001','-Reviewer','claude:peer','-Summary','Current source reviewed','-Evidence','fixture inspection','-Verdict','pass') | Out-Null
    Invoke-Tool $board @('qa','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Verdict','fail','-Summary','Still loses value','-Evidence','fixture output') -Fails | Out-Null
    Assert-True ((Task 'T-000001').validationFailures.Count -eq 1) 'Manual runtime failure counted once.'
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Same evidence','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') | Out-Null
    Assert-True ((Task 'T-000001').validationFailures.Count -eq 1) 'Identical replan preserves first failed round.'
    Invoke-Tool $board @('review','-ProjectPath',$project,'-Id','T-000001','-Reviewer','claude:peer','-Summary','Replanned source reviewed','-Evidence','fixture inspection') | Out-Null
    Invoke-Tool $board @('qa','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Verdict','fail','-Summary','Still loses value','-Evidence','fixture output') -Fails | Out-Null
    Assert-True ((Task 'T-000001').validationFailures.Count -eq 2) 'Second failure triggers cap.'
    Invoke-Tool $board @('review','-ProjectPath',$project,'-Id','T-000001','-Reviewer','claude:peer','-Summary','Too early','-Evidence','review','-Verdict','pass') -Fails | Out-Null
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Same cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    $ready['newEvidence']=@('Trace hits wrong branch')
    Write-Ready $ready
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Same cause','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') -Fails | Out-Null
    Invoke-Tool $board @('worktree','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead') | Out-Null
    $worktree=Join-Path $project '.agent-coordination/worktrees/T-000001'
    $null=New-Item -ItemType Directory -Path (Join-Path $worktree 'work') -Force
    [IO.File]::WriteAllText((Join-Path $worktree 'work/readiness.json'),($ready | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','Same cause after worktree','-Evidence','trace','-NoChecksReason','Manual fixture','-ReadinessFile','work/readiness.json') -Fails | Out-Null
    $ready.newEvidence=@('New debugger trace at branch boundary')
    [IO.File]::WriteAllText((Join-Path $worktree 'work/readiness.json'),($ready | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:lead','-Summary','New finding','-Evidence','new trace','-NoChecksReason','Manual fixture','-ReadinessFile','work/readiness.json') | Out-Null
    Assert-True ((Task 'T-000001').validationFailures.Count -eq 0) 'Fresh evidence replan clears cap.'

    Invoke-Tool $board @('new','-ProjectPath',$project,'-Kind','feature','-Risk','medium','-Title','System','-Goal','Add behavior','-Acceptance','Result persists','-Owner','codex:system','-OwnedFile','system') | Out-Null
    $feature=[ordered]@{ schemaVersion=1; kind='feature'; requirements=@('Persist result'); design=@{ownership='Service owns result';data='Existing settings field';interfaces='UI calls service';states='Default and persisted';failureHandling='Fallback to default';compatibility='Old records load default';nonGoals='N/A: no remote storage in scope'};acceptanceMapping=@(@{acceptance='Result persists';verification='Restart and inspect'}) }
    Write-Ready $feature
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system','-Summary','Scoped design','-Evidence','requirements','-NoChecksReason','Manual fixture','-ReadinessFile','.agent-coordination/readiness.json') | Out-Null
    $check=@([ordered]@{name='failing-acceptance';executable=$hostExecutable;arguments=@('-NoProfile','-Command','exit 7');workingDirectory='.';timeoutSeconds=5})
    [IO.File]::WriteAllText((Join-Path $project 'checks.json'),(ConvertTo-Json -InputObject $check -Depth 8),[Text.UTF8Encoding]::new($false))
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system','-Summary','Executable verification','-Evidence','requirements','-CheckFile','checks.json','-ReadinessFile','.agent-coordination/readiness.json') | Out-Null
    Invoke-Tool $board @('review','-ProjectPath',$project,'-Id','T-000002','-Reviewer','claude:system-peer','-Summary','Current design reviewed','-Evidence','fixture review') | Out-Null
    Invoke-Tool $board @('qa','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system') -Fails | Out-Null
    Assert-True ((Task 'T-000002').validationFailures.Count -eq 1) 'Executed failing check counts as validation failure.'
    $check[0].arguments=@('-NoProfile','-Command','exit 0')
    [IO.File]::WriteAllText((Join-Path $project 'checks.json'),(ConvertTo-Json -InputObject $check -Depth 8),[Text.UTF8Encoding]::new($false))
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system','-Summary','Passing check','-Evidence','requirements','-CheckFile','checks.json','-ReadinessFile','.agent-coordination/readiness.json') | Out-Null
    Assert-True ((Task 'T-000002').validationFailures.Count -eq 1) 'Ordinary replan does not erase failed round.'
    Invoke-Tool $board @('review','-ProjectPath',$project,'-Id','T-000002','-Reviewer','claude:system-peer','-Summary','Current source reviewed','-Evidence','fixture review') | Out-Null
    Invoke-Tool $board @('qa','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system') | Out-Null
    Assert-True ((Task 'T-000002').validationFailures.Count -eq 0) 'Passing QA clears consecutive failure streak.'
    $check[0].arguments=@('-NoProfile','-Command','exit 7')
    [IO.File]::WriteAllText((Join-Path $project 'checks.json'),(ConvertTo-Json -InputObject $check -Depth 8),[Text.UTF8Encoding]::new($false))
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system','-Summary','Regression check','-Evidence','requirements','-CheckFile','checks.json','-ReadinessFile','.agent-coordination/readiness.json') | Out-Null
    Invoke-Tool $board @('review','-ProjectPath',$project,'-Id','T-000002','-Reviewer','claude:system-peer','-Summary','Current source reviewed','-Evidence','fixture review') | Out-Null
    Invoke-Tool $board @('qa','-ProjectPath',$project,'-Id','T-000002','-Owner','codex:system') -Fails | Out-Null
    Assert-True ((Task 'T-000002').validationFailures.Count -eq 1) 'Fail, pass, fail is one consecutive failed round.'
    Invoke-Tool $board @('new','-ProjectPath',$project,'-Kind','feature','-Risk','low','-Title','Small change','-Goal','Tweak behavior','-Acceptance','Tweak visible','-Owner','codex:small','-OwnedFile','small') | Out-Null
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000003','-Owner','codex:small','-Summary','Small change','-Evidence','inspection','-NoChecksReason','Manual fixture') | Out-Null
    Invoke-Tool $board @('new','-ProjectPath',$project,'-Kind','analysis','-Risk','high','-Title','Investigate','-Goal','Find cause','-Acceptance','Report cause','-Owner','codex:analyst') | Out-Null
    Invoke-Tool $board @('plan','-ProjectPath',$project,'-Id','T-000004','-Owner','codex:analyst','-Summary','Read-only investigation','-Evidence','source inspection','-NoChecksReason','No implementation checks') | Out-Null
    $preview=Invoke-Tool $dispatch @('-ProjectPath',$project,'-Id','T-000001','-Phase','implement','-Runtime','codex','-Workload','code') | ConvertFrom-Json
    Assert-True ($preview.model -eq 'gpt-6.1-sol') 'Routing retained after replan.'
    Write-Output 'Coordination readiness checks passed.'
} finally {
    $resolved=[IO.Path]::GetFullPath($project)
    $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or $resolved -eq $tempRoot) { throw "Refusing to remove test fixture outside temp root: $resolved" }
    $worktreePath=[IO.Path]::GetFullPath((Join-Path $resolved '.agent-coordination/worktrees/T-000001'))
    if (-not $worktreePath.StartsWith($resolved+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove worktree outside fixture: $worktreePath" }
    if (Test-Path -LiteralPath $worktreePath) { & git -C $resolved worktree remove --force --force $worktreePath | Out-Null }
    if (Test-Path -LiteralPath $resolved) {
        foreach ($item in (Get-ChildItem -LiteralPath $resolved -Recurse -Force -File)) { $item.Attributes=[IO.FileAttributes]::Normal }
        [IO.Directory]::Delete($resolved,$true)
    }
}
