Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$env:CODEWALK_INSTALLER_SOURCE_ONLY = "1"
. (Join-Path $repoRoot "install.ps1")

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -ne $Expected) {
    throw "Assertion failed ($Label): expected '$Expected', got '$Actual'"
  }
}

function Assert-Throws([scriptblock]$Block, [string]$Pattern, [string]$Label) {
  try {
    & $Block | Out-Null
  } catch {
    if ($_.Exception.Message -match $Pattern) {
      return
    }
    throw "Assertion failed ($Label): exception '$($_.Exception.Message)' did not match '$Pattern'"
  }
  throw "Assertion failed ($Label): expected exception matching '$Pattern'"
}

function New-FakeRelease([string]$Tag, [bool]$Draft = $false, [bool]$Prerelease = $false) {
  return [PSCustomObject]@{
    tag_name   = $Tag
    draft      = $Draft
    prerelease = $Prerelease
    assets     = @(
      [PSCustomObject]@{
        name                 = "codewalk-windows-x64.zip"
        browser_download_url = "https://github.com/verseles/codewalk/releases/download/$Tag/codewalk-windows-x64.zip"
      }
    )
  }
}

# 1. Channel tag major validation
Assert-Equal (Get-ChannelTagMajor "v2.0.0" "stable") "2" "stable v2.0.0"
Assert-Equal (Get-ChannelTagMajor "v1.265.1" "v1") "1" "v1 v1.265.1"
Assert-Equal (Get-ChannelTagMajor "v2.0.0" "v1") $null "v1 refuses v2"
Assert-Equal (Get-ChannelTagMajor "v2.0.0-beta.31" "beta") "2" "beta accepts beta"
Assert-Equal (Get-ChannelTagMajor "v2.0.0" "beta") "2" "beta accepts final v2"

# 2. Selection and graduation
$releases = @(
  (New-FakeRelease "v1.265.1"),
  (New-FakeRelease "v2.0.0-beta.9" $false $true),
  (New-FakeRelease "v2.0.0-beta.31" $false $true),
  (New-FakeRelease "v2.0.0-beta.32" $true $true),
  (New-FakeRelease "v1.266.0-native.1" $false $true),
  (New-FakeRelease "v2.0.0")
)

$v1Pick = Select-ReleaseForChannel -Releases $releases -Channel "v1"
Assert-Equal $v1Pick.tag_name "v1.265.1" "v1 picks highest v1"

$betaGraduate = Select-ReleaseForChannel -Releases $releases -Channel "beta"
Assert-Equal $betaGraduate.tag_name "v2.0.0" "beta graduates to v2.0.0"

$betasOnly = @(
  (New-FakeRelease "v1.265.1"),
  (New-FakeRelease "v2.0.0-beta.9" $false $true),
  (New-FakeRelease "v2.0.0-beta.31" $false $true)
)
$betaPick = Select-ReleaseForChannel -Releases $betasOnly -Channel "beta"
Assert-Equal $betaPick.tag_name "v2.0.0-beta.31" "beta picks highest beta when no final v2"

# 3. Major policy consent gate
$v1State = [PSCustomObject]@{ InstalledMajor = "1"; InstalledVersion = "v1.265.1" }
$v2Target = [PSCustomObject]@{ Tag = "v2.0.0"; TargetMajor = "2" }
Assert-Throws { Assert-MajorPolicy -State $v1State -Target $v2Target -Migration "none" } "CODEWALK_MIGRATION='accept-v2'" "refuse v1->v2 without consent"
Assert-MajorPolicy -State $v1State -Target $v2Target -Migration "accept-v2"

$v2State = [PSCustomObject]@{ InstalledMajor = "2"; InstalledVersion = "v2.0.0" }
$v1Target = [PSCustomObject]@{ Tag = "v1.265.1"; TargetMajor = "1" }
Assert-Throws { Assert-MajorPolicy -State $v2State -Target $v1Target -Migration "accept-v2" } "cannot replace" "refuse v2->v1 downgrade"

# 4. Empty page ($null in PowerShell 5.1) after a full page terminates pagination cleanly
$ReleasePageSize = 2
function Invoke-GitHubReleaseApi([string]$Path) {
  if ($Path -eq "releases?per_page=2&page=1") {
    return @(
      (New-FakeRelease "v2.0.0-beta.31" $false $true),
      (New-FakeRelease "v2.0.0")
    )
  }
  if ($Path -eq "releases?per_page=2&page=2") {
    return $null
  }
  throw "Unexpected API path: $Path"
}
$req = [PSCustomObject]@{ Contract = ""; RequestedChannel = "beta"; RequestedVersion = ""; Migration = "none" }
$st = [PSCustomObject]@{ InstalledVersion = "v2.0.0-beta.31"; ExistingInstall = $true; InstalledMajor = "2"; Channel = "beta" }
$resolved = Resolve-TargetRelease -Request $req -State $st
Assert-Equal $resolved.Tag "v2.0.0" "null empty page still resolves v2.0.0"
Assert-Equal $resolved.Channel "stable" "null empty page graduates beta channel to stable"

Write-Host "install.ps1 tests passed."
