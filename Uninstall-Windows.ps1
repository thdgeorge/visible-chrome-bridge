#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param([string]$DataRoot, [switch]$RemoveData)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Bridge.psm1') -Force
    $root=Get-BridgeRoot $DataRoot
    if ($PSCmdlet.ShouldProcess('Owned Visible Chrome Bridge installation', 'Stop bridge and remove its startup registration')) {
        Invoke-BridgeLocked $root {
            Uninstall-Bridge -Root $root -RemoveData:$RemoveData
        } -RemoveDataAfterAction:$RemoveData
    }
} catch { Write-Error ('Uninstall failed: ' + $_.Exception.Message); exit 1 }
