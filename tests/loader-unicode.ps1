[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$powershellExecutable = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-unicode-$([Guid]::NewGuid().ToString('N'))"
$projectRoot = Join-Path $temporaryRoot 'No Git - ทดสอบ 記憶'

try {
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
    & (Join-Path $repositoryRoot 'scripts/initialize-memory.ps1') -ProjectPath $projectRoot

    $memoryDirectory = Join-Path $projectRoot '.agent-memory'
    [System.IO.File]::WriteAllText((Join-Path $memoryDirectory 'MEMORY.md'), 'unicode-project-marker')

    $payload = [ordered]@{
        session_id = 'unicode-loader-test'
        cwd = $projectRoot
        hook_event_name = 'SessionStart'
        source = 'startup'
    } | ConvertTo-Json -Compress
    $inputPath = Join-Path $temporaryRoot 'loader.stdin.json'
    $outputPath = Join-Path $temporaryRoot 'loader.stdout.json'
    $errorPath = Join-Path $temporaryRoot 'loader.stderr.txt'
    [System.IO.File]::WriteAllText($inputPath, $payload, [System.Text.UTF8Encoding]::new($false))

    $process = Start-Process -FilePath $powershellExecutable -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repositoryRoot 'codex/hooks/load-project-memory.ps1')
    ) -RedirectStandardInput $inputPath -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Loader exited with code $($process.ExitCode): $([System.IO.File]::ReadAllText($errorPath))"
    }

    $output = [System.IO.File]::ReadAllText($outputPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $context = [string]$output.hookSpecificOutput.additionalContext
    if ($context -notlike '*unicode-project-marker*') {
        throw "Assertion failed: loader did not preserve the UTF-8 cwd or load project-local fallback Memory. Context: $context"
    }

    Write-Host 'Unicode loader test passed.'
} finally {
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if (
        $resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and
        (Test-Path -LiteralPath $resolvedTemporaryRoot)
    ) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
