#Requires -RunAsAdministrator
<#
  Install / rollback the AutoConfig patch that turns Ctrl+W on a PINNED tab into an
  unload (discard) instead of doing nothing. Works for Waterfox and Firefox.

  Usage:
    .\install.ps1                              # auto-detect install dir, install
    .\install.ps1 -AppDir 'C:\Program Files\Waterfox'
    .\install.ps1 -Rollback                    # undo using the newest backup-* folder
    .\install.ps1 -WhatIfOnly                  # print what would be done, touch nothing

  Requires admin rights (browsers live under Program Files).
  Fully quit the browser and start it again for changes to take effect.
#>
[CmdletBinding()]
param(
  [string]$AppDir,
  [switch]$Rollback,
  [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-BrowserDir([string]$dir) {
  if (-not $dir) { return $false }
  return ((Test-Path (Join-Path $dir 'waterfox.exe')) -or (Test-Path (Join-Path $dir 'firefox.exe')))
}

function Find-BrowserDir {
  $candidates = @()
  $roots = @(
    'HKLM:\SOFTWARE\Waterfox', 'HKLM:\SOFTWARE\WOW6432Node\Waterfox', 'HKCU:\SOFTWARE\Waterfox',
    'HKLM:\SOFTWARE\Mozilla\Mozilla Firefox', 'HKCU:\SOFTWARE\Mozilla\Mozilla Firefox'
  )
  foreach ($root in $roots) {
    try {
      $base = Get-ItemProperty -Path $root -ErrorAction Stop
      if ($base.InstallDirectory) { $candidates += $base.InstallDirectory }
      Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
        $bin = Get-ItemProperty -Path (Join-Path $_.PSPath 'bin') -ErrorAction SilentlyContinue
        if ($bin.PathToExe) { $candidates += (Split-Path $bin.PathToExe -Parent) }
      }
    } catch { }
  }
  $candidates += @(
    (Join-Path $env:ProgramFiles 'Waterfox'),
    ('C:\Program Files (x86)\Waterfox'),
    ('D:\Program Files\Waterfox'),
    (Join-Path $env:ProgramFiles 'Mozilla Firefox'),
    ('D:\Program Files\Mozilla Firefox')
  )
  foreach ($c in $candidates) {
    if (Test-BrowserDir $c) { return $c }
  }
  return $null
}

function Read-State([string]$file) {
  $state = @{}
  foreach ($line in Get-Content $file) {
    $kv = $line -split '=', 2
    if ($kv.Count -eq 2) { $state[$kv[0]] = $kv[1] }
  }
  return $state
}

if (-not (Test-BrowserDir $AppDir)) {
  $AppDir = Find-BrowserDir
}
if (-not (Test-BrowserDir $AppDir)) {
  throw "Browser install directory not found. Pass it explicitly, e.g. -AppDir 'C:\Program Files\Waterfox'."
}

$cfgFile  = Join-Path $AppDir 'config.js'
$prefDir  = Join-Path $AppDir 'defaults\pref'
$prefFile = Join-Path $prefDir 'autoconfig.js'

Write-Host "Target install dir: $AppDir"

if ($WhatIfOnly) {
  Write-Host "Would write: $cfgFile"
  Write-Host "Would write: $prefFile"
  Write-Host "Rollback requested: $Rollback"
  exit 0
}

if ($Rollback) {
  $stateFile = Get-ChildItem -Path $src -Directory -Filter 'backup-*' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'state.txt' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

  if (-not $stateFile) {
    Write-Host "No backup found - removing the two files this patch adds."
    Remove-Item $cfgFile  -Force -ErrorAction SilentlyContinue
    Remove-Item $prefFile -Force -ErrorAction SilentlyContinue
  } else {
    $backupDir = Split-Path $stateFile -Parent
    $state = Read-State $stateFile
    Write-Host "Restoring state recorded in: $backupDir"
    if ($state['hadConfig'] -eq 'True' -and (Test-Path (Join-Path $backupDir 'config.js'))) {
      Copy-Item (Join-Path $backupDir 'config.js') $cfgFile -Force
      Write-Host "  restored previous config.js"
    } else {
      Remove-Item $cfgFile -Force -ErrorAction SilentlyContinue
      Write-Host "  removed config.js"
    }
    if ($state['hadAutoconfig'] -eq 'True' -and (Test-Path (Join-Path $backupDir 'autoconfig.js'))) {
      Copy-Item (Join-Path $backupDir 'autoconfig.js') $prefFile -Force
      Write-Host "  restored previous autoconfig.js"
    } else {
      Remove-Item $prefFile -Force -ErrorAction SilentlyContinue
      Write-Host "  removed autoconfig.js"
    }
  }
  Write-Host ""
  Write-Host "Now fully quit the browser and start it again."
  exit 0
}

$backup = Join-Path $src ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$hadConfig = Test-Path $cfgFile
$hadAutoconfig = Test-Path $prefFile
if ($hadConfig)     { Copy-Item $cfgFile  (Join-Path $backup 'config.js')     -Force }
if ($hadAutoconfig) { Copy-Item $prefFile (Join-Path $backup 'autoconfig.js') -Force }
Set-Content -Path (Join-Path $backup 'state.txt') -Value @(
  "when=$(Get-Date -Format o)",
  "appDir=$AppDir",
  "hadConfig=$hadConfig",
  "hadAutoconfig=$hadAutoconfig"
)

New-Item -ItemType Directory -Force -Path $prefDir | Out-Null
Copy-Item (Join-Path $src 'config.js')     $cfgFile  -Force
Copy-Item (Join-Path $src 'autoconfig.js') $prefFile -Force

Write-Host "Installed:"
Write-Host "  $cfgFile"
Write-Host "  $prefFile"
Write-Host "Backup of the previous state: $backup"
Write-Host ""
Write-Host "Now FULLY quit the browser (check Task Manager for a leftover waterfox.exe / firefox.exe)"
Write-Host "and start it again. Then: pin a tab, press Ctrl+W -> it should grey out and stay pinned."
Write-Host "Undo later with: .\install.ps1 -Rollback"
