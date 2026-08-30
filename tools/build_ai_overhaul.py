from __future__ import annotations

import hashlib
import json
import shutil
import struct
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable


PROJECT_ROOT = Path(__file__).resolve().parents[1]
VANILLA_CASTLES = PROJECT_ROOT / "source" / "vanilla" / "castles"
MODDED_ROOT = PROJECT_ROOT / "modded"
PROFILE_ROOT = MODDED_ROOT / "profiles"
LEGACY_HARD_CASTLES = MODDED_ROOT / "castles"
AGGREGATE_MANIFEST_PATH = MODDED_ROOT / "manifest.json"

EXCLUDED_PREFIXES = ("aivchap", "test")

ECONOMY_BUILDINGS = {
    0x02,  # saw pit
    0x03,  # wheat farm
    0x04,  # stone quarry
    0x05,  # mill
    0x06,  # bakery
    0x07,  # granary
    0x0F,  # iron mine
    0x11,  # ox tether
    0x12,  # hovel
    0x27,  # pig farm
    0x29,  # dairy farm
    0x2A,  # apple farm
    0x2B,  # hunter's post
    0x40,  # market
    0x53,  # carter post
}

WEAPON_BUILDINGS = {
    0x08,  # fletcher
    0x09,  # poleturner
    0x0A,  # armoury
    0x0E,  # blacksmith
    0x30,  # smelter
    0x4A,  # armourer
    0x4B,  # weaver
    0x4D,  # tanner
}

MILITARY_BUILDINGS = {
    0x18,  # barracks
    0x41,  # mercenary post
    0x44,  # engineers' guild
    0x46,  # siege camp
    0x51,  # stables
}

INFRASTRUCTURE_FACTORS = {
    "balanced": (1.00, 1.00, 1.00),
    "hard": (0.90, 0.94, 0.96),
    "brutal": (0.78, 0.84, 0.88),
    "overlord": (0.65, 0.72, 0.78),
}

BALANCED_SUBSTITUTIONS = {
    "edwin01.aic": "edwin03.aic",
    "edwin02.aic": "edwin03.aic",
    "hawk02.aic": "hawk01.aic",
    "king02.aic": "king01.aic",
}

HARD_SUBSTITUTIONS = {
    "Barclay02.aic": "Barclay01.aic",
    "Barclay03.aic": "Barclay01.aic",
    "edwin01.aic": "edwin03.aic",
    "edwin02.aic": "edwin03.aic",
    "hawk02.aic": "hawk01.aic",
    "king02.aic": "king01.aic",
    "William01.aic": "William02.aic",
    "Tiny_Stone.aic": "Tiny_Stone3.aic",
    "Tiny_Stone2.aic": "Tiny_Stone3.aic",
    "Tiny_Wooden.aic": "Small_Wooden.aic",
}

BRUTAL_SUBSTITUTIONS = {
    **HARD_SUBSTITUTIONS,
    "Tiny_Stone.aic": "Small_Stone4.aic",
    "Tiny_Stone2.aic": "Small_Stone4.aic",
    "Tiny_Stone3.aic": "Small_Stone4.aic",
    "Tiny_Stone4.aic": "Small_Stone4.aic",
    "Small_Stone.aic": "Small_Stone4.aic",
    "Small_Stone2.aic": "Small_Stone4.aic",
    "Small_Stone3.aic": "Small_Stone4.aic",
    "Tiny_Wooden.aic": "Med_Wooden.aic",
    "Small_Wooden.aic": "Med_Wooden.aic",
}

OVERLORD_SUBSTITUTIONS = {
    **BRUTAL_SUBSTITUTIONS,
    "Tiny_Stone.aic": "Med_Stone.aic",
    "Tiny_Stone2.aic": "Med_Stone.aic",
    "Tiny_Stone3.aic": "Med_Stone.aic",
    "Tiny_Stone4.aic": "Med_Stone.aic",
    "Small_Stone.aic": "Med_Stone.aic",
    "Small_Stone2.aic": "Med_Stone.aic",
    "Small_Stone3.aic": "Med_Stone.aic",
    "Small_Stone4.aic": "Med_Stone.aic",
    "Med_Stone.aic": "Large_Stone.aic",
    "Tiny_Wooden.aic": "Large_Wooden.aic",
    "Small_Wooden.aic": "Large_Wooden.aic",
    "Med_Wooden.aic": "Large_Wooden.aic",
}


@dataclass(frozen=True)
class ProfileConfig:
    key: str
    title: str
    description: str
    substitutions: dict[str, str]
    priority_scale: Callable[[int], int]


@dataclass
class PriorityStats:
    minimum: int
    maximum: int
    average: float


@dataclass
class FileReport:
    file: str
    source_file: str
    patched: bool
    substituted: bool
    object_count: int
    trailer_bytes: int
    vanilla_sha256: str
    modded_sha256: str
    priority_before: PriorityStats | None
    priority_after: PriorityStats | None


def balanced_priority(priority: int) -> int:
    if priority <= 1:
        return priority
    if priority <= 10:
        return max(2, round(priority * 0.95))
    if priority <= 40:
        return max(3, round(priority * 0.88))
    if priority <= 100:
        return max(15, round(priority * 0.82))
    return max(45, round(priority * 0.75))


def hard_priority(priority: int) -> int:
    if priority <= 1:
        return priority
    if priority <= 10:
        return max(2, round(priority * 0.85))
    if priority <= 40:
        return max(3, round(priority * 0.72))
    if priority <= 100:
        return max(12, round(priority * 0.65))
    return max(25, round(priority * 0.55))


def brutal_priority(priority: int) -> int:
    if priority <= 1:
        return priority
    if priority <= 10:
        return max(2, round(priority * 0.68))
    if priority <= 40:
        return max(2, round(priority * 0.54))
    if priority <= 100:
        return max(8, round(priority * 0.46))
    return max(18, round(priority * 0.38))


def overlord_priority(priority: int) -> int:
    if priority <= 1:
        return priority
    if priority <= 10:
        return max(2, round(priority * 0.58))
    if priority <= 40:
        return max(2, round(priority * 0.42))
    if priority <= 100:
        return max(6, round(priority * 0.34))
    return max(14, round(priority * 0.28))


PROFILES = (
    ProfileConfig(
        key="balanced",
        title="Balanced",
        description=(
            "Moderate AI castle hardening. Keeps economy pressure lower and is "
            "the safest profile for longer matches."
        ),
        substitutions=BALANCED_SUBSTITUTIONS,
        priority_scale=balanced_priority,
    ),
    ProfileConfig(
        key="hard",
        title="Hard",
        description=(
            "Stronger same-lord and same-material castle progression."
        ),
        substitutions=HARD_SUBSTITUTIONS,
        priority_scale=hard_priority,
    ),
    ProfileConfig(
        key="brutal",
        title="Brutal",
        description=(
            "Large same-material castle upgrades with aggressive build priorities."
        ),
        substitutions=BRUTAL_SUBSTITUTIONS,
        priority_scale=brutal_priority,
    ),
    ProfileConfig(
        key="overlord",
        title="Overlord",
        description=(
            "Maximum infrastructure for large, open AI estates. Not intended "
            "for cramped build areas."
        ),
        substitutions=OVERLORD_SUBSTITUTIONS,
        priority_scale=overlord_priority,
    ),
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_patch_target(path: Path) -> bool:
    lowered = path.name.lower()
    return not lowered.startswith(EXCLUDED_PREFIXES)


def parse_aic(data: bytes) -> tuple[int, int]:
    if len(data) < 4:
        raise ValueError("AIC file is too small")
    count = struct.unpack_from("<I", data, 0)[0]
    records_end = 4 + count * 8
    if records_end > len(data):
        raise ValueError(
            f"AIC object table overruns file: count={count}, size={len(data)}"
        )
    return count, len(data) - records_end


def read_priorities(data: bytes, count: int) -> list[int]:
    return [
        struct.unpack_from("<H", data, 4 + index * 8 + 4)[0]
        for index in range(count)
    ]


def stats(values: list[int]) -> PriorityStats:
    return PriorityStats(
        minimum=min(values),
        maximum=max(values),
        average=round(sum(values) / len(values), 2),
    )


def infrastructure_priority(profile: ProfileConfig, building_id: int, priority: int) -> int:
    economy_factor, weapon_factor, military_factor = INFRASTRUCTURE_FACTORS[profile.key]
    if building_id in ECONOMY_BUILDINGS:
        factor = economy_factor
    elif building_id in WEAPON_BUILDINGS:
        factor = weapon_factor
    elif building_id in MILITARY_BUILDINGS:
        factor = military_factor
    else:
        return priority
    return max(2, round(priority * factor))


def patch_priorities(data: bytes, count: int, profile: ProfileConfig) -> bytes:
    output = bytearray(data)
    for index in range(count):
        record_offset = 4 + index * 8
        priority_offset = record_offset + 4
        building_id = output[record_offset]
        priority = struct.unpack_from("<H", output, priority_offset)[0]
        scaled = profile.priority_scale(priority)
        strategic = infrastructure_priority(profile, building_id, scaled)
        struct.pack_into("<H", output, priority_offset, strategic)
    return bytes(output)


def build_profile(profile: ProfileConfig) -> dict:
    output_root = PROFILE_ROOT / profile.key
    output_castles = output_root / "castles"
    output_castles.mkdir(parents=True, exist_ok=True)

    reports: list[FileReport] = []
    for target_path in sorted(VANILLA_CASTLES.glob("*.aic")):
        source_name = profile.substitutions.get(target_path.name, target_path.name)
        source_path = VANILLA_CASTLES / source_name
        if not source_path.exists():
            raise FileNotFoundError(f"Missing substituted source: {source_path}")

        target_data = target_path.read_bytes()
        source_data = source_path.read_bytes()
        count, trailer_bytes = parse_aic(source_data)
        before_values = read_priorities(source_data, count)

        patched = is_patch_target(target_path)
        if patched:
            output_data = patch_priorities(source_data, count, profile)
            after_values = read_priorities(output_data, count)
        else:
            output_data = source_data
            after_values = before_values

        output_path = output_castles / target_path.name
        output_path.write_bytes(output_data)

        reports.append(
            FileReport(
                file=target_path.name,
                source_file=source_name,
                patched=patched,
                substituted=source_name != target_path.name,
                object_count=count,
                trailer_bytes=trailer_bytes,
                vanilla_sha256=sha256(target_data),
                modded_sha256=sha256(output_data),
                priority_before=stats(before_values) if before_values else None,
                priority_after=stats(after_values) if after_values else None,
            )
        )

    manifest = {
        "name": f"Stronghold 2 AI Overhaul - {profile.title}",
        "profile": profile.key,
        "title": profile.title,
        "description": profile.description,
        "game": "Stronghold 2 Steam Edition",
        "game_rules_dat": "not modified by this build",
        "strategy": {
            "aic_record_format": "uint32 count followed by count 8-byte records; bytes 4-5 of each record are build priority",
            "priority_scaling": profile.priority_scale.__name__,
            "strategic_infrastructure_factors": {
                "economy": INFRASTRUCTURE_FACTORS[profile.key][0],
                "weapons": INFRASTRUCTURE_FACTORS[profile.key][1],
                "military": INFRASTRUCTURE_FACTORS[profile.key][2],
            },
            "substitutions": profile.substitutions,
            "excluded_prefixes": EXCLUDED_PREFIXES,
        },
        "files": [asdict(report) for report in reports],
    }
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    return manifest


def build() -> dict:
    if not VANILLA_CASTLES.exists():
        raise FileNotFoundError(f"Missing vanilla source directory: {VANILLA_CASTLES}")

    PROFILE_ROOT.mkdir(parents=True, exist_ok=True)
    manifests = [build_profile(profile) for profile in PROFILES]

    hard_castles = PROFILE_ROOT / "hard" / "castles"
    if LEGACY_HARD_CASTLES.exists():
        shutil.rmtree(LEGACY_HARD_CASTLES)
    shutil.copytree(hard_castles, LEGACY_HARD_CASTLES)

    aggregate = {
        "name": "Stronghold 2 AI Overhaul",
        "game": "Stronghold 2 Steam Edition",
        "version": "4.5-strategic-build-order",
        "default_profile": "hard",
        "profiles": [
            {
                "profile": manifest["profile"],
                "title": manifest["title"],
                "description": manifest["description"],
                "file_count": len(manifest["files"]),
                "patched_count": sum(1 for file in manifest["files"] if file["patched"]),
                "substituted_count": sum(
                    1 for file in manifest["files"] if file["substituted"]
                ),
            }
            for manifest in manifests
        ],
    }
    AGGREGATE_MANIFEST_PATH.write_text(
        json.dumps(aggregate, indent=2), encoding="utf-8"
    )
    return aggregate


def main() -> None:
    if PROFILE_ROOT.exists():
        shutil.rmtree(PROFILE_ROOT)
    aggregate = build()
    print(f"Built {len(aggregate['profiles'])} profiles")
    for profile in aggregate["profiles"]:
        print(
            f"{profile['title']}: files={profile['file_count']} "
            f"patched={profile['patched_count']} "
            f"substituted={profile['substituted_count']}"
        )
    print(f"Manifest: {AGGREGATE_MANIFEST_PATH}")


if __name__ == "__main__":
    main()
