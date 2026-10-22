#requires -Version 5.1
[CmdletBinding()]
param([string]$DataRoot, [switch]$Scheduled)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Bridge.psm1') -Force
    $root=Get-BridgeRoot $DataRoot
    Invoke-BridgeLocked $root {
        $updates=Get-BridgeUpdates $root
        $updates
        if ($Scheduled -and $updates.Policy -eq 'Unattended' -and ($updates.TunnelUpdate -or $updates.McpUpdate)) {
            if (-not (Test-BridgeLifetime $root)) {
                Update-Bridge -Root $root -TunnelVersion $updates.TunnelLatest -McpVersion $updates.McpLatest
            }
        }
    }
} catch { Write-Error ('Update check failed: ' + $_.Exception.Message); exit 1 }
