#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ct_tool.py — Utilidades offline para tablas de Cheat Engine (.CT).

Subcomandos:
  info      Resumen de la tabla: versión, tipos, scripts, anclas (bases absolutas), símbolos.
  tree      Árbol jerárquico de entradas (con dirección y offsets).
  chains    Exporta cada entrada con su cadena de punteros completa (CSV o stdout).
  rebase    Reemplaza una o más anclas absolutas por otra dirección/símbolo.
  resolve   Inserta/actualiza un script "[Resolver]" (AOB + respaldo estático) desde un JSON
            y reemplaza las anclas por los símbolos registrados.
  validate  Chequeos estructurales: XML, IDs duplicados, símbolos no registrados, offsets
            inválidos, enlaces DropDownListLink rotos, scripts AA sin [ENABLE]/[DISABLE].
  diff      Compara dos tablas (por ID) y lista cambios de dirección/offsets/tipo/descripción.

Notas de formato (ver references/ct-format.md):
  * En el XML, <Offsets> se guarda en ORDEN INVERSO: el primer <Offset> es el ÚLTIMO que se
    aplica (el más cercano al valor final). Este script lo convierte al orden de aplicación.
  * Una dirección que empieza con '+' o '-' es relativa a la dirección ya resuelta del padre.

Requiere solo la biblioteca estándar de Python 3.9+.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator, Optional

HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")
RESOLVER_TAG = "[Resolver]"


# --------------------------------------------------------------------------------------
# Modelo
# --------------------------------------------------------------------------------------
@dataclass
class Entry:
    elem: ET.Element
    parent: Optional["Entry"]
    depth: int
    children: list = field(default_factory=list)

    # --- accesos cómodos -------------------------------------------------------------
    @property
    def id(self) -> str:
        return (self.elem.findtext("ID") or "").strip()

    @property
    def desc(self) -> str:
        d = self.elem.findtext("Description") or ""
        return d.strip().strip('"')

    @property
    def vtype(self) -> str:
        return (self.elem.findtext("VariableType") or "").strip()

    @property
    def address(self) -> Optional[str]:
        a = self.elem.findtext("Address")
        return a.strip() if a is not None else None

    @property
    def offsets_xml(self) -> list[str]:
        """Offsets tal como están en el XML (orden inverso al de aplicación)."""
        return [(o.text or "").strip() for o in self.elem.findall("Offsets/Offset")]

    @property
    def offsets_applied(self) -> list[str]:
        """Offsets en el orden en que Cheat Engine los aplica (base -> valor)."""
        return list(reversed(self.offsets_xml))

    @property
    def is_group(self) -> bool:
        return (self.elem.findtext("GroupHeader") or "").strip() == "1"

    @property
    def is_script(self) -> bool:
        return self.vtype == "Auto Assembler Script"

    @property
    def path(self) -> str:
        parts = []
        e: Optional[Entry] = self
        while e is not None:
            parts.append(e.desc)
            e = e.parent
        return " / ".join(reversed(parts))

    # --- cadena de punteros ----------------------------------------------------------
    def resolved_expr(self) -> Optional[str]:
        """Expresión textual de la dirección final, p. ej. [[mod+X]+238]+70."""
        addr = self.address
        if addr is None or addr == "":
            return None
        if addr[0] in "+-":
            # CE resuelve "+X" contra el ancestro más cercano que tenga dirección
            # (los encabezados de grupo sin <Address> son transparentes).
            anc = self.address_ancestor()
            base = anc.resolved_expr() if anc else None
            if base is None:
                base = "<sin ancestro con dirección>"
            expr = f"{base}{addr}"
        else:
            expr = addr
        for off in self.offsets_applied:
            sign = "" if off.startswith(("-", "+")) else "+"
            expr = f"[{expr}]{sign}{off}"
        # Limpieza cosmética: "+0" intermedios no aportan
        return re.sub(r"\+0(?=[+\-\]]|$)", "", expr) or expr

    def address_ancestor(self) -> Optional["Entry"]:
        p = self.parent
        while p is not None and not p.address:
            p = p.parent
        return p

    def anchor(self) -> Optional[str]:
        """Dirección absoluta raíz de la que depende esta entrada."""
        e: Optional[Entry] = self
        while e is not None:
            a = e.address
            if a and a[0] not in "+-":
                return a
            e = e.parent
        return None


class CheatTable:
    def __init__(self, path: Path):
        self.path = path
        self.tree = ET.parse(path)
        self.root = self.tree.getroot()
        if self.root.tag != "CheatTable":
            raise SystemExit(f"{path}: el elemento raíz no es <CheatTable>")
        self.entries: list[Entry] = []
        self.top: list[Entry] = []
        self._build()

    def _build(self):
        self.entries.clear()
        self.top.clear()

        def walk(container: ET.Element, parent: Optional[Entry], depth: int):
            ce = container.find("CheatEntries")
            if ce is None:
                return
            for el in ce.findall("CheatEntry"):
                ent = Entry(el, parent, depth)
                self.entries.append(ent)
                (parent.children if parent else self.top).append(ent)
                walk(el, ent, depth + 1)

        walk(self.root, None, 0)

    @property
    def version(self) -> str:
        return self.root.get("CheatEngineTableVersion", "?")

    def max_id(self) -> int:
        ids = [int(e.id) for e in self.entries if e.id.isdigit()]
        return max(ids) if ids else -1

    def save(self, out: Path):
        ET.indent(self.tree, space="  ")
        body = ET.tostring(self.root, encoding="unicode")
        out.write_text('<?xml version="1.0" encoding="utf-8"?>\n' + body + "\n", encoding="utf-8")


# --------------------------------------------------------------------------------------
# Utilidades de direcciones
# --------------------------------------------------------------------------------------
def norm_addr(a: str) -> str:
    """Normaliza 'Mod.exe'+0E120A40 / mod.exe+e120a40 -> mod.exe+E120A40 (para comparar)."""
    a = a.strip().replace('"', "").replace(" ", "")
    m = re.match(r"^(.*?)([+-])([0-9A-Fa-f]+)$", a)
    if m and m.group(1):
        return f"{m.group(1).lower()}{m.group(2)}{int(m.group(3), 16):X}"
    return a.lower()


def base_token(addr: str) -> Optional[str]:
    """Primer término de una dirección absoluta (módulo, símbolo o número)."""
    a = addr.strip()
    if not a or a[0] in "+-":
        return None
    a = a.replace('"', "")
    tok = re.split(r"[+\-*\[\]]", a, maxsplit=1)[0].strip()
    return tok or None


def is_module_name(tok: str) -> bool:
    return bool(re.search(r"\.(exe|dll|so|dylib)$", tok, re.I))


def registered_symbols(ct: CheatTable) -> set[str]:
    syms: set[str] = set()
    for e in ct.entries:
        if e.is_script:
            src = e.elem.findtext("AssemblerScript") or ""
            syms.update(re.findall(r"registersymbol\(\s*([A-Za-z_][\w.]*)", src, re.I))
            syms.update(re.findall(r'registerSymbol\(\s*["\']([^"\']+)["\']', src))
            syms.update(re.findall(r'symbol\s*=\s*["\']([^"\']+)["\']', src))  # tabla BASES del resolver
            # aobscanmodule(name,...) y label(name) también definen símbolos locales
            syms.update(re.findall(r"aobscan(?:module|region)?\(\s*([A-Za-z_]\w*)", src, re.I))
    for s in ct.root.findall("UserdefinedSymbols/SymbolEntry"):
        n = s.findtext("Name")
        if n:
            syms.add(n.strip())
    lua = ct.root.findtext("LuaScript") or ""
    syms.update(re.findall(r'registerSymbol\(\s*["\']([^"\']+)["\']', lua))
    return syms


# --------------------------------------------------------------------------------------
# Subcomandos
# --------------------------------------------------------------------------------------
def cmd_info(a):
    ct = CheatTable(Path(a.file))
    types = Counter(e.vtype or ("(grupo)" if e.is_group else "(sin tipo)") for e in ct.entries)
    anchors = Counter(norm_addr(e.address) for e in ct.entries if e.address and e.address[0] not in "+-")
    depth = max((e.depth for e in ct.entries), default=0)
    offs = Counter(len(e.offsets_xml) for e in ct.entries)
    print(f"Archivo:                 {ct.path}")
    print(f"CheatEngineTableVersion: {ct.version}")
    print(f"Entradas:                {len(ct.entries)}  (profundidad máx. {depth}, ID máx. {ct.max_id()})")
    print("Tipos de variable:")
    for t, n in types.most_common():
        print(f"  {n:6d}  {t}")
    print("Anclas absolutas (de las que dependen las demás entradas):")
    for anc, n in anchors.most_common():
        users = [e for e in ct.entries if e.anchor() and norm_addr(e.anchor()) == anc]
        tops = sorted({e.path.split(' / ')[0] for e in users})
        print(f"  {anc:50s} usada como raíz {n}x, entradas dependientes: {len(users)}")
        for t in tops:
            print(f"      - {t}")
    print("Nº de offsets por entrada:", dict(sorted(offs.items())))
    syms = registered_symbols(ct)
    print("Símbolos registrados por scripts/tabla:", ", ".join(sorted(syms)) or "(ninguno)")
    print("Lua de tabla (<LuaScript>):", "sí" if ct.root.find("LuaScript") is not None else "no")


def cmd_tree(a):
    ct = CheatTable(Path(a.file))
    flt = a.filter.lower() if a.filter else None
    for e in ct.entries:
        if e.depth > a.depth:
            continue
        if flt and flt not in e.path.lower():
            continue
        kind = "AA" if e.is_script else ("G" if e.is_group else (e.vtype or "-"))
        addr = e.address or ""
        offs = ",".join(e.offsets_applied)
        extra = f"  addr={addr}" if addr else ""
        extra += f"  offs(aplic.)=[{offs}]" if offs else ""
        print(f"{'  ' * e.depth}[{e.id}] {e.desc}  <{kind}>{extra}")


def cmd_chains(a):
    ct = CheatTable(Path(a.file))
    rows = []
    for e in ct.entries:
        expr = e.resolved_expr()
        if expr is None:
            continue
        rows.append({"id": e.id, "path": e.path, "type": e.vtype or ("grupo" if e.is_group else ""),
                     "anchor": e.anchor() or "", "chain": expr})
    if a.csv:
        with open(a.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()) if rows else ["id"])
            w.writeheader()
            w.writerows(rows)
        print(f"{len(rows)} cadenas exportadas a {a.csv}")
    else:
        for r in rows:
            if a.filter and a.filter.lower() not in r["path"].lower():
                continue
            print(f"[{r['id']}] {r['path']}\n      {r['chain']}  ({r['type']})")


def _parse_map(pairs: list[str]) -> dict[str, str]:
    m = {}
    for p in pairs:
        if "=" not in p:
            raise SystemExit(f"--map inválido: {p!r} (use VIEJA=NUEVA)")
        old, new = p.split("=", 1)
        m[norm_addr(old)] = new.strip()
    return m


def _apply_map(ct: CheatTable, mapping: dict[str, str]) -> Counter:
    hits: Counter = Counter()
    for e in ct.entries:
        a = e.address
        if a and a[0] not in "+-":
            k = norm_addr(a)
            if k in mapping:
                e.elem.find("Address").text = mapping[k]
                hits[k] += 1
    return hits


def cmd_rebase(a):
    ct = CheatTable(Path(a.file))
    mapping = _parse_map(a.map)
    hits = _apply_map(ct, mapping)
    for k in mapping:
        print(f"  {k} -> {mapping[k]}: {hits.get(k, 0)} reemplazo(s)")
    if not sum(hits.values()):
        raise SystemExit("Ninguna ancla coincidió; revise 'ct_tool.py info'.")
    ct.save(Path(a.out))
    print(f"Guardado: {a.out}")


# --------------------------------------------------------------------------------------
# Resolver AOB + respaldo
# --------------------------------------------------------------------------------------
LUA_RESOLVER = r'''[ENABLE]
{$lua}
if syntaxcheck then return end
-- =====================================================================================
-- Resolver de bases generado por ct_tool.py (skill cheat-engine-tables)
-- Estrategia: 1) AOB dentro del módulo -> resolver dirección RIP-relativa
--             2) Si el AOB falla (0 o >1 destinos distintos) -> offset estático de respaldo
-- Resultado en la tabla global CT_RESOLVER (consultar con showMessage; print() va a Memory View > Tools > Lua Engine)
-- =====================================================================================
local MODULE = "%(module)s"
local BASES = {
%(bases)s
}

local function aobInModule(mod, aob)
  local base = getAddressSafe(mod)
  local size = getModuleSize(mod)
  if base == nil or base == 0 or size == nil then return nil end
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtByteArray, rtRounded, aob, nil, base, base + size,
               "", fsmNotAligned, "1", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms)
  fl.initialize()
  local hits = {}
  for i = 0, fl.Count - 1 do hits[#hits + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return hits
end

local function ripTarget(hit, disp, len)
  local d = readInteger(hit + disp)
  if d == nil then return nil end
  if d >= 0x80000000 then d = d - 0x100000000 end
  return hit + len + d
end

local modBase = getAddressSafe(MODULE)
if modBase == nil or modBase == 0 then
  error("[Resolver] Módulo no encontrado: " .. MODULE .. " (¿proceso adjuntado?)")
end
local modEnd = modBase + getModuleSize(MODULE)

CT_RESOLVER = {}
local report = {}
for _, b in ipairs(BASES) do
  local addr, how = nil, nil
  -- Lista de firmas candidatas (se prueba en orden; gana la primera inequívoca)
  local cands = b.aobs or {}
  if b.aob and b.aob ~= "" then table.insert(cands, 1, { aob = b.aob, disp = b.disp, len = b.len }) end
  local fails = {}
  for i, c in ipairs(cands) do
    local hits = aobInModule(MODULE, c.aob) or {}
    local targets, uniq = {}, {}
    for _, h in ipairs(hits) do
      local t = ripTarget(h, c.disp, c.len)
      if t and not uniq[t] then uniq[t] = true; targets[#targets + 1] = t end
    end
    if #targets == 1 and targets[1] >= modBase and targets[1] < modEnd then
      addr, how = targets[1], string.format("AOB #%%d de %%d (%%d coincidencia/s)", i, #cands, #hits)
      break
    end
    fails[#fails + 1] = string.format("#%%d:%%d/%%d", i, #hits, #targets)
  end
  if addr == nil and #cands > 0 then
    how = "AOB falló (" .. table.concat(fails, " ") .. ")"
  end
  if addr == nil and b.fallback then
    addr = modBase + b.fallback
    how = (how and (how .. " -> ") or "") .. "RESPALDO estático"
  end
  if addr then
    registerSymbol(b.symbol, addr, true)
    local ok = readQword(addr) ~= nil
    CT_RESOLVER[b.symbol] = { address = addr, method = how, readable = ok }
    report[#report + 1] = string.format("%%-16s = %%s+%%X  [%%s]%%s", b.symbol, MODULE,
                                        addr - modBase, how, ok and "" or "  (NO LEGIBLE)")
  else
    report[#report + 1] = string.format("%%-16s = NO RESUELTO [%%s]", b.symbol, how or "sin AOB ni respaldo")
  end
end
print("[Resolver] " .. os.date("%%Y-%%m-%%d %%H:%%M:%%S"))
for _, l in ipairs(report) do print("  " .. l) end
{$asm}

[DISABLE]
{$lua}
if syntaxcheck then return end
%(unregister)s
CT_RESOLVER = nil
{$asm}
'''


def build_resolver_script(cfg: dict) -> str:
    lines, unreg = [], []
    for b in cfg["bases"]:
        # "aobs": [{"aob","disp_offset","instr_len"}, ...]  o el formato simple "aob"/"disp_offset"/"instr_len"
        cands = list(b.get("aobs") or [])
        if (b.get("aob") or "").strip():
            cands.insert(0, {"aob": b["aob"], "disp_offset": b.get("disp_offset", 3),
                             "instr_len": b.get("instr_len", 7)})
        aobs_lua = ", ".join(
            f'{{ aob = "{c["aob"].strip()}", disp = {int(c.get("disp_offset", 3))}, len = {int(c.get("instr_len", 7))} }}'
            for c in cands)
        fb = b.get("fallback_offset")
        fb_lua = f"0x{int(str(fb), 16):X}" if fb not in (None, "") else "nil"
        note = b.get("note", "")
        lines.append(
            f'  {{ symbol = "{b["symbol"]}", fallback = {fb_lua},'
            + (f"  -- {note}" if note else "")
            + f'\n    aobs = {{ {aobs_lua} }} }},'
        )
        unreg.append(f'unregisterSymbol("{b["symbol"]}")')
    return LUA_RESOLVER % {"module": cfg["module"], "bases": "\n".join(lines),
                           "unregister": "\n".join(unreg)}


def _new_entry(parent_container: ET.Element, idx: int, entry_id: int, desc: str) -> ET.Element:
    ce = parent_container.find("CheatEntries")
    if ce is None:
        ce = ET.SubElement(parent_container, "CheatEntries")
    el = ET.Element("CheatEntry")
    ET.SubElement(el, "ID").text = str(entry_id)
    ET.SubElement(el, "Description").text = f'"{desc}"'
    ce.insert(idx, el)
    return el


def cmd_resolve(a):
    ct = CheatTable(Path(a.file))
    cfg = json.loads(Path(a.config).read_text(encoding="utf-8"))
    script = build_resolver_script(cfg)
    desc = cfg.get("description", f"{RESOLVER_TAG} Bases del juego — activar primero")

    # 1) Reemplazar anclas por símbolos
    mapping = {norm_addr(b["replaces"]): b["symbol"] for b in cfg["bases"] if b.get("replaces")}
    hits = _apply_map(ct, mapping)
    for k, sym in mapping.items():
        print(f"  ancla {k} -> {sym}: {hits.get(k, 0)} reemplazo(s)")

    # 2) Crear o actualizar el script resolver
    existing = [e for e in ct.entries if e.is_script and e.desc.startswith(RESOLVER_TAG)]
    if existing:
        el = existing[0].elem
        el.find("AssemblerScript").text = script
        el.find("Description").text = f'"{desc}"'
        print(f"  Resolver existente actualizado (ID {existing[0].id}).")
    else:
        top_ce = ct.root.find("CheatEntries")
        # Insertar después de entradas utilitarias iniciales (p. ej. CompactMode)
        pos = 0
        for i, child in enumerate(top_ce.findall("CheatEntry")):
            d = (child.findtext("Description") or "").lower()
            if "compact" in d:
                pos = i + 1
        el = _new_entry(ct.root, pos, ct.max_id() + 1, desc)
        ET.SubElement(el, "VariableType").text = "Auto Assembler Script"
        ET.SubElement(el, "AssemblerScript").text = script
        print(f"  Resolver insertado en posición {pos} (ID {ct.max_id() + 1}).")
        if a.nest:
            # Mover como hijos del resolver las entradas raíz que usan los símbolos
            syms = {b["symbol"] for b in cfg["bases"]}
            opts = ET.Element("Options", {"moHideChildren": "1", "moDeactivateChildrenAsWell": "1"})
            el.insert(2, opts)
            child_ce = ET.SubElement(el, "CheatEntries")
            moved = 0
            for child in list(top_ce.findall("CheatEntry")):
                if child is el:
                    continue
                addr = (child.findtext("Address") or "").strip()
                if base_token(addr) in syms:
                    top_ce.remove(child)
                    child_ce.append(child)
                    moved += 1
            print(f"  {moved} grupo(s) raíz anidados bajo el resolver (se muestran al activarlo).")
    ct.save(Path(a.out))
    print(f"Guardado: {a.out}")


# --------------------------------------------------------------------------------------
# Validación
# --------------------------------------------------------------------------------------
def cmd_validate(a):
    ct = CheatTable(Path(a.file))
    errs, warns = [], []
    ids = Counter(e.id for e in ct.entries)
    for i, n in ids.items():
        if n > 1:
            errs.append(f"ID duplicado {i} ({n} veces)")
    syms = registered_symbols(ct)
    dd_names = {e.desc for e in ct.entries if e.elem.find("DropDownList") is not None}
    for e in ct.entries:
        addr = e.address
        if e.offsets_xml and not addr:
            errs.append(f"[{e.id}] {e.path}: tiene <Offsets> pero no <Address>")
        for o in e.offsets_xml:
            if not o:
                errs.append(f"[{e.id}] {e.path}: offset vacío")
            elif not HEX_RE.match(o.lstrip("+-")):
                warns.append(f"[{e.id}] {e.path}: offset no hexadecimal '{o}' (¿símbolo/expresión?)")
        if addr:
            if addr[0] in "+-":
                if not HEX_RE.match(addr[1:]):
                    warns.append(f"[{e.id}] {e.path}: dirección relativa no hex '{addr}'")
                if e.address_ancestor() is None:
                    errs.append(f"[{e.id}] {e.path}: dirección relativa '{addr}' sin ancestro con dirección")
            else:
                tok = base_token(addr)
                if tok and not is_module_name(tok) and not HEX_RE.match(tok) and tok not in syms:
                    errs.append(f"[{e.id}] {e.path}: símbolo '{tok}' no registrado en la tabla")
                if tok and is_module_name(tok):
                    warns.append(f"[{e.id}] {e.path}: ancla estática '{addr}' (frágil ante parches)")
        link = e.elem.findtext("DropDownListLink")
        if link and link.strip() not in dd_names:
            errs.append(f"[{e.id}] {e.path}: DropDownListLink '{link}' no existe")
        if e.is_script:
            src = e.elem.findtext("AssemblerScript") or ""
            if "[ENABLE]" not in src.upper() or "[DISABLE]" not in src.upper():
                errs.append(f"[{e.id}] {e.path}: script AA sin [ENABLE]/[DISABLE]")
            if "{$lua}" in src.lower() and src.lower().count("{$lua}") != src.lower().count("{$asm}"):
                warns.append(f"[{e.id}] {e.path}: bloques {{$lua}} sin {{$asm}} de cierre")
        if not e.is_group and not e.is_script and not e.vtype and addr:
            warns.append(f"[{e.id}] {e.path}: entrada con dirección pero sin VariableType")
    # Resumen (las advertencias de ancla estática se agrupan)
    static = [w for w in warns if "ancla estática" in w]
    other = [w for w in warns if "ancla estática" not in w]
    print(f"Errores: {len(errs)}   Advertencias: {len(other)}   Anclas estáticas: {len(static)}")
    for x in errs:
        print("  ERROR  ", x)
    for x in other[: a.max]:
        print("  AVISO  ", x)
    if len(other) > a.max:
        print(f"  ... {len(other) - a.max} avisos más")
    for x in static:
        print("  ESTÁTICA", x)
    sys.exit(1 if errs else 0)


def cmd_diff(a):
    A, B = CheatTable(Path(a.a)), CheatTable(Path(a.b))
    ma = {e.id: e for e in A.entries}
    mb = {e.id: e for e in B.entries}
    only_a = sorted(set(ma) - set(mb), key=lambda x: int(x) if x.isdigit() else 0)
    only_b = sorted(set(mb) - set(ma), key=lambda x: int(x) if x.isdigit() else 0)
    changed = 0
    for i in sorted(set(ma) & set(mb), key=lambda x: int(x) if x.isdigit() else 0):
        ea, eb = ma[i], mb[i]
        diffs = []
        for name, fa, fb in (("desc", ea.desc, eb.desc), ("tipo", ea.vtype, eb.vtype),
                             ("addr", ea.address, eb.address),
                             ("offs", ea.offsets_applied, eb.offsets_applied),
                             ("ruta", ea.path if a.paths else "", eb.path if a.paths else "")):
            if fa != fb:
                diffs.append(f"{name}: {fa} -> {fb}")
        if diffs:
            changed += 1
            print(f"[{i}] {eb.path}")
            for d in diffs:
                print(f"      {d}")
    print(f"\nModificadas: {changed}   Solo en A: {len(only_a)}   Solo en B: {len(only_b)}")
    for i in only_a:
        print(f"  - [{i}] {ma[i].path}")
    for i in only_b:
        print(f"  + [{i}] {mb[i].path}")


# --------------------------------------------------------------------------------------
def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)

    s = sp.add_parser("info"); s.add_argument("file"); s.set_defaults(fn=cmd_info)
    s = sp.add_parser("tree"); s.add_argument("file"); s.add_argument("--depth", type=int, default=99)
    s.add_argument("--filter"); s.set_defaults(fn=cmd_tree)
    s = sp.add_parser("chains"); s.add_argument("file"); s.add_argument("--csv"); s.add_argument("--filter")
    s.set_defaults(fn=cmd_chains)
    s = sp.add_parser("rebase"); s.add_argument("file"); s.add_argument("--map", action="append", required=True,
                                                                       help='"mod.exe"+OLD=mod.exe+NEW (repetible)')
    s.add_argument("-o", "--out", required=True); s.set_defaults(fn=cmd_rebase)
    s = sp.add_parser("resolve"); s.add_argument("file"); s.add_argument("--config", required=True)
    s.add_argument("--nest", action="store_true", help="anidar grupos dependientes bajo el resolver")
    s.add_argument("-o", "--out", required=True); s.set_defaults(fn=cmd_resolve)
    s = sp.add_parser("validate"); s.add_argument("file"); s.add_argument("--max", type=int, default=40)
    s.set_defaults(fn=cmd_validate)
    s = sp.add_parser("diff"); s.add_argument("a"); s.add_argument("b")
    s.add_argument("--paths", action="store_true", help="informar también cambios de ruta (reanidado)")
    s.set_defaults(fn=cmd_diff)

    a = p.parse_args(argv)
    a.fn(a)


if __name__ == "__main__":
    main()
