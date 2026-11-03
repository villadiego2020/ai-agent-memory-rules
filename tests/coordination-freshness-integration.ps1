[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hostExecutable=(Get-Process -Id $PID).Path
$board=Join-Path $repo 'scripts/coordination.ps1'
$dispatch=Join-Path $repo 'scripts/orchestrate.ps1'
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('freshness-integration-'+[guid]::NewGuid().ToString('N'))))
$project=Join-Path $fixtureRoot 'project'
function Assert-True($Condition,[string]$Message) { if (-not $Condition) { throw "Assertion failed: $Message" } }
function Run([string]$Script,[string[]]$Arguments,[switch]$Fails) {
    $ErrorActionPreference='Continue'
    $output=@(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1)
    $code=$LASTEXITCODE
    if ($Fails) { Assert-True ($code -ne 0) "Expected rejection: $($Arguments -join ' ')" }
    else { Assert-True ($code -eq 0) "Command failed: $($Arguments -join ' ')`n$output" }
    return ($output -join "`n")
}
function Read-Task { Get-Content -LiteralPath (Join-Path $project '.agent-coordination/tasks/T-000001.json') -Raw | ConvertFrom-Json }
function Environment([string]$Version='v1') { [IO.File]::WriteAllText((Join-Path $project 'environment.json'), ('{"runtime":"'+$Version+'"}')) }
function Review { Run $board @('review','-ProjectPath',$project,'-Id','T-000001','-Reviewer','claude:independent','-Summary','Inspected fixture','-Evidence','fixture review') | Out-Null }
function QA { Run $board @('qa','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner','-Summary','Observed fixture','-Evidence','fixture acceptance') | Out-Null }
try {
    $null=New-Item -ItemType Directory -Path $project -Force
    & git init --quiet $project
    Assert-True ($LASTEXITCODE -eq 0) 'Fixture Git initialization'
    [IO.File]::WriteAllText((Join-Path $project '.gitignore'),"environment.json`n")
    [IO.File]::WriteAllText((Join-Path $project 'source.txt'),'source')
    Environment
    Run $board @('init','-ProjectPath',$project) | Out-Null
    Run $board @('new','-ProjectPath',$project,'-Kind','feature','-Risk','low','-Title','Freshness fixture','-Goal','Preserve acceptance','-Acceptance','Fixture passes','-Owner','codex:owner','-OwnedFile','source.txt') | Out-Null
    Run $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner','-Summary','Manual plan','-Evidence','fixture','-NoChecksReason','Observed fixture','-EnvironmentFile','environment.json') | Out-Null
    Review; QA
    Environment 'v2'
    $rejection=Run $board @('complete','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner','-QaSummary','Observed','-Evidence','fixture') -Fails
    Assert-True ($rejection -match 'stale') 'Ignored environment drift rejected at completion'
    Review; QA
    $task=Read-Task
    $task.goal='Changed requirement without changing source'
    $task | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $project '.agent-coordination/tasks/T-000001.json') -Encoding UTF8
    $rejection=Run $board @('complete','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner','-QaSummary','Observed','-Evidence','fixture') -Fails
    Assert-True ($rejection -match 'stale') 'Board-only requirement change rejected'

    # A real executable acceptance check changes only the ignored descriptor.
    $checks=@(@{name='drift';executable=$hostExecutable;arguments=@('-NoProfile','-Command',"[IO.File]::WriteAllText('environment.json','{}')");workingDirectory='.';timeoutSeconds=20})
    ConvertTo-Json -InputObject $checks -Depth 10 | Set-Content -LiteralPath (Join-Path $project 'checks.json') -Encoding UTF8
    Run $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner','-Summary','Executable drift','-Evidence','fixture','-CheckFile','checks.json','-EnvironmentFile','environment.json','-RequirementRevision','2') | Out-Null
    Review
    $rejection=Run $board @('qa','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner') -Fails
    $task=Read-Task
    Assert-True ($rejection -match 'changed during QA' -and -not $task.qa.passed -and -not $task.execution) 'During-QA drift fails receipt and releases execution'

    Environment
    $checks[0].arguments=@('-NoProfile','-Command',"[IO.File]::Delete('environment.json')")
    ConvertTo-Json -InputObject $checks -Depth 10 | Set-Content -LiteralPath (Join-Path $project 'checks.json') -Encoding UTF8
    Run $board @('plan','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner','-Summary','Descriptor deletion','-Evidence','fixture','-CheckFile','checks.json','-EnvironmentFile','environment.json','-RequirementRevision','3') | Out-Null
    Review
    $rejection=Run $board @('qa','-ProjectPath',$project,'-Id','T-000001','-Owner','codex:owner') -Fails
    $task=Read-Task
    Assert-True ($rejection -match 'changed during QA' -and -not $task.qa.passed -and -not $task.execution) 'Descriptor deletion during QA fails closed and releases execution'

    # The mock CLI returns a valid passing report after changing an ignored input.
    $stub=Join-Path $fixtureRoot 'review.ps1'
    [IO.File]::WriteAllText($stub,@'
$null=[Console]::In.ReadToEnd()
[IO.File]::WriteAllText('environment.json','{"runtime":"cli-changed"}')
@{structured_output=@{schemaVersion=1;outcome='pass';summary='Mock inspected';evidence=@('mock evidence');limitations=@();changedFiles=@()}} | ConvertTo-Json -Depth 8 -Compress
'@)
    Environment
    $rejection=Run $dispatch @('-ProjectPath',$project,'-Id','T-000001','-Phase','review','-Runtime','claude','-Actor','claude:mock','-CliPath',$stub,'-Execute') -Fails
    $task=Read-Task
    Assert-True ($rejection -match 'environment changed during review') 'CLI review drift diagnosed'
    Assert-True (-not $task.execution) 'Rejected CLI review releases lease'
    Assert-True ($task.runs.Count -eq 1 -and -not $task.runs[-1].passed) 'Rejected CLI review saves failed receipt'
    Write-Output 'Freshness integration checks passed: completion, contract drift, during-QA drift, CLI review lifecycle.'
} finally {
    # Verify this exact unique task-created root before removing its fixture files.
    $resolved=[IO.Path]::GetFullPath($fixtureRoot)
    $temporaryRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if ($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^freshness-integration-[0-9a-f]{32}$') {
        if (Test-Path -LiteralPath $resolved) {
            foreach ($file in @(Get-ChildItem -LiteralPath $resolved -File -Recurse -Force)) { Remove-Item -LiteralPath $file.FullName -Force }
            foreach ($directory in @(Get-ChildItem -LiteralPath $resolved -Directory -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending)) { [IO.Directory]::Delete($directory.FullName) }
            [IO.Directory]::Delete($resolved)
        }
    } else { throw 'Fixture cleanup path escaped the task-owned temporary boundary.' }
}
