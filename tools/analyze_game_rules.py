#!/usr/bin/env python3
import argparse
import csv
import hashlib
import json
import pathlib
import struct
import zlib


LORD_NAMES_FROM_EXE = [
    "bishop", "queen", "caliph", "wolf", "pig", "snake", "rat", "bull",
    "hawk", "grey", "olaf", "edwin", "king", "william", "seren", "barclay",
]

VERIFIED_ACTOR_IDS = {
    0x13: "archer",
    0x1B: "swordsman",
    0x1C: "spearman",
    0x1D: "ladderman",
    0x30: "engineer",
    0x31: "armed peasant",
    0x32: "maceman",
    0x33: "pikeman",
    0x34: "crossbowman",
    0x42: "trebuchet",
    0x43: "fire ballista",
    0x44: "catapult",
    0x47: "knight",
    0x48: "assassin",
    0x49: "outlaw",
    0x4A: "horse archer",
    0x4B: "berserker",
    0x4C: "boat warrior",
    0x4D: "light cavalry",
    0x4E: "axe thrower",
    0x4F: "thief",
    0x58: "large siege tower",
    0x59: "small siege tower",
    0x5A: "battering ram",
    0x5B: "unknown siege actor",
    0x66: "mantlet",
    0x67: "burning cart",
    0x68: "tunneller",
}

# Raw columns are relative to the prefix [tail, 2, 1, 8, 88]. Column 5 is
# the first payload int32 in serialized LordsRules section 8.
ATTACK_FIELDS = [
    (5, "0x340", "minimum_attack_army_size", "count"),
    (6, "0x344", "random_extra_army_size", "count"),
    (7, "0x348", "attack_unit_ranged", "actor"),
    (8, "0x34c", "attack_unit_ranged_weight", "weight"),
    (9, "0x350", "attack_unit_infantry", "actor"),
    (10, "0x354", "attack_unit_infantry_weight", "weight"),
    (11, "0x358", "attack_unit_support", "actor"),
    (12, "0x35c", "attack_unit_support_weight", "weight"),
    (13, "0x360", "attack_unit_elite", "actor"),
    (14, "0x364", "attack_unit_elite_weight", "weight"),
    (15, "0x394", "laddermen", "count"),
    (16, "0x368", "catapults", "count"),
    (17, "0x36c", "trebuchets", "count"),
    (18, "0x370", "fire_ballistas", "count"),
    (19, "0x374", "battering_rams", "count"),
    (20, "0x378", "small_siege_towers", "count"),
    (21, "0x37c", "large_siege_towers", "count"),
    (22, "0x380", "unknown_siege_actor_0x5b", "count"),
    (23, "0x384", "burning_carts", "count"),
    (24, "0x388", "mantlets", "count"),
    (25, "0x38c", "unknown_0x38c", "unknown"),
    (26, "0x390", "unknown_0x390", "unknown"),
]


def int32_at(raw: bytes, offset: int) -> int:
    return struct.unpack_from("<i", raw, offset)[0]


def find_attack_blocks(raw: bytes, start: int):
    blocks = []
    for offset in range(start + 4, len(raw) - 15):
        header = [int32_at(raw, offset + index * 4) for index in range(4)]
        if header != [2, 1, 8, 88]:
            continue
        block_start = offset - 4
        if not 0 <= int32_at(raw, block_start) <= 16:
            continue

        fields = {}
        for column, object_offset, name, kind in ATTACK_FIELDS:
            value = int32_at(raw, block_start + column * 4)
            entry = {
                "column": column,
                "object_offset": object_offset,
                "kind": kind,
                "value": value,
            }
            if kind == "actor":
                entry["actor_name"] = VERIFIED_ACTOR_IDS.get(value, "unmapped")
            fields[name] = entry

        index = len(blocks)
        blocks.append(
            {
                "index": index,
                "lord_candidate": LORD_NAMES_FROM_EXE[index] if index < len(LORD_NAMES_FROM_EXE) else f"fallback_{index}",
                "raw_offset": block_start,
                "section_8_header_offset": block_start + 12,
                "record_spacing_from_previous": None if not blocks else block_start - blocks[-1]["raw_offset"],
                "prefix": [int32_at(raw, block_start + index * 4) for index in range(5)],
                "fields": fields,
            }
        )
    return blocks


def build_report(game_rules_path: pathlib.Path):
    compressed = game_rules_path.read_bytes()
    raw = zlib.decompress(compressed)
    marker_offset = raw.find(b"LordsRules")
    if marker_offset < 0:
        raise ValueError("LordsRules marker not found")

    blocks = find_attack_blocks(raw, marker_offset + len(b"LordsRules"))
    if len(blocks) != 21:
        raise ValueError(f"Expected 21 LordsRules attack blocks, found {len(blocks)}")
    if any(block["record_spacing_from_previous"] != 1045 for block in blocks[1:]):
        raise ValueError("LordsRules records do not have the expected 1045-byte spacing")

    return {
        "source": str(game_rules_path),
        "compressed_length": len(compressed),
        "compressed_sha256": hashlib.sha256(compressed).hexdigest().upper(),
        "raw_length": len(raw),
        "raw_sha256": hashlib.sha256(raw).hexdigest().upper(),
        "markers": {
            "GameRules": raw.find(b"GameRules"),
            "LordsRules": marker_offset,
        },
        "verified_layout": {
            "lord_record_count": len(blocks),
            "lord_record_spacing": 1045,
            "lords_rules_object_size": 0x3C0,
            "serialized_section": 8,
            "serialized_section_payload_bytes": 88,
            "attack_fields": [
                {"column": column, "object_offset": object_offset, "name": name, "kind": kind}
                for column, object_offset, name, kind in ATTACK_FIELDS
            ],
        },
        "verified_actor_ids": {str(actor_id): name for actor_id, name in VERIFIED_ACTOR_IDS.items()},
        "lord_attack_blocks": blocks,
        "interpretation": {
            "verified": [
                "gameRules.dat is a zlib stream.",
                "LordsRules contains 21 serialized lord objects spaced 1045 bytes apart.",
                "Section 8 contains 88 bytes and serializes the four attack actor types, their weights, laddermen, and siege support counts.",
                "FUN_00461c20 consumes minimum/random army size plus three primary actor weights.",
                "FUN_0045feb0 maps the four attack categories to LordsRules offsets 0x348, 0x350, 0x358, and 0x360.",
                "FUN_00460370 consumes siege counts at offsets 0x368 through 0x388; FUN_00462ac0 consumes laddermen at 0x394.",
                "Actor ids in this report come from the executable's actor-name initialization function FUN_008be030.",
            ],
            "corrected_previous_assumptions": [
                "The former 63 x 347 model describes archive chunking, not 63 gameplay profiles.",
                "The section-8 values are not early/mid/late reinforcement slots.",
                "Columns 8, 10, 12, and 14 are selection weights, not staged unit quantities.",
                "Column 15 is the ladderman count, not a late-game unit actor id.",
            ],
            "unknown": [
                "The exact semantics of LordsRules offsets 0x38c and 0x390 remain unknown.",
                "Siege actor 0x5B is executed by the game, but its display name is not yet resolved.",
                "The mapping of lord indices 16 through 20 remains unknown.",
                "Gold and resource assistance are not part of this serialized attack block.",
            ],
        },
    }


def write_outputs(report, output_dir: pathlib.Path):
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "gameRules-analysis.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    with (output_dir / "lord-attack-rules.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        field_names = [name for _, _, name, _ in ATTACK_FIELDS]
        writer.writerow(["index", "lord_candidate", "raw_offset", *field_names])
        for block in report["lord_attack_blocks"]:
            writer.writerow(
                [
                    block["index"],
                    block["lord_candidate"],
                    block["raw_offset"],
                    *[block["fields"][name]["value"] for name in field_names],
                ]
            )

    lines = ["# Stronghold 2 gameRules.dat Analysis", "", "## Verified"]
    lines.extend(f"- {item}" for item in report["interpretation"]["verified"])
    lines.extend(["", "## Corrected Previous Assumptions"])
    lines.extend(f"- {item}" for item in report["interpretation"]["corrected_previous_assumptions"])
    lines.extend(["", "## Unknowns"])
    lines.extend(f"- {item}" for item in report["interpretation"]["unknown"])
    lines.extend(["", "## Lord Attack Rules", ""])

    compact_fields = [
        "minimum_attack_army_size", "random_extra_army_size", "attack_unit_ranged",
        "attack_unit_infantry", "attack_unit_support", "attack_unit_elite", "laddermen",
        "catapults", "trebuchets", "fire_ballistas", "battering_rams",
        "small_siege_towers", "large_siege_towers", "burning_carts", "mantlets",
    ]
    lines.append("| Index | Lord candidate | " + " | ".join(compact_fields) + " |")
    lines.append("|---:|---|" + "---:|" * len(compact_fields))
    for block in report["lord_attack_blocks"]:
        values = [str(block["fields"][name]["value"]) for name in compact_fields]
        lines.append(f"| {block['index']} | {block['lord_candidate']} | " + " | ".join(values) + " |")

    lines.extend(
        [
            "",
            "## Safety Note",
            "",
            "- Keep rules changes behind the explicit experimental launcher option until the verified fields have completed in-game balance testing.",
            "- Do not patch offsets 0x38c, 0x390, or siege actor 0x5B until their behavior is proven.",
            "",
        ]
    )
    (output_dir / "gameRules-analysis.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Analyze verified Stronghold 2 LordsRules attack fields.")
    parser.add_argument("game_rules", type=pathlib.Path)
    parser.add_argument("--output-dir", type=pathlib.Path, default=pathlib.Path("analysis"))
    args = parser.parse_args()

    report = build_report(args.game_rules)
    write_outputs(report, args.output_dir)
    print(f"Wrote {args.output_dir / 'gameRules-analysis.json'}")
    print(f"Wrote {args.output_dir / 'lord-attack-rules.csv'}")
    print(f"Wrote {args.output_dir / 'gameRules-analysis.md'}")
    print(f"raw={report['raw_length']} lord_records={report['verified_layout']['lord_record_count']}")


if __name__ == "__main__":
    main()
