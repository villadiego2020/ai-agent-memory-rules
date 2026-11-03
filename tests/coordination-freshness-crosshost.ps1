[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('freshness-crosshost-'+[guid]::NewGuid().ToString('N'))))
function Assert-True($Value,[string]$Message) { if (-not $Value) { throw "Assertion failed: $Message" } }
try {
    $null=New-Item -ItemType Directory -Path (Join-Path $fixture 'tasks') -Force
    [IO.File]::WriteAllText((Join-Path $fixture 'environment.json'),'{"runtime":"fixture"}')
    $helper=Join-Path $fixture 'probe.ps1'
    [IO.File]::WriteAllText($helper,@'
param($Root,$Library)
$ErrorActionPreference='Stop'
. $Library
$context=[pscustomobject]@{tasks=(Join-Path $Root 'tasks')}
$task=Read-CoordinationTask $context 'T-000001'
$before=Get-CoordinationFreshness $task
Save-CoordinationTask $context $task
$after=Get-CoordinationFreshness (Read-CoordinationTask $context 'T-000001')
@{before=$before;after=$after} | ConvertTo-Json -Compress
'@)
    $library=Join-Path $repo 'skills/agent-coordination/scripts/lib/Coordination.Common.ps1'
    $thai=[string]::Concat([char]0x0E07,[char]0x0E32,[char]0x0E19)
    $cases=@('Plain contract',"Keep <API> & old 'values'",("Unicode "+$thai+' "quotes" \ path'),'<','\u003c')
    $hashes=@()
    foreach ($text in $cases) {
        $task=[ordered]@{schemaVersion=2;id='T-000001';title='Cross-host fixture';goal=$text;acceptance=@('Stable digest');risk='low';kind='feature';playbook='feature';stack='tooling';runtime='codex';status='claimed';stage='plan';owner='codex:fixture';pendingOwner=$null;worktree=$fixture;ownedFiles=@('source.txt');implementationParticipants=@();handoffs=@();artifacts=@();runs=@();review=$null;qa=$null;execution=$null;createdAt='2026-11-03T01:02:03.1234567Z';updatedAt='2026-11-03T01:02:03.1234567Z';plan=[ordered]@{summary=$text;evidence=@($text);checks=@();noChecksReason='Cross-host serialization probe';requireRuntimeEvidence=$false;recordedAt='2026-11-03T01:02:03.1234567Z';requirementRevision='1';environmentFile='environment.json'}}
        $task | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $fixture 'tasks/T-000001.json') -Encoding UTF8
        $expected=$null
        foreach ($hostName in @('pwsh','powershell.exe','pwsh')) {
            $output=@(& $hostName -NoProfile -ExecutionPolicy Bypass -File $helper $fixture $library 2>&1)
            Assert-True ($LASTEXITCODE -eq 0) "Probe failed on ${hostName}: $output"
            $receipt=($output -join "`n") | ConvertFrom-Json
            Assert-True ($receipt.before -ceq $receipt.after) 'Save/read must preserve contract digest'
            if ($expected) { Assert-True ($receipt.before -ceq $expected) "Same contract differs across hosts: $text" }
            else { $expected=$receipt.before }
        }
        $hashes+=@($expected)
    }
    Assert-True ($hashes[3] -cne $hashes[4]) 'HTML character and literal Unicode escape must not collide'
    Write-Output 'Cross-host freshness checks passed: HTML, Unicode, quotes, nested strings, literal escapes and save/read roundtrip.'
} finally {
    $resolved=[IO.Path]::GetFullPath($fixture)
    $temporaryRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if (-not $resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^freshness-crosshost-[0-9a-f]{32}$') { throw 'Unexpected fixture cleanup target.' }
    if (Test-Path -LiteralPath $resolved) {
        foreach ($file in @(Get-ChildItem -LiteralPath $resolved -File -Recurse -Force)) { Remove-Item -LiteralPath $file.FullName -Force }
        foreach ($directory in @(Get-ChildItem -LiteralPath $resolved -Directory -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending)) { [IO.Directory]::Delete($directory.FullName) }
        [IO.Directory]::Delete($resolved)
    }
}
