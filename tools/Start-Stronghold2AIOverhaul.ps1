param(
    [string]$GamePath = "F:\SteamLibrary\steamapps\common\Stronghold 2",
    [switch]$Check,
    [switch]$UiCheck,
    [ValidateSet("Balanced", "Hard", "Brutal", "Overlord")]
    [string]$Profile = "Hard",
    [ValidateSet("Balanced", "Hard", "Brutal", "Overlord")]
    [string]$RuntimeDifficulty = "Hard",
    [switch]$EnableRuntimeDll,
    [switch]$EnableTunnelAssaults,
    [switch]$PatchGameRules,
    [ValidateSet("None", "Install", "Verify", "Restore")]
    [string]$BundleAction = "None"
)

$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSHOME "Modules\Microsoft.PowerShell.Utility") -ErrorAction Stop

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ExperimentalRoot = Join-Path $ProjectRoot "experimental_dll"
$ExperimentalLauncherPath = Join-Path $ExperimentalRoot "Start-ExperimentalDllLauncher.ps1"
$HasExperimentalDll = Test-Path -LiteralPath $ExperimentalLauncherPath
$CastleProfiles = @("Balanced", "Hard", "Brutal", "Overlord")
$ArmyProfiles = @("Balanced", "Hard", "Brutal", "Overlord")
$Script:Language = "de"
$Script:Texts = @{
    de = @{
        FormTitle = "Stronghold 2 AI Overhaul Launcher"
        Title = "Stronghold 2 AI Overhaul"
        Language = "Sprache"
        GamePath = "Stronghold 2 Ordner"
        Browse = "Suchen"
        ProfileGroup = "KI-Konfiguration"
        Profile = "Burgenprofil"
        ArmyProfile = "Armeedruck"
        RuntimeProfile = "DLL-Schwierigkeit"
        ProfileDescription = "Profilbeschreibung"
        Actions = "Aktionen"
        Install = "Installieren"
        InstallComplete = "Komplett installieren"
        Verify = "Pruefen"
        VerifyComplete = "Alles pruefen"
        Restore = "Backup wiederherstellen"
        RestoreComplete = "Alles entfernen"
        Launch = "Via Steam starten"
        OpenFolder = "Mod-Ordner"
        OptionalFeature = "Optionale Testfunktion"
        RulesCheckbox = "Experimentelle Truppen + Belagerungs-KI aktivieren (gameRules.dat)"
        RulesHint = "v4.5: strategische Bauabfolge plus verifizierte Truppentypen und direkte Belagerungsmengen. Engine-sichere Angriffsbudgets, Bonusgold und optionale Tunnel gibt es in der experimentellen DLL v0.10. Benoetigt eine saubere gameRules.dat."
        RuntimeFeature = "Experimentelle DLL v0.10 (nur Offline-Gefechte)"
        RuntimeCheckbox = "DLL-Roster, groessere Armeen und KI-Bonusgold aktivieren"
        TunnelCheckbox = "Zusaetzlich Tunnelangriffe gegen Tore und Tuerme aktivieren"
        RuntimeHint = "Empfohlen fuer den vollen KI-Test. Installiert den Steam-kompatiblen D3D9-Loader; nicht online verwenden. Die alte gameRules.dat-Testoption bleibt dabei aus."
        Log = "Log"
        Ready = "Bereit. Profil installieren und via Steam starten. Fuer den Online AI Enabler: nur installieren, Launcher schliessen und danach ueber den Enabler starten."
        GeneratingProfiles = "Erzeuge Profile aus lokalen Stronghold-2-Dateien..."
        GeneratingRules = "Erzeuge verifizierte Truppen- und Belagerungsprofile aus lokalen Stronghold-2-Dateien..."
        BrowseDialog = "Stronghold 2 Installationsordner auswaehlen"
        InvalidPath = "Stronghold-2-Pfad ist ungueltig"
        RulesEnabled = "Experimenteller Lord-Armee-/Unit-Roster-Patch ist aktiv."
        Installing = "Installiere Profil"
        InstallDone = "Installation abgeschlossen."
        RuntimeInstallDone = "Experimentelle DLL installiert."
        CheckResult = "Dateien stimmen"
        Missing = "Fehlend"
        Different = "Anders"
        RulesMatch = "gameRules.dat: stimmt mit dem experimentellen Regelprofil ueberein."
        RulesDifferent = "gameRules.dat: stimmt nicht mit dem experimentellen Regelprofil ueberein."
        Restoring = "Stelle aeltestes Backup wieder her..."
        RestoreDone = "Restore abgeschlossen."
        RuntimeRestoreDone = "Experimenteller DLL-Loader entfernt."
        RuntimeCheckDone = "Experimenteller DLL-Loader stimmt ueberein."
        Started = "Stronghold 2 ueber Steam gestartet."
        BalancedDescription = "Balanced: Moderate KI-Verstaerkung. Empfohlen fuer kleine oder enge Bauplaetze und fuer den ersten Test."
        HardDescription = "Hard: Standard-Herausforderung. Frueherer Burgausbau; bei sehr engen Karten ggf. Balanced nutzen."
        BrutalDescription = "Brutal: Staerkstes Profil. Nicht ideal fuer enge KI-Bauflaechen; kann unfertige oder unlogische Burgen verursachen."
        OverlordDescription = "Overlord: Maximales Bautempo fuer grosse KI-Bauflaechen. Auf engen Karten besser Balanced-Burgen mit Overlord-Armeedruck kombinieren."
        ArmyBalancedDescription = "Armee Balanced: unveraenderte Vanilla-Regeln als Kontrollprofil."
        ArmyHardDescription = "Armee Hard: gueltige Upgrades auf Armbrust-, Piken-, Streitkolben- und Schwertkaempfer plus moderate Belagerungsunterstuetzung."
        ArmyBrutalDescription = "Armee Brutal: staerkere Kerntruppen, Ritter im Elite-Slot und garantierte Leitern sowie mehrere Belagerungsgeraete."
        ArmyOverlordDescription = "Armee Overlord: maximale verifizierte Truppen-Upgrades mit der groessten Leiter-, Belagerungs- und Mantlet-Unterstuetzung."
        RuntimeBalancedDescription = "DLL Balanced: Vanilla-nahe Armeen, geringe Goldhilfe, keine Tunnel und maximal 160 Einheiten im spaeten Angriffspaket."
        RuntimeHardDescription = "DLL Hard: frueher Druck, begrenzte Tunnel und maximal 190 Einheiten im spaeten Angriffspaket."
        RuntimeBrutalDescription = "DLL Brutal: gemischte Bogenschuetzen/Armbrustschuetzen, hohe Goldreserve, breitere Tunnelangriffe und maximal 210 Einheiten im spaeten Angriffspaket."
        RuntimeOverlordDescription = "DLL Overlord: maximales engine-sicheres Angriffspaket von 220 inklusive Belagerung; mindestens 50 unter dem verifizierten KI-Rekrutierungsstopp."
    }
    en = @{
        FormTitle = "Stronghold 2 AI Overhaul Launcher"
        Title = "Stronghold 2 AI Overhaul"
        Language = "Language"
        GamePath = "Stronghold 2 folder"
        Browse = "Browse"
        ProfileGroup = "AI configuration"
        Profile = "Castle profile"
        ArmyProfile = "Army pressure"
        RuntimeProfile = "DLL difficulty"
        ProfileDescription = "Profile description"
        Actions = "Actions"
        Install = "Install"
        InstallComplete = "Install complete mod"
        Verify = "Check"
        VerifyComplete = "Check everything"
        Restore = "Restore backup"
        RestoreComplete = "Remove everything"
        Launch = "Start via Steam"
        OpenFolder = "Mod folder"
        OptionalFeature = "Optional test feature"
        RulesCheckbox = "Enable experimental troops + siege AI (gameRules.dat)"
        RulesHint = "v4.5: strategic build order plus verified troop types and direct siege quantities. Engine-safe attack budgets, bonus gold, and optional tunnels are in experimental DLL v0.10. Requires a clean gameRules.dat."
        RuntimeFeature = "Experimental DLL v0.10 (offline skirmishes only)"
        RuntimeCheckbox = "Enable DLL roster, larger armies, and AI bonus gold"
        TunnelCheckbox = "Also enable tunnel assaults against gates and towers"
        RuntimeHint = "Recommended for the full AI test. Installs the Steam-compatible D3D9 loader; do not use online. The legacy gameRules.dat test remains off."
        Log = "Log"
        Ready = "Ready. Install a profile and start through Steam. For Online AI Enabler: install only, close this launcher, then start through the enabler."
        GeneratingProfiles = "Generating profiles from local Stronghold 2 files..."
        GeneratingRules = "Generating verified troop and siege profiles from local Stronghold 2 files..."
        BrowseDialog = "Select Stronghold 2 installation folder"
        InvalidPath = "Stronghold 2 path is invalid"
        RulesEnabled = "Experimental Lord army/unit roster patch is enabled."
        Installing = "Installing profile"
        InstallDone = "Install finished."
        RuntimeInstallDone = "Experimental DLL installed."
        CheckResult = "files match"
        Missing = "Missing"
        Different = "Different"
        RulesMatch = "gameRules.dat: matches the experimental rules profile."
        RulesDifferent = "gameRules.dat: does not match the experimental rules profile."
        Restoring = "Restoring oldest backup..."
        RestoreDone = "Restore finished."
        RuntimeRestoreDone = "Experimental DLL loader removed."
        RuntimeCheckDone = "Experimental DLL loader matches."
        Started = "Started Stronghold 2 through Steam."
        BalancedDescription = "Balanced: Moderate AI hardening. Recommended for small or cramped build areas and for the first test."
        HardDescription = "Hard: Default challenge profile. Earlier castle development; use Balanced if the map is very cramped."
        BrutalDescription = "Brutal: Strongest profile. Not ideal for cramped AI build areas; it can cause incomplete or illogical castles."
        OverlordDescription = "Overlord: Maximum build speed for large AI estates. On cramped maps combine Balanced castles with Overlord army pressure."
        ArmyBalancedDescription = "Balanced army: unchanged vanilla rules as the control profile."
        ArmyHardDescription = "Hard army: valid crossbow, pike, mace, and sword upgrades with moderate siege support."
        ArmyBrutalDescription = "Brutal army: stronger core troops, knights in the elite slot, guaranteed ladders, and multiple siege engines."
        ArmyOverlordDescription = "Overlord army: maximum verified troop upgrades with the largest ladder, siege, and mantlet support."
        RuntimeBalancedDescription = "DLL Balanced: near-vanilla armies, low gold assistance, no tunnels, and a late attack-package cap of 160 units."
        RuntimeHardDescription = "DLL Hard: early pressure, limited tunnels, and a late attack-package cap of 190 units."
        RuntimeBrutalDescription = "DLL Brutal: mixed archers/crossbows, a high gold reserve, broader tunnel assaults, and a late attack-package cap of 210 units."
        RuntimeOverlordDescription = "DLL Overlord: maximum engine-safe attack package of 220 including siege, leaving at least 50 below the verified AI recruitment stop."
    }
}

function Get-Text {
    param([string]$Key)
    return $Script:Texts[$Script:Language][$Key]
}

function Get-ProfileCastlesPath {
    param([string]$Profile)
    $profileKey = $Profile.ToLowerInvariant()
    return (Join-Path $ProjectRoot "modded\profiles\$profileKey\castles")
}

function Get-RulesProfilePath {
    param([string]$Profile)
    $profileKey = $Profile.ToLowerInvariant()
    return (Join-Path $ProjectRoot "modded\rules\$profileKey\gameRules.dat")
}

function Ensure-ProfilesAvailable {
    param([string]$SelectedGamePath)

    $missing = @()
    foreach ($profile in $CastleProfiles) {
        $profilePath = Get-ProfileCastlesPath -Profile $profile
        if (-not (Test-Path -LiteralPath $profilePath)) {
            $missing += $profile
        }
    }

    if ($missing.Count -eq 0) {
        return
    }

    $builder = Join-Path $PSScriptRoot "Build-Stronghold2AIProfiles.ps1"
    if (-not (Test-Path -LiteralPath $builder)) {
        throw "Profiles are missing and profile builder was not found: $builder"
    }

    Write-Log (Get-Text "GeneratingProfiles")
    & $builder -GamePath $SelectedGamePath -ProjectRoot $ProjectRoot 2>&1 |
        ForEach-Object { Write-Log $_.ToString() }
}

function Ensure-RulesAvailable {
    param([string]$SelectedGamePath)

    $missing = @()
    foreach ($profile in $ArmyProfiles) {
        $rulesPath = Get-RulesProfilePath -Profile $profile
        if (-not (Test-Path -LiteralPath $rulesPath)) {
            $missing += $profile
        }
    }

    if ($missing.Count -eq 0) {
        return
    }

    $builder = Join-Path $PSScriptRoot "Build-Stronghold2GameRulesPatch.ps1"
    if (-not (Test-Path -LiteralPath $builder)) {
        throw "Experimental gameRules.dat profiles are missing and rules builder was not found: $builder"
    }

    Write-Log (Get-Text "GeneratingRules")
    & $builder -GamePath $SelectedGamePath -ProjectRoot $ProjectRoot 2>&1 |
        ForEach-Object { Write-Log $_.ToString() }
}

function Test-Stronghold2Path {
    param([string]$Path)
    if (-not $Path) {
        return $false
    }

    $exePath = Join-Path $Path "Stronghold2.exe"
    $castlesPath = Join-Path $Path "castles"
    return ((Test-Path -LiteralPath $exePath) -and (Test-Path -LiteralPath $castlesPath))
}

function Get-InstallComparison {
    param(
        [string]$SelectedGamePath,
        [string]$Profile
    )

    $profileCastles = Get-ProfileCastlesPath -Profile $Profile
    $gameCastles = Join-Path $SelectedGamePath "castles"
    if (-not (Test-Path -LiteralPath $profileCastles)) {
        throw "Missing profile castles: $profileCastles"
    }
    if (-not (Test-Path -LiteralPath $gameCastles)) {
        throw "Missing game castles: $gameCastles"
    }

    $profileFiles = Get-ChildItem -LiteralPath $profileCastles -Filter "*.aic" -File
    $sameAsProfile = 0
    $missing = 0
    $different = 0

    foreach ($file in $profileFiles) {
        $gameFile = Join-Path $gameCastles $file.Name
        if (-not (Test-Path -LiteralPath $gameFile)) {
            $missing++
            continue
        }

        $profileHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $gameHash = (Get-FileHash -LiteralPath $gameFile -Algorithm SHA256).Hash
        if ($profileHash -eq $gameHash) {
            $sameAsProfile++
        } else {
            $different++
        }
    }

    return [pscustomobject]@{
        Profile = $Profile
        FilesChecked = $profileFiles.Count
        SameAsProfile = $sameAsProfile
        Missing = $missing
        Different = $different
    }
}

function Get-RulesComparison {
    param(
        [string]$SelectedGamePath,
        [string]$Profile
    )

    $rulesPath = Get-RulesProfilePath -Profile $Profile
    $gameRulesPath = Join-Path $SelectedGamePath "gameRules.dat"
    if (-not (Test-Path -LiteralPath $rulesPath)) {
        throw "Missing generated gameRules.dat profile: $rulesPath"
    }
    if (-not (Test-Path -LiteralPath $gameRulesPath)) {
        throw "Missing gameRules.dat in game folder: $gameRulesPath"
    }

    $profileHash = (Get-FileHash -LiteralPath $rulesPath -Algorithm SHA256).Hash
    $gameHash = (Get-FileHash -LiteralPath $gameRulesPath -Algorithm SHA256).Hash
    return [pscustomobject]@{
        Profile = $Profile
        Matches = ($profileHash -eq $gameHash)
    }
}

if ($BundleAction -ne "None") {
    if (-not (Test-Stronghold2Path -Path $GamePath)) {
        throw "Stronghold 2 path is invalid: $GamePath"
    }
    if ($EnableRuntimeDll -and $PatchGameRules) {
        throw "The experimental DLL and legacy gameRules.dat patch cannot be enabled together."
    }
    if ($EnableRuntimeDll -and (-not $HasExperimentalDll)) {
        throw "The combined package is missing its experimental DLL launcher: $ExperimentalLauncherPath"
    }

    switch ($BundleAction) {
        "Install" {
            $installArguments = @{
                GamePath = $GamePath
                ProjectRoot = $ProjectRoot
                Profile = $Profile
                RulesProfile = $RuntimeDifficulty
                PatchGameRules = [bool]$PatchGameRules
            }
            & (Join-Path $PSScriptRoot "Install-Stronghold2AIOverhaul.ps1") @installArguments
            if ($EnableRuntimeDll) {
                $runtimeArguments = @{
                    GamePath = $GamePath
                    Difficulty = $RuntimeDifficulty
                    EnableAiAssistance = $true
                    EnableTunnelAssaults = [bool]$EnableTunnelAssaults
                    LoaderAction = "Install"
                }
                & $ExperimentalLauncherPath @runtimeArguments
            }
        }
        "Verify" {
            if (-not (Test-Path -LiteralPath (Get-ProfileCastlesPath -Profile $Profile))) {
                & (Join-Path $PSScriptRoot "Build-Stronghold2AIProfiles.ps1") -GamePath $GamePath -ProjectRoot $ProjectRoot
            }
            $comparison = Get-InstallComparison -SelectedGamePath $GamePath -Profile $Profile
            if (($comparison.FilesChecked -eq 0) -or ($comparison.SameAsProfile -ne $comparison.FilesChecked) -or
                ($comparison.Missing -ne 0) -or ($comparison.Different -ne 0)) {
                throw "Castle profile verification failed: $($comparison.SameAsProfile)/$($comparison.FilesChecked) match, missing=$($comparison.Missing), different=$($comparison.Different)."
            }
            Write-Host "Castle profile verification OK: $($comparison.SameAsProfile)/$($comparison.FilesChecked) files match."

            if ($PatchGameRules) {
                if (-not (Test-Path -LiteralPath (Get-RulesProfilePath -Profile $RuntimeDifficulty))) {
                    & (Join-Path $PSScriptRoot "Build-Stronghold2GameRulesPatch.ps1") -GamePath $GamePath -ProjectRoot $ProjectRoot
                }
                $rulesComparison = Get-RulesComparison -SelectedGamePath $GamePath -Profile $RuntimeDifficulty
                if (-not $rulesComparison.Matches) {
                    throw "Legacy gameRules.dat verification failed."
                }
                Write-Host "Legacy gameRules.dat verification OK."
            }

            $loaderMarker = Join-Path $GamePath "Stronghold2AIOverhaul.Experimental.loader.json"
            if ($EnableRuntimeDll -or (Test-Path -LiteralPath $loaderMarker)) {
                if (-not $HasExperimentalDll) {
                    throw "Experimental loader marker found, but the DLL launcher is missing."
                }
                & $ExperimentalLauncherPath -GamePath $GamePath -LoaderAction Check
            }
        }
        "Restore" {
            $loaderMarker = Join-Path $GamePath "Stronghold2AIOverhaul.Experimental.loader.json"
            if (Test-Path -LiteralPath $loaderMarker) {
                if (-not $HasExperimentalDll) {
                    throw "Experimental loader marker found, but the DLL launcher is missing."
                }
                & $ExperimentalLauncherPath -GamePath $GamePath -LoaderAction Restore
            }
            & (Join-Path $PSScriptRoot "Restore-Stronghold2AIOverhaul.ps1") -GamePath $GamePath -ProjectRoot $ProjectRoot
        }
    }
    return
}

if ($Check) {
    $builder = Join-Path $PSScriptRoot "Build-Stronghold2AIProfiles.ps1"
    if (-not (Test-Path -LiteralPath $builder)) {
        throw "Missing profile builder: $builder"
    }
    $rulesBuilder = Join-Path $PSScriptRoot "Build-Stronghold2GameRulesPatch.ps1"
    if (-not (Test-Path -LiteralPath $rulesBuilder)) {
        throw "Missing experimental rules builder: $rulesBuilder"
    }
    if ($HasExperimentalDll) {
        & $ExperimentalLauncherPath -Check
    }
    Write-Host "Launcher check OK. Castle profiles: $($CastleProfiles -join ', '). Army profiles: $($ArmyProfiles -join ', ')."
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function Add-RowStyle {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Panel,
        [System.Windows.Forms.SizeType]$SizeType,
        [float]$Value
    )
    [void]$Panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle -ArgumentList $SizeType, $Value))
}

function Add-ColumnStyle {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Panel,
        [System.Windows.Forms.SizeType]$SizeType,
        [float]$Value
    )
    [void]$Panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle -ArgumentList $SizeType, $Value))
}

function Set-ButtonStyle {
    param([System.Windows.Forms.Button]$Button)
    $Button.Height = 34
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::System
    $Button.Margin = New-Object System.Windows.Forms.Padding(4, 4, 10, 4)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = (Get-Text "FormTitle")
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(980, 720)
$form.MinimumSize = New-Object System.Drawing.Size(780, 650)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)

$rootPanel = New-Object System.Windows.Forms.TableLayoutPanel
$rootPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$rootPanel.ColumnCount = 1
$rootPanel.RowCount = 6
$rootPanel.Padding = New-Object System.Windows.Forms.Padding(18, 14, 18, 14)
Add-RowStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 54
Add-RowStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 74
Add-RowStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 128
Add-RowStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 84
Add-RowStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 134
Add-RowStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
Add-ColumnStyle -Panel $rootPanel -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
$form.Controls.Add($rootPanel)

$headerPanel = New-Object System.Windows.Forms.TableLayoutPanel
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerPanel.ColumnCount = 3
$headerPanel.RowCount = 1
$headerPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
Add-ColumnStyle -Panel $headerPanel -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
Add-ColumnStyle -Panel $headerPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 86
Add-ColumnStyle -Panel $headerPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 140
Add-RowStyle -Panel $headerPanel -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
$rootPanel.Controls.Add($headerPanel, 0, 0)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = (Get-Text "Title")
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$headerPanel.Controls.Add($titleLabel, 0, 0)

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Text = (Get-Text "Language")
$languageLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$languageLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$languageLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$headerPanel.Controls.Add($languageLabel, 1, 0)

$languageCombo = New-Object System.Windows.Forms.ComboBox
$languageCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$languageCombo.Dock = [System.Windows.Forms.DockStyle]::Fill
$languageCombo.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 8)
[void]$languageCombo.Items.AddRange([object[]]@("Deutsch", "English"))
$languageCombo.SelectedItem = "Deutsch"
$headerPanel.Controls.Add($languageCombo, 2, 0)

$pathPanel = New-Object System.Windows.Forms.TableLayoutPanel
$pathPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$pathPanel.ColumnCount = 2
$pathPanel.RowCount = 2
$pathPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
Add-ColumnStyle -Panel $pathPanel -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
Add-ColumnStyle -Panel $pathPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 128
Add-RowStyle -Panel $pathPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 24
Add-RowStyle -Panel $pathPanel -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 32
$rootPanel.Controls.Add($pathPanel, 0, 1)

$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = (Get-Text "GamePath")
$pathLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$pathLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$pathPanel.Controls.Add($pathLabel, 0, 0)
$pathPanel.SetColumnSpan($pathLabel, 2)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Text = $GamePath
$pathBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$pathBox.Margin = New-Object System.Windows.Forms.Padding(0, 4, 10, 4)
$pathPanel.Controls.Add($pathBox, 0, 1)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = (Get-Text "Browse")
$browseButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$browseButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 4)
Set-ButtonStyle -Button $browseButton
$pathPanel.Controls.Add($browseButton, 1, 1)

$profileGroup = New-Object System.Windows.Forms.GroupBox
$profileGroup.Text = (Get-Text "ProfileGroup")
$profileGroup.Dock = [System.Windows.Forms.DockStyle]::Fill
$profileGroup.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
$rootPanel.Controls.Add($profileGroup, 0, 2)

$profileLayout = New-Object System.Windows.Forms.TableLayoutPanel
$profileLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$profileLayout.ColumnCount = 3
$profileLayout.RowCount = 2
$profileLayout.Padding = New-Object System.Windows.Forms.Padding(12, 16, 12, 12)
Add-ColumnStyle -Panel $profileLayout -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 190
Add-ColumnStyle -Panel $profileLayout -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 190
Add-ColumnStyle -Panel $profileLayout -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
Add-RowStyle -Panel $profileLayout -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 26
Add-RowStyle -Panel $profileLayout -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
$profileGroup.Controls.Add($profileLayout)

$profileLabel = New-Object System.Windows.Forms.Label
$profileLabel.Text = (Get-Text "Profile")
$profileLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$profileLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$profileLayout.Controls.Add($profileLabel, 0, 0)

$profileCombo = New-Object System.Windows.Forms.ComboBox
$profileCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$profileCombo.Dock = [System.Windows.Forms.DockStyle]::Top
$profileCombo.Margin = New-Object System.Windows.Forms.Padding(0, 2, 28, 0)
[void]$profileCombo.Items.AddRange($CastleProfiles)
$profileCombo.SelectedItem = $Profile
$profileLayout.Controls.Add($profileCombo, 0, 1)

$descriptionLabel = New-Object System.Windows.Forms.Label
$descriptionLabel.Text = (Get-Text "ProfileDescription")
$descriptionLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$descriptionLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$armyProfileLabel = New-Object System.Windows.Forms.Label
$armyProfileLabel.Text = (Get-Text "ArmyProfile")
$armyProfileLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$armyProfileLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$profileLayout.Controls.Add($armyProfileLabel, 1, 0)

$armyProfileCombo = New-Object System.Windows.Forms.ComboBox
$armyProfileCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$armyProfileCombo.Dock = [System.Windows.Forms.DockStyle]::Top
$armyProfileCombo.Margin = New-Object System.Windows.Forms.Padding(0, 2, 28, 0)
[void]$armyProfileCombo.Items.AddRange($ArmyProfiles)
$armyProfileCombo.SelectedItem = $RuntimeDifficulty
$armyProfileCombo.Enabled = $false
$profileLayout.Controls.Add($armyProfileCombo, 1, 1)

$profileLayout.Controls.Add($descriptionLabel, 2, 0)

$descriptionBox = New-Object System.Windows.Forms.Label
$descriptionBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$descriptionBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$descriptionBox.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$descriptionBox.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$profileLayout.Controls.Add($descriptionBox, 2, 1)

$actionsGroup = New-Object System.Windows.Forms.GroupBox
$actionsGroup.Text = (Get-Text "Actions")
$actionsGroup.Dock = [System.Windows.Forms.DockStyle]::Fill
$actionsGroup.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
$rootPanel.Controls.Add($actionsGroup, 0, 3)

$actionsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$actionsFlow.Dock = [System.Windows.Forms.DockStyle]::Fill
$actionsFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$actionsFlow.WrapContents = $true
$actionsFlow.AutoScroll = $true
$actionsFlow.Padding = New-Object System.Windows.Forms.Padding(10, 18, 10, 8)
$actionsGroup.Controls.Add($actionsFlow)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = (Get-Text "Install")
$installButton.Size = New-Object System.Drawing.Size(145, 34)
Set-ButtonStyle -Button $installButton
$actionsFlow.Controls.Add($installButton)

$verifyButton = New-Object System.Windows.Forms.Button
$verifyButton.Text = (Get-Text "Verify")
$verifyButton.Size = New-Object System.Drawing.Size(125, 34)
Set-ButtonStyle -Button $verifyButton
$actionsFlow.Controls.Add($verifyButton)

$restoreButton = New-Object System.Windows.Forms.Button
$restoreButton.Text = (Get-Text "Restore")
$restoreButton.Size = New-Object System.Drawing.Size(175, 34)
Set-ButtonStyle -Button $restoreButton
$actionsFlow.Controls.Add($restoreButton)

$launchButton = New-Object System.Windows.Forms.Button
$launchButton.Text = (Get-Text "Launch")
$launchButton.Size = New-Object System.Drawing.Size(130, 34)
Set-ButtonStyle -Button $launchButton
$actionsFlow.Controls.Add($launchButton)

$openFolderButton = New-Object System.Windows.Forms.Button
$openFolderButton.Text = (Get-Text "OpenFolder")
$openFolderButton.Size = New-Object System.Drawing.Size(145, 34)
Set-ButtonStyle -Button $openFolderButton
$actionsFlow.Controls.Add($openFolderButton)

$rulesGroup = New-Object System.Windows.Forms.GroupBox
$rulesGroup.Text = (Get-Text "OptionalFeature")
$rulesGroup.Dock = [System.Windows.Forms.DockStyle]::Fill
$rulesGroup.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
$rootPanel.Controls.Add($rulesGroup, 0, 4)

$rulesLayout = New-Object System.Windows.Forms.TableLayoutPanel
$rulesLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$rulesLayout.ColumnCount = 1
$rulesLayout.RowCount = 3
$rulesLayout.Padding = New-Object System.Windows.Forms.Padding(12, 18, 12, 10)
Add-ColumnStyle -Panel $rulesLayout -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
Add-RowStyle -Panel $rulesLayout -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 28
Add-RowStyle -Panel $rulesLayout -SizeType ([System.Windows.Forms.SizeType]::Absolute) -Value 28
Add-RowStyle -Panel $rulesLayout -SizeType ([System.Windows.Forms.SizeType]::Percent) -Value 100
$rulesGroup.Controls.Add($rulesLayout)

$rulesCheckBox = New-Object System.Windows.Forms.CheckBox
$rulesCheckBox.Text = (Get-Text "RulesCheckbox")
$rulesCheckBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$rulesCheckBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)
$rulesCheckBox.Checked = $false
$rulesCheckBox.Visible = -not $HasExperimentalDll
$rulesLayout.Controls.Add($rulesCheckBox, 0, 0)

$runtimeCheckBox = New-Object System.Windows.Forms.CheckBox
$runtimeCheckBox.Text = (Get-Text "RuntimeCheckbox")
$runtimeCheckBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$runtimeCheckBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)
$runtimeCheckBox.Checked = $false
$runtimeCheckBox.Visible = $HasExperimentalDll
$rulesLayout.Controls.Add($runtimeCheckBox, 0, 0)

$tunnelCheckBox = New-Object System.Windows.Forms.CheckBox
$tunnelCheckBox.Text = (Get-Text "TunnelCheckbox")
$tunnelCheckBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$tunnelCheckBox.Margin = New-Object System.Windows.Forms.Padding(18, 0, 0, 4)
$tunnelCheckBox.Checked = $false
$tunnelCheckBox.Enabled = $false
$tunnelCheckBox.Visible = $HasExperimentalDll
$rulesLayout.Controls.Add($tunnelCheckBox, 0, 1)

$rulesHintLabel = New-Object System.Windows.Forms.Label
$rulesHintLabel.Text = if ($HasExperimentalDll) { Get-Text "RuntimeHint" } else { Get-Text "RulesHint" }
$rulesHintLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$rulesHintLabel.AutoEllipsis = $true
$rulesLayout.Controls.Add($rulesHintLabel, 0, 2)

$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = (Get-Text "Log")
$logGroup.Dock = [System.Windows.Forms.DockStyle]::Fill
$logGroup.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
$rootPanel.Controls.Add($logGroup, 0, 5)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$logBox.Margin = New-Object System.Windows.Forms.Padding(12, 18, 12, 12)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logGroup.Controls.Add($logBox)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$timestamp] $Message`r`n")
}

function Update-Description {
    $castleDescription = ""
    switch ($profileCombo.SelectedItem) {
        "Balanced" {
            $castleDescription = (Get-Text "BalancedDescription")
        }
        "Hard" {
            $castleDescription = (Get-Text "HardDescription")
        }
        "Brutal" {
            $castleDescription = (Get-Text "BrutalDescription")
        }
        "Overlord" {
            $castleDescription = (Get-Text "OverlordDescription")
        }
    }
    $armyDescriptionKey = if ($HasExperimentalDll) {
        "Runtime{0}Description" -f [string]$armyProfileCombo.SelectedItem
    } else {
        "Army{0}Description" -f [string]$armyProfileCombo.SelectedItem
    }
    $armyDescription = Get-Text $armyDescriptionKey
    $descriptionBox.Text = $castleDescription + [Environment]::NewLine + $armyDescription
}

function Apply-Language {
    $form.Text = (Get-Text "FormTitle")
    $titleLabel.Text = (Get-Text "Title")
    $languageLabel.Text = (Get-Text "Language")
    $pathLabel.Text = (Get-Text "GamePath")
    $browseButton.Text = (Get-Text "Browse")
    $profileGroup.Text = (Get-Text "ProfileGroup")
    $profileLabel.Text = (Get-Text "Profile")
    $armyProfileLabel.Text = if ($HasExperimentalDll) { Get-Text "RuntimeProfile" } else { Get-Text "ArmyProfile" }
    $descriptionLabel.Text = (Get-Text "ProfileDescription")
    $actionsGroup.Text = (Get-Text "Actions")
    $installButton.Text = if ($HasExperimentalDll) { Get-Text "InstallComplete" } else { Get-Text "Install" }
    $verifyButton.Text = if ($HasExperimentalDll) { Get-Text "VerifyComplete" } else { Get-Text "Verify" }
    $restoreButton.Text = if ($HasExperimentalDll) { Get-Text "RestoreComplete" } else { Get-Text "Restore" }
    $launchButton.Text = (Get-Text "Launch")
    $openFolderButton.Text = (Get-Text "OpenFolder")
    $rulesGroup.Text = if ($HasExperimentalDll) { Get-Text "RuntimeFeature" } else { Get-Text "OptionalFeature" }
    $rulesCheckBox.Text = (Get-Text "RulesCheckbox")
    $runtimeCheckBox.Text = (Get-Text "RuntimeCheckbox")
    $tunnelCheckBox.Text = (Get-Text "TunnelCheckbox")
    $rulesHintLabel.Text = if ($HasExperimentalDll) { Get-Text "RuntimeHint" } else { Get-Text "RulesHint" }
    $logGroup.Text = (Get-Text "Log")
    Update-Description
}

$profileCombo.Add_SelectedIndexChanged({ Update-Description })
$armyProfileCombo.Add_SelectedIndexChanged({ Update-Description })
$rulesCheckBox.Add_CheckedChanged({
    $armyProfileCombo.Enabled = [bool]$rulesCheckBox.Checked
})
$runtimeCheckBox.Add_CheckedChanged({
    $armyProfileCombo.Enabled = [bool]$runtimeCheckBox.Checked
    $tunnelCheckBox.Enabled = [bool]$runtimeCheckBox.Checked
    if (-not $runtimeCheckBox.Checked) {
        $tunnelCheckBox.Checked = $false
    }
})

$languageCombo.Add_SelectedIndexChanged({
    if ($languageCombo.SelectedItem -eq "English") {
        $Script:Language = "en"
    } else {
        $Script:Language = "de"
    }
    Apply-Language
})

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = (Get-Text "BrowseDialog")
    if (Test-Path -LiteralPath $pathBox.Text) {
        $dialog.SelectedPath = $pathBox.Text
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.SelectedPath
    }
})

$installButton.Add_Click({
    try {
        $selectedPath = $pathBox.Text.Trim()
        $profile = [string]$profileCombo.SelectedItem
        $rulesProfile = [string]$armyProfileCombo.SelectedItem
        if (-not (Test-Stronghold2Path -Path $selectedPath)) {
            throw "$(Get-Text "InvalidPath"): $selectedPath"
        }

        Ensure-ProfilesAvailable -SelectedGamePath $selectedPath
        $patchRules = (-not $HasExperimentalDll) -and [bool]$rulesCheckBox.Checked
        if ($patchRules) {
            Ensure-RulesAvailable -SelectedGamePath $selectedPath
            Write-Log (Get-Text "RulesEnabled")
        }
        Write-Log "$(Get-Text "Installing") '$profile'..."
        $installArguments = @{
            GamePath = $selectedPath
            ProjectRoot = $ProjectRoot
            Profile = $profile
            RulesProfile = $rulesProfile
            PatchGameRules = $patchRules
        }
        & (Join-Path $PSScriptRoot "Install-Stronghold2AIOverhaul.ps1") @installArguments 2>&1 |
            ForEach-Object { Write-Log $_.ToString() }
        Write-Log (Get-Text "InstallDone")

        if ($HasExperimentalDll -and $runtimeCheckBox.Checked) {
            $runtimeArguments = @{
                GamePath = $selectedPath
                Difficulty = $rulesProfile
                EnableAiAssistance = $true
                EnableTunnelAssaults = [bool]$tunnelCheckBox.Checked
                LoaderAction = "Install"
            }
            & $ExperimentalLauncherPath @runtimeArguments 2>&1 |
                ForEach-Object { Write-Log $_.ToString() }
            Write-Log (Get-Text "RuntimeInstallDone")
        }
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
})

$verifyButton.Add_Click({
    try {
        $selectedPath = $pathBox.Text.Trim()
        $profile = [string]$profileCombo.SelectedItem
        $rulesProfile = [string]$armyProfileCombo.SelectedItem
        if (-not (Test-Stronghold2Path -Path $selectedPath)) {
            throw "$(Get-Text "InvalidPath"): $selectedPath"
        }

        Ensure-ProfilesAvailable -SelectedGamePath $selectedPath
        $result = Get-InstallComparison -SelectedGamePath $selectedPath -Profile $profile
        Write-Log "Profile '$profile': $($result.SameAsProfile)/$($result.FilesChecked) $(Get-Text "CheckResult"). $(Get-Text "Missing")=$($result.Missing), $(Get-Text "Different")=$($result.Different)."
        if ((-not $HasExperimentalDll) -and $rulesCheckBox.Checked) {
            Ensure-RulesAvailable -SelectedGamePath $selectedPath
            $rulesResult = Get-RulesComparison -SelectedGamePath $selectedPath -Profile $rulesProfile
            if ($rulesResult.Matches) {
                Write-Log (Get-Text "RulesMatch")
            } else {
                Write-Log (Get-Text "RulesDifferent")
            }
        }
        if ($HasExperimentalDll) {
            $loaderMarker = Join-Path $selectedPath "Stronghold2AIOverhaul.Experimental.loader.json"
            if ($runtimeCheckBox.Checked -or (Test-Path -LiteralPath $loaderMarker)) {
                & $ExperimentalLauncherPath -GamePath $selectedPath -LoaderAction Check 2>&1 |
                    ForEach-Object { Write-Log $_.ToString() }
                Write-Log (Get-Text "RuntimeCheckDone")
            }
        }
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
})

$restoreButton.Add_Click({
    try {
        $selectedPath = $pathBox.Text.Trim()
        if (-not (Test-Stronghold2Path -Path $selectedPath)) {
            throw "$(Get-Text "InvalidPath"): $selectedPath"
        }

        Write-Log (Get-Text "Restoring")
        $loaderMarker = Join-Path $selectedPath "Stronghold2AIOverhaul.Experimental.loader.json"
        if ($HasExperimentalDll -and (Test-Path -LiteralPath $loaderMarker)) {
            & $ExperimentalLauncherPath -GamePath $selectedPath -LoaderAction Restore 2>&1 |
                ForEach-Object { Write-Log $_.ToString() }
            Write-Log (Get-Text "RuntimeRestoreDone")
        }
        & (Join-Path $PSScriptRoot "Restore-Stronghold2AIOverhaul.ps1") `
            -GamePath $selectedPath `
            -ProjectRoot $ProjectRoot 2>&1 | ForEach-Object { Write-Log $_.ToString() }
        Write-Log (Get-Text "RestoreDone")
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
})

$launchButton.Add_Click({
    try {
        $selectedPath = $pathBox.Text.Trim()
        if (-not (Test-Stronghold2Path -Path $selectedPath)) {
            throw "$(Get-Text "InvalidPath"): $selectedPath"
        }

        Start-Process -FilePath "steam://rungameid/40960"
        Write-Log (Get-Text "Started")
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
})

$openFolderButton.Add_Click({
    Start-Process -FilePath "explorer.exe" -ArgumentList $ProjectRoot
})

Apply-Language
Write-Log (Get-Text "Ready")
if ($UiCheck) {
    Write-Host "Launcher UI check OK."
    $form.Dispose()
    return
}
[void]$form.ShowDialog()
