[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repo 'scripts/lib/OfflineEvaluation.ps1')
$hostExecutable = (Get-Process -Id $PID).Path
$command = Join-Path $repo 'scripts/evaluate-offline.ps1'
# Same-filesystem staging is exercised under the writable checkout: some restricted
# Windows hosts allow TEMP writes but deny TEMP renames independently of this tool.
$temp = Join-Path $repo ('.offline-canaries-' + [guid]::NewGuid().ToString('N'))
if ([IO.Directory]::Exists($temp) -or [IO.File]::Exists($temp)) { throw 'Generated test directory already exists; refusing ownership.' }
[void][IO.Directory]::CreateDirectory($temp)
$inputFile = Join-Path $temp 'raw.json'
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "Assertion failed: $Message" } }
function New-Manifest($Result, $Usage = @()) {
    return @{ schemaVersion = 1; evaluator = @{ id = 'synthetic'; version = '1' }; fixture = @{ id = 'canary'; version = '1' }; expectedRuns = @(@{ runId = 'run'; result = $Result }); usage = @($Usage) }
}
function New-Call([string]$Id, $InputTokens = 100, $Parent = $null) {
    return @{ callId = $Id; parentCallId = $Parent; inputTokens = $InputTokens; outputTokens = 0; cacheReadTokens = 2; cacheWriteTokens = 3; runtime = 'fixture'; requestedModel = 'requested'; observedModel = 'observed'; observationSource = 'synthetic-receipt' }
}
function Write-Manifest($Manifest) { [IO.File]::WriteAllText($inputFile, (ConvertTo-Json -InputObject $Manifest -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Read-Report($Manifest) { Write-Manifest $Manifest; return ConvertTo-OfflineReport -InputPath $inputFile }
function Assert-Rejected($Manifest, [string]$Message) {
    Write-Manifest $Manifest
    $rejected = $false
    try { $null = ConvertTo-OfflineReport -InputPath $inputFile } catch { $rejected = $true }
    Assert-True $rejected $Message
}
function Invoke-Cli([string[]]$Extra = @()) {
    $ErrorActionPreference = 'Continue'
    $output = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $command -InputPath $inputFile @Extra 2>&1)
    return @{ code = $LASTEXITCODE; text = ($output -join "`n") }
}
try {
    $pass = @{ status = 'completed'; passed = 1; failed = 0; skipped = 0; outcome = 'pass' }
    # Literal oracle values are independent of the production classifier/aggregator.
    $canaries = @(
        @{ name = 'known-pass'; result = $pass; usage = @((New-Call 'a')); class = 'pass'; total = 100 },
        @{ name = 'known-fail'; result = @{ status = 'completed'; passed = 0; failed = 1; skipped = 0; outcome = 'fail' }; usage = @(); class = 'fail'; total = $null },
        @{ name = 'zero-tests'; result = @{ status = 'completed'; passed = 0; failed = 0; skipped = 0; outcome = 'pass' }; usage = @(); class = 'ungraded'; total = $null },
        @{ name = 'skipped'; result = @{ status = 'skipped' }; usage = @(); class = 'skipped'; total = $null },
        @{ name = 'missing'; result = $null; usage = @(); class = 'missing'; total = $null },
        @{ name = 'invalid'; result = @{ status = 'completed'; passed = 1; failed = 1; skipped = 0; outcome = 'pass' }; usage = @(); class = 'invalid'; total = $null },
        @{ name = 'timeout'; result = @{ status = 'timedOut' }; usage = @(); class = 'timeout'; total = $null },
        @{ name = 'cancelled'; result = @{ status = 'cancelled' }; usage = @(); class = 'cancelled'; total = $null },
        @{ name = 'duplicate'; result = $pass; usage = @((New-Call 'a'), (New-Call 'a')); class = 'pass'; total = 100 },
        @{ name = 'distinct'; result = $pass; usage = @((New-Call 'a'), (New-Call 'b')); class = 'pass'; total = 200 },
        @{ name = 'nested'; result = $pass; usage = @((New-Call 'a'), (New-Call 'b' 100 'a')); class = 'pass'; total = 200 },
        @{ name = 'unknown'; result = $pass; usage = @((New-Call 'a' $null)); class = 'pass'; total = $null }
    )
    foreach ($case in $canaries) {
        $report = Read-Report (New-Manifest $case.result $case.usage)
        Assert-True ($report.runs.Count -eq 1 -and $report.runs[0].classification -ceq $case.class) "$($case.name) classification"
        Assert-True ($report.usage.totals.inputTokens.total -eq $case.total) "$($case.name) independent token oracle"
        $d = $report.denominator
        Assert-True ($d.expected -eq 1 -and $d.classified -eq 1 -and ($d.graded + $d.ungraded + $d.infrastructureFailed + $d.cancelled) -eq 1) "$($case.name) denominator"
    }
    # Mixed denominator cannot hide ungraded/infra cases behind an aggregate pass rate.
    $mixed = New-Manifest $pass
    $mixed.expectedRuns = @($canaries | ForEach-Object { @{ runId = $_.name; result = $_.result } })
    $r = Read-Report $mixed
    Assert-True ($r.denominator.expected -eq 12 -and $r.denominator.graded -eq 6 -and $r.denominator.ungraded -eq 2 -and $r.denominator.infrastructureFailed -eq 3 -and $r.denominator.cancelled -eq 1) 'mixed explicit denominator oracle'
    $r = Read-Report (New-Manifest $pass @((New-Call 'a'), (New-Call 'a' 101)))
    Assert-True ($r.usage.uniqueCalls -eq 1 -and $r.usage.calls[0].status -eq 'conflicted' -and $null -eq $r.usage.totals.inputTokens.total -and $r.usage.totals.inputTokens.knownSubtotal -eq '0') 'conflicting duplicates poison authoritative totals'
    $r = Read-Report (New-Manifest @{ status = 'completed'; passed = 0; failed = 0; skipped = 5; outcome = 'pass' })
    Assert-True ($r.runs[0].classification -eq 'ungraded') 'skipped-only completed evaluator is ungraded'
    $r = Read-Report (New-Manifest $pass @((New-Call 'a'), (New-Call 'b' $null)))
    Assert-True ($r.usage.totals.inputTokens.status -eq 'unknown' -and $r.usage.totals.inputTokens.knownSubtotal -eq '100' -and $r.usage.totals.inputTokens.knownCalls -eq 1) 'partial coverage remains unknown'
    $r = Read-Report (New-Manifest $pass @((New-Call 'a'), (New-Call 'A')))
    Assert-True ($r.usage.uniqueCalls -eq 2 -and $r.usage.totals.inputTokens.total -eq 200 -and $r.usage.totals.cacheReadTokens.total -eq 4 -and $r.usage.totals.cacheWriteTokens.total -eq 6) 'ordinal IDs and cache metrics'
    $r = Read-Report (New-Manifest $pass @((New-Call 'a' 9007199254740991), (New-Call 'b' 9007199254740991)))
    Assert-True ($r.usage.totals.inputTokens.status -eq 'overflow' -and $null -eq $r.usage.totals.inputTokens.total -and $r.usage.totals.inputTokens.exactTotal -ceq '18014398509481982') 'safe JSON number overflow exact oracle'
    foreach ($bad in @($true, '100', -1, 0.5, 9007199254740992)) { Assert-Rejected (New-Manifest $pass @((New-Call 'a' $bad))) 'reject invalid metric type/range' }
    foreach ($bad in @($true, '1')) {
        $result = @{ status = 'completed'; passed = $bad; failed = 0; skipped = 0; outcome = 'pass' }
        $r = Read-Report (New-Manifest $result)
        Assert-True ($r.runs[0].classification -eq 'invalid') 'reject invalid test count'
    }
    $m = New-Manifest $pass; $m.expectedRuns += @{ runId = 'run'; result = $pass }; Assert-Rejected $m 'duplicate run ID'
    $m = New-Manifest $pass; $m.schemaVersion = '1'; Assert-Rejected $m 'schema version cannot be coerced'
    $m = New-Manifest $pass; $m.expectedRuns = @(); Assert-Rejected $m 'empty expected denominator rejected'
    foreach ($bad in @(-1, 0.5)) { Assert-Rejected (New-Manifest @{ status = 'completed'; passed = $bad; failed = 0; skipped = 0; outcome = 'pass' }) 'noncanonical count rejects manifest' }
    $m = New-Manifest $pass; $m.expectedRuns += @{ runId = 'RUN'; result = $pass }; $r = Read-Report $m; Assert-True ($r.runs.Count -eq 2) 'ordinal run IDs'
    Assert-Rejected (New-Manifest $pass @((New-Call 'a' 100 'absent'))) 'unresolved parent'
    Assert-Rejected (New-Manifest $pass @((New-Call 'a' 100 'b'), (New-Call 'b' 100 'a'))) 'parent cycle'
    Assert-Rejected (New-Manifest $pass @((New-Call 'a'), (New-Call 'a' 100 'b'), (New-Call 'b' 100 'a'))) 'conflicted alternative parent cycle'
    $call = New-Call 'a'; $call.Remove('observationSource'); Assert-Rejected (New-Manifest $pass @($call)) 'observed identity needs evidence source'
    $call = New-Call 'a'; $call.Remove('observedModel'); $call.Remove('observationSource')
    $r = Read-Report (New-Manifest $pass @($call)); Assert-True ($r.usage.calls[0].attributionStatus -eq 'unavailable' -and $r.certificationStatus -eq 'incomplete') 'requested identity never claimed observed'
    $m = New-Manifest $pass @((New-Call 'a')); $m.fixture.id = 'Unicode ' + [char]0x0e01 + ' literal \n \\'; Write-Manifest $m
    $original = [IO.File]::ReadAllBytes($inputFile)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $expectedHash = ([BitConverter]::ToString($sha.ComputeHash($original))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    $r1 = ConvertTo-OfflineReport $inputFile; $r2 = ConvertTo-OfflineReport $inputFile
    Assert-True ($r1.provenance.rawSha256 -ceq $expectedHash -and $r2.provenance.rawSha256 -ceq $expectedHash -and $r1.provenance.fixture.id -ceq $m.fixture.id) 'byte hash Unicode literal escapes and stable replay'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) -ceq [Convert]::ToBase64String($original)) 'replay leaves raw bytes unchanged'
    $m.evaluator.version = '2'; $r = Read-Report $m
    Assert-True ($r.provenance.evaluator.version -ceq '2' -and $r.provenance.rawSha256 -cne $expectedHash) 'evaluator version change detectable'
    $m.fixture.version = '2'; $r = Read-Report $m; Assert-True ($r.provenance.fixture.version -ceq '2') 'fixture version change detectable'
    Write-Manifest $m; $raw = [IO.File]::ReadAllText($inputFile)
    [IO.File]::WriteAllText($inputFile, $raw, [Text.UTF8Encoding]::new($true)); $r = ConvertTo-OfflineReport $inputFile
    Assert-True ($r.provenance.rawBytes -eq ([Text.Encoding]::UTF8.GetByteCount($raw) + 3)) 'BOM accepted and fingerprinted'
    [IO.File]::WriteAllBytes($inputFile, [byte[]]@(0xc3, 0x28)); $rejected = $false
    try { $null = ConvertTo-OfflineReport $inputFile } catch { $rejected = $true }; Assert-True $rejected 'invalid UTF8 rejected'
    [IO.File]::WriteAllText($inputFile, '{broken'); $cli = Invoke-Cli; Assert-True ($cli.code -ne 0 -and $cli.code -ne 2) 'malformed JSON exit distinct'
    Write-Manifest $m; $rejected = $false
    try { $null = ConvertTo-OfflineReport $inputFile -MaxBytes 2 } catch { $rejected = $true }; Assert-True $rejected 'bounded input'
    $cli = Invoke-Cli; Assert-True ($cli.code -eq 0 -and ($cli.text | ConvertFrom-Json).certificationStatus -eq 'complete') 'complete report exit0'
    $outputFile = Join-Path $temp 'report.json'
    $cli = Invoke-Cli @('-OutputPath', $outputFile); Assert-True ($cli.code -eq 0 -and [IO.File]::Exists($outputFile)) 'new output success'
    $outputBefore = [IO.File]::ReadAllText($outputFile)
    $cli = Invoke-Cli @('-OutputPath', $outputFile); Assert-True ($cli.code -ne 0 -and [IO.File]::ReadAllText($outputFile) -ceq $outputBefore) 'existing output preserved'
    $before = [IO.File]::ReadAllText($inputFile); $cli = Invoke-Cli @('-OutputPath', (Join-Path $temp './raw.json'))
    Assert-True ($cli.code -ne 0 -and [IO.File]::ReadAllText($inputFile) -ceq $before) 'same-path alias preserved'
    Write-Manifest (New-Manifest @{ status = 'timedOut' }); $cli = Invoke-Cli
    Assert-True ($cli.code -eq 2 -and ($cli.text | ConvertFrom-Json).runs[0].classification -eq 'timeout') 'incomplete report emitted with exit2'
    Write-Manifest (New-Manifest $pass); $cli = Invoke-Cli
    Assert-True ($cli.code -eq 2 -and ($cli.text | ConvertFrom-Json).usage.totals.inputTokens.status -eq 'unknown') 'missing telemetry cannot silently pass acceptance'
    # Preserve the independent repros as literal JSON, never through a numeric serializer.
    $rawBase = '{"schemaVersion":1,"evaluator":{"id":"e","version":"1"},"fixture":{"id":"f","version":"1"},"expectedRuns":[{"runId":"r","result":{"status":"completed","outcome":"pass","passed":1,"failed":0,"skipped":0}}],"usage":[{"callId":"a","observedModel":"m","observationSource":"s","inputTokens":100,"outputTokens":0,"cacheReadTokens":0,"cacheWriteTokens":0}]}'
    $rawCases = @(
        @{ name = 'underflow'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":1e-999'); code = 1 },
        @{ name = 'near-safe fraction'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":9007199254740990.5'); code = 1 },
        @{ name = 'tiny count fraction'; json = $rawBase.Replace('"passed":1', '"passed":1.00000000000000000001'); code = 1 },
        @{ name = 'decimal spelling'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":100.0'); code = 1 },
        @{ name = 'exponent spelling'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":1e2'); code = 1 },
        @{ name = 'negative zero'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":-0'); code = 1 },
        @{ name = 'leading zero'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":0100'); code = 1 },
        @{ name = 'duplicate key'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":99,"inputTokens":100'); code = 1 },
        @{ name = 'escaped duplicate'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":99,"input\u0054okens":100'); code = 1 },
        @{ name = 'case duplicate'; json = $rawBase.Replace('"inputTokens":100', '"inputTokens":99,"InputTokens":100'); code = 1 },
        @{ name = 'status array'; json = $rawBase.Replace('"status":"completed"', '"status":["completed"]'); code = 2 },
        @{ name = 'outcome array'; json = $rawBase.Replace('"outcome":"pass"', '"outcome":["pass"]'); code = 2 },
        @{ name = 'evaluator array'; json = $rawBase.Replace('"evaluator":{"id":"e","version":"1"}', '"evaluator":[{"id":"e","version":"1"}]'); code = 1 },
        @{ name = 'nested run array'; json = $rawBase.Replace('"expectedRuns":[{', '"expectedRuns":[[{').Replace('"skipped":0}}]', '"skipped":0}}]]'); code = 1 },
        @{ name = 'nested usage array'; json = $rawBase.Replace('"usage":[{', '"usage":[[{').Replace('"cacheWriteTokens":0}]}', '"cacheWriteTokens":0}]]}'); code = 1 },
        @{ name = 'root singleton array'; json = '[' + $rawBase + ']'; code = 1 },
        @{ name = 'ignored duplicate'; json = $rawBase.Replace('"schemaVersion":1', '"extra":{"x":1,"x":2},"schemaVersion":1'); code = 1 },
        @{ name = 'ignored noncanonical number'; json = $rawBase.Replace('"schemaVersion":1', '"extra":1.0,"schemaVersion":1'); code = 1 },
        @{ name = 'depth bound'; json = $rawBase.Replace('"schemaVersion":1', ('"extra":' + ('[' * 65) + '0' + (']' * 65) + ',"schemaVersion":1')); code = 1 }
    )
    foreach ($case in $rawCases) {
        [IO.File]::WriteAllText($inputFile, $case.json, [Text.UTF8Encoding]::new($false))
        $cli = Invoke-Cli
        Assert-True ($cli.code -eq $case.code) "$($case.name) literal CLI outcome"
        if ($case.code -eq 2) { Assert-True (($cli.text | ConvertFrom-Json).runs[0].classification -eq 'invalid') "$($case.name) cannot classify pass" }
        Assert-True ([IO.File]::ReadAllText($inputFile) -ceq $case.json) "$($case.name) immutable raw input"
    }
    $rawGood = $rawBase.Replace('"inputTokens":100', '"inputTokens":9007199254740991')
    [IO.File]::WriteAllText($inputFile, $rawGood, [Text.UTF8Encoding]::new($false)); $cli = Invoke-Cli
    Assert-True ($cli.code -eq 0 -and ($cli.text | ConvertFrom-Json).usage.totals.inputTokens.total -eq 9007199254740991) 'literal safe maximum remains exact'
    Assert-True (@(Get-ChildItem -LiteralPath $temp -Filter '.offline-*.tmp').Count -eq 0) 'staging files cleaned'
    Write-Host 'Passed 12 core offline canaries and adversarial provenance/usage/path checks.'
} finally {
    # Only this invocation's fresh GUID directory and known generated files are owned.
    if ([IO.Directory]::Exists($temp)) {
        $cleanupRoot = [IO.Path]::GetFullPath($temp)
        if (-not [string]::Equals([IO.Path]::GetDirectoryName($cleanupRoot), $repo, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($cleanupRoot) -notmatch '^\.offline-canaries-[0-9a-f]{32}$') { throw 'Unsafe test cleanup boundary.' }
        $rootItem = Get-Item -LiteralPath $cleanupRoot -Force
        if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Refusing linked test cleanup directory.' }
        $entries = @(Get-ChildItem -LiteralPath $cleanupRoot -Force)
        foreach ($entry in $entries) {
            if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
                ($entry.Name -cnotin @('raw.json', 'report.json') -and $entry.Name -cnotmatch '^\.offline-[0-9a-f]{32}\.tmp$') -or
                -not [string]::Equals([IO.Path]::GetDirectoryName($entry.FullName), $cleanupRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Unexpected test cleanup entry retained: $($entry.FullName)"
            }
        }
        foreach ($entry in $entries) { Remove-Item -LiteralPath $entry.FullName -Force }
        [IO.Directory]::Delete($cleanupRoot, $false)
    }
}
