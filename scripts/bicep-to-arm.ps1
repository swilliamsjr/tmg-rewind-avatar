#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Rebuild infra/azuredeploy.json from infra/main.bicep.

.DESCRIPTION
  The Deploy-to-Azure button targets the committed ARM JSON file.
  Always run this after editing any *.bicep file in /infra and commit
  the regenerated infra/azuredeploy.json alongside the Bicep change.
#>
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    az bicep build --file infra/main.bicep --outfile infra/azuredeploy.json
    Write-Host "Wrote infra/azuredeploy.json ($((Get-Item infra/azuredeploy.json).Length) bytes)"
} finally { Pop-Location }
