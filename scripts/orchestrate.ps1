$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot '../skills/agent-coordination/scripts/orchestrate.ps1') @args
