# Credits and third-party works

[Español](CREDITS.md) · **English**

## Original Mega Man Star Force Legacy Collection table

The tables `ct-tablas/mmsf-legacy-collection/MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0_ES.CT` and `..._EN.CT` are **derivative works** of the table published by its original author on FearLess Revolution. The repository also includes `build_v8.py`, which rebuilds v8 from the original in either language.

- Thread: <https://fearlessrevolution.com/viewtopic.php?t=38738>

All credit for the entry structure, the card, sub item, ability and battle field offsets, and the entry names goes to the original author.

**Contributions of this repository on top of the original table:**
- bases recovered for build 1.0.2.0;
- `[Resolver]` script with AOB signatures and a static fallback;
- game groups nested under the resolver;
- usage notes: edit from the field map, per-border byte map, and 4-byte overlap warnings;
- label fixes: current HP, base HP and the `+30` field;
- Noise Gauge and Delete Time script headers in SF3;
- translation of labels, notes and messages into Spanish and English.

The licenses of this repository cover **only those contributions**. The rights to the content of the original table remain with its author, and any terms the author has set are respected. **If you are the author and want the table changed, restricted or removed, please open an *issue*: it will be handled immediately.**

## Trademarks

*Mega Man*, *Mega Man Star Force* and the names of cards, characters and items are trademarks and content of CAPCOM. They are mentioned only to identify the game and its data. This project is not affiliated with or endorsed by CAPCOM.

*Cheat Engine* is a project by Eric Heijnen (Dark Byte): <https://cheatengine.org> · <https://github.com/cheat-engine/cheat-engine>.

## Tools

The toolkit uses [pefile](https://github.com/erocarrera/pefile), [Capstone](https://www.capstone-engine.org/) and [NumPy](https://numpy.org/), each under its own license. They are not redistributed in this repository.

## Assistance

Toolkit, skill, table repair and translation developed with help from Claude (Anthropic).
