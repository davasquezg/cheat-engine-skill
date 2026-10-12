# MMSF Legacy Collection — v8 table (build 1.0.2.0)

[Español](README.md) · **English**

**Ready-to-use tables:**

| Language | File |
|---|---|
| Spanish | `MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0_ES.CT` |
| English | `MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0_EN.CT` |

Both use the same addresses, bases and scripts; only the labels, notes and messages differ. In-game proper names (cards, abilities, items) are kept as in the original table.

Optional: rebuild them from the **original table** on FearLess Revolution with the patch:

```bash
# 1) Download the original: https://fearlessrevolution.com/viewtopic.php?t=38738
# 2) Apply the patch (from this folder)
python build_v8.py MEGAMAN_STARFORCE_Legacy_Collection.CT --lang en    # English
python build_v8.py MEGAMAN_STARFORCE_Legacy_Collection.CT --lang es    # Spanish
python ../../cheat-engine-tables/scripts/ct_tool.py validate MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0_EN.CT
```

- **Expected original table (SHA-256):** `9b1b11a1f01b0495ed149fa8668dd33f4446b8ab3cb898ae8c602b9c752459c8`. If the author has published a different revision, the script warns you. `--force` lets you try anyway, but entry IDs may not match.
- **Verification:** addresses, offsets and types in both versions are identical to the v8 table validated in-game on 2026-10-12.
- **`resolvers.json`:** holds the bases and AOB signatures for build 1.0.2.0. If the game is updated and the signatures fail, regenerate them with `sigmaker.py` (see the skill) and run the patch again.
- **`i18n.py`:** holds the translations. To fix or add a text, edit it there and rebuild the tables.

## Changes from the original

| Area | Change |
|---|---|
| Bases | `[Resolver]` with 3 AOB signatures per base and a static fallback; the game groups are nested under it |
| SF1 | "Current HP" (+2E), new "Base HP" entry (+28), and the +30 field marked as unknown |
| Cards | "Edit only from the field map" notes, per-border byte map, and a warning on the "5. All" group |
| SF2 | Duplicate "Gorgon Eye" entry marked as unverified |
| SF3 Battle | **Noise Gauge** submenu whose header is a script (locked value, 500–9999) and **Delete Time** submenu (locked at 1) |
| Languages | Spanish and English versions generated from `i18n.py` |
