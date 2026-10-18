[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [Parameter(Mandatory)][string]$ArgumentsBase64
)
$ErrorActionPreference='Stop'
$encoding=[Text.UTF8Encoding]::new($false)
[Console]::InputEncoding=$encoding
[Console]::OutputEncoding=$encoding
$json=$encoding.GetString([Convert]::FromBase64String($ArgumentsBase64))
if (-not $json.TrimStart().StartsWith('[')) { throw 'Script argument transport requires a JSON string array.' }
$parsed=$json | ConvertFrom-Json
$decoded=@($parsed)
foreach ($item in $decoded) { if ($item -isnot [string]) { throw 'Script argument transport only accepts literal strings.' } }
[string[]]$scriptArguments=@($decoded)
$global:LASTEXITCODE=0
& $ScriptPath @scriptArguments
if (-not $?) { exit 1 }
exit $LASTEXITCODE
