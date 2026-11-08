#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_trilogia_alpha.py — Genera la tabla ALFA de Azure Striker Gunvolt Trilogy Enhanced (ES).

Junta en una sola tabla, un grupo por ejecutable (activar el grupo = adjuntar CE a ese exe):
  * GV1 (game1.exe): todo lo rescatado de la multisonda (trucos verificados en vivo + sondas)
    y las direcciones candidatas trasladadas desde la tabla de wepon1984 (ANALISIS §8.1).
  * GV2 / GV3 / Connect iX (game2/3/4.exe): grupos de wepon1984 portados tal cual desde
    original/trilogy.CT (otra build: sin verificar en la nuestra).
Colores: verde = verificado en vivo · gris = candidato sin verificar · naranja = dato de wepon1984.

Versiones: cada vez que cambia el contenido se sube VERSION y el .CT anterior se conserva como referencia.
  v0.1-alpha (2026-11-08) GV1 de la multisonda + candidatas de wepon1984; GV2/GV3/Connect iX portados.
  v0.2-alpha (2026-11-08) Verificación v1/v2: Nivel, EXP, PV máx. y puntero al jugador [+7B3220] en verde;
                          fuera las candidatas fallidas; nuevas pistas (Δ 0x9000, Kudos ×1, Tiempo total);
                          «🔎 Verificar candidatas» v3 (5 min de muestreo).
  v0.3-alpha (2026-11-08) Verificación v3: Medallas (+7E10DC), Tiempo de nivel (+7E10D4) y Tiempo total
                          (Créditos−0xE0) en verde; fuera Score y Kudos estáticos (no existen en game1.exe).
                          EXP ×N y Prestigio ×N separados, con listas desplegables ×1, ×2, ×4 … ×1024.

Uso:  python build_trilogia_alpha.py [original/trilogy.CT] [-o salida.CT] [--force]
Licencia de este archivo: PolyForm Noncommercial 1.0.0 (ver LICENSE en la raíz).
"""
import argparse
import copy
import hashlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "sondas"))
import build_multisonda as bm  # noqa: E402  (gv1_trucos, gv1_sondas y utilidades de la multisonda)

# SHA-256 de la tabla de wepon1984 analizada (original/FUENTES.md)
ORIGINAL_SHA256 = "395928fcaeaf2241b414dc706a7d9d7e8d926af0f59f6cdf3d6898a0c3bab0fd"
VERSION = "v0.3-alpha"
SALIDA = HERE / f"Gunvolt_Trilogy_Enhanced_{VERSION}_ES.CT"

VERDE, GRIS, NARANJA, AZUL = "008000", "808080", "0080FF", "FF0000"   # CE usa BGR

CRED = 0x7B3668        # Créditos GV1 (verificado)
COMB = 0x7ED64C        # Energía, inicio del bloque de combate GV1 (verificado)
COPIA = 0x7ED67C       # copia del bloque de combate (no manda)
PJUG = 0x7B3220       # puntero estático al jugador (hallado 2026-11-08; también +7E02F8 y +7ED630)

CREDITOS = """Azure Striker Gunvolt Trilogy Enhanced — tabla {v} (ES), en construcción.
Proyecto: https://github.com/davasquezg/cheat-engine-skill (Skolleks).

Créditos:
- wepon1984 (FearLess t=35866): tabla de la trilogía; grupos de GV2, GV3 y Connect iX portados tal cual,
  direcciones de GV1 usadas como candidatas y patrón de «activar grupo = adjuntar al exe».
- ndck1 (FearLess t=35891): zona AOB del editor de vida de GV1, base de la «Captura jugador».
- WarCOzes (t=1929), Shinkansen (t=12924), RTX_XXXX (t=21777): formas de datos y escalas de GV1/GV2/GV3.

Colores: verde = verificado en vivo (build 2026-10-07) · gris = candidato sin verificar · naranja = wepon1984 (otra build).
Editar valores desde el mapa, sin menús abiertos. Desactivar los scripts antes de recargar la tabla.""".format(v=VERSION)


def nota(parent, texto, color=AZUL):
    e = bm.new(parent, "##" + texto, color)
    ET.SubElement(e, "GroupHeader").text = "1"
    return e


def adjuntar(parent, desc, exe, color):
    """Script que adjunta CE al exe; sus hijos se ocultan y se desactivan al apagarlo."""
    src = f"""{{ Adjunta Cheat Engine a {exe} (patrón de wepon1984). Activar con el juego abierto. }}
[ENABLE]
{{$lua}}
if syntaxcheck then return end
if getCEVersion() < 7.4 then showMessage("Se recomienda Cheat Engine 7.4 o superior.") end
if (process or ""):lower() ~= "{exe}" then openProcess("{exe}") end
if (process or ""):lower() ~= "{exe}" then
  error("{exe} no está abierto: entra a ese juego desde el menú de la colección.")
end
{{$asm}}
[DISABLE]
"""
    e = bm.script(parent, desc, src, color)
    ET.SubElement(e, "Options", {"moHideChildren": "1", "moDeactivateChildrenAsWell": "1"})
    return ET.SubElement(e, "CheatEntries")


def renumerar(e):
    """IDs nuevos (únicos en esta tabla) y sin LastState heredado."""
    for x in e.iter("CheatEntry"):
        bm.nid += 1
        x.find("ID").text = str(bm.nid)
        for ls in x.findall("LastState"):
            x.remove(ls)
    return e


def portar(dest, origen, listas):
    """Copia los hijos de un grupo de wepon1984. Quita los DropDownListLink que apuntan a una entrada
    sin lista (en el original, 6 armas EX de Connect iX enlazan a «Anchor Nexus», que no tiene lista)."""
    for c in origen.find("CheatEntries"):
        c = renumerar(copy.deepcopy(c))
        for x in c.iter("CheatEntry"):
            ln = x.find("DropDownListLink")
            if ln is not None and (ln.text or "").strip() not in listas:
                x.remove(ln)
        dest.append(c)


# ================================ GV1 ================================
def gv1(top):
    G = adjuntar(top, "▶ Azure Striker Gunvolt 1 (game1.exe) — activar para adjuntar", "game1.exe", VERDE)
    nota(G, "GV1: entra a un nivel. Los trucos activan solos la «Captura jugador».")
    bm.gv1_trucos(G, con_valores=False)

    V = bm.group(G, "Valores verificados (estáticos, build 2026-10-07)", VERDE)
    bm.dword(V, "Créditos — persiste al guardar", f"game1.exe+{CRED:X}")
    bm.dword(V, "Nivel (Créditos+0x47C; no modificar)", f"game1.exe+{CRED + 0x47C:X}", None, "2 Bytes")
    bm.dword(V, "EXP total (Créditos+0x478)", f"game1.exe+{CRED + 0x478:X}")
    bm.dword(V, "Energía / PE (×10 000; congelar = infinita)", f"game1.exe+{COMB:X}")
    bm.dword(V, "Skill Points / PH (1 = 20000000; 3 = 60000000)", f"game1.exe+{COMB + 4:X}")
    for i in range(4):
        bm.dword(V, f"Cooldown habilidad {i+1} (lista = 76800)", f"game1.exe+{COMB + 0xC + 4*i:X}")
    bm.dword(V, "PV máx. sin escalar (bloque de combate +0x2C; +5 por nivel)", f"game1.exe+{COMB + 0x2C:X}")
    bm.dword(V, "Medallas del nivel (+7E10DC)", "game1.exe+7E10DC")
    bm.dword(V, "Tiempo de nivel (+7E10D4; ≈ 7660 por segundo)", "game1.exe+7E10D4")
    bm.dword(V, "Tiempo total (Créditos−0xE0; ≈ 7660 por segundo)", f"game1.exe+{CRED - 0xE0:X}")

    J = bm.group(G, f"Jugador por puntero estático [game1.exe+{PJUG:X}] (válido tras recargar partida)", VERDE)
    bm.ptr(J, "HP actual (×16)", f"game1.exe+{PJUG:X}", 0x398)
    bm.ptr(J, "HP máximo (×16)", f"game1.exe+{PJUG:X}", 0x39C)
    bm.ptr(J, "Invencibilidad (+518, entero; 11520 = recién golpeado)", f"game1.exe+{PJUG:X}", 0x518)
    bm.ptr(J, "Invencibilidad (+518, float según wepon1984 — verificar tipo)", f"game1.exe+{PJUG:X}", 0x518, "Float")

    C = bm.group(G, "Candidatos sin verificar", GRIS)
    nota(C, "Campos que se mueven pero aún no tienen significado confirmado.", GRIS)
    bm.dword(C, "Copia de la EXP (Créditos+0x438; la mantiene el juego, no editar)", f"game1.exe+{CRED + 0x438:X}", GRIS)
    bm.dword(C, "Medallas guardadas? (Créditos+0x44C; subió 1 → 2)", f"game1.exe+{CRED + 0x44C:X}", GRIS)
    bm.dword(C, "Contador desconocido (+7FFEC8; sube al combatir, NO es el Prestigio)", "game1.exe+7FFEC8", GRIS)
    bm.dword(C, "Contador desconocido (+7FFEE0; sube al combatir, NO es el Prestigio)", "game1.exe+7FFEE0", GRIS)
    K = bm.group(C, "Copia del bloque de combate (+7ED67C) — no manda (¿punto de control?)", GRIS)
    bm.dword(K, "Energía (copia)", f"game1.exe+{COPIA:X}", GRIS)
    bm.dword(K, "Skill Points (copia)", f"game1.exe+{COPIA + 4:X}", GRIS)
    for i in range(4):
        bm.dword(K, f"Cooldown habilidad {i+1} (copia)", f"game1.exe+{COPIA + 0xC + 4*i:X}", GRIS)

    bm.gv1_sondas(G)


# ================================ GV2 / GV3 / Connect iX ================================
JUEGOS = [("126151", "▶ Azure Striker Gunvolt 2 (game2.exe) — activar para adjuntar", "game2.exe"),
          ("126152", "▶ Azure Striker Gunvolt 3 (game3.exe) — activar para adjuntar", "game3.exe"),
          ("126153", "▶ Azure Striker Gunvolt Connect iX (game4.exe) — activar para adjuntar", "game4.exe")]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("original", nargs="?", default=str(HERE / "original" / "trilogy.CT"),
                    help="tabla de wepon1984 (original/trilogy.CT)")
    ap.add_argument("-o", "--output", default=str(SALIDA))
    ap.add_argument("--force", action="store_true", help="continuar aunque el SHA-256 no coincida")
    a = ap.parse_args()

    src = Path(a.original)
    if not src.exists():
        sys.exit(f"No existe {src}. Ver original/FUENTES.md para descargarla.")
    sha = hashlib.sha256(src.read_bytes()).hexdigest()
    if sha != ORIGINAL_SHA256:
        print(f"AVISO: el SHA-256 de la tabla de wepon1984 no coincide.\n  esperado {ORIGINAL_SHA256}\n  recibido {sha}")
        if not a.force:
            sys.exit("Usa --force para continuar igualmente.")
    w = ET.parse(src).getroot()
    por_id = {e.findtext("ID"): e for e in w.iter("CheatEntry")}
    listas = {(e.findtext("Description") or "").strip('"') for e in w.iter("CheatEntry") if e.find("DropDownList") is not None}

    root = ET.Element("CheatTable", {"CheatEngineTableVersion": "45"})
    top = ET.SubElement(root, "CheatEntries")
    nota(top, f"Gunvolt Trilogy Enhanced — {VERSION} (ES) · Skolleks · en construcción")
    nota(top, "Créditos: wepon1984 · ndck1 · WarCOzes · Shinkansen · RTX_XXXX (ver Table Extras → Comments)")
    nota(top, "Verde = verificado en vivo · gris = candidato · naranja = wepon1984 (otra build, sin verificar)", GRIS)

    gv1(top)
    for wid, desc, exe in JUEGOS:
        G = adjuntar(top, desc, exe, NARANJA)
        nota(G, f"Grupo de wepon1984 portado sin cambios (nombres originales). Sin verificar en nuestra build de {exe}.",
             NARANJA)
        portar(G, por_id[wid], listas)

    # Listas desplegables de wepon1984: las entradas las enlazan por su Description, que se conserva
    top.append(renumerar(copy.deepcopy(por_id["116253"])))

    ET.SubElement(root, "Comments").text = CREDITOS
    ET.indent(root)
    out = Path(a.output)
    ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)
    print("Generado:", out)


if __name__ == "__main__":
    main()
