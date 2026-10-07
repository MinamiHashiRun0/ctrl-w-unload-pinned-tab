#Requires -RunAsAdministrator
<#
  Install / rollback the Waterfox AutoConfig patch that turns Ctrl+W on a PINNED tab
  into an unload (discard) instead of doing nothing.

  Usage:
    .\install.ps1                      # install (asks nothing)
    .\install.ps1 -Rollback            # undo
    .\install.ps1 -AppDir 'D:\Program Files\Waterfox'

  Requires admin rights (Waterfox lives under Program Files).
  Waterfox must be fully quit and restarted for changes to take effect.
#>
[CmdletBinding()]
param(
  [string]$AppDir = 'D:\Program Files\Waterfox',
  [switch]$Rollback
)

$ErrorActionPreference = 'Stop'
$src      = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgFile  = Join-Path $AppDir 'config.js'
$prefDir  = Join-Path $AppDir 'defaults\pref'
$prefFile = Join-Path $prefDir 'autoconfig.js'

if (-not (Test-Path (Join-Path $AppDir 'waterfox.exe'))) {
  throw "waterfox.exe not found in $AppDir -- pass -AppDir explicitly."
}

$backup = Join-Path $src ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
if (Test-Path $cfgFile)  { Copy-Item $cfgFile  (Join-Path $backup 'config.js')     -Force }
if (Test-Path $prefFile) { Copy-Item $prefFile (Join-Path $backup 'autoconfig.js') -Force }

if ($Rollback) {
  if (Test-Path (Join-Path $backup 'config.js')) {
    Copy-Item (Join-Path $backup 'config.js') $cfgFile -Force
  } else {
    Remove-Item $cfgFile -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path (Join-Path $backup 'autoconfig.js')) {
    Copy-Item (Join-Path $backup 'autoconfig.js') $prefFile -Force
  } else {
    Remove-Item $prefFile -Force -ErrorAction SilentlyContinue
  }
  Write-Host "Rolled back. Files restored from: $backup"
} else {
  New-Item -ItemType Directory -Force -Path $prefDir | Out-Null
  Copy-Item (Join-Path $src 'config.js')     $cfgFile  -Force
  Copy-Item (Join-Path $src 'autoconfig.js') $prefFile -Force
  Write-Host "Installed:"
  Write-Host "  $cfgFile"
  Write-Host "  $prefFile"
  Write-Host "Backup of previous state: $backup"
}

Write-Host ""
Write-Host "Now fully quit Waterfox (check Task Manager for leftover waterfox.exe) and start it again."
Write-Host "Check: pin a tab, press Ctrl+W -> the tab should grey out and stay pinned in the strip."
