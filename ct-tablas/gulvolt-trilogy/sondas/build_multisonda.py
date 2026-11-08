#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_multisonda.py — Genera multisonda_gv1.CT (sondas de diagnóstico para GV1 en la Trilogy).
Incrusta multisonda_gv1.lua y sonda_invencibilidad_gv1.lua en scripts de la tabla.
Licencia: PolyForm Noncommercial 1.0.0."""
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
SITES = [(0x90D41, "r8", "4C 8B 83 D8 03 00 00", "mov r8,[rbx+3D8]"),
         (0x91494, "r8", "4C 8B 81 D8 03 00 00", "mov r8,[rcx+3D8]"),
         (0x915FA, "r8", "4C 8B 81 D8 03 00 00", "mov r8,[rcx+3D8]"),
         (0x91899, "r8", "4C 8B 81 D8 03 00 00", "mov r8,[rcx+3D8]"),
         (0x91A8E, "r9", "4C 8B 89 D8 03 00 00", "mov r9,[rcx+3D8]"),
         (0x1A2729, "r8", "4C 8B 80 D8 03 00 00", "mov r8,[rax+3D8]"),
         (0x1AAB62, "r8", "4C 8B 87 D8 03 00 00", "mov r8,[rdi+3D8]")]

CAPTURA = r"""{ Sonda 1 — Captura del jugador (sin depurador)
  Engancha la rutina que recalcula HP/HP máx. (la misma zona que usa ndck1, 7 bytes antes,
  así que pueden convivir). Guarda:
    gv1_player = objeto del personaje (rdi)   gv1_hp = su componente de vida ([rdi+3D8])
    gv1_last   = último componente visto (cualquier personaje)
  Solo guarda gv1_player/gv1_hp cuando el byte +18 del componente vale 1 (jugador).
  El AOB tolera que la zona ya esté parchada (por esta sonda tras recargar la tabla, o por ndck1). }
[ENABLE]
aobscanmodule(gv1cap,game1.exe,F6 47 26 04 74 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 45 8B C8 44 0F 4E CD)
alloc(gv1cap_mem,$200,gv1cap)
label(gv1cap_ret)
label(gv1_player)
label(gv1_hp)
label(gv1_last)
registersymbol(gv1cap)
registersymbol(gv1_player)
registersymbol(gv1_hp)
registersymbol(gv1_last)

gv1cap_mem:
  mov rcx,[rdi+3D8]
  test rcx,rcx
  je @f
  mov [gv1_last],rcx
  cmp byte ptr [rcx+18],1
  jne @f
  mov [gv1_player],rdi
  mov [gv1_hp],rcx
@@:
  jmp gv1cap_ret
align 8
gv1_player:
  dq 0
gv1_hp:
  dq 0
gv1_last:
  dq 0

gv1cap+6:
  jmp gv1cap_mem
  nop 2
gv1cap_ret:

[DISABLE]
gv1cap+6:
  db 48 8B 8F D8 03 00 00
unregistersymbol(gv1cap)
unregistersymbol(gv1_player)
unregistersymbol(gv1_hp)
unregistersymbol(gv1_last)
dealloc(gv1cap_mem)
"""


ENSURE_C = """if not getAddressSafe("gv1_hp") then
  local r = getAddressList().getMemoryRecordByDescription("Captura jugador (base de los trucos; se activa sola)")
  if r and not r.Active then r.Active = true end
end
if not getAddressSafe("gv1_hp") then error("No se pudo activar 'Captura jugador'. Entra a un nivel.") end"""


def contador():
    L = ["{ Sonda 2 — Contador de daño: 7 sitios que restan HP. 'jugador' = víctima es [gv1_hp].",
         "  Activa sola la Captura jugador si hace falta. Aborta si los bytes no son los originales (build 2026-10-07) ni un jmp de una activación anterior. }",
         "[ENABLE]"]
    L += ["{$lua}", "if syntaxcheck then return end", ENSURE_C, "local base = getAddress('game1.exe')", "local SITES = {"]
    L += [f"  {{0x{s:X}, '{b}'}}," for s, _, b, _ in SITES]
    L += ["}",
          "for _, st in ipairs(SITES) do",
          "  local t = readBytes(base + st[1], 7, true) or {}",
          "  local h = {}",
          "  for i = 1, #t do h[i] = string.format('%02X', t[i]) end",
          "  local hs = table.concat(h, ' ')",
          "  if hs ~= st[2] and t[1] ~= 0xE9 then",
          "    error(string.format('Bytes inesperados en game1.exe+%X: %s (¿otra build?)', st[1], hs))",
          "  end",
          "end",
          "{$asm}"]
    L += ["alloc(sonda_mem,$1000,game1.exe)", "label(cnt_tab)", "registersymbol(cnt_tab)"]
    L += [f"label(hook_{i})" for i in range(len(SITES))]
    L.append("\nsonda_mem:")
    for i, (s, R, b, ins) in enumerate(SITES):
        L.append(f"""hook_{i}:
  {ins}
  pushfq
  push rax
  lock inc dword ptr [cnt_tab+{i*8+4:X}]
  mov rax,[gv1_hp]
  cmp {R},rax
  jne @f
  lock inc dword ptr [cnt_tab+{i*8:X}]
@@:
  pop rax
  popfq
  jmp game1.exe+{s+7:X}
""")
    L.append("align 10\ncnt_tab:\n  dd 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n")
    for i, (s, *_r) in enumerate(SITES):
        L.append(f"game1.exe+{s:X}:\n  jmp hook_{i}\n  nop 2\n")
    L.append("[DISABLE]")
    for s, _, b, _ in SITES:
        L.append(f"game1.exe+{s:X}:\n  db {b}")
    L.append("unregistersymbol(cnt_tab)\ndealloc(sonda_mem)")
    return "\n".join(L) + "\n"


def lua_wrap(path: Path) -> str:
    code = path.read_text(encoding="utf-8")
    return "[ENABLE]\n{$lua}\nif syntaxcheck then return end\n" + code + "\n{$asm}\n[DISABLE]\n"


nid = 0
def new(parent, desc, color=None):
    global nid
    nid += 1
    e = ET.SubElement(parent, "CheatEntry")
    ET.SubElement(e, "ID").text = str(nid)
    ET.SubElement(e, "Description").text = f'"{desc}"'
    if color:
        ET.SubElement(e, "Color").text = color
    return e


def script(parent, desc, src, color="008000"):
    e = new(parent, desc, color)
    ET.SubElement(e, "VariableType").text = "Auto Assembler Script"
    ET.SubElement(e, "AssemblerScript").text = src
    return e


def ptr(parent, desc, sym, off, vt="4 Bytes"):
    e = new(parent, desc)
    ET.SubElement(e, "ShowAsSigned").text = "0"
    ET.SubElement(e, "VariableType").text = vt
    ET.SubElement(e, "Address").text = sym
    o = ET.SubElement(e, "Offsets")
    ET.SubElement(o, "Offset").text = f"{off:X}"
    return e



ENSURE = """if not getAddressSafe("gv1_hp") then
  local r = getAddressList().getMemoryRecordByDescription("Captura jugador (base de los trucos; se activa sola)")
  if r and not r.Active then r.Active = true end
end
if not getAddressSafe("gv1_hp") then error("No se pudo activar 'Captura jugador'. Entra a un nivel.") end
"""

CAP = "Captura jugador (base de los trucos; se activa sola)"


def rd(name):
    return (HERE / name).read_text(encoding="utf-8")


def lua_onoff(on: str, off: str) -> str:
    return ("[ENABLE]\n{$lua}\nif syntaxcheck then return end\n" + on +
            "\n{$asm}\n[DISABLE]\n{$lua}\nif syntaxcheck then return end\n" + off + "\n{$asm}\n")


def group(parent, desc, color=None):
    g = new(parent, desc, color)
    ET.SubElement(g, "Options", {"moManualExpandCollapse": "1"})
    ET.SubElement(g, "GroupHeader").text = "1"
    return ET.SubElement(g, "CheatEntries")


def dword(parent, desc, addr, color=None, vt="4 Bytes"):
    e = new(parent, desc, color)
    ET.SubElement(e, "ShowAsSigned").text = "0"
    ET.SubElement(e, "VariableType").text = vt
    ET.SubElement(e, "Address").text = addr
    return e


MATS = [("Microantigenerador", "Microdegenerator", 3), ("Servocarga fotónica", "Custom Servophoton", 3),
        ("Cuasicristal espinela", "Spinel Quasicrystal", 3), ("Imán ultradenso", "Ultradense Magnet", 3),
        ("Resonador genómico", "Genomic Resonator", 3), ("Metal líquido en fase", "Phased Fluid Metal", 3),
        ("Calcedonia amarilla", "Yellow Chalcedony", 3), ("Pieza de Hihirogane", "Hihirogane Shard", 3),
        ("Motor de antigravedad", "Antigravity Engine", None), ("Mecanismo de propulsión", "Propulsion Mechanism", None),
        ("Mineral Fénix", "Phoenix Ore", None), ("Coraza de onda corta", "Shock Response Plate", None),
        ("Graym de 6 milagros", "Six-miracle Graym", None), ("Apoitagara", "Apoitagara", None),
        ("Extracto de graym 239", "Graym Extract 239", None), ("Graym electromotriz", "Electromotive Graym", None),
        ("Aleación Kripp", "Kripp Alloy", 0), ("Xiwidia", "Xiwidia", 1), ("Acero bambú", "Faraging Steel", 2),
        ("Nanochip 98", "Nanochip 98", 0), ("Protoinfraestructura", "Proto Infrastructure", 1),
        ("NcGbx de alto grado", "High-end NcGbx", 2), ("Granado", "Garnet", 0), ("Cuarcita", "Quartzite", 1),
        ("Electrum", "Electrum", 2), ("Cultivo de graym", "Graym Culture", 0), ("Polímero Gm238", "Polymer Gm238", 1),
        ("Cristal de uranio 235 (?)", "Uranium-235 Crystal", 2)]


root = ET.Element("CheatTable", {"CheatEngineTableVersion": "45"})
top = ET.SubElement(root, "CheatEntries")
note = new(top, "##GV1 (game1.exe) — los trucos activan solos lo que necesitan. Entra a un nivel antes.", "0000FF")
ET.SubElement(note, "GroupHeader").text = "1"

# ================================ TRUCOS ================================
T = group(top, "▶ GV1 — Trucos", "008000")

s1 = script(T, CAP, CAPTURA)
ch = ET.SubElement(s1, "CheatEntries")
ptr(ch, "HP actual (×16)", "gv1_hp", 0)
ptr(ch, "HP máximo (×16)", "gv1_hp", 4)
ptr(ch, "Daño del golpe en curso (+08)", "gv1_hp", 8)
ptr(ch, "Flag jugador (+18)", "gv1_hp", 0x18, "Byte")
ptr(ch, "Temporizador de invencibilidad (obj+518; 11520 = recién golpeado)", "gv1_player", 0x518)
ptr(ch, "Flag de golpe? (obj+528)", "gv1_player", 0x528)
ptr(ch, "Estado? (obj+3D0)", "gv1_player", 0x3D0)

script(T, "Invencibilidad (Sí/No)", lua_onoff(rd("invencible_gv1.lua"), rd("invencible_off_gv1.lua")), "008000")

combo_on = ("KUDOS_SILENCIO = true\nlocal okK, errK = pcall(function()\n" + rd("kudos_gv1.lua") +
            "\nend)\nKUDOS_SILENCIO = nil\nif not okK then print('[Prestigio] ' .. tostring(errK)) end\n" +
            rd("multiplicador_gv1.lua"))
combo_off = rd("multiplicador_off_gv1.lua") + "\n" + rd("kudos_off_gv1.lua")
kd = script(T, "Prestigio y EXP ×N / mantener Prestigio (localiza el Prestigio solo)", lua_onoff(combo_on, combo_off), "008000")
kch = ET.SubElement(kd, "CheatEntries")
dword(kch, "Prestigio en pantalla (solo lectura)", "gv1_kudos_vis")
dword(kch, "Prestigio interno ×256 (editar este: pantalla × 256)", "gv1_kudos")

mm = script(T, "Materiales al máximo (pide cantidad; desactivar = restaurar)",
            lua_onoff(rd("materiales_max_gv1.lua"), rd("materiales_restaurar_gv1.lua")), "008000")
mch = ET.SubElement(mm, "CheatEntries")
for nm, o in (("¿? Créditos+0x3A8 (NO es material)", 0), ("¿? Créditos+0x3AC (NO es material)", 4)):
    dword(mch, nm, f"game1.exe+{0x7B3668 + 0x3A8 + o:X}", "808080")
for i, (es, en, st) in enumerate(MATS):
    tag = "único" if st is None else ("★" * st if st else "0★")
    dword(mch, f"{es} [{tag}] ({en})", f"game1.exe+{0x7B3668 + 0x3B0 + 4*i:X}")

V = group(T, "Valores (estáticos en game1.exe, build 2026-10-07)")
dword(V, "Créditos (vig) — persiste al guardar", "game1.exe+7B3668")
dword(V, "Nivel? (Créditos+0x474, 2 B — verificar)", "game1.exe+7B3ADC", None, "2 Bytes")
dword(V, "Energía / PE (llena = 5000000; congelar = infinita)", "game1.exe+7ED64C")
dword(V, "Skill Points / PH (1 = 20000000; 3 = 60000000)", "game1.exe+7ED650")
for i in range(4):
    dword(V, f"Cooldown habilidad {i+1} (lista = 76800)", f"game1.exe+{0x7ED658 + 4*i:X}")
dword(V, "Copia del bloque de combate (+7ED67C) — ¿cuál manda? verificar", "game1.exe+7ED67C", "808080")

# ================================ HERRAMIENTAS ================================
H = group(top, "🔧 Sondas y herramientas de búsqueda", "808080")
s2 = script(H, "Contador de daño (7 sitios)", contador())
ch2 = ET.SubElement(s2, "CheatEntries")
for i, (sa, *_r) in enumerate(SITES):
    for k, lbl in ((0, "jugador"), (4, "total")):
        dword(ch2, f"Sitio {i} (game1.exe+{sa:X}) — {lbl}", f"cnt_tab+{i*8+k:X}")
script(H, "Multisonda: bloques de partida y combate (pide Créditos; Energía LLENA)", lua_wrap(HERE / "multisonda_gv1.lua"), "FF0000")
script(H, "Etiquetar materiales (99…72; desactivar = restaurar; NO guardar)",
       lua_onoff(rd("materiales_etiquetar_gv1.lua"), rd("materiales_etiquetar_restaurar_gv1.lua")), "0000FF")
script(H, "Sonda de invencibilidad (10 s de muestreo)", "[ENABLE]\n{$lua}\nif syntaxcheck then return end\n" + ENSURE + rd("sonda_invencibilidad_gv1.lua") + "\n{$asm}\n[DISABLE]\n", "FF0000")

ET.indent(root)
out = HERE / "multisonda_gv1.CT"
ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)
print("Generado:", out)
