#requires -Version 5.1
[CmdletBinding()]
param([string]$DataRoot)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Bridge.psm1') -Force
    Get-BridgeStatus (Get-BridgeRoot $DataRoot)
} catch { Write-Error ('Status failed: ' + $_.Exception.Message); exit 1 }
