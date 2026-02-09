Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# CodeWalk installer (Windows)
# Usage: irm https://raw.githubusercontent.com/<owner>/<repo>/main/install.ps1 | iex

$Repo = if ($env:CODEWALK_REPO) { $env:CODEWALK_REPO } else { "helio/codewalk" }
$InstallDir = Join-Path $env:LOCALAPPDATA "CodeWalk"
$BinaryPath = Join-Path $InstallDir "codewalk.exe"

function Info([string]$Message) {
  Write-Host ":: $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  throw $Message
}

function Get-ArchTag {
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  switch ($arch) {
    "X64" { return "x64" }
    "Arm64" { return "arm64" }
    default { Fail "Unsupported architecture: $arch" }
  }
}

function Add-ToUserPath([string]$PathEntry) {
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($current) {
    $parts = $current.Split(";") | Where-Object { $_ -and $_.Trim() -ne "" }
  }
  if ($parts -contains $PathEntry) {
    return
  }
  $updated = if ($parts.Count -eq 0) { $PathEntry } else { ($parts + $PathEntry) -join ";" }
  [Environment]::SetEnvironmentVariable("Path", $updated, "User")
}

$archTag = Get-ArchTag
$asset = "codewalk-windows-$archTag.zip"

Info "Fetching latest release from $Repo"
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "codewalk-install" }
if (-not $release.tag_name) {
  Fail "Could not determine latest release tag."
}

$match = $release.assets | Where-Object { $_.name -eq $asset } | Select-Object -First 1
if (-not $match) {
  $available = ($release.assets | ForEach-Object { $_.name }) -join ", "
  Fail "Asset '$asset' not found. Available: $available"
}

$tmpRoot = Join-Path $env:TEMP ("codewalk-install-" + [Guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tmpRoot $asset

try {
  New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

  Info "Downloading $asset"
  Invoke-WebRequest -Uri $match.browser_download_url -OutFile $zipPath

  if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force -Path $InstallDir
  }
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

  Info "Extracting package"
  Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force

  if (-not (Test-Path $BinaryPath)) {
    $nested = Join-Path $InstallDir "bin\codewalk.exe"
    if (Test-Path $nested) {
      Copy-Item -Force $nested $BinaryPath
    } else {
      Fail "codewalk.exe not found in archive."
    }
  }

  Add-ToUserPath -PathEntry $InstallDir

  Write-Host ""
  Write-Host "CodeWalk installed successfully at $InstallDir" -ForegroundColor Green
  Write-Host "Open a new terminal and run: codewalk"
}
finally {
  if (Test-Path $tmpRoot) {
    Remove-Item -Recurse -Force -Path $tmpRoot -ErrorAction SilentlyContinue
  }
}
