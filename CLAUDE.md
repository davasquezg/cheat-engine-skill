# CLAUDE.md — guía del repositorio para Claude (Code / Cowork)

Repositorio: <https://github.com/davasquezg/cheat-engine-skill> · Autor: Darío Vásquez Guzmán (@davasquezg; en FearLess Revolution: **Skolleks**).

## Qué es

1. **`cheat-engine-tables/`** — una *skill* de Claude + kit (Python/Lua) para crear, auditar, reparar y endurecer tablas de Cheat Engine (`.CT`) en juegos **de un jugador / offline**.
2. **`ct-tablas/<juego>/`** — un proyecto por juego, construido con esa skill. Cada carpeta tiene su propio `CLAUDE.md` con el estado y los datos verificados.

| Carpeta | Juego | Estado |
|---|---|---|
| `ct-tablas/mmsf-legacy-collection/` | Mega Man Star Force Legacy Collection (Steam, build 1.0.2.0) | ✅ Publicada: tabla **v9** ES/EN + versión FearLess |
| `ct-tablas/gulvolt-trilogy/` | Azure Striker Gunvolt Trilogy Enhanced (Steam app 3813350) | 🧪 En investigación: GV1 (`game1.exe`) con multisonda sin depurador |

> El nombre de carpeta `gulvolt-trilogy` es histórico (el juego es *Gunvolt*). No renombrar sin actualizar las rutas absolutas de los scripts Lua (`D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\…`).

## Entorno del usuario

- Equipo **dvg-arcx2**, Windows 11; repo en `D:\SCM\cheat-engine-skill`; git con **GitKraken** (usar el MCP de GitKraken para status/add/commit/push).
- Cheat Engine 7.5+. Scripts Lua de diagnóstico se pegan en **Memory View → Tools → Lua Engine** (Ctrl+Alt+L es la ventana de ejecutar script). `print()` sale en el Lua Engine; para que el usuario vea resultados usar `showMessage` + `writeToClipboard`.
- Juegos: MMSF en `H:\SteamLibrary\steamapps\common\MegaMan StarForce LegacyCollection`; Gunvolt en `C:\Program Files (x86)\Steam\steamapps\common\Azure Striker Gunvolt Trilogy Enhanced`.
- Idioma de trabajo: **español** (documentos ES primero, luego EN). Mensajes de commit en español.

## Estructura

```
CLAUDE.md                     ← este archivo
README.md / README.en.md      ← presentación pública (ES / EN)
CREDITS*.md, LICENSE, LICENSE-docs
cheat-engine-tables/          ← la skill
├── SKILL.md                  ← instrucciones de la skill (leer antes de trabajar en una tabla)
├── scripts/ct_tool.py        ← info · tree · chains · rebase · resolve · validate · diff
├── scripts/sigmaker.py       ← peinfo · refs · make · check (firmas AOB x64; --dump para volcados)
├── lua/ct_helpers.lua        ← ctFindStatic, ctFollow, ctVerify, ctDumpModule (consola Lua de CE)
├── references/               ← ct-format.md, live-workflow.md, aa-templates.md
├── templates/                ← resolvers.<juego>.json
└── tests/run_tests.sh        ← pruebas de humo (requiere Lua 5.3)
ct-tablas/<juego>/            ← cada juego: CLAUDE.md + README ES/EN + scripts de build + .CT
```

## Comandos frecuentes

```bash
pip install pefile capstone numpy
python cheat-engine-tables/scripts/ct_tool.py validate <tabla.CT>     # siempre tras generar una tabla
python cheat-engine-tables/scripts/ct_tool.py tree <tabla.CT>
python cheat-engine-tables/scripts/sigmaker.py peinfo <exe|dump> [--dump]
bash   cheat-engine-tables/tests/run_tests.sh
```

Revisar sintaxis de Lua antes de entregar: `luac5.3 -p archivo.lua` (CE usa Lua 5.3; `//` y `goto` están permitidos).

## Reglas del proyecto

- **Legal / alcance:** solo juegos offline. No se publican ejecutables, volcados (`*.dmp`, `dumps/`) ni recursos del juego. Las tablas **originales de terceros** se guardan solo en local en `ct-tablas/<juego>/original/` (los `.CT` están en `.gitignore`); lo que sí se versiona es `original/FUENTES.md` con el hilo, el nombre y el SHA-256 para volver a descargarlas. En `dumps/` se versionan los informes `.txt` de las sondas, nunca los `.dmp`.
- **Licencias:** código = PolyForm Noncommercial 1.0.0 (`LICENSE`); docs y datos = CC BY-NC-SA 4.0 (`LICENSE-docs`). Cabecera de licencia en cada script nuevo.
- **Créditos:** toda tabla derivada acredita al autor original (`CREDITS.md`, nota `##` y *Table Extras → Comments*).
- **FearLess Revolution** (<https://fearlessrevolution.com/viewtopic.php?t=20>): tablas modificadas → PM al autor y esperar 48 h; cabecera `[Autor] (original author)` intacta + cabecera propia `[Skolleks]`; sin enlaces externos en el post; el `.CT` se adjunta en el foro. En GitHub estas reglas no aplican, pero se respetan los créditos.
- **Tablas generadas, no editadas a mano:** cada `.CT` publicado sale de un script `build_*.py`. Para cambiar una tabla, editar el script (y `i18n.py` para textos) y regenerar; luego `ct_tool.py validate`.
- **Versiones:** al cambiar el contenido de una tabla publicada se sube la versión (v8 → v9…) y la anterior se conserva como referencia.
- **Edición de valores en juego:** siempre desde el mapa, sin menús abiertos (el juego sobrescribe al cerrar menús).

## Lecciones técnicas (aplican a cualquier juego)

- `<Offsets>` del `.CT` se guardan en orden **inverso** al de aplicación.
- Ejecutables con SteamStub (`.bind`, `.text` con entropía 8,0): las firmas se sacan de un **volcado de memoria** del módulo, no del `.exe` en disco.
- Si el juego se cierra con el depurador de CE (anti-debug, p. ej. Gunvolt): trabajar **sin depurador** — análisis estático del volcado + sondas por inyección que cuentan ejecuciones + muestreo de memoria con temporizadores Lua.
- Valores en memoria a menudo escalados: ×16 (HP GV1), ×256 (punto fijo 24.8: Prestigio GV1, EP GV2), ×10 000 (PE GV1), ×160 (HP/Kudos GV2), float (GV3).
- Estructuras en el heap sin punteros estáticos: localizar por **firma de memoria** (punteros a código de `game.exe` dentro del objeto) + validación de campos; re-localizar con un temporizador.
- Al recargar una tabla, CE **no deshace** las inyecciones activas: desactivar los scripts antes de recargar, o escribir AOB tolerantes a la zona ya parchada.
