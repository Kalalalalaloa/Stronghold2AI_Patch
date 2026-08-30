# Nexus Mods security review notes

## Submitted file

- File: `Stronghold2AIOverhaul-v4.5-StrategicBuildOrder-PublicSafe.zip`
- Version: 4.5, Strategic Build Order, PublicSafe
- Size: 35,556 bytes
- SHA256: `094FD7930E3F26252B6CF336AD198A609F4E632AED81D1FF33F19B8E52D7C282`
- ZIP contents: 12 readable source/documentation files
- Bundled EXE, DLL, AIC, DAT, PDB, or other binary game files: none

The twelve release files are committed here without source changes. Their hashes
are recorded in `SOURCE_MANIFEST.sha256`. `BUILDING.md` gives the clean-checkout
generation and validation procedure.

## Source map

| Release component | Purpose |
|---|---|
| `Launcher.cmd` | Starts the PowerShell UI with a process-local execution-policy bypass. It does not alter the system PowerShell policy. |
| `tools/Start-Stronghold2AIOverhaul.ps1` | Windows Forms UI and orchestration for build, validation, install, restore, and optional Steam launch. |
| `tools/Build-Stronghold2AIProfiles.ps1` | Reads locally installed castle templates and generates four modified profile sets. |
| `tools/Build-Stronghold2GameRulesPatch.ps1` | Generates optional Lord-rules profiles from a supported clean local `gameRules.dat`. |
| `tools/Install-Stronghold2AIOverhaul.ps1` | Installs a selected generated profile after creating a timestamped backup. |
| `tools/Restore-Stronghold2AIOverhaul.ps1` | Restores backed-up castle/rules files. |
| `tools/Validate-Stronghold2AIOverhaul.ps1` | Validates generated AIC structures, manifests, and rules output. |
| `tools/build_ai_overhaul.py` | Independent standard-library Python castle-profile builder used for parity checks. |
| `tools/analyze_game_rules.py` | Read-only standard-library Python analysis/export tool for `gameRules.dat`. |

The remaining three files are the user README, patch notes, and manual test plan.

## Security-relevant behavior

- No network requests, downloaders, telemetry, account access, registry edits,
  services, scheduled tasks, drivers, injection, process-memory access, or
  executable patching are present.
- Build operations write generated data only below the selected project root.
- Game-directory writes occur only through an explicit install action.
- Before replacing castle templates or the optional rules file, the installer
  creates a timestamped backup below the project directory.
- The optional game launch action opens Steam URI `steam://rungameid/40960`.
- The launcher can open the project directory in Windows Explorer.
- The release includes no experimental DLL/proxy-loader code; that is a separate,
  later development track and is not part of the submitted v4.5 PublicSafe ZIP.

## Redistributed game content

None. Original Stronghold 2 `.aic` and `gameRules.dat` files are read from the
reviewer's/user's own local installation and are not committed or bundled. All
generated outputs are excluded from this source repository.
