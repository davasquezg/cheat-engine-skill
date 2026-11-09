#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gv3.py — Grupo de GV3 (game3.exe) para la tabla alfa de la trilogía. Lo usa ../build_trilogia_alpha.py.
Base de wepon1984 hallada en la build 2026-10-13: game3.exe+1F02FE8 (ANALISIS §9.2–9.3).
Incrusta los .lua *_gv3 de esta carpeta. Licencia: PolyForm Noncommercial 1.0.0."""
import xml.etree.ElementTree as ET

import build_multisonda as bm

BASE = "game3.exe+1F02FE8"
VERDE, GRIS = "008000", "808080"


def cadena(parent, desc, offs, vt="4 Bytes", color=None):
    """Entrada con puntero desde BASE; offs en orden de APLICACIÓN (en el XML van al revés)."""
    e = bm.new(parent, desc, color)
    ET.SubElement(e, "ShowAsSigned").text = "0"
    ET.SubElement(e, "VariableType").text = vt
    ET.SubElement(e, "Address").text = BASE
    o = ET.SubElement(e, "Offsets")
    for off in reversed(offs):
        ET.SubElement(o, "Offset").text = f"{off:X}"
    return e


VIDA = r"""{ Vida de GV3 (captura propia; reemplaza al «Health» de wepon1984 / RTX_XXXX, misma AOB y lógica).
  Engancha la escritura del HP (movss [rcx+08],xmm0; HP float, máx. en +0C) en game3.exe+8B5B62, que el juego
  ejecuta al recibir o curar daño. El jugador es el componente con [rcx+20] = 1 (sonda v3, 2026-11-08):
    gv3_hp  = componente de vida del jugador (lo captura en cada golpe)
    gv3_god = 1 → el HP del jugador queda en su máximo (vida infinita)
    gv3_1hk = 1 → los demás (enemigos) quedan con 0 HP al recibir daño (One Hit Kill)
  No usar a la vez que el «Health» de wepon1984: los dos parchan la misma instrucción. }
[ENABLE]
aobscanmodule(gv3vida,game3.exe,F3 0F 11 41 08 83 49 18 01 C3 0F)
alloc(gv3vida_mem,$200,gv3vida)
label(gv3vida_ret)
label(gv3vida_normal)
label(gv3vida_enemigo)
label(gv3vida_fin)
label(gv3_hp)
label(gv3_god)
label(gv3_1hk)
registersymbol(gv3vida)
registersymbol(gv3_hp)
registersymbol(gv3_god)
registersymbol(gv3_1hk)

gv3vida_mem:
  cmp dword ptr [rcx+20],1
  jne gv3vida_enemigo
  mov [gv3_hp],rcx
  cmp dword ptr [gv3_god],0
  je gv3vida_normal
  movss xmm0,[rcx+0C]
gv3vida_normal:
  movss [rcx+08],xmm0
  jmp gv3vida_ret
gv3vida_enemigo:
  movss [rcx+08],xmm0
  cmp dword ptr [gv3_1hk],0
  je gv3vida_fin
  mov dword ptr [rcx+08],0
gv3vida_fin:
  jmp gv3vida_ret
align 8
gv3_hp:
  dq 0
gv3_god:
  dd 0
gv3_1hk:
  dd 0

gv3vida:
  jmp gv3vida_mem
gv3vida_ret:

[DISABLE]
gv3vida:
  db F3 0F 11 41 08
unregistersymbol(gv3vida)
unregistersymbol(gv3_hp)
unregistersymbol(gv3_god)
unregistersymbol(gv3_1hk)
dealloc(gv3vida_mem)
"""


def gv3_trucos(G):
    """Trucos de GV3 rescatados de wepon1984 con la base nueva + multiplicadores con listas desplegables.
    La invencibilidad aún no está: jugador+0x592 resultó ser la cámara lenta (se busca con la sonda)."""
    T = bm.group(G, "▶ GV3 — Trucos (build 2026-10-13)", VERDE)

    vida = bm.script(T, "Vida: infinita / One Hit Kill — ❌ no protege (¿HP de la interfaz?; ver ANALISIS §9.10)",
                     VIDA, VERDE)
    vch = ET.SubElement(vida, "CheatEntries")
    bm.lista(vch, "Vida infinita (el HP vuelve al máximo al recibir daño)", "gv3_god", bm.SINO)
    bm.lista(vch, "One Hit Kill (enemigos con 0 HP al recibir daño)", "gv3_1hk", bm.SINO)
    bm.ptr(vch, "HP del jugador (float)", "gv3_hp", 8, "Float")
    bm.ptr(vch, "HP máximo (float)", "gv3_hp", 0xC, "Float")
    bm.ptr(vch, "Marca de jugador [+20] (1 = jugador)", "gv3_hp", 0x20)

    lenta = bm.script(T, "Cámara lenta (Sí/No) — efecto del golpe; NO es invencibilidad",
                      bm.lua_onoff(bm.rd("camara_lenta_gv3.lua"), bm.rd("camara_lenta_off_gv3.lua")), VERDE)
    lch = ET.SubElement(lenta, "CheatEntries")
    cadena(lch, "Cámara lenta (float, jugador+0x590; ~57 tras un golpe)", [0x10, 0x10, 0x590], "Float")
    cadena(lch, "¿Estado del golpe? (jugador+0x594; 255 en reposo)", [0x10, 0x10, 0x594], "2 Bytes", GRIS)

    xp = bm.script(T, "EXP ×N — ❌ NO sube el nivel (EXP de wepon1984 no es la real; ver «Sonda de EXP»)",
                   bm.lua_onoff(bm.rd("exp_mult_gv3.lua"), bm.rd("exp_mult_off_gv3.lua")), VERDE)
    xch = ET.SubElement(xp, "CheatEntries")
    bm.lista(xch, "Multiplicador de EXP (×1 … ×1024)", "gv3_exp_mult", bm.MULT)
    cadena(xch, "EXP de wepon1984 (cambia, pero el nivel no la usa)", [0x20, 0x110, 0x2A80], "4 Bytes", GRIS)
    cadena(xch, "Nivel (solo lectura)", [0x20, 0x110, 0x2A86], "Byte")

    kd = bm.script(T, "Prestigio ×N / mantener (elegir ×N abajo) — probado ✅",
                   bm.lua_onoff(bm.rd("prestigio_mult_gv3.lua"), bm.rd("prestigio_mult_off_gv3.lua")), VERDE)
    kch = ET.SubElement(kd, "CheatEntries")
    bm.lista(kch, "Multiplicador de Prestigio (×1 … ×1024)", "gv3_kudos_mult", bm.MULT)
    bm.lista(kch, "Mantener Prestigio (no baja)", "gv3_kudos_keep", bm.SINO)
    cadena(kch, "Prestigio (float; = pantalla)", [0x264], "Float")

    kb = bm.script(T, "Kudos bloqueados: quitar ×N / anular (elegir abajo) — probado ✅",
                   bm.lua_onoff(bm.rd("kudos_bloq_mult_gv3.lua"), bm.rd("kudos_bloq_mult_off_gv3.lua")), VERDE)
    bch = ET.SubElement(kb, "CheatEntries")
    bm.lista(bch, "Multiplicador al pagar el castigo (×1 … ×1024)", "gv3_kbloq_mult", bm.MULT)
    bm.lista(bch, "Anular el castigo (lo deja en 0)", "gv3_kbloq_cero", bm.SINO)
    cadena(bch, "Castigo (float, [B]+0x2FC; en pantalla sale en negativo; se paga solo)", [0x2FC], "Float")

    ic = cadena(T, "Image Chips del nivel (bits; elegir «todos» según el nivel: 3, 5 o 7 chips)", [0x198], "Byte", VERDE)
    ET.SubElement(ic, "DropDownList", {"DisplayValueAsItem": "1"}).text = \
        "0:ninguno\n7:3 de 3 (todos)\n31:5 de 5 (todos)\n127:7 de 7 (todos)\n"

    V = bm.group(T, "Valores (cadenas de wepon1984 desde game3.exe+1F02FE8)", VERDE)
    cadena(V, "Prestigio (float)", [0x264], "Float")
    cadena(V, "Score", [0x44])
    cadena(V, "Score (float, copia)", [0x348], "Float", GRIS)
    cadena(V, "Barra Fetters (float)", [0x478], "Float")
    cadena(V, "Tiempo de nivel (float; unidad por confirmar)", [0x354], "Float", GRIS)
    cadena(V, "Image Chips (copia en +0xA0; ¿cuál cuenta al terminar?)", [0xA0], "Byte", GRIS)
    return T


def gv3_sondas(G):
    H = bm.group(G, "🔧 Sondas de GV3", GRIS)
    bm.script(H, "Sonda de invencibilidad v5 (dueños del componente de vida; 30 s, NO atacar)",
              bm.lua_wrap(bm.HERE / "sonda_invencibilidad_gv3.lua"), bm.CELESTE)
    bm.script(H, "Sonda de EXP real (pide EXP y Nivel del menú; 5 min)",
              bm.lua_wrap(bm.HERE / "sonda_exp_gv3.lua"), bm.CELESTE)
    bm.script(H, "Sonda de Kudos bloqueados (pide direcciones y pantalla; 5 min)",
              bm.lua_wrap(bm.HERE / "sonda_kudos_bloqueados_gv3.lua"), bm.CELESTE)
    bm.script(H, "Diagnóstico GV3 v3 (base, cadenas, mapas de campos; 5 min)",
              bm.lua_wrap(bm.HERE / "diag_gv3.lua"), bm.CELESTE)
    return H
