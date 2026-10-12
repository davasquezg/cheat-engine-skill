# cheat-engine-skill

[Español](README.md) · **English**

A Claude skill to **build, audit, repair and harden Cheat Engine tables (`.CT`)** for **single-player / offline** games. It includes a toolkit (Python + Lua) and a sample table that has already been repaired and validated in-game, available in **Spanish and English**.

## What it solves

When a game is updated, `.CT` tables that rely on static addresses (`game.exe+0E120A40`) stop working. This project lets you:

1. **Audit the table:** finds the anchors that hundreds of entries depend on and validates the XML.
2. **Recover the bases** with the game running, using a reverse pointer search from a known value.
3. **Harden the table:** replaces fixed addresses with **AOB-resolved symbols** (several signatures per base) plus a static fallback, so the table can survive future patches.
4. **Handle packed or DRM-protected executables:** generates signatures from a memory dump of the module, without modifying the executable.

## Contents

```
cheat-engine-tables/          ← the skill (SKILL.md) and its toolkit
├── SKILL.md                  ← instructions for Claude (Spanish)
├── scripts/
│   ├── ct_tool.py            ← info, tree, chains, rebase, resolve, validate, diff
│   └── sigmaker.py           ← peinfo, refs, make, check (x64 AOB signatures, supports --dump)
├── lua/ct_helpers.lua        ← helper functions for the Cheat Engine Lua console
├── templates/                ← per-game resolver configuration (JSON)
├── references/               ← .CT format, live workflow, Auto Assembler templates
└── tests/run_tests.sh        ← smoke tests (synthetic PE + simulated CE API)
ct-tablas/
└── mmsf-legacy-collection/
    ├── MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_ES.CT   ← Spanish table
    ├── MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_EN.CT   ← English table
    ├── ..._v8_..._ES.CT / _EN.CT  ← previous version (reference)
    ├── build_v9.py           ← reproducible patch from the original table (--lang es|en)
    ├── i18n.py               ← table translations
    └── resolvers.json        ← bases and AOB signatures for build 1.0.2.0
```

## Installation

### As a Claude skill
Upload the `cheat-engine-tables/` folder as a custom skill (Claude Desktop / Cowork or Claude Code). The entry file is `SKILL.md`.

### Toolkit on your machine
```bash
pip install pefile capstone numpy
python cheat-engine-tables/scripts/ct_tool.py info table.CT
bash cheat-engine-tables/tests/run_tests.sh          # Linux/WSL, requires Lua 5.3
```

## Included table: Mega Man Star Force Legacy Collection

| Item | Value |
|---|---|
| Build | FileVersion **1.0.2.0**, TimeDateStamp `0x6A0A9BF4` (2026-05-18), Steam |
| Bases | `sf12_base` (SF1/SF2) and `sf3_base` (SF3), resolved by AOB (3 signatures per base) with a static fallback |
| Validated in-game | Zenny, HP, cards, sub items and abilities (SF1–SF3); Noise Gauge, Delete Time and HP Upgrades scripts (SF3) |
| Languages | `_ES.CT` (Spanish) and `_EN.CT` (English). Both use the same addresses; only the text differs |

**Get the table:** use the `.CT` in your language directly from `ct-tablas/mmsf-legacy-collection/`. If you prefer, rebuild it from the original on [FearLess Revolution (t=38738)](https://fearlessrevolution.com/viewtopic.php?t=38738) with `build_v9.py --lang en` or `--lang es`.

**Usage:**
1. Start the game and attach Cheat Engine (7.5 or later).
2. Load the table and enable **`[Resolver] SF1/SF2/SF3 bases — enable first`**.
3. **Edit values only from the field map**, with the Folder and the Library closed. If a menu is open, the game overwrites your changes when you close it.
4. To lock values in battle (SF3), enable the script headers **Noise Gauge** (asks for a value between 500 and 9999) or **Delete Time** (locks it at 1). For max HP, enable **HP Upgrades** (1000 HP by default; disable it to edit by hand).

> In the English version, only the Spanish labels, notes and messages added by this project were translated. The original table was already in English, and **in-game proper names** (cards, abilities, items such as *Unlocker* or *Search Eye*) are kept as they are.

## Scope

- Intended **only** for single-player or offline games, to modify the local game state.
- **Not** intended for online or competitive games, titles with anti-cheat, or bypassing DRM. Memory dumps are only used to read signatures and are never distributed.
- No game files are included: no executable, no dumps, no assets.

## Licenses

| Part | License | File |
|---|---|---|
| Code: `scripts/`, `lua/`, `tests/`, `build_v9.py`, `i18n.py` and the scripts they generate | **PolyForm Noncommercial 1.0.0** | [`LICENSE`](LICENSE) |
| Documentation and data: `SKILL.md`, `references/`, `templates/`, `resolvers.json` and the project's own contributions in the `.CT` tables | **CC BY-NC-SA 4.0** | [`LICENSE-docs`](LICENSE-docs) |

Personal, educational, research and non-profit use is allowed. **Commercial and corporate use is not allowed.** If you need a different license, open an *issue*.

See credits and third-party works in [`CREDITS.en.md`](CREDITS.en.md).

## Author

Darío Vásquez Guzmán — [@davasquezg](https://github.com/davasquezg)
