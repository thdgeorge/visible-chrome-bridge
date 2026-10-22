#requires -Version 5.1
[CmdletBinding()]
param([string]$DataRoot)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Bridge.psm1') -Force
    $root=Get-BridgeRoot $DataRoot
    Invoke-BridgeLocked $root { Stop-Bridge $root }
    Write-Output 'Owned bridge stopped. Chrome remains running.'
} catch { Write-Error ('Stop failed: ' + $_.Exception.Message); exit 1 }
