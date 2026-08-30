# Stronghold 2 AI Overhaul - Profile Launcher

This project builds a reversible Stronghold 2 Steam Edition AI castle-pack with selectable difficulty profiles.

## What this mod changes

- Keeps the Steam installation untouched during build.
- Copies vanilla `.aic` castle templates into `source/vanilla/castles`.
- Builds patched templates in `modded/profiles/<profile>/castles`.
- Can optionally generate experimental `gameRules.dat` profiles in `modded/rules/<profile>` for verified troop upgrades and direct siege support.
- Adds a PowerShell launcher UI for installing, checking, restoring, and launching the game.
- Launcher UI supports Deutsch/English and uses a resizable layout for different screen sizes and DPI settings.
- Public-safe releases can generate profiles locally from the user's own Stronghold 2 install and do not need bundled `.aic` files.
- Adds four castle profiles:
  - `Balanced`: moderate priority changes and fewer substitutions. Best first test if AI economy stalls.
  - `Hard`: stronger same-lord and same-material castle progression.
  - `Brutal`: aggressive priorities plus larger stone and wooden infrastructure.
  - `Overlord`: maximum infrastructure using medium/large templates for open AI estates only.
- Lowers build-priority values in non-campaign/non-test AIC templates so defenses and later castle parts are placed earlier.
- v4.5 additionally advances verified economy chains, weapon workshops, barracks, engineer guilds, siege camps, and stables by difficulty so larger runtime armies have infrastructure to support them.
- Replaces weak alternate lord castles with stronger variants from the same lord family. Hard, Brutal, and Overlord use:
  - `Barclay02.aic` and `Barclay03.aic` use `Barclay01.aic`.
  - `edwin01.aic` and `edwin02.aic` use `edwin03.aic`.
  - `hawk02.aic` uses `hawk01.aic`.
  - `king02.aic` uses `king01.aic`.
  - `William01.aic` uses `William02.aic`.

Balanced only replaces `edwin01.aic`, `edwin02.aic`, `hawk02.aic`, and `king02.aic`.
Hard also promotes the weakest generic stone/wood templates within the same material. Brutal promotes tiny and small layouts further; Overlord uses medium/large stone and wooden templates. These substitutions preserve construction material but require large, open AI estates.

## Map compatibility notes

This mod works best on maps where the AI has enough buildable space around the keep.

On maps with very small or awkward AI estates, Stronghold 2 may fail to place the stronger castle templates correctly. Known symptoms include:

- wooden/raider-style lords building only a small wall or moat around the keep;
- fewer defending troops than expected;
- tower doors or access points facing away from the protected courtyard;
- unfinished, cramped, or visually illogical castle layouts.

For cramped maps, start with `Balanced`. Use `Hard`, `Brutal`, and the experimental `gameRules.dat` checkbox mainly on maps with enough AI build space.

## Experimental gameRules.dat patch

Version 4.5 separates castle construction from army pressure. You can select a compact `Balanced` castle profile for a cramped map and independently select `Hard`, `Brutal`, or `Overlord` army pressure.

When enabled, the launcher generates a patched `gameRules.dat` locally from the user's own installed game file. Ghidra analysis proved that the relevant `LordsRules` block contains four attack-unit actor fields, four selection weights, a ladderman count, and direct siege-engine counts. Version 4.2 corrects the older staged-slot interpretation and patches only fields with confirmed code consumers:

- `Balanced`: byte-identical vanilla rules, used as a control profile.
- `Hard`: upgrades weak standard roles toward crossbowmen, pikemen, macemen, and swordsmen; guarantees moderate ladder and siege support.
- `Brutal`: upgrades weak elite roles to knights and requests at least 18 laddermen, 4 catapults, 2 trebuchets, 2 fire ballistas, 2 rams, siege towers, 2 protected Cats, a burning cart, and 4 mantlets per attack.
- `Overlord`: strongest verified troop upgrades and the largest direct ladder/siege support request.

The patched actor ids and field offsets are statically verified against `Stronghold2.exe`. Gameplay balance, affordability, and whether every lord can satisfy the larger siege request still need in-game feedback, so the option remains disabled by default.

The rules generator expects a clean vanilla Stronghold 2 Steam Edition `gameRules.dat`. If an older experimental rules profile is already installed, restore the mod backup or use Steam's file verification before generating/installing a newer experimental rules profile.

Vanilla minimum attack size, random extra size, and all four selection weights remain unchanged in the public-safe rules patch. Dynamic Early/Mid/Late army sizes, lord-specific siege strategies, AI bonus gold, and optional tunnel assaults are available only in the separate experimental DLL v0.8 package.

## What this mod does not change

- It does not patch `Stronghold2.exe`, DLLs, memory, saves, or Steam files during build.
- It does not modify `gameRules.dat` unless the experimental launcher checkbox or installer switch is explicitly enabled.
- It cannot add true dynamic weak-point detection to the AI, because that behavior is not exposed in the AIC templates.
- It does not add a real in-game menu. The launcher is an external UI because Stronghold 2 menu behavior is not exposed through editable menu scripts.

## Launcher

For normal use, run:

```powershell
.\Launcher.cmd
```

The launcher can:

- generate missing profiles from the selected local Stronghold 2 install;
- generate optional experimental Lord army/unit-roster `gameRules.dat` profiles from the selected local Stronghold 2 install;
- switch UI language between Deutsch and English;
- select `Balanced`, `Hard`, `Brutal`, or `Overlord` independently for castle construction and experimental army pressure;
- install the selected profile;
- optionally install the matching experimental `gameRules.dat` Lord army/unit-roster profile;
- check whether the selected profile is currently installed;
- restore the oldest backup;
- start Stronghold 2.

The start button uses Steam App ID `40960` so Steam presence, overlay, and F12 screenshots can initialize normally. The CMD starter applies `ExecutionPolicy Bypass` only to its own PowerShell process; it does not change the user's permanent Windows policy.

For Stronghold 2 Online AI Enabler compatibility, use this launcher only to install the selected files, close it, and then start the game through the Online AI Enabler. Do not combine another D3D9 loader with the separate optional Experimental DLL package unless that loader explicitly supports proxy chaining.

## Build and Validate

Run from this directory:

```powershell
& 'C:\Users\Skral\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' .\tools\build_ai_overhaul.py
.\tools\Build-Stronghold2GameRulesPatch.ps1 -GamePath 'F:\SteamLibrary\steamapps\common\Stronghold 2'
.\tools\Validate-Stronghold2AIOverhaul.ps1
```

## Install

Installing writes to the Stronghold 2 Steam installation and creates a backup first:

```powershell
.\tools\Install-Stronghold2AIOverhaul.ps1 -GamePath 'F:\SteamLibrary\steamapps\common\Stronghold 2'
```

Install a specific profile:

```powershell
.\tools\Install-Stronghold2AIOverhaul.ps1 -GamePath 'F:\SteamLibrary\steamapps\common\Stronghold 2' -Profile Brutal
```

Install a specific profile with the experimental `gameRules.dat` patch:

```powershell
.\tools\Install-Stronghold2AIOverhaul.ps1 -GamePath 'F:\SteamLibrary\steamapps\common\Stronghold 2' -Profile Brutal -PatchGameRules
```

If the exact same AIC pack is already installed, the installer exits without changing files or creating another backup.

## Restore

Restore the first backup, which should be the original vanilla state before the first install:

```powershell
.\tools\Restore-Stronghold2AIOverhaul.ps1 -GamePath 'F:\SteamLibrary\steamapps\common\Stronghold 2'
```

Restore a specific backup:

```powershell
.\tools\Restore-Stronghold2AIOverhaul.ps1 -GamePath 'F:\SteamLibrary\steamapps\common\Stronghold 2' -BackupPath 'F:\CodeX\EldenRing\Stronghold2AIMod\backups\20260730-232751'
```

By default, the installer only overwrites `.aic` files in the game's `castles` directory and leaves `gameRules.dat` alone. With `-PatchGameRules`, it backs up and overwrites `gameRules.dat` too.
