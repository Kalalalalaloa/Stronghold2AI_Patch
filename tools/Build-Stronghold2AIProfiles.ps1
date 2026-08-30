param(
    [string]$GamePath = "F:\SteamLibrary\steamapps\common\Stronghold 2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$sourceCastles = Join-Path $GamePath "castles"
$profilesRoot = Join-Path $ProjectRoot "modded\profiles"
$legacyHardCastles = Join-Path $ProjectRoot "modded\castles"

if (-not (Test-Path -LiteralPath (Join-Path $GamePath "Stronghold2.exe"))) {
    throw "Missing Stronghold2.exe under game path: $GamePath"
}

if (-not (Test-Path -LiteralPath $sourceCastles)) {
    throw "Missing Stronghold 2 castles directory: $sourceCastles"
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-PatchTarget {
    param([string]$Name)
    $lower = $Name.ToLowerInvariant()
    return (-not $lower.StartsWith("aivchap")) -and (-not $lower.StartsWith("test"))
}

function Get-ScaledPriority {
    param(
        [int]$Priority,
        [string]$Profile
    )

    switch ($Profile) {
        "Balanced" {
            if ($Priority -le 1) { return $Priority }
            if ($Priority -le 10) { return [Math]::Max(2, [Math]::Round($Priority * 0.95)) }
            if ($Priority -le 40) { return [Math]::Max(3, [Math]::Round($Priority * 0.88)) }
            if ($Priority -le 100) { return [Math]::Max(15, [Math]::Round($Priority * 0.82)) }
            return [Math]::Max(45, [Math]::Round($Priority * 0.75))
        }
        "Hard" {
            if ($Priority -le 1) { return $Priority }
            if ($Priority -le 10) { return [Math]::Max(2, [Math]::Round($Priority * 0.85)) }
            if ($Priority -le 40) { return [Math]::Max(3, [Math]::Round($Priority * 0.72)) }
            if ($Priority -le 100) { return [Math]::Max(12, [Math]::Round($Priority * 0.65)) }
            return [Math]::Max(25, [Math]::Round($Priority * 0.55))
        }
        "Brutal" {
            if ($Priority -le 1) { return $Priority }
            if ($Priority -le 10) { return [Math]::Max(2, [Math]::Round($Priority * 0.68)) }
            if ($Priority -le 40) { return [Math]::Max(2, [Math]::Round($Priority * 0.54)) }
            if ($Priority -le 100) { return [Math]::Max(8, [Math]::Round($Priority * 0.46)) }
            return [Math]::Max(18, [Math]::Round($Priority * 0.38))
        }
        "Overlord" {
            if ($Priority -le 1) { return $Priority }
            if ($Priority -le 10) { return [Math]::Max(2, [Math]::Round($Priority * 0.58)) }
            if ($Priority -le 40) { return [Math]::Max(2, [Math]::Round($Priority * 0.42)) }
            if ($Priority -le 100) { return [Math]::Max(6, [Math]::Round($Priority * 0.34)) }
            return [Math]::Max(14, [Math]::Round($Priority * 0.28))
        }
        default {
            throw "Unknown profile: $Profile"
        }
    }
}

function Get-InfrastructurePriority {
    param(
        [int]$BuildingId,
        [int]$Priority,
        [string]$Profile
    )

    $economy = @(0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x0F, 0x11, 0x12, 0x27, 0x29, 0x2A, 0x2B, 0x40, 0x53)
    $weapons = @(0x08, 0x09, 0x0A, 0x0E, 0x30, 0x4A, 0x4B, 0x4D)
    $military = @(0x18, 0x41, 0x44, 0x46, 0x51)

    $category = if ($economy -contains $BuildingId) {
        "Economy"
    } elseif ($weapons -contains $BuildingId) {
        "Weapons"
    } elseif ($military -contains $BuildingId) {
        "Military"
    } else {
        return $Priority
    }

    $factor = 1.0
    switch ($Profile) {
        "Hard" {
            if ($category -eq "Economy") { $factor = 0.90 }
            elseif ($category -eq "Weapons") { $factor = 0.94 }
            else { $factor = 0.96 }
        }
        "Brutal" {
            if ($category -eq "Economy") { $factor = 0.78 }
            elseif ($category -eq "Weapons") { $factor = 0.84 }
            else { $factor = 0.88 }
        }
        "Overlord" {
            if ($category -eq "Economy") { $factor = 0.65 }
            elseif ($category -eq "Weapons") { $factor = 0.72 }
            else { $factor = 0.78 }
        }
    }
    return [Math]::Max(2, [Math]::Round($Priority * $factor))
}

function Patch-AicBytes {
    param(
        [byte[]]$Bytes,
        [string]$Profile,
        [switch]$Patch
    )

    if ($Bytes.Length -lt 4) {
        throw "AIC file is too small"
    }

    $count = [BitConverter]::ToUInt32($Bytes, 0)
    $recordsEnd = 4 + ($count * 8)
    if ($recordsEnd -gt $Bytes.Length) {
        throw "AIC object table overruns file: count=$count size=$($Bytes.Length)"
    }

    $output = New-Object byte[] $Bytes.Length
    [Array]::Copy($Bytes, $output, $Bytes.Length)

    if ($Patch) {
        for ($index = 0; $index -lt $count; $index++) {
            $recordOffset = 4 + ($index * 8)
            $offset = $recordOffset + 4
            $buildingId = [int]$output[$recordOffset]
            $priority = [BitConverter]::ToUInt16($output, $offset)
            $scaled = [int](Get-ScaledPriority -Priority $priority -Profile $Profile)
            $scaled = [int](Get-InfrastructurePriority -BuildingId $buildingId -Priority $scaled -Profile $Profile)
            $output[$offset] = [byte]($scaled -band 0xFF)
            $output[$offset + 1] = [byte](($scaled -shr 8) -band 0xFF)
        }
    }

    return [pscustomobject]@{
        Bytes = $output
        ObjectCount = $count
        TrailerBytes = $Bytes.Length - $recordsEnd
    }
}

function Get-SubstitutionMap {
    param([string]$Profile)

    $balanced = @{
        "edwin01.aic" = "edwin03.aic"
        "edwin02.aic" = "edwin03.aic"
        "hawk02.aic" = "hawk01.aic"
        "king02.aic" = "king01.aic"
    }

    $hard = @{
        "Barclay02.aic" = "Barclay01.aic"
        "Barclay03.aic" = "Barclay01.aic"
        "edwin01.aic" = "edwin03.aic"
        "edwin02.aic" = "edwin03.aic"
        "hawk02.aic" = "hawk01.aic"
        "king02.aic" = "king01.aic"
        "William01.aic" = "William02.aic"
        "Tiny_Stone.aic" = "Tiny_Stone3.aic"
        "Tiny_Stone2.aic" = "Tiny_Stone3.aic"
        "Tiny_Wooden.aic" = "Small_Wooden.aic"
    }

    $brutal = $hard.Clone()
    foreach ($name in @("Tiny_Stone.aic", "Tiny_Stone2.aic", "Tiny_Stone3.aic", "Tiny_Stone4.aic")) {
        $brutal[$name] = "Small_Stone4.aic"
    }
    foreach ($name in @("Small_Stone.aic", "Small_Stone2.aic", "Small_Stone3.aic")) {
        $brutal[$name] = "Small_Stone4.aic"
    }
    $brutal["Tiny_Wooden.aic"] = "Med_Wooden.aic"
    $brutal["Small_Wooden.aic"] = "Med_Wooden.aic"

    $overlord = $brutal.Clone()
    foreach ($name in @(
        "Tiny_Stone.aic", "Tiny_Stone2.aic", "Tiny_Stone3.aic", "Tiny_Stone4.aic",
        "Small_Stone.aic", "Small_Stone2.aic", "Small_Stone3.aic", "Small_Stone4.aic"
    )) {
        $overlord[$name] = "Med_Stone.aic"
    }
    $overlord["Med_Stone.aic"] = "Large_Stone.aic"
    $overlord["Tiny_Wooden.aic"] = "Large_Wooden.aic"
    $overlord["Small_Wooden.aic"] = "Large_Wooden.aic"
    $overlord["Med_Wooden.aic"] = "Large_Wooden.aic"

    if ($Profile -eq "Balanced") {
        return $balanced
    }
    if ($Profile -eq "Hard") {
        return $hard
    }
    if ($Profile -eq "Brutal") {
        return $brutal
    }
    if ($Profile -eq "Overlord") {
        return $overlord
    }
    throw "Unknown profile: $Profile"
}

$profiles = @(
    [pscustomobject]@{ Key = "balanced"; Title = "Balanced"; Description = "Moderate AI castle hardening." },
    [pscustomobject]@{ Key = "hard"; Title = "Hard"; Description = "Stronger same-lord and same-material castle progression." },
    [pscustomobject]@{ Key = "brutal"; Title = "Brutal"; Description = "Large same-material castle upgrades with aggressive build priorities." },
    [pscustomobject]@{ Key = "overlord"; Title = "Overlord"; Description = "Maximum infrastructure for large, open AI estates; not intended for cramped build areas." }
)

$sourceFiles = Get-ChildItem -LiteralPath $sourceCastles -Filter "*.aic" -File | Sort-Object Name
if ($sourceFiles.Count -eq 0) {
    throw "No .aic files found under: $sourceCastles"
}

if (Test-Path -LiteralPath $profilesRoot) {
    Remove-Item -LiteralPath $profilesRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $profilesRoot | Out-Null

$aggregateProfiles = @()
foreach ($profile in $profiles) {
    $profileName = $profile.Title
    $profileRoot = Join-Path $profilesRoot $profile.Key
    $profileCastles = Join-Path $profileRoot "castles"
    New-Item -ItemType Directory -Force -Path $profileCastles | Out-Null

    $substitutions = Get-SubstitutionMap -Profile $profileName
    $fileReports = @()

    foreach ($targetFile in $sourceFiles) {
        $sourceName = $targetFile.Name
        if ($substitutions.ContainsKey($targetFile.Name)) {
            $sourceName = $substitutions[$targetFile.Name]
        }

        $sourcePath = Join-Path $sourceCastles $sourceName
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Missing substituted source file: $sourcePath"
        }

        $sourceBytes = [System.IO.File]::ReadAllBytes($sourcePath)
        $patch = Test-PatchTarget -Name $targetFile.Name
        $patched = Patch-AicBytes -Bytes $sourceBytes -Profile $profileName -Patch:$patch
        $outputPath = Join-Path $profileCastles $targetFile.Name
        [System.IO.File]::WriteAllBytes($outputPath, $patched.Bytes)

        $fileReports += [pscustomobject]@{
            file = $targetFile.Name
            source_file = $sourceName
            patched = $patch
            substituted = ($sourceName -ne $targetFile.Name)
            object_count = $patched.ObjectCount
            trailer_bytes = $patched.TrailerBytes
            source_sha256 = (Get-FileSha256 -Path $sourcePath)
            modded_sha256 = (Get-FileSha256 -Path $outputPath)
        }
    }

    $manifest = [ordered]@{
        name = "Stronghold 2 AI Overhaul - $($profile.Title)"
        profile = $profile.Key
        title = $profile.Title
        description = $profile.Description
        game = "Stronghold 2 Steam Edition"
        game_rules_dat = "not modified"
        generated_from = $sourceCastles
        files = $fileReports
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $profileRoot "manifest.json") -Encoding UTF8

    $aggregateProfiles += [pscustomobject]@{
        profile = $profile.Key
        title = $profile.Title
        description = $profile.Description
        file_count = $fileReports.Count
        patched_count = ($fileReports | Where-Object { $_.patched }).Count
        substituted_count = ($fileReports | Where-Object { $_.substituted }).Count
    }
}

$hardCastles = Join-Path $profilesRoot "hard\castles"
if (Test-Path -LiteralPath $legacyHardCastles) {
    Remove-Item -LiteralPath $legacyHardCastles -Recurse -Force
}
Copy-Item -LiteralPath $hardCastles -Destination $legacyHardCastles -Recurse -Force

$aggregate = [ordered]@{
    name = "Stronghold 2 AI Overhaul"
    version = "4.5-strategic-build-order-local-generator"
    default_profile = "hard"
    source_game_path = $GamePath
    profiles = $aggregateProfiles
}
$aggregate | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ProjectRoot "modded\manifest.json") -Encoding UTF8

Write-Host "Generated AI profiles from local Stronghold 2 files:"
foreach ($profile in $aggregateProfiles) {
    Write-Host ("{0}: files={1} patched={2} substituted={3}" -f $profile.title, $profile.file_count, $profile.patched_count, $profile.substituted_count)
}
