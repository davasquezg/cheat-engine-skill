# cheat-engine-skill

**Español** · [English](README.en.md)

Skill para Claude que sirve para **crear, auditar, reparar y endurecer tablas de Cheat Engine (`.CT`)** en juegos **de un jugador / offline**. Incluye un kit de herramientas (Python + Lua) y una tabla de ejemplo ya reparada y validada en el juego, disponible en **español e inglés**.

## Qué resuelve

Cuando un juego se actualiza, las tablas `.CT` que dependen de direcciones estáticas (`juego.exe+0E120A40`) dejan de funcionar. Este proyecto sirve para:

1. **Auditar la tabla:** detecta las anclas de las que dependen cientos de entradas y valida el XML.
2. **Recuperar las bases** con el juego abierto mediante búsqueda inversa de punteros desde un valor conocido.
3. **Endurecer la tabla:** cambia las direcciones fijas por **símbolos resueltos por AOB** (varias firmas por base) con un respaldo estático. Así la tabla puede sobrevivir a futuros parches.
4. **Trabajar con ejecutables empaquetados o con DRM:** genera las firmas desde un volcado de memoria del módulo, sin modificar el ejecutable.

## Contenido

```
cheat-engine-tables/          ← la skill (SKILL.md) y su kit
├── SKILL.md                  ← instrucciones para Claude
├── scripts/
│   ├── ct_tool.py            ← info, tree, chains, rebase, resolve, validate, diff
│   └── sigmaker.py           ← peinfo, refs, make, check (firmas AOB x64, admite --dump)
├── lua/ct_helpers.lua        ← funciones para la consola Lua de Cheat Engine
├── templates/                ← configuración del resolver por juego (JSON)
├── references/               ← formato .CT, flujo en vivo, plantillas Auto Assembler
└── tests/run_tests.sh        ← pruebas de humo (PE sintético + API de CE simulada)
ct-tablas/
└── mmsf-legacy-collection/
    ├── MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_ES.CT   ← tabla en español
    ├── MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_EN.CT   ← tabla en inglés
    ├── ..._v8_..._ES.CT / _EN.CT  ← versión anterior (referencia)
    ├── build_v9.py           ← parche reproducible desde la tabla original (--lang es|en)
    ├── i18n.py               ← traducciones de la tabla
    └── resolvers.json        ← bases y firmas AOB de la build 1.0.2.0
```

## Instalación

### Como skill de Claude
Sube la carpeta `cheat-engine-tables/` como skill personalizada (Claude Desktop / Cowork o Claude Code). El archivo de entrada es `SKILL.md`.

### Kit en tu equipo
```bash
pip install pefile capstone numpy
python cheat-engine-tables/scripts/ct_tool.py info tabla.CT
bash cheat-engine-tables/tests/run_tests.sh          # Linux/WSL, requiere Lua 5.3
```

## Tabla incluida: Mega Man Star Force Legacy Collection

| Dato | Valor |
|---|---|
| Build | FileVersion **1.0.2.0**, TimeDateStamp `0x6A0A9BF4` (2026-05-18), Steam |
| Bases | `sf12_base` (SF1/SF2) y `sf3_base` (SF3), resueltas por AOB (3 firmas por base) con respaldo estático |
| Validado en el juego | Zenny, HP, cartas, subitems y habilidades (SF1–SF3); scripts de Noise Gauge, Delete Time y Mejoras de HP (SF3) |
| Idiomas | `_ES.CT` (español) y `_EN.CT` (inglés). Ambas tienen las mismas direcciones; solo cambian los textos |

**Obtener la tabla:** usa directamente el `.CT` en tu idioma, que está en `ct-tablas/mmsf-legacy-collection/`. Si lo prefieres, regenérala desde la original de [FearLess Revolution (t=38738)](https://fearlessrevolution.com/viewtopic.php?t=38738) con `build_v9.py --lang es` o `--lang en`.

**Uso:**
1. Abre el juego y adjunta Cheat Engine (7.5 o superior).
2. Carga la tabla y activa **`[Resolver] Bases SF1/SF2/SF3 — activar primero`**.
3. **Edita los valores solo desde el mapa**, sin la Carpeta ni la Biblioteca abiertas. Si hay un menú abierto, el juego sobrescribe los cambios al cerrarlo.
4. Para fijar valores en combate (SF3), activa las cabeceras-script **Noise Gauge** (pide un valor entre 500 y 9999) o **Delete Time** (lo fija en 1). Para el HP máximo, activa **Mejoras de HP** (por defecto 1000 HP; para editar a mano, desactívalo).

> En la versión en español se tradujeron las etiquetas, notas y mensajes. Los **nombres propios del juego** (cartas, habilidades y objetos como *Unlocker* o *Search Eye*) se mantienen como en la tabla original, para no inventar nombres oficiales.

## Alcance

- Pensado **solo** para juegos de un jugador u offline, para modificar el estado local de la partida.
- **No** está pensado para juegos en línea o competitivos, títulos con anti-cheat ni para evadir DRM. Los volcados de memoria se usan solo para leer firmas y nunca se distribuyen.
- No se incluye ningún archivo del juego: ni el ejecutable, ni volcados, ni recursos.

## Licencias

| Parte | Licencia | Archivo |
|---|---|---|
| Código: `scripts/`, `lua/`, `tests/`, `build_v9.py`, `i18n.py` y los scripts que genera | **PolyForm Noncommercial 1.0.0** | [`LICENSE`](LICENSE) |
| Documentación y datos: `SKILL.md`, `references/`, `templates/`, `resolvers.json` y los aportes propios en las tablas `.CT` | **CC BY-NC-SA 4.0** | [`LICENSE-docs`](LICENSE-docs) |

Se permite el uso personal, educativo, de investigación y de organizaciones sin fines de lucro. **No se permite el uso comercial ni corporativo.** Si necesitas otra licencia, abre un *issue*.

Los textos de licencia en inglés son los oficiales y vinculantes. Ver créditos y obras de terceros en [`CREDITS.md`](CREDITS.md).

## Autor

Darío Vásquez Guzmán — [@davasquezg](https://github.com/davasquezg)
