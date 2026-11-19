Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# CodeWalk installer (Windows)
# Usage: irm https://raw.githubusercontent.com/<owner>/<repo>/main/install.ps1 | iex
#
# Release selection environment variables:
#   CODEWALK_CHANNEL          stable | v1 | beta (default: saved choice, then stable)
#   CODEWALK_VERSION          exact release tag to install instead of the newest one
#   CODEWALK_MIGRATION        none | accept-v2: consent to move CodeWalk 1 to 2
#   CODEWALK_UPDATE_CONTRACT  1 for app handoff (requires channel, version, migration)

$Repo = if ($env:CODEWALK_REPO) { $env:CODEWALK_REPO } else { "verseles/codewalk" }
$InstallDir = Join-Path $env:LOCALAPPDATA "CodeWalk"
$BinaryPath = Join-Path $InstallDir "codewalk.exe"
$VersionFile = Join-Path $InstallDir ".installed-version"
$ChannelFile = Join-Path $InstallDir ".installed-channel"
$StartMenuShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\CodeWalk.lnk"
$StageRoot = Join-Path $env:LOCALAPPDATA "CodeWalk.update"
$StagePayloadDir = Join-Path $StageRoot "payload"
$PendingVersionFile = Join-Path $StageRoot ".pending-version"
$PendingChannelFile = Join-Path $StageRoot ".pending-channel"
$InstallMode = if ($env:CODEWALK_INSTALL_MODE) { $env:CODEWALK_INSTALL_MODE.ToLowerInvariant() } else { "install" }
$ReleasePageSize = 100
$ReleasePageLimit = 10

function Info([string]$Message) {
  Write-Host ":: $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  throw $Message
}

function Warn([string]$Message) {
  Write-Host ":: $Message" -ForegroundColor Yellow
}

function Get-WindowsArchitecture {
  $runtimeInfoType = [Type]::GetType("System.Runtime.InteropServices.RuntimeInformation", $false)
  if ($runtimeInfoType) {
    $osArchitectureProperty = $runtimeInfoType.GetProperty("OSArchitecture", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
    if ($osArchitectureProperty) {
      try {
        $osArchitecture = $osArchitectureProperty.GetValue($null, $null)
        if ($osArchitecture) {
          return $osArchitecture.ToString().ToUpperInvariant()
        }
      }
      catch {
        # Ignore and use compatibility fallbacks below.
      }
    }
  }

  $processArchitecture = ""
  $wow64Architecture = ""
  if ($env:PROCESSOR_ARCHITECTURE) {
    $processArchitecture = $env:PROCESSOR_ARCHITECTURE.ToUpperInvariant()
  }
  if ($env:PROCESSOR_ARCHITEW6432) {
    $wow64Architecture = $env:PROCESSOR_ARCHITEW6432.ToUpperInvariant()
  }

  if ($processArchitecture -eq "ARM64" -or $wow64Architecture -eq "ARM64") {
    return "ARM64"
  }

  if ([Environment]::Is64BitOperatingSystem) {
    return "X64"
  }

  return "X86"
}

function Get-WindowsAssetCandidates {
  $arch = Get-WindowsArchitecture
  switch ($arch) {
    "X64" { return @("codewalk-windows-x64.zip") }
    "ARM64" {
      # Same-release x64 emulation only; never falls back to another release.
      return @("codewalk-windows-arm64.zip", "codewalk-windows-x64.zip")
    }
    default { Fail "Unsupported architecture: $arch" }
  }
}

function Get-PropertyValue($Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $null }
  return $prop.Value
}

function Get-ChannelTagMajor([string]$Tag, [string]$Channel) {
  $num = "(?:0|[1-9][0-9]*)"
  if ($Channel -eq "beta") {
    if ($Tag -match "^v2\.0\.0-beta\.$num$") { return "2" }
    if ($Tag -match "^v?2\.$num\.$num$") { return "2" }
    return $null
  }
  if ($Tag -notmatch "^v?($num)\.$num\.$num$") {
    return $null
  }
  $major = $Matches[1]
  if ($Channel -eq "v1" -and $major -ne "1") {
    return $null
  }
  return $major
}

function Compare-VersionKey([string[]]$A, [string[]]$B) {
  for ($i = 0; $i -lt 5; $i++) {
    $x = "n" + $A[$i]
    $y = "n" + $B[$i]
    if ($x.Length -ne $y.Length) {
      return ($x.Length -gt $y.Length)
    }
    if ($x -ne $y) {
      return ([string]::CompareOrdinal($x, $y) -gt 0)
    }
  }
  return $false
}

function Get-VersionKeyForChannel($Release, [string]$Channel) {
  $tag = Get-PropertyValue $Release "tag_name"
  $draft = Get-PropertyValue $Release "draft"
  $prerelease = Get-PropertyValue $Release "prerelease"
  if ($tag -isnot [string] -or $draft -isnot [bool] -or $prerelease -isnot [bool]) {
    Fail "Malformed release metadata from GitHub."
  }
  if ($draft) { return $null }
  $num = "(?:0|[1-9][0-9]*)"
  if ($Channel -eq "beta") {
    if ($prerelease -and $tag -match "^v2\.0\.0-beta\.($num)$") {
      return @("2", "0", "0", "0", $Matches[1])
    }
    if ((-not $prerelease) -and $tag -match "^v?(2)\.($num)\.($num)$") {
      return @($Matches[1], $Matches[2], $Matches[3], "1", "0")
    }
    return $null
  }
  if ($prerelease) { return $null }
  if ($tag -notmatch "^v?($num)\.($num)\.($num)$") {
    return $null
  }
  if ($Channel -eq "v1" -and $Matches[1] -ne "1") {
    return $null
  }
  return @($Matches[1], $Matches[2], $Matches[3], "1", "0")
}

function Select-ReleaseForChannel([object[]]$Releases, [string]$Channel) {
  $bestRelease = $null
  $bestKey = $null
  foreach ($rel in $Releases) {
    $key = Get-VersionKeyForChannel -Release $rel -Channel $Channel
    if ($null -eq $key) { continue }
    if ($null -eq $bestKey -or (Compare-VersionKey -A $key -B $bestKey)) {
      $bestKey = $key
      $bestRelease = $rel
    }
  }
  return $bestRelease
}

function Read-InstallRequest {
  $contract = if ($env:CODEWALK_UPDATE_CONTRACT) { $env:CODEWALK_UPDATE_CONTRACT.Trim() } else { "" }
  $requestedChannel = if ($env:CODEWALK_CHANNEL) { $env:CODEWALK_CHANNEL.Trim().ToLowerInvariant() } else { "" }
  $requestedVersion = if ($env:CODEWALK_VERSION) { $env:CODEWALK_VERSION.Trim() } else { "" }
  $migration = if ($env:CODEWALK_MIGRATION) { $env:CODEWALK_MIGRATION.Trim().ToLowerInvariant() } else { "" }

  if ($contract -ne "") {
    if ($contract -ne "1") {
      Fail "Unsupported CODEWALK_UPDATE_CONTRACT: $contract"
    }
    if (-not $requestedChannel -or -not $requestedVersion -or -not $migration) {
      Fail "CODEWALK_UPDATE_CONTRACT=1 requires CODEWALK_CHANNEL, CODEWALK_VERSION and CODEWALK_MIGRATION"
    }
  }

  if ($requestedChannel -and @("stable", "v1", "beta") -notcontains $requestedChannel) {
    Fail "Unsupported CODEWALK_CHANNEL: $requestedChannel (use stable, v1 or beta)"
  }

  if (-not $migration) {
    $migration = "none"
  }
  elseif (@("none", "accept-v2") -notcontains $migration) {
    Fail "Unsupported CODEWALK_MIGRATION: $migration (use none or accept-v2)"
  }

  if ($requestedVersion -and $requestedVersion -notmatch "^[A-Za-z0-9._+-]+$") {
    Fail "Invalid CODEWALK_VERSION: $requestedVersion"
  }

  return [PSCustomObject]@{
    Contract         = $contract
    RequestedChannel = $requestedChannel
    RequestedVersion = $requestedVersion
    Migration        = $migration
  }
}

function Get-SavedChannel {
  if (-not (Test-Path $ChannelFile)) {
    return ""
  }
  try {
    $lines = @(Get-Content -Path $ChannelFile -ErrorAction Stop)
    if ($lines.Count -eq 0) { return "" }
    return $lines[0].Trim().ToLowerInvariant()
  }
  catch {
    return ""
  }
}

function Read-InstallState($Request) {
  $installedVersion = Get-InstalledVersion
  $existingInstall = [bool]($installedVersion -or (Test-Path $InstallDir) -or (Test-Path $BinaryPath))
  $installedMajor = $null
  if ($existingInstall) {
    if ($installedVersion -match "^v?([0-9]+)\.") {
      $installedMajor = $Matches[1]
    }
    else {
      Warn "The installed CodeWalk version is unknown; treating it as CodeWalk 1"
      $installedMajor = "1"
    }
  }

  $savedChannel = Get-SavedChannel
  if ($savedChannel -and @("stable", "v1", "beta") -notcontains $savedChannel) {
    if (-not $Request.RequestedChannel) {
      Fail "Unreadable saved channel in $ChannelFile; set CODEWALK_CHANNEL to stable, v1 or beta"
    }
    $savedChannel = ""
  }

  $effectiveChannel = if ($Request.RequestedChannel) {
    $Request.RequestedChannel
  }
  elseif ($savedChannel) {
    $savedChannel
  }
  else {
    "stable"
  }

  return [PSCustomObject]@{
    InstalledVersion = $installedVersion
    ExistingInstall  = $existingInstall
    InstalledMajor   = $installedMajor
    Channel          = $effectiveChannel
  }
}

function Invoke-GitHubReleaseApi([string]$Path) {
  $uri = "https://api.github.com/repos/$Repo/$Path"
  try {
    return Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "codewalk-install"; "Accept" = "application/vnd.github+json" }
  }
  catch {
    Fail "Could not fetch release metadata from GitHub ($Path); check the network or the API rate limit."
  }
}

function Resolve-TargetRelease($Request, $State) {
  $channel = $State.Channel
  if ($Request.RequestedVersion) {
    $requested = $Request.RequestedVersion
    $release = Invoke-GitHubReleaseApi -Path "releases/tags/$requested"
    $tag = Get-PropertyValue $release "tag_name"
    $draft = Get-PropertyValue $release "draft"
    $prerelease = Get-PropertyValue $release "prerelease"
    if ($tag -isnot [string] -or $draft -isnot [bool] -or $prerelease -isnot [bool]) {
      Fail "Malformed release metadata for $requested"
    }
    if ($tag -ne $requested) {
      Fail "Release $requested was not found as an exact tag"
    }
    $expectedPrerelease = ($channel -eq "beta" -and $requested -match "^v2\.0\.0-beta\.")
    $targetMajor = Get-ChannelTagMajor -Tag $requested -Channel $channel
    if ($draft -or ($prerelease -ne $expectedPrerelease) -or $null -eq $targetMajor) {
      Fail "Release $requested is not a $channel release"
    }
    $resolvedChannel = if ($channel -eq "beta" -and (-not $expectedPrerelease)) { "stable" } else { $channel }
    return [PSCustomObject]@{
      Release     = $release
      Tag         = $tag
      TargetMajor = $targetMajor
      Channel     = $resolvedChannel
    }
  }

  if ($channel -eq "stable") {
    $release = Invoke-GitHubReleaseApi -Path "releases/latest"
    $selected = Select-ReleaseForChannel -Releases @($release) -Channel "stable"
    if ($null -eq $selected) {
      Fail "The latest release of $Repo is not a stable release"
    }
  }
  else {
    $allReleases = New-Object System.Collections.ArrayList
    $page = 1
    while ($true) {
      $batch = Invoke-GitHubReleaseApi -Path "releases?per_page=$ReleasePageSize&page=$page"
      if ($null -eq $batch) { break }
      $items = @($batch)
      if ($items.Count -eq 0) { break }
      foreach ($item in $items) {
        if ($null -ne $item) { [void]$allReleases.Add($item) }
      }
      if ($items.Count -lt $ReleasePageSize) { break }
      if ($page -ge $ReleasePageLimit) {
        Fail "More than $($ReleasePageSize * $ReleasePageLimit) releases; cannot prove the newest $channel release"
      }
      $page++
    }
    $selected = Select-ReleaseForChannel -Releases $allReleases.ToArray() -Channel $channel
    if ($null -eq $selected) {
      Fail "No $channel release of $Repo is available"
    }
  }

  $selectedTag = Get-PropertyValue $selected "tag_name"
  $targetMajor = Get-ChannelTagMajor -Tag $selectedTag -Channel $channel
  if ($null -eq $targetMajor) {
    Fail "Release $selectedTag is not a $channel release"
  }
  $resolvedChannel = if ($channel -eq "beta" -and $selectedTag -notmatch "^v2\.0\.0-beta\.") { "stable" } else { $channel }
  return [PSCustomObject]@{
    Release     = $selected
    Tag         = $selectedTag
    TargetMajor = $targetMajor
    Channel     = $resolvedChannel
  }
}

function Assert-MajorPolicy($State, $Target, [string]$Migration) {
  if ($null -eq $State.InstalledMajor) { return }
  if ($Target.TargetMajor -eq $State.InstalledMajor) { return }
  if ($State.InstalledMajor -eq "1" -and $Target.TargetMajor -eq "2") {
    if ($Migration -eq "accept-v2") { return }
    Fail ("CodeWalk $($Target.Tag) is CodeWalk 2, which works only with OpenCode 2 servers; " +
      "CodeWalk 1 servers stop working with it. Your installation was not changed. " +
      "To migrate, run again with `$env:CODEWALK_MIGRATION='accept-v2'. " +
      "To stay on CodeWalk 1, run again with `$env:CODEWALK_CHANNEL='v1'.")
  }
  Fail "CodeWalk $($Target.Tag) cannot replace the installed CodeWalk $($State.InstalledMajor) ($($State.InstalledVersion)); your installation was not changed."
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

function New-StartMenuShortcut([string]$TargetExePath) {
  $shortcutDir = Split-Path -Parent $StartMenuShortcutPath
  New-Item -ItemType Directory -Force -Path $shortcutDir | Out-Null

  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($StartMenuShortcutPath)
  $shortcut.TargetPath = $TargetExePath
  $shortcut.WorkingDirectory = Split-Path -Parent $TargetExePath
  $shortcut.IconLocation = "$TargetExePath,0"
  $shortcut.Description = "CodeWalk"
  $shortcut.Save()
}

function Get-InstalledVersion {
  if (-not (Test-Path $VersionFile)) {
    return ""
  }

  try {
    return (Get-Content -Path $VersionFile -Raw).Trim()
  }
  catch {
    return ""
  }
}

function Get-PendingVersion {
  if (-not (Test-Path $PendingVersionFile)) {
    return ""
  }

  try {
    return (Get-Content -Path $PendingVersionFile -Raw).Trim()
  }
  catch {
    return ""
  }
}

function Get-PendingChannel {
  if (-not (Test-Path $PendingChannelFile)) {
    return "stable"
  }

  try {
    $value = (Get-Content -Path $PendingChannelFile -Raw).Trim().ToLowerInvariant()
    if (@("stable", "v1", "beta") -contains $value) {
      return $value
    }
    return "stable"
  }
  catch {
    return "stable"
  }
}

function Test-CodeWalkRunning {
  $proc = Get-Process -Name 'codewalk' -ErrorAction SilentlyContinue
  return $null -ne $proc
}

function Stop-CodeWalkProcess {
  $procs = @()
  try {
    $found = Get-Process -Name 'codewalk' -ErrorAction Stop
    if ($found -is [array]) { $procs = $found } else { $procs = @($found) }
  } catch { return }
  if ($procs.Count -eq 0) { return }

  Info "Stopping $($procs.Count) running CodeWalk process(es) before applying update"
  foreach ($proc in $procs) {
    try {
      Stop-Process -Id $proc.Id -Force -ErrorAction Stop
    } catch {
      Warn "Could not stop CodeWalk process (PID $($proc.Id)): $($_.Exception.Message)"
    }
  }
  foreach ($proc in $procs) {
    $proc | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
  }
  Start-Sleep -Milliseconds 500

  $survivors = Get-Process -Name 'codewalk' -ErrorAction SilentlyContinue
  if ($survivors) {
    Warn "CodeWalk process(es) still running after first stop attempt; retrying"
    foreach ($proc in @($survivors)) {
      try {
        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
      } catch {
        Warn "Could not stop CodeWalk process (PID $($proc.Id)): $($_.Exception.Message)"
      }
    }
    Start-Sleep -Seconds 2
  }
}

function Get-ParentProcessId {
  try {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $PID" -ErrorAction Stop
    if ($proc.ParentProcessId) { return [int]$proc.ParentProcessId }
  } catch {
    try {
      $proc = Get-WmiObject Win32_Process -Filter "ProcessId = $PID" -ErrorAction Stop
      if ($proc.ParentProcessId) { return [int]$proc.ParentProcessId }
    } catch {}
  }

  return 0
}

function Get-CodeWalkParentProcessId {
  $parentPid = Get-ParentProcessId
  if ($parentPid -le 0) { return 0 }

  try {
    $parent = Get-Process -Id $parentPid -ErrorAction Stop
    if ($parent.ProcessName -eq 'codewalk') {
      return $parentPid
    }
  } catch {}

  return 0
}

function Wait-ForParentExit([int]$ProcessId) {
  if ($ProcessId -le 0) { return }

  try {
    Info "Waiting for CodeWalk process $ProcessId to exit before applying update"
    Wait-Process -Id $ProcessId -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
  } catch {}
}

function Complete-InstallIntegration([string]$Version, [string]$Channel = "stable") {
  Get-ChildItem -Path $InstallDir -Recurse | Unblock-File -ErrorAction SilentlyContinue

  if (-not (Test-Path $BinaryPath)) {
    $nested = Join-Path $InstallDir "bin\codewalk.exe"
    if (Test-Path $nested) {
      Copy-Item -Force $nested $BinaryPath
    } else {
      Fail "codewalk.exe not found in staged package."
    }
  }

  Add-ToUserPath -PathEntry $InstallDir

  try {
    New-StartMenuShortcut -TargetExePath $BinaryPath
    Info "Start Menu shortcut created at $StartMenuShortcutPath"
  }
  catch {
    Warn "Could not create Start Menu shortcut: $($_.Exception.Message)"
  }

  Set-Content -Path $VersionFile -Value $Version -NoNewline
  Set-Content -Path $ChannelFile -Value $Channel -NoNewline
}

function Save-StagedPackage([string]$ZipPath, [string]$Version, [string]$Channel = "stable") {
  if (Test-Path $StageRoot) {
    Remove-Item -Recurse -Force -Path $StageRoot -ErrorAction Stop
  }
  New-Item -ItemType Directory -Force -Path $StagePayloadDir | Out-Null

  Info "Extracting package to staging directory"
  Expand-Archive -Path $ZipPath -DestinationPath $StagePayloadDir -Force

  $stagedBinary = Join-Path $StagePayloadDir "codewalk.exe"
  $nestedBinary = Join-Path $StagePayloadDir "bin\codewalk.exe"
  if (-not (Test-Path $stagedBinary) -and -not (Test-Path $nestedBinary)) {
    Fail "codewalk.exe not found in archive."
  }

  Set-Content -Path $PendingVersionFile -Value $Version -NoNewline
  Set-Content -Path $PendingChannelFile -Value $Channel -NoNewline
}

function Apply-StagedInstall {
  $pendingVersion = Get-PendingVersion
  if (-not $pendingVersion) {
    Fail "No staged CodeWalk update found."
  }
  if (-not (Test-Path $StagePayloadDir)) {
    Fail "Staged CodeWalk payload not found."
  }
  $pendingChannel = Get-PendingChannel

  Stop-CodeWalkProcess

  if (Test-Path $InstallDir) {
    $removed = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
      try {
        Remove-Item -Recurse -Force -Path $InstallDir -ErrorAction Stop
        $removed = $true
        break
      } catch {
        if ($attempt -lt 3) {
          Warn "Install directory is still locked; retrying removal ($attempt/3)"
          Start-Sleep -Seconds 2
        }
      }
    }
    if (-not $removed) {
      Fail "Cannot remove $InstallDir after closing CodeWalk. Staged update remains at $StageRoot."
    }
  }
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

  Get-ChildItem -Path $StagePayloadDir -Force | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $InstallDir -Recurse -Force
  }

  Complete-InstallIntegration -Version $pendingVersion -Channel $pendingChannel
  Remove-Item -Recurse -Force -Path $StageRoot -ErrorAction SilentlyContinue
  Info "CodeWalk update applied at $InstallDir ($pendingVersion)"
}

function Start-ApplyHelper([int]$ParentPid, [bool]$Relaunch) {
  $repoValue = $Repo.Replace("'", "''")
  $relaunchValue = if ($Relaunch) { "1" } else { "0" }
  $command = "`$env:CODEWALK_REPO='$repoValue'; `$env:CODEWALK_INSTALL_MODE='apply'; `$env:CODEWALK_PARENT_PID='$ParentPid'; `$env:CODEWALK_RELAUNCH='$relaunchValue'; irm install.cat/$repoValue | iex"
  $encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
  Start-Process -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encoded) -WindowStyle Hidden
}

function Invoke-CodeWalkInstallMain {
  if ($InstallMode -eq "apply") {
    $parentPid = 0
    if ($env:CODEWALK_PARENT_PID) {
      try { $parentPid = [int]$env:CODEWALK_PARENT_PID } catch { $parentPid = 0 }
    }
    try {
      Wait-ForParentExit -ProcessId $parentPid
      Apply-StagedInstall
      if ($env:CODEWALK_RELAUNCH -eq "1" -and (Test-Path $BinaryPath)) {
        Start-Process -FilePath $BinaryPath -WorkingDirectory $InstallDir
      }
    } catch {
      Warn "CodeWalk update apply failed: $($_.Exception.Message)"
      $canRelaunch = (Test-Path $BinaryPath) -and (Test-Path $VersionFile)
      if ($env:CODEWALK_RELAUNCH -eq "1" -and $canRelaunch) {
        Start-Process -FilePath $BinaryPath -WorkingDirectory $InstallDir
      } elseif ($env:CODEWALK_RELAUNCH -eq "1") {
        Warn "CodeWalk was not relaunched because the install directory is incomplete. Staged update remains at $StageRoot."
      }
      exit 1
    }
    exit 0
  }

  $assetCandidates = Get-WindowsAssetCandidates
  $request = Read-InstallRequest
  $state = Read-InstallState -Request $request

  Info "Resolving $($state.Channel) release from $Repo"
  $target = Resolve-TargetRelease -Request $request -State $state
  Assert-MajorPolicy -State $state -Target $target -Migration $request.Migration

  if ($state.InstalledVersion) {
    if ($state.InstalledVersion -eq $target.Tag) {
      Info "Reinstalling CodeWalk $($target.Tag) ($($target.Channel))"
    }
    else {
      Info "Updating CodeWalk from $($state.InstalledVersion) to $($target.Tag) ($($target.Channel))"
    }
  }
  elseif ($state.ExistingInstall) {
    Info "Existing installation detected. Installing $($target.Channel) release $($target.Tag)"
  }
  else {
    Info "Installing CodeWalk $($target.Tag) ($($target.Channel))"
  }

  $rawAssets = Get-PropertyValue $target.Release "assets"
  $releaseAssets = if ($null -eq $rawAssets) { @() } else { @($rawAssets) }
  $match = $null
  $asset = $null
  foreach ($candidate in $assetCandidates) {
    $found = $releaseAssets | Where-Object { (Get-PropertyValue $_ "name") -eq $candidate } | Select-Object -First 1
    if ($found) {
      $match = $found
      $asset = $candidate
      break
    }
  }

  if (-not $match) {
    $available = ($releaseAssets | ForEach-Object { Get-PropertyValue $_ "name" }) -join ", "
    $requested = $assetCandidates -join ", "
    Fail "None of the expected assets were found in $($target.Tag) ($requested). Available: $available"
  }

  $tmpRoot = Join-Path $env:TEMP ("codewalk-install-" + [Guid]::NewGuid().ToString("N"))
  $zipPath = Join-Path $tmpRoot $asset

  try {
    New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

    Info "Downloading $asset from $Repo ($($target.Tag))"
    Invoke-WebRequest -Uri (Get-PropertyValue $match "browser_download_url") -OutFile $zipPath

    Save-StagedPackage -ZipPath $zipPath -Version $target.Tag -Channel $target.Channel

    if ($InstallMode -eq "stage") {
      Write-Host ""
      Write-Host "CodeWalk update staged at $StageRoot ($($target.Tag))" -ForegroundColor Green
      Write-Host "Restart CodeWalk to apply the update."
      exit 0
    }

    if (Test-CodeWalkRunning) {
      $parentPid = Get-CodeWalkParentProcessId
      Start-ApplyHelper -ParentPid $parentPid -Relaunch $true
      Write-Host ""
      Write-Host "CodeWalk update staged at $StageRoot ($($target.Tag))" -ForegroundColor Green
      Write-Host "Restart CodeWalk to apply the update."
      exit 0
    }

    Apply-StagedInstall

    Write-Host ""
    Write-Host "CodeWalk installed to $InstallDir ($($target.Tag), $($target.Channel))" -ForegroundColor Green
    Write-Host "Open a new terminal and run: codewalk"
    Write-Host "Or launch CodeWalk from the Start Menu."
  }
  finally {
    if (Test-Path $tmpRoot) {
      Remove-Item -Recurse -Force -Path $tmpRoot -ErrorAction SilentlyContinue
    }
  }
}

if ($env:CODEWALK_INSTALLER_SOURCE_ONLY -ne "1") {
  Invoke-CodeWalkInstallMain
}
