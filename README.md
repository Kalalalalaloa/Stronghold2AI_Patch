# Stronghold 2 AI Overhaul v4.5 - Strategic Build Order

This repository contains the complete source code for the v4.5 PublicSafe release
submitted to Nexus Mods. The release consists of readable PowerShell, Python, and
CMD files; it contains no compiled application or redistributed Stronghold 2 game
files.

## Review information

- [Detailed build and validation instructions](BUILDING.md)
- [Security review notes and source map](NEXUS_REVIEW.md)
- [Manual test plan](TEST_PLAN_v4.5.md)
- Submitted ZIP SHA256:
  `094FD7930E3F26252B6CF336AD198A609F4E632AED81D1FF33F19B8E52D7C282`
- Exact submitted snapshot: Git tag `nexus-v4.5`, commit `4b84a43`

The executable source files on `main` are byte-for-byte identical to the submitted
ZIP. Public-facing documentation was shortened after submission; the original
twelve-file snapshot remains available through the tag above.

## Overview

The mod reads castle templates from the user's own Stronghold 2: Steam Edition
installation and generates four selectable profiles:

- `Balanced`: conservative priority and castle substitutions.
- `Hard`: faster construction and stronger compatible layouts.
- `Brutal`: aggressive construction and larger compatible layouts.
- `Overlord`: maximum construction pressure for large, open AI estates.

Version 4.5 adds building-aware priorities for economy, housing, weapon production,
and military infrastructure. An optional rules generator can create matching
`gameRules.dat` profiles from a supported clean local game file. This option is
disabled by default.

The launcher provides profile generation, validation, installation, status checks,
backup restoration, and optional Steam startup in English and German.

## Source layout

| Path | Purpose |
|---|---|
| `Launcher.cmd` | Double-click entry point for the PowerShell launcher. |
| `tools/Start-Stronghold2AIOverhaul.ps1` | Launcher UI and action orchestration. |
| `tools/Build-Stronghold2AIProfiles.ps1` | Generates the four castle profiles. |
| `tools/Build-Stronghold2GameRulesPatch.ps1` | Generates optional rules profiles. |
| `tools/Install-Stronghold2AIOverhaul.ps1` | Installs a selected generated profile with backup. |
| `tools/Restore-Stronghold2AIOverhaul.ps1` | Restores previously backed-up files. |
| `tools/Validate-Stronghold2AIOverhaul.ps1` | Validates generated profiles and manifests. |
| `tools/build_ai_overhaul.py` | Independent Python profile builder used for parity testing. |
| `tools/analyze_game_rules.py` | Read-only structure analysis utility. |

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 or newer
- Stronghold 2: Steam Edition
- Python 3 only for the optional Python utilities; no third-party packages

## Generate and validate

Run from the repository root and replace the example with the local game path:

```powershell
$gamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Stronghold 2'
.\tools\Build-Stronghold2AIProfiles.ps1 -GamePath $gamePath
.\tools\Build-Stronghold2GameRulesPatch.ps1 -GamePath $gamePath
.\tools\Validate-Stronghold2AIOverhaul.ps1 -GamePath $gamePath
```

The generated files are written under `modded\profiles` and `modded\rules` inside
the repository. See [BUILDING.md](BUILDING.md) for the complete review procedure.

## Run, install, and restore

Start the UI with:

```powershell
.\Launcher.cmd
```

Opening the launcher does not install anything. Installation occurs only after an
explicit install action and creates a timestamped backup before replacing selected
castle or rules files. The launcher and `Restore-Stronghold2AIOverhaul.ps1` can
restore that backup.
