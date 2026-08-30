param(
    [string]$GamePath = "F:\SteamLibrary\steamapps\common\Stronghold 2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$BackupPath
)

$ErrorActionPreference = "Stop"

$gameCastles = Join-Path $GamePath "castles"
if (-not (Test-Path -LiteralPath $gameCastles)) {
    throw "Missing Stronghold 2 castles directory: $gameCastles"
}

$backupRoot = Join-Path $ProjectRoot "backups"
if (-not $BackupPath) {
    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory |
        Sort-Object Name |
        Select-Object -First 1
    if (-not $latest) {
        throw "No backup found under $backupRoot"
    }
    $BackupPath = $latest.FullName
}

$backupCastles = Join-Path $BackupPath "castles"
if (-not (Test-Path -LiteralPath $backupCastles)) {
    throw "Missing backup castles directory: $backupCastles"
}

$backupFiles = Get-ChildItem -LiteralPath $backupCastles -Filter "*.aic" -File
foreach ($file in $backupFiles) {
    Copy-Item -LiteralPath $file.FullName -Destination $gameCastles -Force
}

$gameRulesPath = Join-Path $GamePath "gameRules.dat"
$backupRules = Join-Path $BackupPath "gameRules.dat"
$rulesRestoreSource = $null
if (Test-Path -LiteralPath $backupRules) {
    $rulesRestoreSource = $backupRules
} elseif (Test-Path -LiteralPath $backupRoot) {
    $rulesBackup = Get-ChildItem -LiteralPath $backupRoot -Directory |
        Sort-Object Name |
        ForEach-Object {
            $candidate = Join-Path $_.FullName "gameRules.dat"
            if (Test-Path -LiteralPath $candidate) {
                Get-Item -LiteralPath $candidate
            }
        } |
        Select-Object -First 1
    if ($rulesBackup) {
        $rulesRestoreSource = $rulesBackup.FullName
    }
}

if (-not $rulesRestoreSource) {
    $sourceRules = Join-Path $ProjectRoot "source\vanilla\gameRules.dat"
    if (Test-Path -LiteralPath $sourceRules) {
        $rulesRestoreSource = $sourceRules
    }
}

if ($rulesRestoreSource) {
    Copy-Item -LiteralPath $rulesRestoreSource -Destination $gameRulesPath -Force
    Write-Host "Restored gameRules.dat from: $rulesRestoreSource"
} else {
    Write-Host "No gameRules.dat backup found. gameRules.dat was not restored."
}

Write-Host "Restored $($backupFiles.Count) AIC files from: $BackupPath"
