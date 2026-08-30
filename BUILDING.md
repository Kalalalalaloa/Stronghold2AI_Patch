# Build and verification instructions

This repository contains the complete readable source shipped in
`Stronghold2AIOverhaul-v4.5-StrategicBuildOrder-PublicSafe.zip` on Nexus Mods.
The release is a PowerShell/Python script package, not a precompiled application.
There are no bundled executables, DLLs, game data files, third-party libraries, or
download steps.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 or newer
- Stronghold 2: Steam Edition installed locally
- Python 3 only for the optional developer-side Python parity builder and analysis
  tool; both Python files use only the standard library

No Visual Studio build, package manager, SDK, or network access is required.

## 1. Obtain the source

```powershell
git clone https://github.com/Kalalalalaloa/Stronghold2AI_Patch.git
Set-Location .\Stronghold2AI_Patch
```

The nine executable source files listed in `SOURCE_MANIFEST.sha256` are
byte-for-byte identical to the submitted Nexus ZIP. The exact original twelve-file
snapshot is preserved at tag `nexus-v4.5` and recorded in
`NEXUS_PACKAGE_MANIFEST.sha256`. The ZIP itself has SHA256:

```text
094FD7930E3F26252B6CF336AD198A609F4E632AED81D1FF33F19B8E52D7C282
```

## 2. Generate the castle profiles

Replace the example path with the reviewer's Stronghold 2 installation path:

```powershell
$gamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Stronghold 2'
.\tools\Build-Stronghold2AIProfiles.ps1 -GamePath $gamePath
```

This reads the installed `.aic` castle templates and creates four generated
profiles under `modded\profiles`: `Balanced`, `Hard`, `Brutal`, and `Overlord`.
The public repository deliberately does not redistribute Firefly Studios' original
`.aic` files.

## 3. Generate the optional Lord-rules profiles

```powershell
.\tools\Build-Stronghold2GameRulesPatch.ps1 -GamePath $gamePath
```

This requires the supported clean Steam Edition `gameRules.dat`. The script checks
the source hash and refuses an unknown or already modified file by default. Output
is written under `modded\rules`; the original game file is not changed by this
build step.

## 4. Validate the generated output

```powershell
.\tools\Validate-Stronghold2AIOverhaul.ps1 -GamePath $gamePath
```

The validator checks all generated castle manifests and the decompressed
Lord-rules structures. A successful run prints a validation message for every
profile.

## Optional independent Python builder

For developer parity testing, first place locally owned vanilla inputs under
`source\vanilla`, then run:

```powershell
python .\tools\build_ai_overhaul.py
python .\tools\analyze_game_rules.py `
  "$gamePath\gameRules.dat" `
  --output-dir ".\analysis\game_rules"
```

The Python tools use only Python's standard library. They are not required to use
the release launcher.

## Run without installing

The UI can be constructed and closed without displaying it or changing the game:

```powershell
.\tools\Start-Stronghold2AIOverhaul.ps1 -GamePath $gamePath -UiCheck
```

For normal interactive use, run `Launcher.cmd`. Merely opening the launcher does
not install files. Installation happens only after the user selects the install
action. The installer creates a timestamped backup before copying generated files
into the game directory. Restore is available through the launcher or
`Restore-Stronghold2AIOverhaul.ps1`.

## Package layout

The submitted Nexus ZIP places the release files below one folder named
`Stronghold2AIOverhaul-v4.5-StrategicBuildOrder-PublicSafe`. No compilation or
binary embedding is performed. `NEXUS_REVIEW.md` describes the security-relevant
behavior and maps every release component to its source.
