# Standalone v1 offline evidence contract. No commands from the input are executed.
function Skip-OfflineJsonWhitespace($State) {
    while ($State.position -lt $State.text.Length -and @(' ', "`t", "`r", "`n") -ccontains [string]$State.text[$State.position]) { $State.position++ }
}

function Read-OfflineJsonString($State) {
    if ($State.position -ge $State.text.Length -or $State.text[$State.position] -cne '"') { throw 'Expected JSON string.' }
    $start = $State.position
    $State.position++
    while ($State.position -lt $State.text.Length) {
        $character = $State.text[$State.position]
        $State.position++
        if ($character -ceq '"') { return $State.text.Substring($start, $State.position - $start) }
        if ([int]$character -lt 32) { throw 'Unescaped control character in JSON string.' }
        if ($character -ceq '\') {
            if ($State.position -ge $State.text.Length) { throw 'Incomplete JSON escape.' }
            $escape = [string]$State.text[$State.position]
            $State.position++
            if ($escape -ceq 'u') {
                if ($State.position + 4 -gt $State.text.Length -or $State.text.Substring($State.position, 4) -cnotmatch '^[0-9a-fA-F]{4}$') { throw 'Invalid JSON Unicode escape.' }
                $State.position += 4
            } elseif (@('"', '\', '/', 'b', 'f', 'n', 'r', 't') -cnotcontains $escape) { throw 'Invalid JSON escape.' }
        }
    }
    throw 'Unterminated JSON string.'
}

function Read-OfflineJsonValue($State, [int]$Depth) {
    if ($Depth -gt 64) { throw 'JSON nesting exceeds 64 levels.' }
    Skip-OfflineJsonWhitespace $State
    if ($State.position -ge $State.text.Length) { throw 'Missing JSON value.' }
    $character = $State.text[$State.position]
    if ($character -ceq '"') { $null = Read-OfflineJsonString $State; return }
    if ($character -ceq '{') {
        $State.position++
        $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        Skip-OfflineJsonWhitespace $State
        if ($State.position -lt $State.text.Length -and $State.text[$State.position] -ceq '}') { $State.position++; return }
        while ($true) {
            Skip-OfflineJsonWhitespace $State
            $keyToken = Read-OfflineJsonString $State
            # Decode escapes before comparison; a key parser sees only a bounded JSON string.
            $key = ConvertFrom-Json -InputObject ('[' + $keyToken + ']') -ErrorAction Stop
            if (-not $keys.Add([string]$key)) { throw 'Duplicate or case-ambiguous JSON property.' }
            Skip-OfflineJsonWhitespace $State
            if ($State.position -ge $State.text.Length -or $State.text[$State.position] -cne ':') { throw 'Expected JSON colon.' }
            $State.position++
            Read-OfflineJsonValue $State ($Depth + 1)
            Skip-OfflineJsonWhitespace $State
            if ($State.position -ge $State.text.Length) { throw 'Unterminated JSON object.' }
            $separator = $State.text[$State.position]; $State.position++
            if ($separator -ceq '}') { return }
            if ($separator -cne ',') { throw 'Expected JSON object separator.' }
        }
    }
    if ($character -ceq '[') {
        $State.position++
        Skip-OfflineJsonWhitespace $State
        if ($State.position -lt $State.text.Length -and $State.text[$State.position] -ceq ']') { $State.position++; return }
        while ($true) {
            Read-OfflineJsonValue $State ($Depth + 1)
            Skip-OfflineJsonWhitespace $State
            if ($State.position -ge $State.text.Length) { throw 'Unterminated JSON array.' }
            $separator = $State.text[$State.position]; $State.position++
            if ($separator -ceq ']') { return }
            if ($separator -cne ',') { throw 'Expected JSON array separator.' }
        }
    }
    $start = $State.position
    while ($State.position -lt $State.text.Length -and @(' ', "`t", "`r", "`n", ',', ']', '}') -cnotcontains [string]$State.text[$State.position]) { $State.position++ }
    $token = $State.text.Substring($start, $State.position - $start)
    if (@('true', 'false', 'null') -ccontains $token) { return }
    # Restrict raw numeric spelling before either host can round/underflow it.
    if ($token -cnotmatch '^(0|[1-9][0-9]*)$' -or $token.Length -gt 16 -or
        ($token.Length -eq 16 -and [string]::CompareOrdinal($token, '9007199254740991') -gt 0)) { throw 'Expected canonical safe unsigned JSON integer.' }
}

function Assert-OfflineJsonLexemes([string]$Json) {
    $state = [pscustomobject]@{ text = $Json; position = 0 }
    Skip-OfflineJsonWhitespace $state
    if ($state.position -ge $Json.Length -or $Json[$state.position] -cne '{') { throw 'Manifest must be a JSON object.' }
    Read-OfflineJsonValue $state 0
    Skip-OfflineJsonWhitespace $state
    if ($state.position -ne $Json.Length) { throw 'Unexpected trailing JSON content.' }
}

function Test-OfflineCount($Value) {
    return ($null -ne $Value -and ($Value -is [int] -or $Value -is [long]) -and $Value -ge 0 -and $Value -le 9007199254740991)
}

function Assert-OfflineText($Value, [string]$Name) {
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { throw "$Name must be nonblank text." }
}

function Get-OfflineRunClass($Result) {
    if ($null -eq $Result) { return 'missing' }
    if ($Result -isnot [pscustomobject]) { return 'invalid' }
    if ($Result.status -isnot [string]) { return 'invalid' }
    if (@('timedOut', 'cancelled', 'skipped') -ccontains $Result.status) {
        return @{ timedOut = 'timeout'; cancelled = 'cancelled'; skipped = 'skipped' }[$Result.status]
    }
    if ($Result.status -cne 'completed') { return 'invalid' }
    foreach ($field in @('passed', 'failed', 'skipped')) {
        if (-not (Test-OfflineCount $Result.$field)) { return 'invalid' }
    }
    if ($Result.outcome -isnot [string] -or @('pass', 'fail') -cnotcontains $Result.outcome) { return 'invalid' }
    if (($Result.failed -gt 0 -and $Result.outcome -cne 'fail') -or ($Result.failed -eq 0 -and $Result.outcome -cne 'pass')) { return 'invalid' }
    if ($Result.passed -eq 0 -and $Result.failed -eq 0) { return 'ungraded' }
    if ($Result.failed -gt 0) { return 'fail' }
    return 'pass'
}

function ConvertTo-OfflineReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InputPath, [ValidateRange(1,16777216)][int]$MaxBytes = 4194304)
    $path = [IO.Path]::GetFullPath($InputPath)
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        if ($stream.Length -gt $MaxBytes) { throw "Input exceeds $MaxBytes bytes." }
        $buffer = New-Object byte[] ($MaxBytes + 1)
        $length = 0
        while ($length -lt $buffer.Length) {
            $read = $stream.Read($buffer, $length, $buffer.Length - $length)
            if ($read -eq 0) { break }
            $length += $read
        }
        if ($length -gt $MaxBytes) { throw "Input exceeds $MaxBytes bytes." }
        $bytes = New-Object byte[] $length
        [Array]::Copy($buffer, $bytes, $length)
    } finally { $stream.Dispose() }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    $json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    # UTF-8 BOM is accepted and remains part of the raw-byte fingerprint.
    if ($json.Length -gt 0 -and $json[0] -eq [char]0xfeff) { $json = $json.Substring(1) }
    Assert-OfflineJsonLexemes $json
    $manifest = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    if ($manifest -isnot [pscustomobject] -or -not (Test-OfflineCount $manifest.schemaVersion) -or $manifest.schemaVersion -ne 1) { throw 'Expected manifest schemaVersion 1.' }
    foreach ($identity in @('evaluator', 'fixture')) {
        if ($manifest.$identity -isnot [pscustomobject]) { throw "$identity must be an object." }
        Assert-OfflineText $manifest.$identity.id "$identity.id"
        Assert-OfflineText $manifest.$identity.version "$identity.version"
    }
    if ($manifest.expectedRuns -isnot [Array] -or $manifest.expectedRuns.Count -eq 0) { throw 'expectedRuns must be a nonempty array.' }
    if ($null -ne $manifest.usage -and $manifest.usage -isnot [Array]) { throw 'usage must be an array or null.' }
    if ($manifest.expectedRuns.Count -gt 4096 -or @($manifest.usage).Count -gt 4096) { throw 'At most 4096 runs and usage observations are supported.' }
    $runIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $runs = @()
    $counts = [ordered]@{ pass = 0; fail = 0; ungraded = 0; invalid = 0; missing = 0; timeout = 0; cancelled = 0; skipped = 0 }
    foreach ($run in $manifest.expectedRuns) {
        if ($run -isnot [pscustomobject]) { throw 'Each expectedRuns element must be an object.' }
        Assert-OfflineText $run.runId 'runId'
        if (-not $runIds.Add($run.runId)) { throw "Duplicate runId: $($run.runId)" }
        $class = Get-OfflineRunClass $run.result
        $counts[$class]++
        $runs += [pscustomobject][ordered]@{ runId = $run.runId; classification = $class }
    }
    $metrics = @('inputTokens', 'outputTokens', 'cacheReadTokens', 'cacheWriteTokens')
    $calls = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $observations = 0
    foreach ($item in $manifest.usage) {
        if ($item -isnot [pscustomobject]) { throw 'Each usage element must be an object.' }
        $observations++
        Assert-OfflineText $item.callId 'callId'
        $record = [ordered]@{ callId = $item.callId; parentCallId = $null; runtime = $null; requestedModel = $null; observedModel = $null; observationSource = $null }
        foreach ($field in @('parentCallId', 'runtime', 'requestedModel', 'observedModel', 'observationSource')) {
            if ($null -ne $item.$field) { Assert-OfflineText $item.$field $field; $record[$field] = $item.$field }
        }
        if ($null -ne $record.observedModel -and $null -eq $record.observationSource) { throw 'observedModel requires observationSource.' }
        foreach ($field in $metrics) {
            if ($null -ne $item.$field -and -not (Test-OfflineCount $item.$field)) { throw "Invalid $field for call $($item.callId)." }
            $record[$field] = $null
            if ($null -ne $item.$field) { $record[$field] = [long]$item.$field }
        }
        $signature = ConvertTo-Json -InputObject $record -Compress -Depth 6
        if ($calls.ContainsKey($item.callId)) {
            $existing = $calls[$item.callId]
            $existing.observationCount++
            if ($existing.signature -cne $signature) { $existing.conflicted = $true }
        } else {
            $calls.Add($item.callId, [pscustomobject]@{ record = $record; signature = $signature; conflicted = $false; observationCount = 1 })
        }
    }
    # Validate the parent graph even when telemetry conflicts; conflicts cannot hide malformed graph evidence.
    foreach ($item in $manifest.usage) {
        if ($null -ne $item.parentCallId -and -not $calls.ContainsKey($item.parentCallId)) { throw "Unresolved parentCallId: $($item.parentCallId)" }
    }
    $parents = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $children = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($id in $calls.Keys) {
        $parents.Add($id, [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal))
        $children.Add($id, [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal))
    }
    foreach ($item in $manifest.usage) {
        if ($null -ne $item.parentCallId) { [void]$parents[$item.callId].Add($item.parentCallId); [void]$children[$item.parentCallId].Add($item.callId) }
    }
    $ready = [Collections.Generic.Queue[string]]::new()
    foreach ($id in $calls.Keys) { if ($parents[$id].Count -eq 0) { $ready.Enqueue($id) } }
    $visitedCount = 0
    while ($ready.Count -gt 0) {
        $id = $ready.Dequeue(); $visitedCount++
        foreach ($child in $children[$id]) {
            [void]$parents[$child].Remove($id)
            if ($parents[$child].Count -eq 0) { $ready.Enqueue($child) }
        }
    }
    if ($visitedCount -ne $calls.Count) { throw 'Parent cycle in usage observations.' }
    $normalized = @()
    foreach ($id in $calls.Keys) {
        $entry = $calls[$id]
        if ($entry.conflicted) {
            $normalized += [pscustomobject]@{ callId = $id; status = 'conflicted'; observationCount = $entry.observationCount; attributionStatus = 'unresolved'; evidence = $null }
        } else {
            $attribution = 'unavailable'
            if ($null -ne $entry.record.observedModel) { $attribution = 'observed' }
            $normalized += [pscustomobject]@{ callId = $id; status = 'resolved'; observationCount = $entry.observationCount; attributionStatus = $attribution; evidence = [pscustomobject]$entry.record }
        }
    }
    $totals = [ordered]@{}
    foreach ($field in $metrics) {
        [decimal]$sum = 0
        $known = 0
        foreach ($entry in $calls.Values) {
            if (-not $entry.conflicted -and $null -ne $entry.record[$field]) { $sum += [decimal]$entry.record[$field]; $known++ }
        }
        $status = 'known'; $total = $null; $exactTotal = $null
        if ($calls.Count -eq 0 -or $known -ne $calls.Count) { $status = 'unknown' }
        elseif ($sum -gt 9007199254740991) { $status = 'overflow'; $exactTotal = $sum.ToString([Globalization.CultureInfo]::InvariantCulture) }
        else { $total = [long]$sum }
        $totals[$field] = [pscustomobject]@{ status = $status; total = $total; exactTotal = $exactTotal; knownSubtotal = $sum.ToString([Globalization.CultureInfo]::InvariantCulture); knownCalls = $known; expectedCalls = $calls.Count }
    }
    $reasons = @()
    if ($counts.pass -ne $runs.Count) { $reasons += 'non-pass-evaluation' }
    if (@($normalized | Where-Object { $_.attributionStatus -ne 'observed' }).Count -gt 0) { $reasons += 'unresolved-model-attribution' }
    if (@($totals.Values | Where-Object { $_.status -ne 'known' }).Count -gt 0) { $reasons += 'incomplete-usage' }
    $certificationStatus = 'complete'
    if ($reasons.Count -gt 0) { $certificationStatus = 'incomplete' }
    return [pscustomobject][ordered]@{
        schemaVersion = 1
        certificationStatus = $certificationStatus
        certificationReasons = @($reasons)
        provenance = [pscustomobject]@{ rawSha256 = $hash; rawBytes = $length; normalizerVersion = '1'; evaluator = $manifest.evaluator; fixture = $manifest.fixture }
        denominator = [pscustomobject]@{ expected = $runs.Count; classified = $runs.Count; classes = [pscustomobject]$counts; graded = $counts.pass + $counts.fail; ungraded = $counts.ungraded + $counts.skipped; infrastructureFailed = $counts.invalid + $counts.missing + $counts.timeout; cancelled = $counts.cancelled }
        runs = @($runs)
        usage = [pscustomobject]@{ observations = $observations; uniqueCalls = $calls.Count; calls = @($normalized); totals = [pscustomobject]$totals }
    }
}
