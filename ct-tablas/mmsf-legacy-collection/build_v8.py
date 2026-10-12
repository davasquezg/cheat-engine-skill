#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_v8.py — Reconstruye la tabla "MMSF Legacy Collection v8 (build 1.0.2.0)" a partir
de la TABLA ORIGINAL publicada por su autor en FearLess Revolution (t=38738).

Este repositorio NO redistribuye la tabla original ni la derivada: solo contiene las
transformaciones (obra propia) que se aplican sobre tu copia de la original.

Uso:
  1) Descarga la tabla original desde https://fearlessrevolution.com/viewtopic.php?t=38738
  2) python build_v8.py MEGAMAN_STARFORCE_Legacy_Collection.CT -o MMSF_LC_v8.CT

Requiere: Python 3.9+ y ../../cheat-engine-tables/scripts/ct_tool.py (incluido en el repo).
Licencia de este archivo: PolyForm Noncommercial 1.0.0 (ver LICENSE en la raíz).
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "cheat-engine-tables" / "scripts"))
import ct_tool  # noqa: E402

# SHA-256 de la tabla original con la que se validó este parche
ORIGINAL_SHA256 = "9b1b11a1f01b0495ed149fa8668dd33f4446b8ab3cb898ae8c602b9c752459c8"


# --------------------------------------------------------------------------------------
# Generador de cabeceras-script "valor fijo en batalla" (obra propia)
# --------------------------------------------------------------------------------------
def freeze_script(name, glob, offs, field, vmin, vmax, default, ask, interval_ms, note):
    offs_lua = ", ".join(f"0x{o:X}" for o in offs)
    ask_block = f'''
local prev = (OLD and OLD.objetivo) or {default}
local txt = inputQuery("{name}", "Valor fijo ({vmin} a {vmax}):", tostring(prev))
if txt == nil then error("Cancelado por el usuario") end
local v = tonumber(txt)
if v == nil then error("Valor no numérico: " .. tostring(txt)) end
v = math.floor(v)
if v < {vmin} then v = {vmin} end
if v > {vmax} then v = {vmax} end''' if ask else f"\nlocal v = {default}"
    return f'''[ENABLE]
{{$lua}}
if syntaxcheck then return end
-- =====================================================================================
-- {name}
-- {note}
-- Cadena: [[sf3_base]{''.join(f"+{o:X}]" for o in offs)}+{field:X}  (4 Bytes). Requiere el [Resolver] activo.
-- Mantiene el valor FIJO mientras dure la batalla (revisa cada {interval_ms} ms).
-- Fuera de batalla la cadena no resuelve y el script no escribe nada.
-- =====================================================================================
local OLD = {glob}
if OLD and OLD.timer then OLD.timer.destroy() end
{ask_block}

{glob} = {{ objetivo = v, escrituras = 0 }}
local OFFS, FIELD = {{ {offs_lua} }}, 0x{field:X}

local function campo()
  local b = getAddressSafe("sf3_base")
  if not b then return nil end
  local p = readQword(b)
  if not p or p == 0 then return nil end
  for _, o in ipairs(OFFS) do
    p = readQword(p + o)
    if not p or p == 0 or p < 0x10000 then return nil end
  end
  return p + FIELD
end

local t = createTimer(nil, false)
t.Interval = {interval_ms}
t.OnTimer = function()
  local ok, err = pcall(function()
    local a = campo()
    if not a then return end
    local cur = readInteger(a)
    if cur ~= nil and cur ~= {glob}.objetivo then
      writeInteger(a, {glob}.objetivo)
      {glob}.escrituras = {glob}.escrituras + 1
    end
  end)
  if not ok then print("[{name}] " .. tostring(err)) end
end
{glob}.timer = t
t.Enabled = true
if not getAddressSafe("sf3_base") then
  showMessage("Aviso: sf3_base no está registrado. Activa primero el [Resolver].")
end
{{$asm}}

[DISABLE]
{{$lua}}
if syntaxcheck then return end
if {glob} and {glob}.timer then {glob}.timer.destroy(); {glob}.timer = nil end
{{$asm}}
'''


# --------------------------------------------------------------------------------------
def reload(path: Path) -> ct_tool.CheatTable:
    return ct_tool.CheatTable(path)


def note_entry(entry_id: int, text: str, color: str = "0000FF") -> ET.Element:
    return ET.fromstring(f'<CheatEntry><ID>{entry_id}</ID><Description>"{text}"</Description>'
                         f'<Color>{color}</Color><GroupHeader>1</GroupHeader></CheatEntry>')


def make_absolute(el: ET.Element, applied: list[int]) -> None:
    el.find("Address").text = "sf3_base"
    o = el.find("Offsets")
    if o is None:
        o = ET.SubElement(el, "Offsets")
    for c in list(o):
        o.remove(c)
    for x in reversed(applied):          # XML: orden inverso al de aplicación
        ET.SubElement(o, "Offset").text = f"{x:X}"


def to_script_header(el: ET.Element, desc: str, script: str) -> None:
    el.find("Description").text = f'"{desc}"'
    for tag in ("GroupHeader", "Options", "VariableType", "AssemblerScript"):
        x = el.find(tag)
        if x is not None:
            el.remove(x)
    el.insert(2, ET.Element("Options", {"moManualExpandCollapse": "1", "moAllowManualCollapseAndExpand": "1"}))
    el.insert(3, ET.fromstring("<Color>008000</Color>"))
    vt = ET.Element("VariableType"); vt.text = "Auto Assembler Script"; el.insert(4, vt)
    s = ET.Element("AssemblerScript"); s.text = script; el.insert(5, s)


def build(original: Path, out: Path, tmp: Path) -> None:
    # 1) Resolver AOB + respaldo, anclas -> símbolos, grupos anidados
    ct_tool.cmd_resolve(SimpleNamespace(file=str(original), config=str(HERE / "resolvers.json"),
                                        nest=True, out=str(tmp)))
    ct = reload(tmp)
    by = {e.id: e for e in ct.entries}

    # 2) SF1: HP actual / HP base / campo +30 (validado en vivo)
    hp, mx = by["270"], by["272"]
    hp.elem.find("Description").text = '"HP actual"'
    mx.elem.find("Description").text = '"+30 desconocido (NO es Max HP; 710 fijo al recibir daño) — sin verificar"'
    mx.elem.append(ET.fromstring("<Color>808080</Color>"))
    new = copy.deepcopy(hp.elem)
    new.find("ID").text = str(ct.max_id() + 1)
    new.find("Description").text = '"HP base (inicial 100)"'
    new.find("Offsets")[0].text = "28"
    parent = hp.parent.elem.find("CheatEntries")
    parent.insert(list(parent).index(hp.elem), new)
    ct.save(tmp); ct = reload(tmp); by = {e.id: e for e in ct.entries}

    # 3) Notas de uso en Cards, aviso "5. All", Gorgon Eye duplicado en SF2
    nid = ct.max_id()
    for e in ct.entries:
        if e.desc == "Cards" and e.is_group:
            nid += 1
            e.elem.find("CheatEntries").insert(0, note_entry(nid,
                "##Editar SOLO desde el mapa (sin Folder/Biblioteca abiertos): al cerrar el menú se sobrescribe"))
    for e in ct.entries:
        if e.desc == "Cards" and "Pegasus" in e.path:
            nid += 1
            e.elem.find("CheatEntries").insert(0, note_entry(nid,
                "##Bytes por carta: +70 blanco | +71 amarillo | +72 azul (Mega) | +73 rojo (Giga)"))
        if e.desc == "5. All" and "Pegasus" in e.path:
            e.elem.find("Description").text = ('"5. All  [⚠ 4 Bytes desde +71: escribe también +72/+73/+74 — '
                                               'puede borrar Mega/Giga]"')
            if e.elem.find("Color") is None:
                ET.SubElement(e.elem, "Color").text = "0000FF"
    d = by["1780"]
    d.elem.find("Description").text = '"Gorgon Eye (? duplicado de +7A8 en tabla original — sin verificar)"'
    ET.SubElement(d.elem, "Color").text = "808080"
    ct.save(tmp); ct = reload(tmp); by = {e.id: e for e in ct.entries}

    # 4) SF3 Battle: submenú Noise Gauge (cabecera-script) y submenú Delete Time
    battle_ce = by["238"].elem.find("CheatEntries")
    nid = ct.max_id() + 1
    noise = ET.fromstring(f'<CheatEntry><ID>{nid}</ID><Description>"Noise Gauge"</Description>'
                          f'<GroupHeader>1</GroupHeader><Address/><CheatEntries/></CheatEntry>')
    n_change, n_disp = by["4310"].elem, by["4312"].elem
    pos = list(battle_ce).index(n_change)
    battle_ce.remove(n_change); battle_ce.remove(n_disp)
    battle_ce.insert(pos, noise)
    noise.find("CheatEntries").extend([n_change, n_disp])
    to_script_header(noise, "Noise Gauge  [Script: fijo en batalla — pide valor 500–9999]",
                     freeze_script("SF3 - Noise fijo en batalla", "NOISE_SF3", [0x190, 0x38], 0x2D4,
                                   500, 9999, 2000, True, 100,
                                   "Noise Gauge Change (Current Battle). Unidades 0.1 %: 500 = 50.0 %, "
                                   "9999 = 999.9 %. Pide el valor al activar."))
    make_absolute(n_change, [0x190, 0x38, 0x2D4])
    make_absolute(n_disp, [0x190, 0x38, 0x2D8])

    dt = by["244"].elem
    hdr = ET.fromstring(f'<CheatEntry><ID>{nid + 1}</ID><Description>"x"</Description></CheatEntry>')
    to_script_header(hdr, "Delete Time  [Script: fijo en 1 durante la batalla]",
                     freeze_script("SF3 - Delete Time fijo en 1", "DELTIME_SF3", [0x168, 0x10], 0x60,
                                   1, 1, 1, False, 30,
                                   "Delete Time = 1 desde el inicio de la batalla y fijo hasta el final."))
    idx = list(battle_ce).index(dt)
    battle_ce.remove(dt); battle_ce.insert(idx, hdr)
    ET.SubElement(hdr, "CheatEntries").append(dt)
    make_absolute(dt, [0x168, 0x10, 0x60])
    ct.save(out)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("original", help="tabla original descargada de FearLess Revolution")
    ap.add_argument("-o", "--out", default="MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0.CT")
    ap.add_argument("--force", action="store_true", help="continuar aunque el SHA-256 no coincida")
    a = ap.parse_args()
    src = Path(a.original)
    sha = hashlib.sha256(src.read_bytes()).hexdigest()
    if sha != ORIGINAL_SHA256:
        print(f"AVISO: el SHA-256 de la tabla original no coincide.\n  esperado {ORIGINAL_SHA256}\n  recibido {sha}")
        if not a.force:
            sys.exit("Usa --force si sabes que es la misma tabla (o una revisión compatible).")
    out = Path(a.out)
    tmp = out.with_suffix(".tmp.CT")
    try:
        build(src, out, tmp)
    finally:
        if tmp.exists():
            tmp.unlink()
    print(f"Tabla generada: {out}")
    print("Valida con: python ../../cheat-engine-tables/scripts/ct_tool.py validate", out)


if __name__ == "__main__":
    main()
