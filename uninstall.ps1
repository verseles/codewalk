Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# CodeWalk uninstaller (Windows)
# Usage: irm https://raw.githubusercontent.com/<owner>/<repo>/main/uninstall.ps1 | iex

$InstallDir = Join-Path $env:LOCALAPPDATA "CodeWalk"
$StartMenuShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\CodeWalk.lnk"

function Info([string]$Message) {
  Write-Host ":: $Message" -ForegroundColor Cyan
}

function Warn([string]$Message) {
  Write-Host ":: $Message" -ForegroundColor Yellow
}

function Remove-FromUserPath([string]$PathEntry) {
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $current) {
    return
  }

  $normalizedTarget = $PathEntry.Trim().TrimEnd('\').ToLowerInvariant()
  $parts = $current.Split(";") | Where-Object {
    $candidate = $_.Trim()
    if (-not $candidate) {
      return $false
    }
    $candidate.TrimEnd('\').ToLowerInvariant() -ne $normalizedTarget
  }

  $updated = $parts -join ";"
  [Environment]::SetEnvironmentVariable("Path", $updated, "User")
}

$removedAny = $false

if (Test-Path $StartMenuShortcutPath) {
  Remove-Item -Force -Path $StartMenuShortcutPath
  Info "Removed Start Menu shortcut: $StartMenuShortcutPath"
  $removedAny = $true
}

if (Test-Path $InstallDir) {
  Remove-Item -Recurse -Force -Path $InstallDir
  Info "Removed install directory: $InstallDir"
  $removedAny = $true
}

Remove-FromUserPath -PathEntry $InstallDir
Info "Removed CodeWalk install path from user PATH (if present)."

if (-not $removedAny) {
  Warn "No CodeWalk installation artifacts found."
}

Write-Host ""
Write-Host "CodeWalk uninstall finished." -ForegroundColor Green
