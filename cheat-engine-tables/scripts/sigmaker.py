#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sigmaker.py — Genera y verifica firmas AOB (array of bytes) para bases estáticas x64.

Idea: un puntero estático "modulo.exe+RVA" casi siempre es leído por instrucciones con
direccionamiento RIP-relativo (p. ej. `mov rax,[rip+disp32]`). Este script:
  1) localiza en las secciones ejecutables todas las instrucciones cuyo destino RIP-relativo
     es exactamente la RVA indicada;
  2) construye, para cada una, la firma más corta que sea ÚNICA en el código, con comodines
     en el disp32 y en saltos/llamadas relativas (que cambian entre compilaciones);
  3) entrega disp_offset / instr_len para que el Resolver Lua recalcule la base en tiempo real.

Fuentes de entrada:
  * El .exe en disco (si no está empaquetado/cifrado).
  * Un volcado de memoria del módulo (--dump), guardado desde Cheat Engine con
    writeRegionToFile() — necesario si el ejecutable usa empaquetador/DRM.

Subcomandos:
  refs   Lista instrucciones que referencian la RVA.
  make   Genera firmas únicas (texto y JSON listo para resolvers.json).
  check  Verifica una firma: nº de coincidencias y RVA a la que resuelve.

Dependencias: pip install pefile capstone numpy --break-system-packages
"""
from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from dataclasses import dataclass

import numpy as np
import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, Cs
from capstone.x86 import X86_OP_MEM, X86_REG_RIP

IMAGE_SCN_MEM_EXECUTE = 0x20000000
PREFIXES = set(range(0x40, 0x50)) | {0x66, 0x67, 0xF0, 0xF2, 0xF3, 0x2E, 0x36, 0x3E, 0x26, 0x64, 0x65}


# --------------------------------------------------------------------------------------
# Imagen: mapeo RVA <-> bytes de secciones ejecutables
# --------------------------------------------------------------------------------------
@dataclass
class CodeSection:
    name: str
    rva: int
    data: bytes


class Image:
    def __init__(self, path: str, dump: bool = False):
        raw = open(path, "rb").read()
        self.sections: list[CodeSection] = []
        if dump:
            # Volcado "mapeado": el offset en el archivo == RVA.
            pe = pefile.PE(data=raw[:0x2000], fast_load=True)
            for s in pe.sections:
                if s.Characteristics & IMAGE_SCN_MEM_EXECUTE:
                    va, sz = s.VirtualAddress, max(s.Misc_VirtualSize, s.SizeOfRawData)
                    self.sections.append(CodeSection(s.Name.rstrip(b"\0").decode(errors="replace"),
                                                     va, raw[va:va + sz]))
            if not self.sections:  # cabecera dañada: tratar todo como código
                self.sections.append(CodeSection("dump", 0, raw))
        else:
            pe = pefile.PE(data=raw, fast_load=True)
            if pe.FILE_HEADER.Machine != 0x8664:
                sys.exit("Solo se soportan binarios x64 (AMD64).")
            for s in pe.sections:
                if s.Characteristics & IMAGE_SCN_MEM_EXECUTE:
                    self.sections.append(CodeSection(s.Name.rstrip(b"\0").decode(errors="replace"),
                                                     s.VirtualAddress, s.get_data()))
        if not self.sections:
            sys.exit("No se encontraron secciones ejecutables.")
        self.md = Cs(CS_ARCH_X86, CS_MODE_64)
        self.md.detail = True

    def disasm_one(self, sec: CodeSection, off: int):
        for ins in self.md.disasm(sec.data[off:off + 16], sec.rva + off, count=1):
            return ins
        return None


# --------------------------------------------------------------------------------------
# Búsqueda de referencias RIP-relativas
# --------------------------------------------------------------------------------------
def find_refs(img: Image, target_rva: int):
    """Devuelve [(sección, offset_instr, instrucción, disp_offset)]."""
    out = []
    for sec in img.sections:
        buf = sec.data
        n = len(buf)
        if n < 8:
            continue
        cand = set()
        for align in range(4):
            cnt = (n - align) // 4
            d = np.frombuffer(buf, dtype="<i4", count=cnt, offset=align).astype(np.int64)
            pos = align + 4 * np.arange(cnt, dtype=np.int64)
            # fin de instrucción = pos+4 (+0/1/2/4 bytes de inmediato)
            for extra in (0, 1, 2, 4):
                hit = np.nonzero(sec.rva + pos + 4 + extra + d == target_rva)[0]
                cand.update(int(pos[i]) for i in hit)
        for p in sorted(cand):
            # El disp32 empieza en p; la instrucción comienza 2..7 bytes antes.
            valid = {}
            for back in range(2, 8):
                start = p - back
                if start < 0:
                    continue
                ins = img.disasm_one(sec, start)
                if ins is None or ins.disp_offset != back:
                    continue
                for op in ins.operands:
                    if (op.type == X86_OP_MEM and op.mem.base == X86_REG_RIP
                            and ins.address + ins.size + op.mem.disp == target_rva):
                        valid[back] = ins
            if not valid:
                continue
            # Preferir la decodificación más larga cuyos bytes extra sean solo prefijos
            # (REX 40-4F, 66, 67, F0, F2, F3, segmentos): evita perder el REX.W (48).
            bmin = min(valid)
            best = bmin
            for back in sorted(valid, reverse=True):
                extra = sec.data[p - back:p - bmin]
                rex = [b for b in extra if 0x40 <= b <= 0x4F]
                # Válido: solo prefijos, a lo sumo un REX y, si existe, justo antes del opcode
                if all(b in PREFIXES for b in extra) and len(rex) <= 1 and \
                        (not rex or extra[-1] == rex[0]) and \
                        not (rex and 0x40 <= sec.data[p - bmin] <= 0x4F):
                    best = back
                    break
            out.append((sec, p - best, valid[best], best))
    return out


# --------------------------------------------------------------------------------------
# Construcción de firmas
# --------------------------------------------------------------------------------------
def wildcard_mask(ins) -> list[bool]:
    """True = byte variable (comodín) dentro de la instrucción."""
    mask = [False] * ins.size
    # disp de memoria RIP-relativa o desplazamiento grande
    if ins.disp_size and ins.disp_offset:
        rip = any(op.type == X86_OP_MEM and op.mem.base == X86_REG_RIP for op in ins.operands)
        if rip or ins.disp_size == 4:
            for i in range(ins.disp_offset, ins.disp_offset + ins.disp_size):
                mask[i] = True
    # saltos/llamadas relativas (rel32) e inmediatos de 4+ bytes que parecen direcciones
    grp = {g for g in ins.groups}
    is_branch = ins.mnemonic.startswith("j") or ins.mnemonic in ("call", "jmp")
    if ins.imm_size and ins.imm_offset:
        if is_branch:  # rel8 y rel32: cambian entre compilaciones
            for i in range(ins.imm_offset, ins.imm_offset + ins.imm_size):
                mask[i] = True
    _ = grp
    return mask


def to_aob(data: bytes, mask: list[bool]) -> str:
    return " ".join("??" if m else f"{b:02X}" for b, m in zip(data, mask))


def aob_regex(aob: str) -> re.Pattern:
    parts = []
    for tok in aob.split():
        parts.append(b"." if "?" in tok or "*" in tok or tok.lower() == "x" else re.escape(bytes([int(tok, 16)])))
    return re.compile(b"".join(parts), re.DOTALL)


def count_matches(img: Image, aob: str, limit: int = 50):
    rx = aob_regex(aob)
    hits = []
    for sec in img.sections:
        for m in rx.finditer(sec.data):
            hits.append((sec, m.start()))
            if len(hits) >= limit:
                return hits
    return hits


def build_signature(img: Image, sec: CodeSection, start: int, min_len: int, max_len: int):
    """Extiende instrucción a instrucción desde 'start' hasta que la firma sea única."""
    data, mask = b"", []
    off = start
    first = None
    while len(data) < max_len:
        ins = img.disasm_one(sec, off)
        if ins is None:
            break
        if first is None:
            first = ins
        data += bytes(ins.bytes)
        mask += wildcard_mask(ins)
        off += ins.size
        if len(data) >= min_len:
            aob = to_aob(data, mask)
            if len(count_matches(img, aob, limit=2)) == 1:
                return aob, first, True
        if ins.mnemonic in ("ret", "int3", "jmp") and len(data) >= min_len:
            break
    return to_aob(data, mask), first, False


def build_signature_backward(img: Image, sec: CodeSection, start: int, min_len: int, max_len: int):
    """Alternativa: incluir bytes previos (prefijo) cuando la firma hacia adelante no es única.
    Devuelve (aob, delta) donde delta = bytes antes de la instrucción objetivo."""
    for pre in range(4, max_len, 2):
        s = start - pre
        if s < 0:
            break
        # Alinear al inicio de una instrucción válida que termine exactamente en 'start'
        ok_start = None
        for back in range(pre, pre + 8):
            s2 = start - back
            if s2 < 0:
                break
            o, valid = s2, True
            while o < start:
                ins = img.disasm_one(sec, o)
                if ins is None:
                    valid = False
                    break
                o += ins.size
            if valid and o == start:
                ok_start = s2
                break
        if ok_start is None:
            continue
        data, mask, o = b"", [], ok_start
        while o < start + min_len:
            ins = img.disasm_one(sec, o)
            if ins is None:
                break
            data += bytes(ins.bytes)
            mask += wildcard_mask(ins)
            o += ins.size
        aob = to_aob(data, mask)
        if len(count_matches(img, aob, limit=2)) == 1:
            return aob, start - ok_start
    return None, 0


# --------------------------------------------------------------------------------------
# Subcomandos
# --------------------------------------------------------------------------------------
def parse_int(s: str) -> int:
    s = s.strip().replace('"', "")
    if "+" in s:  # admite "modulo.exe+0E120A40"
        s = s.split("+")[-1]
    return int(s, 16) if not s.lower().startswith("0x") else int(s, 0)


def cmd_refs(a):
    img = Image(a.file, a.dump)
    rva = parse_int(a.rva)
    refs = find_refs(img, rva)
    print(f"Referencias RIP-relativas a RVA 0x{rva:X}: {len(refs)}")
    for sec, off, ins, dpo in refs:
        print(f"  {sec.name}+{off:X} (RVA {ins.address:X})  {ins.bytes.hex(' ').upper():32s} "
              f"{ins.mnemonic} {ins.op_str}   disp@+{dpo}")


def cmd_make(a):
    img = Image(a.file, a.dump)
    rva = parse_int(a.rva)
    refs = find_refs(img, rva)
    if not refs:
        sys.exit(f"Sin referencias a RVA 0x{rva:X}. ¿Ejecutable empaquetado? Pruebe con --dump.")
    results = []
    for sec, off, ins, dpo in refs[: a.max_refs]:
        aob, first, uniq = build_signature(img, sec, off, a.min_len, a.max_len)
        entry = {"rva_instr": f"{ins.address:X}", "asm": f"{ins.mnemonic} {ins.op_str}",
                 "aob": aob, "disp_offset": dpo, "instr_len": ins.size, "unique": uniq,
                 "length": len(aob.split())}
        if not uniq:
            baob, delta = build_signature_backward(img, sec, off, a.min_len, a.max_len)
            if baob:
                entry.update(aob=baob, disp_offset=dpo + delta, instr_len=ins.size + delta,
                             unique=True, length=len(baob.split()), note=f"incluye {delta} bytes previos")
        results.append(entry)
    results.sort(key=lambda r: (not r["unique"], r["length"]))
    for r in results:
        flag = "ÚNICA" if r["unique"] else "NO única"
        print(f"[{flag}] RVA {r['rva_instr']}  {r['asm']}")
        print(f"   AOB: {r['aob']}")
        print(f"   disp_offset={r['disp_offset']}  instr_len={r['instr_len']}  ({r['length']} bytes)"
              + (f"  — {r['note']}" if r.get("note") else ""))
    best = next((r for r in results if r["unique"]), None)
    if best:
        snippet = {"symbol": a.symbol or "base", "replaces": a.replaces or f"<modulo>+{rva:X}",
                   "aob": best["aob"], "disp_offset": best["disp_offset"],
                   "instr_len": best["instr_len"], "fallback_offset": f"{rva:X}",
                   "note": f"{best['asm']} @RVA {best['rva_instr']}"}
        print("\nFragmento para resolvers.json:")
        print(json.dumps(snippet, ensure_ascii=False, indent=2))
        if a.json:
            with open(a.json, "w", encoding="utf-8") as fh:
                json.dump({"best": snippet, "all": results}, fh, ensure_ascii=False, indent=2)
            print(f"Guardado: {a.json}")


def cmd_check(a):
    img = Image(a.file, a.dump)
    hits = count_matches(img, a.aob, limit=100)
    print(f"Coincidencias: {len(hits)}")
    targets = set()
    for sec, off in hits:
        p = off + a.disp_offset
        disp = struct.unpack_from("<i", sec.data, p)[0]
        t = sec.rva + off + a.instr_len + disp
        targets.add(t)
        print(f"  {sec.name}+{off:X} (RVA {sec.rva + off:X}) -> base RVA 0x{t:X}")
    if len(targets) == 1:
        print(f"OK: resuelve de forma inequívoca a RVA 0x{targets.pop():X}")
    else:
        print("ATENCIÓN: 0 o múltiples destinos; la firma no es utilizable tal cual.")
        sys.exit(1)


def secname(sct) -> str:
    return sct.Name.rstrip(b"\0").decode(errors="replace")


def cmd_peinfo(a):
    """Huella de la build: sirve para documentar en la tabla a qué versión corresponde."""
    import datetime
    import hashlib
    raw = open(a.file, "rb").read()
    pe = pefile.PE(data=raw, fast_load=True)
    ts = pe.FILE_HEADER.TimeDateStamp
    print(f"Archivo:        {a.file}")
    print(f"SHA-256:        {hashlib.sha256(raw).hexdigest()}")
    print(f"TimeDateStamp:  0x{ts:08X}  ({datetime.datetime.fromtimestamp(ts, datetime.timezone.utc):%Y-%m-%d %H:%M:%S} UTC)")
    print(f"SizeOfImage:    0x{pe.OPTIONAL_HEADER.SizeOfImage:X}")
    print(f"EntryPoint RVA: 0x{pe.OPTIONAL_HEADER.AddressOfEntryPoint:X}")
    for sct in pe.sections:
        print(f"  {secname(sct):8s} RVA 0x{sct.VirtualAddress:08X} "
              f"VSize 0x{sct.Misc_VirtualSize:08X} Raw 0x{sct.SizeOfRawData:08X} Ch 0x{sct.Characteristics:08X}")
    try:
        pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]])
        for fi in getattr(pe, "FileInfo", []) or []:
            for st in fi:
                for tbl in getattr(st, "StringTable", []):
                    for k, v in tbl.entries.items():
                        if k in (b"FileVersion", b"ProductVersion", b"ProductName"):
                            print(f"{k.decode():15s} {v.decode(errors='replace')}")
    except Exception as exc:  # recursos ausentes o dañados
        print(f"(sin VERSIONINFO legible: {exc})")
    # Pista de empaquetado: secciones con nombres típicos o entropía alta en código
    names = {secname(sct).lower() for sct in pe.sections}
    sus = names & {".bind", ".arch", ".vmp0", ".vmp1", ".themida", ".enigma1", ".winlice", ".boot"}
    for sct in pe.sections:
        if sct.Characteristics & IMAGE_SCN_MEM_EXECUTE and sct.get_entropy() > 7.2:
            sus.add(f"{secname(sct)} (entropía {sct.get_entropy():.2f})")
    if sus:
        print("POSIBLE EMPAQUETADO/DRM:", ", ".join(sorted(sus)), "-> use un volcado de memoria (--dump)")


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--dump", action="store_true", help="el archivo es un volcado de memoria del módulo")
    sp = p.add_subparsers(dest="cmd", required=True)
    _add = sp.add_parser
    sp.add_parser = lambda name, **kw: _add(name, parents=[common], **kw)
    s = sp.add_parser("peinfo"); s.add_argument("file"); s.set_defaults(fn=cmd_peinfo)
    s = sp.add_parser("refs"); s.add_argument("file"); s.add_argument("--rva", required=True); s.set_defaults(fn=cmd_refs)
    s = sp.add_parser("make"); s.add_argument("file"); s.add_argument("--rva", required=True)
    s.add_argument("--symbol"); s.add_argument("--replaces"); s.add_argument("--json")
    s.add_argument("--min-len", type=int, default=12); s.add_argument("--max-len", type=int, default=48)
    s.add_argument("--max-refs", type=int, default=30); s.set_defaults(fn=cmd_make)
    s = sp.add_parser("check"); s.add_argument("file"); s.add_argument("--aob", required=True)
    s.add_argument("--disp-offset", type=int, required=True); s.add_argument("--instr-len", type=int, required=True)
    s.set_defaults(fn=cmd_check)
    a = p.parse_args(argv)
    a.fn(a)


if __name__ == "__main__":
    main()
