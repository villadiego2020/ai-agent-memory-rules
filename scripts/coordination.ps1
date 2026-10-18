$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../skills/agent-coordination/scripts/coordination.ps1') @args
