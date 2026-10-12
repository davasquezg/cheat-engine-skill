#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_fearless.py — Genera la versión de la tabla compatible con las reglas de FearLess Revolution
(https://fearlessrevolution.com/viewtopic.php?t=20, regla "Can I post tables other people created?" #4b):

  * Cabecera "[wepon1984] (original author)" con TODO el contenido original intacto
    (nombres, estructura y scripts originales). Lo único que cambia es el ancla de las bases
    (dirección estática antigua -> símbolo sf12_base / sf3_base), imprescindible para que funcione
    con la build 1.0.2.0.
  * Cabecera "[Skolleks]" con los aportes propios: Resolver AOB, scripts de batalla de SF3,
    entrada HP base de SF1 y notas verificadas en el juego.
  * Solo inglés.

Uso:
  python build_fearless.py MEGAMAN_STARFORCE_Legacy_Collection.CT [-o salida.CT] [--user NOMBRE]

Licencia de este archivo: PolyForm Noncommercial 1.0.0 (ver LICENSE en la raíz).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "cheat-engine-tables" / "scripts"))
sys.path.insert(0, str(HERE))
import ct_tool    # noqa: E402
import i18n       # noqa: E402
from build_v9 import (ORIGINAL_SHA256, HP_FIELD10, HP_FIELD20, HP_OFFS,  # noqa: E402
                      freeze_script, hp_lock_script, note_entry)

ORIGINAL_AUTHOR = "wepon1984"
OUT_DEFAULT = "fearless/MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_FearLess_EN.CT"


def en(text: str) -> str:
    for a, b in i18n.SCRIPT_EN:
        text = text.replace(a, b)
    return text


def group(entry_id: int, desc: str, color: str | None = None) -> ET.Element:
    el = ET.fromstring(f'<CheatEntry><ID>{entry_id}</ID><Description>"{desc}"</Description>'
                       '<Options moManualExpandCollapse="1" moAllowManualCollapseAndExpand="1"/>'
                       '<GroupHeader>1</GroupHeader><CheatEntries/></CheatEntry>')
    if color:
        el.insert(2, ET.fromstring(f"<Color>{color}</Color>"))
    return el


def script(entry_id: int, desc: str, src: str, color: str = "008000") -> ET.Element:
    el = ET.fromstring(f'<CheatEntry><ID>{entry_id}</ID><Description>"{desc}"</Description>'
                       f'<Color>{color}</Color><VariableType>Auto Assembler Script</VariableType>'
                       '<AssemblerScript/></CheatEntry>')
    el.find("AssemblerScript").text = src
    return el


def pointer(entry_id: int, desc: str, vtype: str, symbol: str, applied: list[int]) -> ET.Element:
    el = ET.fromstring(f'<CheatEntry><ID>{entry_id}</ID><Description>"{desc}"</Description>'
                       f'<ShowAsSigned>0</ShowAsSigned><VariableType>{vtype}</VariableType>'
                       f'<Address>{symbol}</Address><Offsets/></CheatEntry>')
    offs = el.find("Offsets")
    for o in reversed(applied):          # XML: orden inverso al de aplicación
        ET.SubElement(offs, "Offset").text = f"{o:X}"
    return el


def build(original: Path, out: Path, user: str) -> None:
    ct = ct_tool.CheatTable(original)
    cfg = json.loads((HERE / "resolvers.json").read_text(encoding="utf-8"))
    cfg["description"] = "[Resolver] SF1/SF2/SF3 bases — enable first"

    # 1) Contenido original: solo se cambian las anclas por los símbolos del resolver
    mapping = {ct_tool.norm_addr(b["replaces"]): b["symbol"] for b in cfg["bases"]}
    hits = ct_tool._apply_map(ct, mapping)
    if sum(hits.values()) != 3:
        sys.exit(f"Se esperaban 3 anclas en la tabla original, se encontraron {sum(hits.values())}")

    nid = ct.max_id()

    def next_id() -> int:
        nonlocal nid
        nid += 1
        return nid

    top = ct.root.find("CheatEntries")
    original_entries = list(top)
    for el in original_entries:
        top.remove(el)

    # 2) Cabecera del autor original con TODO su contenido
    author = group(next_id(), f"[{ORIGINAL_AUTHOR}] (original author)")
    author.find("CheatEntries").extend(original_entries)

    # 3) Cabecera propia
    mine = group(next_id(), f"[{user}]", "008000")
    m = mine.find("CheatEntries")
    m.append(note_entry(next_id(), f"##Additions by {user} — enable the [Resolver] below FIRST; "
                                   f"all other entries are by {ORIGINAL_AUTHOR}", "008000"))
    m.append(script(next_id(), "[Resolver] SF1/SF2/SF3 bases — enable first",
                    en(ct_tool.build_resolver_script(cfg)), "0000FF"))

    sf1 = group(next_id(), "SF1 (Pegasus / Leo / Dragon)")
    sf1.find("CheatEntries").extend([
        pointer(next_id(), "Base HP (starts at 100)", "2 Bytes", "sf12_base", [0x238, 0x170, 0x28, 0x28]),
        note_entry(next_id(), "##Original 'HP' (+2E) is CURRENT HP; original 'Max HP' (+30) is NOT max HP "
                              "(stays at 710 after taking damage)", "808080"),
        note_entry(next_id(), "##Card bytes per border: +70 white | +71 yellow | +72 blue (Mega) | +73 red (Giga)",
                   "808080"),
        note_entry(next_id(), "##'5. All' card entries are 4 Bytes from +71: they also overwrite +72/+73/+74 "
                              "(Mega/Giga) — prefer the per-border groups", "808080"),
    ])
    m.append(sf1)

    sf2 = group(next_id(), "SF2 (Zerker x Ninja / Zerker x Saurian)")
    sf2.find("CheatEntries").append(
        note_entry(next_id(), "##'0 Stars' has two 'Gorgon Eye' entries (+7A8 and +B68); +B68 is unverified",
                   "808080"))
    m.append(sf2)

    sf3 = group(next_id(), "SF3 (Black Ace / Red Joker)")
    s3 = sf3.find("CheatEntries")
    s3.append(note_entry(next_id(), "##Do NOT use these scripts while connected online, in network/Brother "
                                    "battles or trades: SP boss times are visible to your Brothers", "0000FF"))
    s3.append(script(next_id(), "Noise Gauge locked in battle (asks for a value 500–9999)",
                     en(freeze_script("SF3 - Noise fijo en batalla", "NOISE_SF3", [0x190, 0x38], 0x2D4,
                                      500, 9999, 2000, True, 100,
                                      "Noise Gauge Change (Current Battle). Unidades 0.1 %: 500 = 50.0 %, "
                                      "9999 = 999.9 %. Pide el valor al activar."))))
    s3.append(script(next_id(), "Delete Time locked at 1 during battle",
                     en(freeze_script("SF3 - Delete Time fijo en 1", "DELTIME_SF3", [0x168, 0x10], 0x60,
                                      1, 1, 1, False, 30,
                                      "Delete Time = 1 desde el inicio de la batalla y fijo hasta el final."))))
    hp = script(next_id(), "HP Upgrades locked (Max HP 1000; asks for a target 100–1000)", en(hp_lock_script()))
    hp.insert(2, ET.Element("Options", {"moManualExpandCollapse": "1", "moAllowManualCollapseAndExpand": "1"}))
    ET.SubElement(hp, "CheatEntries").extend([
        note_entry(next_id(), "##Max HP = 100 + 10x(HP Upgrade +10) + 20x(HP Upgrade +20), capped at 1000 "
                              "(e.g. 18/36). Disable the script to edit by hand", "808080"),
        pointer(next_id(), "HP Upgrade +10 (count)", "Byte", "sf3_base", HP_OFFS + [HP_FIELD10]),
        pointer(next_id(), "HP Upgrade +20 (count)", "Byte", "sf3_base", HP_OFFS + [HP_FIELD20]),
    ])
    s3.append(hp)
    s3.append(note_entry(next_id(), "##'Mr Hertzes' value sticks but does not affect the game (under investigation)",
                         "808080"))
    m.append(sf3)

    m.append(note_entry(next_id(), "##Edit values ONLY from the field map (Folder/Library closed): "
                                   "closing a menu overwrites your changes", "0000FF"))

    top.append(mine)
    top.append(author)
    out.parent.mkdir(parents=True, exist_ok=True)
    ct.save(out)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("original")
    ap.add_argument("-o", "--out", default=OUT_DEFAULT)
    ap.add_argument("--user", default="Skolleks", help="tu nombre de usuario en FearLess")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    src = Path(a.original)
    sha = hashlib.sha256(src.read_bytes()).hexdigest()
    if sha != ORIGINAL_SHA256 and not a.force:
        sys.exit(f"SHA-256 distinto al esperado ({sha}); usa --force si es compatible.")
    out = Path(a.out)
    build(src, out, a.user)
    print(f"Tabla FearLess generada: {out}")


if __name__ == "__main__":
    main()
