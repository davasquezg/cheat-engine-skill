# -*- coding: utf-8 -*-
"""
i18n.py — Traducciones de la tabla MMSF Legacy Collection v8 (español / inglés).

Criterio:
  * Se traducen etiquetas genéricas, notas (##), cabeceras de grupo y textos de los scripts.
  * NO se traducen nombres propios del juego (cartas, habilidades, objetos como Unlocker o
    Search Eye, títulos) para no inventar nombres oficiales.
  * Los nombres "[List] ..." no se traducen porque los referencian los DropDownListLink.

Licencia: PolyForm Noncommercial 1.0.0 (ver LICENSE en la raíz del repositorio).
"""

# --------------------------------------------------------------------------------------
# Descripciones de entradas: texto en la tabla base -> traducción
# --------------------------------------------------------------------------------------
DESC_ES = {
    "##Chance of pointer breaking and crashing game if locked":
        "##Si se congela, el puntero puede romperse y cerrar el juego",
    "##Do not change quantity if it is not 0 or does not match what you have":
        "##No cambies la cantidad si no es 0 o no coincide con lo que tienes",
    "##Not all pointers will work until battle is started":
        "##Algunos punteros solo funcionan después de iniciar una batalla",
    "##Will not save if modified while editing Folder":
        "##No se guarda si se modifica mientras editas la Carpeta",
    "0 Stars": "0 estrellas",
    "1 Stars": "1 estrella",
    "2 Stars": "2 estrellas",
    "3 Stars": "3 estrellas",
    "1. White / Colorless Border": "1. Borde blanco / sin color",
    "2. Standard / Yellow Border": "2. Standard / borde amarillo",
    "2.1 Mega / Giga / Yellow Border": "2.1 Mega / Giga / borde amarillo",
    "3. Mega / Blue Border": "3. Mega / borde azul",
    "4. Giga / Red Border": "4. Giga / borde rojo",
    "Ability": "Habilidades",
    "Battle": "Batalla",
    "Buster Charge": "Carga del Buster",
    "Buster Charge Level": "Nivel de carga del Buster",
    "Busting Rank Modifier": "Modificador de Busting Rank",
    "Cards": "Cartas",
    "Cloak Steps Left": "Pasos restantes de Cloaker",
    "Counter Hits": "Golpes de contraataque (Counter)",
    "Current Charge Level (Vusual Only)": "Nivel de carga actual (solo visual)",
    "Max Charge Level  (Vusual Only) (Do not Change)": "Nivel de carga máximo (solo visual) (no cambiar)",
    "Custom Gauge": "Barra Custom",
    "Delete Time": "Tiempo de eliminación (Delete Time)",
    "Double Deletion": "Doble eliminación",
    "Triple Deletion": "Triple eliminación",
    "HP Upgrade +10": "Mejora de HP +10",
    "HP Upgrade +20": "Mejora de HP +20",
    "HP Upgrade +10  [HP máx. = 100 + 10×(+10) + 20×(+20); tope 1000]":
        "Mejora de HP +10  [HP máx. = 100 + 10×(+10) + 20×(+20); tope 1000]",
    "HP Upgrade +20  [tope de HP 1000: p. ej. 18/36 o 30/30]":
        "Mejora de HP +20  [tope de HP 1000: p. ej. 18/36 o 30/30]",
    "Invincibility Timer": "Temporizador de invencibilidad",
    "Noise Gauge - 0.#%  (Display)": "Barra de Noise - 0.#% (visualización)",
    "Noise Gauge Change - 0.#% (Current Battle)": "Cambio de Noise - 0.#% (batalla actual)",
    "Steps Taken": "Pasos dados",
    "Sub item": "Subobjetos",
    "Time Since Last Shot": "Tiempo desde el último disparo",
    "Times Hit in Battle": "Veces golpeado en batalla",
    "[Backup]": "[Respaldo]",
    "[WIP]": "[En desarrollo]",
}

DESC_EN = {
    "##Bytes por carta: +70 blanco | +71 amarillo | +72 azul (Mega) | +73 rojo (Giga)":
        "##Bytes per card: +70 white | +71 yellow | +72 blue (Mega) | +73 red (Giga)",
    "##Editar SOLO desde el mapa (sin Folder/Biblioteca abiertos): al cerrar el menú se sobrescribe":
        "##Edit ONLY from the field map (Folder/Library closed): closing the menu overwrites changes",
    "+30 desconocido (NO es Max HP; 710 fijo al recibir daño) — sin verificar":
        "+30 unknown (NOT Max HP; stays at 710 after taking damage) — unverified",
    "5. All  [⚠ 4 Bytes desde +71: escribe también +72/+73/+74 — puede borrar Mega/Giga]":
        "5. All  [⚠ 4 Bytes from +71: also writes +72/+73/+74 — may erase Mega/Giga]",
    "Delete Time  [Script: fijo en 1 durante la batalla]":
        "Delete Time  [Script: locked at 1 during battle]",
    "Gorgon Eye (? duplicado de +7A8 en tabla original — sin verificar)":
        "Gorgon Eye (? duplicate of +7A8 in the original table — unverified)",
    "HP actual": "Current HP",
    "HP base (inicial 100)": "Base HP (starts at 100)",
    "Noise Gauge  [Script: fijo en batalla — pide valor 500–9999]":
        "Noise Gauge  [Script: locked during battle — asks for a value 500–9999]",
    "[Resolver] Bases SF1/SF2/SF3 — activar primero": "[Resolver] SF1/SF2/SF3 bases — enable first",
    "HP Upgrade +10  [HP máx. = 100 + 10×(+10) + 20×(+20); tope 1000]":
        "HP Upgrade +10  [Max HP = 100 + 10×(+10) + 20×(+20); capped at 1000]",
    "HP Upgrade +20  [tope de HP 1000: p. ej. 18/36 o 30/30]":
        "HP Upgrade +20  [HP capped at 1000: e.g. 18/36 or 30/30]",
    "Mr Hertzes  [persiste pero NO afecta al juego — en investigación]":
        "Mr Hertzes  [value sticks but does NOT affect the game — under investigation]",
    "Current Charge Level (Vusual Only)": "Current Charge Level (Visual Only)",
    "Max Charge Level  (Vusual Only) (Do not Change)": "Max Charge Level (Visual Only) (Do not Change)",
}

# Listas desplegables (texto completo del elemento <DropDownList>)
DROPDOWN_ES = {"4000:Max\n0000:Empty\n*:Filling\n": "4000:Llena\n0000:Vacía\n*:Cargando\n"}
DROPDOWN_EN = {}

# --------------------------------------------------------------------------------------
# Textos dentro de los scripts (AssemblerScript): la base está en español
# --------------------------------------------------------------------------------------
SCRIPT_EN = [
    # Resolver
    ("-- Resolver de bases generado por ct_tool.py (skill cheat-engine-tables)",
     "-- Base resolver generated by ct_tool.py (cheat-engine-tables skill)"),
    ("-- Estrategia: 1) AOB dentro del módulo -> resolver dirección RIP-relativa",
     "-- Strategy: 1) AOB inside the module -> resolve the RIP-relative address"),
    ("--             2) Si el AOB falla (0 o >1 destinos distintos) -> offset estático de respaldo",
     "--           2) If the AOB fails (0 or >1 distinct targets) -> static fallback offset"),
    ("-- Resultado en la tabla global CT_RESOLVER (consultar con showMessage; print() va a Memory View > Tools > Lua Engine)",
     "-- Result in the global table CT_RESOLVER (check it with showMessage; print() goes to Memory View > Tools > Lua Engine)"),
    ('"[Resolver] Módulo no encontrado: " .. MODULE .. " (¿proceso adjuntado?)"',
     '"[Resolver] Module not found: " .. MODULE .. " (is the process attached?)"'),
    ("-- Lista de firmas candidatas (se prueba en orden; gana la primera inequívoca)",
     "-- Candidate signatures (tried in order; the first unambiguous one wins)"),
    ('"AOB #%d de %d (%d coincidencia/s)"', '"AOB #%d of %d (%d match(es))"'),
    ('"AOB falló ("', '"AOB failed ("'),
    ('"RESPALDO estático"', '"static FALLBACK"'),
    ('"  (NO LEGIBLE)"', '"  (NOT READABLE)"'),
    ('"%-16s = NO RESUELTO [%s]"', '"%-16s = NOT RESOLVED [%s]"'),
    ('"sin AOB ni respaldo"', '"no AOB and no fallback"'),
    ("Validado 2026-10-10. AOB verificados en volcado 2026-10-11",
     "Validated 2026-10-10. AOBs verified on memory dump 2026-10-11"),
    # Scripts de batalla (SF3)
    ("SF3 - Noise fijo en batalla", "SF3 - Noise locked in battle"),
    ("Noise Gauge Change (Current Battle). Unidades 0.1 %: 500 = 50.0 %, 9999 = 999.9 %. Pide el valor al activar.",
     "Noise Gauge Change (Current Battle). Units of 0.1 %: 500 = 50.0 %, 9999 = 999.9 %. Asks for the value when enabled."),
    ("SF3 - Delete Time fijo en 1", "SF3 - Delete Time locked at 1"),
    ("Delete Time = 1 desde el inicio de la batalla y fijo hasta el final.",
     "Delete Time = 1 from the start of the battle and locked until the end."),
    ("(4 Bytes). Requiere el [Resolver] activo.", "(4 Bytes). Requires the [Resolver] to be enabled."),
    ("-- Mantiene el valor FIJO mientras dure la batalla (revisa cada",
     "-- Keeps the value LOCKED for the whole battle (checks every"),
    ("-- Fuera de batalla la cadena no resuelve y el script no escribe nada.",
     "-- Outside battle the chain does not resolve and the script writes nothing."),
    ("-- Cadena:", "-- Chain:"),
    ('"Valor fijo (500 a 9999):"', '"Locked value (500 to 9999):"'),
    ('"Cancelado por el usuario"', '"Cancelled by the user"'),
    ('"Valor no numérico: "', '"Not a number: "'),
    ('"Aviso: sf3_base no está registrado. Activa primero el [Resolver]."',
     '"Warning: sf3_base is not registered. Enable the [Resolver] first."'),
]

SCRIPT_ES = []   # la base ya está en español
