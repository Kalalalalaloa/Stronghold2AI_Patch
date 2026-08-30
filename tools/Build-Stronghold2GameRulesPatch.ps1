param(
    [string]$GamePath = "F:\SteamLibrary\steamapps\common\Stronghold 2",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AllowNonVanillaSource
)

$ErrorActionPreference = "Stop"

$sourceRules = Join-Path $GamePath "gameRules.dat"
$rulesRoot = Join-Path $ProjectRoot "modded\rules"

if (-not (Test-Path -LiteralPath $sourceRules)) {
    throw "Missing gameRules.dat: $sourceRules"
}

function Get-Adler32Bytes {
    param([byte[]]$Data)

    [uint32]$a = 1
    [uint32]$b = 0
    foreach ($byte in $Data) {
        $a = ($a + [uint32]$byte) % 65521
        $b = ($b + $a) % 65521
    }
    [uint32]$adler = (($b -shl 16) -bor $a)
    return [byte[]]@(
        [byte](($adler -shr 24) -band 255),
        [byte](($adler -shr 16) -band 255),
        [byte](($adler -shr 8) -band 255),
        [byte]($adler -band 255)
    )
}

function Get-Sha256Hex {
    param([byte[]]$Data)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($Data)
        return (($hashBytes | ForEach-Object { $_.ToString("x2") }) -join "").ToUpperInvariant()
    } finally {
        $sha.Dispose()
    }
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

function Compress-Zlib {
    param([byte[]]$Raw)

    $output = New-Object System.IO.MemoryStream
    $output.WriteByte(0x78)
    $output.WriteByte(0x9c)
    $deflater = New-Object System.IO.Compression.DeflateStream($output, [System.IO.Compression.CompressionMode]::Compress, $true)
    $deflater.Write($Raw, 0, $Raw.Length)
    $deflater.Dispose()
    $adler = Get-Adler32Bytes -Data $Raw
    $output.Write($adler, 0, 4)
    return $output.ToArray()
}

function Find-Bytes {
    param(
        [byte[]]$Haystack,
        [byte[]]$Needle,
        [int]$Start = 0
    )

    $hits = @()
    for ($i = $Start; $i -le ($Haystack.Length - $Needle.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            $hits += $i
        }
    }
    return $hits
}

function Get-Int32LittleEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    return [BitConverter]::ToInt32($Bytes, $Offset)
}

function Get-LordCandidateName {
    param([int]$GroupIndex)

    $lordNames = @(
        "Bishop", "Queen", "Caliph", "Wolf", "Pig", "Snake", "Rat", "Bull",
        "Hawk", "Grey", "Olaf", "Edwin", "King", "William", "Seren", "Barclay"
    )
    if ($GroupIndex -ge 0 -and $GroupIndex -lt $lordNames.Count) {
        return $lordNames[$GroupIndex]
    }
    return "Fallback$GroupIndex"
}

function Get-VerifiedUnitReplacement {
    param(
        [int]$Value,
        [string]$Profile,
        [string]$Role,
        [int]$GroupIndex,
        [int]$SlotIndex
    )

    if ($Profile -eq "Balanced") {
        return $Value
    }

    # Actor ids verified in Stronghold2.exe at FUN_008be030.
    $archer = 0x13
    $swordsman = 0x1b
    $spearman = 0x1c
    $armedPeasant = 0x31
    $maceman = 0x32
    $pikeman = 0x33
    $crossbowman = 0x34
    $knight = 0x47

    switch ($Profile) {
        "Hard" {
            switch ($Role) {
                "ranged" { if ($Value -eq $archer) { return $crossbowman } }
                "infantry" { if ($Value -in @($spearman, $armedPeasant)) { return $pikeman } }
                "support" { if ($Value -in @($spearman, $armedPeasant)) { return $maceman } }
                "elite" { if ($Value -in @($archer, $spearman, $armedPeasant)) { return $swordsman } }
            }
        }
        "Brutal" {
            switch ($Role) {
                "ranged" { if ($Value -in @($archer, $armedPeasant)) { return $crossbowman } }
                "infantry" { if ($Value -in @($spearman, $armedPeasant)) { return $maceman } }
                "support" { if ($Value -in @($spearman, $armedPeasant, $maceman)) { return $pikeman } }
                "elite" { if ($Value -in @($archer, $spearman, $armedPeasant, $maceman)) { return $knight } }
            }
        }
        "Overlord" {
            switch ($Role) {
                "ranged" { if ($Value -in @($archer, $armedPeasant)) { return $crossbowman } }
                "infantry" {
                    if ($Value -in @($spearman, $armedPeasant)) {
                        if ((($GroupIndex + $SlotIndex) % 2) -eq 0) { return $pikeman }
                        return $maceman
                    }
                }
                "support" { if ($Value -in @($spearman, $armedPeasant, $maceman)) { return $swordsman } }
                "elite" { if ($Value -in @($archer, $spearman, $armedPeasant, $maceman, $pikeman, $swordsman)) { return $knight } }
            }
        }
        default { throw "Unknown profile: $Profile" }
    }

    return $Value
}

function Get-MinimumSupportCount {
    param(
        [int]$Value,
        [string]$Profile,
        [string]$FieldName
    )

    if ($Profile -eq "Balanced") {
        return $Value
    }

    $minimums = switch ($Profile) {
        "Hard" { @{ laddermen = 12; catapults = 2; trebuchets = 1; fire_ballistas = 1; battering_rams = 1; small_siege_towers = 0; large_siege_towers = 1; cats = 1; burning_carts = 0; mantlets = 2 } }
        "Brutal" { @{ laddermen = 18; catapults = 4; trebuchets = 2; fire_ballistas = 2; battering_rams = 2; small_siege_towers = 1; large_siege_towers = 2; cats = 2; burning_carts = 1; mantlets = 4 } }
        "Overlord" { @{ laddermen = 24; catapults = 6; trebuchets = 3; fire_ballistas = 3; battering_rams = 3; small_siege_towers = 2; large_siege_towers = 3; cats = 3; burning_carts = 2; mantlets = 6 } }
        default { throw "Unknown profile: $Profile" }
    }

    if (-not $minimums.ContainsKey($FieldName)) {
        return $Value
    }
    return [Math]::Max($Value, [int]$minimums[$FieldName])
}

function Set-Int32LittleEndian {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [int]$Value
    )

    $Bytes[$Offset] = [byte]($Value -band 255)
    $Bytes[$Offset + 1] = [byte](($Value -shr 8) -band 255)
    $Bytes[$Offset + 2] = [byte](($Value -shr 16) -band 255)
    $Bytes[$Offset + 3] = [byte](($Value -shr 24) -band 255)
}

function Find-LordArmyGroups {
    param(
        [byte[]]$Bytes,
        [int]$Start,
        [int]$End
    )

    $groups = @()
    for ($offset = ($Start + 4); $offset -le ($End - 16); $offset++) {
        $v0 = Get-Int32LittleEndian -Bytes $Bytes -Offset $offset
        $v1 = Get-Int32LittleEndian -Bytes $Bytes -Offset ($offset + 4)
        $v2 = Get-Int32LittleEndian -Bytes $Bytes -Offset ($offset + 8)
        $v3 = Get-Int32LittleEndian -Bytes $Bytes -Offset ($offset + 12)

        if (($v0 -eq 2) -and ($v1 -eq 1) -and ($v2 -eq 8) -and ($v3 -eq 88)) {
            $groupStart = $offset - 4
            $first = Get-Int32LittleEndian -Bytes $Bytes -Offset $groupStart
            if ($first -ge 0 -and $first -le 16) {
                $groups += $groupStart
            }
        }
    }

    return $groups
}

function New-ExperimentalRules {
    param(
        [byte[]]$Raw,
        [string]$Profile
    )

    $output = New-Object byte[] $Raw.Length
    [Array]::Copy($Raw, $output, $Raw.Length)

    $lordsName = [System.Text.Encoding]::ASCII.GetBytes("LordsRules")
    $lordsNameHits = Find-Bytes -Haystack $Raw -Needle $lordsName
    if ($lordsNameHits.Count -ne 1) {
        throw "Expected one LordsRules marker, found $($lordsNameHits.Count)"
    }

    $lordsBase = $lordsNameHits[0] + $lordsName.Length
    $armyGroupStarts = Find-LordArmyGroups -Bytes $Raw -Start $lordsBase -End $Raw.Length
    if ($armyGroupStarts.Count -ne 21) {
        throw "Expected 21 inferred Lord army groups, found $($armyGroupStarts.Count)"
    }

    # FUN_00467260 serializes LordsRules section 8 as 22 int32 values. The
    # executable reads these fields in FUN_00461c20, FUN_0045feb0,
    # FUN_00460370, and FUN_00462ac0. Columns 25/26 stay untouched because
    # their behavior is not yet proven. Actor 0x5B is the verified Cat.
    $unitFields = @(
        [pscustomobject]@{ Slot = 0; Column = 7; ObjectOffset = "0x348"; Name = "attack_unit_ranged"; Role = "ranged" },
        [pscustomobject]@{ Slot = 1; Column = 9; ObjectOffset = "0x350"; Name = "attack_unit_infantry"; Role = "infantry" },
        [pscustomobject]@{ Slot = 3; Column = 11; ObjectOffset = "0x358"; Name = "attack_unit_support"; Role = "support" },
        [pscustomobject]@{ Slot = 2; Column = 13; ObjectOffset = "0x360"; Name = "attack_unit_elite"; Role = "elite" }
    )
    $supportFields = @(
        [pscustomobject]@{ Column = 15; ObjectOffset = "0x394"; Name = "laddermen"; ActorId = 0x1d },
        [pscustomobject]@{ Column = 16; ObjectOffset = "0x368"; Name = "catapults"; ActorId = 0x44 },
        [pscustomobject]@{ Column = 17; ObjectOffset = "0x36c"; Name = "trebuchets"; ActorId = 0x42 },
        [pscustomobject]@{ Column = 18; ObjectOffset = "0x370"; Name = "fire_ballistas"; ActorId = 0x43 },
        [pscustomobject]@{ Column = 19; ObjectOffset = "0x374"; Name = "battering_rams"; ActorId = 0x5a },
        [pscustomobject]@{ Column = 20; ObjectOffset = "0x378"; Name = "small_siege_towers"; ActorId = 0x59 },
        [pscustomobject]@{ Column = 21; ObjectOffset = "0x37c"; Name = "large_siege_towers"; ActorId = 0x58 },
        [pscustomobject]@{ Column = 22; ObjectOffset = "0x380"; Name = "cats"; ActorId = 0x5b },
        [pscustomobject]@{ Column = 23; ObjectOffset = "0x384"; Name = "burning_carts"; ActorId = 0x67 },
        [pscustomobject]@{ Column = 24; ObjectOffset = "0x388"; Name = "mantlets"; ActorId = 0x66 }
    )
    $changes = @()

    for ($groupIndex = 0; $groupIndex -lt $armyGroupStarts.Count; $groupIndex++) {
        $groupStart = $armyGroupStarts[$groupIndex]
        foreach ($field in $unitFields) {
            $offset = $groupStart + ([int]$field.Column * 4)
            if (($offset + 4) -gt $Raw.Length) {
                throw "Attack unit field exceeds raw size: group=$groupIndex field=$($field.Name) offset=$offset"
            }

            $old = Get-Int32LittleEndian -Bytes $Raw -Offset $offset
            $new = [int](Get-VerifiedUnitReplacement `
                -Value $old `
                -Profile $Profile `
                -Role $field.Role `
                -GroupIndex $groupIndex `
                -SlotIndex $field.Slot)
            if ($new -ne $old) {
                Set-Int32LittleEndian -Bytes $output -Offset $offset -Value $new
                $changes += [pscustomobject]@{
                    raw_offset = $offset
                    army_group_index = $groupIndex
                    lord_candidate = (Get-LordCandidateName -GroupIndex $groupIndex)
                    army_group_start = $groupStart
                    column = $field.Column
                    object_offset = $field.ObjectOffset
                    field_name = $field.Name
                    slot = $field.Slot
                    change_type = "unit_type"
                    old_value = $old
                    new_value = $new
                }
            }
        }

        foreach ($field in $supportFields) {
            $offset = $groupStart + ([int]$field.Column * 4)
            if (($offset + 4) -gt $Raw.Length) {
                throw "Attack support field exceeds raw size: group=$groupIndex field=$($field.Name) offset=$offset"
            }

            $old = Get-Int32LittleEndian -Bytes $Raw -Offset $offset
            $new = [int](Get-MinimumSupportCount -Value $old -Profile $Profile -FieldName $field.Name)
            if ($new -ne $old) {
                Set-Int32LittleEndian -Bytes $output -Offset $offset -Value $new
                $changes += [pscustomobject]@{
                    raw_offset = $offset
                    army_group_index = $groupIndex
                    lord_candidate = (Get-LordCandidateName -GroupIndex $groupIndex)
                    army_group_start = $groupStart
                    column = $field.Column
                    object_offset = $field.ObjectOffset
                    field_name = $field.Name
                    actor_id = $field.ActorId
                    change_type = "support_count"
                    old_value = $old
                    new_value = $new
                }
            }
        }
    }

    return [pscustomobject]@{
        Raw = $output
        LordsBase = $lordsBase
        ArmyGroupStarts = $armyGroupStarts
        UnitFields = $unitFields
        SupportFields = $supportFields
        Changes = $changes
    }
}

$sourceBytes = [System.IO.File]::ReadAllBytes($sourceRules)
$sourceHash = Get-Sha256Hex -Data $sourceBytes
$knownVanillaGameRulesHashes = @(
    "BBB321060700E8366BA71DC04BDECD43F007012D39A0B0DAB0790DC2B431D452"
)

if (($knownVanillaGameRulesHashes -notcontains $sourceHash) -and (-not $AllowNonVanillaSource)) {
    throw "Selected gameRules.dat is not the known clean Stronghold 2 Steam Edition file. Restore the mod backup or use Steam 'Verify integrity of game files' before generating experimental rules. Source=$sourceRules SHA256=$sourceHash"
}

$raw = Expand-Zlib -Bytes $sourceBytes

if (Test-Path -LiteralPath $rulesRoot) {
    Remove-Item -LiteralPath $rulesRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $rulesRoot | Out-Null

$profiles = @("Balanced", "Hard", "Brutal", "Overlord")
foreach ($profile in $profiles) {
    $profileKey = $profile.ToLowerInvariant()
    $profileRoot = Join-Path $rulesRoot $profileKey
    New-Item -ItemType Directory -Force -Path $profileRoot | Out-Null

    $patched = New-ExperimentalRules -Raw $raw -Profile $profile
    $compressed = Compress-Zlib -Raw $patched.Raw
    $outputPath = Join-Path $profileRoot "gameRules.dat"
    [System.IO.File]::WriteAllBytes($outputPath, $compressed)

    $verifyRaw = Expand-Zlib -Bytes $compressed
    if ($verifyRaw.Length -ne $raw.Length) {
        throw "Roundtrip raw length mismatch for $profile"
    }

    $manifest = [ordered]@{
        name = "Stronghold 2 AI Overhaul v4.5 Verified Attack Rules - $profile"
        profile = $profileKey
        source = $sourceRules
        warning = "Experimental reverse-engineered rules patch. Field offsets, actor ids, and code consumers are statically verified; gameplay balance and AI economy behavior still require in-game testing."
        patch_strategy = "Patches only verified LordsRules section-8 unit actor fields and direct ladder/siege support quantities. Vanilla army target sizes, random ranges, and selection weights remain unchanged to avoid delaying the first attack."
        stage_policy = "Stronghold 2 has no early/mid/late roster slots in this block. Balanced is a byte-identical rules baseline. Hard, Brutal, and Overlord progressively upgrade valid troop actor ids and guaranteed siege support."
        siege_pressure_note = "FUN_00460370 directly consumes the patched catapult, trebuchet, fire-ballista, ram, siege-tower, Cat, burning-cart, and mantlet counts. FUN_00462ac0 consumes the ladderman count. Gold/resource assistance is not included in the public-safe track."
        lord_mapping_note = "Strong candidate only: profile indices 0-15 are mapped to the executable lord enum order Bishop, Queen, Caliph, Wolf, Pig, Snake, Rat, Bull, Hawk, Grey, Olaf, Edwin, King, William, Seren, Barclay. Indices 16-20 are treated as fallbacks."
        verified_actor_ids = [ordered]@{
            Archer = 0x13
            Swordsman = 0x1b
            Spearman = 0x1c
            Ladderman = 0x1d
            ArmedPeasant = 0x31
            Maceman = 0x32
            Pikeman = 0x33
            Crossbowman = 0x34
            Knight = 0x47
            Trebuchet = 0x42
            FireBallista = 0x43
            Catapult = 0x44
            LargeSiegeTower = 0x58
            SmallSiegeTower = 0x59
            BatteringRam = 0x5a
            Cat = 0x5b
            Mantlet = 0x66
            BurningCart = 0x67
        }
        verified_unit_type_columns = @(7, 9, 11, 13)
        verified_support_count_columns = @(15, 16, 17, 18, 19, 20, 21, 22, 23, 24)
        intentionally_unchanged_columns = [ordered]@{
            minimum_attack_army_size = 5
            random_extra_army_size = 6
            selection_weights = @(8, 10, 12, 14)
            unknown_fields = @(25, 26)
        }
        unit_fields = $patched.UnitFields
        support_fields = $patched.SupportFields
        raw_length = $raw.Length
        compressed_length = $compressed.Length
        lords_base = $patched.LordsBase
        army_group_starts = $patched.ArmyGroupStarts
        change_count = $patched.Changes.Count
        changes = $patched.Changes
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $profileRoot "manifest.json") -Encoding UTF8
    Write-Host ("{0}: gameRules.dat generated, changes={1}, compressed={2} bytes" -f $profile, $patched.Changes.Count, $compressed.Length)
}
