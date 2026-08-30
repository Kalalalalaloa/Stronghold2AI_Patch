param(
    [string]$GamePath = "F:\SteamLibrary\steamapps\common\Stronghold 2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("Balanced", "Hard", "Brutal", "Overlord")]
    [string]$Profile = "Hard",
    [string]$RulesProfile = "",
    [switch]$PatchGameRules
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RulesProfile)) {
    $RulesProfile = $Profile
}
$validProfiles = @("Balanced", "Hard", "Brutal", "Overlord")
if ($validProfiles -notcontains $RulesProfile) {
    throw "Unknown rules profile '$RulesProfile'. Expected one of: $($validProfiles -join ', ')."
}

$profileKey = $Profile.ToLowerInvariant()
$rulesProfileKey = $RulesProfile.ToLowerInvariant()
$profileCastles = Join-Path $ProjectRoot "modded\profiles\$profileKey\castles"
$legacyCastles = Join-Path $ProjectRoot "modded\castles"
$moddedCastles = $profileCastles
$rulesPath = Join-Path $ProjectRoot "modded\rules\$rulesProfileKey\gameRules.dat"
$gameRulesPath = Join-Path $GamePath "gameRules.dat"
if (-not (Test-Path -LiteralPath $moddedCastles)) {
    $builder = Join-Path $ProjectRoot "tools\Build-Stronghold2AIProfiles.ps1"
    if (Test-Path -LiteralPath $builder) {
        Write-Host "Profile '$Profile' is missing. Generating profiles from local game files..."
        & $builder -GamePath $GamePath -ProjectRoot $ProjectRoot
    }
}

if ($PatchGameRules -and (-not (Test-Path -LiteralPath $rulesPath))) {
    $rulesBuilder = Join-Path $ProjectRoot "tools\Build-Stronghold2GameRulesPatch.ps1"
    if (Test-Path -LiteralPath $rulesBuilder) {
        Write-Host "Experimental gameRules.dat army profile '$RulesProfile' is missing. Generating rules from local game files..."
        & $rulesBuilder -GamePath $GamePath -ProjectRoot $ProjectRoot
    }
}

if (-not (Test-Path -LiteralPath $moddedCastles)) {
    if ($profileKey -eq "hard" -and (Test-Path -LiteralPath $legacyCastles)) {
        $moddedCastles = $legacyCastles
    }
}

$gameCastles = Join-Path $GamePath "castles"
$backupRoot = Join-Path $ProjectRoot "backups"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$backupDir = Join-Path $backupRoot $timestamp
$suffix = 1
while (Test-Path -LiteralPath $backupDir) {
    $backupDir = Join-Path $backupRoot ("{0}-{1}" -f $timestamp, $suffix)
    $suffix++
}
$backupCastles = Join-Path $backupDir "castles"

if (-not (Test-Path -LiteralPath $moddedCastles)) {
    throw "Missing modded castles directory: $moddedCastles"
}

if (-not (Test-Path -LiteralPath $gameCastles)) {
    throw "Missing Stronghold 2 castles directory: $gameCastles"
}

if ($PatchGameRules) {
    if (-not (Test-Path -LiteralPath $rulesPath)) {
        throw "Missing generated gameRules.dat profile: $rulesPath"
    }
    if (-not (Test-Path -LiteralPath $gameRulesPath)) {
        throw "Missing Stronghold 2 gameRules.dat: $gameRulesPath"
    }
}

$modFiles = Get-ChildItem -LiteralPath $moddedCastles -Filter "*.aic" -File
$alreadyInstalled = $true
foreach ($file in $modFiles) {
    $target = Join-Path $gameCastles $file.Name
    if (-not (Test-Path -LiteralPath $target)) {
        $alreadyInstalled = $false
        break
    }

    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        $alreadyInstalled = $false
        break
    }
}

$rulesAlreadyInstalled = $true
if ($PatchGameRules) {
    $rulesAlreadyInstalled = $false
    if ((Test-Path -LiteralPath $rulesPath) -and (Test-Path -LiteralPath $gameRulesPath)) {
        $sourceRulesHash = (Get-FileHash -LiteralPath $rulesPath -Algorithm SHA256).Hash
        $targetRulesHash = (Get-FileHash -LiteralPath $gameRulesPath -Algorithm SHA256).Hash
        $rulesAlreadyInstalled = ($sourceRulesHash -eq $targetRulesHash)
    }
}

if ($alreadyInstalled -and $rulesAlreadyInstalled) {
    Write-Host "Stronghold 2 AI Overhaul castle profile '$Profile' and army profile '$RulesProfile' are already installed. No files changed and no backup created."
    return
}

New-Item -ItemType Directory -Force -Path $backupCastles | Out-Null

foreach ($file in $modFiles) {
    $target = Join-Path $gameCastles $file.Name
    if (Test-Path -LiteralPath $target) {
        Copy-Item -LiteralPath $target -Destination $backupCastles -Force
    }
}

$moddedRulesInfo = $null
if ($PatchGameRules) {
    Copy-Item -LiteralPath $gameRulesPath -Destination (Join-Path $backupDir "gameRules.dat") -Force
    $moddedRulesInfo = $rulesPath
}

$installInfo = [ordered]@{
    installedAt = (Get-Date).ToString("s")
    gamePath = $GamePath
    profile = $Profile
    armyProfile = $RulesProfile
    moddedCastles = $moddedCastles
    patchGameRules = [bool]$PatchGameRules
    moddedRules = $moddedRulesInfo
    fileCount = $modFiles.Count
}
$installInfo | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backupDir "install-info.json") -Encoding UTF8

foreach ($file in $modFiles) {
    Copy-Item -LiteralPath $file.FullName -Destination $gameCastles -Force
}

if ($PatchGameRules) {
    Copy-Item -LiteralPath $rulesPath -Destination $gameRulesPath -Force
}

Write-Host "Installed Stronghold 2 AI Overhaul profile '$Profile'."
Write-Host "Backup created at: $backupDir"
if ($PatchGameRules) {
    Write-Host "gameRules.dat was modified with the experimental '$RulesProfile' army profile."
} else {
    Write-Host "gameRules.dat was not modified."
}
