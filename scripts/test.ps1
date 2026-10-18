[CmdletBinding()]
param(
    [string[]]$TestName = @()
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$powershellExecutable = (Get-Process -Id $PID).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-Check {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Path, [string[]]$Arguments = @())
    Write-Host "RUN $Name"
    & $powershellExecutable -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$Name (exit $LASTEXITCODE)")
        Write-Host "FAIL $Name"
    } else {
        Write-Host "PASS $Name"
    }
}

$tests = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'tests') -Filter '*.ps1' -File | Sort-Object Name)
if ($TestName.Count -gt 0) {
    $tests = @($tests | Where-Object {
        $test = $_
        @($TestName | Where-Object { $test.Name -like $_ -or $test.BaseName -like $_ }).Count -gt 0
    })
    if ($tests.Count -eq 0) { throw "No tests matched: $($TestName -join ', ')" }
}

Invoke-Check -Name 'repository validation' -Path (Join-Path $PSScriptRoot 'validate.ps1') -Arguments @('-ProjectPath', $repositoryRoot)
foreach ($test in $tests) {
    Invoke-Check -Name $test.Name -Path $test.FullName
}

if ($failures.Count -gt 0) {
    throw "$($failures.Count) check(s) failed: $($failures -join '; ')"
}
Write-Host "All checks passed ($($tests.Count) test script(s) and repository validation)."
