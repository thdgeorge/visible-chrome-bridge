#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DataRoot)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Bridge.psm1') -Force
    Invoke-BridgeWorker (Get-BridgeRoot $DataRoot)
} catch { exit 1 }
