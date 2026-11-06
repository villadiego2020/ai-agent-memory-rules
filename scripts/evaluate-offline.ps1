[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [string]$OutputPath,
    [ValidateRange(1,16777216)][int]$MaxBytes = 4194304
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/OfflineEvaluation.ps1')
$report = ConvertTo-OfflineReport -InputPath $InputPath -MaxBytes $MaxBytes
$json = (ConvertTo-Json -InputObject $report -Depth 20) + "`n"
if ($OutputPath) {
    $inputFull = [IO.Path]::GetFullPath($InputPath)
    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    if ([string]::Equals($inputFull, $outputFull, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must differ from input.' }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $staging = Join-Path ([IO.Path]::GetDirectoryName($outputFull)) ('.offline-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $stream = [IO.File]::Open($staging, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
        [IO.File]::Move($staging, $outputFull)
    } finally { if ([IO.File]::Exists($staging)) { [IO.File]::Delete($staging) } }
}
$json
if ($report.certificationStatus -ne 'complete') { exit 2 }
exit 0
