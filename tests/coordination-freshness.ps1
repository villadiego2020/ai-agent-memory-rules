$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../skills/agent-coordination/scripts/lib/Coordination.Common.ps1')
function Assert-True($Value, $Message) { if (-not $Value) { throw $Message } }
function Reject($Operation) { $failed=$false; try { & $Operation } catch { $failed=$true }; Assert-True $failed 'Expected stale/invalid evidence rejection' }
$directory=Join-Path ([IO.Path]::GetTempPath()) ('freshness-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $directory
try {
    $task=[pscustomobject]@{ worktree=$directory; goal='Keep behavior'; acceptance=@('Preserve A'); kind='feature'; risk='medium'; stack='tooling'; ownedFiles=@('source.txt'); plan=[pscustomobject]@{ requirementRevision='1'; environmentFile='environment.json'; checks=@(); summary='Plan' }; updatedAt='before' }
    $path=Join-Path $directory 'environment.json'
    [IO.File]::WriteAllText($path,'{"tool":"v1"}')
    $first=Get-CoordinationFreshness $task
    $receipt=[pscustomobject]@{freshness=$first}
    Assert-CoordinationFreshReceipt $task $receipt
    $task.updatedAt='after'
    Assert-True ((Get-CoordinationFreshness $task) -eq $first) 'Transient state must not invalidate evidence'
    $task.acceptance=@('Preserve A','Add B')
    Reject { Assert-CoordinationFreshReceipt $task $receipt }
    $task.acceptance=@('Preserve A')
    $task.plan.requirementRevision='2'
    Reject { Assert-CoordinationFreshReceipt $task $receipt }
    $task.plan.requirementRevision='1'
    [IO.File]::WriteAllText($path,'{"tool":"v2"}')
    Reject { Assert-CoordinationFreshReceipt $task $receipt }
    [IO.File]::WriteAllText($path,'not json')
    Reject { Get-CoordinationFreshness $task }
    [IO.File]::WriteAllText($path,('x'*65537))
    Reject { Get-CoordinationFreshness $task }
    $task.plan.environmentFile='../escape.json'
    Reject { Get-CoordinationFreshness $task }
    $task.plan.environmentFile=''
    $task.plan.requirementRevision=2
    Reject { Get-CoordinationFreshness $task }
    $task.plan.PSObject.Properties.Remove('requirementRevision')
    Assert-True ((Get-CoordinationFreshness $task) -eq '') 'Legacy plan stays source-only'
    Assert-CoordinationFreshReceipt $task ([pscustomobject]@{})
    Write-Output 'Coordination freshness checks passed.'
} finally {
    # Only the uniquely created fixture directory is removed.
    Remove-Item -LiteralPath $path -Force
    [IO.Directory]::Delete($directory, $false)
}
