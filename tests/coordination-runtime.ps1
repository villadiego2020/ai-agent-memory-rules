[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hostExecutable = (Get-Process -Id $PID).Path
$boardCommand = Join-Path $repo 'scripts/coordination.ps1'
$orchestrator = Join-Path $repo 'scripts/orchestrate.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) "coordination-runtime-$([guid]::NewGuid().ToString('N'))"
$thaiPathPart = [string]::Concat([char]0x0E07, [char]0x0E32, [char]0x0E19)
$project = Join-Path $temp "$thaiPathPart with spaces"
$stub = Join-Path $temp 'agent stub.ps1'
$capture = Join-Path $temp 'capture.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "Assertion failed: $Message" } }

function Invoke-CommandFile {
    param([string]$Script, [string[]]$Arguments, [switch]$Fails)
    $ErrorActionPreference = 'Continue'
    $output = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    if ($Fails -and $exitCode -eq 0) { throw "Expected rejection: $Script $($Arguments -join ' ')`n$output" }
    if (-not $Fails -and $exitCode -ne 0) {
        $artifactRoot = Join-Path $project '.agent-coordination/artifacts'
        $recentError = if (Test-Path -LiteralPath $artifactRoot) { Get-ChildItem -LiteralPath $artifactRoot -Filter 'process.stderr.log' -Recurse -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1 } else { $null }
        $detail = if ($recentError) { [IO.File]::ReadAllText($recentError.FullName, [Text.Encoding]::UTF8) } else { '' }
        throw "Command failed ($exitCode): $Script $($Arguments -join ' ')`n$output`nAgent stderr: $detail"
    }
    return ($output -join "`n")
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

    $stubSource = @'
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$argv = @($args)
$stdin = [Console]::In.ReadToEnd()
$captureRecord = [ordered]@{ argv = $argv; stdin = $stdin; cwd = (Get-Location).Path }
[IO.File]::WriteAllText($env:COORDINATION_TEST_CAPTURE, ($captureRecord | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
if ($env:COORDINATION_TEST_MODE -eq 'sleep') { Start-Sleep -Seconds 5 }
if ($env:COORDINATION_TEST_MODE -eq 'fail') { exit 7 }
if ($env:COORDINATION_TEST_MODE -eq 'auth') {
    [ordered]@{ is_error = $true; result = 'Failed to authenticate: OAuth session expired and could not be refreshed. private-test-marker'; usage = @{ input_tokens = 0; output_tokens = 0 } } | ConvertTo-Json -Depth 8 -Compress | Write-Output
    exit 1
}
if ($env:COORDINATION_TEST_MODE -eq 'tamper') { [IO.File]::WriteAllText((Join-Path (Get-Location).Path 'src/reviewer-edit.txt'), 'review changed source') }
$thaiReportPart = [string]::Concat([char]0x0E07, [char]0x0E32, [char]0x0E19)
$report = [ordered]@{ schemaVersion = 1; outcome = 'pass'; summary = "reviewed $thaiReportPart `"quotes`""; evidence = @('stub evidence'); limitations = @(); changedFiles = @() }
if ($env:COORDINATION_TEST_MODE -eq 'malformed') { $report = [ordered]@{ invalid = $true } }
$index = [Array]::IndexOf($argv, '--output-last-message')
if ($index -ge 0) {
    [IO.File]::WriteAllText($argv[$index + 1], ($report | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
} else {
    [ordered]@{ structured_output = $report } | ConvertTo-Json -Depth 12 -Compress | Write-Output
}
'@
    [IO.File]::WriteAllText($stub, $stubSource, [Text.UTF8Encoding]::new($true))
    $env:COORDINATION_TEST_CAPTURE = $capture
    $env:COORDINATION_TEST_MODE = 'pass'

    Invoke-CommandFile $boardCommand @('init', '-ProjectPath', $project) | Out-Null
    Invoke-CommandFile $boardCommand @('new', '-ProjectPath', $project, '-Kind', 'bugfix', '-Risk', 'high', '-Runtime', 'codex', '-Title', 'CLI dispatch', '-Goal', 'Bounded peer review', '-Acceptance', 'Capture arguments and prompt', '-Owner', 'codex:lead', '-OwnedFile', 'src/example.txt') | Out-Null
    Invoke-CommandFile $boardCommand @('plan', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead', '-Summary', 'Manual runtime fixture', '-Evidence', 'fixture', '-NoChecksReason', 'CLI contract check only') | Out-Null

    $carefulCodex = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex') | ConvertFrom-Json
    Assert-True ($carefulCodex.execute -eq $false -and $carefulCodex.role -eq 'careful' -and $carefulCodex.model -eq 'gpt-6.1-sol' -and $carefulCodex.effort -eq 'high') 'High-risk Codex implementation previews careful tier.'
    $carefulClaude = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'claude') | ConvertFrom-Json
    Assert-True ($carefulClaude.role -eq 'careful' -and $carefulClaude.model -eq 'sonnet' -and $carefulClaude.effort -eq 'high') 'High-risk Claude implementation previews careful tier.'
    $imagePreview = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex', '-Workload', 'image') | ConvertFrom-Json
    Assert-True ($imagePreview.workload -eq 'image' -and $imagePreview.role -eq 'image' -and $imagePreview.model -eq 'gpt-6-astra' -and $imagePreview.effort -eq 'medium') 'High-risk image workload keeps image tier pending independent review.'
    $computerPreview = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex', '-Workload', 'computer') | ConvertFrom-Json
    Assert-True ($computerPreview.workload -eq 'computer' -and $computerPreview.role -eq 'computer' -and $computerPreview.model -eq 'gpt-6.1-terra' -and $computerPreview.effort -eq 'medium') 'High-risk Computer Use workload keeps computer tier pending independent review.'
    $codePreview = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex', '-Workload', 'code') | ConvertFrom-Json
    Assert-True ($codePreview.role -eq 'careful' -and $codePreview.model -eq 'gpt-6.1-sol' -and $codePreview.effort -eq 'high') 'High-risk code workload retains careful tier.'
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'claude', '-Workload', 'image') -Fails | Out-Null
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'review', '-Runtime', 'codex', '-Workload', 'computer') -Fails | Out-Null
    Invoke-CommandFile $boardCommand @('plan', '-ProjectPath', $project, '-Id', 'T-000001', '-Owner', 'codex:lead', '-Summary', 'Complex coordination', '-Evidence', 'fixture', '-NoChecksReason', 'CLI contract check only', '-HardProblem', 'Cross-module race requires deeper reasoning') | Out-Null
    $hardCodex = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex') | ConvertFrom-Json
    Assert-True ($hardCodex.role -eq 'hard' -and $hardCodex.model -eq 'gpt-6-astra' -and $hardCodex.effort -eq 'high') 'Named difficult problem previews Codex hard tier.'
    $hardComputer = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex', '-Workload', 'computer') | ConvertFrom-Json
    Assert-True ($hardComputer.role -eq 'hard' -and $hardComputer.model -eq 'gpt-6-astra' -and $hardComputer.effort -eq 'high') 'Named difficult problem takes precedence over explicit workload.'
    $hardClaude = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'claude') | ConvertFrom-Json
    Assert-True ($hardClaude.role -eq 'hard' -and $hardClaude.model -eq 'opus' -and $hardClaude.effort -eq 'high') 'Named difficult problem previews Claude hard tier.'
    $reviewPreview = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'review') | ConvertFrom-Json
    Assert-True ($reviewPreview.runtime -eq 'claude' -and $reviewPreview.role -eq 'review' -and $reviewPreview.model -eq 'sonnet' -and $reviewPreview.effort -eq 'xhigh') 'Named hard problem preserves independent peer review tier.'

    $before = (Get-Content -LiteralPath (Join-Path $project '.agent-coordination/tasks/T-000001.json') -Raw)
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'review', '-Runtime', 'claude', '-Actor', 'claude:peer', '-CliPath', $stub) | Out-Null
    Assert-True (-not (Test-Path -LiteralPath $capture)) 'Dry run did not launch a process.'
    $after = (Get-Content -LiteralPath (Join-Path $project '.agent-coordination/tasks/T-000001.json') -Raw)
    Assert-True ($before -eq $after) 'Dry run did not modify the task.'

    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'review', '-Runtime', 'claude', '-Actor', 'claude:peer', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') | Out-Null
    Assert-True (Test-Path -LiteralPath $capture) 'Executed CLI created capture.'
    $observed = [IO.File]::ReadAllText($capture, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ($observed.cwd -eq $project) 'CLI working directory is project root.'
    Assert-True ($observed.stdin -match 'CLI dispatch') 'CLI received task context over stdin.'
    Assert-True (@($observed.argv) -contains '--print') 'Claude received structured print invocation.'
    Assert-True (@($observed.argv) -contains '--json-schema') 'Claude received report schema.'
    $claudeArguments = @($observed.argv)
    $schemaIndex = [Array]::IndexOf($claudeArguments, '--json-schema')
    Assert-True ($schemaIndex -ge 0 -and $schemaIndex + 1 -lt $claudeArguments.Count) 'Claude schema has a value argument.'
    $claudeSchema = [string]$claudeArguments[$schemaIndex + 1] | ConvertFrom-Json
    $canonicalSchemaPath = Join-Path $repo 'skills/agent-coordination/schemas/result.schema.json'
    $canonicalSchema = [IO.File]::ReadAllText($canonicalSchemaPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ($null -ne $canonicalSchema.PSObject.Properties['$schema']) 'Canonical result schema retains its draft declaration.'
    Assert-True ($null -eq $claudeSchema.PSObject.Properties['$schema']) 'Claude receives a portable schema without unsupported draft metadata.'
    Assert-True ($claudeSchema.type -eq 'object' -and $claudeSchema.additionalProperties -eq $false) 'Claude schema retains object shape and disallows extra fields.'
    $requiredFields = @('schemaVersion', 'outcome', 'summary', 'evidence', 'limitations', 'changedFiles')
    Assert-True (@($claudeSchema.required).Count -eq $requiredFields.Count -and @($requiredFields | Where-Object { $_ -notin @($claudeSchema.required) }).Count -eq 0) 'Claude schema retains every required result field.'
    Assert-True ($claudeSchema.properties.schemaVersion.type -eq 'integer' -and @($claudeSchema.properties.schemaVersion.enum).Count -eq 1 -and $claudeSchema.properties.schemaVersion.enum[0] -eq 1) 'Claude schema retains version constraint.'
    $expectedOutcomes = @('pass', 'fail', 'needs-input')
    Assert-True ($claudeSchema.properties.outcome.type -eq 'string' -and @($claudeSchema.properties.outcome.enum).Count -eq 3 -and @($expectedOutcomes | Where-Object { $_ -notin @($claudeSchema.properties.outcome.enum) }).Count -eq 0) 'Claude schema retains allowed outcomes.'
    foreach ($field in @('evidence', 'limitations', 'changedFiles')) {
        Assert-True ($claudeSchema.properties.$field.type -eq 'array' -and $claudeSchema.properties.$field.items.type -eq 'string') "Claude schema retains $field string array."
    }
    $canonicalSchema.PSObject.Properties.Remove('$schema')
    $expectedPortableSchema = $canonicalSchema | ConvertTo-Json -Depth 20 -Compress
    $actualPortableSchema = $claudeSchema | ConvertTo-Json -Depth 20 -Compress
    Assert-True ($expectedPortableSchema -eq $actualPortableSchema) 'Claude schema preserves every canonical constraint after removing draft metadata.'

    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'analysis', '-Runtime', 'codex', '-Actor', 'codex:lead', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') | Out-Null
    $codexObserved = [IO.File]::ReadAllText($capture, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True (@($codexObserved.argv) -contains 'exec') 'Codex received exec subcommand.'
    Assert-True (@($codexObserved.argv) -contains '--output-last-message') 'Codex received structured result path.'
    Assert-True ($codexObserved.stdin -match 'CLI dispatch') 'Codex received task context over stdin.'

    $env:COORDINATION_TEST_MODE = 'auth'
    $authFailure = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'review', '-Runtime', 'claude', '-Actor', 'claude:peer', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') -Fails
    Assert-True ($authFailure -match 'claude auth login') 'Expired Claude OAuth returns an actionable login hint.'
    Assert-True ($authFailure -notmatch 'private-test-marker') 'Authentication failure does not expose raw CLI result text.'

    $env:COORDINATION_TEST_MODE = 'tamper'
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'review', '-Runtime', 'claude', '-Actor', 'claude:peer', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') -Fails | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $project 'src/reviewer-edit.txt')) 'Adversarial reviewer actually changed source.'
    [IO.File]::Delete((Join-Path $project 'src/reviewer-edit.txt'))

    $env:COORDINATION_TEST_MODE = 'malformed'
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'analysis', '-Runtime', 'codex', '-Actor', 'codex:lead', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') -Fails | Out-Null
    $env:COORDINATION_TEST_MODE = 'fail'
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'analysis', '-Runtime', 'codex', '-Actor', 'codex:lead', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') -Fails | Out-Null
    $env:COORDINATION_TEST_MODE = 'sleep'
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'analysis', '-Runtime', 'codex', '-Actor', 'codex:lead', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '1') -Fails | Out-Null
    Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'analysis', '-Runtime', 'codex', '-Actor', 'codex:lead', '-CliPath', (Join-Path $temp 'unavailable-cli.ps1'), '-Execute') -Fails | Out-Null

    Invoke-CommandFile $boardCommand @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Risk', 'low', '-Title', 'Hard at intake', '-Goal', 'Route named difficulty', '-Acceptance', 'Preview hard tier', '-Owner', 'codex:intake', '-OwnedFile', 'docs', '-HardProblem', 'Novel dependency cycle') | Out-Null
    $intakeHard = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000002', '-Phase', 'plan') | ConvertFrom-Json
    Assert-True ($intakeHard.role -eq 'hard' -and $intakeHard.model -eq 'gpt-6-astra') 'HardProblem supplied at new routes the plan preview to hard tier.'
    Invoke-CommandFile $boardCommand @('new', '-ProjectPath', $project, '-Kind', 'feature', '-Risk', 'low', '-Runtime', 'codex', '-Title', 'Workload dispatch', '-Goal', 'Route one bounded implementation', '-Acceptance', 'Correct model and effort reach CLI', '-Owner', 'codex:operator', '-OwnedFile', 'images') | Out-Null
    Invoke-CommandFile $boardCommand @('plan', '-ProjectPath', $project, '-Id', 'T-000003', '-Owner', 'codex:operator', '-Summary', 'Use stub CLI', '-Evidence', 'fixture', '-NoChecksReason', 'CLI contract check only') | Out-Null
    $legacyLow = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000003', '-Phase', 'implement', '-Runtime', 'codex') | ConvertFrom-Json
    Assert-True ($legacyLow.role -eq 'routine' -and $legacyLow.effort -eq 'low') 'Unspecified low-risk workload retains legacy routing.'
    $lowCode = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000003', '-Phase', 'implement', '-Runtime', 'codex', '-Workload', 'code') | ConvertFrom-Json
    Assert-True ($lowCode.role -eq 'implement' -and $lowCode.model -eq 'gpt-6.1-sol' -and $lowCode.effort -eq 'medium') 'Explicit code workload uses Sol medium even at low risk.'
    $env:COORDINATION_TEST_MODE = 'pass'
    foreach ($route in @(
        @{ name = 'image'; model = 'gpt-6-astra'; role = 'image' },
        @{ name = 'computer'; model = 'gpt-6.1-terra'; role = 'computer' },
        @{ name = 'code'; model = 'gpt-6.1-sol'; role = 'implement' }
    )) {
        Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000003', '-Phase', 'implement', '-Runtime', 'codex', '-Workload', $route.name, '-Actor', 'codex:operator', '-CliPath', $stub, '-Execute', '-TimeoutSeconds', '4') | Out-Null
        $actual = [IO.File]::ReadAllText($capture, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $argv = @($actual.argv)
        $modelIndex = [Array]::IndexOf($argv, '--model')
        Assert-True ($modelIndex -ge 0 -and $argv[$modelIndex + 1] -eq $route.model) "The $($route.name) workload model reached the Codex CLI."
        Assert-True (@($argv) -contains 'model_reasoning_effort="medium"') "The $($route.name) workload effort reached the Codex CLI."
        Assert-True ($actual.stdin -match ('"workload":\s*"' + $route.name + '"')) "The $($route.name) workload appears in the task brief."
        $run = @((Get-Content -Raw -LiteralPath (Join-Path $project '.agent-coordination/tasks/T-000003.json') | ConvertFrom-Json).runs)[-1]
        Assert-True ($run.workload -eq $route.name -and $run.role -eq $route.role -and $run.model -eq $route.model) "The $($route.name) workload is recorded in the run receipt."
    }
    $legacyTaskPath = Join-Path $project '.agent-coordination/tasks/T-000001.json'
    $legacyTask = [IO.File]::ReadAllText($legacyTaskPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $legacyTask.PSObject.Properties.Remove('hardProblem')
    [IO.File]::WriteAllText($legacyTaskPath, (($legacyTask | ConvertTo-Json -Depth 40) + "`n"), [Text.UTF8Encoding]::new($false))
    $legacyPreview = Invoke-CommandFile $orchestrator @('-ProjectPath', $project, '-Id', 'T-000001', '-Phase', 'implement', '-Runtime', 'codex') | ConvertFrom-Json
    Assert-True ($legacyPreview.role -eq 'careful' -and $legacyPreview.model -eq 'gpt-6.1-sol') 'Older task without hardProblem retains high-risk careful routing.'
    Invoke-CommandFile $boardCommand @('validate', '-ProjectPath', $project) | Out-Null

    Write-Host 'Coordination runtime checks passed.'
} finally {
    Remove-Item Env:COORDINATION_TEST_CAPTURE -ErrorAction SilentlyContinue
    Remove-Item Env:COORDINATION_TEST_MODE -ErrorAction SilentlyContinue
    $base = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolved = [IO.Path]::GetFullPath($temp)
    if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -and $resolved -ne $base -and (Test-Path -LiteralPath $resolved)) {
        Get-ChildItem -LiteralPath $resolved -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
        [IO.Directory]::Delete($resolved, $true)
    }
}
