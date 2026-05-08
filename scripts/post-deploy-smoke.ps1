#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Quick post-deploy smoke test against the deployed Container App.

.PARAMETER AppUrl
  https URL of the Container App (the `appUrl` Bicep output).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $AppUrl
)

$ErrorActionPreference = 'Stop'
$AppUrl = $AppUrl.TrimEnd('/')

Write-Host "Pinging $AppUrl/health ..." -ForegroundColor Cyan
for ($i = 0; $i -lt 18; $i++) {
    try {
        $r = Invoke-RestMethod "$AppUrl/health" -TimeoutSec 5
        Write-Host "/health -> $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
        break
    } catch {
        Start-Sleep -Seconds 5
    }
    if ($i -eq 17) { throw "App never became healthy after 90s." }
}

Write-Host "`nFetching $AppUrl/api/diag ..." -ForegroundColor Cyan
$diag = Invoke-RestMethod "$AppUrl/api/diag"
$diag | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "`nFetching $AppUrl/api/config ..." -ForegroundColor Cyan
$cfg = Invoke-RestMethod "$AppUrl/api/config"
$cfg | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "`nSmoke test passed." -ForegroundColor Green
