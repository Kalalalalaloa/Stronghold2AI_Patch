param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Profile = "All",
    [string]$GamePath = "F:\SteamLibrary\steamapps\common\Stronghold 2"
)

$ErrorActionPreference = "Stop"

function Test-AicProfile {
    param(
        [string]$CastlesPath,
        [string]$ManifestPath,
        [string]$ProfileName
    )

    if (-not (Test-Path -LiteralPath $CastlesPath)) {
        throw "Missing modded castles directory: $CastlesPath"
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Missing manifest: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $files = Get-ChildItem -LiteralPath $CastlesPath -Filter "*.aic" -File

    if ($files.Count -ne $manifest.files.Count) {
        throw "Manifest/file count mismatch for ${ProfileName}: manifest=$($manifest.files.Count), files=$($files.Count)"
    }

    foreach ($file in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        if ($bytes.Length -lt 4) {
            throw "$($file.Name) is too small"
        }

        $count = [BitConverter]::ToUInt32($bytes, 0)
        $recordsEnd = 4 + ($count * 8)
        if ($recordsEnd -gt $bytes.Length) {
            throw "$($file.Name) has an invalid object table"
        }

        $trailerBytes = $bytes.Length - $recordsEnd
        $lowerName = $file.Name.ToLowerInvariant()
        $excluded = $lowerName.StartsWith("aivchap") -or $lowerName.StartsWith("test")
        if ((-not $excluded) -and ($trailerBytes -ne 2924)) {
            throw "$($file.Name) has unexpected trailer size $trailerBytes"
        }
    }

    Write-Host "Validation OK: $ProfileName profile has $($files.Count) structurally consistent AIC files."
}

function Expand-Zlib {
    param([byte[]]$Bytes)

    if ($Bytes.Length -lt 6) {
        throw "gameRules.dat is too small to be a zlib stream"
    }

    if (($Bytes[0] -ne 0x78) -or ($Bytes[1] -ne 0x9c)) {
        throw "Unexpected zlib header: $($Bytes[0].ToString('X2')) $($Bytes[1].ToString('X2'))"
    }

    $payload = New-Object byte[] ($Bytes.Length - 6)
    [Array]::Copy($Bytes, 2, $payload, 0, $payload.Length)
    $input = New-Object System.IO.MemoryStream(,$payload)
    $deflate = New-Object System.IO.Compression.DeflateStream($input, [System.IO.Compression.CompressionMode]::Decompress)
    $output = New-Object System.IO.MemoryStream
    $deflate.CopyTo($output)
    $deflate.Dispose()
    return $output.ToArray()
}

function Test-RulesProfile {
    param(
        [string]$RulesPath,
        [string]$ManifestPath,
        [string]$ProfileName
    )

    if (-not (Test-Path -LiteralPath $RulesPath)) {
        throw "Missing gameRules.dat profile: $RulesPath"
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Missing gameRules manifest: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $bytes = [System.IO.File]::ReadAllBytes($RulesPath)
    $raw = Expand-Zlib -Bytes $bytes

    if ($raw.Length -ne [int]$manifest.raw_length) {
        throw "gameRules.dat raw length mismatch for ${ProfileName}: manifest=$($manifest.raw_length), raw=$($raw.Length)"
    }

    $changeCount = [int]$manifest.change_count
    if (($ProfileName -eq "balanced") -and ($changeCount -ne 0)) {
        throw "Balanced gameRules.dat must remain a byte-identical rules baseline, found $changeCount changes"
    }
    if (($ProfileName -ne "balanced") -and ($changeCount -lt 1)) {
        throw "gameRules.dat manifest has no changes for $ProfileName"
    }

    if ($manifest.PSObject.Properties.Name -contains "army_group_starts") {
        if ($manifest.army_group_starts.Count -ne 21) {
            throw "gameRules.dat manifest expected 21 Lord army groups for ${ProfileName}, found $($manifest.army_group_starts.Count)"
        }

        $hasTypedChanges = (
            ($manifest.changes.Count -gt 0) -and
            ($manifest.changes[0].PSObject.Properties.Name -contains "change_type")
        )

        if (
            $hasTypedChanges -and
            ($manifest.PSObject.Properties.Name -contains "verified_unit_type_columns") -and
            ($manifest.PSObject.Properties.Name -contains "verified_support_count_columns")
        ) {
            $allowedUnitTypeColumns = @($manifest.verified_unit_type_columns | ForEach-Object { [int]$_ })
            $allowedSupportColumns = @($manifest.verified_support_count_columns | ForEach-Object { [int]$_ })
            foreach ($change in $manifest.changes) {
                $column = [int]$change.column
                $changeType = [string]$change.change_type
                switch ($changeType) {
                    "unit_type" {
                        if ($allowedUnitTypeColumns -notcontains $column) {
                            throw "gameRules.dat manifest has unexpected unit-type column $column for ${ProfileName}"
                        }
                    }
                    "support_count" {
                        if ($allowedSupportColumns -notcontains $column) {
                            throw "gameRules.dat manifest has unexpected support-count column $column for ${ProfileName}"
                        }
                    }
                    default {
                        throw "gameRules.dat manifest has unexpected change type '$changeType' for ${ProfileName}"
                    }
                }
            }
        } elseif (
            $hasTypedChanges -and
            ($manifest.PSObject.Properties.Name -contains "quantity_columns") -and
            ($manifest.PSObject.Properties.Name -contains "unit_type_columns")
        ) {
            $allowedQuantityColumns = @($manifest.quantity_columns | ForEach-Object { [int]$_ })
            $allowedUnitTypeColumns = @($manifest.unit_type_columns | ForEach-Object { [int]$_ })
            foreach ($change in $manifest.changes) {
                $column = [int]$change.column
                $changeType = [string]$change.change_type
                switch ($changeType) {
                    "quantity" {
                        if ($allowedQuantityColumns -notcontains $column) {
                            throw "gameRules.dat manifest has unexpected quantity column $column for ${ProfileName}"
                        }
                    }
                    "unit_id" {
                        if ($allowedUnitTypeColumns -notcontains $column) {
                            throw "gameRules.dat manifest has unexpected unit-id column $column for ${ProfileName}"
                        }
                    }
                    default {
                        throw "gameRules.dat manifest has unexpected change type '$changeType' for ${ProfileName}"
                    }
                }
            }
        } else {
            $allowedColumns = @(5, 6, 8, 10, 12, 14, 15)
            foreach ($change in $manifest.changes) {
                if ($allowedColumns -notcontains [int]$change.column) {
                    throw "gameRules.dat manifest has unexpected changed column $($change.column) for ${ProfileName}"
                }
            }
        }
    }

    Write-Host "Validation OK: $ProfileName gameRules.dat decompresses to $($raw.Length) bytes with $($manifest.change_count) candidate changes."
}

$profilesRoot = Join-Path $ProjectRoot "modded\profiles"
if (-not (Test-Path -LiteralPath $profilesRoot)) {
    $builder = Join-Path $ProjectRoot "tools\Build-Stronghold2AIProfiles.ps1"
    if (Test-Path -LiteralPath $builder) {
        Write-Host "Profiles are missing. Generating profiles from local game files before validation..."
        & $builder -GamePath $GamePath -ProjectRoot $ProjectRoot
    }
}

if (Test-Path -LiteralPath $profilesRoot) {
    if ($Profile -eq "All") {
        $profileDirs = Get-ChildItem -LiteralPath $profilesRoot -Directory
    } else {
        $profileDirs = @(
            Get-Item -LiteralPath (Join-Path $profilesRoot $Profile.ToLowerInvariant())
        )
    }

    foreach ($profileDir in $profileDirs) {
        Test-AicProfile `
            -CastlesPath (Join-Path $profileDir.FullName "castles") `
            -ManifestPath (Join-Path $profileDir.FullName "manifest.json") `
            -ProfileName $profileDir.Name
    }
} else {
    Test-AicProfile `
        -CastlesPath (Join-Path $ProjectRoot "modded\castles") `
        -ManifestPath (Join-Path $ProjectRoot "modded\manifest.json") `
        -ProfileName "legacy-hard"
}

$rulesRoot = Join-Path $ProjectRoot "modded\rules"
if (-not (Test-Path -LiteralPath $rulesRoot)) {
    $rulesBuilder = Join-Path $ProjectRoot "tools\Build-Stronghold2GameRulesPatch.ps1"
    if (Test-Path -LiteralPath $rulesBuilder) {
        Write-Host "Experimental gameRules.dat profiles are missing. Generating them from local game files before validation..."
        & $rulesBuilder -GamePath $GamePath -ProjectRoot $ProjectRoot
    }
}

if (Test-Path -LiteralPath $rulesRoot) {
    if ($Profile -eq "All") {
        $rulesProfileDirs = Get-ChildItem -LiteralPath $rulesRoot -Directory
    } else {
        $rulesProfileDirs = @(
            Get-Item -LiteralPath (Join-Path $rulesRoot $Profile.ToLowerInvariant())
        )
    }

    foreach ($rulesProfileDir in $rulesProfileDirs) {
        Test-RulesProfile `
            -RulesPath (Join-Path $rulesProfileDir.FullName "gameRules.dat") `
            -ManifestPath (Join-Path $rulesProfileDir.FullName "manifest.json") `
            -ProfileName $rulesProfileDir.Name
    }
}
